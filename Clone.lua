-- Kopie eines Fensters für die Vorschau im Einstellungsfenster (Hub): Das echte Fenster bleibt, wo es ist; eine Kopie
-- seines Aussehens lebt im Vorschaubereich. Kopiert wird, was man sieht: Rahmen (mit Hintergrund und Rand), Texturen
-- (Farbe, Bild, Ausschnitt, Verlauf), Schriften (Text, Schrift, Farbe), Statusbalken, Größen und Anker. Die Kopie ist ein
-- Abbild, nicht bedienbar; sie wird mit lib:SyncClone bei jeder Änderung nachgezogen (vorhandene Teile werden
-- wiederverwendet, es entstehen keine neuen Rahmen pro Zeichnen).
--
-- Texturen mit SetColorTexture kann man nicht auslesen. Darum merken Haken in den Widget-Methoden (SetColorTexture,
-- SetGradient, SetTexture, SetAtlas) den letzten Aufruf am Objekt (.sxColor, .sxGrad); sie müssen vor den Fenstern der
-- Addons geladen sein (Clone.lua steht deshalb ganz vorn in der TOC).

local lib = LibStub("SexyEditMode-1.0", true)
if not lib then return end

-- Haken: letzte Farbe/Verlauf einer Textur merken
do
	local probe = UIParent:CreateTexture()
	local mt = getmetatable(probe)
	local index = mt and mt.__index
	if type(index) == "table" and not index.__sxHooked then
		index.__sxHooked = true
		hooksecurefunc(index, "SetColorTexture", function(self, r, g, b, a)
			self.sxColor, self.sxGrad = { r, g, b, a }, nil
		end)
		hooksecurefunc(index, "SetTexture", function(self) self.sxColor, self.sxGrad = nil, nil end)
		if index.SetAtlas then hooksecurefunc(index, "SetAtlas", function(self) self.sxColor, self.sxGrad = nil, nil end) end
		if index.SetGradient then
			hooksecurefunc(index, "SetGradient", function(self, orientation, c1, c2) self.sxGrad = { orientation, c1, c2 } end)
		end
		if index.SetGradientAlpha then
			hooksecurefunc(index, "SetGradientAlpha", function(self, ...) self.sxGradA = { ... } end)
		end
	end
end

local function Safe(f, ...)
	local ok, a, b, c, d, e, f2, g, h = pcall(f, ...)
	if ok then return a, b, c, d, e, f2, g, h end
end

-- Zustand einer Kopie: st = { map = { [echtes Objekt] = Kopie }, root = Kopie des Wurzelfensters }
function lib:NewClone() return { map = {}, order = {} } end

-- Legt für ein echtes Objekt und alles darunter die Kopien an (nur fehlende)
local function Build(st, src, parentDst)
	local dst = st.map[src]
	if not dst then
		local kind = src.GetObjectType and src:GetObjectType()
		if kind == "Texture" then
			local layer, sub = src:GetDrawLayer()
			dst = parentDst:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
		elseif kind == "FontString" then
			local layer, sub = src:GetDrawLayer()
			dst = parentDst:CreateFontString(nil, layer or "OVERLAY")
		elseif kind == "StatusBar" then
			dst = CreateFrame("StatusBar", nil, parentDst)
		elseif src.GetBackdrop then
			dst = CreateFrame("Frame", nil, parentDst, BackdropTemplateMixin and "BackdropTemplate" or nil)
		elseif kind == "Frame" or kind == "Button" or kind == "CheckButton" or kind == "ScrollFrame" or kind == "Slider" or kind == "EditBox" then
			dst = CreateFrame("Frame", nil, parentDst)
		end
		if not dst then return end
		st.map[src] = dst
		st.order[#st.order + 1] = src
	end
	-- Rahmen: Kinder und Regionen
	if src.GetChildren then
		for _, child in ipairs({ src:GetChildren() }) do
			if not child.sxNoClone then Build(st, child, dst) end
		end
		for _, region in ipairs({ src:GetRegions() }) do
			Build(st, region, dst)
		end
		if src.GetFontString then
			local fs = src:GetFontString()
			if fs then Build(st, fs, dst) end
		end
	end
	return dst
end

local function CopyPoints(st, src, dst)
	dst:ClearAllPoints()
	if src == st.src then
		dst:SetPoint("TOPLEFT", st.host, "TOPLEFT")   -- die Wurzel sitzt oben links im Vorschaubereich
		return
	end
	local n = src:GetNumPoints()
	if n == 0 then
		dst:SetPoint("TOPLEFT", dst:GetParent(), "TOPLEFT")
		return
	end
	for i = 1, n do
		local point, rel, relPoint, x, y = src:GetPoint(i)
		local target = rel and st.map[rel]
		if rel and not target then target = st.root end   -- Anker außerhalb des Fensters: an der Wurzel
		dst:SetPoint(point, target or dst:GetParent(), relPoint or point, x or 0, y or 0)
	end
end

local function CopyTexture(src, dst)
	if src.sxColor then
		dst:SetColorTexture(unpack(src.sxColor))
		if src.sxGrad and dst.SetGradient then pcall(dst.SetGradient, dst, unpack(src.sxGrad)) end
		if src.sxGradA and dst.SetGradientAlpha then pcall(dst.SetGradientAlpha, dst, unpack(src.sxGradA)) end
	else
		local atlas = src.GetAtlas and src:GetAtlas()
		if atlas then
			dst:SetAtlas(atlas)
		else
			local tex = src:GetTexture()
			if tex then dst:SetTexture(tex) else dst:SetTexture(nil) end
		end
		local ulx, uly, llx, lly, urx, ury, lrx, lry = src:GetTexCoord()
		if ulx then dst:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry) end
	end
	local r, g, b, a = src:GetVertexColor()
	if r then dst:SetVertexColor(r, g, b, a) end
	dst:SetBlendMode(src:GetBlendMode() or "BLEND")
	if src.IsDesaturated then dst:SetDesaturated(src:IsDesaturated() and true or false) end
	local layer, sub = src:GetDrawLayer()
	if layer then dst:SetDrawLayer(layer, sub or 0) end
end

local function CopyFont(src, dst)
	local font, size, flags = src:GetFont()
	if font then dst:SetFont(font, size or 12, flags or "") end
	dst:SetText(src:GetText() or "")
	local r, g, b, a = src:GetTextColor()
	if r then dst:SetTextColor(r, g, b, a or 1) end
	local sr, sg, sb, sa = src:GetShadowColor()
	if sr then dst:SetShadowColor(sr, sg, sb, sa) end
	local sx, sy = src:GetShadowOffset()
	if sx then dst:SetShadowOffset(sx, sy) end
	dst:SetJustifyH(src:GetJustifyH() or "LEFT")
	dst:SetJustifyV(src:GetJustifyV() or "MIDDLE")
	if src.GetWordWrap then dst:SetWordWrap(src:GetWordWrap() and true or false) end
	local w = src:GetWidth()
	if w and w > 0 then dst:SetWidth(w) end
	local layer, sub = src:GetDrawLayer()
	if layer then dst:SetDrawLayer(layer, sub or 0) end
end

local function CopyFrame(st, src, dst, baseLevel, srcRootLevel)
	local kind = src:GetObjectType()
	dst:SetAlpha(src:GetAlpha() or 1)
	dst:SetFrameStrata(st.host:GetFrameStrata())
	dst:SetFrameLevel(math.max(0, baseLevel + (src:GetFrameLevel() - srcRootLevel)))
	dst:EnableMouse(false)
	if src.GetClipsChildren and dst.SetClipsChildren then dst:SetClipsChildren(src:GetClipsChildren() and true or false) end
	if src.GetBackdrop and dst.SetBackdrop then
		local bd = src:GetBackdrop()
		if bd then
			dst:SetBackdrop(bd)
			local r, g, b, a = src:GetBackdropColor()
			if r then dst:SetBackdropColor(r, g, b, a) end
			r, g, b, a = src:GetBackdropBorderColor()
			if r then dst:SetBackdropBorderColor(r, g, b, a) end
		else
			dst:SetBackdrop(nil)
		end
	end
	if kind == "StatusBar" and dst.SetMinMaxValues then
		local lo, hi = src:GetMinMaxValues()
		if lo then dst:SetMinMaxValues(lo, hi) end
		local v = src:GetValue()
		if v then dst:SetValue(v) end
		local tex = src:GetStatusBarTexture()
		if tex then
			local path = tex:GetTexture()
			if path then dst:SetStatusBarTexture(path) end
			if tex.sxColor then dst:SetStatusBarColor(unpack(tex.sxColor)) end
		end
		local r, g, b, a = src:GetStatusBarColor()
		if r then dst:SetStatusBarColor(r, g, b, a) end
	end
end

-- Zieht die Kopie nach: legt fehlende Teile an, kopiert Aussehen, Größe und Anker. src = echtes Fenster, host = Rahmen,
-- in dem die Kopie oben links sitzt. Liefert die Kopie des Fensters.
function lib:SyncClone(st, src, host)
	st.host, st.src = host, src
	local root = Build(st, src, host)
	if not root then return end
	st.root = root
	local baseLevel, srcRootLevel = host:GetFrameLevel() + 1, src:GetFrameLevel()

	for _, real in ipairs(st.order) do
		local dst = st.map[real]
		local kind = real:GetObjectType()
		if kind == "Texture" then
			CopyTexture(real, dst)
		elseif kind == "FontString" then
			CopyFont(real, dst)
		else
			CopyFrame(st, real, dst, baseLevel, srcRootLevel)
		end
		-- Größe (Wurzel: ohne Skalierung, sie hängt am Vorschaubereich)
		local w, h = real:GetSize()
		if kind ~= "FontString" and w and h and w > 0 and h > 0 then dst:SetSize(w, h) end
		Safe(CopyPoints, st, real, dst)
		if real == src then
			dst:SetScale(src:GetScale() or 1)
			dst:SetAlpha(1)   -- das echte Fenster darf unsichtbar sein (Sichtbarkeitsregeln), die Kopie nicht
			dst:Show()
		else
			dst:SetShown(real:IsShown() and true or false)
		end
	end
	return root
end

-- Kopie ausblenden (beim Verlassen der Vorschau)
function lib:HideClone(st)
	if st and st.root then st.root:Hide() end
end
