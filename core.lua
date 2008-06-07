local print = function(str) return ChatFrame3:AddMessage(tostring(str)) end
local _G = getfenv(0)
local oUF = _G.oUF

local UnitName = UnitName
local UnitClass = UnitClass
local select = select
local unpack = unpack
local UnitDebuff = UnitDebuff

local width, height = 32, 32

local supernova = [[Interface\AddOns\oUF_Kanne2\media\nokiafc22.ttf]]
local texture = [[Interface\AddOns\oUF_Kanne_Grid\gradient32x32.tga]]

local PLAYERCLASS = select(2, UnitClass("player"))
PLAYERCLASS = "PALADIN"
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

-- Debuff priority, with the same number = same mechanic, i gave wounder >
-- mortal beacuse wound is dispellable etc.

local debuffs = {
	["Mortal Strike"] = 8,
	["Wound Poison"] = 9,
	["Fear"] = 3,
	["Phsycic Scream"] = 3,
	["Howl of Terror"] = 3,
	["Hamstring"] = 5,
	["Crippling Poison"] = 6,
	["Blind"] = 10,
	["Cyclone"] = 10,
	["Entangling Roots"] = 7,
	["Freezing Trap Effect"] = 7,
	["Counterspell-Silenced"] = 10,
	["Counterspell"] = 10,
	["Viper Sting"] = 11,
}

local dispellClass = {
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
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("PLAYER_TARGET_CHANGED")

local name, rank, buffTexture, count, duration, timeLeft, dtype
function f:UNIT_AURA(unit)
	if not oUF.units[unit] then return end

	local frame = oUF.units[unit]
	if not frame.Icon then return end
	local current, text, dispell
	for i = 1, 40 do
		name, rank, buffTexture, count, dtype, duration, timeLeft = UnitDebuff(unit, i)
		if not name then break end

		if dispellClass[PLAYERCLASS] and dispellClass[PLAYERCLASS][dtype] then
			dispell = dtype
		end

		if not debuffs[name] then break end

		current = current or name
		text = text or buffTexture
		local prio = debuffs[name]
		if prio > debuffs[current] then
			current = name
			text = buffTexture
		end
	end

	if dispellClass[PLAYERCLASS] then
		if dispell then
			if dispellClass[PLAYERCLASS][dispell] then
				local col = DebuffTypeColor[dispell]
				frame.border:Show()
				frame.border:SetVertexColor(col.r, col.g, col.b)
				frame.Dispell = true
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

	if current and text then
		frame.Icon:SetTexture(text)
		frame.Icon:ShowText()
	else
		frame.Icon:HideText()
	end
end

function f:PLAYER_TARGET_CHANGED()
	local id = UnitInRaid("target") and UnitInRaid("target") + 1
	local frame = id and oUF.units["raid" .. id]
	if not frame then
		if coloredFrame then
			if not oUF.units[coloredFrame].Dispell then
				oUF.units[coloredFrame].border:Hide()
			end
		end
		return
	end

	if coloredFrame and not oUF.units[coloredFrame].Dispell then
		oUF.units[coloredFrame].border:Hide()
	end

	if not frame.Dispell then
		frame.border:SetVertexColor(1,1,1)
		frame.border:Show()
	end
	coloredFrame = "raid" .. id
end

local Name_Update = function(self, event, unit)
	if self.unit ~= unit then return end

	self.name = string.sub(UnitName(unit), 1, 3)
	local class = select(2, UnitClass(unit))
	self.Health:SetStatusBarColor(unpack(colors.class[class]))
	self.Health.bg:SetVertexColor(unpack(colors.class[class]))
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
end

local frame = function(settings, self, unit)
	self.menu = menu

	self:EnableMouse(true)

	self:SetScript("OnEnter", UnitFrame_OnEnter)
	self:SetScript("OnLeave", UnitFrame_OnLeave)

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

	local hpbg = hp:CreateTexture(nil, "BORDER")
	hpbg:SetAllPoints(hp)
	hpbg:SetTexture(texture)
	hpbg:SetAlpha(0.2)

	hp.bg = hpbg
	self.Health = hp
	self.OverrideUpdateHealth = Health_Update

	local name = hp:CreateFontString(nil, "OVERLAY")
	name:SetPoint("CENTER")
	name:SetJustifyH("CENTER")
	name:SetFont(supernova, 10, "THINOUTLINE")
	name:SetShadowColor(0,0,0,1)
	name:SetShadowOffset(1, -1)
	name:SetTextColor(1,1,1,1)

	self.Name = name
	self.UNIT_NAME_UPDATE = Name_Update

	local border = hp:CreateTexture(nil, "OVERLAY")
	border:SetPoint("LEFT", self, "LEFT", -4, 0)
	border:SetPoint("RIGHT", self, "RIGHT", 4, 0)
	border:SetPoint("TOP", self, "TOP", 0, 4)
	border:SetPoint("BOTTOM", self, "BOTTOM", 0, -4)
	border:SetTexture([[Interface\AddOns\oUF_Kanne2\media\Normal.tga]])
	border:Hide()
	border:SetVertexColor(1, 1, 1)

	local icon = hp:CreateTexture(nil, "OVERLAY")
	icon:SetPoint("CENTER")
	icon:SetHeight(20)
	icon:SetWidth(20)

	icon.ShowText = function(self)
		self:GetParent():GetParent().Name:Hide()
		self:Show()
	end

	icon.HideText = function(self)
		self:GetParent():GetParent().Name:Show()
		self:Hide()
	end
	self.Icon = icon

	self.border = border

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

local raid = oUF:Spawn("header", "oUF_Raid")

raid:SetPoint("LEFT", UIParent, "LEFT", 10, 0)
raid:SetPoint("TOP", UIParent, "TOP", 0, -500)
raid:Show()

local atrib = {
	["showRaid"] = true,
	["maxColumns"] = 8,
	["unitsPerColumn"] = 5,
	["columnSpacing"] = 5,
	["yOffset"] = -10,
	["columnAnchorPoint"] = "LEFT",
	["groupingOrder"] = "1,2,3,4,5,6,7,8",
}

for k, v in pairs(atrib) do
	raid:SetAttribute(k, v)
end
