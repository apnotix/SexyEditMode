-- Neuigkeiten für das gemeinsame Fenster (/sem news). Neueste Version zuerst.
-- Eintrag: { deutscher Titel, deutscher Text, englischer Titel, englischer Text }
local lib = LibStub("SexyEditMode-1.0", true)
if not (lib and lib.RegisterNews) then return end

lib:RegisterNews("SexyEditMode", {
	color = { 0.71, 0.55, 1 },
	{ v = "1.0.3",
		{ "Profile", "Charaktere sind nur eine Anzeige; „Aktivieren“ weist den aktuellen Charakter zu und erscheint nur, wenn es etwas bewirkt. Umbenennen und Löschen oben im Kopf (nicht beim Standardprofil), Knöpfe unten im Fuß, Esc schließt die Profil-Fenster.",
		  "Profiles", "Characters are display only; \"Activate\" assigns the current character and only shows when it does something. Rename and Delete sit in the header (not for the default profile), the buttons at the bottom, Esc closes the profile windows." },
		{ "Fenster entsperren", "Der Knopf ist auffälliger und entsperrt die Fenster aller Sexy-Addons. Im Verschiebe-Modus lässt sich die Kamera mit der Maus drehen, die Leiste hat den Look der Fenster. Rechtsklick auf den Eintrag im Esc-Menü schaltet den Modus ein.",
		  "Unlock frames", "The button is more prominent and unlocks the windows of all Sexy addons. In move mode you can rotate the camera with the mouse, the bar has the look of the windows. A right-click on the Esc menu entry turns the mode on." },
		{ "Verschieben", "Eigener Verschiebe-Modus statt Blizzards Edit Mode: Raster, Hilfslinien, Einrasten, Ausrichten, Dunkel-Stufen, Filter nach Addon und Mehrfachauswahl. Start mit „Fenster entsperren“ oder /sem move.",
		  "Moving", "Own move mode instead of Blizzard's Edit Mode: grid, guides, snapping, aligning, dim levels, filter by addon and multi-select. Start with \"Unlock frames\" or /sem move." },
		{ "Profile", "Ein gemeinsames Profil für alle Addons, pro Charakter zuweisbar, mit Export und Import. Alte Einstellungen werden übernommen.",
		  "Profiles", "One shared profile for all addons, assignable per character, with export and import. Old settings are migrated." },
		{ "Spielmenü", "Ein Eintrag im Esc-Menü über „AddOns“ öffnet das Einstellungsfenster.",
		  "Game menu", "An entry in the Esc menu above \"AddOns\" opens the settings window." },
		{ "Neuigkeiten", "Dieses Fenster: alle Änderungen der Sexy-Addons an einem Ort, beim Start nur bei Neuem (/sem news).",
		  "News", "This window: all changes of the Sexy addons in one place, shown at start only when there is something new (/sem news)." },
	},
})
