local Config = require("./Config")
local StatusService = require("../../Character/StatusService")

export type Side = {
	Status: string?,
	Part: string?,
}

local Walk = {}

function Walk.Begin(walker: Model, carried: Model, walk: Side, walkerAnchor: CFrame, carriedAnchor: CFrame): boolean
	local part = walker:FindFirstChild(walk.Part or Config.WalkPart)
	if not part or not part:IsA("BasePart") then return false end

	carried:SetAttribute(Config.FollowAttribute, part.Name)
	carried:SetAttribute(Config.FollowOffsetAttribute, walkerAnchor:ToObjectSpace(carriedAnchor))
	walker:SetAttribute(Config.AnchorAttribute, nil)

	StatusService:RemoveStatus(walker, Config.Status)

	if walk.Status then
		StatusService:SetStatus(walker, walk.Status, true)
	end

	return true
end

function Walk.Stop(walker: Model, held: Model, walk: Side?, walkerFrame: CFrame, heldFrame: CFrame?)
	walker:SetAttribute(Config.AnchorAttribute, walkerFrame)

	if heldFrame then
		held:SetAttribute(Config.AnchorAttribute, heldFrame)
	end

	Walk.End(walker, walk)
	StatusService:SetStatus(walker, Config.Status, true)
end

function Walk.End(walker: Model, walk: Side?)
	if walk and walk.Status then
		StatusService:RemoveStatus(walker, walk.Status)
	end
end

return Walk
