local _G = getfenv(0)

local oUF = _G.oufgrid or _G.oUF

if not oUF then
	return error("oUF_Grid requires oUF")
end

local libheal = LibStub("LibHealComm-3.0", true)

local UnitName = UnitName
local UnitClass = UnitClass
local select = select
local unpack = unpack
local UnitDebuff = UnitDebuff
local UnitInRaid = UnitInRaid
local GetTime = GetTime

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, evnet, ...)
	return self[event](self, event, ...)
end)

local playerClass = select(2, UnitClass("player"))
local playerName, playerRealm = UnitName("player"), GetRealmName()

-- Currently selected raid member frame.
local coloredFrame
local UpdateRoster
local width, height = 32, 32

if playerName == "Kanne" then
	playerClass = "PALADIN"
end

-- spell = priority
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
	if t[playerClass] then
		dispellClass = {}
		for k, v in pairs(t[playerClass]) do
			dispellClass[k] = v
		end
		t = nil
	end
end

local dispellPiority = {
	["Magic"] = 4,
	["Poison"] = 3,
	["Curse"] = 2,
	["Disease"] = 1,
}

-- Lib Heal Support

if libheal then
	local ownHeals = {}
	local Roster, invRoster = {}, {}

	setmetatable(invRoster, {
		__index = function(self, key)
			local name, server = UnitName(key)
			if name == playerName then server = playerRealm end
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
			if key == playerName then
				local unit
				if UnitInRaid("player") then
					unit = "raid" .. UnitInRaid("player") + 1
				else
					unit = "player"
				end
				local set = key .. "-" .. playerRealm
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
		if GetNumRaidMembers() > 0 then
			for i = 1, 40 do
				unit = "raid" .. i
				if UnitExists(unit) then
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
				if UnitExists(unit) then
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

	local heals = {}

	function heals:HealComm_DirectHealStop(event, healerName, healSize, succeeded, ...)
		self:HealComm_DirectHealStart(event, healerName, 0, endTime, ...)
	end

	function heals:HealModifierUpdate(event, unit, targetName, healModifier)
		self:UpdateHeals(targetName)
	end

	function heals:HealComm_DirectHealDelayed(event, healerName, healSize, endTime, ...)
		self:HealComm_DirectHealStart(event, healerName, healSize, endTime, ...)
	end

	function heals:HealComm_DirectHealStart(event, healerName, healSize, endTime, ...)
		local isOwn = healerName == playerName
		for i = 1, select("#", ...) do
			local name = select(i, ...)
			if isOwn then
				ownHeals[name] = healSize
			end
			self:UpdateHeals(name)
		end
	end

	local mod, incPer, per, incSize, size, max
	function heals:GetIncSize(unit, name)
		name = name or invRoster[unit]
		local incHeal = select(2, libheal:UnitIncomingHealGet(unit, GetTime())) or 0
		incHeal = incHeal + (ownHeals[name] or 0)

		if incHeal > 0 then
			max = UnitHealthMax(unit)
			mod = libheal:UnitHealModifierGet(name)
			incPer = (mod * incHeal) / max
			per = UnitHealth(unit) / max
			incSize = incPer * height
			size = height * per

			if incSize + size >= height then
				incSize = height - size
			end

			return incSize, incHeal, mod
		else
			return
		end
	end

	function heals:UpdateHeals(name)
		local unit = Roster[name]
		if not oUF.units[unit] then return end

		local frame = oUF.units[unit]

		if not frame.heal then
			local heal = frame.Health:CreateTexture(nil, "OVERLAY")
			heal:SetHeight(height)
			heal:SetWidth(width)
			heal:SetPoint("BOTTOM", frame.Health)
			heal:SetTexture([[Interface\AddOns\oUF_Grid\media\gradient32x32.tga]])
			heal:SetVertexColor(0, 1, 0)
			heal:Hide()
			frame.heal = heal
		end

		local incSize, incHeal, healMod = self:GetIncSize(unit, name)
		if incSize then
			local size = height * (UnitHealth(unit) / UnitHealthMax(unit))
			frame.heal:SetHeight(incSize)
			frame.heal:SetPoint("BOTTOM", frame, "BOTTOM", 0, size)
			frame.heal:Show()
		else
			frame.heal:Hide()
		end

		frame.incHeal = incHeal or 0
		frame.healMod = healMod or 0
	end

	libheal.RegisterCallback(heals, "HealComm_DirectHealStop")
	libheal.RegisterCallback(heals, "HealComm_DirectHealDelayed")
	libheal.RegisterCallback(heals, "HealComm_DirectHealStart")
	libheal.RegisterCallback(heals, "HealModifierUpdate")
end

local name, rank, buffTexture, count, duration, timeLeft, dtype, isPlayer
function f:UNIT_AURA(event, unit)
	if not oUF.units[unit] then return end

	local frame = oUF.units[unit]

	if not frame.Icon then return end
	local current, bTexture, dispell, dispellTexture
	for i = 1, 40 do
		name, rank, buffTexture, count, dtype, duration, timeLeft, isPlayer = UnitAura(unit, i, "HARMFUL")
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

			if debuffs[name] > debuffs[current] then
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
				if unit ~= coloredFrame.unit then
					frame.border:Hide()
				end
			else
				frame.border:Hide()
			end
		end
	end

	if current and bTexture or buffTexture  then
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
	local inRaid = UnitInRaid("target")
	local frame
	if inRaid then
		if UnitExists("raid" .. inRaid + 1) then
			frame = oUF.units["raid" .. inRaid + 1]
		end
	else
		local name = UnitName("target")
		if name == playerName and oUF.units.player then
			frame = oUF.units.player
		else
			for i = 1, 4 do
				if UnitExists("party" .. i) then
					if name == UnitName("party" .. i) then
						frame = oUF.units["party" .. i]
						break
					end
				else
					break
				end
			end
		end
	end

	if not frame then
		if coloredFrame then
			if not coloredFrame.Dispell then
				coloredFrame.border:Hide()
			end
			coloredFrame = nil
		end
		return
	end

	if coloredFrame and not coloredFrame.Dispell then
		coloredFrame.border:Hide()
	end

	if not frame.Dispell and frame.border then
		frame.border:SetVertexColor(1, 1, 1)
		frame.border:Show()
		coloredFrame = frame
	end
end

function f:RAID_ROSTER_UPDATE(event)
	if libheal then
		UpdateRoster()
	else
		self:UnregisterEvent(event)
	end
end

f.PLAYER_LOGIN = f.RAID_ROSTER_UPDATE
f.PARTY_MEMBERS_CHANGED = f.RAID_ROSTER_UPDATE
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("RAID_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PARTY_MEMBERS_CHANGED")
