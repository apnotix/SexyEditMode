# SexyEditMode

Gemeinsames Einstellungsfenster und Edit-Mode-Bibliothek für die Sexy-Addons: **SexyLoot**, **SexyQuestHelper**, **SexyInterrupter**, **SexyHarvester**. Läuft auf **WoW: Forever** und **Retail**.

([English version](README.en.md))

## Was es tut

- **Ein Fenster für alle Sexy-Addons:** Links stehen die Fenster der geladenen Addons (nach Addon gruppiert), rechts deren Einstellungen. Öffnen mit `/sem` oder dem Minimap-Knopf (Rechtsklick öffnet den Edit Mode).
- **Edit-Mode-Bibliothek:** Macht Addon-Fenster im Blizzard-Edit-Mode verschiebbar, mit Dialog für Position, Größe, Sichtbarkeit und eigene Einstellungen.
- Eigene Widgets (Checkbox, Regler, Auswahl, Farbe, Knopf, Eingabefeld), ohne die für Addons gesperrten Blizzard-Dropdown-Vorlagen.

## Für Addon-Autoren

```lua
local SEM = LibStub("SexyEditMode-1.0")
SEM:RegisterAddon("MeinAddon", { title = "MeinAddon", version = "1.0" })
SEM:Register(frame, {
    name = "MeinAddon: Fenster",
    addon = "MeinAddon",
    db = MeinAddonDB.frames.fenster,
    settings = {
        { type = "header", name = "Anzeige", id = "view" },
        { type = "check", name = "Titel ausblenden", get = function() return x end, set = function(v) x = v end },
    },
})
```

Alle Zeilenarten und Optionen stehen im Kopfkommentar von [SexyEditMode.lua](SexyEditMode.lua).

## Befehle

| Befehl | Beschreibung |
|---|---|
| `/sem` | Einstellungsfenster ein-/ausblenden |
| `/sem minimap` | Minimap-Knopf ein-/ausblenden |

## Hinweis

Die Sexy-Addons brauchen dieses Addon. CurseForge und die gängigen Addon-Manager installieren es automatisch mit.
