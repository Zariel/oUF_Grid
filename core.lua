local _G = getfenv(0)
local oUF = _G.oufgrid or _G.oUF

if not oUF then
	return error("oUF_Grid requires oUF")
end

local UnitName = UnitName
local UnitClass = UnitClass
local select = select
local unpack = unpack
local UnitDebuff = UnitDebuff
local UnitInRaid = UnitInRaid

local width, height = 32, 32

local supernova = [[Interface\AddOns\oUF_Grid\media\nokiafc22.ttf]]
local texture = [[Interface\AddOns\oUF_Grid\media\gradient32x32.tga]]
local hightlight = [[Interface\AddOns\oUF_Grid\media\mouseoverHighlight.tga]]

local colors = {
	class ={
		-- I accept patches you know
		["DEATHKNIGHT"] = { 0.77, 0.12, 0.23 },
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
		return { 0.78, 0.61, 0.43 }
	end
})

local GetClassColor = function(unit)
	return unpack(colors.class[select(2, UnitClass(unit))])
end

local ColorGradient = function(perc, r1, g1, b1, r2, g2, b2, r3, g3, b3)
	if perc >= 1 then
		return { r3, g3, b3 }
	elseif perc <= 0 then
		return { r1, g1, b1 }
	end

	local segment, relperc = math.modf(perc*(2))
	local offset = (segment*3)+1

	if(offset == 1) then
		return { r1 + (r2-r1)*relperc, g1 + (g2-g1)*relperc, b1 + (b2-b1)*relperc }
	end

	return { r2 + (r3-r2)*relperc, g2 + (g3-g2)*relperc, b2 + (b3-b2)*relperc }
end

local Name_Update = function(self, event, unit)
	if self.unit ~= unit then return end

	local n, s = UnitName(unit)
	self.name = string.utf8sub(n, 1, 3)

	if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then
		self.Health.bg:SetVertexColor(0.3, 0.3, 0.3)
	else
		self.Health.bg:SetVertexColor(GetClassColor(unit))
	end
end

local round = function(x, y)
	return math.floor((x * 10 ^ y)+ 0.5) / 10 ^ y
end

local Health_Update = function(self, event, unit, bar, current, max)
	local def = max - current
	bar:SetValue(current)

	local per = round(current/max, 100)
	local col = ColorGradient(per, 1, 0, 0, 1, 1, 0, 1, 1, 1)
	self.Name:SetTextColor(unpack(col))

	if per > 0.9 or UnitIsDeadOrGhost(unit) then
		self.Name:SetText(self.name)
	else
		self.Name:SetFormattedText("-%0.1f", math.floor(def/100)/10)
	end

	if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then
		bar.bg:SetVertexColor(0.3, 0.3, 0.3)
	else
		bar.bg:SetVertexColor(GetClassColor(unit))
	end

	-- Hopefully this fixes everything ...
	local incHeal = self.incHeal
	if incHeal > 0 then
		if max == current then
			self.heal:Hide()
			return
		end
		local size = height * per
		local incSize = ((self.healMod or 1 * incHeal) / max) * height

		if incSize + size >= height then
			incSize = height - size
		end

		self.heal:SetHeight(incSize)
		self.heal:SetPoint("BOTTOM", self, "BOTTOM", 0, size)
		self.heal:Show()
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
	--self:SetMovable(true)
	--self:RegisterForDrag("LleftButton")

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
	hp:SetStatusBarColor(0, 0, 0)
	hp:SetAlpha(0.9)

	local hpbg = hp:CreateTexture(nil, "BACKGROUND")
	hpbg:SetAllPoints(hp)
	hpbg:SetTexture(texture)
	hpbg:SetAlpha(1)

	local heal = hp:CreateTexture(nil, "OVERLAY")
	heal:SetHeight(height)
	heal:SetWidth(width)
	heal:SetPoint("BOTTOM")
	heal:SetTexture(texture)
	heal:SetVertexColor(0, 1, 0)
	heal:Hide()

	self.heal = heal

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
	name:SetAlpha(1)
	name:SetPoint("CENTER")
	name:SetJustifyH("CENTER")
	name:SetFont(supernova, 10, "THINOUTLINE")
	name:SetShadowColor(0,0,0,1)
	name:SetShadowOffset(1, -1)
	name:SetTextColor(1, 1, 1, 1)

	self.Name = name
	self.UNIT_NAME_UPDATE = Name_Update

	local border = hp:CreateTexture(nil, "ARTWORK")
	border:SetPoint("LEFT", self, "LEFT", -4, 0)
	border:SetPoint("RIGHT", self, "RIGHT", 4, 0)
	border:SetPoint("TOP", self, "TOP", 0, 4)
	border:SetPoint("BOTTOM", self, "BOTTOM", 0, -4)
	border:SetTexture([[Interface\AddOns\oUF_Grid\media\Normal.tga]])
	border:SetAlpha(1)
	border:Hide()
	border:SetVertexColor(1, 1, 1)

	self.border = border

	local icon = hp:CreateTexture(nil, "OVERLAY")
	icon:SetPoint("CENTER")
	icon:SetAlpha(1)
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

	self.incHeal = 0
	self.healMod = 0

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
		-- Change this to move it
		r:SetPoint("LEFT", UIParent, "LEFT", 10, 0)
		r:SetAttribute("showParty", true)
		r:SetAttribute("showPlayer", true)
		r:SetAttribute("showSolo", true)
	else
		r:SetPoint("LEFT", raid[i - 1], "RIGHT", 6, 0)
	end

	r:SetManyAttributes(
		"showRaid", true,
		"groupFilter", i,
		"yOffset", - 10
	)

	r:Show()
	raid[i] = r
end

local SubGroups = function()
	local t = {}
	for i = 1, 8 do t[i] = 0 end
	for i = 1, GetNumRaidMembers() do
		local s = select(3, GetRaidRosterInfo(i))
		t[s] = t[s] + 1
	end
	return t
end

-- BG
local bg = CreateFrame("Frame")
bg:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground", tile = true, tileSize = 16,
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
	insets = {left = 2, right = 2, top = 2, bottom = 2}
})
bg:SetBackdropColor(0, 0, 0, 0.6)
bg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
bg:SetFrameLevel(0)

bg:SetScript("OnEvent", function(self, event, ...)
	return self[event](self, event, ...)
end)

function bg:RAID_ROSTER_UPDATE()
	if not UnitInRaid("player") then
		return self:PARTY_MEMBERS_CHANGED()
	else
		self:Show()
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

	self:ClearAllPoints()
	self:SetPoint("TOP", _G["oUF_Raid1"], "TOP", 0, 8)
	self:SetPoint("LEFT", _G["oUF_Raid" .. first], "LEFT", -8 , 0)
	self:SetPoint("RIGHT", _G["oUF_Raid" .. last], "RIGHT", 8, 0)
	self:SetPoint("BOTTOM", _G["oUF_Raid" .. h], "BOTTOM", 0, -8)
end

function bg:PARTY_MEMBERS_CHANGED()
	if UnitInRaid("player") then return end

	self:ClearAllPoints()
	self:SetPoint("BOTTOMRIGHT", _G["oUF_Raid1"], "BOTTOMRIGHT", 8, - 8)
	self:SetPoint("TOPLEFT", _G["oUF_Raid1"], "TOPLEFT", - 8, 8)
	self:Show()
end

bg.PLAYER_LOGIN = bg.RAID_ROSTER_UPDATE
bg:RegisterEvent("PLAYER_LOGIN")
bg:RegisterEvent("RAID_ROSTER_UPDATE")
bg:RegisterEvent("PARTY_MEMBERS_CHANGED")
