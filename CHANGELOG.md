# Changelog

## 1.0.3

- Der Edit-Mode-Dialog liegt jetzt über Blizzards Edit-Mode-Fenster (auch über dessen X-Knopf); Auswahllisten liegen darüber. Bibliothek MINOR 23.
- Andocken für alle Fenster aller Addons: jedes Fenster bekommt im Dialog und im Hub den Abschnitt „Andocken“ mit Ziel (jedes andere Fenster, auch eines anderen Addons), Seite (unten, oben, links, rechts) und Ausrichtung (bündig an einer Kante oder zentriert). Wer ein Fenster im Edit Mode selbst zieht, löst es ab. `Register` mit `dock = false` schaltet es ab (für Addons mit eigenem Andocken). Bibliothek MINOR 22.
- Edit Mode nur für ein Addon: `lib:ToggleEditMode(addonId)` öffnet Blizzards Edit Mode so, dass nur die Fenster dieses Addons ihr Rechteck und ihre Vorschau zeigen (`lib:IsEditing(addonId)` kennt das). Der Knopf im Einstellungsfenster öffnet ihn für das gewählte Addon. Bibliothek MINOR 21.
- Edit-Mode-Dialog: Fenster mit gleicher `group` zeigen oben eine Tab-Leiste (bis vier Tabs je Zeile) statt der Fensterauswahl und der Verweiszeilen; ein Klick auf ein Fenster im Edit Mode wählt den Tab. Bibliothek MINOR 20.
- Der Edit-Mode-Dialog der Fenster hat den Look des Einstellungsfensters (gleiche Zeilen und Farben, breiter) und zeigt nur noch Visuelles: Einstellungen mit `behavior = true` gibt es nur im Hub, Überschriften ohne Rest entfallen. Ohne Hub bleibt alles wie bisher. Bibliothek MINOR 19.
- Auswahl: Der Umschalter erscheint nur, wenn alle Möglichkeiten nebeneinander passen, sonst gibt es den Knopf mit Liste. Lange Einträge brechen nicht mehr um, die Liste wird breit genug (bis 420 px). Bibliothek MINOR 14.
- Auswahllisten: Optionen können mit `font = Pfad` in einer eigenen Schrift gezeichnet werden (Schriftauswahl). Neue Zeilenart `keybind` (Taste wählen). Bibliothek MINOR 13.
- Hub im neuen Look: Titelband, Seitenleiste mit Kategorien, Seitentitel mit Beschreibung, Fußleiste.
- Alle Einstellungszeilen im Hub neu gestaltet (Beschriftung links, Bedienelement rechts, Trennlinie): Checkbox, Regler, Umschalter oder Liste, Farbe, Knopf, Eingabefeld, Position. Abschnitte sind immer offen; Verweise auf andere Fenster entfallen, weil die Seitenleiste dorthin führt.
- Neu bei `Register`: `category` und `description`. `lib:BuildRows` nimmt eigene Zeilenhersteller entgegen. Bibliothek MINOR 11.
- Der X-Knopf des Hubs schließt das Fenster zuverlässig.

## 1.0.0

- Veröffentlichung auf CurseForge (Projekt-ID eingetragen).

- SexyEditMode ist jetzt ein eigenes Addon (bisher als Kopie in jedem Sexy-Addon eingebettet). Die Bibliothek `SexyEditMode-1.0` (MINOR 10) bleibt über `LibStub` erreichbar.
- Neu: gemeinsames Einstellungsfenster (Hub). Addons melden sich mit `RegisterAddon` an und geben bei `Register` `addon = "..."` an; ihre Fenster erscheinen links in der Seitenleiste, rechts stehen die Einstellungen. Öffnen mit `/sem` oder dem Minimap-Knopf.
- Neu: `lib:BuildRows` und `lib:EntrySpecs` (Zeilenaufbau für Dialog und Hub gemeinsam), `lib:Navigate` für Verweise zwischen Fenstern.
