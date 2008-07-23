local print = function(...)
	local str = ""
	for i = 1, select("#", ...) do
		str = str .. " " .. tostring(select(i, ...))
	end

	return ChatFrame3:AddMessage(str)
end

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

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, evnet, ...)
	return self[event](self, ...)
end)

local PLAYERCLASS = select(2, UnitClass("player"))
local playername, playerrealm = UnitName("player"), GetRealmName()

local coloredFrame      -- Selected Raid Member

local UpdateRoster

local width, height = 32, 32

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

-- Lib Heal Support

if libheal then
	local Roster, invRoster = {}, {}

	setmetatable(invRoster, {
		__index = function(self, key)
			local name, server = UnitName(key)
			if name == playername then server = playerrealm end
			if server and server ~= "" then
				name = name .. "-" .. server
			end
			if name then
				rawset(Roster, name, key)
				rawset(self, key, name)
				return name
			end
			return
		end
	})

	setmetatable(Roster, {
		__index = function(self, key)
			if key == playername then
				local unit
				if UnitInRaid("player") then
					unit = "raid" .. UnitInRaid("player") + 1
				else
					unit = "player"
				end
				local set = key .. "-" .. playerrealm
				rawset(self, set, unit)
				rawset(invRoster, unit, set)
				return unit
			end
			-- Dont want to do this :(
			for unit in pairs(oUF.units) do
				local name, server = UnitName(unit)
				if name == key and server and server ~= "" then
					name = name .. "-" .. server
					rawset(self, name, unit)
					rawset(invRoster, unit, name)
					return unit
				end
			end
			return
		end
	})

	UpdateRoster = function()
		local unit
		local e
		if GetNumRaidMembers() > 0 then
			for i = 1, 40 do
				unit = "raid" .. i
				e = UnitExists(unit)
				if e then
					local name, server = UnitName(unit)
					if server and server ~= "" then
						name = name .. "-" .. server
					end
					if name then
						Roster[name] = unit
						invRoster[unit] = name
					end
				else
					local n = invRoster[unit]
					if n then
						Roster[n] = nil
					end
					invRoster[unit] = nil
				end
			end
		elseif GetNumPartyMembers() > 0 then
			for i = 1, 4 do
				unit = "party" .. i
				e = UnitExists(unit)
				if e then
					local name, server = UnitName(unit)
					if not Roster[name] then
						Roster[name] = unit
						invRoster[unit] = name
					end
				else
					local n = invRoster[unit]
					if n then
						Roster[n] = nil
					end
					invRoster[unit] = nil
				end
			end
		end
	end

	local HealInc = function(event, healerName, healSize, endTime, ...)
		for i = 1, select("#", ...) do
			local name = tostring(select(i, ...))
			local unit = Roster[name]
			if not unit then return end
			local frame = oUF.units[unit]

			if not frame or not frame.heal then
				print("===========================")
				printf("No Frame: unit = %s name = %s", tostring(unit), tostring(name))
				printf("Unitexists: %s", UnitExists(unit))
				return
			end

			local incHeal = select(2, libheal:UnitIncomingHealGet(unit, GetTime()))
			local a, b = libheal:UnitIncomingHealGet(unit, GetTime())
			print(name, unit, a, b)
			if incHeal then
				local mod = libheal:UnitHealModifierGet(name)
				local val = (mod * incHeal)
				local incPer = val / UnitHealthMax(unit)
				local per = UnitHealth(unit) / UnitHealthMax(unit)
				frame.heal:SetHeight(incPer * height)
				frame.heal:SetPoint("BOTTOM", frame, "BOTTOM", 0, height * per)
				frame.heal:Show()
				printf("%s (%s) ---> %s (%s)", healerName, val, name, unit)
			else
				frame.heal:Hide()
			end
		end
	end

	libheal.RegisterCallback("", "HealComm_DirectHealStop", HealInc)
	libheal.RegisterCallback("", "HealComm_DirectHealStart", HealInc)
	libheal.RegisterCallback("", "HealModifierUpdate", HealInc)
end

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
		frame.IconShown = true
		frame.Icon:SetTexture(bTexture)
		frame.Icon:ShowText()
		frame.DebuffTexture = true
	else
		frame.IconShown = false
		frame.DebuffTexture = false
		frame.Icon:HideText()
	end
end

function f:PLAYER_TARGET_CHANGED()
	local id = UnitInRaid("target") and UnitInRaid("target") + 1
	local frame = id and UnitInRaid("target") and oUF.units["raid" .. id]
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

	coloredFrame = UnitInRaid("target") and "raid" .. id
end


local SubGroups
do
	local t = {}
	SubGroups = function()
		for i = 1, 8 do t[i] = 0 end
		for i = 1, GetNumRaidMembers() do
			local s = select(3, GetRaidRosterInfo(i))
			t[s] = t[s] + 1
		end
		return t
	end
end

-- BG
local bg = CreateFrame("Frame")
bg:SetPoint("TOP", _G["oUF_Raid1"], "TOP", 0, 8)
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

	local h, last, first = 1
	for k, v in ipairs(roster) do
		if v > 0 then
			if not first then
				first = k
			end
			last = k
		end
		if v > roster[h] then
			h = k
		end
	end

	bg:SetPoint("LEFT", _G["oUF_Raid" .. first], "LEFT", -8 , 0)
	bg:SetPoint("RIGHT", _G["oUF_Raid" .. last], "RIGHT", 8, 0)
	bg:SetPoint("BOTTOM", _G["oUF_Raid" .. h], "BOTTOM", 0, -8)

	if libheal then
		UpdateRoster()
	end
end

f.PLAYER_LOGIN = f.RAID_ROSTER_UPDATE
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_LOGIN")
