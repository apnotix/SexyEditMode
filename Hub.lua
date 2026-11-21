-- Hub: das gemeinsame Einstellungsfenster aller Sexy-Addons.
--
-- Jedes Addon meldet sich einmal an:
--   LibStub("SexyEditMode-1.0"):RegisterAddon("SexyLoot", { title = "SexyLoot", version = "0.1.24" })
-- und gibt bei seinen :Register-Aufrufen `addon = "SexyLoot"` an (optional `category` für die
-- Zwischenüberschrift in der Seitenleiste und `description` für den Text über den Einstellungen).
-- Die Fenster erscheinen links in der Seitenleiste (nach Addon gruppiert), rechts stehen die Einstellungen
-- des gewählten Fensters. Es sind dieselben Zeilen wie im Edit-Mode-Dialog (check, slider, select, ...).
--
-- Öffnen: /sem, Minimap-Knopf (Linksklick), lib:ToggleHub(), lib:OpenHub("SexyLoot").

local lib = LibStub("SexyEditMode-1.0", true)
if not (lib and lib.ui) then return end

local ui = lib.ui
local Backdrop, Text, FlatButton = ui.Backdrop, ui.Text, ui.FlatButton

local de = GetLocale() == "deDE"
local L = {
	title = de and "Sexy Einstellungen" or "Sexy Settings",
	editMode = de and "Edit Mode öffnen" or "Open Edit Mode",
	empty = de and "Kein Sexy-Addon geladen." or "No Sexy addon loaded.",
	pick = de and "Wähle links ein Fenster." or "Pick a window on the left.",
	other = de and "Sonstige" or "Other",
	windows = de and "%d Fenster" or "%d windows",
	applied = de and "Änderungen gelten sofort" or "Changes apply immediately",
	minimapTip = de and "Linksklick: Einstellungen" or "Left click: settings",
	minimapTip2 = de and "Rechtsklick: Edit Mode" or "Right click: Edit Mode",
	minimapShown = de and "Minimap-Knopf eingeblendet" or "minimap button shown",
	minimapHidden = de and "Minimap-Knopf ausgeblendet" or "minimap button hidden",
}

-- Look wie im Mockup A: dunkelbraune Fläche, Goldrand, Titelband, dunkle Seitenleiste, Fußleiste
local C = {
	bg = { 0.141, 0.102, 0.067, 0.98 },
	edge = { 0.78, 0.635, 0.29, 1 },
	band = { 0.227, 0.169, 0.106, 1 },
	side = { 0.114, 0.078, 0.05, 1 },
	line = { 0.24, 0.185, 0.122, 1 },
	gold = { 0.91, 0.76, 0.42 },
	title = { 0.96, 0.89, 0.69 },
	text = { 0.85, 0.80, 0.66 },
	muted = { 0.71, 0.65, 0.53 },
	sel = { 0.227, 0.169, 0.106, 1 },
}

local W, H = 900, 600
local SIDE_W = 230
local HEAD_H = 40
local FOOT_H = 56
local PAGE_HEAD = 64
local CONTENT_W = W - SIDE_W - 56
local ROW_H = 28

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

-- Fenster nach Addon und Kategorie gruppiert:
-- { { addon = ..., cats = { { name = <Kategorie oder nil>, entries = { ... } }, ... }, count = n }, ... }
local function Groups()
	local list, byId = {}, {}
	local function Group(id)
		if not byId[id] then
			local a = lib.addons[id] or lib:RegisterAddon(id, { title = id == "_other" and L.other or id })
			byId[id] = { addon = a, cats = {}, byCat = {}, count = 0 }
			list[#list + 1] = byId[id]
		end
		return byId[id]
	end
	for _, id in ipairs(lib.addonOrder) do Group(id) end
	for _, e in ipairs(lib.order) do
		local g = Group(e.addon or "_other")
		local key = e.category or ""
		local cat = g.byCat[key]
		if not cat then
			cat = { name = e.category, entries = {} }
			g.byCat[key] = cat
			g.cats[#g.cats + 1] = cat
		end
		table.insert(cat.entries, e)
		g.count = g.count + 1
	end
	return list
end

local function FirstEntry()
	for _, g in ipairs(Groups()) do
		if g.cats[1] then return g.cats[1].entries[1] end
	end
end

-- "SexyLoot: Rollfenster" wird in der Seitenleiste zu "Rollfenster"
local function ShortName(entry, title)
	local name = entry.name or "?"
	for _, prefix in ipairs({ title .. ": ", title .. " " }) do
		if name:sub(1, #prefix) == prefix then return name:sub(#prefix + 1) end
	end
	return name
end

-- Fenster ----------------------------------------------------------------------------

local function Solid(parent, layer, color, sub)
	local t = parent:CreateTexture(nil, layer, nil, sub or 0)
	t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
	return t
end

local function NavItem(parent)
	local b = CreateFrame("Button", nil, parent)
	b.sel = Solid(b, "BACKGROUND", C.sel)
	b.sel:SetAllPoints()
	b.bar = Solid(b, "ARTWORK", { C.gold[1], C.gold[2], C.gold[3], 1 })
	b.bar:SetPoint("TOPLEFT")
	b.bar:SetPoint("BOTTOMLEFT")
	b.bar:SetWidth(3)
	b.hl = Solid(b, "HIGHLIGHT", { 1, 1, 1, 0.05 })
	b.hl:SetAllPoints()
	b.dot = Solid(b, "ARTWORK", { 0.42, 0.35, 0.24, 1 })
	b.dot:SetSize(6, 6)
	b.dot:SetPoint("LEFT", 16, 0)
	b.text = Text(b, "GameFontHighlight")
	b.text:SetPoint("LEFT", 32, 0)
	b.text:SetPoint("RIGHT", -8, 0)
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
	Backdrop(f, C.bg, C.edge)
	f:Hide()
	tinsert(UISpecialFrames, "SexyEditModeHub")

	-- Titelband mit Titel, Fenster-Zähler und Schließen-Knopf
	f.band = Solid(f, "BACKGROUND", C.band, 1)
	f.band:SetPoint("TOPLEFT", 3, -3)
	f.band:SetPoint("TOPRIGHT", -3, -3)
	f.band:SetHeight(HEAD_H - 3)
	f.bandLine = Solid(f, "ARTWORK", C.edge)
	f.bandLine:SetPoint("TOPLEFT", f.band, "BOTTOMLEFT")
	f.bandLine:SetPoint("TOPRIGHT", f.band, "BOTTOMRIGHT")
	f.bandLine:SetHeight(1)
	f.title = Text(f, "GameFontNormalLarge", 18)
	f.title:SetPoint("LEFT", f.band, "LEFT", 14, 0)
	f.title:SetTextColor(C.title[1], C.title[2], C.title[3])
	f.title:SetText(L.title)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 1, 1)
	close:SetScale(0.85)
	close:SetFrameLevel(f:GetFrameLevel() + 20)   -- über Titelband und Seitenleiste, sonst fängt ein anderes Fenster den Klick ab
	close:SetScript("OnClick", function() f:Hide() end)
	f.badge = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f.badge:SetHeight(20)
	f.badge:SetPoint("RIGHT", close, "LEFT", -12, 0)
	Backdrop(f.badge, { 0.11, 0.075, 0.047, 1 }, { 0.42, 0.35, 0.24, 1 })
	f.badge.text = Text(f.badge, "GameFontHighlightSmall")
	f.badge.text:SetPoint("CENTER")
	f.badge.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])

	-- Seitenleiste
	f.sideBg = Solid(f, "BACKGROUND", C.side, 0)
	f.sideBg:SetPoint("TOPLEFT", 3, -HEAD_H - 1)
	f.sideBg:SetPoint("BOTTOMLEFT", 3, FOOT_H)
	f.sideBg:SetWidth(SIDE_W)
	f.sideLine = Solid(f, "ARTWORK", C.line)
	f.sideLine:SetPoint("TOPLEFT", f.sideBg, "TOPRIGHT")
	f.sideLine:SetPoint("BOTTOMLEFT", f.sideBg, "BOTTOMRIGHT")
	f.sideLine:SetWidth(1)

	f.side = CreateFrame("ScrollFrame", nil, f)
	f.side:SetPoint("TOPLEFT", f.sideBg, "TOPLEFT", 0, -8)
	f.side:SetPoint("BOTTOMRIGHT", f.sideBg, "BOTTOMRIGHT", 0, 8)
	f.sideContent = CreateFrame("Frame", nil, f.side)
	f.sideContent:SetSize(SIDE_W, 10)
	f.side:SetScrollChild(f.sideContent)
	f.side:EnableMouseWheel(true)
	f.side:SetScript("OnMouseWheel", function(self, delta)
		local max = math.max(0, f.sideContent:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 30)))
	end)
	f.nav = {}

	-- Inhalt: Seitentitel, Beschreibung, Einstellungen
	f.pageTitle = Text(f, "GameFontNormalLarge", 22)
	f.pageTitle:SetPoint("TOPLEFT", f.sideBg, "TOPRIGHT", 24, -16)
	f.pageTitle:SetTextColor(C.title[1], C.title[2], C.title[3])
	f.pageDesc = Text(f, "GameFontHighlightSmall", 12)
	f.pageDesc:SetPoint("TOPLEFT", f.pageTitle, "BOTTOMLEFT", 0, -6)
	f.pageDesc:SetWidth(CONTENT_W)
	f.pageDesc:SetJustifyH("LEFT")
	f.pageDesc:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	f.scroll = CreateFrame("ScrollFrame", nil, f)
	f.scroll:SetPoint("TOPLEFT", f.sideBg, "TOPRIGHT", 18, -PAGE_HEAD - 8)
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
	f.foot = Solid(f, "BACKGROUND", C.side, 0)
	f.foot:SetPoint("BOTTOMLEFT", 3, 3)
	f.foot:SetPoint("BOTTOMRIGHT", -3, 3)
	f.foot:SetHeight(FOOT_H - 3)
	f.footLine = Solid(f, "ARTWORK", C.line)
	f.footLine:SetPoint("BOTTOMLEFT", f.foot, "TOPLEFT")
	f.footLine:SetPoint("BOTTOMRIGHT", f.foot, "TOPRIGHT")
	f.footLine:SetHeight(1)
	local edit = FlatButton(f, L.editMode, 170, 30)
	edit:SetPoint("BOTTOMLEFT", 18, 13)
	edit.text:SetFontObject("GameFontHighlight")
	-- Edit Mode für das Addon des gerade gewählten Fensters (Seiten ohne Addon: für alle)
	edit:SetScript("OnClick", function()
		local e = lib.hubSelected
		lib:ToggleEditMode(e and e.addon)
	end)
	f.hint = Text(f, "GameFontHighlightSmall")
	f.hint:SetPoint("BOTTOMRIGHT", -18, 21)
	f.hint:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	f.hint:SetText(L.applied)

	f:SetScript("OnShow", function() lib:BuildNav(); lib:BuildContent(true) end)
	return f
end

-- Zeilen im neuen Look (Mockup A) -------------------------------------------------------
-- Gleiche Zeilenarten wie im Edit-Mode-Dialog, aber flacher: Beschriftung links, Bedienelement rechts,
-- dünne Trennlinie darunter. Abschnitte (header) sind immer offen; "link"-Zeilen gibt es hier nicht,
-- weil die Seitenleiste schon zu allen Fenstern führt.

local HUBROWS = {}
local ROW_H2 = 42
local LABEL_W = 300

local function Outline(parent, layer)
	local t = Solid(parent, layer or "BACKGROUND", { 0.45, 0.37, 0.22, 1 })
	t:SetPoint("TOPLEFT", -1, 1)
	t:SetPoint("BOTTOMRIGHT", 1, -1)
	return t
end

local function Decorate(row, spec, noLine)
	if not noLine then
		row.line = Solid(row, "BACKGROUND", C.line)
		row.line:SetPoint("BOTTOMLEFT")
		row.line:SetPoint("BOTTOMRIGHT")
		row.line:SetHeight(1)
	end
	row.label = Text(row, "GameFontHighlight", 13)
	row.label:SetPoint("LEFT", 2, 0)
	local parent = row:GetParent()
	row.label:SetWidth(math.floor(((parent and parent:GetWidth()) or 614) * 0.48))
	row.label:SetJustifyH("LEFT")
	row.label:SetTextColor(C.text[1], C.text[2], C.text[3])
	row.label:SetText(spec.name or "")
	if spec.tooltip and row.EnableMouse then
		row:EnableMouse(true)
		row:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(spec.tooltip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", GameTooltip_Hide)
	end
	return row.label
end

function HUBROWS.header(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	row.text = Text(row, "GameFontNormal", 14)
	row.text:SetPoint("BOTTOMLEFT", 2, 8)
	row.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	row.text:SetText(spec.name or "")
	row.line = Solid(row, "BACKGROUND", { C.edge[1], C.edge[2], C.edge[3], 0.55 })
	row.line:SetPoint("BOTTOMLEFT")
	row.line:SetPoint("BOTTOMRIGHT")
	row.line:SetHeight(1)
	return row, 44
end

function HUBROWS.divider(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	if spec.name and spec.name ~= "" then
		row.text = Text(row, "GameFontNormalSmall")
		row.text:SetPoint("BOTTOMLEFT", 2, 6)
		row.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
		row.text:SetText(spec.name)
	end
	row.line = Solid(row, "BACKGROUND", C.line)
	row.line:SetPoint("BOTTOMLEFT")
	row.line:SetPoint("BOTTOMRIGHT")
	row.line:SetHeight(1)
	return row, 30
end

function HUBROWS.check(parent, spec)
	local row = CreateFrame("Button", nil, parent)
	Decorate(row, spec)
	row.hl = Solid(row, "HIGHLIGHT", { 1, 1, 1, 0.04 })
	row.hl:SetAllPoints()
	row.box = CreateFrame("Frame", nil, row)
	row.box:SetSize(22, 22)
	row.box:SetPoint("RIGHT", -4, 0)
	Outline(row.box)
	Solid(row.box, "BORDER", { 0.07, 0.05, 0.035, 1 }):SetAllPoints()
	row.mark = Solid(row.box, "OVERLAY", { C.gold[1], C.gold[2], C.gold[3], 1 })
	row.mark:SetPoint("TOPLEFT", 4, -4)
	row.mark:SetPoint("BOTTOMRIGHT", -4, 4)
	function row:Update() self.mark:SetShown(spec.get() and true or false) end
	row:SetScript("OnClick", function()
		spec.set(not spec.get())
		lib:RefreshDialog()
	end)
	row:Update()
	return row, ROW_H2
end

function HUBROWS.slider(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	Decorate(row, spec)
	row.value = Text(row, "GameFontHighlight", 13)
	row.value:SetPoint("RIGHT", -4, 0)
	row.value:SetWidth(52)
	row.value:SetJustifyH("RIGHT")
	row.value:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	local s = CreateFrame("Slider", nil, row)
	s:SetOrientation("HORIZONTAL")
	s:SetPoint("RIGHT", row.value, "LEFT", -14, 0)
	s:SetSize(200, 16)
	local track = Solid(s, "BACKGROUND", { 0.04, 0.03, 0.02, 1 })
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	track:SetHeight(4)
	s:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
	local thumb = s:GetThumbTexture()
	thumb:SetSize(10, 16)
	thumb:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1)
	s:SetMinMaxValues(spec.min, spec.max)
	s:SetValueStep(spec.step or 1)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	local fmt = spec.format or function(v)
		if spec.step and spec.step < 1 then return string.format("%.2f", v) end
		return tostring(math.floor(v + 0.5))
	end
	local updating = false
	function row:Update()
		local v = spec.get() or spec.min
		updating = true
		s:SetValue(v)
		updating = false
		self.value:SetText(fmt(v))
	end
	s:SetScript("OnValueChanged", function(_, v)
		if updating then return end
		if spec.step and spec.step > 0 then v = math.floor(v / spec.step + 0.5) * spec.step end
		row.value:SetText(fmt(v))
		spec.set(v)
	end)
	row:Update()
	return row, ROW_H2
end

-- Auswahl: bis vier Möglichkeiten als Umschalter, sonst ein Knopf mit Liste
function HUBROWS.select(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	Decorate(row, spec)
	local options = spec.options
	if type(options) == "function" then options = options() end
	options = options or {}

	-- Umschalter nur, wenn alle Möglichkeiten nebeneinander passen; sonst Knopf mit Liste
	local fits = #options > 0 and #options <= 4
	if fits then
		local probe = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		probe:SetAlpha(0)
		local total = 0
		for _, o in ipairs(options) do
			probe:SetText(o.label or tostring(o.value))
			total = total + math.max(56, probe:GetStringWidth() + 26)
		end
		fits = total <= 300
	end

	if fits then
		row.segs = {}
		local total = 0
		local group = CreateFrame("Frame", nil, row)
		group:SetHeight(26)
		group:SetPoint("RIGHT", -4, 0)
		Outline(group)
		for i, o in ipairs(options) do
			local b = CreateFrame("Button", nil, group)
			b:SetHeight(26)
			b.bg = Solid(b, "BORDER", { 0.07, 0.05, 0.035, 1 })
			b.bg:SetAllPoints()
			b.hl = Solid(b, "HIGHLIGHT", { 1, 1, 1, 0.08 })
			b.hl:SetAllPoints()
			b.text = Text(b, "GameFontHighlightSmall", 12)
			b.text:SetPoint("CENTER")
			b.text:SetText(o.label or tostring(o.value))
			local w = math.max(56, b.text:GetStringWidth() + 26)
			b:SetWidth(w)
			b:SetPoint("LEFT", group, "LEFT", total, 0)
			total = total + w
			b:SetScript("OnClick", function()
				spec.set(o.value)
				lib:RefreshDialog()
			end)
			b.value = o.value
			row.segs[i] = b
		end
		group:SetWidth(math.max(1, total))
		function row:Update()
			local cur = spec.get()
			for _, b in ipairs(self.segs) do
				local on = b.value == cur
				b.bg:SetColorTexture(on and C.gold[1] or 0.07, on and C.gold[2] or 0.05, on and C.gold[3] or 0.035, 1)
				b.text:SetTextColor(on and 0.14 or C.text[1], on and 0.1 or C.text[2], on and 0.07 or C.text[3])
			end
		end
	else
		local b = CreateFrame("Button", nil, row)
		b:SetSize(230, 26)
		b:SetPoint("RIGHT", -4, 0)
		Outline(b)
		Solid(b, "BORDER", { 0.07, 0.05, 0.035, 1 }):SetAllPoints()
		Solid(b, "HIGHLIGHT", { 1, 1, 1, 0.08 }):SetAllPoints()
		b.text = Text(b, "GameFontHighlightSmall", 12)
		b.text:SetPoint("LEFT", 10, 0)
		b.text:SetPoint("RIGHT", -22, 0)
		b.text:SetJustifyH("LEFT")
		b.text:SetWordWrap(false)
		b.arrow = Text(b, "GameFontNormalSmall")
		b.arrow:SetPoint("RIGHT", -8, 0)
		b.arrow:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
		b.arrow:SetText("v")
		b:SetScript("OnClick", function(self) ui.OpenSelectMenu(self, spec) end)
		function row:Update()
			local cur = spec.get()
			local label, shown = tostring(cur), nil
			local list = spec.options
			if type(list) == "function" then list = list() end
			for _, o in ipairs(list or {}) do
				if o.value == cur then label, shown = o.label or tostring(o.value), o break end
			end
			b.text:SetText(label)
			ui.ApplyOptionFont(b.text, shown, "GameFontHighlightSmall", 12)
		end
	end
	row:Update()
	return row, ROW_H2
end

function HUBROWS.color(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	Decorate(row, spec)
	local b = CreateFrame("Button", nil, row)
	b:SetSize(48, 22)
	b:SetPoint("RIGHT", -4, 0)
	Outline(b)
	b.swatch = Solid(b, "BORDER", { 1, 1, 1, 1 })
	b.swatch:SetAllPoints()
	function row:Update()
		local r, g, bl = spec.get()
		b.swatch:SetColorTexture(r or 1, g or 1, bl or 1, 1)
	end
	b:SetScript("OnClick", function()
		local r, g, bl, a = spec.get()
		local function Apply()
			local nr, ng, nb = ColorPickerFrame:GetColorRGB()
			local na = spec.hasAlpha and ColorPickerFrame:GetColorAlpha() or 1
			spec.set(nr, ng, nb, na)
			lib:RefreshDialog()
		end
		ColorPickerFrame:SetupColorPickerAndShow({
			r = r or 1, g = g or 1, b = bl or 1, opacity = a or 1, hasOpacity = spec.hasAlpha and true or false,
			swatchFunc = Apply, opacityFunc = Apply,
			cancelFunc = function()
				spec.set(r or 1, g or 1, bl or 1, a or 1)
				lib:RefreshDialog()
			end,
		})
	end)
	row:Update()
	return row, ROW_H2
end

function HUBROWS.button(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	local b = CreateFrame("Button", nil, row)
	b:SetPoint("LEFT", 2, 0)
	b:SetHeight(28)
	Outline(b)
	Solid(b, "BORDER", { 0.07, 0.05, 0.035, 1 }):SetAllPoints()
	Solid(b, "HIGHLIGHT", { 1, 1, 1, 0.08 }):SetAllPoints()
	b.text = Text(b, "GameFontHighlight", 13)
	b.text:SetPoint("CENTER")
	b.text:SetTextColor(C.title[1], C.title[2], C.title[3])
	b.text:SetText(spec.name or "")
	b:SetWidth(math.max(160, b.text:GetStringWidth() + 36))
	b:SetScript("OnClick", function()
		if spec.onClick then spec.onClick() end
		lib:RefreshDialog()
	end)
	function row:Update() end
	return row, 40
end

-- Verweis auf ein zugehöriges Fenster (nur im kleinen Edit-Mode-Dialog; im Hub führt die Seitenleiste dorthin)
function HUBROWS.link(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	local b = CreateFrame("Button", nil, row)
	b:SetPoint("TOPLEFT", 2, -6)
	b:SetPoint("TOPRIGHT", -4, -6)
	b:SetHeight(28)
	Outline(b)
	Solid(b, "BORDER", C.band):SetAllPoints()
	Solid(b, "HIGHLIGHT", { 1, 1, 1, 0.08 }):SetAllPoints()
	b.text = Text(b, "GameFontNormal", 13)
	b.text:SetPoint("LEFT", 10, 0)
	b.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	b.text:SetText(spec.name or "")
	b.arrow = Text(b, "GameFontNormal", 13)
	b.arrow:SetPoint("RIGHT", -10, 0)
	b.arrow:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
	b.arrow:SetText(">>")
	b:SetScript("OnClick", function()
		local f = spec.frame
		if type(f) == "function" then f = f() end
		local e = f and lib.entries[f]
		if e then lib:Navigate(e) end
	end)
	function row:Update() end
	return row, 40
end

-- Textfeld mit aktuellem Wert: Enter oder Verlassen des Felds übernimmt ihn, Esc verwirft
function HUBROWS.input(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	Decorate(row, spec)
	local box = CreateFrame("EditBox", nil, row)
	box:SetAutoFocus(false)
	box:SetFontObject("GameFontHighlight")
	box:SetHeight(26)
	box:SetPoint("RIGHT", -4, 0)
	box:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
	box:SetTextInsets(8, 8, 0, 0)
	box:SetMaxLetters(spec.maxLetters or 120)
	Outline(box)
	Solid(box, "BORDER", { 0.07, 0.05, 0.035, 1 }):SetAllPoints()
	box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	box:SetScript("OnEscapePressed", function(self) self.cancel = true; self:ClearFocus() end)
	box:SetScript("OnEditFocusLost", function(self)
		if self.cancel then
			self.cancel = nil
		else
			spec.set(box:GetText() or "")
			lib:RefreshDialog()
		end
		row:Update()
	end)
	function row:Update()
		if not box:HasFocus() then box:SetText(spec.get() or "") end
	end
	row:Update()
	return row, ROW_H2
end

-- Zeile mit Name links und einem Knopf rechts (z. B. Liste mit "Einblenden")
function HUBROWS.buttonrow(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	row.line = Solid(row, "BACKGROUND", C.line)
	row.line:SetPoint("BOTTOMLEFT")
	row.line:SetPoint("BOTTOMRIGHT")
	row.line:SetHeight(1)
	local b = CreateFrame("Button", nil, row)
	b:SetSize(110, 26)
	b:SetPoint("RIGHT", -4, 0)
	Outline(b)
	Solid(b, "BORDER", { 0.07, 0.05, 0.035, 1 }):SetAllPoints()
	Solid(b, "HIGHLIGHT", { 1, 1, 1, 0.08 }):SetAllPoints()
	b.text = Text(b, "GameFontHighlight", 13)
	b.text:SetPoint("CENTER")
	b.text:SetTextColor(C.title[1], C.title[2], C.title[3])
	b.text:SetText(spec.text or "")
	b:SetScript("OnClick", function()
		if spec.onClick then spec.onClick() end
		lib:RefreshDialog()
	end)
	row.label = Text(row, "GameFontHighlight", 13)
	row.label:SetPoint("LEFT", 2, 0)
	row.label:SetPoint("RIGHT", b, "LEFT", -12, 0)
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)
	row.label:SetTextColor(C.text[1], C.text[2], C.text[3])
	row.label:SetText(spec.name or "")
	-- Mouseover: spec.onEnter(frame) zeigt z. B. einen Tooltip, spec.onLeave() räumt ihn weg (Standard: GameTooltip ausblenden)
	if spec.onEnter then
		row:EnableMouse(true)
		row:SetScript("OnEnter", function(self) spec.onEnter(self) end)
		row:SetScript("OnLeave", function()
			if spec.onLeave then spec.onLeave() else GameTooltip:Hide() end
		end)
	end
	function row:Update() end
	return row, ROW_H2
end

-- Tastenwahl: der Knopf zeigt die gewählte Taste, ein Klick startet die Abfrage
function HUBROWS.keybind(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	Decorate(row, spec)
	local right = -4
	if spec.onClear then
		local x = CreateFrame("Button", nil, row)
		x:SetSize(26, 26)
		x:SetPoint("RIGHT", -4, 0)
		Outline(x)
		Solid(x, "BORDER", { 0.07, 0.05, 0.035, 1 }):SetAllPoints()
		Solid(x, "HIGHLIGHT", { 1, 1, 1, 0.08 }):SetAllPoints()
		x.text = Text(x, "GameFontHighlight", 13)
		x.text:SetPoint("CENTER")
		x.text:SetText("x")
		x:SetScript("OnClick", function()
			spec.onClear()
			lib:RefreshDialog()
		end)
		right = -38
	end
	local b = CreateFrame("Button", nil, row)
	b:SetSize(210, 26)
	b:SetPoint("RIGHT", right, 0)
	Outline(b)
	Solid(b, "BORDER", { 0.07, 0.05, 0.035, 1 }):SetAllPoints()
	Solid(b, "HIGHLIGHT", { 1, 1, 1, 0.08 }):SetAllPoints()
	b.text = Text(b, "GameFontHighlight", 13)
	b.text:SetPoint("CENTER")
	b:SetScript("OnClick", function()
		if spec.onClick then spec.onClick() end
		lib:RefreshDialog()
	end)
	function row:Update()
		local waiting = spec.waiting and spec.waiting()
		local key = spec.get and spec.get()
		if waiting then
			b.text:SetText(lib.L.pressKey)
			b.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
		elseif key and key ~= "" then
			b.text:SetText(key)
			b.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
		else
			b.text:SetText(lib.L.unbound)
			b.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
		end
	end
	row:Update()
	return row, ROW_H2
end

function HUBROWS.edit(parent, spec)
	local row = CreateFrame("Frame", nil, parent)
	row.label = Text(row, "GameFontHighlight", 13)
	row.label:SetPoint("TOPLEFT", 2, -6)
	row.label:SetTextColor(C.text[1], C.text[2], C.text[3])
	row.label:SetText(spec.name or "")
	local box = CreateFrame("EditBox", nil, row)
	box:SetAutoFocus(false)
	box:SetFontObject("GameFontHighlight")
	box:SetSize(320, 26)
	box:SetPoint("TOPLEFT", 2, -26)
	box:SetTextInsets(8, 8, 0, 0)
	box:SetMaxLetters(80)
	Outline(box)
	Solid(box, "BORDER", { 0.07, 0.05, 0.035, 1 }):SetAllPoints()
	local add = CreateFrame("Button", nil, row)
	add:SetSize(40, 26)
	add:SetPoint("LEFT", box, "RIGHT", 10, 0)
	Outline(add)
	Solid(add, "BORDER", { ui.GREEN[1], ui.GREEN[2], ui.GREEN[3], 1 }):SetAllPoints()
	Solid(add, "HIGHLIGHT", { 1, 1, 1, 0.15 }):SetAllPoints()
	add.text = Text(add, "GameFontHighlight", 14)
	add.text:SetPoint("CENTER")
	add.text:SetText("+")
	local function submit()
		local text = (box:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
		box:ClearFocus()
		if text ~= "" and spec.onSubmit then
			box:SetText("")
			spec.onSubmit(text)
			lib:RebuildDialog()
		end
	end
	box:SetScript("OnEnterPressed", submit)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	add:SetScript("OnClick", submit)
	function row:Update() end
	return row, 64
end

-- X und Y der Position
function HUBROWS.position(parent, spec, entry)
	local row = CreateFrame("Frame", nil, parent)
	Decorate(row, { name = lib.L.position })
	row.boxes = {}
	local function Make(label, key, rightOffset)
		local e = CreateFrame("EditBox", nil, row)
		e:SetSize(72, 26)
		e:SetPoint("RIGHT", rightOffset, 0)
		e:SetAutoFocus(false)
		e:SetFontObject("GameFontHighlight")
		e:SetJustifyH("CENTER")
		Outline(e)
		Solid(e, "BORDER", { 0.07, 0.05, 0.035, 1 }):SetAllPoints()
		local fs = Text(row, "GameFontNormalSmall")
		fs:SetPoint("RIGHT", e, "LEFT", -8, 0)
		fs:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
		fs:SetText(label)
		e:SetScript("OnEnterPressed", function(self)
			local v = tonumber(self:GetText())
			self:ClearFocus()
			if v then
				entry.db[key] = v
				ui.ApplyPosition(entry)
				if entry.onMoved then entry.onMoved(entry.frame) end
			end
			lib:RefreshDialog()
		end)
		e:SetScript("OnEscapePressed", function(self) self:ClearFocus() lib:RefreshDialog() end)
		row.boxes[key] = e
	end
	Make("Y", "y", -4)
	Make("X", "x", -118)
	function row:Update()
		local x, y = entry.db.x, entry.db.y
		if not (x and y) then x, y = entry.frame:GetLeft(), entry.frame:GetBottom() end
		if not self.boxes.x:HasFocus() then self.boxes.x:SetText(x and string.format("%d", x + 0.5) or "") end
		if not self.boxes.y:HasFocus() then self.boxes.y:SetText(y and string.format("%d", y + 0.5) or "") end
	end
	row:Update()
	return row, ROW_H2
end

lib.ShortName = ShortName   -- für die Tabs im Edit-Mode-Dialog

-- Der kleine Edit-Mode-Dialog übernimmt Zeilen und Farben des Hubs (siehe CreateDialog in SexyEditMode.lua)
lib.HubStyle = { rows = HUBROWS, C = C }

-- Seitenleiste ------------------------------------------------------------------------

function lib:BuildNav()
	local hub = self.hub
	if not hub then return end
	for _, it in ipairs(hub.nav) do it:Hide(); it:ClearAllPoints() end
	local n, y, total = 0, 0, 0

	local function Take(height)
		n = n + 1
		local it = hub.nav[n]
		if not it then it = NavItem(hub.sideContent); hub.nav[n] = it end
		it:SetPoint("TOPLEFT", hub.sideContent, "TOPLEFT", 0, -y)
		it:SetPoint("TOPRIGHT", hub.sideContent, "TOPRIGHT", 0, -y)
		it:SetHeight(height)
		it:Show()
		y = y + height
		return it
	end

	-- Überschrift: kein Klick, keine Fläche
	local function Heading(text, big, gapBefore)
		y = y + (gapBefore or 0)
		local h = Take(big and 28 or 24)
		h.entry = nil
		h:EnableMouse(false)
		h.sel:Hide(); h.bar:Hide(); h.hl:Hide(); h.dot:Hide()
		h.text:ClearAllPoints()
		h.text:SetPoint("LEFT", 16, 0)
		h.text:SetPoint("RIGHT", -8, 0)
		if big then
			h.text:SetFontObject("GameFontNormal")
			h.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
		else
			h.text:SetFontObject("GameFontNormalSmall")
			h.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
		end
		h.text:SetText(text)
	end

	for _, g in ipairs(Groups()) do
		if g.count > 0 then
			total = total + g.count
			Heading(g.addon.title .. (g.addon.version and ("  |cff9a8f72" .. g.addon.version .. "|r") or ""), true, n > 0 and 10 or 0)
			for _, cat in ipairs(g.cats) do
				if cat.name then Heading(cat.name:upper(), false, 4) end
				for _, e in ipairs(cat.entries) do
					local it = Take(ROW_H)
					local selected = e == self.hubSelected
					it.entry = e
					it:EnableMouse(true)
					it.hl:Show()
					it.dot:Show()
					it.sel:SetShown(selected)
					it.bar:SetShown(selected)
					if selected then
						it.dot:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
						it.text:SetTextColor(C.title[1], C.title[2], C.title[3])
					else
						it.dot:SetColorTexture(0.42, 0.35, 0.24, 1)
						it.text:SetTextColor(C.text[1], C.text[2], C.text[3])
					end
					it.text:ClearAllPoints()
					it.text:SetPoint("LEFT", 32, 0)
					it.text:SetPoint("RIGHT", -8, 0)
					it.text:SetFontObject("GameFontHighlight")
					it.text:SetText(ShortName(e, g.addon.title))
				end
			end
		end
	end
	hub.sideContent:SetHeight(math.max(1, y))
	hub.badge.text:SetText(L.windows:format(total))
	hub.badge:SetWidth(hub.badge.text:GetStringWidth() + 20)
end

-- Inhalt ------------------------------------------------------------------------------

function lib:BuildContent(resetScroll)
	local hub, entry = self.hub, self.hubSelected
	if not hub then return end
	for _, r in ipairs(hub.rows) do r:Hide(); r:ClearAllPoints() end
	hub.rows = {}
	if not entry then
		hub.pageTitle:SetText(#self.order == 0 and L.empty or L.pick)
		hub.pageDesc:SetText("")
		hub.content:SetHeight(1)
		return
	end
	local a = self.addons[entry.addon or "_other"]
	hub.pageTitle:SetText(a and ShortName(entry, a.title) or entry.name)
	hub.pageDesc:SetText(entry.description or "")
	if not entry.hubFlat then
		entry.hubFlat = {}
		for _, spec in ipairs(self:EntrySpecs(entry)) do
			if spec.type ~= "link" then entry.hubFlat[#entry.hubFlat + 1] = spec end
		end
	end
	local y, rows = self:BuildRows(hub.content, self.hubRowCache, entry.hubFlat, entry, CONTENT_W, HUBROWS, true)
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
	if not self.hubSelected then self.hubSelected = FirstEntry() end
	self.hub:Show()
end

-- Öffnet den Hub beim ersten Fenster des Addons (oder bei einem bestimmten Fenster)
function lib:OpenHub(addonOrEntry)
	local entry = addonOrEntry
	if type(addonOrEntry) == "string" then
		entry = nil
		for _, g in ipairs(Groups()) do
			if g.addon.id == addonOrEntry and g.cats[1] then entry = g.cats[1].entries[1] break end
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
