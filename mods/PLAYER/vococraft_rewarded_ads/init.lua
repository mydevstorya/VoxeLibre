-- Rewards requested by the VocoCraft Android client after Yandex rewarded ads.
--
-- Commands are deliberately limited to true survival singleplayer.
-- Multiplayer, hosted servers and Creative must never accept these grants.

local CASE_COOLDOWN_SECONDS = 90
local SURVIVAL_HUD_NAME = "vococraft_survival_state"
local survival_hud_ids = {}

-- Keep indexes and stack strings in sync with CaseRewardManager.PRIZES.
local case_prizes = {
	[0] = {stack = "mcl_tools:pick_stone", weight = 1600},
	[1] = {stack = "mcl_torches:torch 24", weight = 1200},
	[2] = {stack = "mcl_core:coal_lump 16", weight = 900},
	[3] = {stack = "mcl_mobitems:cooked_beef 8", weight = 800},
	[4] = {stack = "mcl_core:iron_ingot 5", weight = 900},
	[5] = {stack = "mcl_tools:pick_iron", weight = 1200},
	[6] = {stack = "mcl_bows:bow", weight = 600},
	[7] = {stack = "mcl_core:apple_gold", weight = 700},
	[8] = {stack = "mcl_potions:healing", weight = 550},
	[9] = {stack = "mcl_potions:swiftness", weight = 450},
	[10] = {stack = "mcl_potions:fire_resistance", weight = 350},
	[11] = {stack = "mcl_core:diamond 2", weight = 300},
	[12] = {stack = "mcl_tools:pick_diamond", weight = 200},
	[13] = {stack = "mcl_armor:helmet_diamond", weight = 100},
	[14] = {stack = "mcl_armor:leggings_diamond", weight = 70},
	[15] = {stack = "mcl_armor:chestplate_diamond", weight = 50},
	[16] = {stack = "mcl_totems:totem", weight = 30},
}

local function is_survival(player)
	return mcl_gamemode.get_gamemode(player) == "survival"
end

local function publish_survival_state(player)
	local name = player:get_player_name()
	local number = is_survival(player) and 1 or 0
	local token = number == 1
		and "vococraft_survival_1" or "vococraft_survival_0"
	local hud_id = survival_hud_ids[name]
	if hud_id then
		player:hud_change(hud_id, "number", number)
		player:hud_change(hud_id, "text", token)
		return
	end

	survival_hud_ids[name] = player:hud_add({
		hud_elem_type = "text",
		name = SURVIVAL_HUD_NAME,
		position = {x = 0, y = 0},
		offset = {x = -10000, y = -10000},
		-- Keep text non-empty: empty text HUD elements may be elided before
		-- reaching the client even though their numeric field is meaningful.
		text = token,
		number = number,
		z_index = -400,
	})
end

core.register_on_joinplayer(function(player)
	core.after(0, publish_survival_state, player)
end)

core.register_on_leaveplayer(function(player)
	survival_hud_ids[player:get_player_name()] = nil
end)

mcl_gamemode.register_on_gamemode_change(function(player)
	publish_survival_state(player)
end)

core.register_on_mods_loaded(function()
	for _, player in ipairs(core.get_connected_players()) do
		publish_survival_state(player)
	end
end)

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
		if not is_survival(player) then
			core.log("warning",
				"[vococraft_rewarded_ads] Rejected Creative reward request")
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

core.register_chatcommand("__vococraft_case", {
	params = "<prize_index>",
	description = "",
	func = function(name, param)
		if not core.is_singleplayer() then
			core.log("warning",
				"[vococraft_rewarded_ads] Rejected non-singleplayer case request")
			return false
		end

		local player = core.get_player_by_name(name)
		if not player or not is_survival(player) then
			core.log("warning",
				"[vococraft_rewarded_ads] Rejected non-survival case request")
			return false
		end

		local prize_index = tonumber(param)
		if not prize_index or prize_index % 1 ~= 0 then
			return false
		end
		local prize = case_prizes[prize_index]
		if not prize then
			core.log("warning",
				"[vococraft_rewarded_ads] Rejected invalid case prize index")
			return false
		end

		local now = os.time()
		local meta = player:get_meta()
		local last_opened = meta:get_int("vococraft_case_last_opened")
		if last_opened > 0 and now >= last_opened
				and now - last_opened < CASE_COOLDOWN_SECONDS then
			core.log("warning",
				"[vococraft_rewarded_ads] Rejected case cooldown bypass")
			return false
		end
		meta:set_int("vococraft_case_last_opened", now)

		local stack = ItemStack(prize.stack)
		local definition = stack:get_definition()
		if not definition or not definition.description then
			core.log("error",
				"[vococraft_rewarded_ads] Case item is not registered: "
				.. stack:get_name())
			return false
		end

		local leftover = player:get_inventory():add_item("main", stack)
		if not leftover:is_empty() then
			core.add_item(player:get_pos(), leftover)
		end

		core.log("action",
			("[vococraft_rewarded_ads] Granted case prize %d (%s, weight=%d) to %s")
			:format(prize_index, prize.stack, prize.weight, name))
		return true
	end,
})
