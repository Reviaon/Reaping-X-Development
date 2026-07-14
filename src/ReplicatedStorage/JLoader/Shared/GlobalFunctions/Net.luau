--@ Net — ByteNet-backed networking router for the JLoader framework.

--[[
	Events -> one reliable ByteNet packet   carrying { channel, payload }
	RPC    -> one ByteNet query              carrying { channel, payload } -> response

	`payload` is table.pack(...) of the fired / invoked varargs, shipped as
	ByteNet `unknown` (passed by reference), so arbitrary tables and Instances
	survive the trip. Each fire / invoke uses exactly ONE reference (the packed
	table), keeping us far below ByteNet's 255-references-per-Heartbeat ceiling.

	Behavioural note: ByteNet flushes once per Heartbeat, so sends are delivered
	on the next frame rather than immediately (unlike a raw RemoteEvent).

	Server API:  Net.fireTo / fireAll / fireExcept / fireList / onEvent / onRpc
	Client API:  Net.fireServer / onEvent / invoke
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ByteNet = require(ReplicatedStorage:WaitForChild("Libraries"):WaitForChild("ByteNet"))

local IS_SERVER = RunService:IsServer()
local NAMESPACE_NAME = "JLoaderNet"

--@ On the client the namespace layout replicates from the server as a
--@  StringValue under ReplicatedStorage.BytenetStorage. ByteNet resolves it with
--@  FindFirstChild (no wait) and JSON-decodes it immediately, so we must block
--@  until it exists AND is populated before defining the namespace.
if not IS_SERVER then
	local storage = ReplicatedStorage:WaitForChild("BytenetStorage")
	local nsValue = storage:WaitForChild(NAMESPACE_NAME)
	while nsValue.Value == "" do
		nsValue.Changed:Wait()
	end
end

local Namespace = ByteNet.defineNamespace(NAMESPACE_NAME, function()
	return {
		packets = {
			event = ByteNet.definePacket({
				value = ByteNet.struct({
					channel = ByteNet.string,
					payload = ByteNet.unknown,
				}),
			}),
		},
		queries = {
			rpc = ByteNet.defineQuery({
				request = ByteNet.struct({
					channel = ByteNet.string,
					payload = ByteNet.unknown,
				}),
				response = ByteNet.unknown,
			}),
		},
	}
end)

local eventPacket = Namespace.packets.event
local rpcQuery = Namespace.queries.rpc

--@ channel -> map of connection token -> event handler (token-keyed so the same
--  function can be connected multiple times, each with an independent disconnect)
local eventHandlers: { [string]: { [any]: (...any) -> () } } = {}
--@ channel -> single RPC handler
local rpcHandlers: { [string]: (player: Player?, ...any) -> ...any } = {}

--@ Events received for a channel before any handler is registered are buffered
--  here (bounded) and flushed on registration, mirroring the queue-until-listener
--  behaviour of raw RemoteEvents so first-join server->client events aren't lost.
local pendingEvents: { [string]: { { payload: any, player: Player? } } } = {}
local MAX_PENDING_PER_CHANNEL = 32

local function unpackPayload(packed)
	if typeof(packed) ~= "table" then
		return
	end
	return table.unpack(packed, 1, packed.n or #packed)
end

local Net = {}

--=============================== EVENTS ===============================--

--@ Deliver a table.pack payload to one handler with the correct arg shape.
local function invokeHandler(handler, player, packed)
	if IS_SERVER then
		task.spawn(handler, player, table.unpack(packed, 1, packed.n or #packed))
	else
		task.spawn(handler, table.unpack(packed, 1, packed.n or #packed))
	end
end

--@ Fan an incoming event out to every handler registered on its channel.
--  On the server `player` is the sender; on the client it is nil.
local function dispatchEvent(data, player)
	if typeof(data) ~= "table" then
		return
	end

	local packed = data.payload
	if typeof(packed) ~= "table" then
		return
	end

	local handlers = eventHandlers[data.channel]
	if not handlers then
		--@ No listener yet (e.g. a first-join event arriving before its handler
		--  registers): buffer it, bounded, to flush when a handler connects.
		local queue = pendingEvents[data.channel]
		if not queue then
			queue = {}
			pendingEvents[data.channel] = queue
		end
		if #queue < MAX_PENDING_PER_CHANNEL then
			table.insert(queue, { payload = packed, player = player })
		end
		return
	end

	for _, handler in handlers do
		invokeHandler(handler, player, packed)
	end
end

eventPacket.listen(dispatchEvent)

--@ Register a handler for `channel`. Returns a connection with :Disconnect().
--  Server handlers receive (player, ...); client handlers receive (...).
function Net.onEvent(channel: string, handler: (...any) -> ())
	local set = eventHandlers[channel]
	if not set then
		set = {}
		eventHandlers[channel] = set
	end

	--@ Unique token per registration, so the same function can be connected
	--  more than once and each connection disconnects independently.
	local token = {}
	set[token] = handler

	--@ Flush any events that arrived on this channel before a handler existed.
	local queued = pendingEvents[channel]
	if queued then
		pendingEvents[channel] = nil
		for _, item in ipairs(queued) do
			invokeHandler(handler, item.player, item.payload)
		end
	end

	return {
		Disconnect = function()
			local s = eventHandlers[channel]
			if s then
				s[token] = nil
				if next(s) == nil then
					eventHandlers[channel] = nil
				end
			end
		end,
	}
end

if IS_SERVER then
	function Net.fireTo(channel: string, player: Player, ...)
		eventPacket.sendTo({ channel = channel, payload = table.pack(...) }, player)
	end

	function Net.fireAll(channel: string, ...)
		eventPacket.sendToAll({ channel = channel, payload = table.pack(...) })
	end

	function Net.fireExcept(channel: string, except, ...)
		--@ Accept a Player or its name string (preserves the pre-migration contract).
		if type(except) == "string" then
			except = Players:FindFirstChild(except)
		end
		eventPacket.sendToAllExcept({ channel = channel, payload = table.pack(...) }, except)
	end

	function Net.fireList(channel: string, players: { Player }, ...)
		eventPacket.sendToList({ channel = channel, payload = table.pack(...) }, players)
	end
else
	function Net.fireServer(channel: string, ...)
		eventPacket.send({ channel = channel, payload = table.pack(...) })
	end
end

--================================ RPC ================================--

if IS_SERVER then
	--@ A single query listener dispatches by channel and returns the packed
	--  result. Packing guarantees a non-nil response table even when the handler
	--  returns nil/false, which keeps the query layer from stalling.
	rpcQuery.listen(function(data, player)
		if typeof(data) ~= "table" then
			return table.pack(nil)
		end

		local handler = rpcHandlers[data.channel]
		if not handler then
			warn(string.format("[Net] No RPC handler registered for channel '%s'", tostring(data.channel)))
			return table.pack(nil)
		end

		return table.pack(handler(player, unpackPayload(data.payload)))
	end)

	--@ Register a server RPC handler: handler(player, ...) -> ...
	function Net.onRpc(channel: string, handler: (player: Player?, ...any) -> ...any)
		rpcHandlers[channel] = handler

		return {
			Disconnect = function()
				if rpcHandlers[channel] == handler then
					rpcHandlers[channel] = nil
				end
			end,
		}
	end
else
	--@ Invoke a server RPC channel and return its unpacked result(s). Yields
	--  until the response arrives (or the ByteNet query times out).
	function Net.invoke(channel: string, ...): ...any
		local response = rpcQuery.invoke({ channel = channel, payload = table.pack(...) })
		return unpackPayload(response)
	end
end

return Net
