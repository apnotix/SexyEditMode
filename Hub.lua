-- Hub: das gemeinsame Einstellungsfenster aller Sexy-Addons.
--
-- Jedes Addon meldet sich einmal an:
--   LibStub("SexyEditMode-1.0"):RegisterAddon("SexyLoot", { title = "SexyLoot", version = "0.1.24" })
-- und gibt bei seinen :Register-Aufrufen `addon = "SexyLoot"` an. Die Fenster samt Einstellungen
-- erscheinen dann links in der Seitenleiste (nach Addon gruppiert), rechts stehen die Einstellungen des
-- gewählten Fensters. Es sind dieselben Zeilen wie im Edit-Mode-Dialog (check, slider, select, ...).
--
-- Öffnen: /sem, Minimap-Knopf (Linksklick), lib:ToggleHub(), lib:OpenHub("SexyLoot").

local lib = LibStub("SexyEditMode-1.0", true)
if not (lib and lib.ui) then return end

local ui = lib.ui
local Backdrop, Text, FlatButton = ui.Backdrop, ui.Text, ui.FlatButton
local GOLD, EDGE, BAND = ui.GOLD, ui.EDGE, ui.BAND

local de = GetLocale() == "deDE"
local L = {
	title = de and "Sexy Einstellungen" or "Sexy Settings",
	editMode = de and "Edit Mode öffnen" or "Open Edit Mode",
	empty = de and "Kein Sexy-Addon geladen." or "No Sexy addon loaded.",
	pick = de and "Wähle links ein Fenster." or "Pick a window on the left.",
	other = de and "Sonstige" or "Other",
	minimapTip = de and "Linksklick: Einstellungen" or "Left click: settings",
	minimapTip2 = de and "Rechtsklick: Edit Mode" or "Right click: Edit Mode",
	minimapShown = de and "Minimap-Knopf eingeblendet" or "minimap button shown",
	minimapHidden = de and "Minimap-Knopf ausgeblendet" or "minimap button hidden",
}

local W, H = 840, 560
local SIDE_W = 210
local HEAD_H = 30
local FOOT_H = 48
local CONTENT_W = W - SIDE_W - 44
local ROW_H = 24

lib.addons = lib.addons or {}         -- [id] = { id, title, version, icon }
lib.addonOrder = lib.addonOrder or {}
lib.hubRowCache = lib.hubRowCache or {}

-- Anmelden ----------------------------------------------------------------------------

function lib:RegisterAddon(id, opts)
	opts = opts or {}
	local a = self.addons[id]
	if not a then
		a = { id = id }
		self.addons[id] = a
		self.addonOrder[#self.addonOrder + 1] = id
	end
	a.title = opts.title or a.title or id
	a.version = opts.version or a.version
	a.icon = opts.icon or a.icon
	return a
end

-- Fenster nach Addon gruppiert: { { addon = ..., entries = { ... } }, ... }
local function Groups()
	local list, byId = {}, {}
	local function Group(id)
		if not byId[id] then
			local a = lib.addons[id] or lib:RegisterAddon(id, { title = id == "_other" and L.other or id })
			byId[id] = { addon = a, entries = {} }
			list[#list + 1] = byId[id]
		end
		return byId[id]
	end
	for _, id in ipairs(lib.addonOrder) do Group(id) end
	for _, e in ipairs(lib.order) do table.insert(Group(e.addon or "_other").entries, e) end
	return list
end

-- "SexyLoot: Rollfenster" wird in der Seitenleiste zu "Rollfenster"
local function ShortName(entry, title)
	local name = entry.name or "?"
	local prefix = title .. ": "
	if name:sub(1, #prefix) == prefix then return name:sub(#prefix + 1) end
	return name
end

-- Fenster ----------------------------------------------------------------------------

local function NavItem(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetHeight(ROW_H)
	b.sel = b:CreateTexture(nil, "BACKGROUND")
	b.sel:SetAllPoints()
	b.sel:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.18)
	b.hl = b:CreateTexture(nil, "HIGHLIGHT")
	b.hl:SetAllPoints()
	b.hl:SetColorTexture(1, 1, 1, 0.06)
	b.text = Text(b, "GameFontHighlightSmall")
	b.text:SetPoint("LEFT", 14, 0)
	b.text:SetPoint("RIGHT", -6, 0)
	b.text:SetJustifyH("LEFT")
	b:SetScript("OnClick", function(self)
		if self.entry then lib:HubSelect(self.entry) end
	end)
	return b
end

local function CreateHub()
	local f = CreateFrame("Frame", "SexyEditModeHub", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(W, H)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetFrameLevel(50)
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	Backdrop(f)
	f:Hide()
	tinsert(UISpecialFrames, "SexyEditModeHub")

	f.band = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	f.band:SetPoint("TOPLEFT", 3, -3)
	f.band:SetPoint("TOPRIGHT", -3, -3)
	f.band:SetHeight(HEAD_H - 3)
	f.band:SetColorTexture(BAND[1], BAND[2], BAND[3], BAND[4])
	f.title = Text(f, "GameFontNormalLarge")
	f.title:SetPoint("LEFT", f.band, "LEFT", 10, 0)
	f.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	f.title:SetText(L.title)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 1, 1)
	close:SetScale(0.8)

	-- Seitenleiste
	f.sideBg = f:CreateTexture(nil, "BACKGROUND", nil, 0)
	f.sideBg:SetPoint("TOPLEFT", 3, -HEAD_H)
	f.sideBg:SetPoint("BOTTOMLEFT", 3, FOOT_H)
	f.sideBg:SetWidth(SIDE_W)
	f.sideBg:SetColorTexture(0.05, 0.04, 0.03, 0.9)
	f.sideLine = f:CreateTexture(nil, "ARTWORK")
	f.sideLine:SetPoint("TOPLEFT", f.sideBg, "TOPRIGHT", 0, 0)
	f.sideLine:SetPoint("BOTTOMLEFT", f.sideBg, "BOTTOMRIGHT", 0, 0)
	f.sideLine:SetWidth(1)
	f.sideLine:SetColorTexture(EDGE[1], EDGE[2], EDGE[3], 0.8)

	f.side = CreateFrame("ScrollFrame", nil, f)
	f.side:SetPoint("TOPLEFT", f.sideBg, "TOPLEFT", 0, -6)
	f.side:SetPoint("BOTTOMRIGHT", f.sideBg, "BOTTOMRIGHT", 0, 6)
	f.sideContent = CreateFrame("Frame", nil, f.side)
	f.sideContent:SetSize(SIDE_W, 10)
	f.side:SetScrollChild(f.sideContent)
	f.side:EnableMouseWheel(true)
	f.side:SetScript("OnMouseWheel", function(self, delta)
		local max = math.max(0, f.sideContent:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 30)))
	end)
	f.nav = {}

	-- Inhalt
	f.pageTitle = Text(f, "GameFontNormalLarge")
	f.pageTitle:SetPoint("TOPLEFT", f.sideBg, "TOPRIGHT", 18, -12)
	f.pageTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	f.scroll = CreateFrame("ScrollFrame", nil, f)
	f.scroll:SetPoint("TOPLEFT", f.sideBg, "TOPRIGHT", 14, -42)
	f.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, FOOT_H + 8)
	f.content = CreateFrame("Frame", nil, f.scroll)
	f.content:SetSize(CONTENT_W, 10)
	f.scroll:SetScrollChild(f.content)
	f.scroll:EnableMouseWheel(true)
	f.scroll:SetScript("OnMouseWheel", function(self, delta)
		local max = math.max(0, f.content:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 30)))
	end)
	f.rows = {}

	-- Fußleiste
	f.footLine = f:CreateTexture(nil, "ARTWORK")
	f.footLine:SetPoint("BOTTOMLEFT", 3, FOOT_H)
	f.footLine:SetPoint("BOTTOMRIGHT", -3, FOOT_H)
	f.footLine:SetHeight(1)
	f.footLine:SetColorTexture(EDGE[1], EDGE[2], EDGE[3], 0.8)
	local edit = FlatButton(f, L.editMode, 160, 26)
	edit:SetPoint("BOTTOMLEFT", 16, 11)
	edit:SetScript("OnClick", function()
		local m = _G.EditModeManagerFrame
		if not m then return end
		if m:IsShown() then HideUIPanel(m) else ShowUIPanel(m) end
	end)

	f:SetScript("OnShow", function() lib:BuildNav(); lib:BuildContent(true) end)
	return f
end

-- Seitenleiste ------------------------------------------------------------------------

function lib:BuildNav()
	local hub = self.hub
	if not hub then return end
	for _, it in ipairs(hub.nav) do it:Hide(); it:ClearAllPoints() end
	local n, y = 0, 0
	local function Take(height)
		n = n + 1
		local it = hub.nav[n]
		if not it then it = NavItem(hub.sideContent); hub.nav[n] = it end
		it:SetPoint("TOPLEFT", hub.sideContent, "TOPLEFT", 0, -y)
		it:SetPoint("TOPRIGHT", hub.sideContent, "TOPRIGHT", 0, -y)
		it:SetHeight(height or ROW_H)
		it:Show()
		y = y + (height or ROW_H)
		return it
	end

	for _, g in ipairs(Groups()) do
		if #g.entries > 0 then
			local h = Take(ROW_H + 6)
			h.entry = nil
			h:EnableMouse(false)
			h.sel:Hide()
			h.hl:Hide()
			h.text:SetFontObject("GameFontNormal")
			h.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
			h.text:SetText(g.addon.title .. (g.addon.version and ("  |cff9a8f72" .. g.addon.version .. "|r") or ""))
			for _, e in ipairs(g.entries) do
				local it = Take()
				it.entry = e
				it:EnableMouse(true)
				it.hl:Show()
				it.sel:SetShown(e == self.hubSelected)
				it.text:SetFontObject("GameFontHighlightSmall")
				it.text:SetTextColor(1, 1, 1)
				it.text:SetText(ShortName(e, g.addon.title))
			end
		end
	end
	hub.sideContent:SetHeight(math.max(1, y))
end

-- Inhalt ------------------------------------------------------------------------------

function lib:BuildContent(resetScroll)
	local hub, entry = self.hub, self.hubSelected
	if not hub then return end
	for _, r in ipairs(hub.rows) do r:Hide(); r:ClearAllPoints() end
	hub.rows = {}
	if not entry then
		hub.pageTitle:SetText(#self.order == 0 and L.empty or L.pick)
		hub.content:SetHeight(1)
		return
	end
	hub.pageTitle:SetText(entry.name)
	local y, rows = self:BuildRows(hub.content, self.hubRowCache, self:EntrySpecs(entry), entry, CONTENT_W)
	hub.rows = rows
	hub.content:SetHeight(math.max(1, y))
	if resetScroll then hub.scroll:SetVerticalScroll(0) end
end

-- Vom Edit-Mode-Dialog aufgerufen, wenn sich Zeilen ändern (Aufklappen, neue Einträge, ...)
function lib:RebuildHub()
	if self:HubIsShown() then self:BuildContent(false) end
end

function lib:RefreshHub()
	if not self:HubIsShown() then return end
	for _, r in ipairs(self.hub.rows) do
		if r.Update then r:Update() end
	end
end

-- Öffnen ------------------------------------------------------------------------------

function lib:HubIsShown() return self.hub and self.hub:IsShown() and true or false end

function lib:HubSelect(entry)
	if not self.hub then self.hub = CreateHub() end
	self.hubSelected = entry
	if self.hub:IsShown() then
		self:BuildNav()
		self:BuildContent(true)
	else
		self.hub:Show()   -- OnShow baut Leiste und Inhalt auf
	end
end

function lib:ToggleHub()
	if not self.hub then self.hub = CreateHub() end
	if self.hub:IsShown() then
		self.hub:Hide()
		return
	end
	if not self.hubSelected then
		local g = Groups()
		for _, grp in ipairs(g) do
			if grp.entries[1] then self.hubSelected = grp.entries[1]; break end
		end
	end
	self.hub:Show()
end

-- Öffnet den Hub beim ersten Fenster des Addons (oder bei einem bestimmten Fenster)
function lib:OpenHub(addonOrEntry)
	local entry = addonOrEntry
	if type(addonOrEntry) == "string" then
		entry = nil
		for _, grp in ipairs(Groups()) do
			if grp.addon.id == addonOrEntry and grp.entries[1] then entry = grp.entries[1] break end
		end
	end
	if entry then self:HubSelect(entry) else self:ToggleHub() end
end

-- Minimap-Knopf, /sem ------------------------------------------------------------------

SLASH_SEXYEDITMODE1 = "/sem"
SLASH_SEXYEDITMODE2 = "/sexyeditmode"
SlashCmdList.SEXYEDITMODE = function(msg)
	msg = (msg or ""):lower()
	if msg == "minimap" then
		local icon = LibStub("LibDBIcon-1.0", true)
		local s = SexyEditModeDB and SexyEditModeDB.minimap
		if not (icon and s) then return end
		s.hide = not s.hide
		if s.hide then icon:Hide("SexyEditMode") else icon:Show("SexyEditMode") end
		print("|cffe8c26aSexyEditMode|r: " .. (s.hide and L.minimapHidden or L.minimapShown))
		return
	end
	lib:ToggleHub()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	SexyEditModeDB = SexyEditModeDB or {}
	SexyEditModeDB.minimap = SexyEditModeDB.minimap or {}
	local s = SexyEditModeDB.minimap
	if not s.minimapPos then s.minimapPos = 160 end   -- eigener Startwinkel, damit er nicht auf anderen Knöpfen liegt
	local ldb = LibStub("LibDataBroker-1.1", true)
	local icon = LibStub("LibDBIcon-1.0", true)
	if not (ldb and icon) then return end
	local obj = ldb:NewDataObject("SexyEditMode", {
		type = "launcher",
		label = "SexyEditMode",
		text = "SexyEditMode",
		icon = "Interface/AddOns/SexyEditMode/icon.tga",
		OnClick = function(_, button)
			if button == "RightButton" then
				local m = _G.EditModeManagerFrame
				if m then
					if m:IsShown() then HideUIPanel(m) else ShowUIPanel(m) end
				end
			else
				lib:ToggleHub()
			end
		end,
		OnTooltipShow = function(tip)
			if not (tip and tip.AddLine) then return end
			tip:AddLine("SexyEditMode")
			tip:AddLine(L.minimapTip, 1, 1, 1)
			tip:AddLine(L.minimapTip2, 1, 1, 1)
		end,
	})
	if obj and not icon:IsRegistered("SexyEditMode") then icon:Register("SexyEditMode", obj, s) end
end)
