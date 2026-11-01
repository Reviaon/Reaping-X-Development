local Fusion = require("@game/ReplicatedStorage/Utilities/Fusion")

local OnEvent, peek = Fusion.OnEvent, Fusion.peek

local Indicator = {}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Indicator.new(template: GuiObject, board: Instance, data, profile, onPress: () -> ())
	local style = profile.Style
	local scope = Fusion.scoped(Fusion)

	local bubble = template:Clone()
	table.insert(scope, bubble)

	local backdrop = bubble:FindFirstChild("Backdrop") :: Frame
	local approachRing = bubble:FindFirstChild("Approach") :: Frame
	local target = bubble:FindFirstChild("Target") :: Frame
	local core = bubble:FindFirstChild("Core") :: Frame
	local key = core and core:FindFirstChild("Key") :: TextLabel
	local approachStroke = approachRing:FindFirstChildOfClass("UIStroke")
	local targetStroke = target:FindFirstChildOfClass("UIStroke")
	local sheenGradient = targetStroke and targetStroke:FindFirstChildOfClass("UIGradient")
	local bubbleScale = bubble:FindFirstChildOfClass("UIScale")

	if not bubbleScale then
		bubbleScale = Instance.new("UIScale")
		bubbleScale.Parent = bubble
	end

	local base = {
		Color = targetStroke.Color,
		Thickness = targetStroke.Thickness,
		Transparency = targetStroke.Transparency,
		Core = core.BackgroundColor3,
		CoreTransparency = core.BackgroundTransparency,
		Backdrop = backdrop and backdrop.BackgroundTransparency or 1,
		KeyColor = key.TextColor3,
	}

	local approach = scope:Value(0)
	local phase = scope:Value("Idle")
	local fade = scope:Value(0)
	local sheen = scope:Value(0)
	local scale = scope:Value(style.SpawnScale)
	local jitter = scope:Value(0)

	local fading = scope:Tween(fade, TweenInfo.new(style.FadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	local scaling = scope:Spring(scale, style.AppearSpeed, style.AppearDamping)
	local shaking = scope:Spring(jitter, style.MissJitterSpeed, style.MissJitterDamping)

	local tint = scope:Spring(scope:Computed(function(use)
		local current = use(phase)

		if current == "Ready" or current == "Hit" then return style.Accent end
		if current == "Miss" then return style.Miss end
		if current == "Expire" then return style.Expire end

		return base.Color
	end), style.ColourSpeed, 1)

	local function faded(use, resting: number): number
		return lerp(resting, 1, use(fading))
	end

	local origin = UDim2.fromScale(data.X, data.Y)

	scope:Hydrate(bubble) {
		Name = `Bubble{data.Id}`,
		Visible = true,
		Position = scope:Computed(function(use)
			return origin + UDim2.fromOffset(use(shaking), 0)
		end),
		Parent = board,

		[OnEvent "Activated"] = onPress,
	}

	scope:Hydrate(bubbleScale) { Scale = scaling }

	if backdrop then
		scope:Hydrate(backdrop) {
			BackgroundTransparency = scope:Computed(function(use)
				return faded(use, base.Backdrop)
			end),
		}
	end

	scope:Hydrate(approachRing) {
		Size = scope:Computed(function(use)
			local size = lerp(profile.StartScale, profile.EndScale, use(approach))
			return UDim2.fromScale(size, size)
		end),
	}

	if approachStroke then
		scope:Hydrate(approachStroke) {
			Color = tint,
			Transparency = scope:Computed(function(use)
				if use(phase) == "Hit" or use(phase) == "Miss" then return 1 end

				return faded(use, lerp(style.ApproachFade.Max, style.ApproachFade.Min, use(approach)))
			end),
		}
	end

	scope:Hydrate(targetStroke) {
		Color = tint,
		Thickness = scope:Computed(function(use)
			return if use(phase) == "Ready" then style.ReadyThickness else base.Thickness
		end),
		Transparency = scope:Computed(function(use)
			return faded(use, base.Transparency)
		end),
	}

	if sheenGradient then
		scope:Hydrate(sheenGradient) { Rotation = sheen }
	end

	scope:Hydrate(core) {
		BackgroundColor3 = scope:Computed(function(use)
			return if use(phase) == "Hit" then style.Accent else base.Core
		end),
		BackgroundTransparency = scope:Computed(function(use)
			return faded(use, base.CoreTransparency)
		end),
	}

	scope:Hydrate(key) {
		Text = data.Key,
		TextColor3 = scope:Computed(function(use)
			return if use(phase) == "Hit" then base.Core else base.KeyColor
		end),
		TextTransparency = scope:Computed(function(use)
			return faded(use, 0)
		end),
	}

	local handle = { Root = bubble, Phase = "Idle" }
	local cleaned = false

	local function cleanup()
		if cleaned then return end

		cleaned = true
		Fusion.doCleanup(scope)
	end

	local function finish(after: number)
		fade:set(1)
		task.delay(after, cleanup)
	end

	function handle.Update(alpha: number, dt: number)
		approach:set(math.clamp(alpha, 0, 1))
		sheen:set((peek(sheen) + style.SheenSpeed * dt) % 360)
	end

	function handle.Appear()
		scale:set(1)
	end

	function handle.Ready()
		if handle.Phase ~= "Idle" then return end

		handle.Phase = "Ready"
		phase:set("Ready")
	end

	function handle.Hit()
		handle.Phase = "Hit"
		phase:set("Hit")
		scale:set(style.BurstScale)
		finish(style.FadeTime)
	end

	function handle.Miss()
		handle.Phase = "Miss"
		phase:set("Miss")
		jitter:set(style.MissJitter)

		task.delay(style.MissHold / 4, function()
			jitter:set(0)
		end)

		task.delay(style.MissHold, function()
			finish(style.FadeTime)
		end)
	end

	function handle.Expire()
		handle.Phase = "Expire"
		phase:set("Expire")
		finish(style.FadeTime)
	end

	handle.Destroy = cleanup

	return handle
end

return Indicator
