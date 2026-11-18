# Changelog

## 1.0.0

- SexyEditMode ist jetzt ein eigenes Addon (bisher als Kopie in jedem Sexy-Addon eingebettet). Die Bibliothek `SexyEditMode-1.0` (MINOR 10) bleibt über `LibStub` erreichbar.
- Neu: gemeinsames Einstellungsfenster (Hub). Addons melden sich mit `RegisterAddon` an und geben bei `Register` `addon = "..."` an; ihre Fenster erscheinen links in der Seitenleiste, rechts stehen die Einstellungen. Öffnen mit `/sem` oder dem Minimap-Knopf.
- Neu: `lib:BuildRows` und `lib:EntrySpecs` (Zeilenaufbau für Dialog und Hub gemeinsam), `lib:Navigate` für Verweise zwischen Fenstern.
