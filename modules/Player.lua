--[[
	Copyright (C) 2006-2007 Nymbia
	Copyright (C) 2010 Hendrik "Nevcairiel" Leppkes < h.leppkes@gmail.com >

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program; if not, write to the Free Software Foundation, Inc.,
	51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
]]
local Quartz3 = LibStub("AceAddon-3.0"):GetAddon("Quartz3")
local L = LibStub("AceLocale-3.0"):GetLocale("Quartz3")
local Gratuity = AceLibrary("Gratuity-2.0")


local MODNAME = "Player"
local Player = Quartz3:NewModule(MODNAME)

----------------------------
-- Upvalues
-- GLOBALS: CastingBarFrame
local unpack = unpack
local getn = table.getn
local UnitChannelInfo = UnitChannelInfo
local playerClass
local db, getOptions, castBar
local ICON_ENGI = "Interface\\Icons\\Trade_Engineering"

local defaults = {
	profile = Quartz3:Merge(Quartz3.CastBarTemplate.defaults,
	{
		hideblizz = true,
		showticks = true,
		-- no interrupt is pointless for player, disable all options
		noInterruptBorderChange = false,
		noInterruptColorChange = false,
		noInterruptShield = false,
	})
}

do 
	local function setOpt(info, value)
		db[info[getn(info)]] = value
		Player:ApplySettings()
	end

	local options
	function getOptions()
		if not options then
			options = Player.Bar:CreateOptions()
			options.args.hideblizz = {
				type = "toggle",
				name = L["Disable Blizzard Cast Bar"],
				desc = L["Disable and hide the default UI's casting bar"],
				set = setOpt,
				order = 101,
			}
			options.args.showticks = {
				type = "toggle",
				name = L["Show channeling ticks"],
				desc = L["Show damage / mana ticks while channeling spells like Drain Life or Blizzard"],
				order = 102,
			}
			options.args.targetname = {
				type = "toggle",
				name = L["Show Target Name"],
				desc = L["Display target name of spellcasts after spell name"],
				disabled = function() return db.hidenametext end,
				order = 402,
			}
			options.args.noInterruptGroup = nil
		end
		return options
	end
end
local channelingTicks
function Player:OnInitialize()
	self.db = Quartz3.db:RegisterNamespace(MODNAME, defaults)
	db = self.db.profile

	self:SetEnabledState(Quartz3:GetModuleEnabled(MODNAME))
	Quartz3:RegisterModuleOptions(MODNAME, getOptions, L["Player"])

	self.Bar = Quartz3.CastBarTemplate:new(self, "player", MODNAME, L["Player"], db)
	castBar = self.Bar.Bar

	
end

local slots = {
	["Head"] = true,
	["Neck"] = true,
	["Shoulder"] = true,
	["Shirt"] = true,
	["Chest"] = true,
	["Waist"] = true,
	["Legs"] = true,
	["Feet"] = true,
	["Wrist"] = true,
	["Hands"] = true,
	["Finger0"] = true,
	["Finger1"] = true,
	["Trinket0"] = true,
	["Trinket1"] = true,
	["Back"] = true,
	["MainHand"] = true,
	["SecondaryHand"] = true,
	["Ranged"] = true,
	["Tabard"] = true,
}


-- local warlockHasteBuffs = {
-- 	[52614] = .05,  -- Ruination
-- 	[42027] = .05,  -- Sulfuron's Blaze
-- 	[57692] = .10,  -- Elune's Courage
-- 	[16322] = .03,  -- Juju Flurry
-- 	[45425] = .05,  -- Potion of Quickness
-- 	[51481] = .13,  -- Chastise (8sec)
-- 	[52658] = .13,  -- Chastise (12sec)
-- 	[51196] = -.25,  -- Curse of the Rift

-- 	-- Add more buffs here as needed
-- }

local talentIncrease ={
	["MAGE"] = {
		["arcane"] = {1, 15, 1.05},
	}
}

local function isTalentKnown(x,y,k)
	local _,_,_,_,tal = GetTalentInfo(x,y)
	return tal * k
end

function Player:OnEnable()
	self.Bar:RegisterEvents()
	self:ApplySettings()
	channelingTicks = {
		-- warlock
		[SpellInfo(1120)] = 6, -- drain soul
		[SpellInfo(689)] = 5, -- drain life
		[SpellInfo(5138)] = 5, -- drain mana
		[SpellInfo(5740)] = 4, -- rain of fire
		[SpellInfo(52552)] = 8, -- dark harvest
		[SpellInfo(11684)] = 15, -- Hellfire
		-- druid
		[SpellInfo(740)] = 4, -- Tranquility
		[SpellInfo(16914)] = 10, -- Hurricane
		-- priest
		[SpellInfo(15407)] = 3, -- mind flay
		--[SpellInfo(48045)] = 5, -- mind sear
		--[SpellInfo(47540)] = 2, -- penance
		-- mage
		[SpellInfo(5143)] = 5, -- arcane missiles
		[SpellInfo(10)] = 5, -- blizzard
		[SpellInfo(12051)] = 4, -- evocation
		[SpellInfo(52516)] = 5, -- Icicles (52500)
		-- hunter
		[SpellInfo(1510)] = 6, -- volley
		[SpellInfo(3662)] = 5, -- mend pet
	} 
	for s in pairs(slots) do
		slots[s] = GetInventorySlotInfo (s.."Slot")
	end
	local _
	_, playerClass = UnitClass("player")

end

function Player:OnDisable()
	self.Bar:UnregisterEvents()
	self.Bar:Hide()
end

function Player:ApplySettings()
	db = self.db.profile
	
	-- obey the hideblizz setting no matter if disabled or not
	if db.hideblizz then
		CastingBarFrame.RegisterEvent = function() end
		CastingBarFrame:UnregisterAllEvents()
		CastingBarFrame:Hide()
	else
		CastingBarFrame.RegisterEvent = nil
		CastingBarFrame:UnregisterAllEvents()
		CastingBarFrame:RegisterEvent("SPELLCAST_START")
		CastingBarFrame:RegisterEvent("SPELLCAST_STOP")
		CastingBarFrame:RegisterEvent("SPELLCAST_INTERRUPTED")
		CastingBarFrame:RegisterEvent("SPELLCAST_FAILED")
		CastingBarFrame:RegisterEvent("SPELLCAST_DELAYED")
		CastingBarFrame:RegisterEvent("SPELLCAST_CHANNEL_START")
		CastingBarFrame:RegisterEvent("SPELLCAST_CHANNEL_STOP")
	end
	
	self.Bar:SetConfig(db)
	if self:IsEnabled() then
		self.Bar:ApplySettings()
	end
end

function Player:Unlock()
	self.Bar:Unlock()
end

function Player:Lock()
	self.Bar:Lock()
end

----------------------------
-- Cast Bar Hooks

function Player:OnHide()
	local Latency = Quartz3:GetModule(L["Latency"],true)
	if Latency then
		if Latency:IsEnabled() and Latency.lagbox then
			Latency.lagbox:Hide()
			Latency.lagtext:Hide()
		end
	end
end

local sparkfactory = {
	__index = function(t,k)
		local spark = castBar:CreateTexture(nil, 'OVERLAY')
		t[k] = spark
		spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
		spark:SetVertexColor(unpack(Quartz3.db.profile.sparkcolor))
		spark:SetBlendMode('ADD')
		spark:SetWidth(20)
		spark:SetHeight(db.h*2.2)
		return spark
	end
}
local barticks = setmetatable({}, sparkfactory)

local function setBarTicks(ticknum)
	if( ticknum and ticknum > 0) then
		local delta = ( castBar:GetWidth() / ticknum )
		for k = 0,ticknum-1 do
			local t = barticks[k]
			t:ClearAllPoints()
			t:SetPoint("CENTER", castBar, "LEFT", delta * k, 0 )
			t:Show()
		end
		for k = ticknum,getn(barticks) do
			barticks[k]:Hide()
		end
	else
		barticks[1].Hide = nil
		for i=1,getn(barticks) do
			barticks[i]:Hide()
		end
	end
end

local function getPlayerModDuration()
	local modCastSpeed = GetUnitField("player", "modCastSpeed")
	-- modCastSpeed: 1.0 = normal, 0.9 = 10% faster, 1.1 = 10% slower
	-- Convert to haste multiplier: 1 + h where h is % haste in decimals
	-- If 0.9 (10% faster), we want 1.1 to divide by
	return modCastSpeed
end

local function getHasteFromItems(unit)
	local haste = 1
	for slot, id in pairs(slots) do
		local link = GetInventoryItemLink(unit, id)
		if link then
			local _, _, link = string.find(link, "|c%x+|H(item:%d+:%d+:%d+:%d+)|h%[.-%]|h|r")
			Gratuity:SetHyperlink(link)
  		local found, _, h = Gratuity:Find("Increases your attack and casting speed by (%d+)%%.",5,20,false,true,false)	
			if found then
				haste = haste + (tonumber(h) or 0) / 100
				--print(slot,h)
			end
			local found, _, h = Gratuity:Find("%+(%d+)%% Haste",5,20,false,true,false)
			if found then
				haste = haste + (tonumber(h) or 0) / 100
				--print(slot,h)
			end
		end
	end
	return haste
end



local function getMageHasteMultiplier()
	-- Mage: Accelerated Arcana (tree 1, position 15, 1 point, 5% reduction)
	if playerClass == "MAGE" then
		local tal = isTalentKnown(1, 15, 0.95)
		if tal > 0 then
			return tal
		end
	end
	return 1
end

local function getWarlockRapidDeterioration()
	-- Warlock: Rapid Deterioration (tree 1, position 14, 2 points, 50/100% efficiency)
	if playerClass == "WARLOCK" then
		local tal = isTalentKnown(1, 14, 1)
		return tal
	end
	return 0
end

local function checkPlayerBuff(spellId)
	for i = 1, 100 do
		local _, _, id = UnitBuff("player", i)
		if spellId == id then
			return true
		end
	end
end

local function getActiveHasteBuff()
	local totalHasteMult = 1
	for buffId, hasteMultiplier in pairs(warlockHasteBuffs) do
		if checkPlayerBuff(buffId) then
			totalHasteMult = totalHasteMult+hasteMultiplier
		end
	end
	return totalHasteMult
end

local function checkItemInSlot(item, slot)
	if not item or not slot then  return false end
	local link = GetInventoryItemLink("player", GetInventorySlotInfo(slot.."Slot"))
	local _, _, itemId = string.find(link, "|c%x+|Hitem:(%d+):(%d+):(%d+):(%d+)|h%[.-%]|h|r")
	return tonumber(itemId) == item
end

local function getChannelingTicks(spell)
	if not db.showticks then
		return 0
	end
	if spell == SpellInfo(5143) and checkItemInSlot( 47104, "Waist") then  -- Arcane Missiles -- t3 waist arcane missiles
		return 6
	end
	return channelingTicks[spell] or 0
end

local function roundUpTo(num, precision)
	return math.ceil(num / precision) * precision
end

local function roundDownTo(num,precision)
	return math.floor(num / precision) * precision
end

function round(num, decimals)
  local mult = 10 ^ decimals
  return math.floor(num * mult + 0.5) / mult
end

function Player:UNIT_SPELLCAST_START(bar, unit, spell)
	if spell.id == 22810 then 
		self.Bar.Text:SetText("Opening...")
		self.Bar.Icon:SetTexture(ICON_ENGI)
	end
	if bar.channeling then
		local spell = SpellInfo(spell.id)
		bar.channelingTicks = getChannelingTicks(spell)
		setBarTicks(bar.channelingTicks)
		local duration = self.Bar.endTime - self.Bar.startTime
		local mod_duration = 1
		local warlockReduction = 0.94
		local mageReduction = getMageHasteMultiplier()
		if mageReduction < 1 then
			mod_duration = mod_duration * getPlayerModDuration() 
		end
		
		-- Apply Warlock Rapid Deterioration talent (50/100% efficiency on channeled spells)
		local warlockRD = getWarlockRapidDeterioration()
		if warlockRD > 0 then
			local efficiency = warlockRD * 0.5 
			mod_duration = mod_duration * getPlayerModDuration()  * efficiency
			-- haste = math.floor((haste-1)*100)/100 +1

		end
		
		if spell == SpellInfo(52516) and checkPlayerBuff(52500) then -- Flash Freeze
			duration = duration * 0.2
		elseif spell == SpellInfo(5143) then
			if checkItemInSlot(47104, "Waist") then
				duration = duration + 1
			end
		end
		
		if spell == SpellInfo(11684) then -- Hellfire
			duration = 15
		elseif warlockRD > 0 then 
			self.Bar.endTime = self.Bar.startTime + duration * round(mod_duration* warlockReduction,2)
		elseif mageReduction < 1 then
			self.Bar.endTime = self.Bar.startTime + duration * round(mod_duration* mageReduction,2)
		end
	else
		setBarTicks(0)
	end
end

function Player:UNIT_SPELLCAST_STOP(bar, unit, spellId)
	setBarTicks(0)
end

function Player:UNIT_SPELLCAST_FAILED(bar, unit, spellId)
	setBarTicks(0)
end

function Player:UNIT_SPELLCAST_INTERRUPTED(bar, unit)
	setBarTicks(0)
end

function Player:UNIT_SPELLCAST_DELAYED(bar, unit, d)

end
function Player:UNIT_SPELLCAST_CHANNEL_UPDATE(bar, unit, d)

end