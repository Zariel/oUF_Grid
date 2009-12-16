local _G = getfenv(0)

local oUF = _G.oufgrid or _G.oUF

if not oUF then
	return error("oUF_Grid requires oUF")
end

local libheal = LibStub("LibHealComm-4.0", true)

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
local playerGUID = UnitGUID("player")

-- Currently selected raid member frame.
local coloredFrame
local UpdateRoster
local width, height = 32, 32

if playerName == "Kanne" then
	playerClass = "PALADIN"
end

-- spell = priority
local debuffs = setmetatable({
	["Viper Sting"] = 7,

	["Wound Poison"] = 9,
	["Mortal Strike"] = 8,
	["Aimed Shot"] = 8,

	["Counterspell - Silenced"] = 11,
	["Counterspell"] = 10,

	["Blind"] = 10,
	["Cyclone"] = 10,
	["Scatter Shot"] = 10,

	["Polymorph"] = 7,

	["Entangling Roots"] = 7,
	["Freezing Trap Effect"] = 7,
	["Chains of Ice"] = 7,

	["Crippling Poison"] = 6,
	["Hamstring"] = 5,
	["Wingclip"] = 5,

	["Fear"] = 3,
	["Psycic Scream"] = 3,
	["Howl of Terror"] = 3,
}, { __index = function() return 0 end })

local dispellPriority = {
	["Magic"] = 4,
	["Poison"] = 3,
	["Disease"] = 1,
	["Curse"] = 2,
	["None"] = 0,
}

local dispellClass
do
	local t = {
		["PRIEST"] = {
			["Magic"] = true,
			["Disease"] = true,
		},
		["SHAMAN"] = {
			["Poison"] = true,
			["Disease"] = true,
			["Curse"] = true,
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
			dispellPriority[k] = dispellPriority[k] * 10
		end
		t = nil
	end
end

-- Lib Heal Support

if libheal then
	local heals = {}
	local roster = libheal:GetGUIDUnitMapTable()

	function heals:HealComm_HealStopped(event, casterGUID, spellID, type, interuptted, ...)
		self:HealComm_HealStarted(nil, nil, nil, nil, nil, ...)
	end

	function heals:HealComm_ModifierChanged(event, guid)
		self:UpdateHeals(nil, nil, nil, nil, nil, guid)
	end

	function heals:HealComm_HealDelayed(event, healerName, healSize, endTime, ...)
		self:HealComm_HealStarted(event, healerName, healSize, endTime, ...)
	end

	heals.HealComm_HealUpdated = heals.HealComm_HealDelayed

	function heals:HealComm_HealStarted(event, healerGUID, spellID, healType, endTime, ...)
		for i = 1, select("#", ...) do
			self:UpdateHeals(select(i, ...))
		end
	end

	local mod, incPer, per, incSize, size, max
	function heals:GetIncSize(guid, unit)
		local incHeal = libheal:GetHealAmount(guid, libheal.ALL_HEALS)

		if incHeal then
			max = UnitHealthMax(unit)
			mod = libheal:GetHealModifier(guid)
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

	function heals:UpdateHeals(guid)
		local unit = roster[guid]
		if not oUF.units[unit] then return end

		local frame = oUF.units[unit]

		local max, current = UnitHealth(unit), UnitHealthMax(unit)
		if current == max then
			return frame.heal:Hide()
		end

		local incSize, incHeal, healMod = self:GetIncSize(guid, unit)
		if incSize then
			local size = height * (UnitHealth(unit) / UnitHealthMax(unit))
			frame.heal:SetHeight(incSize)
			frame.heal:SetPoint("BOTTOM", frame, "BOTTOM", 0, size)
			frame.heal:Show()
		else
			frame.heal:Hide()
		end

		frame.incHeal = incHeal or 0
		frame.healMod = healMod or 1
	end

	libheal.RegisterCallback(heals, "HealComm_HealStopped")
	libheal.RegisterCallback(heals, "HealComm_HealDelayed")
	libheal.RegisterCallback(heals, "HealComm_HealUpdated")
	libheal.RegisterCallback(heals, "HealComm_HealStarted")
	libheal.RegisterCallback(heals, "HealComm_ModifierChanged")
end

local frame
function f:UNIT_AURA(event, unit)
	frame = oUF.units[unit]
	if not frame or frame.unit ~= unit then return end

	local cur, tex, dis, dur, exp
	local name, rank, buffTexture, count, duration, expire, dtype, isPlayer
	for i = 1, 40 do
		name, rank, buffTexture, count, dtype, duration, expire, isPlayer = UnitAura(unit, i, "HARMFUL")
		if not name then break end

		if not cur or (debuffs[name] >= debuffs[cur]) then
			if debuffs[name] > 0 and debuffs[name] > debuffs[cur or 1] then
				-- Highest priority
				cur = name
				tex = buffTexture
				dis = dtype or "none"
				exp = expire
				dur = duration
			elseif dtype and dtype ~= "none" then
				if not dis or (dispellPriority[dtype] > dispellPriority[dis]) then
					cur = name
					tex = buffTexture
					dis = dtype
					exp = expire
					dur = duration
				end
			end
		end
	end

	if dis then
		local col = DebuffTypeColor[dis]
		frame.border:SetVertexColor(col.r, col.g, col.b)
		frame.Dispell = true
		frame.border:Show()
	elseif frame.Dispell then
		if colouredFrame and colouredFrame ~= colouredFrame or not colouredFrame then
			frame.border:Hide()
			frame.Dispell = False
		end
	end

	if exp and exp > 0 and dur and dur > 0 then
		frame.cd:SetCooldown(exp - dur, dur)
		frame.cd:Show()
	else
		frame.cd:Hide()
	end

	if cur then
		frame.Icon:SetTexture(tex)
		frame.Icon:Show()
	else
		frame.Icon:Hide()
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

f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
