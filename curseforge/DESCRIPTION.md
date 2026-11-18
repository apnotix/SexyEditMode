# SexyEditMode

![WoW Forever](https://img.shields.io/badge/WoW-Forever-e8c26a?style=for-the-badge) ![WoW Retail](https://img.shields.io/badge/WoW-Retail-c8a24a?style=for-the-badge) ![Interface](https://img.shields.io/badge/Interface-120100%20%7C%2016001-3b2b12?style=for-the-badge)

**One settings window for all Sexy addons.**

SexyEditMode is the shared base of **SexyLoot**, **SexyQuestHelper**, **SexyInterrupter** and **SexyHarvester**. It gives them one settings window in the same dark brown and gold look, and makes their windows movable in Blizzard's Edit Mode. You need it for those addons; CurseForge installs it automatically.

## Features

- 🗂️ **One window for everything** - the windows of every loaded Sexy addon on the left, their settings on the right. Open it with `/sem` or the minimap button.
- ✋ **Edit Mode integration** - move, scale and hide the addons' windows right in Blizzard's Edit Mode, with their own settings next to them.
- 🎛️ **Own widgets** - checkboxes, sliders, selects, colours, buttons and text fields that work on Forever and Retail.
- 💾 **Your settings stay put** - positions and options are saved by each addon itself.
- 🪶 **Light** - no windows of its own until you open it.

## Commands

| Command | Description |
|---|---|
| `/sem` | Show or hide the settings window |
| `/sem minimap` | Show or hide the minimap button |

Minimap button: left click opens the settings, right click opens Edit Mode.

## For addon authors

Register your addon and its windows with the `SexyEditMode-1.0` library (`LibStub`); the README on GitHub has a short example.

## 🇩🇪 Deutsch

**SexyEditMode** ist die gemeinsame Grundlage von SexyLoot, SexyQuestHelper, SexyInterrupter und SexyHarvester.

- Ein Einstellungsfenster für alle Sexy-Addons: `/sem` oder Minimap-Knopf
- Fenster im Edit Mode verschieben, skalieren und ausblenden
- Einstellungen bleiben im jeweiligen Addon gespeichert
- Wird von CurseForge automatisch mitinstalliert

## Credits

LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 (embedded).
