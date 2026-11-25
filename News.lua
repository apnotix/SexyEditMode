-- Neuigkeiten: gemeinsame Patch-Notes aller Sexy-Addons als Seite im Einstellungsfenster (Addon-Liste links, Einträge rechts).
--
-- Jedes Addon pflegt seine Texte in einer eigenen Datei (News.lua im Addon) und meldet sie an:
--   LibStub("SexyEditMode-1.0"):RegisterNews("SexyLoot", {
--       color = { 0.79, 0.64, 0.35 },                      -- Farbe des Addons
--       { v = "0.1.25",                                     -- Versionen, die neueste zuerst
--           { "Titel", "Text", "Title", "Text" },           -- Eintrag: deutscher Titel, Text, englischer Titel, Text
--       },
--   })
-- Neu ist alles, was jünger ist als die zuletzt gesehene Version des Addons (ohne gemerkte Version: nur die neueste).
-- Gesehen gilt es, sobald die Seite verlassen oder das Einstellungsfenster geschlossen wird. Beim Start öffnet sich das
-- Einstellungsfenster auf dieser Seite, wenn es etwas Neues gibt (abschaltbar). Sonst: /sem news oder der Eintrag in der Leiste.

local lib = LibStub("SexyEditMode-1.0", true)
if not (lib and lib.ui) then return end

local ui = lib.ui
local Text = ui.Text
local de = GetLocale() == "deDE"
local function T(d, e) return de and d or e end

local GOLD, EDGE = ui.GOLD, ui.EDGE
local TITLE_FONT = "Interface/AddOns/SexyEditMode/media/fonts/Marcellus-Regular.ttf"

lib.news = lib.news or {}
lib.newsOrder = lib.newsOrder or {}

local RAIL_W, ITEM_H = 230, 54
local CONTENT_W = 590
local FOOT_H = 44

local panel, selectedId
local expanded = {}

function lib:RegisterNews(id, data)
	if type(data) ~= "table" then return end
	if not self.news[id] then self.newsOrder[#self.newsOrder + 1] = id end
	self.news[id] = data
end

local function Store()
	SexyEditModeDB = SexyEditModeDB or {}
	SexyEditModeDB.newsSeen = SexyEditModeDB.newsSeen or {}
	return SexyEditModeDB
end

local function VNum(v)
	local t = {}
	for n in tostring(v or ""):gmatch("%d+") do t[#t + 1] = tonumber(n) end
	return t
end

local function Newer(a, b)
	local x, y = VNum(a), VNum(b)
	for i = 1, math.max(#x, #y) do
		local p, q = x[i] or 0, y[i] or 0
		if p ~= q then return p > q end
	end
	return false
end

local function IsNew(id, v)
	local data = lib.news[id]
	if not (data and data[1]) then return false end
	local seen = Store().newsSeen[id]
	if seen == nil then return v == data[1].v end
	return Newer(v, seen)
end

local function AddonNew(id)
	local data = lib.news[id]
	return data and data[1] and IsNew(id, data[1].v) or false
end

function lib:NewsHasNew()
	for _, id in ipairs(self.newsOrder) do
		if AddonNew(id) then return true end
	end
	return false
end

-- Alles als gesehen merken (beim Verlassen der Seite)
function lib:NewsMarkSeen()
	local d = Store()
	for _, id in ipairs(self.newsOrder) do
		local data = self.news[id]
		if data and data[1] then d.newsSeen[id] = data[1].v end
	end
	if self.hub and self.hub:IsShown() and self.BuildRail then self:BuildRail() end
end

local function Pick(item, k)   -- k = 1 Titel, 2 Text
	if de then return item[k] end
	return item[k + 2] or item[k]
end

local function AddonTitle(id)
	local a = lib.addons and lib.addons[id]
	return a and a.title or id
end

-- Darstellung ----------------------------------------------------------------------------

local function Solid(parent, layer, c)
	local t = parent:CreateTexture(nil, layer)
	t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
	return t
end

local function NewPool(create)
	local pool = { used = 0, items = {} }
	function pool:Next()
		self.used = self.used + 1
		local it = self.items[self.used]
		if not it then it = create(); self.items[self.used] = it end
		it:Show()
		return it
	end
	function pool:Reset()
		for i = 1, #self.items do self.items[i]:Hide(); self.items[i]:ClearAllPoints() end
		self.used = 0
	end
	return pool
end

local function Redraw()
	local f = panel
	if not f then return end
	local ids = lib.newsOrder

	-- Liste links
	for i, id in ipairs(ids) do
		local r = f.rail[i]
		if not r then
			r = CreateFrame("Button", nil, f.railBg)
			r:SetSize(RAIL_W - 1, ITEM_H)
			r:SetPoint("TOPLEFT", 0, -8 - (i - 1) * ITEM_H)
			r.sel = Solid(r, "BACKGROUND", { 0.227, 0.169, 0.106, 1 })
			r.sel:SetAllPoints()
			r.hl = Solid(r, "HIGHLIGHT", { 1, 1, 1, 0.05 })
			r.hl:SetAllPoints()
			r.bar = Solid(r, "ARTWORK", { GOLD[1], GOLD[2], GOLD[3], 1 })
			r.bar:SetPoint("TOPLEFT")
			r.bar:SetPoint("BOTTOMLEFT")
			r.bar:SetWidth(3)
			r.sq = r:CreateTexture(nil, "ARTWORK")
			r.sq:SetSize(30, 30)
			r.sq:SetPoint("LEFT", 14, 0)
			r.name = Text(r, "GameFontHighlight", 12)
			r.name:SetPoint("TOPLEFT", r.sq, "TOPRIGHT", 10, 0)
			r.name:SetWidth(RAIL_W - 96)
			r.name:SetJustifyH("LEFT")
			r.name:SetWordWrap(false)
			r.ver = Text(r, "GameFontHighlightSmall", 11)
			r.ver:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
			r.ver:SetTextColor(0.71, 0.65, 0.53)
			r.new = Text(r, "GameFontHighlightSmall", 11)
			r.new:SetPoint("RIGHT", -8, 0)
			r.new:SetTextColor(0.48, 0.88, 0.56)
			r.new:SetText(T("neu", "new"))
			r:SetScript("OnClick", function(self)
				selectedId = self.id
				Redraw()
			end)
			f.rail[i] = r
		end
		r.id = id
		local data = lib.news[id]
		local a = lib.addons and lib.addons[id]
		r.sq:SetTexture((a and a.icon) or ("Interface/AddOns/" .. id .. "/icon.tga"))
		r.name:SetText(AddonTitle(id))
		r.ver:SetText(data[1] and ("v" .. data[1].v) or "")
		r.new:SetShown(AddonNew(id))
		local on = id == selectedId
		r.sel:SetShown(on)
		r.bar:SetShown(on)
		r.name:SetTextColor(on and 0.96 or 0.85, on and 0.89 or 0.8, on and 0.69 or 0.66)
		r:Show()
	end
	for i = #ids + 1, #f.rail do f.rail[i]:Hide() end

	-- Inhalt rechts
	local data = selectedId and lib.news[selectedId]
	f.pHead:Reset(); f.pText:Reset(); f.pBox:Reset()
	if not data then return end
	local c = data.color or { 0.8, 0.7, 0.4 }
	f.title:SetText(AddonTitle(selectedId))
	f.pill:SetText(data[1] and data[1].v or "")
	f.pillBg:SetWidth(f.pill:GetStringWidth() + 18)
	local isNew = AddonNew(selectedId)
	f.sub:SetText(isNew and T("neu seit deinem letzten Start", "new since your last start") or "")

	local y = 0
	local child = f.child
	for vi, ver in ipairs(data) do
		local key = selectedId .. ":" .. ver.v
		local open = expanded[key]
		if open == nil then open = IsNew(selectedId, ver.v) or (vi == 1) end
		local head = f.pHead:Next()
		head:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
		head.key = key
		head.open = open
		head.arrow:SetText(open and "v" or ">")
		head.label:SetText(ver.v)
		head.count:SetText(T("%d Einträge", "%d entries"):format(#ver))
		head.fresh:SetShown(IsNew(selectedId, ver.v))
		y = y + 34 + 4
		if open then
			local box = f.pBox:Next()
			box:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
			box.bar:SetColorTexture(c[1], c[2], c[3], 1)
			local by = 8
			for _, item in ipairs(ver) do
				local t = f.pText:Next()
				t:SetParent(box)   -- die Box ist ein Rahmen und würde Text des Scroll-Inhalts überdecken
				t:SetFont(ui.TEXT_FONT or STANDARD_TEXT_FONT, 11, "")
				t:SetTextColor(0.71, 0.65, 0.53)
				t:SetPoint("TOPLEFT", box, "TOPLEFT", 16, -by)
				t:SetWidth(CONTENT_W - 32)
				t:SetText((Pick(item, 1) or ""):upper())
				by = by + t:GetStringHeight() + 2
				local d = f.pText:Next()
				d:SetParent(box)
				d:SetFont(ui.TEXT_FONT or STANDARD_TEXT_FONT, 12, "")
				d:SetTextColor(0.85, 0.80, 0.66)
				d:SetPoint("TOPLEFT", box, "TOPLEFT", 16, -by)
				d:SetWidth(CONTENT_W - 32)
				d:SetText(Pick(item, 2) or "")
				by = by + d:GetStringHeight() + 7
			end
			box:SetHeight(by + 2)
			y = y + by + 2 + 8
		end
	end
	child:SetHeight(math.max(y, 1))
	f.scroll:SetVerticalScroll(0)
end

-- Seite im Einstellungsfenster (Rahmen: Hub.lua, ProfileMode)
function lib:FillNewsPanel(f)
	panel = f
	f.rail = {}

	-- Liste der Addons links
	f.railBg = CreateFrame("Frame", nil, f)
	f.railBg:SetPoint("TOPLEFT", 0, 0)
	f.railBg:SetPoint("BOTTOMLEFT", 0, 0)
	f.railBg:SetWidth(RAIL_W)
	local rb = Solid(f.railBg, "BACKGROUND", { 0.114, 0.078, 0.05, 1 })
	rb:SetAllPoints()
	local rl = Solid(f.railBg, "BORDER", { 0.24, 0.185, 0.122, 1 })
	rl:SetPoint("TOPRIGHT")
	rl:SetPoint("BOTTOMRIGHT")
	rl:SetWidth(1)

	-- Kopf des gewählten Addons
	local x = RAIL_W + 24
	f.title = Text(f, "GameFontNormal", 26)
	f.title:SetFont(TITLE_FONT, 26, "")
	f.title:SetTextColor(0.96, 0.89, 0.69)
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", x, -16)
	f.pillBg = Solid(f, "ARTWORK", { 0.082, 0.188, 0.11, 1 })
	f.pillBg:SetHeight(20)
	f.pillBg:SetPoint("LEFT", f.title, "RIGHT", 12, 0)
	f.pill = Text(f, "GameFontHighlightSmall", 13)
	f.pill:SetTextColor(0.48, 0.88, 0.56)
	f.pill:SetPoint("CENTER", f.pillBg, "CENTER", 0, 0)
	f.sub = Text(f, "GameFontHighlightSmall", 13)
	f.sub:SetTextColor(0.48, 0.88, 0.56)
	f.sub:SetPoint("LEFT", f.pillBg, "RIGHT", 12, 0)

	-- Scrollbereich mit den Versionen
	f.scroll = CreateFrame("ScrollFrame", nil, f)
	f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", x, -58)
	f.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, FOOT_H + 8)
	f.child = CreateFrame("Frame", nil, f.scroll)
	f.child:SetSize(CONTENT_W, 10)
	f.scroll:SetScrollChild(f.child)
	f.scroll:EnableMouseWheel(true)
	f.scroll:SetScript("OnMouseWheel", function(self, delta)
		local maxScroll = math.max(0, f.child:GetHeight() - self:GetHeight())
		self:SetVerticalScroll(math.max(0, math.min(maxScroll, self:GetVerticalScroll() - delta * 40)))
	end)

	f.pHead = NewPool(function()
		local b = CreateFrame("Button", nil, f.child)
		b:SetSize(CONTENT_W, 34)
		b.bg = Solid(b, "BACKGROUND", { 0.15, 0.12, 0.07, 1 })
		b.bg:SetAllPoints()
		b.hl = Solid(b, "HIGHLIGHT", { 1, 1, 1, 0.05 })
		b.hl:SetAllPoints()
		b.arrow = Text(b, "GameFontNormal", 14)
		b.arrow:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		b.arrow:SetPoint("LEFT", 12, 0)
		b.label = Text(b, "GameFontHighlight", 14)
		b.label:SetPoint("LEFT", 32, 0)
		b.count = Text(b, "GameFontHighlightSmall", 12)
		b.count:SetPoint("RIGHT", -12, 0)
		b.count:SetTextColor(0.71, 0.65, 0.53)
		b.fresh = Text(b, "GameFontHighlightSmall", 11)
		b.fresh:SetPoint("LEFT", b.label, "RIGHT", 10, 0)
		b.fresh:SetTextColor(0.48, 0.88, 0.56)
		b.fresh:SetText(T("neu", "new"))
		b:SetScript("OnClick", function(self)
			expanded[self.key] = not self.open
			Redraw()
		end)
		return b
	end)
	f.pBox = NewPool(function()
		local b = CreateFrame("Frame", nil, f.child)
		b:SetWidth(CONTENT_W)
		b.bg = Solid(b, "BACKGROUND", { 0.165, 0.125, 0.086, 1 })
		b.bg:SetAllPoints()
		b.bar = Solid(b, "ARTWORK", { GOLD[1], GOLD[2], GOLD[3], 1 })
		b.bar:SetPoint("TOPLEFT")
		b.bar:SetPoint("BOTTOMLEFT")
		b.bar:SetWidth(3)
		return b
	end)
	f.pText = NewPool(function()
		local t = Text(f.child, "GameFontHighlight", 14)
		t:SetJustifyH("LEFT")
		t:SetJustifyV("TOP")
		t:SetWordWrap(true)
		return t
	end)

	-- Fußzeile der Seite: Schalter für das Fenster beim Start
	local fl = Solid(f, "BORDER", { 0.24, 0.185, 0.122, 1 })
	fl:SetPoint("BOTTOMLEFT", RAIL_W + 1, FOOT_H)
	fl:SetPoint("BOTTOMRIGHT", 0, FOOT_H)
	fl:SetHeight(1)
	local cb = CreateFrame("Button", nil, f)
	cb:SetSize(500, 26)
	cb:SetPoint("BOTTOMLEFT", x, 9)
	-- Kästchen wie im Einstellungsdialog: Rand, dunkle Fläche, goldenes Quadrat
	cb.edge = Solid(cb, "ARTWORK", { EDGE[1], EDGE[2], EDGE[3], 1 })
	cb.edge:SetSize(16, 16)
	cb.edge:SetPoint("LEFT", 0, 0)
	cb.box = Solid(cb, "OVERLAY", { 0.06, 0.05, 0.04, 1 })
	cb.box:SetPoint("TOPLEFT", cb.edge, "TOPLEFT", 1, -1)
	cb.box:SetPoint("BOTTOMRIGHT", cb.edge, "BOTTOMRIGHT", -1, 1)
	cb.mark = cb:CreateTexture(nil, "OVERLAY", nil, 2)
	cb.mark:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
	cb.mark:SetPoint("TOPLEFT", cb.edge, "TOPLEFT", 3, -3)
	cb.mark:SetPoint("BOTTOMRIGHT", cb.edge, "BOTTOMRIGHT", -3, 3)
	cb.text = Text(cb, "GameFontHighlight", 13)
	cb.text:SetPoint("LEFT", cb.edge, "RIGHT", 10, 0)
	cb.text:SetText(T("Nur beim Start zeigen, wenn es etwas Neues gibt", "Only show at start when there is something new"))
	cb.text:SetTextColor(0.85, 0.80, 0.66)
	local function Sync() cb.mark:SetShown(not Store().newsOff) end
	cb:SetScript("OnClick", function()
		local d = Store()
		d.newsOff = not d.newsOff or nil
		Sync()
	end)
	f.syncCheck = Sync

	-- Seite verlassen (oder Einstellungsfenster schließen): alles gilt als gesehen
	f:SetScript("OnHide", function() lib:NewsMarkSeen() end)
end

-- Seite zeigen/aktualisieren (von Hub.lua beim Wechsel auf die Seite)
function lib:RefreshNews(id)
	if not panel then return end
	if id and self.news[id] then selectedId = id end
	if not (selectedId and self.news[selectedId]) then
		selectedId = nil
		for _, nid in ipairs(self.newsOrder) do
			if AddonNew(nid) then selectedId = nid break end
		end
		selectedId = selectedId or self.newsOrder[1]
	end
	panel.syncCheck()
	local ok, err = pcall(Redraw)
	if not ok then print("|cffe8c26aSexyEditMode|r News: " .. tostring(err)) end
end

function lib:OpenNews(id)
	if #self.newsOrder == 0 then return end
	if id and self.news[id] then selectedId = id end
	self:HubShowNews()
end

function lib:ToggleNews()
	if self.hub and self.hub:IsShown() and self.hubProfiles == "news" then self.hub:Hide() else self:OpenNews() end
end

-- Beim Start: Einstellungsfenster auf dieser Seite öffnen, wenn es etwas Neues gibt (und nicht im Kampf)
local starter = CreateFrame("Frame")
starter:RegisterEvent("PLAYER_LOGIN")
starter:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		C_Timer.After(5, function()
			if Store().newsOff or not lib:NewsHasNew() then return end
			if InCombatLockdown() then
				self:RegisterEvent("PLAYER_REGEN_ENABLED")
			else
				lib:OpenNews()
			end
		end)
	else
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		if lib:NewsHasNew() then lib:OpenNews() end
	end
end)
