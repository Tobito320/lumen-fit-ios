# Lumen Fit – Design-System

Stand: 2026-10-29. Fitness- und Gesundheits-App für iPhone (SwiftUI, Swift 6, iOS 26), nutzbar von mehreren Personen
(Profil mit Name und Passwort, eine Anmeldung für immer). Standard: monochrom im Apple-Stil, fünf wählbare Themes,
drei Datenfarben wie Apple-Fitness, Muster je Theme, Figur Lumi, Bewegung nur bei Ereignissen.

Dies ist die Bauvorlage für Farben, Schrift, Abstände, Muster, Glas, Symbole, Bewegung, Haptik, Maskottchen, Tabs und
Skizzen je Tab. Alle Kontrastzahlen sind nachgerechnet (`docs/research/kontrast.py`, Exit 0 = alle Pflichtpaare bestehen).
Aussehen am Gerät ist ungeprüft: es gibt keinen Mac, Layout wird erst auf dem iPhone gesehen (Abschnitt 18).

Vorlage für den Entwurf ist `design.html` v9 (Artifact, verbindlich laut Auftrag). Wo dieses Dokument davon abweicht,
steht es in Abschnitt 17 mit Grund. Namen von Personen stehen hier nicht (Repo ist zeitweise öffentlich): "Partner",
"Freund", "Studio" sind Platzhalter.

## 0. Quellen

Heute (29.10.2026) im Wortlaut gelesen (Apple-Doku-JSON `developer.apple.com/tutorials/data/...`):

| Thema | URL | Übernommen |
|---|---|---|
| Activity rings | https://developer.apple.com/design/human-interface-guidelines/activity-rings | Regeln und Konflikt mit dem Entwurf, siehe Abschnitt 2 |
| Charts | https://developer.apple.com/design/human-interface-guidelines/charts | Marks, Achsen, Beschriftung als Begriffe für Abschnitt 13 |
| Materials | https://developer.apple.com/design/human-interface-guidelines/materials | Liquid Glass nur für Steuerung und Navigation, nie in der Inhaltsebene; sparsam |
| Color | https://developer.apple.com/design/human-interface-guidelines/color | eigene Farben brauchen hell, dunkel und erhöhten Kontrast; Farbe nie allein |
| Tab bars | https://developer.apple.com/design/human-interface-guidelines/tab-bars | Einwort-Beschriftung, SF Symbols für Tab-Symbole. ("Fünf oder weniger" steht dort nur für Tab-Leisten, die Nutzer selbst anpassen; fünf Tabs kommen hier aus der Spec.) |
| Typography | https://developer.apple.com/design/human-interface-guidelines/typography | Regular, Medium, Semibold, Bold bevorzugen; Ultralight, Thin, Light vermeiden; Textstile = Dynamic Type |
| Accessibility | https://developer.apple.com/design/human-interface-guidelines/accessibility | Kontrast bis 17 pt 4,5:1, ab 18 pt oder fett 3:1; Reduce Motion; 44x44 pt iOS, Minimum 28x28 pt |
| Motion | https://developer.apple.com/design/human-interface-guidelines/motion | Bewegung optional, kurz und präzise, nie einziger Informationsweg |
| SF Symbols | https://developer.apple.com/design/human-interface-guidelines/sf-symbols | vier Darstellungsarten: monochrom, hierarchisch, Palette, mehrfarbig |
| App icons | https://developer.apple.com/design/human-interface-guidelines/app-icons | keine UI-Nachbauten, System macht Effekte, Text als Pfad |
| Widgets, Live Activities | https://developer.apple.com/design/human-interface-guidelines/widgets , .../live-activities | Seiten geladen, nur Präsenzorte (Sperrbildschirm, Dynamic Island, Home) verwendet |
| API-Verfügbarkeit | `developer.apple.com/tutorials/data/documentation/<pfad>.json` | geprüft, alle iOS-Mindestversionen unten stehen in Tabelle 0.1 |

Tabelle 0.1, geprüfte Mindestversionen (iOS): `Tab` 18.0; `MeshGradient` 18.0; `glassEffect`, `GlassEffectContainer`,
`tabBarMinimizeBehavior`, `scrollEdgeEffectStyle`, `backgroundExtensionEffect`, `tabViewBottomAccessory` 26.0;
`SectorMark`, `PhaseAnimator`, `KeyframeAnimator`, `sensoryFeedback` (mit `.start`, `.stop`, `.increase`, `.decrease`,
`.levelChange`, `.selection`, `.success`, `.warning`, `.error`, `.impact`), `scrollTransition`, `visualEffect`,
`symbolEffect`, `containerBackground`, `contentMargins`, SwiftData 17.0; `Chart`, `LineMark`, `AreaMark`, `BarMark`,
`RectangleMark`, `Gauge`, `contentTransition`, `fontDesign` (16.1), `widgetAccentable`, `presentationDetents` 16.0;
`accessibilityChartDescriptor` 15.0; `Canvas`, `TimelineView` 15.0; `Activity` (ActivityKit) 16.1; `HKActivityRingView` 9.3.
`AXChartDescriptorRepresentable`: Doku-Pfad nicht gefunden (404), Typ am Compiler prüfen.

Aus der Bahnherz-Doku (`~/projects/bahnherz-ios/docs/research/design.md`, 17.10.2026) übernommen, heute nicht neu geprüft:
HIG Liquid-Glass-Seiten (`adopting-liquid-glass`, `applying-liquid-glass-to-custom-views`), HIG Layout, Buttons, Playing
Haptics, Feder- und Haptik-Tabellen, `.glassProminent`. Playing haptics: Seite geladen, aber keine Stelle ausgelesen
(Abschnitt 9 stützt sich deshalb auf die Bahnherz-Tabelle und die `SensoryFeedback`-Typen der API-Doku).

Lokal gelesen: Skill `ui-ux-pro-max` (Suchen: "fitness health tracker" Produkt, "swiftui accessibility dynamic type motion
haptic" Stack) in `~/.agents/skills/ui-ux-pro-max`; Skill `apple-design` (`~/.agents/skills/apple-design/SKILL.md`, Web-Übersetzung
der WWDC-Vorträge: Federn, Unterbrechbarkeit, Antwort sofort); Hausregeln `Design-Regeln für Agenten.md`; Bahnherz-Bausteine
(`Gemeinsam/Design/Farben.swift`, `Abstand.swift`, `Bahnherz/Sources/Design/Feder.swift`, `HaptikZentrale.swift`, `Hintergrund.swift`,
`TschuliView.swift`). Unter `~/.claude/plugins/cache` liegt kein SwiftUI-/HIG-/Liquid-Glass-Skill (Suche nach `swiftui`,
`human interface`, `liquid glass` findet nur `taste-skill`, eine Bild-Vorlage ohne SwiftUI-Inhalt).

Ergebnis der UI-UX-Pro-Max-Suche für "Fitness/Gym App": Stil "Vibrant & Block-based + Dark Mode (OLED)", Palette
"Energetic (Orange #FF6B35, Electric Blue) + Dark bg". Nicht übernommen: der Auftrag verlangt Apple-monochrom; Orange
lebt nur im Theme Glut, Blau nur als Datenfarbe Erholen. Die Stack-Regeln (Dynamic Type statt fester Größen,
`accessibilityReduceMotion`, `accessibilityLabel` an jedem Symbol) sind übernommen.

## 1. Leitplanken

Aus dem Auftrag (verbindlich):
- Standard ist monochrom im Apple-Stil, kein "girly" Theme, mehrere Themes in den Einstellungen.
- Nur drei Farben wie die Apple-Fitness-Ringe (Bewegen, Trainieren, Erholen), alles andere monochrom.
- Mehr Muster und Animation, aber Bewegung nur bei Ereignissen (Akku-Lehre aus der Schwester-App).
- Figur Lumi ist süß und bunt, das einzig Bunte neben den drei Datenfarben.
- Nie wieder anmelden: kein Anmelde-Bildschirm nach dem ersten Mal (Konto-Teil in SPEC.md, hier nur die Oberfläche: Abschnitt 12.7).
- Kein Wecker, keine Erinnerungen: nur Gesundheit.

Aus den Hausregeln (`Design-Regeln für Agenten.md`) übernommen: eine mutige Sache je Bildschirm (die Ringplatte, das
Training, die Schlafzeit), Haarlinien statt Kachelkränzen, keine Emojis als Icons, keine Farbverläufe außer in Lumi und in
Messwerten, Farbe nie allein (immer Text, Symbol oder Form dabei), echte Zahlen aus den Daten, kleinste Schrift 11 pt,
Zahlen tabellarisch, Tippflächen 44 pt, Reduce Motion schaltet alles ab.

Bewusst anders als die Hausregeln, der Auftrag geht vor:
- Hausregel "kein Umschalter in der App, Hell/Dunkel über das System": es gibt Themes in den Einstellungen. Jedes Theme
  folgt weiter dem System (hell/dunkel), Graphit und Glut wählen beim Einschalten einmalig "Dunkel" vor, Nutzer ändern es.
- Hausregel "eine Akzentfarbe": drei Datenfarben plus die Theme-Farbe. Regel: die Theme-Farbe heißt "Aktion und Auswahl",
  die drei Datenfarben heißen je einen Lebensbereich (Abschnitt 3.3).
- Hausregel "Dunkel ist die Grundlage": hier ist das System maßgeblich, Standard-Theme Monochrom folgt dem System.

## 2. Abgrenzung zu Apples Aktivitätsringen (Risiko)

Die HIG-Seite "Activity rings" (heute gelesen) sagt (englischer Wortlaut, leicht gekürzt):
- "Use Activity rings only to show Move, Exercise, and Stand information. Don't replicate or modify Activity rings for other purposes. Never use Activity rings to display other types of data. Never show Move, Exercise, and Stand progress in another ring-like element."
- "Never change the colors of the rings." "Always display Activity rings on a black background."
- "Don't use Activity rings for decoration." "Never use Activity rings in your app's icon or marketing materials."
- "Differentiate other ring-like elements from Activity rings ... use padding, lines, or labels to separate them ... Color and scale can also help."
- Apple bietet echte Ringe als `HKActivityRingView` (iOS 9.3+).

Der Entwurf v9 zeigt drei konzentrische Ringe in Rot, Grün, Blau für Schritte, Gym und Schlaf. Das ist Risiko, nicht Verbot: Es
sind andere Daten als Move/Exercise/Stand und andere Farbwerte, aber der Look ist nah dran. Ob App-Review das beanstandet, ist
nicht geprüft; die HIG ist eine Richtlinie, keine Review-Regel (nicht verifiziert, welche Regel Review heranzieht).

Entscheidung für die Umsetzung ("Lumen-Bögen", Baustein `LumenBogen`):
1. Form unterscheidet sich: offener Bogen von 270 Grad (Öffnung unten), runde Enden, Strichstärke 9 pt, sichtbare Spur in
   `rand`-Ton. Kein geschlossener Vollkreis, kein Überlauf über 100 Prozent als zweite Runde.
2. Jeder Bogen trägt Beschriftung und Zahl daneben ("8.412 / 10.000 Schritte"), Bogenreihenfolge innen/außen wie in der
   Legende, Abstand zwischen den Bögen 6 pt. Mittelpunkt zeigt Lumi (klein) statt leer.
3. Die Plattenfarbe ist Schwarz (`ringPlatte` #000000) aus einem reinen Kontrastgrund: die Ring-Farben #2DBE4F und #0A9FE0
   erreichen auf hellen Flächen 3:1 nicht (2,05 bis 2,98, Tabelle 3.6). Die Platte macht die Bögen nicht zu Aktivitätsringen; Abstand
   zu Apples Ringen kommt aus Form (offen, 270 Grad), Beschriftung und Daten (Punkte 1 und 2).
4. Kein Ring, auch kein Bogen, in App-Icon, Store-Bildern oder Werbung (Icon-Entwurf in v9 ist ein einzelner offener Bogen
   mit Punkt: einzelne Form, kein Ringsatz; bei Bedenken Lumi statt Bogen nehmen).
5. Fallback, falls der Look zu nah wirkt oder Review ablehnt: statt Bögen drei waagerechte Fortschrittsbalken mit Beschriftung
   (gleiche Farben, gleiche Daten), Umbau ist nur `LumenBogen` -> `LumenBalken`, keine Datenänderung.
6. Optional später: Apples echte Ringe mit `HKActivityRingView` auf einer eigenen Seite "Apple-Aktivität", dann mit den echten
   Move/Exercise/Stand-Daten und ohne Änderung. Nicht in v1.

## 3. Farben

### 3.1 Prinzip

Oberfläche monochrom (Schwarz, Weiß, Grautöne), kleine Theme-Tönung. Drei Datenfarben, jede bedeutet einen Lebensbereich.
Lumi ist bunt. Jede Farbe hat Varianten für hell, dunkel und erhöhten Kontrast; Text und dünne Linien nehmen die "Tief"-Variante,
die Ring-Originale gibt es nur auf der schwarzen Platte und als große gefüllte Flächen.

### 3.2 Themes (Tokens)

Fünf Themes, jedes hell und dunkel. Aus v9 übernommen: Monochrom hell, Graphit dunkel, Stahl hell, Glut dunkel, Wald hell.
Neu entworfen (nicht im Entwurf, siehe Annahmen): Monochrom dunkel (= Systemdunkel), Graphit hell, Stahl dunkel, Glut hell, Wald dunkel.

Token-Rollen: `grund` (Bildschirm), `flaeche` (Karten, Listen), `text`, `text2` (Nebentext), `rand` (Rand von Eingabefeldern und
Segmenten, Bedienelement-Kontrast 3:1), `haar` (reine Trennlinie, dekorativ), `akzent` (Aktion, Auswahl, Hero-Fläche, Tab-Tint),
`aufAkzent` (Text auf `akzent`), `muster` (Linienfarbe der Muster = `akzent`).

| Theme | Modus | grund | flaeche | text | text2 | rand | haar | akzent | aufAkzent |
|---|---|---|---|---|---|---|---|---|---|
| Monochrom | hell | #FFFFFF | #F2F2F7 | #000000 | #5E5E62 | #8A8A8E | #E5E5EA | #000000 | #FFFFFF |
| Monochrom | dunkel | #000000 | #1C1C1E | #FFFFFF | #98989F | #8E8E93 | #2C2C2E | #FFFFFF | #000000 |
| Graphit | hell | #F2F2F7 | #FFFFFF | #1C1C1E | #5A5A5E | #85858A | #D1D1D6 | #1C1C1E | #FFFFFF |
| Graphit | dunkel | #000000 | #1C1C1E | #FFFFFF | #98989F | #8E8E93 | #2C2C2E | #FFFFFF | #000000 |
| Stahl | hell | #F5F7FA | #E8EDF3 | #0B1220 | #566377 | #7B8798 | #D6DDE6 | #1F4E79 | #FFFFFF |
| Stahl | dunkel | #0B1220 | #151E2E | #F2F5FA | #9AA8BC | #7B8BA3 | #243146 | #7FB2E5 | #0B1220 |
| Glut | hell | #FFF8F3 | #FFEBDD | #1A0E05 | #6B4A33 | #9A7258 | #F0D5C0 | #A84300 | #FFFFFF |
| Glut | dunkel | #0D0D0D | #1A1A1A | #F5F5F5 | #9A9A9A | #808080 | #2A2A2A | #FF6A00 | #000000 |
| Wald | hell | #F7F8F6 | #E9ECE6 | #111611 | #566156 | #7A877A | #D8DDD4 | #2F5D3A | #FFFFFF |
| Wald | dunkel | #0C120D | #172019 | #EEF3EE | #9DAE9D | #7E907F | #2A3A2D | #8FC79A | #0C120D |

Graphit dunkel und Monochrom dunkel haben gleiche Farben, sie unterscheiden sich nur im Muster (so auch im Entwurf v9).

Standard: Theme `monochrom`, Erscheinung "System".

Muster (Abschnitt 6) je Theme: Monochrom Punkte, Graphit Diagonalen, Stahl Raster, Glut Wellen, Wald Höhenlinien.

### 3.3 Die drei Datenfarben (eine Farbe heißt eine Sache)

| Bereich | Bedeutung in der App | Ring-Original (nur Platte) hell / dunkel | Tief auf Flächen hell / dunkel |
|---|---|---|---|
| Bewegen | Schritte, aktive Energie, Cardio, Distanz | #FA114F / #FA114F | #D00A3C / #FF4F7E |
| Trainieren | Gym: Sätze, Volumen, Rekorde, Konstanz-Raster, Trainingsdauer, Meilensteine | #2DBE4F / #A6FF00 | #16742F / #A6FF00 |
| Erholen | Schlaf, Erholung, HRV, Ruhepuls, Atmung, Temperatur, Gewichtsverlauf | #0A9FE0 / #00E0F0 | #00699E / #00E0F0 |

Essen ist monochrom (Text-Grautöne und Muster), der Grund: Auftrag "weniger Farben" (Entwurf v8), Essen bekommt keine vierte Farbe.
Warnung und Fehler siehe 3.5.

Regeln:
- Bögen, Balken, Linien und Punkte einer Datenfarbe gehören immer zu genau diesem Bereich.
- Text in Datenfarbe und dünne Linien auf Flächen: nur die Tief-Variante (Kontrast 4,5:1, Tabelle 3.6).
- Ring-Originale nie als Textfarbe, nie als Hintergrund für weißen Text: Weiß auf #FA114F hat 3,99:1 (nur ab 18 pt oder fett).
- Knöpfe sind nie in Datenfarbe, sondern Theme-Akzent; Datenfarben sind Daten.
- Datenfarbe trägt nie allein die Aussage: immer Label, Symbol oder Zahl daneben (CVD-Hinweis: Rot und Grün unterscheiden sich
  für Rot-Grün-Schwache; deshalb zusätzlich Symbol je Bereich: `figure.run`, `figure.strengthtraining.traditional`, `bed.double.fill`).
- Mehrere Reihen in Charts: Datenfarbe plus Muster oder Linienstil, nie nur Farbe.

### 3.4 Lumi-Farben

Lumi ist Dekor mit Textalternative (Stimmung steht auch als Text). Verlauf Mitte nach Rand:

| Stimmung | Mitte | Rand | Kontur auf hellen Flächen | Hof |
|---|---|---|---|---|
| müde | #7C8CF8 | #5E5CE6 | #4B49C9 | #7C8CF8, 55 % |
| bereit | #FFC53D | #FF9500 | #9A5B00 | #FFC53D, 55 % |
| stolz | #FF7A3D | #FA114F | #C20D3F | #FF7A3D, 55 % |

Highlight-Streifen #FFFFFF 55 %, Bäckchen #FF6B8A 55 %, Augen und Mund #2B1A05 (müde #2A2340, stolz #3A0A14). Auf hellen
Flächen bekommt Lumi eine 2-pt-Kontur in der Konturfarbe, weil der gelbe Körper auf Weiß nur 1,58:1 hätte (Tabelle 3.6).
Im Dunkeln braucht Lumi keine Kontur (Randfarbe gegen Flächen: 3,30 bis 7,60:1).

### 3.5 Status, Warnung, Fehler

Weniger Farben: Es gibt kein Ampel-Grün/Gelb/Rot. Halal-, Zucker- und Gut/Schlecht-Zustände sind Pille mit Symbol und Text
in `text` auf `flaeche` (`checkmark.circle.fill`, `exclamationmark.triangle.fill`, `xmark.circle.fill`). Ausnahme: ein Fehlertext
oder eine Warnbox nutzt Warn-Tief `#8F4B00` / `#FFB340` (hell/dunkel) bzw. Fehler-Tief `#C4161C` / `#FF6961`, immer mit Symbol und Text, nie in
Diagrammen. Fehler-Rot ist so nur über Farbe nie von Bewegen-Rot zu unterscheiden; Symbol, Ort (Meldung statt Diagramm) und Text unterscheiden sie. Zerstörerische
Aktionen (Löschen) nutzen die System-Rolle `.destructive`.

### 3.6 Kontrastnachweis (WCAG 2.2, Skript `docs/research/kontrast.py`)

Pflichtpaarungen je Theme und Modus: Text 4,5:1, Bedienelementrand 3:1, Text über Mustern 4,5:1 (schlechtester Punkt = Musterlinie
genau unter dem Text, Muster-Deckkraft in Spalte rechts), Text auf Hero-Streifen, Datenfarben-Tief auf Flächen. Exit 0 heißt: alle bestehen.
Zusammenfassung (Minimum je Spalte; `text2` enthält auch den Fall über der Musterlinie):

| Theme | text/grund | text2 (min) | Akzent (min) | auf Akzent | auf Hero-Streifen | Rand (min) | Muster-Deckkraft |
|---|---|---|---|---|---|---|---|
| Monochrom hell | 21,00 | 4,89 | 18,82 | 21,00 | 17,40 | 3,08 | 12 % |
| Monochrom dunkel | 21,00 | 5,13 | 17,01 | 21,00 | 15,91 | 5,22 | 12 % |
| Graphit hell | 15,25 | 5,07 | 15,25 | 17,01 | 12,62 | 3,29 | 10 % |
| Graphit dunkel | 21,00 | 5,27 | 17,01 | 21,00 | 15,91 | 5,22 | 10 % |
| Stahl hell | 17,45 | 4,53 | 7,36 | 8,66 | 6,63 | 3,10 | 14 % |
| Stahl dunkel | 17,13 | 6,15 | 7,48 | 8,38 | 6,73 | 4,82 | 14 % |
| Glut hell | 18,01 | 6,14 | 5,24 | 6,06 | 4,98 | 3,69 | 14 % |
| Glut dunkel | 17,83 | 5,30 | 6,06 | 7,31 | 5,74 | 4,41 | 20 % |
| Wald hell | 17,19 | 4,62 | 6,41 | 7,64 | 5,93 | 3,16 | 18 % |
| Wald dunkel | 16,87 | 5,69 | 8,59 | 9,75 | 7,72 | 4,92 | 18 % |

Die Zahlen je Paar stehen im Skript (`python3 -I docs/research/kontrast.py`). Mindestwert Text 4,5: Stahl hell (4,53) und Wald hell (4,62) liegen knapp darüber, bei
Änderung eines Tokens Skript neu laufen lassen. Rand Monochrom hell 3,08 gegen 3,0 ebenso knapp.

Hero-Nebentext: der Entwurf dimmt ihn auf 75 % Deckkraft. Über dem Streifen fällt das in vier Themes unter 4,5:1 (Glut hell 3,53; Wald hell 4,13;
Glut dunkel 4,44; Stahl dunkel 4,47; Zeilen "INFO Entwurf v9" im Skript). Regel deshalb: auf Hero-Karten und Ringplatte kein Dimmen mit Deckkraft,
Nebentext in vollem `aufAkzent`, Hierarchie über Größe und Gewicht. Der volle `aufAkzent` auf Streifen ist im Skript Pflichtpaar (4,98 bis 17,40).

Datenfarben:

| Paarung | Ergebnis (min bis max über alle Themes des Modus) | Anforderung |
|---|---|---|
| Bewegen-Tief hell auf `grund`/`flaeche` | 4,64 bis 5,54 | 4,5 |
| Trainieren-Tief hell | 4,93 bis 5,88 | 4,5 |
| Erholen-Tief hell | 5,01 bis 5,98 | 4,5 |
| Warn-Tief hell / Fehler-Tief hell | 5,55 bis 6,62 / 5,06 bis 6,04 | 4,5 |
| Bewegen-Tief dunkel / Trainieren / Erholen dunkel | 5,31 bis 6,67 / 13,46 bis 16,93 / 10,28 bis 12,92 | 4,5 |
| Ringplatte #000000: #FA114F | 5,26 | 3 (Grafik) |
| Ringplatte: #2DBE4F / #A6FF00 | 8,59 / 16,93 | 3 |
| Ringplatte: #0A9FE0 / #00E0F0 | 7,05 / 12,92 | 3 |
| Weißer Text neben den Bögen auf der Platte | 21,00 | 4,5 |
| Lumi-Kontur hell: müde / bereit / stolz | min 5,69 / 4,55 / 5,14 | 3 |
| Lumi-Rand dunkel: müde / bereit / stolz | min 3,30 / 7,60 / 4,18 | 3 |

Beleg für die Notwendigkeit der Tief-Varianten und der Platte (Ring-Originale direkt auf der Fläche, Info im Skript):
#2DBE4F hat auf `flaeche` hell nur 2,05 bis 2,44:1 und #0A9FE0 2,50 bis 2,98:1, beides unter 3:1 für Grafik. Deshalb Platte oder Tief.

Fallen:
- Weißer Text auf #FA114F: 3,99:1. Auf #2DBE4F: 2,44:1. Datenfarbflächen tragen deshalb nie Text, Knöpfe nehmen Theme-Akzent.
- Glass-Tönung ändert den gerenderten Ton (Bahnherz-Erfahrung): Hauptknopf ist deshalb deckend `.borderedProminent`, nicht `.glassProminent` (Abschnitt 7).

### 3.7 Erhöhter Kontrast (`colorSchemeContrast == .increased`, HIG Pflicht für eigene Farben)

Regel statt Tabelle: `text2` wird `text`, `rand` wird `text2` des Modus, `haar` wird `rand`, alle Muster aus (Kopf, Karten, Hero-Streifen),
Hero bleibt in `akzent`, Lumi behält Farben (Kontur immer an). Datenfarben auf Flächen: nur Tief-Varianten (Ring-Originale nur auf der Platte).
Nachweis: `text` auf `grund` 15,2 bis 21,0:1 (Tabelle 3.6), `text2`=`text`; Rand=text2 ≥ 4,5:1 (Wert aus Spalte text2).

## 4. Schrift

System-SF Pro, Zahlen in SF Rounded (`.fontDesign(.rounded)` nur an Zahlen, Beschriftungen bleiben SF Pro, so wie im Entwurf:
Titel `SF Pro Display` 700, Zahlen `Rounded` 700). Nichts einbetten (HIG, Systemschriften). Nur Textstile (Dynamic Type), kein
`.system(size:)`, Ausnahme Heldenzahl mit `@ScaledMetric(relativeTo: .largeTitle)`.

| Rolle | Stil | Gewicht | Pt | Verwendung |
|---|---|---|---|---|
| Heldenzahl | `@ScaledMetric` 56, rounded, `.monospacedDigit()` | `.bold` | 56 | Schlafzeit, Pausen-Timer, Gewicht im Detail |
| Seitentitel | `.largeTitle` | `.bold` | 34 | "Heute", "Gym" |
| Titel | `.title2` | `.bold` | 22 | Kartenüberschrift |
| Zeilentitel | `.headline` | `.semibold` | 17 | Übungsname, Mahlzeit |
| Fließtext | `.body` | `.regular` | 17 | Coach-Antworten, Hinweise |
| Zahl in Zeile | `.title3` rounded | `.bold`, `.monospacedDigit()` | 20 | 70 kg, 142 g |
| Meta | `.subheadline` | `.medium` | 15 | "Letztes Mal 67,5 kg × 6" |
| Beschriftung, Datum, Pille | `.footnote` | `.semibold` | 13 | Pillen, GROSSBUCHSTABEN-Datum (+0,04 em) |
| Kleinstes | `.caption` | `.medium` | 12 | Achsenwerte; `.caption2` (11 pt) nicht benutzen |

Regeln:
- Kein Gewicht unter `.regular`, unter 15 pt mindestens `.medium` (Hausregel und HIG "avoid Ultralight, Thin, Light").
- Zahlen immer `.monospacedDigit()` und `.contentTransition(.numericText())`, damit sie beim Aktualisieren rollen statt springen.
- Hierarchie über Größe und Gewicht, nicht Farbe. Genau ein Heldenelement je Bildschirm.
- Dynamic Type bis `.accessibility3`: Zeilen wechseln ab `dynamicTypeSize.isAccessibilitySize` von HStack auf VStack; Satz-Raster
  (4 Spalten) wird zu einer Liste. Chips lineLimit 1, Übungsnamen bis 3 Zeilen.
- Tab-Leisten-Beschriftung ist Systemverhalten (wächst nicht mit), nichts tun.
- Sprache: Deutsch, liebevoll, klar, kurz. Beispiele: "Starker Tag. 70 kg sind 2,5 mehr als letzte Woche.", "Heute eher locker. Du hast
  zweimal unter 6 Stunden geschlafen.", leer: "Noch kein Training. Tipp auf Starten, Lumi zählt mit."
  Fehler sagen, was schiefging und was jetzt hilft: "Kein Zugriff auf Schlaf. Öffne Einstellungen > Health und erlaube Schlaf."

## 5. Abstände, Radien, Schatten

Raster 4 pt (gleiche Namen wie Bahnherz/Lovea):

| Token | pt | Nutzung |
|---|---|---|
| `xs` | 4 | Symbol zu Text |
| `s` | 8 | Chips untereinander, Satz-Kästchen |
| `m` | 12 | Kartenabstand, innen in Zeilen |
| `l` | 16 | Seitenrand, Karteninnenrand (Entwurf: 14 px, gerundet auf 16) |
| `xl` | 24 | zwischen Abschnitten |
| `xxl` | 32 | unter dem Titel, über der Hauptkarte |
| `tippflaeche` | 44 | Mindestgröße jeder Tippfläche |

| Radius | pt | Nutzung |
|---|---|---|
| `Rundung.klein` | 10 | Satz-Kästchen, Heatmap-Zellen (2 pt dort) |
| `Rundung.feld` | 12 | Eingabefeld |
| `Rundung.karte` | 16 | Karten, Ringplatte (kontinuierlich `.continuous`) |
| Kapsel | voll | Pillen, Knöpfe, Segmente |
| Sprechblase Coach | 18, an der Absenderseite unten 6 | wie Entwurf |

Schatten: keiner auf Karten. Glas bringt seinen eigenen mit. Karten sind flach (`flaeche`), Trennung durch `haar` und Weißraum.
Keine Kachelkränze: Listen sind Zeilen mit Haarlinien in einer Karte; Drei-Spalten-Raster (Werte, Satz-Kästchen) nur mit echten Zahlen.

Layout: nur iPhone (`TARGETED_DEVICE_FAMILY 1`), Seitenrand 16, Breiten 390 und 440 pt prüfen, einspaltig.

## 6. Muster

Je Theme ein Muster, ruhig im Kopfbereich (läuft nach unten aus), schwächer auf Karten, als Streifen auf der Hauptkarte.
Aus dem Entwurf übernommen (CSS-Werte nach Punkt umgerechnet):

| Theme | Muster | Parameter | Linienfarbe |
|---|---|---|---|
| Monochrom | Punkte | Raster 12 pt, Punktradius 0,55 pt | `akzent`, Deckkraft 12 % |
| Graphit | Diagonalen 135° | Linie 1 pt, Abstand 8 pt | `akzent`, 10 % |
| Stahl | Raster | Linie 1 pt, Raster 16 pt | `akzent`, 14 % |
| Glut | Wellen | konzentrische Kreise um Punkt (85 %, 0 %), Linie 1 pt, Abstand 10 pt | `akzent`, 20 % dunkel / 14 % hell |
| Wald | Höhenlinien | zwei Ellipsen-Sets um (20 %, 10 %) Abstand 10 pt und (90 %, 80 %) Abstand 13 pt, Linie 1 pt | `akzent`, 18 % |

Orte:
1. Bildschirmkopf (Tab-Wurzeln): über die ganze Höhe, Maske von Deckkraft 100 % oben über 55 % bei 35 % Höhe auf 15 % unten.
2. Karten (`flaeche`): Muster mit 45 % der Theme-Deckkraft, `isolation`, hinter dem Text.
3. Hauptkarte (Ringplatte, Schlaf-Zeit, Pausen-Timer): Streifen 120°, 2 pt Linie, Abstand 11 pt, helle Linien auf dunkler Karte,
   dunkle auf heller (Deckkraft Streifen 10 % bzw. 12 %, im Skript als schlechtester Punkt nachgerechnet).
4. Nirgends hinter Diagrammen (Marks müssen lesbar bleiben) und nie bei erhöhtem Kontrast.

Umsetzung (Akku): ein `Canvas`, das beim ersten Zeichnen und bei Größenänderung zeichnet, danach `drawingGroup()` (Metal-Textur, bleibt
im Cache). Kein `TimelineView`, keine Dauer-Animation. Einmaliges Einfahren beim ersten Öffnen eines Tabs: Muster blendet in 1,1 s von
Deckkraft 0 auf Soll und fährt 40 pt hoch (im Entwurf 7 s, hier gekürzt: 7 s für einen Hintergrund ist zu langsam und hält die GPU
unnötig wach). Reduce Motion, Stromsparmodus: kein Einfahren, Muster steht sofort. Reduce Transparency: Muster bleibt, ist undurchsichtig-grau.
Erhöhter Kontrast: aus (Abschnitt 3.7). Alle Muster `accessibilityHidden(true)`.

## 7. Liquid Glass: wo ja, wo nein

Stand 01.11.2026 (Ahmed: "If iOS apple liquid glass is heavy then no more of that"): kein eigenes Glas mehr. Nur das Glas, das iOS selbst
zeichnet (Tab-Leiste, Toolbar, Sheets), bleibt. Was unten unter "Ja, eigenes Glas" steht, ist ersetzt durch `lumenFlaeche` (Bausteine.swift):
`flaeche` mit `haar`-Rand, ohne Unschärfe und Schatten. Der Rest des Abschnitts ist Geschichte.

Grundsatz laut HIG "Materials" (heute gelesen): Liquid Glass ist die Steuerungs- und Navigationsebene und liegt über dem Inhalt; in der
Inhaltsebene benutzt man Standard-Materialien oder deckende Flächen; sparsam einsetzen.

Ja, automatisch durch das System (nichts selbst bauen):
- `TabView` mit `Tab(...)` (iOS 18) in iOS 26: schwebende Glas-Leiste, `.tabBarMinimizeBehavior(.onScrollDown)` auf Listen (nicht auf Gym im Training).
- Toolbar, Sheets, Menüs, Alerts, Scroll-Edge-Effekt oben und unten (`.scrollEdgeEffectStyle(.soft, for: .top)` wo Karten unter der Leiste laufen).
- `tabViewBottomAccessory` (iOS 26): laufendes Training als Minileiste über der Tab-Leiste (Dauer, Pause-Countdown, Beenden).

Ja, eigenes Glas, höchstens zwei Gruppen je Bildschirm, immer in einem `GlassEffectContainer(spacing: 12)`, `.regular.interactive()`:
1. Schwebender Scan-Knopf (`camera.viewfinder`, Essen) und Plus-Knopf (Gym: Übung hinzufügen), 44 pt rund.
2. Profil-Avatar in der Toolbar (Menü).

Nein: Karten, Ringplatte, Zeilen, Chips, Pillen, Hintergrund, Hauptknopf (deckend), Satz-Kästchen. Glas nie auf Glas.
Hauptknopf (`Satz fertig`, `Training starten`): `.buttonStyle(.borderedProminent)` mit `.tint(akzent)` und `foregroundStyle(aufAkzent)`: deckende
Füllung, Kontrast gerechnet (Tabelle 3.6, Spalte "auf Akzent" 6,06 bis 21,00). `.glassProminent` ist nicht nachrechenbar (Tönung ändert den Ton),
Entscheidung deshalb deckend; am Gerät testen, ob Glas besser wirkt (Testpunkt 1).

Beispiel:
```swift
Button("Satz fertig") { satzFertig() }
    .buttonStyle(.borderedProminent)
    .tint(.akzent)
    .foregroundStyle(Color.aufAkzent)
    .controlSize(.large)

GlassEffectContainer(spacing: 12) {
    Button { scannen() } label: { Image(systemName: "camera.viewfinder").frame(width: 44, height: 44) }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Essen scannen")
}
```

Akzent-Tint der Tab-Leiste: `.tint(.akzent)`. Auswahl ist durch gefülltes Symbol und Beschriftung erkennbar, nicht nur Farbe.
Eigene Hintergrundfarbe in Tab- oder Navigationsleiste: nein (stört Glas und Scroll-Edge).
Reduce Transparency und Erhöhter Kontrast übernimmt das System; eigene Flächen sind deckend.

## 8. SF Symbols

Darstellung: `.symbolRenderingMode(.hierarchical)` für Bereichssymbole in Datenfarbe-Tief, `.monochrome` in Tabs und Chips, `.palette` nur für
Leerzustände mit Lumi. Tab-Symbole gefüllt. Jedes Symbol ohne Text bekommt `.accessibilityLabel`. Alle Namen unten sind gegen
`sf-symbols-typescript@2.1.0` (SF Symbols 6, 8198 Namen) geprüft und vorhanden; SF-Symbols-7-Namen sind nicht geprüft und werden nicht benutzt.
Beim Bau: ein Test, der jedes Symbol als `UIImage(systemName:) != nil` prüft (CI-Simulator), weil ein falscher Name nur zur Laufzeit leer bleibt.

| Zweck | Symbol |
|---|---|
| Tab Heute | `sun.max.fill` |
| Tab Gym | `figure.strengthtraining.traditional` |
| Tab Essen | `fork.knife` |
| Tab Schlaf | `bed.double.fill` |
| Tab Coach | `bubble.left.and.bubble.right.fill` |
| Bewegen, Laufen, Cardio | `figure.run` |
| Schritte | `figure.walk` (Alternative `shoeprints.fill`) |
| Training, Hantel | `dumbbell.fill` |
| Serie, Streak | `flame.fill` |
| Scan, Barcode | `camera.viewfinder`, `barcode.viewfinder` |
| Mahlzeit, Trinken | `fork.knife`, `drop.fill` |
| Schlaf, Nacht | `bed.double.fill`, `moon.zzz.fill`, `moon.stars.fill` |
| Puls, Herz | `heart.fill`, `bolt.heart.fill`, `waveform.path.ecg` |
| Atmung, SpO2 | `lungs.fill`, `wind` |
| Temperatur | `thermometer.medium` |
| Gewicht | `scalemass.fill` |
| Diagramme | `chart.line.uptrend.xyaxis`, `chart.bar.fill`, `chart.xyaxis.line`, `chart.pie.fill` |
| Rekord, Pokal | `trophy.fill`, `medal.fill`, `checkmark.seal.fill`, `star.fill` |
| Ziel | `target`, `flag.checkered` |
| Zeit, Pause | `timer`, `stopwatch.fill` |
| Dehnen, Erholung | `figure.cooldown`, `figure.mind.and.body` |
| Freunde | `person.2.fill`, `person.badge.plus` |
| Mit Lovea verbinden | `link`, `link.badge.plus` |
| Band, Funk | `dot.radiowaves.left.and.right`, `antenna.radiowaves.left.and.right`, `applewatch` |
| Profil | `person.crop.circle.fill` |
| Einstellungen | `gearshape.fill` |
| Aussehen | `paintpalette.fill`, `circle.grid.3x3.fill`, `square.grid.3x3.fill` |
| Schloss, Konto | `lock.fill`, `key.fill`, `faceid` |
| Hinzufügen, Mehr | `plus.circle.fill`, `ellipsis.circle` |
| Trend hoch/runter | `arrow.up.right`, `arrow.down.right`, `minus` |
| Haken, Fehler, Warnung | `checkmark.circle.fill`, `xmark.circle.fill`, `exclamationmark.triangle.fill` |
| Mikrofon, Senden | `mic.fill`, `paperplane.fill` |
| Teilen | `square.and.arrow.up` |
| Weiter | `chevron.right` |

Nicht verwendet, weil es den Namen nicht gibt: `bluetooth` (stattdessen `dot.radiowaves.left.and.right`).

## 9. Bewegung und Haptik

Grundsatz (Auftrag): Bewegung nur bei Ereignissen, nichts läuft endlos im Hintergrund (Akku). Mehr Animation als vorher, aber jede hat
Auslöser, Dauer und Obergrenze. HIG Motion (heute gelesen): kurz, präzise, nie einziger Informationsweg, optional.

Federn (gleicher Satz wie Bahnherz/Lovea, Datei `Feder.swift`): `schnell` `.snappy(0.28)` (Tippantwort), `weich` `.smooth(0.38)`
(Übergänge), `federnd` `.bouncy(0.42, extraBounce 0.12)` (Freude), `jelly` `.spring(response 0.32, damping 0.55)` (Loslassen, Press 0,94).
Stromsparmodus: ohne Überschwinger.

Ereignisse (jede Zeile ist ein einmaliger Auslöser, Dauer begrenzt):

| Ereignis | Bewegung | Dauer | API | Obergrenze |
|---|---|---|---|---|
| Tab zum ersten Mal je App-Start sichtbar | Karten gleiten 10 pt hoch + einblenden, gestaffelt 0,06 s | 0,5 s | `.scrollTransition` oder `.transition` + `.animation(weich)` | einmal je Tab und Start, nicht bei jedem Tabwechsel |
| Muster fährt ein | Deckkraft 0 auf Soll, 40 pt hoch | 1,1 s | `withAnimation(.weich)` einmal | einmal je Tab und Start |
| Bögen füllen sich | Strich von 0 auf Wert | 1,1 s `cubic-bezier(.2,.8,.2,1)` | `withAnimation` auf `trim(from:to:)` | einmal beim Anzeigen; Wert-Update: Kurzbewegung 0,38 s |
| Zahlen zählen hoch beim Öffnen (Entwurf: 0,8 s) | Zahl läuft von 0 auf Wert | 0,8 s | `withAnimation(.easeOut(duration: 0.8))` auf einen animierbaren Zahlenwert + `.contentTransition(.numericText(value:))` | einmal beim Anzeigen; spätere Wertänderung rollt 0,38 s |
| Satz fertig | Kästchen hakt, Knopf gibt nach (0,94) | 0,28 s | `jelly` | je Tipp |
| Neuer Rekord | Toast gleitet ein, Medaille `scale 0,3 auf 1` mit `federnd`, Lumi `stolz` hüpft | 0,6 s, Toast steht 3 s | `PhaseAnimator` einmal | einmal je Rekord, nie wiederholt |
| Pause läuft ab | Zahl zählt herunter (Zahl ändert sich nur, keine Bewegung); Ende: Haptik + Band | 1 Zahl/s | `Text(timerInterval:)` (System tickt) | nur während der Pause |
| Lumi öffnet | hüpft 3 mal `huepf` 1,1 s | 3 s | `KeyframeAnimator` | beim ersten Öffnen am Tag, sonst 1 Hüpfer; Reduce Motion: statisch |
| Lumi Stimmung wechselt | Farbe blendet, Auge blinzelt | 0,42 s | `federnd` | je Wechsel |
| Heatmap | Zellen blenden ein, Zellen mit höchster Stufe leuchten einmal | 0,4 s + 1,2 s | `withAnimation` | einmal |
| Linien zeichnen sich | `trim(from:0, to:1)` | 0,8 s | `withAnimation` | einmal je Anzeige |
| Balken wachsen | Höhe von 0 auf Wert | 0,5 s | `withAnimation(.weich)` | einmal |
| Tab-Punkt | springt ein | 0,5 s | `jelly` | je Tabwechsel |
| Coach tippt | drei Punkte pulsieren | solange die Antwort unterwegs ist, max. 15 s | `phaseAnimator`, `.task` mit Abbruch | **einzige** Dauerbewegung, nur solange eine Anfrage läuft |
| Partner im Gym ("live") | Ring um den Avatar pulsiert 3 mal (Entwurf: 1,8 s je Puls) | 5,4 s | `symbolEffect(.pulse, options: .repeat(3))` oder `PhaseAnimator` | beim Erscheinen der Karte, nie dauerhaft |

Regeln:
- Reduce Motion: kein Skalieren, kein Hüpfen, kein Einfahren; Zustände wechseln durch Überblenden (0,2 s) oder sofort; Zahlen ohne Rollen;
  Press-State per Deckkraft 0,6 (HIG Buttons verlangen einen Pressed-State).
- Stromsparmodus: kein Einfahren, kein Überschwinger, Lumi 1 Hüpfer, Charts ohne Zeichnen.
- Nichts läuft im Hintergrund oder bei ausgeschaltetem Bildschirm; keine `TimelineView` ohne Auslöser; `Canvas` nur bei Änderung.
- Alles abbrechbar (Eingabe wird nie blockiert, `apple-design`: "Never lock out input").
- Bewegung und Haptik im selben Frame.

Haptik (`.sensoryFeedback`, iOS 17; nur bei klarer Ursache; Schalter "Haptik" in den Einstellungen, Standard an):

| Moment | Muster |
|---|---|
| Tab-, Theme-, Chip-Auswahl | `.selection` |
| Training starten / beenden | `.start` / `.stop` |
| Satz fertig | `.impact(weight: .medium)` |
| Gewicht oder Wiederholungen ± | `.increase` / `.decrease` |
| Pause vorbei | `.impact(flexibility: .rigid)` (zusätzlich Band, Abschnitt 12.1) |
| Neuer Rekord, Meilenstein | `.success` (einmal) |
| Lumi steigt eine Stufe | `.levelChange` |
| Fehler bei Eingabe (Passwort falsch) | `.error` mit Schütteln |
| Warnung (z. B. Gesundheitszugriff fehlt) | `.warning` (einmal) |

Ton: keiner (Band und System übernehmen Hinweise).

## 10. Maskottchen: Lumi

> Stand 29.10. (nach dem Entwurf v10): Form und Farben von Lumi gelten nach `design.html` v10, Ahmed hat sie freigegeben. Die drei SVG-Vorlagen liegen in `docs/research/lumi/` und gehen dem Flammenpfad unten vor; Stimmungen, Größen, Stufen und Einsatz unten gelten weiter.

Idee: ein kleines Licht, rund wie ein Tropfen mit kleiner Flamme oben (Pfad im Entwurf: `M40 8 C44 14 47 16 50 14 C50 20 62 28 64 44 A24 24 0 0 1 16 44 C17 30 28 24 31 14 C34 17 37 15 40 8Z`,
viewBox 80x80), große glänzende Augen mit Lichtpunkt, Bäckchen, zwei Ärmchen, Leucht-Hof, kleiner Schatten. Süß und bunt, das einzig bunte
Wesen (Oberfläche bleibt Apple-ruhig).

Umsetzung (Ponytail): reine SwiftUI-`Shape`-Komposition wie Tschuli in Bahnherz (Schichten mit `Path`, ohne Bild-Assets, skaliert als Vektor),
`LumiView(stimmung:groesse:)`. Größen 24 (Tab-Punkt, Live Activity), 40 (Zeile), 52 (Stimmungsauswahl), 72 (Kopf), 120 (Leerzustand).
Farben fest, schlagen im Dunkelmodus nicht um (Körper aus Abschnitt 3.4, Augen und Mund fest dunkel).
Auf hellen Flächen: Kontur 2 pt. Fallback bei Zeitnot: SF Symbol `flame.fill` mit Palette.

Der Entwurf nennt Rive (State Machine) für später: nicht nötig für v1, weil Stimmungen nur drei Farben und drei Gesichter wechseln.

| Stimmung | Wann | Aussehen |
|---|---|---|
| `bereit` | gut erholt, Standard | sonnengelb, Augen offen, Mund lächelt, rechter Arm winkt, blinzelt |
| `muede` | wenig Schlaf (unter 6 h) oder niedrige HRV | blau-lila, Augen als Bögen, `z z` schweben, Ärmchen hängen |
| `stolz` | Rekord, Meilenstein, Serie | rot-orange, Arme hoch, Augen als Bögen, offener Mund, bunte Funken (Gelb, Grün, Blau, Rot) |
| `schlaeft` (neu, Annahme) | nachts 22 bis 5 Uhr, im Schlaf-Tab | wie `muede`, Augen zu, `z` |
| `denkt` (neu, Annahme) | Coach lädt | wie `bereit`, Auge schaut nach oben, Punkte-Blase |

Stufen: Lumi wächst mit dir (Entwurf: "Stufe 7", Pfad mit 9 Punkten). Vorschlag: Stufe 1 bis 9 aus Meilensteinen (Abschnitt 12.6),
je Stufe +3 % Größe, ab Stufe 3 Hof, ab 6 zusätzlich Funken beim Öffnen. Genaues Stufenmodell gehört in die Spec (Annahme).

Einsatz: Heute-Kopf (72 pt) mit Satz, Stimmungswahl im Lumi-Detail (52 pt), Leerzustände (120 pt), Coach-Tippanzeige (24 pt),
Mitte der Bögen (40 pt), Live Activity (24 pt), Widgets. Dekoration `accessibilityHidden(true)`, außer Lumi trägt Status; dann steht der Status auch als Text daneben
("Lumi ist müde").

App-Icon: offener Bogen mit Punkt (schwarz auf weiß/hell, weiß auf schwarz/dunkel, wie im Entwurf), ohne Text, als eine PNG im Asset-Katalog. Kein Ringsatz (Abschnitt 2).

## 11. Struktur und Navigation

Fünf Tabs (Vorgabe der Spec; HIG Tab bars: Einwort-Beschriftung, Leiste immer sichtbar, kein "Mehr"):

| # | Tab | Symbol | Zweck |
|---|---|---|---|
| 1 | Heute | `sun.max.fill` | Ringplatte, Plan, Tages-Score, Lumi, Partner-Karte (nur verbunden), Verlauf |
| 2 | Gym | `figure.strengthtraining.traditional` | Training, Pläne, Fortschritt |
| 3 | Essen | `fork.knife` | Mahlzeiten, Makros, Scan, Fasten |
| 4 | Schlaf | `bed.double.fill` | letzte Nacht, Woche, Werte (HRV, Puls, SpO2, Temperatur, Atmung, VO2max) |
| 5 | Coach | `bubble.left.and.bubble.right.fill` | Chat, Vorschläge |

Wohin gehören die übrigen Teile:

| Teil | Ort |
|---|---|
| Fortschritt (Kraftkurve, Sätze je Muskel, Muskel-Körperkarte, Rekorde) | Gym > Segment "Fortschritt" |
| Verlauf (Gewicht, Konstanz-Raster) | Heute > Zeile "Verlauf" (Push); Gewicht eintragen über Heute > Gewicht |
| Freunde-Feed, Rangliste, Einladungscode | Heute > Karte "Freunde" > Sheet; nur sichtbar mit mindestens einem verbundenen Freund |
| Partner-Karte (Lovea) | Heute, nur wenn Lovea verbunden ist; sonst nichts, kein Platzhalter |
| Lumi, Meilensteine, Medaillen, Serie | Heute > Lumi antippen > Push "Lumi" |
| Tages-Score (Erholung, Belastung, Schlaf) | Heute, unter der Ringplatte |
| Gewohnheiten (Habits) | Heute > Karte "Gewohnheiten": Zeilen mit Haken und Serie (Tipp = `.selection`); Verwaltung über Zeile "Bearbeiten" |
| Cardio | Gym > "Training starten" fragt Art: Kraft oder Cardio; Cardio-Werte (Distanz, Dauer, Puls) in Bewegen-Tief; Verlauf im Segment "Fortschritt" |
| Check-in und Check-out (Studio) | Gym > Zeile "Studio" mit Knopf Einchecken/Auschecken; Besuche zählen ins Konstanz-Raster (Verlauf) |
| Lebensmittel-Favoriten, Halal-/Zucker-Ampel | Essen > Chips "Favoriten" über der Mahlzeitenliste; Ampel als Pille mit Symbol und Text (3.5) |
| Wiege-Erinnerung | entfällt: Erinnerungen sind nicht Teil von Lumen Fit; Gewicht trägt man über Heute > Gewicht ein (Annahme, Abschnitt 18) |
| Werte (HRV mit 60-Tage-Bereich) | Schlaf-Tab, Abschnitt "Erholung" |
| Profil, Einstellungen, Themes, Verbindungen | Avatar-Kapsel oben rechts auf jedem Tab > Sheet "Profil" |
| Onboarding: Profil anlegen | einmalig beim allerersten Start, Abschnitt 12.7 |

Regeln: `NavigationStack` je Tab, Ziele über `.navigationDestination(for:)`. Zurück-Wisch systemisch. Tiefe höchstens Tab > Liste > Detail.
Tab bleibt sichtbar außer in Modalen. `tabBarMinimizeBehavior(.onScrollDown)` auf Heute, Essen, Schlaf, Coach-Verlauf; auf Gym während eines Trainings aus
(das Training läuft in `tabViewBottomAccessory`).

## 12. Bildschirm-Skizzen

Alle Skizzen für 390 pt Breite. `[ ]` = tippbar (mindestens 44 pt), `( )` = Glas, `####` = Hauptkarte (die eine mutige Sache),
`:::` = Muster, `~` = Datenfarbe, Partner steht für die verbundene Person.

### 12.1 Gym

```
+------------------------------------+
|  ::::::::::::::::::::::::::::::::: |  Muster im Kopf
|  PUSH · SATZ 3 VON 4      ( J  v ) |  Datum-Stil, Avatar (Glas)
|  Bankdrücken                       |  34 pt Titel
|  [Training | Pläne | Fortschritt]   |  Segment
|                                    |
|  +------------------------------+  |
|  | [1]60x10 [2]65x8 [3]70x6 [4]-|  |  Satz-Kästchen, aktuell mit
|  +------------------------------+  |  2 pt Rand in text
|  ##############################    |
|  # PAUSE                       #    |  Hauptkarte schwarz/akzent mit
|  #            1:24             #    |  Streifen, Heldenzahl 56 pt
|  # Letztes Mal: 67,5 kg x 6    #    |
|  ##############################    |
|  | Schrägbank Kurzhantel  3x10 |   |  Zeilen, Haarlinien
|  | Dips                   3x12 |   |
|  | Seitheben              4x15 |   |
|  [        Satz fertig         ]    |  Hauptknopf deckend
|  ( Training 00:42:10 · Pause 1:24 )|  Minileiste, tabViewBottomAccessory
| ( Heute  Gym  Essen  Schlaf  Coach)|  Tab-Leiste (System-Glas)
+------------------------------------+
```
Kästchen: gewogene Zahl rollt, Rekord: Toast "Neuer Rekord: 70 kg x 6" mit Lumi `stolz`. Scheibenrechner als Sheet (`presentationDetents([.medium])`).
Pause ende: Haptik plus Band vibriert (Band-Verbindung teilt die App mit anderen Apps, Konto-Teil in SPEC.md).
Fortschritt-Segment: Kraftkurve (Linie + Fläche + Endpunkt, Datenfarbe Trainieren-Tief), Sätze je Muskel gegen Ziel (Balken mit Zahl rechts), Muskel-Körperkarte (Erholung je Muskel in Graustufen mit Muster), Rekordliste.
Leer: Lumi `bereit` 120 pt, "Noch kein Training. Tipp auf Starten, Lumi zählt mit." plus Hauptknopf.

### 12.2 Heute

```
+------------------------------------+
|  :::::::::::::::::::::::::::::::   |
|  DONNERSTAG, 29. OKTOBER  ( J v )  |
|  Heute                             |
|  [Lumi 72]  Gut erholt. Heute      |  Lumi antippen = Lumi-Seite
|             Beine?                 |
|                                    |
|  ##############################    |
|  #  (  ~~~~~  )  8.412 Schritte #   |  Ringplatte schwarz, Lumen-Bögen
|  #  ( ~~~~~~~ )  3 / 4 Gym     #   |  Spur + Bogen, Legende mit Zahl
|  #  (  ~~~~~  )  7:12 Schlaf   #   |
|  ##############################    |
|  | Bereit?   ~Erholung ~Belastung|  |  Tages-Score, drei Bögen klein
|  |           ~Schlaf             |  |  (Tief-Farben)
|  | Push heute 17:30   [Starten] |   |  Plan-Karte, Hauptknopf
|  | Kalorien 1.840 / 2.600       |   |
|  | Gewohnheiten  2 / 3 heute    |   |  Zeilen mit Haken, Serie
|  | Gewicht 78,4 kg        >     |   |
|  | Verlauf                >     |   |
|  | ( J ) Partner im Gym seit 18 min|  |  nur wenn verbunden, Punkt pulsiert 3x
| ( Heute  Gym  Essen  Schlaf  Coach)|
+------------------------------------+
```
Die Ringplatte trägt das Heldenelement (Streifenmuster, Text darauf ohne Dimmen). Plan-Karte ist flach (Entwurf v9: Plan-Karte in Akzent; hier eine mutige Karte je Bildschirm, Abschnitt 17).
Leer (neu): Lumi `bereit` 120 pt, "Erlaube Health, dann zähle ich Schritte, Schlaf und Training für dich." [Health erlauben].

### 12.3 Essen

```
+------------------------------------+
|  ::::::::::::::::::::::::::::::::: |
|  HEUTE GEGESSEN           ( J v )  |
|  Essen                             |
|  +------------------------------+  |
|  |  ( Makro-Donut )  142 g Protein| |  SectorMark, drei Muster
|  |                   190 g Kohl.  | |  (Streifen, Punkte, Fläche) + Label
|  |                    58 g Fett   | |
|  +------------------------------+  |
|  | Protein je Tag vs Ziel  ~~~~ |  |  Balken, Ziellinie gestrichelt
|  | Fasten 16:8   noch 3:12      |  |
|  | Döner, Hähnchen   [ok Halal] |  |  Pille mit Symbol + Text
|  | Skyr Vanille   22 g Protein  |  |
|  |                  ( Scan )    |  |  Glas-Knopf rechts unten
| ( Heute  Gym  Essen  Schlaf  Coach)|
+------------------------------------+
```
Essen ist monochrom: Donut-Segmente unterscheiden sich durch Grauton und Muster, nicht Farbe. Foto-Scan mit Portion-Schieber (Sheet),
Zucker- und Halal-Pille: `checkmark.circle.fill` / `exclamationmark.triangle.fill` plus Text. Leer: Lumi `bereit`, "Noch nichts gegessen. Scanne eine Packung oder tippe + ."

### 12.4 Schlaf

```
+------------------------------------+
|  ::::::::::::::::::::::::::::::::: |
|  LETZTE NACHT             ( J v )  |
|  Schlaf                            |
|  ##############################    |
|  #            7:12             #    |  Hauptkarte, Heldenzahl, Streifen
|  #   23:41 bis 06:53 · Ziel 8:00#    |
|  ##############################    |
|  | Phasen-Balken (Kern/Tief/REM)|   |  Phasen durch Muster + Beschriftung
|  | Schnitt Woche            6:48|   |
|  | Unter 6 Stunden    2 Nächte  |   |
|  | Erholung: HRV 68 ms   im Bereich|  |  60-Tage-Bereich, Punkt nach Lage
|  | [Ruhepuls 54][SpO2 97 %]     |   |  Werte-Chips (Symbol + Zahl)
|  | ( J ) Partner 8:05      |    |   |  nur wenn verbunden
| ( Heute  Gym  Essen  Schlaf  Coach)|
+------------------------------------+
```
Datenfarbe Erholen-Tief für Balken und HRV. Lumi `schlaeft` im Kopf nachts. Leer: "Keine Schlafdaten. Trage dein Handy oder die Uhr nachts."

### 12.5 Coach

```
+------------------------------------+
|  :::::::::::::::::::::::::::::::   |
|  MERKT SICH DEINE ZIELE   ( J v )  |
|  Coach                             |
|  ( Starker Tag. 70 kg auf der Bank   |  Blase links, flaeche
|    sind 2,5 mehr als letzte Woche. )|
|           ( Bisschen müde, sonst gut)|  Blase rechts, akzent
|  ( Dann morgen Pull leicht und früh |
|    schlafen. Vor 23 Uhr ins Bett? ) |
|  [Lumi 24] ...                     |  Tippanzeige
|  [Mach ich] [Später]               |  Antwort-Chips
|  [ Nachricht...             (mic) ]|  Eingabe (Feld, rand)
| ( Heute  Gym  Essen  Schlaf  Coach)|
+------------------------------------+
```
Blasen sind keine Glas-Flächen. Coach-Vorschläge als Chips mit Handlung ("Mach ich" setzt eine Gewohnheit, nicht nur Text). Keine Marke, kein "KI-Tonfall": kurze Sätze, eine Frage, Bezug auf echte Zahlen.
Fehler (kein Netz): "Gerade keine Verbindung. Ich merke mir deine Frage und antworte gleich." mit Lumi `bereit`.

### 12.6 Lumi, Meilensteine

```
+------------------------------------+
|  <  Lumi                           |
|        [Lumi stolz 120]            |
|     Neuer Meilenstein              |
|     100 Gym-Tage                   |
|  Stufe 7   o--o--o--o--o--o--o  o  o|  Pfad, erledigt in Trainieren-Tief
|  Serie  flame.fill  12 Wochen      |
|  [Medaille][Medaille][Medaille]    |  schwarz, 2 pt Rand in Trainieren
|  [Medaille][  gesperrt ][gesperrt] |  gesperrt: Grau, Text daneben
|  Nächstes Ziel: 125 Gym-Tage       |
|  ======-----  80 / 125             |
+------------------------------------+
```
Medaillen sind monochrom (schwarz, im Dunkeln weiß), Rand in Trainieren-Ring-Farbe; Text trägt den Namen. Stimmungswahl (müde, bereit, stolz) nur als Vorschau, automatisch aus Daten.

### 12.7 Profil, Einstellungen, Onboarding

Onboarding (einmal, ohne Anmelden danach):
```
+------------------------------------+
|                                    |
|         [Lumi bereit 120]          |
|       Willkommen bei Lumen Fit     |
|  Name      [ Sam              ]    |
|  Passwort  [ ••••••••         ]    |
|  [        Profil anlegen       ]   |
|  Du meldest dich nie wieder an.    |
|  Dein Profil bleibt, auch nach     |
|  einem Update.                     |
+------------------------------------+
```
Anschließend ein Schritt "Health erlauben" (Bildschirm mit Erklärung, kein Zwang). Kein Anmelde-Bildschirm danach: bei fehlendem Netz bleibt die App voll nutzbar,
Sitzung im Schlüsselbund (Konto-Teil in SPEC.md). Passwort falsch bei späterer Passwortänderung: `.error` plus Schütteln, Text "Passwort stimmt nicht. Versuch es nochmal."

Profil (Sheet über Avatar, `presentationDetents([.large])`):
```
|  Profil                            |
|  [Avatar]  Sam         Name ändern |
|  Aussehen                       >  |  Theme-Karten + Erscheinung
|  Verbindungen                   >  |  Lovea, Freunde, Band
|  Health-Daten                   >  |  Zugriff, Quellen
|  Benachrichtigungen             >  |
|  Haptik                      [on]  |
|  Über Lumen Fit                 >  |
```
Aussehen: fünf Karten mit Mini-Vorschau (Farbe, Muster), Auswahl mit Haken und `.selection`-Haptik. Darunter Segment "Erscheinung: System | Hell | Dunkel"
(Graphit und Glut wählen beim Aktivieren einmalig Dunkel vor). Vorschau wechselt sofort, ohne Neustart, ohne erneute Anmeldung.

Verbindungen: "Mit Lovea verbinden" Zeile (`link`), Zustand "Nicht verbunden" / "Verbunden mit Lovea". Nicht verbunden: keine Partner-Teile sichtbar,
alles funktioniert normal. Verbunden: Partner-Karte (Heute, Schlaf), Mitteilungen "Partner ist im Gym", Zusammenfassungen, nicht mehr.
Freunde: Einladungscode zeigen oder eingeben.

## 13. Diagramme

Swift Charts (iOS 16+): `LineMark` + `AreaMark` (Kraftkurve, Gewicht, HRV), `BarMark` (Sätze je Muskel, Protein je Tag, Schlafwoche), `RectangleMark` (Konstanz-Raster, 18 Wochen x 7 Tage),
`SectorMark` (Makro-Donut, iOS 17), `Gauge` mit `.accessoryCircularCapacity` für die kleinen Tages-Score-Bögen.

Regeln:
- Eine Frage je Diagramm, Titel ist die Aussage ("Bankdrücken, bester Satz: 70 kg, +10 kg").
- Datenfarbe des Bereichs in Tief-Variante (Abschnitt 3.3); Ziellinie gestrichelt in `text2` mit Beschriftung; Endpunkt als gefüllter Kreis mit Wert.
- Mehrere Reihen unterscheiden sich durch Farbe plus Muster oder Linienstil, nie nur Farbe (CVD, Kontrast). Essen: nur Grautöne und Muster.
- Achsen: höchstens 4 Beschriftungen, `.caption`, `text2`; Gitterlinien `haar`.
- Konstanz-Raster: vier Stufen aus `flaeche` bis Trainieren-Tief (Deckkraft 0 / 32 / 62 / 100 %), Legende "weniger ... mehr"; jede Zelle 10 pt, Radius 2.
- Jedes Diagramm bekommt `.accessibilityChartDescriptor(_:)` und eine Textzeile mit der Kernzahl.
- Zeichnen einmal beim Anzeigen (Abschnitt 9), nie fortlaufend.
- Keine Muster hinter Diagrammen (Abschnitt 6).

## 14. Widgets und Live Activity

Ziel `com.onlyus.lumen-fit.widgets`. Farben dieselben Tokens des aktiven Themes (über App Group `group.com.onlyus.lumen-fit` gelesen), Hintergrund
`containerBackground(for: .widget)` in `grund`; im getönten Modus (`widgetAccentable`) nur Text und Symbole, Muster entfällt.

| Widget | Inhalt |
|---|---|
| Klein | drei Lumen-Bögen (Bewegen, Trainieren, Erholen) mit Mittelzahl Schritte, Lumi 24 pt |
| Mittel | Bögen links, rechts Plan "Push 17:30", Serie `flame.fill` |
| Sperrbildschirm rund | ein Bogen (Schritte), `Gauge` |
| Sperrbildschirm rechteckig | Schlafzeit + Erholung |
| Live Activity: Training | kompakt: Lumi 24 + Dauer; erweitert: Übung, Satz 3/4, Pause-Countdown; Sperrbildschirm: Fortschritt als Balken in Trainieren-Tief |
| Live Activity: Pause | Countdown `Text(timerInterval:)` (System tickt, keine eigene Animation) |

Text nie unter 11 pt (`.caption` 12). Live Activity nur während Training, Update höchstens bei Satzwechsel (Akku).

## 15. Zustände, Fehler, Barrierefreiheit

- Leerzustände mit Lumi, einem Satz und einer Handlung (`ContentUnavailableView`, Bildslot = Lumi).
- Ladezustand: Skelett-Zeilen, Lumi `denkt` nur im Coach; kein Spinner ohne Text.
- Fehler: sagen, was schiefging und was jetzt hilft; Symbol plus Text; Warn-Tief nur hier (Abschnitt 3.5).
- Dynamic Type bis `.accessibility3`, Layout wechselt zu VStack. 390 und 440 pt prüfen, nichts abgeschnitten, nichts überlappt.
- VoiceOver: Bögen sind ein Element: "Schritte: 8.412 von 10.000" mit `accessibilityValue`; Satz-Kästchen: "Satz 3, 70 Kilogramm, 6 Wiederholungen, aktuell"; Diagramm: Descriptor plus Kernsatz;
  Lumi: Status als Text ("Lumi ist müde"); Dekoration versteckt.
- Reduce Motion, Reduce Transparency, Stromsparmodus, Erhöhter Kontrast: Abschnitte 3.7, 6, 7, 9.
- Differenzieren ohne Farbe (`accessibilityDifferentiateWithoutColor`): Symbol je Bereich (Abschnitt 3.3), Muster in Charts.
- Tippflächen 44x44 pt: Avatar, Satz-Kästchen (Höhe 44 durch Abstand), Chips (Höhe 44 mit `contentShape`), Glas-Knöpfe.
- Datenschutz in der Oberfläche: Partner-Daten nur zeigen, wenn verbunden und freigegeben; sonst nichts.

## 16. Bausteine (Namen verbindlich, aus Bahnherz kopiert und angepasst)

| Datei | Quelle | Inhalt |
|---|---|---|
| `Gemeinsam/Design/Farben.swift` | Bahnherz `Farben.swift` | `FarbToken`, `dyn`, `Palette` je Theme und Modus; Tokens aus 3.2 und 3.3 |
| `Gemeinsam/Design/Abstand.swift` | Bahnherz | `Abstand`, `Rundung` (Werte aus Abschnitt 5) |
| `Gemeinsam/Design/Theme.swift` (neu) | – | `enum LumenTheme { monochrom, graphit, stahl, glut, wald }`, `@AppStorage("theme")`, `@AppStorage("erscheinung")`, `.preferredColorScheme` |
| `Gemeinsam/Design/Muster.swift` (neu) | – | `MusterFlaeche(muster:deckkraft:)`, `Canvas` + `drawingGroup` |
| `Gemeinsam/Design/LumiView.swift` (neu) | Bahnherz `TschuliView.swift` (Aufbau) | `LumiView(stimmung:groesse:)`, Stimmungen, Kontur |
| `Gemeinsam/Design/LumenBogen.swift` (neu) | – | 270°-Bogen mit Spur, `LumenBalken` als Fallback |
| `<App>/Sources/Design/Feder.swift` | Bahnherz | `Feder`, `FederKnopfStil` |
| `<App>/Sources/Design/HaptikZentrale.swift` | Bahnherz | Haptik mit Schalter, plus `.start`, `.stop`, `.levelChange` |
| `<App>/Sources/Design/HeroKarte.swift` (neu) | Bahnherz `Bausteine.swift` | Hauptkarte: `akzent`-Fläche (Ringplatte: `ringPlatte`), Streifenmuster, kein Schatten |
| `<App>/Sources/Design/Bausteine.swift` | Bahnherz | `ListenKarte`, Pille, Zeile mit Haarlinie |

Farben-Helfer (aus Bahnherz, unverändert; Theme-Layer löst `Palette.<token>` je aktivem Theme auf):
```swift
extension Color {
    static func dyn(_ hell: UInt32, _ dunkel: UInt32, hellHoch: UInt32? = nil, dunkelHoch: UInt32? = nil) -> Color { ... }
}
```
Konstanten in `@MainActor`-Typen, die `nonisolated`-Code liest: `nonisolated static let` (Swift-6-Erfahrung aus Bahnherz).
Test `FarbenKontrastTests` rechnet dieselben Paare wie `kontrast.py` und schlägt bei < 4,5 / 3 fehl (zweite Absicherung).

## 17. Abweichungen vom Entwurf v9 (design.html)

| Entwurf | Hier | Grund |
|---|---|---|
| `--sub` #8A8A8E auf Weiß/Grau (3,44 / 3,08:1) | `text2` #5E5E62 (Mono hell) | unter 4,5:1; die gleiche Schwäche steht in Stahl (#64748B auf #E8EDF3: 4,04), Wald (#667066 auf #E9ECE6: 4,32) |
| Muster Monochrom 16 % Punkte (text2 darüber 3,60:1) | 12 %, `text2` dunkler | Text über Musterlinie unter 4,5:1 |
| Zahl in Gewicht 300 (`.alarm` Light, 54 px) | `.bold`, 56 pt | HIG: Light vermeiden |
| Schrift 9 bis 10,5 px in Chips/Badges (mehrfach) | mindestens `.caption` 12 pt | Hausregel Minimum 11, Dynamic Type |
| Muster fährt 7 s ein | 1,1 s, einmal | Akku und Gefühl |
| Plan-Karte in Akzent neben schwarzer Ringkarte (zwei laute Karten) | Plan-Karte flach, Ringplatte ist Heldenelement | Hausregel "eine mutige Sache" |
| Drei geschlossene Ringe in Rot/Grün/Blau auf Theme-Fläche | offene 270°-Bögen auf schwarzer Platte | HIG Activity rings (Abschnitt 2); Kontrast 2,05 bis 2,98:1 auf hellen Flächen |
| Bewegungs-Punkte (Coach tippt) `infinite` | höchstens 15 s, nur bei laufender Anfrage | einzige Dauerbewegung, Akku |
| Ringfarben direkt für Text und Linien (z. B. Pille Trainieren, Chips) | Tief-Variante | 4,5:1 |
| Avatar-/Medaillen-Farben Verlauf (v6) | monochrom, Rand in Datenfarbe | v8 "weniger Farben" |
| Graphit hell, Stahl dunkel, Glut hell, Wald dunkel, Monochrom dunkel | neu entworfen | Entwurf zeigt je Theme nur einen Modus; Auftrag verlangt hell und dunkel |
| Lumi nur `müde`, `bereit`, `stolz` | plus `schlaeft`, `denkt` | Nacht und Coach-Laden (Annahme) |
| Hauptknopf nicht festgelegt | deckend `.borderedProminent` | Kontrast nachrechenbar, Glas-Tönung nicht |
| Gewicht-Verlauf mit Erholen-Farbe | beibehalten | Entwurf `m-rec` |
| Essen-Donut: Protein in Trainieren-Grün, Fett in Erholen-Blau, Kohlenhydrate in Text-Ton (Legende des Entwurfs) | Donut komplett monochrom (Grauton + Muster + Beschriftung) | Grün und Blau heißen Gym und Schlaf (eine Farbe heißt eine Sache); Fett in Erholen-Blau wäre falsch. Kehrt Auftraggeber um: Protein in Trainieren-Tief ist die vertretbare Ausnahme |
| Werte-Chips: Punktfarben HRV und VO2max Grün, Puls Rot, Temperatur Grau, SpO2 und Atmung Blau | Punkt nach Bereich: HRV, Ruhepuls, SpO2, Atmung, Temperatur Erholen-Tief; VO2max Trainieren-Tief; Schritte/Cardio Bewegen-Tief | Puls und HRV sind Erholungswerte; Rot ist Bewegen; im Entwurf steht außerdem ein Roh-Rot #E5484D im Quelltext (ein vierter Ton, vom v8-CSS überdeckt, hier nicht übernommen) |
| HRV-Bereichsbalken: "Im Bereich" in Rot, "Darüber" in Blau (Entwurf) | alle Balken Erholen-Tief, Unterschied durch Beschriftung und Länge | Rot = Bewegen |
| Lumi ohne Kontur | Kontur 2 pt auf hellen Flächen, optional | gelber Körper auf Weiß nur 1,58:1; Lumi ist Dekor mit Textalternative, die Kontur darf entfallen, wenn die Figur auf `ringPlatte` oder dunklem Grund steht |
| Hero-Nebentext 75 % Deckkraft | kein Dimmen | unter 4,5:1 in vier Themes (3.6) |
| Zahlen zählen 0,8 s, Knopf gibt 0,12 s nach | 0,8 s übernommen; Knopf 0,28 s (`jelly`) | Web-Wert gegen SwiftUI-Feder, kein Auftrag zum Ändern |

Aus dem Entwurf v9 gelesen und übernommen (Mockup-Quelltext Zeile für Zeile durchgesehen): fünf Themes mit Farben und Mustern, drei Datenfarben, fünf Tabs,
Lumi (Form, Farben, drei Stimmungen, Funken, Blinzeln, 3 Hüpfer), Meilensteine als schwarze Medaillen mit Rand in Trainieren (gesperrt = grau), Serie, Pfad "Stufe 7",
Tages-Score mit drei Kreisen (hier `Gauge`), Schnell-Satz mit "Letztes Mal" und Rekord-Toast, Scheibenrechner, Foto-Scan mit Portion-Schieber und Fasten-Balken 16:8,
Freunde-Feed mit "Respekt" statt Like und Wochen-Rangliste, Körperkarte (dunkel = müde, hell = frisch), HRV mit persönlichem Bereich (60 Tage), Punkten nach Lage
und Text-Einblick, Konstanz-Raster 18 Wochen, Kraftkurve mit Rekord, Sätze je Muskel gegen Ziel, Coach-Blasen mit Antwort-Chips.

## 18. Annahmen, Risiken, Prüfung

Annahmen (in SPEC.md unter "Annahmen" übernehmen):
1. Fünf Themes jeweils hell und dunkel; die fünf Modi, die der Entwurf nicht zeigt (Monochrom dunkel, Graphit hell, Stahl dunkel, Glut hell, Wald dunkel), sind neu entworfen.
2. Graphit und Glut wählen beim Aktivieren "Dunkel" vor (wie im Entwurf), Nutzer können auf System/Hell umstellen.
3. Das Dokument benutzt keine Personennamen; "Partner", "Freund", "Studio" sind Platzhalter, echte Namen kommen aus dem Profil zur Laufzeit.
4. Ringplatte immer Schwarz (#000000), auch im Hellmodus; im Dunkelmodus auf schwarzem Grund ohne eigene Fläche, mit `haar`-Linie nur bei anderem Grund (Stahl, Glut, Wald dunkel).
5. Lumi `schlaeft` und `denkt`, Stufenmodell (3 % je Stufe), Medaillenliste: Vorschläge.
6. Hauptknopf deckend statt Glas.
7. Gewichtsverlauf in Erholen-Farbe wie im Entwurf.
8. Habits als Karte auf Heute, Cardio als Trainingsart in Gym, Check-in/Check-out als Zeile "Studio" in Gym, Wiege-Erinnerung entfällt (Erinnerungen gehören nicht zu Lumen Fit).
9. Essen-Donut monochrom (Abschnitt 17).

Risiken:
- Aktivitätsringe-Ähnlichkeit (Abschnitt 2): Review-Risiko nicht geprüft; Fallback `LumenBalken`.
- Stahl (Akzent #1F4E79 / #7FB2E5) und Wald (#2F5D3A / #8FC79A) liegen im Farbton nahe an Erholen bzw. Trainieren; Verwechslung nur durch Form (Aktion = Fläche und Kapsel, Daten = Bogen, Linie, Balken) und Label verhindert. Am Gerät prüfen.
- Glas auf Muster: der Scroll-Edge-Effekt kann die Musterlinien unter der Leiste weich ziehen; am Gerät prüfen.
- Glut dunkel: Muster 20 % ist das stärkste; `text2` über Linie 5,30:1 (rechnerisch ok), Lesbarkeit am Gerät prüfen.
- Nicht prüfbar ohne Mac: Aussehen von `glassEffect`, `MeshGradient` (nicht benutzt), Canvas-Muster, Charts, Widgets; SF-Symbols-7-Namen (nicht benutzt).
- `AXChartDescriptorRepresentable` Doku-Pfad 404, Typname am Compiler prüfen.

Testliste am Gerät (Reihenfolge nach Risiko):
1. Hauptknopf: `.borderedProminent` in allen Themes, hell und dunkel, Text lesbar; optional `.glassProminent` vergleichen.
2. Theme wechseln: Muster, Tab-Tint und Ringplatte in allen 10 Kombinationen, kein Neustart, keine erneute Anmeldung.
3. Ringplatte: Bögen lesbar, Beschriftung daneben, Lumi in der Mitte; sieht es zu nah an Apple-Aktivitätsringen aus?
4. Reduce Motion, Reduce Transparency, Erhöhter Kontrast, Stromsparmodus: Muster, Einfahren, Hüpfen, Zahlenrollen.
5. Dynamic Type `.accessibility3`: Satz-Kästchen werden Liste, nichts abgeschnitten (390 und 440 pt).
6. Muster unter der Tab-Leiste und Scroll-Edge-Effekt: kein Flimmern, kein Ruckeln beim Scrollen (Akku, Instruments Energy).
7. Lumi: Kontur hell, Stimmungen im Dunkeln, Größen 24 bis 120.
8. Diagramme: VoiceOver liest Descriptor und Kernsatz; Konstanz-Raster auch ohne Farbe (Stufen erkennbar).
9. Symbole: alle vorhanden (CI-Test `UIImage(systemName:)`).
10. Widgets und Live Activity: getönter Modus, Sperrbildschirm.

## Anhang: Kontrast-Skript

Formel WCAG 2.2: relative Luminanz L = 0,2126 R + 0,7152 G + 0,0722 B mit linearisiertem sRGB (c <= 0,03928 ? c/12,92 : ((c+0,055)/1,055)^2,4); Verhältnis (L1 + 0,05) / (L2 + 0,05).
Skript: `docs/research/kontrast.py` (`python3 -I docs/research/kontrast.py`, Exit 0 = alle Pflichtpaare bestehen; `--md` gibt Markdown-Tabellen je Paar aus). Nach jeder Token-Änderung neu laufen lassen und Abschnitt 3.2 und 3.6 anpassen.
