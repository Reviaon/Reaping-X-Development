-- // @world constants
local constants = {}

-- @raycasting
constants.world_ray_params = RaycastParams.new()
constants.world_ray_params.FilterType = Enum.RaycastFilterType.Include
constants.world_ray_params.FilterDescendantsInstances = {workspace:WaitForChild("World"):WaitForChild("Map")}
constants.world_ray_params.IgnoreWater = true
constants.world_ray_params.RespectCanCollide = true

constants.world_overlap_params = OverlapParams.new()
constants.world_overlap_params.FilterType = Enum.RaycastFilterType.Include
constants.world_overlap_params.FilterDescendantsInstances = {workspace:WaitForChild("World"):WaitForChild("Map")}
constants.world_overlap_params.RespectCanCollide = true

constants.world_overlap_params_ncl = OverlapParams.new()
constants.world_overlap_params_ncl.FilterType = Enum.RaycastFilterType.Include
constants.world_overlap_params_ncl.FilterDescendantsInstances = {workspace:WaitForChild("World"):WaitForChild("Map")}
constants.world_overlap_params_ncl.RespectCanCollide = false

constants.live_ray_params = RaycastParams.new()
constants.live_ray_params.FilterType = Enum.RaycastFilterType.Include
constants.live_ray_params.FilterDescendantsInstances = {workspace:WaitForChild("World"):WaitForChild("Live")}
constants.live_ray_params.IgnoreWater = true
constants.live_ray_params.RespectCanCollide = true

constants.live_overlap_params = OverlapParams.new()
constants.live_overlap_params.FilterType = Enum.RaycastFilterType.Include
constants.live_overlap_params.FilterDescendantsInstances = {workspace:WaitForChild("World"):WaitForChild("Live")}
constants.live_overlap_params.RespectCanCollide = true

return constants
