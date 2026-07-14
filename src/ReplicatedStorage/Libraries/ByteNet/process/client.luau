local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local types = require(script.Parent.Parent.types)
local read = require(script.Parent.read)
local bufferWriter = require(script.Parent.bufferWriter)

local alloc = bufferWriter.alloc
local u8 = bufferWriter.u8
local u32 = bufferWriter.u32
local load = bufferWriter.load

local QUERY_TIMEOUT_SECONDS = 10

local pendingQueries: { [number]: { thread: thread, timeoutToken: any, resumed: boolean } } = {}
local nextQueryId: number = 1

local function onClientEvent(receivedBuffer, ref)
	read(receivedBuffer, ref)
end

local function onQueryResponse(receivedBuffer: buffer, ref)
	if not (typeof(receivedBuffer) == "buffer") then
		return
	end

	if buffer.len(receivedBuffer) < 4 then
		return
	end

	local queryId = buffer.readu32(receivedBuffer, 0)
	local pending = pendingQueries[queryId]
	if not pending or pending.resumed then
		return
	end

	pending.resumed = true
	pendingQueries[queryId] = nil

	local payloadLen = buffer.len(receivedBuffer) - 4
	local payloadBuffer = buffer.create(payloadLen)
	buffer.copy(payloadBuffer, 0, receivedBuffer, 4, payloadLen)

	local decoded = read(payloadBuffer, ref, nil, "query")
	task.spawn(pending.thread, decoded)
end

-- Shared with: src/process/server.luau, src/process/read.luau (Infeasible to split this into another file)
local function create()
	return {
		cursor = 0,
		size = 256,
		references = {},
		buff = buffer.create(256),
	}
end

local function dump(channel: types.channelData): (buffer, { unknown }?)
	local cursor = channel.cursor
	local dumpBuffer = buffer.create(cursor)

	buffer.copy(dumpBuffer, 0, channel.buff, 0, cursor)

	return dumpBuffer, if #channel.references > 0 then channel.references else nil
end
-- No longer shared

local reliable: types.channelData = create()
local unreliable: types.channelData = create()

local queryRequestRemote: RemoteEvent

local clientProcess = {}

function clientProcess.setQueryTimeout(seconds: number)
	if typeof(seconds) == "number" and seconds > 0 then
		QUERY_TIMEOUT_SECONDS = seconds
	end
end

function clientProcess.getQueryTimeout(): number
	return QUERY_TIMEOUT_SECONDS
end

function clientProcess.sendReliable(id: number, writer: (value: any) -> (), data: { [string]: any })
	reliable = load(reliable)

	alloc(1)
	u8(id)
	writer(data)

	reliable = bufferWriter.export()
end

function clientProcess.sendUnreliable(id: number, writer: (value: any) -> (), data: { [string]: any })
	unreliable = load(unreliable)

	alloc(1)
	u8(id)
	writer(data)

	unreliable = bufferWriter.export()
end

function clientProcess.invoke(id: number, requestWriter: (value: any) -> (), data: {[string]: any}): any
	if not queryRequestRemote then
		queryRequestRemote = ReplicatedStorage:WaitForChild("ByteNetQueryReliable") :: RemoteEvent
	end

	local func = create()
	func = load(func)

	alloc(1)
	u8(id)
	requestWriter(data)

	func = bufferWriter.export()

	local queryId: number
	repeat
		queryId = nextQueryId
		nextQueryId += 1
		if nextQueryId >= 4294967295 then
			nextQueryId = 1
		end
	until pendingQueries[queryId] == nil

	local bodyBuffer, references = dump(func)
	local bodyLen = buffer.len(bodyBuffer)
	local framed = buffer.create(4 + bodyLen)
	buffer.writeu32(framed, 0, queryId)
	buffer.copy(framed, 4, bodyBuffer, 0, bodyLen)

	local runningThread = coroutine.running()

	local entry = {
		thread = runningThread,
		timeoutToken = nil :: any,
		resumed = false,
	}

	pendingQueries[queryId] = entry

	entry.timeoutToken = task.delay(QUERY_TIMEOUT_SECONDS, function()
		local pending = pendingQueries[queryId]
		if not pending or pending.resumed then
			return
		end
		pending.resumed = true
		pendingQueries[queryId] = nil
		warn(string.format("[ByteNet] query id %d timed out after %.2fs", queryId, QUERY_TIMEOUT_SECONDS))
		task.spawn(pending.thread, nil)
	end)

	queryRequestRemote:FireServer(framed, references)

	return coroutine.yield()
end

function clientProcess.start()
	local reliableRemote = ReplicatedStorage:WaitForChild("ByteNetReliable")
	reliableRemote.OnClientEvent:Connect(onClientEvent)

	local unreliableRemote = ReplicatedStorage:WaitForChild("ByteNetUnreliable")
	unreliableRemote.OnClientEvent:Connect(onClientEvent)

	queryRequestRemote = ReplicatedStorage:WaitForChild("ByteNetQueryReliable") :: RemoteEvent
	queryRequestRemote.OnClientEvent:Connect(onQueryResponse)

	RunService.Heartbeat:Connect(function()
		if reliable.cursor > 0 then
			local b, r = dump(reliable)
			reliableRemote:FireServer(b, r)

			reliable.cursor = 0
			table.clear(reliable.references)
		end

		if unreliable.cursor > 0 then
			local b, r = dump(unreliable)
			unreliableRemote:FireServer(b, r)

			unreliable.cursor = 0
			table.clear(unreliable.references)
		end
	end)
end

return clientProcess