local configFilename = "TacticalDisadvantage.json"
local DEBUG = false
local MODVERSION = "0.1.0"
local Cfg = {}

local defaultConfiguration = {
	info = {
		actions = "additional actions",
		bonus_actions = "additional bonus actions",
		defense = "AC: base + level*config",
		damage = "bonus damage: base + level*config",
		spell_slots = "spell slots by level: base + level*config",
		resources = "oath, divinity,rage ...: base + level*config",
		movement = "additional movement in meters: base + config",
		health = "additional maximum HP: base + level*config",
		stat_boost = "additional stats: base + level*config",
		roll_bonus = "attack roll bonus: base + level*config",
		spell_save_dc = "spell save DC bonus: base + level*config",
	},
	general = {
		bosses = true,
		enemies = true,
		allies = false,
	},
	bosses = {
		actions = 0.5,
		bonus_actions = 2,
		defense = 0.8,
		damage = 0.7,
		spell_slots = 2,
		resources = 1,
		movement = 0,
		health = 12,
		stat_boost = 0.2,
		roll_bonus = 0.2,
		spell_save_dc = 0.2,
	},
	enemies = {
		actions = 0,
		bonus_actions = 0.4,
		defense = 0.5,
		damage = 1,
		spell_slots = 2,
		resources = 1,
		movement = 0,
		health = 2,
		stat_boost = 0.2,
		roll_bonus = 0,
		spell_save_dc = 0,
	},
	allies = {
		actions = 0.2,
		bonus_actions = 0.3,
		defense = 0.2,
		damage = 0.2,
		spell_slots = 2,
		resources = 1,
		movement = 0,
		health = 5,
		stat_boost = 0.2,
		roll_bonus = 0.2,
		spell_save_dc = 0.2,
	},
}

local ExcludedNPCs = {
	"S_Player_Karlach_2c76687d-93a2-477b-8b18-8a14b549304c",
	"S_Player_Minsc_0de603c5-42e2-4811-9dad-f652de080eba",
	"S_GOB_DrowCommander_25721313-0c15-4935-8176-9f134385451b",
	"S_GLO_Halsin_7628bc0e-52b8-42a7-856a-13a6fd413323",
	"S_Player_Jaheira_91b6b200-7d00-4d62-8dc9-99e8339dfa1a",
	"S_Player_Gale_ad9af97d-75da-406a-ae13-7071c563f604",
	"S_Player_Astarion_c7c13742-bacd-460a-8f65-f864fe41f255",
	"S_Player_Laezel_58a69333-40bf-8358-1d17-fff240d7fb12",
	"S_Player_Wyll_c774d764-4a17-48dc-b470-32ace9ce447d",
	"S_Player_ShadowHeart_3ed74f06-3c60-42dc-83f6-f034cb47c679",
}

local function Unmarshal(buffer)
	local config = {}
	local section, key, value

	for line in buffer:match("([^\r\n]+)") do
		if l:match("^[[]") ~= nil then
			section = l:match("%[(%w+)")

			config[Section] = {}
		end

		if l:match("(.+)=") ~= nil then
			key, value = l:match("(%w+)%s*=%s*(%w+)")

			-- parse numbers
			if tonumber(value) ~= nil then
				value = tonumber(value)
			end

			if value:match("(true|false)") ~= nil then
				value = value == "true"
			end

			config[section][key] = value
		end
	end -- Lines Loop End

	return Config
end

local function Marshal(data)
	buffer = ""

	for key, val in ipairs(data) do
		if type(val) == "table" then
			buffer = buffer .. "\n[" .. key .. "]\n"
			buffer = buffer .. Marshal(val)
		else
			buffer = buffer .. key .. " = " .. tostring(val) .. "\n"
		end
	end

	return buffer .. "\n"
end

local function log(...)
	if DEBUG then
		_P(...)
	end
end

local function loadConfig()
	local data = Ext.IO.LoadFile(configFilename)
	if data ~= nil then
		data = Ext.Json.Parse(data)
	else
		data = defaultConfiguration
	end

	-- sync saved config with latest default configuration
	for section,tbl in ipairs(defaultConfiguration) do
		if data[section] == nil then
			data[section] = tbl
		else
			for key,val in ipairs(tbl) do
				if data[section][key] == nil then
					data[section][key] = defaultConfiguration[section][key]
				end
			end
		end
	end

	return data
end

local function saveConfig()
	local data = Ext.Json.Stringify(Cfg, {
		Beautify = true,
		MaxDepth = 4,
	})
	return Ext.IO.SaveFile(configFilename, data)
end

local function IsOrigin(guid)
	for i = #ExcludedNPCs, 1, -1 do
		if ExcludedNPCs[i] == guid then
			return true
		end
	end
	return false
end

local function IsAlly(guid)
	if IsBoss(guid) or IsEnemy(guid, GetHostCharacter()) or IsParty(guid) or IsOrigin(guid) then
		return false
	end
	return true
end

local function OnEnteredCombat(guid, combatid)
	local config
	local l = GetLevel(guid)
	if l == nil then
		return
	end -- object or contraption

	-- already boosted
	if HasAppliedStatus(guid, "TACTICALDISADVANTAGE") ~= 0 then
		_P("has status ".. guid .. "\n")
		return
	elseif (IsPartyMember(guid, 0) == 1) and (IsEnemy(guid, GetHostCharacter()) == 0) then
		-- party or origin
		_P("is party member ".. guid .. "\n")
		return
	end

	if IsEnemy(guid, GetHostCharacter()) == 1 then
		-- non-boss enemy
		if (IsBoss(guid) == 0) and Cfg.general.enemies then
			_P("is enemy ".. guid .. "\n")
			config = Cfg.enemies
		end

		-- boss
		if (IsBoss(guid) ~= 0) and Cfg.general.bosses then
			log("is boss ".. guid .. "\n")
			config = Cfg.bosses
		end
	elseif Cfg.general.allies then
		log("is ally ".. guid .. "\n")
		config = Cfg.allies
	else
		log("not an enemy or boosted ally ".. guid .. "\n")
		return
	end

	log("OnEnteredCombat: " .. guid .. " combat id:".. combatid .. "\n")

	-- stats multiplier
	-- floor(level * cfg.stats)
	if config.stat_boost > 0 then
		local inc = math.floor(l * config.stat_boost)

		local stats = { "Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma" }
		for _, stat in ipairs(stats) do
			Osi.AddBoosts(guid, "Ability(" .. stat .. ",+" .. tostring(inc) .. ")", "", "")
		end
	end

	-- health multiplier
	-- ceil(level * cfg.health)
	if config.health > 0 then
		local inc = math.ceil(l * config.health)

		Osi.AddBoosts(guid, "IncreaseMaxHP(" .. tostring(inc) .. ")", "", "")
	end

	-- Spell slots
	-- ceil(level * cfg.spell_slots)
	if config.spell_slots > 0 then
		local inc = math.ceil(l * config.spell_slots)
		for i = 6, 1, -1 do
			Osi.AddBoosts(
				guid,
				"ActionResource(SpellSlot," .. tostring(config.spell_slots) .. "," .. tostring(i) .. ")", "", ""
			)
		end
	end

	-- Flat Damage bonus
	-- ceil(level * cfg.damage)
	if config.damage > 0 then
		local inc = math.ceil(l * config.damage)
		Osi.AddBoosts(guid, "DamageBonus(" .. tostring(inc) .. ")", "", "")
	end

	-- Flat attack roll bonus
	-- ceil(level * cfg.roll_bonus)
	if config.roll_bonus > 0 then
		local inc = math.ceil(l * config.roll_bonus)

		Osi.AddBoosts(guid, "RollBonus(" .. tostring(inc) .. ")", "", "")
	end

	-- Flat spell save dc
	-- ceil(level * cfg.spell_save_dc)
	if config.spell_save_dc > 0 then
		local inc = math.ceil(l * config.spell_save_dc)
		Osi.AddBoosts(guid, "SpellSaveDC(" .. tostring(inc) .. ")", "", "")
	end

	-- Flat AC
	-- ceil(level * cfg.defense)
	if config.defense > 0 then
		local inc = math.ceil(l * config.defense)
		Osi.AddBoosts(guid, "AC(" .. tostring(inc) .. ")", "", "")
	end

	-- Flat increase in the number of Actions
	-- cfg.actions
	if config.actions > 0 then
		local inc = config.actions
		Osi.AddBoosts(guid, "ActionResource(ActionPoint," .. tostring(inc) .. ",0)", "", "")

		resources = {
			"ChannelDivinity",
			"ChannelOath",
			"KiPoint",
			"LayOnHandsCharge",
			"Rage",
			"SorceryPoint",
			"SuperiorityDie",
			"WildShape",
		}
		for _, resource in ipairs(resources) do
			Osi.AddBoosts(guid, "ActionResource(" .. resource .. "," .. tostring(config.resouces) .. ",0)", "", "")
		end
	end

	-- bonus actions
	-- cfg
	if config.bonus_actions > 0 then
		local inc = config.actions
		Osi.AddBoosts(guid, "ActionResource(BonusActionPoint," .. tostring(inc) .. ",0)", "", "")
	end

	-- movement
	-- cfg
	if config.movement > 0 then
		Osi.AddBoosts(guid, "ActionResource(Movement," .. tostring(config.movement) .. ")", "", "")
	end

	log(guid .. " boosted!\n")

	Osi.ApplyStatus(guid, "TACTICALDISADVANTAGE", -1)
end

local function OnCombatEnded(combat)
	log("OnCombatEnded:" .. combat)
end

local function OnSessionLoaded()
	_P("Tactical Disadvantage - ".. MODVERSION)

	Cfg = loadConfig()
	saveConfig(Cfg)

	Ext.Osiris.RegisterListener("CombatEnded", 1, "after", OnCombatEnded)
	Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", OnEnteredCombat)
end
Ext.Events.SessionLoaded:Subscribe(OnSessionLoaded)
