-- Rewards requested by the VocoCraft Android client after Yandex rewarded ads.
--
-- The command is deliberately limited to true singleplayer. Multiplayer and
-- hosted servers must never accept a client-originated health/food grant.

local function grant_health(player)
	local properties = player:get_properties()
	local hp_max = properties and properties.hp_max or 20
	player:set_hp(hp_max, {
		type = "set_hp",
		other = "vococraft_rewarded_ad",
	})
end

local function grant_food(player)
	mcl_hunger.set_hunger(player, 20, true)
	mcl_hunger.set_saturation(player, 20, true)
	mcl_hunger.set_exhaustion(player, 0, true)
end

core.register_chatcommand("__vococraft_reward", {
	params = "<health|food>",
	description = "",
	func = function(name, param)
		if not core.is_singleplayer() then
			core.log("warning",
				"[vococraft_rewarded_ads] Rejected non-singleplayer reward request")
			return false
		end

		local player = core.get_player_by_name(name)
		if not player then
			return false
		end

		if param == "health" then
			grant_health(player)
		elseif param == "food" then
			grant_food(player)
		else
			return false
		end

		core.log("action",
			"[vococraft_rewarded_ads] Granted " .. param .. " reward to " .. name)
		return true
	end,
})
