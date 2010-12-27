local _G = getfenv(0)
local oUF = _G.oufgrid or _G.oUF

if not oUF then
	return error("oUF_Grid requires oUF")
end

local kgrid = _G.KanneGrid

local UnitName = UnitName
local UnitClass = UnitClass
local select = select
local unpack = unpack
local UnitDebuff = UnitDebuff
local UnitInRaid = UnitInRaid
local GetTime = GetTime

local playerClass = select(2, UnitClass("player"))
local playerName, playerRealm = UnitName("player"), GetRealmName()
local playerGUID = UnitGUID("player")

-- Currently selected raid member frame.
local curFrame
local UpdateRoster
local size = oUF.size

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
			["Magic"] = true,
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
			["Magic"] = true,
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

function kgrid:HealPredict(event, unit)
	if(self.unit ~= unit) then return end
	local hp = self.HealPrediction

	local incHeal = UnitGetIncomingHeals(unit) or 0
	if(incHeal > 0) then
		local max = UnitHealthMax(unit)
		local incPer = incHeal / max
		local per = UnitHealth(unit) / max
		local incSize = incPer * oUF.size
		local size = oUF.size * per

		if(per > 98) then return hp:Hide() end

		if(incSize + size >= oUF.size) then
			incSize = oUF.size - size
		end

		if(incSize > 0) then
			hp:SetHeight(incSize)
			hp:SetPoint("BOTTOM", self, "BOTTOM", 0, size)
			hp:SetPoint("LEFT", self, "LEFT")
			hp:SetPoint("RIGHT", self, "RIGHT")
			hp:Show()
		else
			hp:Hide()
		end
	else
		hp:Hide()
	end
end

local frame
function kgrid:UNIT_AURA(event)
	if(not self or self.unit ~= unit) then return end

	local cur, tex, dis, dur, exp
	local name, rank, buffTexture, count, duration, expire, dtype, isPlayer

	for i = 1, 40 do
		name, rank, buffTexture, count, dtype, duration, expire, isPlayer = UnitAura(unit, i, "HARMFUL")
		if(not name) then break end

		if(not cur or (debuffs[name] >= debuffs[cur])) then
			if(debuffs[name] > 0 and debuffs[name] > debuffs[cur or 1]) then
				-- Highest priority
				cur = name
				tex = buffTexture
				dis = dtype or "none"
				exp = expire
				dur = duration
			elseif(dtype and dtype ~= "none") then
				if(not dis or (dispellPriority[dtype] > dispellPriority[dis])) then
					cur = name
					tex = buffTexture
					dis = dtype
					exp = expire
					dur = duration
				end
			end
		end
	end

	if(dis) then
		local col = DebuffTypeColor[dis]
		self.border:SetVertexColor(col.r, col.g, col.b)
		self.Dispell = true
		self.border:Show()
	elseif self.Dispell then
		if (curself ~= frame) or not curFrame then
			self.border:Hide()
		elseif curself == frame then
			self.border:SetVertexColor(1, 1, 1)
		end
		self.Dispell = False
	elseif curself and curFrame == frame then
		self.border:SetVertexColor(1, 1, 1)
	end

	if (exp and exp > 0) and (dur and dur > 0) then
		self.cd:SetCooldown(exp - dur, dur)
		self.cd:Show()
	else
		self.cd:Hide()
	end

	if cur then
		self.Icon:SetTexture(tex)
		self.Icon:Show()
	else
		self.Icon:Hide()
	end
end

function kgrid:PLAYER_TARGET_CHANGED(event, ...)
	local inRaid = UnitInRaid("target")
	local frame
	if(inRaid) then
		if UnitExists("raid" .. inRaid) then
			frame = oUF.units["raid" .. inRaid]
		end
	else
		local name = UnitName("target")
		if(name == playerName and oUF.units.player) then
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

	-- Deselected
	if(not frame) then
		if(curFrame) then
			if(not curFrame.Dispell) then
				curFrame.border:Hide()
			end

			curFrame = nil
		end

		return
	end

	if(curFrame) then
		if(frame == curFrame) then
			if(frame.Dispell) then
				return
			else
				frame.border:SetVertexColor(1, 1, 1)
			end
		else
			curFrame.border:Hide()

			if(not frame.Dispell) then
				frame.border:SetVertexColor(1, 1, 1)
				frame.border:Show()
			end

			curFrame = frame
		end
	else
		if(not frame.Dispell) then
			frame.border:SetVertexColor(1, 1, 1)
			frame.border:Show()
		end

		curFrame = frame
	end
end
