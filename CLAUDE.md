# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project overview

SexyEditMode is a World of Warcraft addon (pure Lua, no build step) for **Forever** (Interface `16001`) and **Retail** (`120100`). It contains the library `SexyEditMode-1.0` (Edit Mode integration + settings rows) and the shared settings window ("Hub", [Hub.lua](Hub.lua)) that all Sexy addons (SexyLoot, SexyQuestHelper, SexyInterrupter, SexyHarvester) plug into.

There is no compiler, linter or test suite. Deploy by copying/linking the folder as `SexyEditMode` into `Interface/AddOns/`, then restart the client (new `.toc` entries are only read on a full restart, `/reload` is not enough).

## Layout

- [SexyEditMode.lua](SexyEditMode.lua): the library (`LibStub("SexyEditMode-1.0")`, MINOR in the first lines; bump it on every change). `lib:Register(frame, opts)`, row builders (`ROWS`), `lib:BuildRows` (shared by the small Edit Mode dialog and the Hub), `lib:EntrySpecs`, `lib:Navigate`. The public header comment documents all spec types. Internals needed by Hub.lua are exported as `lib.ui`.
- [Hub.lua](Hub.lua): `lib:RegisterAddon(id, { title, version })`, the Hub window (sidebar grouped by `entry.addon`, content = the entry's settings rows), `/sem`, minimap button (LibDBIcon). The Hub keeps its own row cache (`lib.hubRowCache`); `lib:RebuildDialog`/`lib:RefreshDialog` also rebuild/refresh the Hub.
- `Libs/`: LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 (vendored from SexyInterrupter's `lib/`).
- [tools/make_icon.py](tools/make_icon.py): generates `icon.png` (CurseForge) and `icon.tga` (game).

## Rules

- Positions and settings stay in each addon's own SavedVariables (`opts.db`); this addon only stores its own minimap button (`SexyEditModeDB`).
- No `UIDropDownMenuTemplate` (blocked for addons), no XML `<Binding>`, no `COMBAT_LOG_EVENT_UNFILTERED` (see the other Sexy repos' CLAUDE.md).
- Keep the lib API backwards compatible: addons may still embed an older copy; `LibStub` picks the highest MINOR.

## Packaging / CI

[.github/workflows/release.yml](.github/workflows/release.yml) runs on every push to `master`: bumps the patch number in [SexyEditMode.toc](SexyEditMode.toc), tags it and runs `BigWigsMods/packager` (same mechanism as the other Sexy repos). `[skip ci]` in the commit message suppresses a release. CurseForge needs `## X-Curse-Project-ID:` in the TOC and the `CF_API_KEY` secret. Texts for the CurseForge page live in [curseforge/](curseforge/).
