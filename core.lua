--[[
Copyright (c) 2008 Chris Bannister,
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
3. The name of the author may not be used to endorse or promote products
   derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

local print = function(str) return ChatFrame3:AddMessage(tostring(str)) end
local printf = function(...) return ChatFrame3:AddMessage(string.format(...)) end
local _G = getfenv(0)
local oUF = _G.oUF

local libheal = LibStub("LibHealComm-3.0", true)

local UnitName = UnitName
local UnitClass = UnitClass
local select = select
local unpack = unpack
local UnitDebuff = UnitDebuff
local UnitInRaid = UnitInRaid

local width, height = 32, 32

local supernova = [[Interface\AddOns\oUF_Kanne_Grid\media\nokiafc22.ttf]]
local texture = [[Interface\AddOns\oUF_Kanne_Grid\media\gradient32x32.tga]]
local hightlight = [[Interface\AddOns\oUF_Kanne_Grid\media\mouseoverHighlight.tga]]

local PLAYERCLASS = select(2, UnitClass("player"))

if UnitName("player") == "Kanne" then
	PLAYERCLASS = "PALADIN"
end

local coloredFrame      -- Selected Raid Member

local colors = {
	class ={
		["DRUID"] = { 1.0 , 0.49, 0.04 },
		["HUNTER"] = { 0.67, 0.83, 0.45 },
		["MAGE"] = { 0.41, 0.8 , 0.94 },
		["PALADIN"] = { 0.96, 0.55, 0.73 },
		["PRIEST"] = { 1.0 , 1.0 , 1.0 },
		["ROGUE"] = { 1.0 , 0.96, 0.41 },
		["SHAMAN"] = { 0,0.86,0.73 },
		["WARLOCK"] = { 0.58, 0.51, 0.7 },
		["WARRIOR"] = { 0.78, 0.61, 0.43 },
	},
}
setmetatable(colors.class, {
	__index = function(self, key)
		return self.WARRIOR
	end
})

-- Debuff priority, with the same number = same mechanic, i gave wounder >
-- mortal beacuse wound is dispellable etc.

local debuffs = {
	["Viper Sting"] = 12,

	["Wound Poison"] = 9,
	["Mortal Strike"] = 8,
	["Aimed Shot"] = 8,

	["Counterspell - Silenced"] = 11,
	["Counterspell"] = 10,

	["Blind"] = 10,
	["Cyclone"] = 10,

	["Polymorph"] = 7,

	["Entangling Roots"] = 7,
	["Freezing Trap Effect"] = 7,

	["Crippling Poison"] = 6,
	["Hamstring"] = 5,
	["Wingclip"] = 5,

	["Fear"] = 3,
	["Psycic Scream"] = 3,
	["Howl of Terror"] = 3,
}

local dispellClass
do
	local t = {
		["PRIEST"] = {
			["Magic"] = true,
			["Disease"] = true,
		},
		["SHAMAN"] = {
			["Poision"] = true,
			["Disease"] = true,
		},
		["PALADIN"] = {
			["Poison"] = true,
			["Magic"] = true,
			["Disease"] = true,
		},
		["MAGE"] = {
			["Curse"] = true,
		},
		["DRUID"] = {
			["Curse"] = true,
			["Poison"] = true,
		},
	}
	if t[PLAYERCLASS] then
		dispellClass = {}
		for k, v in pairs(t[PLAYERCLASS]) do
			dispellClass[k] = v
		end
		t = nil
	end
end

local dispellPiority = {
	["Magic"] = 4,
	["Poison"] = 3,
	["Disease"] = 1,
	["Curse"] = 2,
}

local GetClassColor = function(unit)
	return unpack(colors.class[select(2, UnitClass(unit))])
end

local ColorGradient = function(perc, r1, g1, b1, r2, g2, b2, r3, g3, b3)
	if perc >= 1 then
		return {r3, g3, b3}
	elseif perc <= 0 then
		return {r1, g1, b1}
	end

	local segment, relperc = math.modf(perc*(3-1))
	local offset = (segment*3)+1

	if(offset == 1) then
		return {r1 + (r2-r1)*relperc, g1 + (g2-g1)*relperc, b1 + (b2-b1)*relperc}
	end

	return {r2 + (r3-r2)*relperc, g2 + (g3-g2)*relperc, b2 + (b3-b2)*relperc}
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, evnet, ...)
	return self[event](self, ...)
end)


local name, rank, buffTexture, count, duration, timeLeft, dtype
function f:UNIT_AURA(unit)
	if not oUF.units[unit] then return end

	local frame = oUF.units[unit]

	if not frame.Icon then return end
	local current, bTexture, dispell, dispellTexture
	for i = 1, 40 do
		name, rank, buffTexture, count, dtype, duration, timeLeft = UnitDebuff(unit, i)
		if not name then break end

		if dispellClass and dispellClass[dtype] then
			dispell = dispell or dtype
			dispellTexture = dispellTexture or buffTexture
			if dispellPiority[dtype] > dispellPiority[dispell] then
				dispell = dtype
				dispellTexture = buffTexture
			end
		end

		if debuffs[name] then
			current = current or name
			bTexture = bTexture or buffTexture

			local prio = debuffs[name]
			if prio > debuffs[current] then
				current = name
				bTexture = buffTexture
			end
		end
	end

	if dispellClass then
		if dispell then
			if dispellClass[dispell] then
				local col = DebuffTypeColor[dispell]
				frame.border:Show()
				frame.border:SetVertexColor(col.r, col.g, col.b)
				frame.Dispell = true
				if not bTexture and dispellTexture then
					current = dispell
					bTexture = dispellTexture
				end
			end
		else
			frame.border:SetVertexColor(1, 1, 1)
			frame.Dispell = false
			if coloredFrame then
				if unit ~= coloredFrame then
					frame.border:Hide()
				end
			else
				frame.border:Hide()
			end
		end
	end

	if current and bTexture then
		frame.Icon:SetTexture(bTexture)
		frame.Icon:ShowText()
		frame.DebuffTexture = true
	else
		frame.DebuffTexture = false
		frame.Icon:HideText()
	end
end


function f:PLAYER_TARGET_CHANGED()
	local id = UnitInRaid("target") and UnitInRaid("target") + 1 or UnitInParty("target") and UnitInParty("target")
	local frame = id and UnitInRaid("target") and oUF.units["raid" .. id] or id and UnitInParty("target") and oUF.units["party" .. id]
	if not frame then
		if coloredFrame then
			if not oUF.units[coloredFrame].Dispell then
				oUF.units[coloredFrame].border:Hide()
			end
			coloredFrame = nil
		end
		return
	end

	if coloredFrame and not oUF.units[coloredFrame].Dispell then
		oUF.units[coloredFrame].border:Hide()
	end

	if not frame.Dispell and frame.border then
		frame.border:SetVertexColor(1, 1, 1)
		frame.border:Show()
	end

	coloredFrame = UnitInRaid("target") and "raid" .. id or UnitInParty("target") and "party" .. id
end

local Roster = {}
local invRoster = {}

local UpdateRoster = function()
	for i = 1, 40 do
		local unit = "raid" .. i
		local e = UnitExists(unit)
		if e then
			local name, server = UnitName(unit)
			if server and server ~= "" then
				name = name .. "-" .. server
			end

			Roster[name] = unit
			invRoster[unit] = name
		else
			local n = invRoster[unit]
			if n then
				Roster[n] = nil
			end
			invRoster[unit] = nil
		end
	end
	for i = 1, 4 do
		local unit = "party" .. i
		local e = UnitExists(unit)
		if e then
			local name, server = UnitName(unit)
			Roster[name] = unit
			invRoster[unit] = name
		else
			local n = invRoster[unit]
			if n then
				Roster[n] = nil
			end
			invRoster[unit] = nil
		end
	end
end

if libheal then
	local HealInc = function(event, healerName, healSize, endTime, ...)
		print("event: ".. event)
		for i = 1, select("#", ...) do
			local name = tostring(select(i, ...))
			local unit = tostring(Roster[name])
			if not unit then return end
			printf("%s - %s", name, unit)
			local f = oUF.units[unit]

			local incHeal = select(2, libheal:UnitIncomingHealGet(name, GetTime()))
			--print(incHeal)
			if incHeal then
				local mod = libheal:UnitHealModifierGet(name)
				local val = (mod * incHeal) + UnitHealth(unit)
				f.heal:SetValue(val)
				f.heal:Show()
			else
				f.heal:Hide()
			end
		end
	end

	libheal.RegisterCallback("", "HealComm_DirectHealStop", HealInc)
	libheal.RegisterCallback("", "HealComm_DirectHealStart", HealInc)
end

local Name_Update = function(self, event, unit)
	if self.unit ~= unit then return end

	local n, s = UnitName(unit)
	self.name = string.sub(n, 1, 3)
	self.Health:SetStatusBarColor(GetClassColor(unit))
	self.Health.bg:SetVertexColor(GetClassColor(unit))

	if s and s ~= "" then
		n = n .. "-" ..s
	end

	Roster[unit] = n
	invRoster[n] = unit
end

local Health_Update = function(self, event, bar, unit, current, max)
	local def = max - current
	bar:SetValue(current)

	local per = math.floor(current/max*1000)/1000
	local col = ColorGradient(per, 1, 0, 0, 1, 1, 0, 1, 1, 1)
	self.Name:SetTextColor(unpack(col))

	if def < 900 or UnitIsDeadOrGhost(unit) then
		self.Name:SetText(self.name)
	else
		self.Name:SetFormattedText("-%0.1f",math.floor(def/100)/10)
	end

	if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then
		bar.bg:SetVertexColor(0.4, 0.4, 0.4)
	else
		bar.bg:SetVertexColor(GetClassColor(unit))
	end
end

local OnEnter = function(self)
	UnitFrame_OnEnter(self)
	self.Highlight:Show()
end

local OnLeave = function(self)
	UnitFrame_OnLeave(self)
	self.Highlight:Hide()
end

local frame = function(settings, self, unit)
	self.menu = menu

	self:EnableMouse(true)

	self:SetScript("OnEnter", OnEnter)
	self:SetScript("OnLeave", OnLeave)

	self:RegisterForClicks("anyup")

	self:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 16,
		insets = {left = -2, right = -2, top = -2, bottom = -2},
	})
	self:SetBackdropColor(0, 0, 0, 1)

	self:SetAttribute("*type2", "menu")

	local hp = CreateFrame("StatusBar", nil, self)
	hp:SetAllPoints(self)
	hp:SetStatusBarTexture(texture)
	hp:SetOrientation("VERTICAL")
	hp:SetFrameLevel(5)

	local hpbg = hp:CreateTexture(nil, "BACKGROUND")
	hpbg:SetAllPoints(hp)
	hpbg:SetTexture(texture)
	hpbg:SetAlpha(0.2)

	if libheal then
		local heal = CreateFrame("StatusBar", nil, self)
		heal:SetAllPoints(self)
		heal:SetStatusBarTexture(texture)
		heal:SetOrientation("VERTICAL")
		heal:SetStatusBarColor(0, 1, 0)
		heal:SetFrameLevel(3)
		heal:Hide()

		self.heal = heal
	end

	hp.bg = hpbg
	self.Health = hp
	self.OverrideUpdateHealth = Health_Update

	local hl = hp:CreateTexture(nil, "OVERLAY")
	hl:SetAllPoints(self)
	hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	hl:SetBlendMode("ADD")
	hl:Hide()

	self.Highlight = hl

	local name = hp:CreateFontString(nil, "OVERLAY")
	name:SetPoint("CENTER")
	name:SetJustifyH("CENTER")
	name:SetFont(supernova, 10, "THINOUTLINE")
	name:SetShadowColor(0,0,0,1)
	name:SetShadowOffset(1, -1)
	name:SetTextColor(1, 1, 1, 1)

	self.Name = name
	self.UNIT_NAME_UPDATE = Name_Update

	local border = hp:CreateTexture(nil, "OVERLAY")
	border:SetPoint("LEFT", self, "LEFT", -4, 0)
	border:SetPoint("RIGHT", self, "RIGHT", 4, 0)
	border:SetPoint("TOP", self, "TOP", 0, 4)
	border:SetPoint("BOTTOM", self, "BOTTOM", 0, -4)
	border:SetTexture([[Interface\AddOns\oUF_Kanne_Grid\media\Normal.tga]])
	border:Hide()
	border:SetVertexColor(1, 1, 1)

	self.border = border

	local icon = hp:CreateTexture(nil, "OVERLAY")
	icon:SetPoint("CENTER")
	icon:SetHeight(20)
	icon:SetWidth(20)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	icon:Hide()

	icon.ShowText = function(s)
		self.Name:Hide()
		s:Show()
	end

	icon.HideText = function(s)
		self.Name:Show()
		s:Hide()
	end

	self.Icon = icon

	self.Range = true
	self.inRangeAlpha = 1
	self.outsideRangeAlpha = 0.4

	return self
end

local style = setmetatable({
	["initial-height"] = height,
	["initial-width"] = width,
}, {
	__call = frame,
})

oUF:RegisterStyle("Kanne-Grid", style)
oUF:SetActiveStyle("Kanne-Grid")

local raid = {}

for i = 1, 8 do
	local r = oUF:Spawn("header", "oUF_Raid" .. i)
	r:SetPoint("TOP", UIParent, "TOP", 0, -500)
	if i == 1 then
		r:SetPoint("LEFT", UIParent, "LEFT", 10, 0)
		r:SetAttribute("showParty", true)
	else
		r:SetPoint("LEFT", raid[i - 1], "RIGHT", 6, 0)
	end

	r:SetManyAttributes(
		"showRaid", true,
		"groupFilter", i,
		"yOffset", -10
	)

	r:Show()
	raid[i] = r
end

-- BG handling

local SubGroups = function()
	local t = {}
	for i = 1, GetNumRaidMembers() do
		local s = select(3, GetRaidRosterInfo(i))
		t[s] = (t[s] or 0) + 1
	end
	return t
end
-- BG
local bg = CreateFrame("Frame")
bg:SetPoint("TOPLEFT", raid[1], "TOPLEFT", - 8, 8)
bg:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground", tile = true, tileSize = 16,
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
	insets = {left = 2, right = 2, top = 2, bottom = 2}
})
bg:SetBackdropColor(0, 0, 0, 0.6)
bg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
bg:SetFrameLevel(0)
bg:Show()


function f:RAID_ROSTER_UPDATE()
	if not UnitInRaid("player") then
		return bg:Hide()
	else
		bg:Show()
	end

	local roster = SubGroups()

	for k, v in ipairs(roster) do
		if type(v) == "nil" then
			print(string.format("Nil value at index %d", k))
		end
	end

	local h = math.max(unpack(roster))
	local w = #roster

	bg:SetPoint("RIGHT", raid[w], "RIGHT", 8, 0)

	bg:SetHeight(29 * h)

	if libheal then
		UpdateRoster()
	end
end

f.PLAYER_LOGIN = f.RAID_ROSTER_UPDATE
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_LOGIN")
