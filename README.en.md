# SexyEditMode

Shared settings window and Edit Mode library for the Sexy addons: **SexyLoot**, **SexyQuestHelper**, **SexyInterrupter**, **SexyHarvester**. Runs on **WoW: Forever** and **Retail**.

([Deutsche Version](README.md))

## What it does

- **One window for all Sexy addons:** the windows of every loaded addon are listed on the left (grouped by addon), their settings on the right. Open with `/sem` or the minimap button (right click opens Edit Mode).
- **Edit Mode library:** makes addon frames movable in Blizzard's Edit Mode, with a dialog for position, size, visibility and the addon's own settings.
- Own widgets (checkbox, slider, select, colour, button, text field) that avoid Blizzard's drop-down templates, which addons may not use.

## For addon authors

```lua
local SEM = LibStub("SexyEditMode-1.0")
SEM:RegisterAddon("MyAddon", { title = "MyAddon", version = "1.0" })
SEM:Register(frame, {
    name = "MyAddon: Window",
    addon = "MyAddon",
    db = MyAddonDB.frames.window,
    settings = {
        { type = "header", name = "Display", id = "view" },
        { type = "check", name = "Hide title", get = function() return x end, set = function(v) x = v end },
    },
})
```

All row types and options are documented in the header comment of [SexyEditMode.lua](SexyEditMode.lua).

## Commands

| Command | Description |
|---|---|
| `/sem` | Show or hide the settings window |
| `/sem minimap` | Show or hide the minimap button |

## Note

The Sexy addons need this addon. CurseForge and the common addon managers install it automatically.
