-- Pose record: u16 rig id, u8 flags, f64 server-time stamp, f32x3 root position, root rotation,
-- u8 joint count, one rotation per joint (rig order: Root first, then by name).
-- A rotation is smallest-three: u8 index of the dropped component + 3 x i16.

local Codec = {}

Codec.RAGDOLLED = 1
Codec.FINAL = 2

local SCALE = 32767 / 0.70710679

local QUAT_BYTES = 7
local HEADER_BYTES = 2 + 1 + 8 + 12 + QUAT_BYTES + 1

function Codec.recordSize(jointCount: number): number
	return HEADER_BYTES + jointCount * QUAT_BYTES
end

local function toQuat(cf: CFrame): (number, number, number, number)
	local axis, angle = cf:ToAxisAngle()
	local h = angle * 0.5
	local s = math.sin(h)
	return math.cos(h), axis.X * s, axis.Y * s, axis.Z * s
end

local function writeQuat(b: buffer, o: number, cf: CFrame): number
	local w, x, y, z = toQuat(cf)
	local q = { w, x, y, z }
	local big, bigAbs = 1, math.abs(w)
	for i = 2, 4 do
		local a = math.abs(q[i])
		if a > bigAbs then
			big, bigAbs = i, a
		end
	end
	local sign = if q[big] < 0 then -1 else 1
	buffer.writeu8(b, o, big - 1)
	o += 1
	for i = 1, 4 do
		if i ~= big then
			buffer.writei16(b, o, math.clamp(math.round(q[i] * sign * SCALE), -32767, 32767))
			o += 2
		end
	end
	return o
end

local function readQuat(b: buffer, o: number): (CFrame, number)
	local big = buffer.readu8(b, o) + 1
	o += 1
	local q = { 0, 0, 0, 0 }
	local sum = 0
	for i = 1, 4 do
		if i ~= big then
			local v = buffer.readi16(b, o) / SCALE
			o += 2
			q[i] = v
			sum += v * v
		end
	end
	q[big] = math.sqrt(math.max(0, 1 - sum))
	return CFrame.new(0, 0, 0, q[2], q[3], q[4], q[1]), o
end

-- rotations[i] are CFrames; only their rotation is encoded.
function Codec.write(b: buffer, o: number, id: number, flags: number, stamp: number, root: CFrame, rotations: { CFrame }): number
	buffer.writeu16(b, o, id)
	buffer.writeu8(b, o + 2, flags)
	buffer.writef64(b, o + 3, stamp)
	local p = root.Position
	buffer.writef32(b, o + 11, p.X)
	buffer.writef32(b, o + 15, p.Y)
	buffer.writef32(b, o + 19, p.Z)
	o = writeQuat(b, o + 23, root)
	buffer.writeu8(b, o, #rotations)
	o += 1
	for _, cf in rotations do
		o = writeQuat(b, o, cf)
	end
	return o
end

function Codec.peek(b: buffer, o: number): (number, number, number)
	-- id, flags, recordSize
	local id = buffer.readu16(b, o)
	local flags = buffer.readu8(b, o + 2)
	local count = buffer.readu8(b, o + HEADER_BYTES - 1)
	return id, flags, Codec.recordSize(count)
end

function Codec.read(b: buffer, o: number)
	local id = buffer.readu16(b, o)
	local flags = buffer.readu8(b, o + 2)
	local stamp = buffer.readf64(b, o + 3)
	local pos = Vector3.new(buffer.readf32(b, o + 11), buffer.readf32(b, o + 15), buffer.readf32(b, o + 19))
	local rot
	rot, o = readQuat(b, o + 23)
	local count = buffer.readu8(b, o)
	o += 1
	local rotations = table.create(count)
	for i = 1, count do
		rotations[i], o = readQuat(b, o)
	end
	return {
		id = id,
		flags = flags,
		t = stamp,
		root = CFrame.new(pos) * rot,
		rotations = rotations,
	}, o
end

-- Splits records into packets no larger than `limit` bytes. Each record is a buffer.
function Codec.pack(records: { buffer }, limit: number): { buffer }
	local packets = {}
	local batch, size = {}, 0
	local function flush()
		if #batch == 0 then
			return
		end
		local b = buffer.create(size)
		local o = 0
		for _, r in batch do
			buffer.copy(b, o, r)
			o += buffer.len(r)
		end
		table.insert(packets, b)
		batch, size = {}, 0
	end
	for _, r in records do
		local len = buffer.len(r)
		if size + len > limit then
			flush()
		end
		table.insert(batch, r)
		size += len
	end
	flush()
	return packets
end

return Codec
