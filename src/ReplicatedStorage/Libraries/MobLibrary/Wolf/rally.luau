--[[@
	**Rally**: screeches once per life when badly hurt, then flees
	- **Screech:** alerts and aggroes every wolf in `radius`; nearby players get a shake and FOV pulse between two markers
	- **Flee:** runs ahead for `duration`, then heads home
]]
return {
	health = 0.3, --@ Share of max health it screeches at
	animation = "Screech",
	at = 132 / 60, --@ Seconds into the screech wolves are alerted
	radius = 250, --@ Studs heard from
	visual = "Screech", --@ WolfVisuals timeline

	shake = {
		visual = "ScreechShake",
		from = "Begin", --@ Marker
		to = "End", --@ Marker
	},

	flee = {
		duration = 4, --@ Seconds before heading home
		speed = "run_speed",
		distance = 30, --@ Studs ahead it aims
	},
}
