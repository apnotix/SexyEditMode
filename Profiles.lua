local lib = LibStub("SexyEditMode-1.0", true)
if not (lib and lib.ui) then return end

-- Profile für alle Sexy-Addons zusammen: Einstellungen und Fensterpositionen werden als Kopie gespeichert (SexyEditModeDB.profiles),
-- lassen sich wechseln, einem Charakter zuweisen, exportieren und importieren. Jedes Addon meldet mit lib:RegisterProfile(id, spec),
-- welche Daten zu einem Profil gehören:
--   spec = { db = function() return Tabelle end, keys = { "cfg", "frames", ... } }    -- nur diese Schlüssel (ohne keys: die ganze Tabelle)
-- Ein Wechsel schreibt die Daten der Addons um und fragt danach, ob die Oberfläche neu geladen werden soll: viele Einstellungen
-- werden erst beim Laden gelesen.

local ui = lib.ui
local de = GetLocale() == "deDE"
local function T(d, e) return de and d or e end

lib.profileProviders = lib.profileProviders or {}
lib.profileOrder = lib.profileOrder or {}

function lib:RegisterProfile(addonId, spec)
	if not self.profileProviders[addonId] then table.insert(self.profileOrder, addonId) end
	self.profileProviders[addonId] = spec
end

-- SexyEditMode selbst: Minimap-Knopf und Einstellungen des Verschiebe-Modus
lib:RegisterProfile("SexyEditMode", { db = function() return SexyEditModeDB end, keys = { "minimap", "move" } })

-- Daten ---------------------------------------------------------------------------------------------------------------

-- Tiefe Kopie nur aus Texten, Zahlen, Wahrheitswerten und Tabellen; Metatabellen (Standardwerte) werden nicht kopiert
local function Copy(v, depth)
	if type(v) ~= "table" then return v end
	depth = depth or 0
	if depth > 40 then return nil end
	local t = {}
	for k, x in pairs(v) do
		local tk, tv = type(k), type(x)
		if tk == "string" or tk == "number" then
			if tv == "table" then t[k] = Copy(x, depth + 1)
			elseif tv == "string" or tv == "number" or tv == "boolean" then t[k] = x end
		end
	end
	return t
end

local function ProviderGet(spec)
	local db = spec.db()
	if type(db) ~= "table" then return nil end
	if spec.keys then
		local t = {}
		for _, k in ipairs(spec.keys) do
			if db[k] ~= nil then t[k] = Copy(db[k]) end
		end
		return t
	end
	return Copy(db)
end

local function ProviderSet(spec, data)
	local db = spec.db()
	if type(db) ~= "table" or type(data) ~= "table" then return end
	if spec.keys then
		for _, k in ipairs(spec.keys) do
			if data[k] ~= nil then db[k] = Copy(data[k]) else db[k] = nil end
		end
	else
		for k in pairs(db) do db[k] = nil end
		for k, v in pairs(data) do db[k] = Copy(v) end
	end
end

local function Store()
	SexyEditModeDB = SexyEditModeDB or {}
	local d = SexyEditModeDB
	d.profiles = d.profiles or {}
	d.profileChars = d.profileChars or {}
	return d
end

-- "Name-Server"; der Server kann kurz nach dem Login noch leer sein, dann ohne Strich
local function CharParts()
	local name, realm = UnitFullName and UnitFullName("player")
	name = name or UnitName("player") or "?"
	if not realm or realm == "" then realm = GetNormalizedRealmName and GetNormalizedRealmName() end
	if not realm or realm == "" then realm = GetRealmName and GetRealmName() end
	if (not realm or realm == "") and GetCVar then realm = GetCVar("realmName") end
	-- Dieser Client kennt Vor- und Nachnamen ("Apnotix Shyrk"): UnitName liefert nur den ersten Teil, die GUID-Info den vollen Namen
	if GetPlayerInfoByGUID and UnitGUID then
		local ok, _, _, _, _, _, full, r = pcall(GetPlayerInfoByGUID, UnitGUID("player"))
		if ok and type(full) == "string" and full ~= "" then name = full end
		if ok and (not realm or realm == "") then realm = r end
	end
	if realm == "" then realm = nil end
	return name, realm
end

local function CharKey()
	local name, realm = CharParts()
	return realm and (name .. "-" .. realm) or name
end

-- /sem who: zeigt, was der Client als Servernamen liefert
function lib:PrintCharInfo()
	local function V(f, ...) if not f then return "nil" end local ok, a = pcall(f, ...) return ok and ("\"" .. tostring(a) .. "\"") or "Fehler" end
	local _, uf = UnitFullName and UnitFullName("player")
	print("|cffe8c26aSexyEditMode|r UnitFullName=\"" .. tostring(uf) .. "\" GetRealmName=" .. V(GetRealmName) ..
		" Normalized=" .. V(GetNormalizedRealmName) .. " CVar realmName=" .. V(GetCVar, "realmName") ..
		" Schlüssel=\"" .. CharKey() .. "\"")
	if GetPlayerInfoByGUID and UnitGUID then
		print("GUID-Info: " .. table.concat({ tostring(select(1, pcall(GetPlayerInfoByGUID, UnitGUID("player")))), select(2, pcall(function()
			local t = { GetPlayerInfoByGUID(UnitGUID("player")) }
			for i = 1, 8 do t[i] = tostring(t[i]) end
			return table.concat(t, " | ", 1, 8)
		end)) }, " "))
	end
end

-- Aktueller Stand aller Addons: { [Addon] = Daten }
function lib:ProfileSnapshot()
	local snap = {}
	for _, id in ipairs(self.profileOrder) do
		local ok, data = pcall(ProviderGet, self.profileProviders[id])
		if ok and data then snap[id] = data end
	end
	return snap
end

-- Änderungen seit dem Wechsel gehören zum aktiven Profil: vor jedem Wechsel und beim Beenden dort ablegen
function lib:SaveActiveProfile()
	local d = Store()
	if d.profileActive and d.profiles[d.profileActive] then
		d.profiles[d.profileActive] = self:ProfileSnapshot()
	end
end

function lib:ApplyProfileData(snap)
	for _, id in ipairs(self.profileOrder) do
		if snap[id] then pcall(ProviderSet, self.profileProviders[id], snap[id]) end
	end
end

local function ValidName(name, d)
	name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then return nil, T("Bitte einen Namen eingeben.", "Please enter a name.") end
	if #name > 32 then return nil, T("Der Name ist zu lang (höchstens 32 Zeichen).", "The name is too long (32 characters at most).") end
	if d.profiles[name] then return nil, T("Ein Profil mit diesem Namen gibt es schon.", "A profile with this name already exists.") end
	return name
end

-- Neues Profil aus dem aktuellen Stand; es wird aktiv (die Werte sind ja dieselben, kein Neuladen nötig)
function lib:NewProfile(name)
	local d = Store()
	local n, err = ValidName(name, d)
	if not n then return false, err end
	self:SaveActiveProfile()
	d.profiles[n] = self:ProfileSnapshot()
	d.profileActive = n
	return true, n
end

function lib:CopyProfile(from, name)
	local d = Store()
	if not d.profiles[from] then return false end
	local n, err = ValidName(name, d)
	if not n then return false, err end
	self:SaveActiveProfile()
	d.profiles[n] = Copy(d.profiles[from])
	return true, n
end

function lib:RenameProfile(from, name)
	local d = Store()
	if not d.profiles[from] then return false end
	local n, err = ValidName(name, d)
	if not n then return false, err end
	d.profiles[n], d.profiles[from] = d.profiles[from], nil
	if d.profileActive == from then d.profileActive = n end
	for char, p in pairs(d.profileChars) do
		if p == from then d.profileChars[char] = n end
	end
	return true, n
end

function lib:DeleteProfile(name)
	local d = Store()
	if not d.profiles[name] or d.profileActive == name then return false end
	d.profiles[name] = nil
	for char, p in pairs(d.profileChars) do
		if p == name then d.profileChars[char] = nil end
	end
	return true
end

function lib:ActivateProfile(name, silent)
	local d = Store()
	if not d.profiles[name] then return false end
	if d.profileActive == name then return true end
	self:SaveActiveProfile()
	self:ApplyProfileData(d.profiles[name])
	d.profileActive = name
	if not silent and self.ShowReloadPopup then self:ShowReloadPopup(name) end
	return true
end

-- Export und Import ---------------------------------------------------------------------------------------------------
-- Text: "SEMP1:" und Base64 einer Tabellenschrift (eigene Schrift, keine Lua-Auswertung: das Einlesen versteht nur Texte, Zahlen,
-- Wahrheitswerte und Tabellen mit Grenzen für Tiefe und Größe)

local function SerString(s)
	return '"' .. (s:gsub('[%c"\\]', function(c) return ("\\%03d"):format(c:byte()) end)) .. '"'
end

local function Ser(v, out, depth)
	local tv = type(v)
	if tv == "table" then
		if depth > 40 then return end
		out[#out + 1] = "{"
		for k, x in pairs(v) do
			local tk, tx = type(k), type(x)
			if (tk == "string" or tk == "number") and (tx == "table" or tx == "string" or tx == "number" or tx == "boolean") then
				out[#out + 1] = tk == "number" and ("#" .. ("%.14g"):format(k)) or SerString(k)
				out[#out + 1] = "="
				Ser(x, out, depth + 1)
				out[#out + 1] = ","
			end
		end
		out[#out + 1] = "}"
	elseif tv == "string" then
		out[#out + 1] = SerString(v)
	elseif tv == "number" then
		out[#out + 1] = "#" .. ("%.14g"):format(v)
	elseif tv == "boolean" then
		out[#out + 1] = v and "T" or "F"
	end
end

local function Parse(s)
	local pos, nodes = 1, 0
	local function Fail(msg) error(msg, 0) end
	local function Number()
		local a, b = s:find("^#[%-%+%.%deE]+", pos)
		if not a then Fail("Zahl") end
		local n = tonumber(s:sub(a + 1, b))
		if not n or n ~= n or n == math.huge or n == -math.huge then Fail("Zahl") end
		pos = b + 1
		return n
	end
	local function String()
		if s:sub(pos, pos) ~= '"' then Fail("Text") end
		pos = pos + 1
		local parts = {}
		while true do
			local a = s:find('[\\"]', pos)
			if not a then Fail("Text") end
			parts[#parts + 1] = s:sub(pos, a - 1)
			if s:sub(a, a) == '"' then
				pos = a + 1
				return table.concat(parts)
			end
			local n = tonumber(s:match("^%d%d%d", a + 1))
			if not n or n > 255 then Fail("Escape") end
			parts[#parts + 1] = string.char(n)
			pos = a + 4
		end
	end
	local function Value(depth)
		if depth > 40 then Fail("zu tief") end
		nodes = nodes + 1
		if nodes > 300000 then Fail("zu groß") end
		local c = s:sub(pos, pos)
		if c == "{" then
			pos = pos + 1
			local t = {}
			while true do
				local d = s:sub(pos, pos)
				if d == "}" then pos = pos + 1 return t end
				if d == "" then Fail("Ende") end
				local key
				if d == "#" then key = Number() else key = String() end
				if s:sub(pos, pos) ~= "=" then Fail("=") end
				pos = pos + 1
				t[key] = Value(depth + 1)
				if s:sub(pos, pos) ~= "," then Fail(",") end
				pos = pos + 1
			end
		elseif c == '"' then return String()
		elseif c == "#" then return Number()
		elseif c == "T" then pos = pos + 1 return true
		elseif c == "F" then pos = pos + 1 return false
		end
		Fail("Zeichen")
	end
	local v = Value(1)
	if pos <= #s then Fail("Rest") end
	return v
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64DEC = {}
for i = 1, 64 do B64DEC[B64:byte(i)] = i - 1 end

local function Enc(data)
	local out = {}
	for i = 1, #data, 3 do
		local a, b, c = data:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1, c2 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64
		local c3, c4 = math.floor(n / 64) % 64, n % 64
		out[#out + 1] = B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
			.. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "=")
	end
	return table.concat(out)
end

local function Dec(text)
	text = (text:gsub("[^%w%+/=]", ""))
	if #text % 4 ~= 0 then return nil end
	local out = {}
	for i = 1, #text, 4 do
		local a, b, c, d = text:byte(i, i + 3)
		local n1, n2 = B64DEC[a], B64DEC[b]
		local n3 = c ~= 61 and B64DEC[c] or nil
		local n4 = d ~= 61 and B64DEC[d] or nil
		if not (n1 and n2) or (c ~= 61 and not n3) or (d ~= 61 and not n4) then return nil end
		local n = n1 * 262144 + n2 * 4096 + (n3 or 0) * 64 + (n4 or 0)
		out[#out + 1] = string.char(math.floor(n / 65536))
		if n3 then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
		if n4 then out[#out + 1] = string.char(n % 256) end
	end
	return table.concat(out)
end

local PREFIX = "SEMP1:"

function lib:ExportProfile(name)
	local d = Store()
	if not d.profiles[name] then return nil end
	if d.profileActive == name then self:SaveActiveProfile() end
	local out = {}
	Ser({ v = 1, name = name, data = d.profiles[name] }, out, 0)
	return PREFIX .. Enc(table.concat(out))
end

-- liefert Name und Daten oder nil und eine Fehlermeldung
function lib:ParseProfileText(text)
	text = (text or ""):gsub("%s", "")
	if #text > 3000000 then return nil, T("Der Text ist zu lang.", "The text is too long.") end
	if text:sub(1, #PREFIX) ~= PREFIX then return nil, T("Das ist kein Profil-Text (er beginnt nicht mit SEMP1:).", "This is not a profile text (it does not start with SEMP1:).") end
	local raw = Dec(text:sub(#PREFIX + 1))
	if not raw then return nil, T("Der Text ist beschädigt (Base64).", "The text is damaged (Base64).") end
	local ok, t = pcall(Parse, raw)
	if not ok or type(t) ~= "table" or t.v ~= 1 or type(t.data) ~= "table" then
		return nil, T("Der Text ist beschädigt oder stammt aus einer anderen Version.", "The text is damaged or comes from another version.")
	end
	return type(t.name) == "string" and t.name or "", t.data
end

function lib:ImportProfile(text, name)
	local d = Store()
	local pname, data = self:ParseProfileText(text)
	if not pname then return false, data end
	if (name or "") == "" then name = pname end
	local n, err = ValidName(name, d)
	if not n then return false, err end
	d.profiles[n] = Copy(data)
	return true, n
end

-- Fenster -------------------------------------------------------------------------------------------------------------

local GOLD, GREEN, BAND, EDGE, BG = ui.GOLD, ui.GREEN, ui.BAND, ui.EDGE, ui.BG
local frame, popupReload, popupText
local popupCount = 0
local selected
local offset = 0
local ROWS, ROW_H = 7, 52

local function Names()
	local list = {}
	for n in pairs(Store().profiles) do list[#list + 1] = n end
	table.sort(list, function(a, b) return a:lower() < b:lower() end)
	return list
end

local function MakeEdit(parent, w)
	local e = CreateFrame("EditBox", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	e:SetSize(w, 24)
	e:SetAutoFocus(false)
	ui.Face(e, "GameFontHighlightSmall")
	e:SetTextInsets(6, 6, 0, 0)
	ui.Backdrop(e, { 0.05, 0.04, 0.03, 1 }, EDGE)
	e:SetScript("OnEscapePressed", e.ClearFocus)
	e:SetScript("OnEnterPressed", e.ClearFocus)
	return e
end

local function Popup(w, h, title)
	local p = ui.NewFrame(UIParent)
	p:SetSize(w, h)
	p:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	p:SetFrameStrata("FULLSCREEN_DIALOG")
	p:SetFrameLevel(200)
	p:SetClampedToScreen(true)
	p:SetMovable(true)
	p:EnableMouse(true)
	p:RegisterForDrag("LeftButton")
	p:SetScript("OnDragStart", p.StartMoving)
	p:SetScript("OnDragStop", p.StopMovingOrSizing)
	ui.Backdrop(p, BG, EDGE)
	p.band = p:CreateTexture(nil, "BACKGROUND", nil, 1)
	p.band:SetPoint("TOPLEFT", 3, -3)
	p.band:SetPoint("TOPRIGHT", -3, -3)
	p.band:SetHeight(26)
	p.band:SetColorTexture(BAND[1], BAND[2], BAND[3], 1)
	p.title = ui.Text(p, "GameFontNormal", 14)
	p.title:SetPoint("LEFT", p.band, "LEFT", 10, 0)
	p.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	p.title:SetText(title)
	p:Hide()
	-- ESC schließt das Fenster (dafür muss es global benannt in UISpecialFrames stehen)
	popupCount = popupCount + 1
	local gname = "SexyEditModeProfilePopup" .. popupCount
	_G[gname] = p
	tinsert(UISpecialFrames, gname)
	return p
end

-- Nach einem Wechsel: Neu laden oder später
function lib:ShowReloadPopup(name)
	if not popupReload then
		popupReload = Popup(400, 150, T("Profil gewechselt", "Profile switched"))
		popupReload:SetFrameLevel(300)
		popupReload.text = ui.Text(popupReload, "GameFontHighlight")
		popupReload.text:SetPoint("TOPLEFT", 14, -40)
		popupReload.text:SetPoint("RIGHT", popupReload, "RIGHT", -14, 0)
		popupReload.text:SetJustifyH("LEFT")
		local now = ui.HeaderButton(popupReload, T("Neu laden", "Reload"), 150, 28)
		now:SetPoint("BOTTOMLEFT", 14, 14)
		now:SetScript("OnClick", function() ReloadUI() end)
		local later = ui.HeaderButton(popupReload, T("Später", "Later"), 150, 28)
		later:SetPoint("BOTTOMRIGHT", -14, 14)
		later:SetScript("OnClick", function() popupReload:Hide() end)
	end
	popupReload.text:SetText(T("Das Profil „%s“ ist aktiv. Die Oberfläche muss neu geladen werden, damit alle Fenster die Einstellungen übernehmen. Bis dahin gehen Änderungen nicht in das Profil.",
		"The profile \"%s\" is active. The interface has to be reloaded for all windows to take over the settings. Until then changes do not go into the profile."):format(name or ""))
	popupReload:ClearAllPoints()
	popupReload:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	popupReload:Show()
end

-- Export (Text zum Kopieren) und Import (Text einfügen, Namen wählen)
local function ShowText(mode, text)
	if not popupText then
		popupText = Popup(520, 330, "")
		popupText.label = ui.Text(popupText, "GameFontNormalSmall")
		popupText.label:SetPoint("TOPLEFT", 14, -38)
		popupText.label:SetTextColor(0.71, 0.65, 0.53)
		-- sichtbares Eingabefeld: eigener Rahmen, bei Fokus golden
		local box = CreateFrame("Frame", nil, popupText, BackdropTemplateMixin and "BackdropTemplate" or nil)
		box:SetPoint("TOPLEFT", 12, -56)
		box:SetSize(496, 176)
		ui.Backdrop(box, { 0.03, 0.025, 0.02, 1 }, EDGE)
		popupText.box = box
		local sf = CreateFrame("ScrollFrame", nil, popupText)
		sf:SetPoint("TOPLEFT", box, "TOPLEFT", 6, -6)
		sf:SetSize(484, 164)
		local eb = CreateFrame("EditBox", nil, sf)
		eb:SetMultiLine(true)
		ui.Face(eb, "GameFontHighlightSmall")
		eb:SetWidth(480)
		eb:SetHeight(164)
		eb:SetAutoFocus(false)
		eb:SetMaxLetters(0)
		eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); popupText:Hide() end)
		local hint = ui.Text(popupText, "GameFontDisableSmall")
		hint:SetPoint("TOPLEFT", box, "TOPLEFT", 12, -12)
		popupText.hint = hint
		local function Edge(on)
			local c = on and GOLD or EDGE
			if box.SetBackdropBorderColor then box:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
		end
		eb:SetScript("OnEditFocusGained", function() Edge(true); hint:Hide() end)
		eb:SetScript("OnEditFocusLost", function() Edge(false); hint:SetShown(eb:GetText() == "" and popupText.mode == "import") end)
		eb:SetScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "" and not self:HasFocus() and popupText.mode == "import") end)
		sf:SetScrollChild(eb)
		-- Ein mehrzeiliges Eingabefeld ist nur so hoch wie sein Text: ein Klick auf die leere Fläche trifft es nicht. Darum fängt
		-- ein Knopf unter dem Feld Klicks im ganzen Kasten ab und setzt den Fokus.
		local catcher = CreateFrame("Button", nil, popupText)
		catcher:SetAllPoints(box)
		catcher:SetFrameLevel(sf:GetFrameLevel() - 1)
		catcher:SetScript("OnClick", function() eb:SetFocus() end)
		sf:EnableMouse(true)   -- das Scrollfenster (wegen des Mausrads mausaktiv) schluckt sonst die Klicks auf die leere Fläche
		sf:SetScript("OnMouseDown", function() eb:SetFocus() end)
		sf:EnableMouseWheel(true)
		sf:SetScript("OnMouseWheel", function(self, delta)
			local maxScroll = math.max(0, eb:GetHeight() - self:GetHeight())
			self:SetVerticalScroll(math.max(0, math.min(maxScroll, self:GetVerticalScroll() - delta * 30)))
		end)
		popupText.eb, popupText.sf = eb, sf
		popupText.info = ui.Text(popupText, "GameFontHighlightSmall")
		popupText.info:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 2, -8)
		popupText.info:SetPoint("RIGHT", popupText, "RIGHT", -14, 0)
		popupText.info:SetJustifyH("LEFT")
		popupText.info:SetTextColor(0.78, 0.73, 0.64)
		popupText.nameLabel = ui.Text(popupText, "GameFontHighlightSmall")
		popupText.nameLabel:SetText(T("Name:", "Name:"))
		popupText.nameBox = MakeEdit(popupText, 200)
		popupText.nameBox:SetMaxLetters(32)
		popupText.nameLabel:SetPoint("BOTTOMLEFT", 14, 22)
		popupText.nameBox:SetPoint("LEFT", popupText.nameLabel, "RIGHT", 8, 0)
		popupText.go = ui.HeaderButton(popupText, T("Importieren", "Import"), 120, 28)
		popupText.go:SetPoint("BOTTOMRIGHT", -144, 14)
		popupText.close = ui.HeaderButton(popupText, T("Schließen", "Close"), 120, 28)
		popupText.close:SetPoint("BOTTOMRIGHT", -14, 14)
		popupText.close:SetScript("OnClick", function() popupText:Hide() end)
		popupText.go:SetScript("OnClick", function()
			local ok, res = lib:ImportProfile(popupText.eb:GetText(), popupText.nameBox:GetText())
			if ok then
				popupText:Hide()
				selected = res
				if frame then lib:RefreshProfiles(T("Profil importiert: ", "Profile imported: ") .. res) end
			else
				popupText.info:SetTextColor(1, 0.5, 0.45)
				popupText.info:SetText(res or "")
			end
		end)
	end
	local p = popupText
	p.mode = mode
	p.title:SetText(mode == "export" and T("Profil exportieren", "Export profile") or T("Profil importieren", "Import profile"))
	p.eb:SetText(text or "")
	p.sf:SetVerticalScroll(0)
	p.info:SetTextColor(0.78, 0.73, 0.64)
	p.label:SetText(mode == "export" and T("Profil-Text (zum Kopieren)", "Profile text (to copy)") or T("Profil-Text einfügen", "Paste profile text"))
	p.hint:SetText(T("Hier klicken und mit Strg+V einfügen …", "Click here and paste with Ctrl+V …"))
	p.hint:SetShown(mode == "import")
	if mode == "export" then
		p.info:SetText(T("Alles markieren (Strg+A), kopieren (Strg+C) und an anderer Stelle einfügen.", "Select all (Ctrl+A), copy (Ctrl+C) and paste it somewhere else."))
		p.go:Hide()
		p.nameLabel:Hide()
		p.nameBox:Hide()
	else
		p.info:SetText(T("Den Profil-Text hier einfügen (Strg+V). Der Name ist frei; leer lässt den gespeicherten Namen.", "Paste the profile text here (Ctrl+V). The name is free; empty keeps the stored name."))
		p.go:Show()
		p.nameLabel:Show()
		p.nameBox:Show()
		p.nameBox:SetText("")
	end
	p:Show()
	if mode == "export" then
		p.eb:SetFocus()
		p.eb:HighlightText()
	else
		p.eb:ClearFocus()
		p.hint:Show()
	end
end

-- Zeichen, die zum Zuweisen angeboten werden: dieser Charakter und alle, denen schon ein Profil zugewiesen ist
local function CharList(d)
	local me = CharKey()
	-- alte Zuweisung ohne Server ("Name-" oder "Name") auf den vollen Namen umstellen
	local name = CharParts()
	local first = UnitName("player") or name
	for _, old in ipairs({ name .. "-", name, first .. "-", first }) do
		if old ~= me and d.profileChars[old] then
			if not d.profileChars[me] then d.profileChars[me] = d.profileChars[old] end
			d.profileChars[old] = nil
		end
	end
	local list, set, others = { me }, { [me] = true }, {}
	for key in pairs(d.profileChars) do
		if not set[key] then set[key] = true; others[#others + 1] = key end
	end
	table.sort(others)
	for _, k in ipairs(others) do list[#list + 1] = k end
	return list
end

function lib:RefreshProfiles(message)
	local f = frame
	if not f then return end
	local d = Store()
	local names = Names()
	if not (selected and d.profiles[selected]) then selected = d.profileActive or names[1] end
	offset = math.max(0, math.min(math.max(0, #names - ROWS), offset))
	local me = CharKey()

	-- Liste links: Name, darunter Zustand und Zuweisung
	for i = 1, ROWS do
		local row = f.rows[i]
		local name = names[offset + i]
		row.name = name
		row:SetShown(name ~= nil)
		if name then
			local count = 0
			for _, p in pairs(d.profileChars) do if p == name then count = count + 1 end end
			local active, mine = d.profileActive == name, d.profileChars[me] == name
			local sub = {}
			if active then sub[#sub + 1] = T("Aktiv", "Active") end
			if mine then sub[#sub + 1] = T("dieser Charakter", "this character")
			elseif count > 0 then sub[#sub + 1] = count == 1 and T("1 Charakter", "1 character") or (count .. " " .. T("Charaktere", "characters")) end
			if #sub == 0 then sub[1] = T("Kein Charakter fest", "No fixed character") end
			row.text:SetText(name)
			row.sub:SetText(table.concat(sub, " · "))
			row.dot:SetShown(active)
			local on = name == selected
			row.bg:SetColorTexture(on and 0.227 or 0.141, on and 0.169 or 0.102, on and 0.106 or 0.067, 1)
			row.bar:SetShown(on)
		end
	end

	-- Details rechts
	local active = selected and d.profileActive == selected
	f.dName:SetText(selected or "")
	f.status:SetText(active and T("Aktiv", "Active") or T("Nicht aktiv", "Not active"))
	if active then f.status:SetTextColor(0.48, 0.88, 0.56) else f.status:SetTextColor(0.71, 0.65, 0.53) end

	local data = selected and d.profiles[selected] or {}
	local x, y, n = 0, 0, 0
	for _, id in ipairs(lib.profileOrder) do
		if data[id] then
			n = n + 1
			local chip = f.chips[n]
			if not chip then
				chip = CreateFrame("Frame", nil, f)
				chip:SetHeight(24)
				chip.bg = chip:CreateTexture(nil, "BACKGROUND")
				chip.bg:SetAllPoints()
				chip.bg:SetColorTexture(0.165, 0.125, 0.086, 1)
				chip.text = ui.Text(chip, "GameFontHighlightSmall")
				chip.text:SetPoint("CENTER")
				f.chips[n] = chip
			end
			local a = lib.addons and lib.addons[id]
			chip.text:SetText(a and a.title or id)
			local w = math.ceil(chip.text:GetStringWidth()) + 22
			if x + w > 500 then x, y = 0, y + 30 end
			chip:SetWidth(w)
			chip:ClearAllPoints()
			chip:SetPoint("TOPLEFT", f, "TOPLEFT", 360 + x, -(112 + y))
			chip:Show()
			x = x + w + 8
		end
	end
	for i = n + 1, #f.chips do f.chips[i]:Hide() end

	-- Charaktere: Häkchen weist das gewählte Profil zu oder nimmt die Zuweisung zurück
	local chars = CharList(d)
	for i = 1, #f.charRows do
		local row = f.charRows[i]
		local key = chars[i]
		row.key = key
		row:SetShown(key ~= nil)
		if key then
			local cname, realm = key:match("^(.-)%-(.+)$")
			if not cname then cname = key end
			local label = "|cfff5e3b0" .. cname .. "|r" .. (realm and ("  |cffb5a688" .. realm .. "|r") or "")
			if key == me then label = label .. "  |cff7ae08f(" .. T("dieser Charakter", "this character") .. ")|r" end
			row.text:SetText(label)
			local on = d.profileChars[key] == selected
			row.check:SetShown(on)
			local other = d.profileChars[key]
			row.note:SetText((other and not on) and ("→ " .. other) or "")
		end
	end

	local isDefault = selected == "Standard" or selected == "Default"   -- das Standardprofil lässt sich weder umbenennen noch löschen
	f.btnRename:SetShown(selected ~= nil and not isDefault)
	f.btnDelete:SetShown(selected ~= nil and not isDefault)
	-- Aktivieren nur anbieten, wenn es etwas bewirkt: anderes Profil wählen oder diesen Charakter dem aktiven Profil zuweisen
	f.btnActivate:SetShown(selected ~= nil and (not active or d.profileChars[me] ~= selected))
	f.btnDelete:SetAlpha(active and 0.4 or 1)
	f.msg:SetText(message or "")
	f.msg:SetTextColor(0.71, 0.65, 0.53)
end

local function Msg(text, bad)
	if not frame then return end
	frame.msg:SetText(text or "")
	if bad then frame.msg:SetTextColor(1, 0.5, 0.45) else frame.msg:SetTextColor(0.55, 0.9, 0.6) end
end

-- Fenster zum Eingeben eines Namens (neu, kopieren, umbenennen); onOk(name) liefert true oder false und eine Fehlermeldung
local askFrame
function lib:AskProfileName(title, default, onOk)
	if not askFrame then
		askFrame = Popup(380, 150, "")
		askFrame:SetFrameLevel(260)
		askFrame.box = MakeEdit(askFrame, 340)
		askFrame.box:SetPoint("TOPLEFT", 20, -52)
		askFrame.box:SetMaxLetters(32)
		askFrame.err = ui.Text(askFrame, "GameFontHighlightSmall")
		askFrame.err:SetPoint("TOPLEFT", askFrame.box, "BOTTOMLEFT", 0, -8)
		askFrame.err:SetPoint("RIGHT", askFrame, "RIGHT", -20, 0)
		askFrame.err:SetJustifyH("LEFT")
		askFrame.err:SetTextColor(1, 0.5, 0.45)
		local function Confirm()
			local ok, res = askFrame.onOk(askFrame.box:GetText())
			if ok then askFrame:Hide() else askFrame.err:SetText(res or "") end
		end
		askFrame.ok = ui.HeaderButton(askFrame, "OK", 120, 28)
		askFrame.ok:SetPoint("BOTTOMRIGHT", -144, 14)
		askFrame.ok:SetScript("OnClick", Confirm)
		askFrame.cancel = ui.HeaderButton(askFrame, T("Abbrechen", "Cancel"), 120, 28)
		askFrame.cancel:SetPoint("BOTTOMRIGHT", -14, 14)
		askFrame.cancel:SetScript("OnClick", function() askFrame:Hide() end)
		askFrame.box:SetScript("OnEnterPressed", Confirm)
		askFrame.box:SetScript("OnEscapePressed", function() askFrame:Hide() end)
	end
	askFrame.title:SetText(title)
	askFrame.onOk = onOk
	askFrame.err:SetText("")
	askFrame.box:SetText(default or "")
	askFrame:ClearAllPoints()
	askFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	askFrame:Show()
	askFrame.box:SetFocus()
	askFrame.box:HighlightText()
end

-- Die Seite "Profile" im Einstellungsfenster (Hub): links die Liste, rechts die Details des gewählten Profils
function lib:FillProfilePanel(f)
	frame = f

	f.pageTitle = ui.Text(f, "GameFontNormalLarge", 22)
	f.pageTitle:SetPoint("TOPLEFT", 24, -16)
	f.pageTitle:SetTextColor(0.96, 0.89, 0.69)
	f.pageTitle:SetText(T("Profile", "Profiles"))

	-- Leiste über der Liste: neu aus dem aktuellen Stand, importieren
	local function Btn(parent, label, w, h, x, y, onClick)
		local b = ui.HeaderButton(parent, label, w, h)
		b:SetPoint("TOPLEFT", x, y)
		b:SetScript("OnClick", onClick)
		return b
	end
	f.btnNew = Btn(f, T("+ Neu", "+ New"), 96, 26, 24, -58, function()
		lib:AskProfileName(T("Neues Profil aus dem aktuellen Stand", "New profile from the current state"), "", function(name)
			local ok, res = lib:NewProfile(name)
			if ok then selected = res; lib:RefreshProfiles(T("Profil angelegt und aktiviert: ", "Profile created and activated: ") .. res) end
			return ok, res
		end)
	end)
	f.btnImport = Btn(f, T("Importieren", "Import"), 110, 26, 128, -58, function() ShowText("import", "") end)

	-- Liste
	f.rows = {}
	for i = 1, ROWS do
		local r = CreateFrame("Button", nil, f)
		r:SetSize(300, ROW_H - 4)
		r:SetPoint("TOPLEFT", 24, -(96 + (i - 1) * ROW_H))
		r.bg = r:CreateTexture(nil, "BACKGROUND")
		r.bg:SetAllPoints()
		r.bar = r:CreateTexture(nil, "ARTWORK")
		r.bar:SetPoint("TOPLEFT")
		r.bar:SetPoint("BOTTOMLEFT")
		r.bar:SetWidth(3)
		r.bar:SetColorTexture(0.91, 0.76, 0.42, 1)
		r.hl = r:CreateTexture(nil, "HIGHLIGHT")
		r.hl:SetAllPoints()
		r.hl:SetColorTexture(1, 1, 1, 0.06)
		r.text = ui.Text(r, "GameFontHighlight")
		r.text:SetPoint("TOPLEFT", 14, -8)
		r.text:SetPoint("RIGHT", r, "RIGHT", -28, 0)
		r.text:SetJustifyH("LEFT")
		r.text:SetWordWrap(false)
		r.text:SetTextColor(0.96, 0.89, 0.69)
		r.sub = ui.Text(r, "GameFontHighlightSmall")
		r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -3)
		r.sub:SetTextColor(0.71, 0.65, 0.53)
		r.dot = r:CreateTexture(nil, "ARTWORK")
		r.dot:SetSize(8, 8)
		r.dot:SetPoint("RIGHT", -12, 0)
		r.dot:SetColorTexture(0.48, 0.88, 0.56, 1)
		r:SetScript("OnClick", function(self)
			if self.name then selected = self.name; lib:RefreshProfiles() end
		end)
		f.rows[i] = r
	end
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(_, delta) offset = offset - delta; lib:RefreshProfiles(frame.msg:GetText()) end)

	-- Trennlinie zwischen Liste und Details
	f.sep = f:CreateTexture(nil, "ARTWORK")
	f.sep:SetColorTexture(0.24, 0.185, 0.122, 1)
	f.sep:SetWidth(1)
	f.sep:SetPoint("TOPLEFT", 338, -16)
	f.sep:SetPoint("BOTTOMLEFT", 338, 16)

	-- Details: Name (mit Stift zum Umbenennen), Zustand, Inhalt, Charaktere
	local x = 360
	f.dName = ui.Text(f, "GameFontNormalLarge", 26)
	f.dName:SetPoint("TOPLEFT", x, -14)
	f.dName:SetTextColor(0.96, 0.89, 0.69)
	f.dName:SetWordWrap(false)
	f.dName:SetWidth(400)
	f.dName:SetJustifyH("LEFT")
	f.btnRename = ui.HeaderButton(f, T("Umbenennen", "Rename"), 100, 22)
	f.btnRename:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -18)
	f.btnRename:SetScript("OnClick", function()
		if not selected then return end
		lib:AskProfileName(T("Profil umbenennen", "Rename profile"), selected, function(name)
			local ok, res = lib:RenameProfile(selected, name)
			if ok then selected = res; lib:RefreshProfiles(T("Umbenannt in ", "Renamed to ") .. res) end
			return ok, res
		end)
	end)
	f.status = ui.Text(f, "GameFontHighlight")
	f.status:SetPoint("TOPLEFT", x, -52)

	local function Label(text, y)
		local l = ui.Text(f, "GameFontHighlightSmall")
		l:SetPoint("TOPLEFT", x, y)
		l:SetTextColor(0.71, 0.65, 0.53)
		l:SetText(text:upper())
		return l
	end
	Label(T("Enthält", "Contains"), -88)
	f.chips = {}
	Label(T("Charaktere", "Characters"), -180)
	f.charRows = {}
	for i = 1, 6 do
		local r = CreateFrame("Button", nil, f)
		r:SetSize(500, 26)
		r:SetPoint("TOPLEFT", x, -202 - (i - 1) * 28)
		r.bg = r:CreateTexture(nil, "BACKGROUND")
		r.bg:SetAllPoints()
		r.bg:SetColorTexture(0.165, 0.125, 0.086, 1)
		r.hl = r:CreateTexture(nil, "HIGHLIGHT")
		r.hl:SetAllPoints()
		r.hl:SetColorTexture(1, 1, 1, 0.06)
		r.edge = r:CreateTexture(nil, "ARTWORK")
		r.edge:SetSize(16, 16)
		r.edge:SetPoint("LEFT", 10, 0)
		-- Kästchen wie im Einstellungsdialog: Rand, dunkle Fläche, goldenes Quadrat
		r.edge:SetColorTexture(EDGE[1], EDGE[2], EDGE[3], 1)
		r.box = r:CreateTexture(nil, "OVERLAY")
		r.box:SetPoint("TOPLEFT", r.edge, "TOPLEFT", 1, -1)
		r.box:SetPoint("BOTTOMRIGHT", r.edge, "BOTTOMRIGHT", -1, 1)
		r.box:SetColorTexture(0.06, 0.05, 0.04, 1)
		r.check = r:CreateTexture(nil, "OVERLAY", nil, 2)
		r.check:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 1)
		r.check:SetPoint("TOPLEFT", r.edge, "TOPLEFT", 3, -3)
		r.check:SetPoint("BOTTOMRIGHT", r.edge, "BOTTOMRIGHT", -3, 3)
		r.text = ui.Text(r, "GameFontHighlight")
		r.text:SetPoint("LEFT", r.edge, "RIGHT", 10, 0)
		r.text:SetJustifyH("LEFT")
		r.note = ui.Text(r, "GameFontHighlightSmall")
		r.note:SetPoint("RIGHT", -10, 0)
		r.note:SetTextColor(0.71, 0.65, 0.53)
		r.hl:Hide()
		r:EnableMouse(false)   -- nur Anzeige: die Zuweisung ändert sich ausschließlich über "Aktivieren"
		f.charRows[i] = r
	end

	-- Aktionen unten rechts in der Spalte
	f.btnActivate = Btn(f, T("Aktivieren", "Activate"), 140, 30, 0, 0, function()
		if not selected then return end
		local d = Store()
		local me = CharKey()
		if me then d.profileChars[me] = selected end   -- der aktuelle Charakter gehört danach zu diesem Profil
		if d.profileActive == selected then lib:RefreshProfiles() Msg(T("Dieses Profil ist schon aktiv.", "This profile is already active."), true) return end
		lib:ActivateProfile(selected)
		lib:RefreshProfiles()
	end)
	f.btnActivate:ClearAllPoints()
	f.btnActivate:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 14)
	f.btnCopy = Btn(f, T("Kopieren", "Copy"), 110, 30, 0, 0, function()
		if not selected then return end
		local from = selected
		lib:AskProfileName(T("Profil kopieren", "Copy profile"), from .. " 2", function(name)
			local ok, res = lib:CopyProfile(from, name)
			if ok then selected = res; lib:RefreshProfiles(T("Kopiert als ", "Copied as ") .. res) end
			return ok, res
		end)
	end)
	f.btnCopy:ClearAllPoints()
	f.btnCopy:SetPoint("RIGHT", f.btnExport, "LEFT", -8, 0)
	f.btnExport = Btn(f, T("Exportieren", "Export"), 120, 30, 0, 0, function()
		local text = lib:ExportProfile(selected)
		if text then ShowText("export", text) end
	end)
	f.btnExport:ClearAllPoints()
	f.btnExport:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -24, 14)
	-- Löschen: zweiter Klick bestätigt
	local armed
	f.btnDelete = Btn(f, T("Löschen", "Delete"), 110, 30, 0, 0, function(self)
		if not selected then return end
		if Store().profileActive == selected then Msg(T("Das aktive Profil lässt sich nicht löschen.", "The active profile cannot be deleted."), true) return end
		if armed ~= selected then
			armed = selected
			self.text:SetText(T("Sicher?", "Sure?"))
			C_Timer.After(3, function() armed = nil; self.text:SetText(T("Löschen", "Delete")) end)
			return
		end
		armed = nil
		self.text:SetText(T("Löschen", "Delete"))
		local gone = selected
		lib:DeleteProfile(gone)
		selected = nil
		lib:RefreshProfiles(T("Gelöscht: ", "Deleted: ") .. gone)
	end)
	f.btnDelete:ClearAllPoints()
	f.btnDelete:SetSize(100, 22)
	f.btnDelete:SetPoint("TOPRIGHT", f, "TOPRIGHT", -24, -18)
	f.btnRename:ClearAllPoints()
	f.btnRename:SetPoint("RIGHT", f.btnDelete, "LEFT", -8, 0)
	f.btnDelete.bg:SetColorTexture(0.3, 0.1, 0.08, 1)

	f.msg = ui.Text(f, "GameFontHighlightSmall")
	f.msg:SetPoint("BOTTOMLEFT", x, 52)
	f.msg:SetPoint("RIGHT", f, "RIGHT", -24, 0)
	f.msg:SetJustifyH("LEFT")
	f.hint = ui.Text(f, "GameFontHighlightSmall")
	f.hint:SetPoint("BOTTOMLEFT", 24, 18)
	f.hint:SetWidth(310)
	f.hint:SetJustifyH("LEFT")
	f.hint:SetTextColor(0.62, 0.57, 0.5)
	f.hint:SetText(T("Aktivieren lädt danach die Oberfläche neu.", "Activating reloads the interface afterwards."))
	f:SetScript("OnShow", function() lib:RefreshProfiles() end)
end

-- Öffnet das Einstellungsfenster auf der Seite "Profile"
function lib:OpenProfiles()
	if self.HubShowProfiles then self:HubShowProfiles() end
end

-- Erstes Anlegen: hatte SexyInterrupter mehrere Ace-Profile (z. B. je Charakter), werden sie zu Profilen für alle Addons: der Rest ist der
-- aktuelle Stand, die Daten von SexyInterrupter stammen aus dem jeweiligen Ace-Profil. Die Zuordnung der Charaktere (profileKeys) wird
-- übernommen. Gibt den Namen für das Profil des aktuellen Stands zurück.
local function MigrateAceProfiles(d, baseSnap)
	local ace = _G.SexyInterrupterDB
	if type(ace) ~= "table" or type(ace.profiles) ~= "table" then return nil end
	local count = 0
	for _ in pairs(ace.profiles) do count = count + 1 end
	if count < 2 then return nil end
	local si = _G.SexyInterrupter
	local current = si and si.db and si.db.GetCurrentProfile and si.db:GetCurrentProfile()
	if type(current) ~= "string" then return nil end
	local map = {}
	for pname, pdata in pairs(ace.profiles) do
		if pname ~= current and type(pdata) == "table" then
			local snap = Copy(baseSnap)
			snap.SexyInterrupter = Copy(pdata)
			local name, n = pname, 2
			while d.profiles[name] or name == current do name = pname .. " (" .. n .. ")"; n = n + 1 end
			d.profiles[name] = snap
			map[pname] = name
		end
	end
	for key, pname in pairs(ace.profileKeys or {}) do
		if type(key) == "string" and map[pname] then d.profileChars[(key:gsub(" %- ", "-"))] = map[pname] end
	end
	return current
end

-- Beim Anmelden: erstes Profil anlegen und das Profil des Charakters aktivieren; beim Beenden den Stand ins aktive Profil legen
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGOUT" then
		pcall(lib.SaveActiveProfile, lib)
		return
	end
	-- warten, bis alle Addons ihre Daten gemeldet haben
	C_Timer.After(2, function()
		local d = Store()
		if not next(d.profiles) then
			local snap = lib:ProfileSnapshot()
			-- hatte SexyInterrupter mehrere Ace-Profile, heißt der aktuelle Stand wie sein aktuelles Profil
			local name = MigrateAceProfiles(d, snap) or T("Standard", "Default")
			d.profiles[name] = snap
			d.profileActive = name
			-- Zuordnungen auf den aktuellen Stand gehen verloren, wenn der Name inzwischen vergeben ist: nichts nötig
			local want = d.profileChars[CharKey()]
			if want and d.profiles[want] and want ~= name then lib:ActivateProfile(want)
			elseif not want then d.profileChars[CharKey()] = name end
			return
		end
		local want = d.profileChars[CharKey()]
		if want and d.profiles[want] and want ~= d.profileActive then
			lib:ActivateProfile(want)
		elseif not (want and d.profiles[want]) and d.profileActive then
			-- Charakter ohne Zuweisung nutzt das aktive Profil: gleich eintragen (Häkchen in der Charakterliste)
			d.profileChars[CharKey()] = d.profileActive
		end
	end)
end)
