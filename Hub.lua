-- Hub: das gemeinsame Einstellungsfenster aller Sexy-Addons.
--
-- Jedes Addon meldet sich einmal an:
--   LibStub("SexyEditMode-1.0"):RegisterAddon("SexyLoot", { title = "SexyLoot", version = "0.1.24" })
-- und gibt bei seinen :Register-Aufrufen `addon = "SexyLoot"` an (optional `category` für die
-- Zwischenüberschrift in der Seitenleiste und `description` für den Text über den Einstellungen).
-- Ganz links steht eine Leiste mit den Addons (Symbol und Name), daneben das Menü des gewählten Addons (Fenster nach
-- Kategorie gruppiert), rechts die Einstellungen des gewählten Fensters. Oben gibt es eine Suche über alle Addons.
-- Es sind dieselben Zeilen wie im Edit-Mode-Dialog (check, slider, select, ...).
--
-- Öffnen: /sem, Minimap-Knopf (Linksklick), lib:ToggleHub(), lib:OpenHub("SexyLoot").

local lib = LibStub("SexyEditMode-1.0", true)
if not (lib and lib.ui) then return end

local ui = lib.ui
local Backdrop, Text, FlatButton = ui.Backdrop, ui.Text, ui.FlatButton

local de = GetLocale() == "deDE"
local L = {
	title = de and "Sexy Einstellungen" or "Sexy Settings",
	editMode = de and "Fenster entsperren" or "Unlock frames",
	menuLeft = de and "Linksklick: Einstellungen öffnen" or "Left click: open settings",
	menuRight = de and "Rechtsklick: Fenster entsperren" or "Right click: unlock frames",
	empty = de and "Kein Sexy-Addon geladen." or "No Sexy addon loaded.",
	pick = de and "Wähle links ein Fenster." or "Pick a window on the left.",
	other = de and "Sonstige" or "Other",
	windows = de and "%d Fenster" or "%d windows",
	applied = de and "Änderungen gelten sofort" or "Changes apply immediately",
	minimapTip = de and "Linksklick: Einstellungen" or "Left click: settings",
	minimapTip2 = de and "Rechtsklick: Fenster verschieben" or "Right click: move windows",
	preview = de and "Vorschau" or "Preview",
	general = de and "Allgemein" or "General",
	sampleHint = de and "Klick auf ein Teil des Beispiels springt zu seinen Einstellungen." or "Click a part of the sample to jump to its settings.",
	sampleTip = de and "Klick: zu den Einstellungen springen" or "Click to jump to its settings",
	search = de and "Suchen …" or "Search …",
	results = de and "Suchergebnisse für „%s“" or "Results for “%s”",
	resultCount = de and "%d Treffer" or "%d results",
	noResults = de and "Nichts gefunden." or "Nothing found.",
	minimapShown = de and "Minimap-Knopf eingeblendet" or "minimap button shown",
	minimapHidden = de and "Minimap-Knopf ausgeblendet" or "minimap button hidden",
}

-- Look wie im Mockup A: dunkelbraune Fläche, Goldrand, Titelband, dunkle Seitenleiste, Fußleiste
local C = {
	bg = { 0.08, 0.065, 0.05, 0.96 },       -- wie die anderen Fenster (Tooltip-Rand, dunkles Braun)
	edge = { 0.42, 0.34, 0.15, 1 },
	band = { 0.15, 0.12, 0.07, 1 },   -- wie das Titelband der Fenster
	side = { 0.114, 0.078, 0.05, 1 },
	line = { 0.24, 0.185, 0.122, 1 },
	gold = { 0.91, 0.76, 0.42 },
	title = { 0.96, 0.89, 0.69 },
	text = { 0.85, 0.80, 0.66 },
	muted = { 0.71, 0.65, 0.53 },
	sel = { 0.227, 0.169, 0.106, 1 },
}

local TITLE_FONT = "Interface/AddOns/SexyEditMode/media/fonts/Marcellus-Regular.ttf"   -- wie die Titel der Fenster
local function BandTitle(fs, size)
	fs:SetFont(TITLE_FONT, size, "")
	fs:SetTextColor(0.91, 0.76, 0.42)   -- Gold wie in den Fenstertiteln
end

local W, H = 980, 620
local RAIL_W = 88       -- Leiste mit den Addons
local RAIL_ITEM_H = 76
local SIDE_W = 200      -- Menü des gewählten Addons
local HEAD_H = 40
local FOOT_H = 56
local PAGE_HEAD = 64
local CONTENT_W = W - RAIL_W - SIDE_W - 58
local ROW_H = 28
local STAGE_W = 380   -- Breite des Vorschau-Felds rechts am Fenster
local STAGE_PAD = 10

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
	f.title = Text(f, "GameFontNormalLarge", 18)
	f.title:SetPoint("LEFT", f.band, "LEFT", 14, 0)
	BandTitle(f.title, 22)
	f.title:SetText(L.title)
	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 1, 1)
	close:SetScale(0.85)
	close:SetFrameLevel(f:GetFrameLevel() + 20)   -- über Titelband und Seitenleiste, sonst fängt ein anderes Fenster den Klick ab
	close:SetScript("OnClick", function() f:Hide() end)

	-- Suche über alle Addons
	local box = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	-- beginnt dort, wo rechts der Inhalt anfängt, reicht bis zum Schließen-Knopf ganz rechts, ist 80 % so hoch wie das Band und mittig darin
	box:SetHeight(math.floor((HEAD_H - 3) * 0.8))
	box:SetPoint("LEFT", f.band, "LEFT", RAIL_W + SIDE_W + 19, 0)
	box:SetPoint("RIGHT", close, "LEFT", -12, 0)
	Backdrop(box, { 0.07, 0.048, 0.03, 1 }, { 0.42, 0.35, 0.24, 1 })
	local edit = CreateFrame("EditBox", nil, box)
	edit:SetPoint("TOPLEFT", 8, 0)
	edit:SetPoint("BOTTOMRIGHT", -22, 0)
	ui.Face(edit, "GameFontHighlight")
	edit:SetAutoFocus(false)
	edit:SetMaxLetters(40)
	local ph = Text(box, "GameFontHighlightSmall", 12)
	ph:SetPoint("LEFT", 8, 0)
	ph:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	ph:SetText(L.search)
	local clear = CreateFrame("Button", nil, box)
	clear:SetSize(18, 18)
	clear:SetPoint("RIGHT", -2, 0)
	clear.text = Text(clear, "GameFontNormal", 14)
	clear.text:SetPoint("CENTER")
	clear.text:SetText("x")
	clear.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	clear:Hide()
	clear:SetScript("OnClick", function() edit:SetText(""); edit:ClearFocus() end)
	edit:SetScript("OnTextChanged", function(self)
		local t = self:GetText()
		ph:SetShown(t == "")
		clear:SetShown(t ~= "")
		lib:HubSearch(t)
	end)
	edit:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
	edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	f.searchEdit = edit

	-- Leiste ganz links: ein Eintrag je Addon mit Symbol und Name
	f.railBg = Solid(f, "BACKGROUND", { 0.082, 0.056, 0.036, 1 }, 0)
	f.railBg:SetPoint("TOPLEFT", 3, -HEAD_H - 1)
	f.railBg:SetPoint("BOTTOMLEFT", 3, FOOT_H)
	f.railBg:SetWidth(RAIL_W)
	f.railLine = Solid(f, "ARTWORK", C.line)
	f.railLine:SetPoint("TOPLEFT", f.railBg, "TOPRIGHT")
	f.railLine:SetPoint("BOTTOMLEFT", f.railBg, "BOTTOMRIGHT")
	f.railLine:SetWidth(1)
	f.railItems = {}

	-- Menü daneben: die Fenster des gewählten Addons, nach Kategorie gruppiert
	f.sideBg = Solid(f, "BACKGROUND", C.side, 0)
	f.sideBg:SetPoint("TOPLEFT", f.railBg, "TOPRIGHT", 1, 0)
	f.sideBg:SetPoint("BOTTOMLEFT", f.railBg, "BOTTOMRIGHT", 1, 0)
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
	-- Knopfgruppe unter dem Titel: ein Knopf je Abschnitt (Darstellung, Verhalten, Andocken, ...), darunter nur dessen Einstellungen
	f.groupSel = {}
	f.tabBtns = {}
	f.tabs = CreateFrame("Frame", nil, f)
	f.tabs:SetPoint("TOPLEFT", f.sideBg, "TOPRIGHT", 18, -PAGE_HEAD)
	f.tabs:SetSize(CONTENT_W, 28)
	f.tabs:Hide()
	f.tabsH = 0

	-- Vorschaustreifen: ein Beispiel des gewählten Fensters. Das Addon zeichnet es (Register: sample), jedes Teil hat einen
	-- Klickbereich: Überfahren umrandet es, ein Klick springt zu seinen Einstellungen (siehe lib:RedrawSample).
	local stage = CreateFrame("Frame", nil, f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	-- gleicher Rahmen wie das Einstellungsfenster, direkt daran (die Ränder überlappen leicht, so wirkt es wie ein Teil davon)
	stage:SetPoint("TOPLEFT", f, "TOPRIGHT", -5, 0)
	stage:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", -5, 0)
	stage:SetWidth(STAGE_W)
	Backdrop(stage, C.bg, C.edge)
	stage:Hide()
	stage.band = Solid(stage, "BACKGROUND", C.band, 1)
	stage.band:SetPoint("TOPLEFT", 3, -3)
	stage.band:SetPoint("TOPRIGHT", -3, -3)
	stage.band:SetHeight(HEAD_H - 3)
	stage.title = Text(stage, "GameFontNormalLarge", 18)
	stage.title:SetPoint("LEFT", stage.band, "LEFT", 14, 0)
	BandTitle(stage.title, 22)
	stage.title:SetText(L.preview)
	stage.hosts = {}   -- je Fenster ein eigener Zeichenbereich samt Speicher (siehe lib:RedrawSample)
	stage.hint = Text(stage, "GameFontHighlightSmall", 11)
	stage.hint:SetPoint("BOTTOM", stage, "BOTTOM", 0, 12)
	stage.hint:SetWidth(STAGE_W - 30)
	stage.hint:SetJustifyH("CENTER")
	stage.hint:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	stage.hint:SetText(L.sampleHint)
	stage.hint:Hide()
	f.stage = stage

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
	-- Knopf im Look des Titelbands (ui.HeaderButton), Inter 12
	local edit = ui.HeaderButton(f, L.editMode, 200, 34)
	edit:SetPoint("BOTTOMLEFT", 18, 11)
	edit.text:SetFont(ui.TEXT_FONT or STANDARD_TEXT_FONT, 13, "")
	-- auffälliger als die übrigen Knöpfe: goldene Fläche mit dunkler Schrift
	edit.bg:SetColorTexture(0.78, 0.63, 0.28, 1)
	edit.text:SetTextColor(0.1, 0.07, 0.03)
	edit.hl:SetColorTexture(1, 1, 1, 0.22)
	-- Verschiebe-Modus für alle Fenster aller Sexy-Addons (der Filter in der Leiste schränkt bei Bedarf ein)
	edit:SetScript("OnClick", function()
		lib:ToggleEditMode()
	end)
	f.hint = Text(f, "GameFontHighlightSmall")
	f.hint:SetPoint("BOTTOMRIGHT", -18, 21)
	f.hint:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	f.hint:SetText("")   -- Hinweis "Änderungen gelten sofort" entfällt

	-- kurzes Aufleuchten der Zeile, zu der die Suche gesprungen ist
	f.flashes = {}
	local tick = 0
	f:SetScript("OnUpdate", function(_, dt)
		-- Vorschau mit laufenden Werten (z. B. herunterzählende Balken): die Kopie in festen Abständen nachziehen
		local active = f.stage and f.stage.active
		if active and active.live and active.live.interval then
			tick = tick + dt
			if tick >= active.live.interval then
				tick = 0
				lib:RedrawSample()
			end
		end
		if not next(f.flashes) then return end
		local now = GetTime()
		for frame, t0 in pairs(f.flashes) do
			local p = (now - t0) / 1.6
			if p >= 1 then
				frame.sxFlash:Hide()
				f.flashes[frame] = nil
			else
				frame.sxFlash:SetAlpha(0.3 * (1 - p) * (0.6 + 0.4 * math.abs(math.cos(p * math.pi * 3))))
			end
		end
	end)
	f:SetScript("OnShow", function() lib:BuildRail(); lib:BuildNav(); lib:BuildContent(true) end)
	f:SetScript("OnHide", function() lib:StopSample() end)
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
		if spec.relayout then lib:RebuildDialog() end
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
		lib:RedrawSample()   -- das Beispiel folgt dem Regler schon beim Ziehen
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
	ui.Face(box, "GameFontHighlight")
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
	ui.Face(box, "GameFontHighlight")
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

-- Liste mit Details: links die Einträge (z. B. Instanzen), rechts die Zeilen des gewählten Eintrags mit Suche, Hinzufügen und
-- Entfernen. Spezifikation { type = "masterdetail", height, addText, hint, clearText, emptyText, lists, selected, select, items,
-- toggle, remove, add, clear, footer }:
--   lists() -> { { key, name, badge, marker }, ... }     selected() -> key     select(key)
--   items(key) -> { { name, on }, ... }                    toggle(key, name, on)   remove(key, name)
--   add(key, text)   clear(key)   footer(key, shown, total) -> Text
-- Das Eingabefeld filtert die Zeilen beim Tippen; Enter oder der Knopf legt den Text als neue Zeile an.
function HUBROWS.masterdetail(parent, spec)
	local LIST_W, ITEM_H = 190, 28
	local H = spec.height or 340
	local detailW = CONTENT_W - LIST_W - 12
	local row = CreateFrame("Frame", nil, parent)

	local function Box(frame)
		Outline(frame)
		Solid(frame, "BORDER", { 0.07, 0.05, 0.035, 1 }):SetAllPoints()
	end

	local function Scroller(owner, w, h, x, y)
		local sf = CreateFrame("ScrollFrame", nil, owner)
		sf:SetPoint("TOPLEFT", x, y)
		sf:SetSize(w, h)
		local content = CreateFrame("Frame", nil, sf)
		content:SetSize(w, 1)
		sf:SetScrollChild(content)
		sf:EnableMouseWheel(true)
		sf:SetScript("OnMouseWheel", function(self, delta)
			local max = math.max(0, content:GetHeight() - h)
			self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * ITEM_H * 2)))
		end)
		return sf, content
	end

	-- linke Liste
	local left = CreateFrame("Frame", nil, row)
	left:SetPoint("TOPLEFT", 0, 0)
	left:SetSize(LIST_W, H - 6)
	Box(left)
	local leftScroll, leftContent = Scroller(left, LIST_W - 8, H - 14, 4, -4)
	local leftItems = {}

	-- rechtes Detail
	local right = CreateFrame("Frame", nil, row)
	right:SetPoint("TOPLEFT", LIST_W + 12, 0)
	right:SetSize(detailW, H - 6)
	Box(right)

	local addBtn = ui.HeaderButton(right, spec.addText or "+", 96, 26)
	addBtn:SetPoint("TOPRIGHT", -8, -8)
	local box = CreateFrame("EditBox", nil, right)
	box:SetAutoFocus(false)
	ui.Face(box, "GameFontHighlight")
	box:SetHeight(26)
	box:SetPoint("TOPLEFT", 8, -8)
	box:SetPoint("RIGHT", addBtn, "LEFT", -8, 0)
	box:SetTextInsets(8, 8, 0, 0)
	box:SetMaxLetters(80)
	Outline(box)
	Solid(box, "BORDER", { 0.04, 0.03, 0.02, 1 }):SetAllPoints()
	local hint = Text(box, "GameFontHighlightSmall", 12)
	hint:SetPoint("LEFT", 8, 0)
	hint:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	hint:SetText(spec.hint or "")

	local listH = H - 6 - 52 - 44
	local detailScroll, detailContent = Scroller(right, detailW - 16, listH, 8, -44)
	local detailRows = {}
	local empty = Text(right, "GameFontHighlightSmall", 12)
	empty:SetPoint("TOPLEFT", 14, -56)
	empty:SetWidth(detailW - 28)
	empty:SetJustifyH("LEFT")
	empty:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	empty:SetText(spec.emptyText or "")
	local footer = Text(right, "GameFontHighlightSmall", 12)
	footer:SetPoint("BOTTOMLEFT", 10, 14)
	footer:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
	local clearBtn = ui.HeaderButton(right, spec.clearText or "", 150, 24)
	clearBtn:SetPoint("BOTTOMRIGHT", -8, 8)

	local filter = ""

	local function LeftItem(i)
		local b = leftItems[i]
		if b then return b end
		b = CreateFrame("Button", nil, leftContent)
		b:SetSize(LIST_W - 8, ITEM_H)
		b:SetPoint("TOPLEFT", 0, -(i - 1) * ITEM_H)
		b.bg = Solid(b, "BACKGROUND", { 0.227, 0.169, 0.106, 1 })
		b.bg:SetAllPoints()
		b.bar = Solid(b, "ARTWORK", { C.gold[1], C.gold[2], C.gold[3], 1 })
		b.bar:SetPoint("TOPLEFT")
		b.bar:SetPoint("BOTTOMLEFT")
		b.bar:SetWidth(2)
		Solid(b, "HIGHLIGHT", { 1, 1, 1, 0.05 }):SetAllPoints()
		b.dot = Solid(b, "ARTWORK", { 0.48, 0.88, 0.56, 1 })
		b.dot:SetSize(7, 7)
		b.dot:SetPoint("LEFT", 8, 0)
		b.text = Text(b, "GameFontHighlight", 12)
		b.text:SetPoint("LEFT", 22, 0)
		b.text:SetPoint("RIGHT", -30, 0)
		b.text:SetJustifyH("LEFT")
		b.text:SetWordWrap(false)
		b.badge = Text(b, "GameFontHighlightSmall", 11)
		b.badge:SetPoint("RIGHT", -8, 0)
		b.badge:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
		b:SetScript("OnClick", function(self)
			spec.select(self.key)
			lib:RefreshDialog()
		end)
		leftItems[i] = b
		return b
	end

	local function DetailRow(i)
		local r = detailRows[i]
		if r then return r end
		r = CreateFrame("Button", nil, detailContent)
		r:SetSize(detailW - 16, ITEM_H)
		r:SetPoint("TOPLEFT", 0, -(i - 1) * ITEM_H)
		r.line = Solid(r, "BACKGROUND", { C.line[1], C.line[2], C.line[3], 0.6 })
		r.line:SetPoint("BOTTOMLEFT")
		r.line:SetPoint("BOTTOMRIGHT")
		r.line:SetHeight(1)
		Solid(r, "HIGHLIGHT", { 1, 1, 1, 0.04 }):SetAllPoints()
		r.box = CreateFrame("Frame", nil, r)
		r.box:SetSize(16, 16)
		r.box:SetPoint("LEFT", 4, 0)
		Outline(r.box)
		Solid(r.box, "BORDER", { 0.07, 0.05, 0.035, 1 }):SetAllPoints()
		r.mark = Solid(r.box, "OVERLAY", { C.gold[1], C.gold[2], C.gold[3], 1 })
		r.mark:SetPoint("TOPLEFT", 3, -3)
		r.mark:SetPoint("BOTTOMRIGHT", -3, 3)
		r.text = Text(r, "GameFontHighlight", 12)
		r.text:SetPoint("LEFT", 30, 0)
		r.text:SetPoint("RIGHT", -30, 0)
		r.text:SetJustifyH("LEFT")
		r.text:SetWordWrap(false)
		r.x = CreateFrame("Button", nil, r)
		r.x:SetSize(22, 22)
		r.x:SetPoint("RIGHT", -2, 0)
		r.x.text = Text(r.x, "GameFontHighlight", 12)
		r.x.text:SetPoint("CENTER")
		r.x.text:SetText("x")
		r.x.text:SetTextColor(0.55, 0.5, 0.42)
		r.x:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 0.55, 0.45) end)
		r.x:SetScript("OnLeave", function(self) self.text:SetTextColor(0.55, 0.5, 0.42) end)
		r.x:SetScript("OnClick", function(self)
			local owner = self:GetParent()
			spec.remove(owner.list, owner.item)
			lib:RefreshDialog()
		end)
		r:SetScript("OnClick", function(self)
			spec.toggle(self.list, self.item, not self.on)
			lib:RefreshDialog()
		end)
		detailRows[i] = r
		return r
	end

	local function Redraw()
		local lists = spec.lists() or {}
		local sel = spec.selected()
		local found
		for _, l in ipairs(lists) do if l.key == sel then found = true end end
		if not found and lists[1] then
			sel = lists[1].key
			spec.select(sel)
		end

		for i, l in ipairs(lists) do
			local b = LeftItem(i)
			b.key = l.key
			b.text:SetText(l.name or "")
			b.badge:SetText(l.badge or "")
			b.dot:SetShown(l.marker and true or false)
			local on = l.key == sel
			b.bg:SetShown(on)
			b.bar:SetShown(on)
			b.text:SetTextColor(on and C.title[1] or C.text[1], on and C.title[2] or C.text[2], on and C.title[3] or C.text[3])
			b:Show()
		end
		for i = #lists + 1, #leftItems do leftItems[i]:Hide() end
		leftContent:SetHeight(math.max(1, #lists * ITEM_H))

		if row.lastSel ~= sel then
			row.lastSel = sel
			detailScroll:SetVerticalScroll(0)
		end

		local items = (found or lists[1]) and spec.items(sel) or {}
		local shown, total = 0, #items
		local needle = filter:lower()
		for _, it in ipairs(items) do
			if needle == "" or it.name:lower():find(needle, 1, true) then
				shown = shown + 1
				local r = DetailRow(shown)
				r.list, r.item, r.on = sel, it.name, it.on and true or false
				r.text:SetText(it.name)
				r.text:SetTextColor(it.on and C.text[1] or 0.5, it.on and C.text[2] or 0.46, it.on and C.text[3] or 0.38)
				r.mark:SetShown(it.on and true or false)
				r:Show()
			end
		end
		for i = shown + 1, #detailRows do detailRows[i]:Hide() end
		detailContent:SetHeight(math.max(1, shown * ITEM_H))

		local none = #lists == 0
		empty:SetShown(none)
		hint:SetText((none and spec.noneHint) or spec.hint or "")
		box:SetEnabled(not none)
		addBtn:SetAlpha(none and 0.4 or 1)
		clearBtn:SetShown(not none)
		footer:SetText((not none and spec.footer) and spec.footer(sel, shown, total) or "")
	end

	local function Add()
		local text = (box:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
		local sel = spec.selected()
		if text ~= "" and sel ~= nil then
			box:SetText("")
			box:ClearFocus()
			spec.add(sel, text)
			filter = ""
			lib:RefreshDialog()
		end
	end
	addBtn:SetScript("OnClick", Add)
	box:SetScript("OnEnterPressed", Add)
	box:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
	box:SetScript("OnTextChanged", function(self)
		local text = self:GetText() or ""
		hint:SetShown(text == "")
		filter = text
		Redraw()
	end)
	clearBtn:SetScript("OnClick", function()
		local sel = spec.selected()
		if sel ~= nil then spec.clear(sel) end
		lib:RefreshDialog()
	end)

	function row:Update() Redraw() end
	return row, H
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
		ui.Face(e, "GameFontHighlight")
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
lib.hasMasterDetail = true   -- Zeilenart "masterdetail" gibt es (Addons prüfen das, bevor sie sie benutzen)

-- Leiste, Menü, Suche -----------------------------------------------------------------

local function Plain(text)
	return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function IconOf(a)
	if a.icon then return a.icon end
	if a.id == "_other" then return "Interface/AddOns/SexyEditMode/icon.tga" end
	return "Interface/AddOns/" .. a.id .. "/icon.tga"
end

-- Kurzname unter dem Symbol: "SexyQuestHelper" -> "QuestHelper"
local function RailName(a)
	return (a.title:gsub("^Sexy", ""))
end

local function SelectedAddonId(self)
	local e = self.hubSelected
	if e then return e.addon or "_other" end
	local g = Groups()[1]
	return g and g.addon.id
end

local function RailItem(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(RAIL_W, RAIL_ITEM_H)
	b.sel = Solid(b, "BACKGROUND", C.sel)
	b.sel:SetAllPoints()
	b.bar = Solid(b, "ARTWORK", { C.gold[1], C.gold[2], C.gold[3], 1 })
	b.bar:SetPoint("TOPLEFT")
	b.bar:SetPoint("BOTTOMLEFT")
	b.bar:SetWidth(3)
	b.hl = Solid(b, "HIGHLIGHT", { 1, 1, 1, 0.05 })
	b.hl:SetAllPoints()
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(40, 40)
	b.icon:SetPoint("TOP", 0, -9)
	b.text = Text(b, "GameFontHighlightSmall", 11)
	b.text:SetPoint("TOP", b.icon, "BOTTOM", 0, -5)
	b.text:SetWidth(RAIL_W - 6)
	b.text:SetJustifyH("CENTER")
	b.text:SetWordWrap(false)
	b:SetScript("OnClick", function(self)
		if self.news then lib:HubShowNews()
		elseif self.profile then lib:HubShowProfiles()
		else lib:HubSelectAddon(self.addonId) end
	end)
	b:SetScript("OnEnter", function(self)
		if not self.title then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.title)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	return b
end

function lib:BuildRail()
	local hub = self.hub
	if not hub then return end
	for _, it in ipairs(hub.railItems) do it:Hide(); it:ClearAllPoints() end
	local selId, n = SelectedAddonId(self), 0
	for _, g in ipairs(Groups()) do
		if g.count > 0 then
			n = n + 1
			local it = hub.railItems[n]
			if not it then it = RailItem(hub); hub.railItems[n] = it end
			local a = g.addon
			it:SetPoint("TOPLEFT", hub.railBg, "TOPLEFT", 0, -(6 + (n - 1) * RAIL_ITEM_H))
			it.addonId, it.title = a.id, a.title
			it.icon:SetTexture(IconOf(a))
			it.text:SetText(RailName(a))
			it.profile, it.news = nil, nil
			if it.dot then it.dot:Hide() end
			local on = a.id == selId and not self.hubProfiles
			it.sel:SetShown(on)
			it.bar:SetShown(on)
			local c = on and C.title or C.text
			it.text:SetTextColor(c[1], c[2], c[3])
			it.icon:SetAlpha(on and 1 or 0.8)
			it:Show()
		end
	end
	-- Seite "Profile" (Profiles.lua) als letzter Eintrag
	local pn = n + 1
	local pit = hub.railItems[pn]
	if not pit then pit = RailItem(hub); hub.railItems[pn] = pit end
	pit:SetPoint("TOPLEFT", hub.railBg, "TOPLEFT", 0, -(6 + (pn - 1) * RAIL_ITEM_H))
	pit.addonId, pit.profile, pit.news, pit.title = nil, true, nil, de and "Profile" or "Profiles"
	if pit.dot then pit.dot:Hide() end
	pit.icon:SetTexture("Interface/Icons/INV_Misc_Note_06")
	pit.text:SetText(de and "Profile" or "Profiles")
	local pon = self.hubProfiles == true
	pit.sel:SetShown(pon)
	pit.bar:SetShown(pon)
	local pc = pon and C.title or C.text
	pit.text:SetTextColor(pc[1], pc[2], pc[3])
	pit.icon:SetAlpha(pon and 1 or 0.8)
	pit:Show()
	-- Neuigkeiten (News.lua): Seite im Einstellungsfenster, grüner Punkt bei Ungelesenem
	local nn = n + 2
	local nit = hub.railItems[nn]
	if lib.newsOrder and #lib.newsOrder > 0 then
		if not nit then nit = RailItem(hub); hub.railItems[nn] = nit end
		nit:SetPoint("TOPLEFT", hub.railBg, "TOPLEFT", 0, -(6 + (nn - 1) * RAIL_ITEM_H))
		nit.addonId, nit.profile, nit.news, nit.title = nil, nil, true, de and "Neuigkeiten" or "News"
		nit.icon:SetTexture("Interface/Icons/INV_Misc_Book_09")
		nit.text:SetText(nit.title)
		local non = self.hubProfiles == "news"
		nit.sel:SetShown(non)
		nit.bar:SetShown(non)
		local nc = non and C.title or C.text
		nit.text:SetTextColor(nc[1], nc[2], nc[3])
		nit.icon:SetAlpha(non and 1 or 0.8)
		if not nit.dot then
			nit.dot = nit:CreateTexture(nil, "OVERLAY")
			nit.dot:SetSize(10, 10)
			nit.dot:SetPoint("TOPRIGHT", nit.icon, "TOPRIGHT", 4, 2)
			nit.dot:SetColorTexture(0.48, 0.88, 0.56, 1)
		end
		nit.dot:SetShown(lib:NewsHasNew())
		nit:Show()
	end
end

-- Zeilen eines Fensters im Hub (ohne Verweise auf andere Fenster)
local function EntryFlat(e)
	if not e.hubFlat then
		e.hubFlat = {}
		for _, spec in ipairs(lib:EntrySpecs(e)) do
			if spec.type ~= "link" then e.hubFlat[#e.hubFlat + 1] = spec end
		end
	end
	return e.hubFlat
end

local SEARCHABLE = { check = true, slider = true, select = true, color = true, button = true, buttonrow = true,
	keybind = true, input = true, edit = true, header = true }

function lib:HubSearch(text)
	local hub = self.hub
	text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if hub then hub.query = text end
	if hub and hub:IsShown() then self:BuildContent(true) end
end

function lib:BuildResults()
	local hub = self.hub
	local tokens = {}
	for w in hub.query:gmatch("%S+") do tokens[#tokens + 1] = w end
	local results = {}
	local function Matches(hay)
		hay = hay:lower()
		for _, t in ipairs(tokens) do
			if not hay:find(t, 1, true) then return false end
		end
		return true
	end
	for _, g in ipairs(Groups()) do
		for _, cat in ipairs(g.cats) do
			for _, e in ipairs(cat.entries) do
				local page = ShortName(e, g.addon.title)
				local where = g.addon.title .. "  ›  " .. page
				if Matches(where) and #results < 80 then
					results[#results + 1] = { entry = e, label = page, where = g.addon.title, page = true }
				end
				for _, spec in ipairs(EntryFlat(e)) do
					if #results >= 80 then break end
					if spec.name and SEARCHABLE[spec.type] and Matches(Plain(spec.name) .. " " .. where) then
						results[#results + 1] = { entry = e, spec = spec, label = Plain(spec.name), where = where }
					end
				end
			end
		end
	end

	hub.pageTitle:SetText(L.results:format(hub.query))
	hub.pageDesc:SetText(#results > 0 and L.resultCount:format(#results) or L.noResults)
	hub.resultItems = hub.resultItems or {}
	for i, r in ipairs(results) do
		local b = hub.resultItems[i]
		if not b then
			b = CreateFrame("Button", nil, hub.content)
			b:SetHeight(42)
			b.hl = Solid(b, "HIGHLIGHT", { 1, 1, 1, 0.06 })
			b.hl:SetAllPoints()
			b.line = Solid(b, "BACKGROUND", C.line)
			b.line:SetPoint("BOTTOMLEFT")
			b.line:SetPoint("BOTTOMRIGHT")
			b.line:SetHeight(1)
			b.name = Text(b, "GameFontHighlight", 13)
			b.name:SetPoint("TOPLEFT", 6, -6)
			b.name:SetPoint("RIGHT", -6, 0)
			b.name:SetJustifyH("LEFT")
			b.name:SetWordWrap(false)
			b.name:SetTextColor(C.title[1], C.title[2], C.title[3])
			b.where = Text(b, "GameFontHighlightSmall", 11)
			b.where:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
			b.where:SetPoint("RIGHT", -6, 0)
			b.where:SetJustifyH("LEFT")
			b.where:SetWordWrap(false)
			b.where:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
			b:SetScript("OnClick", function(self) lib:HubGoto(self.entry, self.spec) end)
			hub.resultItems[i] = b
		end
		b.entry, b.spec = r.entry, r.spec
		b.name:SetText(r.label)
		b.where:SetText(r.where)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", hub.content, "TOPLEFT", 0, -(i - 1) * 42)
		b:SetWidth(CONTENT_W)
		b:Show()
	end
	hub.content:SetHeight(math.max(1, #results * 42))
	hub.scroll:SetVerticalScroll(0)
end

-- Springt zu einem Fenster und, falls angegeben, zu der Einstellung darin (sie leuchtet kurz auf)
function lib:HubGoto(entry, spec)
	local hub = self.hub
	if not hub then return end
	if hub.searchEdit:GetText() ~= "" then hub.searchEdit:SetText("") end
	hub.searchEdit:ClearFocus()
	self:HubSelect(entry)
	if not spec then return end
	self:HubSelectGroupOf(entry, spec, nil)
	C_Timer.After(0.05, function() self:HubFlashSpec(spec) end)
end

-- Abschnitte eines Fensters als Knopfgruppe ---------------------------------------------

-- Die Einstellungen eines Fensters, nach ihren Überschriften (header) in Abschnitte geteilt:
-- { { name, id, specs = { ... } }, ... }. Einstellungen vor der ersten Überschrift bilden "Allgemein"; leere Abschnitte entfallen.
local function EntryGroups(e)
	if not e.hubGroups then
		local groups, cur = {}, nil
		for _, spec in ipairs(EntryFlat(e)) do
			if spec.type == "header" then
				cur = { name = spec.name, id = spec.id, specs = {} }
				groups[#groups + 1] = cur
			else
				if not cur then
					cur = { name = L.general, specs = {} }
					groups[#groups + 1] = cur
				end
				cur.specs[#cur.specs + 1] = spec
			end
		end
		for i = #groups, 1, -1 do
			if #groups[i].specs == 0 then table.remove(groups, i) end
		end
		e.hubGroups = groups
	end
	return e.hubGroups
end

local function TabButton(parent)
	local b = CreateFrame("Button", nil, parent)
	b.bg = Solid(b, "BACKGROUND", C.side)
	b.bg:SetAllPoints()
	b.sel = Solid(b, "BACKGROUND", C.sel, 1)
	b.sel:SetAllPoints()
	b.bar = Solid(b, "ARTWORK", { C.gold[1], C.gold[2], C.gold[3], 1 })
	b.bar:SetPoint("BOTTOMLEFT")
	b.bar:SetPoint("BOTTOMRIGHT")
	b.bar:SetHeight(2)
	b.hl = Solid(b, "HIGHLIGHT", { 1, 1, 1, 0.06 })
	b.hl:SetAllPoints()
	b.text = Text(b, "GameFontHighlight", 13)
	b.text:SetPoint("CENTER")
	b:SetScript("OnClick", function(self)
		local hub, entry = lib.hub, lib.hubSelected
		if hub and entry then
			hub.groupSel[entry] = self.index
			lib:BuildContent(true)
		end
	end)
	return b
end

-- Zeichnet die Knopfgruppe; setzt hub.tabsH (Höhe, die die Einstellungen darunter nach unten rückt)
function lib:BuildTabs()
	local hub, entry = self.hub, self.hubSelected
	if not hub then return end
	for _, b in ipairs(hub.tabBtns) do b:Hide() end
	hub.tabsH = 0
	local groups = entry and EntryGroups(entry)
	if not groups or #groups < 2 or (hub.query and hub.query ~= "") then
		hub.tabs:Hide()
		return
	end
	local sel = hub.groupSel[entry] or 1
	if sel > #groups then sel = 1 end
	hub.groupSel[entry] = sel
	local x, y, rowH, gap = 0, 0, 28, 4
	for i, g in ipairs(groups) do
		local b = hub.tabBtns[i]
		if not b then
			b = TabButton(hub.tabs)
			hub.tabBtns[i] = b
		end
		b.text:SetText(g.name)
		local w = b.text:GetStringWidth() + 28
		if x + w > CONTENT_W and x > 0 then
			x = 0
			y = y + rowH + gap
		end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", hub.tabs, "TOPLEFT", x, -y)
		b:SetSize(w, rowH)
		b.index = i
		local on = i == sel
		b.sel:SetShown(on)
		b.bar:SetShown(on)
		local tc = on and C.title or C.text
		b.text:SetTextColor(tc[1], tc[2], tc[3])
		b:Show()
		x = x + w + gap
	end
	hub.tabs:SetHeight(y + rowH)
	hub.tabs:Show()
	hub.tabsH = y + rowH + 10
end

-- Wählt den Abschnitt, in dem eine Einstellung (oder Überschrift) steht; true, wenn gefunden
function lib:HubSelectGroupOf(entry, spec, jump)
	local hub = self.hub
	local groups = EntryGroups(entry)
	for gi, g in ipairs(groups) do
		local found = (spec and spec.type == "header" and (g.id == spec.id and g.name == spec.name))
			or (jump and (g.id == jump or g.name == jump))
		if not found then
			for _, x in ipairs(g.specs) do
				if (spec and x == spec) or (jump and (x.jump == jump or x.id == jump or x.name == jump)) then found = x break end
			end
		end
		if found then
			if #groups >= 2 and hub.groupSel[entry] ~= gi then
				hub.groupSel[entry] = gi
				if self.hubSelected == entry then self:BuildContent(true) end
			end
			return found
		end
	end
end

-- Vorschaustreifen --------------------------------------------------------------------

-- Scrollt zu einer Einstellung und lässt sie kurz aufleuchten (Suche und Vorschau nutzen das)
function lib:HubFlashSpec(spec)
	local hub = self.hub
	local cached = hub and self.hubRowCache[spec.key or spec]
	local frame = cached and cached.frame
	if not (frame and frame:IsShown() and frame:GetTop() and hub.content:GetTop()) then return end
	local maxScroll = math.max(0, hub.content:GetHeight() - hub.scroll:GetHeight())
	local off = hub.content:GetTop() - frame:GetTop()
	hub.scroll:SetVerticalScroll(math.max(0, math.min(maxScroll, off - 12)))
	if not frame.sxFlash then
		frame.sxFlash = frame:CreateTexture(nil, "OVERLAY")
		frame.sxFlash:SetAllPoints()
		frame.sxFlash:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
	end
	frame.sxFlash:SetAlpha(0.3)
	frame.sxFlash:Show()
	hub.flashes[frame] = GetTime()
end

-- Klick auf ein Teil des Beispiels: zur Einstellung mit diesem jump-Wert (spec.jump) bzw. Abschnitt (header id)
function lib:HubJump(entry, jump)
	if not (entry and jump) then return end
	local found = self:HubSelectGroupOf(entry, nil, jump)
	if type(found) == "table" and found.type ~= "header" then
		C_Timer.After(0.05, function() self:HubFlashSpec(found) end)
	end
end

-- Zeichnet das Beispiel des gewählten Fensters. Register(frame, { sample = function(host, cache) ... end }): das Addon
-- zeichnet in host (cache: eigene Tabelle zum Wiederverwenden, der Aufruf kommt nach jeder Änderung) und liefert
-- { w, h, parts = { { name, x, y, w, h, jump }, ... } } (Maße ungeskaliert, y von oben). Der Streifen skaliert es passend.
local function SampleEdge(b)
	b.edges = {}
	for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
		local e = b:CreateTexture(nil, "OVERLAY")
		e:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 1)
		e:SetPoint(p[1]); e:SetPoint(p[2])
		if p[3] then e:SetHeight(2) else e:SetWidth(2) end
		e:Hide()
		b.edges[i] = e
	end
	b.fill = b:CreateTexture(nil, "HIGHLIGHT")
	b.fill:SetAllPoints()
	b.fill:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.12)
end

-- Vorschau mit dem echten Fenster ------------------------------------------------------
-- Register(frame, { live = { frame = <Frame oder Funktion>, enter = function() ... end, leave = function() ... end,
--   parts = function(rel, w, h) ... end }):
-- Das echte Fenster bleibt, wo es ist und verändert sich nie sichtbar: enter() lässt es für einen Moment Beispieldaten zeigen
-- (z. B. die Vorschau des Moduls), die Kopie seines Aussehens (Clone.lua) wird gezogen, leave() setzt es sofort zurück.
-- parts liefert die Klickbereiche; rel(region) misst einen echten Teil relativ zum Fenster.
local function LiveSample(entry)
	local live = entry.live
	return function(host, c)
		local frame = type(live.frame) == "function" and live.frame() or live.frame
		if not frame then return end
		entry.liveState = c
		c.clone = c.clone or lib:NewClone()
		-- Das echte Fenster zeigt nur für diesen Moment Beispieldaten: enter(), Kopie ziehen, messen, leave() - alles in
		-- einem Zug, ohne dass dazwischen etwas gezeichnet wird. Im Spiel verändert sich das echte Fenster daher nie.
		if live.enter then live.enter() end
		local ok, res = pcall(function()
			local root = lib:SyncClone(c.clone, frame, host)
			if not root then return end
			local s = frame:GetScale()
			local w, h = (frame:GetWidth() or 100) * s, (frame:GetHeight() or 60) * s
			local function rel(region)
				if not (region and region.IsShown and region:IsShown()) then return end
				local fl, ft = frame:GetLeft(), frame:GetTop()
				local l, t, r, b = region:GetLeft(), region:GetTop(), region:GetRight(), region:GetBottom()
				if not (fl and ft and l and t and r and b) then return end
				return (l - fl) * s, (ft - t) * s, (r - l) * s, (t - b) * s
			end
			local parts = live.parts and live.parts(rel, w, h) or {}
			table.insert(parts, 1, { name = entry.name, x = 0, y = 0, w = w, h = h, jump = "_pos" })
			return { w = w, h = h, parts = parts }
		end)
		if live.leave then pcall(live.leave) end
		if not ok then error(res, 0) end
		-- beim ersten Mal sind die Maße oft noch nicht berechnet: gleich nochmal zeichnen
		if not c.redrawn then
			c.redrawn = true
			C_Timer.After(0.1, function() lib:RedrawSample() end)
		end
		return res
	end
end

function lib:LiveStop(entry)
	local c = entry.liveState
	if not c then return end
	lib:HideClone(c.clone)
	c.redrawn = nil
end

-- Beendet das gerade gezeigte Beispiel (bei echten Fenstern: Beispieldaten zurücknehmen, Kopie ausblenden)
function lib:StopSample()
	local st = self.hub and self.hub.stage
	if st and st.active then
		local e = st.active
		st.active = nil
		if e.live then pcall(lib.LiveStop, lib, e) end
	end
end

function lib:RedrawSample()
	local hub = self.hub
	if not hub then return end
	if self.hubProfiles then
		self:StopSample()
		hub.stage:Hide()
		return
	end
	local entry, st = self.hubSelected, hub.stage
	if st.active and st.active ~= entry then self:StopSample() end
	local sample = entry and entry.sample
	if entry and entry.live then
		entry.liveSample = entry.liveSample or LiveSample(entry)
		sample = entry.liveSample
	end
	local searching = hub.query and hub.query ~= ""
	local top = PAGE_HEAD + 8 + (hub.tabsH or 0)
	local shown = false

	if sample and not searching then
		-- Jedes Fenster zeichnet in seinen eigenen Rahmen mit eigenem Speicher: sonst würden sich die Beispiele überlagern
		local host = st.hosts[entry]
		if not host then
			host = CreateFrame("Frame", nil, st)
			host:SetSize(1, 1)
			host.cache = {}
			host.spots = {}
			st.hosts[entry] = host
		end
		for e, h in pairs(st.hosts) do h:SetShown(e == entry) end
		if entry.live then st.active = entry end
		local ok, res = pcall(sample, host, host.cache)
		-- Fehler des Beispiels sichtbar machen (einmal je Meldung), sonst bliebe der Streifen einfach leer
		if not ok and st.lastError ~= res then
			st.lastError = res
			print("|cffe8c26aSexyEditMode|r: " .. (de and "Vorschau-Fehler: " or "Preview error: ") .. tostring(res))
		elseif ok and not (type(res) == "table" and res.w and res.h) and st.lastError ~= "bad" then
			st.lastError = "bad"
			print("|cffe8c26aSexyEditMode|r: " .. (de and "Vorschau liefert keine Größe (w, h)." or "Sample returned no size (w, h)."))
		end
		if ok and type(res) == "table" and res.w and res.h and res.w > 0 then
			shown = true
			local sw = (st:GetWidth() and st:GetWidth() > 10) and st:GetWidth() or STAGE_W
			local sh = (st:GetHeight() and st:GetHeight() > 10) and st:GetHeight() or H
			local scale = math.min(1, (sw - 2 * STAGE_PAD) / res.w, (sh - 2 * STAGE_PAD - HEAD_H - 40) / res.h)
			host:SetScale(scale)
			host:SetSize(res.w, res.h)
			host:ClearAllPoints()
			host:SetPoint("CENTER", st, "CENTER", 0, 4)
			local n = 0
			for _, part in ipairs(res.parts or {}) do
				n = n + 1
				local b = host.spots[n]
				if not b then
					b = CreateFrame("Button", nil, host)
					SampleEdge(b)
					b:SetScript("OnEnter", function(self)
						for _, e in ipairs(self.edges) do e:Show() end
						GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
						GameTooltip:SetText(self.partName or "")
						GameTooltip:AddLine(L.sampleTip, 0.7, 0.7, 0.7)
						GameTooltip:Show()
					end)
					b:SetScript("OnLeave", function(self)
						for _, e in ipairs(self.edges) do e:Hide() end
						GameTooltip_Hide()
					end)
					b:SetScript("OnClick", function(self) lib:HubJump(lib.hubSelected, self.jump) end)
					host.spots[n] = b
				end
				b:SetFrameLevel(host:GetFrameLevel() + 20 + n)
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", host, "TOPLEFT", part.x, -part.y)
				b:SetSize(math.max(part.w, 4), math.max(part.h, 4))
				b.partName, b.jump = part.name, part.jump
				b:Show()
			end
			for i = n + 1, #host.spots do host.spots[i]:Hide() end
		end
	end

	if not shown then self:StopSample() end
	st:SetShown(shown)
	st.hint:SetShown(shown)
	hub.scroll:ClearAllPoints()
	hub.scroll:SetPoint("TOPLEFT", hub.sideBg, "TOPRIGHT", 18, -top)
	hub.scroll:SetPoint("BOTTOMRIGHT", hub, "BOTTOMRIGHT", -14, FOOT_H + 8)
end

-- Seitenleiste ------------------------------------------------------------------------

function lib:BuildNav()
	local hub = self.hub
	if not hub then return end
	if self.hubProfiles then return end
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
			ui.Face(h.text, "GameFontNormal")
			h.text:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
		else
			ui.Face(h.text, "GameFontNormalSmall")
			h.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
		end
		h.text:SetText(text)
	end

	local selId = SelectedAddonId(self)
	for _, g in ipairs(Groups()) do total = total + g.count end
	for _, g in ipairs(Groups()) do
		if g.count > 0 and g.addon.id == selId then
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
					ui.Face(it.text, "GameFontHighlight")
					it.text:SetText(ShortName(e, g.addon.title))
				end
			end
		end
	end
	hub.sideContent:SetHeight(math.max(1, y))
end

-- Inhalt ------------------------------------------------------------------------------

-- Die Seite "Profile" ersetzt Menü, Inhalt und Vorschau: sie liegt als eigener Rahmen rechts neben der Leiste
local function ProfileMode(self, on)
	local hub = self.hub
	for _, w in ipairs({ hub.sideBg, hub.sideLine, hub.side, hub.pageTitle, hub.pageDesc, hub.scroll }) do w:SetShown(not on) end
	if on then
		hub.tabs:Hide()
		for _, r in ipairs(hub.rows) do r:Hide() end
		local news = self.hubProfiles == "news"
		local function Panel(key, fill)
			if not hub[key] then
				local p = CreateFrame("Frame", nil, hub)
				p:SetPoint("TOPLEFT", hub.railBg, "TOPRIGHT", 1, 0)
				p:SetPoint("BOTTOMRIGHT", hub, "BOTTOMRIGHT", -3, FOOT_H)
				hub[key] = p
				if fill then fill(lib, p) end
			end
			return hub[key]
		end
		if news then
			if hub.profilePanel then hub.profilePanel:Hide() end
			Panel("newsPanel", lib.FillNewsPanel):Show()
			if lib.RefreshNews then lib:RefreshNews() end
		else
			if hub.newsPanel then hub.newsPanel:Hide() end
			Panel("profilePanel", lib.FillProfilePanel):Show()
			if lib.RefreshProfiles then lib:RefreshProfiles() end
		end
	else
		if hub.profilePanel then hub.profilePanel:Hide() end
		if hub.newsPanel then hub.newsPanel:Hide() end
	end
end

function lib:BuildContent(resetScroll)
	local hub, entry = self.hub, self.hubSelected
	if not hub then return end
	if hub.query and hub.query ~= "" then self.hubProfiles = nil end   -- eine Suche beendet die Seite Profile
	ProfileMode(self, self.hubProfiles and true or false)
	if self.hubProfiles then return end
	for _, r in ipairs(hub.rows) do r:Hide(); r:ClearAllPoints() end
	hub.rows = {}
	for _, b in ipairs(hub.resultItems or {}) do b:Hide(); b:ClearAllPoints() end
	self:BuildTabs()
	self:RedrawSample()
	if hub.query and hub.query ~= "" then return self:BuildResults() end
	if not entry then
		hub.pageTitle:SetText(#self.order == 0 and L.empty or L.pick)
		hub.pageDesc:SetText("")
		hub.content:SetHeight(1)
		return
	end
	local a = self.addons[entry.addon or "_other"]
	hub.pageTitle:SetText(a and ShortName(entry, a.title) or entry.name)
	hub.pageDesc:SetText(entry.description or "")
	local groups = EntryGroups(entry)
	local specs = EntryFlat(entry)
	if #groups >= 2 then specs = groups[hub.groupSel[entry] or 1].specs end
	local y, rows = self:BuildRows(hub.content, self.hubRowCache, specs, entry, CONTENT_W, HUBROWS, true)
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
	self:RedrawSample()   -- das Beispiel folgt jeder Änderung
end

-- Öffnen ------------------------------------------------------------------------------

function lib:HubIsShown() return self.hub and self.hub:IsShown() and true or false end

function lib:HubSelect(entry)
	if not self.hub then self.hub = CreateHub() end
	self.hubProfiles = nil
	if self.hub.searchEdit and self.hub.searchEdit:GetText() ~= "" then self.hub.searchEdit:SetText("") end   -- Auswahl beendet die Suche
	self.hubSelected = entry
	self.hub.lastEntry = self.hub.lastEntry or {}
	if entry then self.hub.lastEntry[entry.addon or "_other"] = entry end
	if self.hub:IsShown() then
		self:BuildRail()
		self:BuildNav()
		self:BuildContent(true)
	else
		self.hub:Show()   -- OnShow baut Leiste und Inhalt auf
	end
end

-- Klick auf ein Addon in der Leiste: sein zuletzt gewähltes (sonst erstes) Fenster
function lib:HubSelectAddon(id)
	local hub = self.hub
	local entry = hub and hub.lastEntry and hub.lastEntry[id]
	if not entry then
		for _, g in ipairs(Groups()) do
			if g.addon.id == id and g.cats[1] then entry = g.cats[1].entries[1] break end
		end
	end
	if hub and hub.searchEdit and hub.searchEdit:GetText() ~= "" then hub.searchEdit:SetText("") end
	if entry then self:HubSelect(entry) end
end

-- Seite "Profile" im Einstellungsfenster (Rahmen und Inhalt: Profiles.lua)
-- Seite "Neuigkeiten" im Einstellungsfenster (Inhalt: News.lua)
function lib:HubShowNews()
	if not self.hub then self.hub = CreateHub() end
	self.hubProfiles = "news"
	if self.hub.searchEdit and self.hub.searchEdit:GetText() ~= "" then self.hub.searchEdit:SetText("") end
	if self.hub:IsShown() then
		self:BuildRail()
		self:BuildNav()
		self:BuildContent(true)
		self:RedrawSample()
	else
		self.hub:Show()
	end
end

function lib:HubShowProfiles()
	if not self.hub then self.hub = CreateHub() end
	self.hubProfiles = true
	if self.hub.searchEdit and self.hub.searchEdit:GetText() ~= "" then self.hub.searchEdit:SetText("") end
	if self.hub:IsShown() then
		self:BuildRail()
		self:BuildNav()
		self:BuildContent(true)
		self:RedrawSample()
	else
		self.hub:Show()
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
	if msg == "profiles" or msg == "profile" or msg == "profile" then
		if lib.OpenProfiles then lib:OpenProfiles() end
		return
	end
	if msg == "who" then
		if lib.PrintCharInfo then lib:PrintCharInfo() end
		return
	end
	if msg == "news" or msg == "neuigkeiten" then
		lib:OpenNews()
		return
	end
	if msg == "move" or msg == "unlock" or msg == "lock" then
		lib:ToggleMoveMode()
		return
	end
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

-- Eintrag im Spielmenü (Esc) über "AddOns": öffnet das Einstellungsfenster. Das Menü baut seine Knöpfe in InitButtons auf; der Eintrag kommt
-- danach dazu. Gibt es die Funktionen auf einem Client nicht, entfällt der Eintrag still.
local function AddGameMenuButton()
	local gm = _G.GameMenuFrame
	if not (gm and gm.AddButton and gm.InitButtons and hooksecurefunc) then return end
	hooksecurefunc(gm, "InitButtons", function(self)
		pcall(function()
			-- Name mit dem Farbverlauf (violett nach weiß) wie im Titel des Addons in der Addon-Liste
			local title = "|cffb48cffSexy|r|cffbd9affE|cffc7a9ffd|cffd0b7ffi|cffdac6fft|cffe3d4ffM|cffece2ffo|cfff6f1ffd|cffffffffe|r"
			local button = self:AddButton(title, function(_, mouse)
				if not InCombatLockdown() and HideUIPanel then HideUIPanel(GameMenuFrame) end
				if mouse == "RightButton" then lib:ToggleEditMode() else lib:ToggleHub() end
			end)
			-- Tooltip und Rechtsklick (Fenster entsperren). Die Knöpfe des Menüs kommen aus einem Pool: Rechtsklick nur für unseren
			-- Knopf zulassen, bei den übrigen zurücknehmen; die Tooltip-Skripte prüfen den Text, falls der Knopf später anders belegt wird.
			if type(button) == "table" and button.RegisterForClicks then
				if self.buttonPool and self.buttonPool.EnumerateActive then
					for b in self.buttonPool:EnumerateActive() do
						if b ~= button and b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp") end
					end
				end
				button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
				if not button.sexyTip then
					button.sexyTip = true
					button:HookScript("OnEnter", function(b)
						if b:GetText() ~= title then return end
						GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
						GameTooltip:SetText("SexyEditMode")
						GameTooltip:AddLine(L.menuLeft, 0.8, 0.8, 0.8)
						GameTooltip:AddLine(L.menuRight, 0.8, 0.8, 0.8)
						GameTooltip:Show()
					end)
					button:HookScript("OnLeave", function() GameTooltip:Hide() end)
				end
			end
			-- direkt über dem Eintrag "AddOns" des Menüs (dort stehen auch andere Addons): das Layout ordnet nach layoutIndex. Liefert
			-- AddButton den Knopf nicht zurück oder gibt es keinen AddOns-Eintrag, bleibt der Eintrag unten.
			if type(button) == "table" and self.buttonPool and self.buttonPool.EnumerateActive then
				local ref
				for b in self.buttonPool:EnumerateActive() do
					if b ~= button and b.GetText and b:GetText() == (_G.ADDONS or "AddOns") then ref = b end
				end
				if ref and ref.layoutIndex then button.layoutIndex = ref.layoutIndex - 0.25 end
			end
			if self.Layout then self:Layout() end
		end)
	end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	AddGameMenuButton()
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
				lib:ToggleMoveMode()
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
