# Lovea-Aufbau der Health-Seiten (Theme Lovea)

Stand 31.10.2026. Ahmed: "Mach Health aus Lovera raus, aber dafür muss diese Health-Ansicht in Lovera 1:1 auch in Lumenfit nachstellbar sein durch dieses Theme Lovera."

## Regel

- Wählt ein Konto das Theme Lovea und hat die Freigabe (`KontoDienst.loveaErlaubt`, nur Ahmed und Annika), gilt der Lovea-Aufbau (`LumenAufbau.lovea`, `Design/LumenAufbau.swift`).
- Alle anderen Themes behalten den heutigen Aufbau, optisch unverändert. Gespeichertes `lovea` ohne Freigabe = Monochrom = heutiger Aufbau.
- Die Wahl fällt einmal an der Wurzel (`AppRootView`, Umgebungswert `lumenAufbau`). Nur die Tab-Wurzeln lesen sie (Heute, Gym-Start); Karten kennen sie nicht.
- Tab-Leiste bleibt (5 Tabs). Sicherheitsgrund: Deep-Links und `Router.oeffne`. Im Lovea-Aufbau öffnen Kacheln auf Heute Schlaf und Essen als Push im Heute-Stapel (`Router.schiebe`), wie in Lovea. Alternative (Tab-Leiste weg) steht unten unter "Offen".

## Was gebaut ist (Heute, Wurzel)

Reihenfolge wie Lovea `HeuteView`: Kopf (Datum, "Health") · Plantag-Zeile · Tagesform (Tageswahl, Wochenleiste, Tagesform-Karte mit Ring, Gründen, "Für heute", Gefühl-Leiste) · Zyklus-Hinweis · "Dein Tag" (Kachelraster: Schritte, Wasser, Schlaf, Habits, Coach, Food, Gewicht, Gym/Pause, Creatin, danach Lumen-Extras Koffein, Protein, Stimmung) + Schreib-Karte · Einsichten · Coach-Sicherheitszeile · "Körper" (Bilanz, Ziel, Sätze/Felder, Körper-Blatt) · Verlauf-Zeile · "Mehr aus Lumen Fit" (Score, Hinweise, Energie-Verlauf, Plan, Schritte, Gewicht, Wochenstreifen, Partner). Kein Lumen-Extra geht verloren, es steht am Ende.
Dazu: Gym-Start im Lovea-Aufbau mit "Auschecken vergessen" vor Kopf/Start. Serie-Feier (Herzen, Hüpfer) an der Habit-Flamme, nur Theme Lovea.

## Bleibt in Lovea (nicht nachgebaut)

- Punkte und Challenges, Shop, Partner-Chat: Lovea-eigene Funktionen.
- Wecker und Erinnerungen: Lumen hat eigene Wege (Umfang-Gate, Alarm nicht erlaubt).
- Partner-spezifische Gym-/Essen-/Messungs-/Plan-Ansichten: bewusst nicht, Lumen zeigt nur die Partner-Karte.

## Offen (klar benannt)

1. Zyklus: `ZyklusKnopf`, `ZyklusChip`, schwebende Zyklus-Deko (Lovea `Zyklus/ZyklusStil.swift:112,146`, `ZyklusDeko.swift:91-113`) nicht angeglichen. Aufwand etwa 0,5 Tag.
2. Diagramm-Farben, Symbolgewichte, Bewegungen je Ansicht in Gym, Schlaf, Essen, Coach: Lumen nimmt Farben aus `LumenFarben.tief` und Palette (themenunabhängig), Lovea feste Farben (Schlafphasen orange/himmel/indigo, Essen mint, Wasser blau). Nicht angeglichen. Aufwand etwa 1 Tag (zentraler Hebel in `LumenFarben.tief`, dann je Ansicht prüfen).
3. Schlaf-, Essen-, Coach-, Gym-Wurzeln im Lovea-Aufbau umsortieren (Schlafziel als Karte, Übungsliste und Split-Zeile auf der Gym-Startseite): laut Tabellen unten "Aufbau anders" oder "fehlt". Aufwand etwa 2 Tage.
4. Energie-Karte: Partner-Zeile, Stufenfarben der Faktoren im Detail, Kappe-Zeile fehlen. Habit-Karte: Tönung je Kachel, Vergangene Tage, Vergleichskarte fehlen.
5. Nichts davon wurde kompiliert oder in der CI gelaufen (kein Swift-Compiler lokal). Screenshots 390/440 pt kommen aus dem CI-Schritt "Screenshots Lovea-Aufbau".

## Tabellen aus dem Code (Datei:Zeile)

Urteil: gleich / AUFBAU ANDERS / FEHLT. Die Tabellen sind der Stand vor dem Bau; Heute und Gym-Reihenfolge sind seitdem angeglichen (siehe oben).

## Teil A: Gym, Essen, Coach, Navigation

**Kürzel:** L = `~/code/lovea-app-ios/Lovea/Sources/Health/`, F = `/home/tobi/projects/lumen-fit-ansicht/LumenFit/Sources/Module/`.

**Gelesen:** alles unten Genannte. **Nicht gelesen oder nur überflogen:**
- `WorkoutSatzZeile` (L/WorkoutView.swift:973), `ScheibenBlatt`, Lovea-Cardio.
- Lumen `RechnerBlatt`, `CardioView`, `UebungsSucheView`, `UebungDetailView` nur im Kopf.
- Lovea `MuskelKarte` und `Muskeln` nicht.
- Pfad `Gemeinsam/Navigation/Route.swift` liegt auf Wurzelebene `/home/tobi/projects/lumen-fit-ansicht/Gemeinsam/Navigation/Route.swift`, nicht unter `Sources/Module`.

## 0. Navigation (Weg dorthin)

| Thema | Lovea | Lumen Fit | Urteil |
|---|---|---|---|
| Einstieg | `HeuteZiel` (HeuteView.swift:419) hat `.training/.koerper/.verlauf`. Push per `pfad.append`. `navigationDestination` :526, Zielwahl :698-712. Alle drei stehen im selben Stapel wie der Rest von Health. | `Route` (Gemeinsam/Navigation/Route.swift): `.gym(GymBereich)` mit `training/plaene/fortschritt`, `.verlauf`, `.uebung(id)`. `RouteAnsicht.swift:10,15,17`. Gym ist ein eigener Tab (`GymTabView`), oben Segment Training/Plan/Fortschritt (`GymTabView.swift:16-20`). | AUFBAU ANDERS: Lovea hat 3 Seiten im Health-Stapel. Lumen hat 1 Tab mit 3 Segmenten. |
| Plantag-Karte oben auf Heute | `PlantagKarte` (HeuteView.swift:472) pusht `.training` | `Heute/HeuteTabView.swift:173` öffnet `.gym(.plaene)` (nur Zeile gesehen, Karte nicht gelesen) | nicht geprüft, Ziel wohl anders (Plan statt Training) |
| Gym-Kachel in "Dein Tag" | `trainingKachel` (HeuteView.swift:953) → `gymOeffnen()` (:685). Läuft eine Einheit, folgt `HealthZiel.gymSession`. | nicht gesucht | – |
| Kasten "Körper" | HeuteView.swift:499. Eingebettet `KoerperInhalt(mitFigur:false, mitStreifen:false, mitNaechstes:false)` (:668-675). Tipp auf Feld öffnet Blatt (:530-534). | gibt es nicht | FEHLT (Lumen bettet nichts in Heute ein) |
| Kasten "Verlauf" | HeuteView.swift:500 und :681 pushen `.verlauf` | Verlauf nur aus Fortschritt-Liste (FortschrittSegmentView.swift:59) | AUFBAU ANDERS |
| Seite "Körper" | `HeuteZiel.koerper` (:711) nur per `healthSeite == "koerper"` (:555) bzw. `tabWunsch` (AppRootView.swift:126). Kein sichtbarer Knopf im Tab. | ersetzt durch Segment Fortschritt | – |

## 1. Gym-Startseite

| | Lovea | Lumen Fit | Urteil |
|---|---|---|---|
| (a) Name | `GymStartView` L/GymNeu/GymStartView.swift:333, Inhalt `GymStartInhalt` :83. Titel "Gym", `.large` (:~350). | `GymStartView` F/Gym/GymStartView.swift:6, Segment "Training" ohne laufende Einheit (GymTabView.swift:37) | – |
| (c) Weg | `GymStartZiel` (:452) wählt für die eigene Person `GymStartView`, für den Partner `TrainingsPlanView`. Push über HeuteZiel.training. | Tab Gym, Segment Training (Standard). Router: `.gym(.training)` (Router.swift:19) | AUFBAU ANDERS (Tab statt Push) |
| (b) Reihenfolge Lovea | 1 `GymWochenLeiste` (:89, Def. :271) · 2 Zeile "Du/Partner + Status" (:90/:110) · 3 "Auschecken vergessen?" orange (:91/:130) · 4 Kopf: Titel + "Starten/Weiter/Fortsetzen"-Kapsel (:92/:138) · 5 Abweichung: Testwoche, Verlegen-Menü, Zurück (:93) · 6 `ZeitKarte` (:95) · 7 Übungsliste (Tipp öffnet Editor, :97) · 8 Überschrift "SPLIT" (:98) · 9 Split-Zeile (:99/:236) · 10 "Diese Woche anderes Split testen" (:100-105) | | |
| (b) Reihenfolge Lumen | | 1 Wochenleiste mit Titel (:52, Def. :77) · 2 Tageskarte `HeroKarte` mit Status, Name, Umfang, Zeitschätzung, Start + "Anderer Tag"-Menü (:53, :105) · 3 Vergessen-Karte mit "Endzeit eintragen" / "Nach 1,5 Stunden" (:54, :150) · 4 "Diese Woche": Testwoche, Verlegen, Zurück (:55, :180) · 5 Zwei Cardio-Knöpfe Laufband / Stairmaster (:56-66) · 6 "Einstellungen fürs Training" (:67-69) · 7 "Letzte Einheiten" (5 Stück) + "Alle Trainingstage" + "Training nachtragen" (:71, :228-262) · 8 `StudioKarte` (:72) | AUFBAU ANDERS: Reihenfolge anders. Fehlt in Lumen: Partner-Zeile, Übungsliste auf der Startseite, Split-Zeile, Split-Test-Zeile. Zusätzlich in Lumen: Cardio-Knöpfe, Einstellungen-Knopf, Letzte Einheiten, Studio-Karte. |
| (c) Menü ⋯ Lovea | Toolbar `menue` (:361): Plan von Partner (:363) · Verlauf · Messungen · Übungen · Split wechseln · Freies Training (:370, nur ohne laufende Einheit). Alles `navigationDestination(item:)` (:355), also Push. | Es gibt kein ⋯-Menü. Wege: Freies Training im "Anderer Tag"-Menü (:~140), Verlauf über "Alle Trainingstage" (:250, Push), Messungen über Fortschritt-Liste, Split-Bibliothek im Segment Plan. | AUFBAU ANDERS |
| (d) Farben / Gewichte | Wochenleiste: Kreis grün `KoerperFarbe.erholt` (30D158), Ring `.primary` 2 pt für heute, gefüllt `.primary` für gewählt, Text 13 pt `.semibold` (:~295-311). Punkt je Person `Color.person`. Vergessen-Zeile `.orange`, `.semibold` (:130-133). Start-Kapsel `.primary` auf `systemBackground`, `.semibold` (:150-155). Animation: `withAnimation(Feder.weich)` beim Tagwechsel (:~397). Chevrons `.footnote.weight(.semibold)`. | Wochenleiste `GymFarbe.gruen` (Tief-Farbe "trainieren"), Symbol `checkmark.circle.fill` / `circle` / `minus` (:87), Rahmen 1,5 pt für heute, Füllung `gruen.opacity(0.16)` für gewählt. Hero-Karte schwarze Platte, Start-Knopf weiß/schwarz (:136-139). Keine Tagwechsel-Animation, nur Haptik `.federnd`. | AUFBAU ANDERS (Lovea: Kreise, Lumen: Symbole in Kachel) |
| Zeitschätzung | `ZeitKarte` L/Zeit/ZeitKarte.swift:4: orange bei Warnung, `.semibold`, eigene Karte mit 12 % Tönung | Als Zeile in der Hero-Karte (GymStartView.swift:~110-113), `timer` / `exclamationmark.triangle.fill` | AUFBAU ANDERS (keine eigene Karte) |

## 2. Studio / Defekt / Einstellung / Zeit

| Ansicht | Lovea (Datei:Zeile) | Weg / Reihenfolge / Farben (Lovea) | Lumen Fit | Urteil |
|---|---|---|---|---|
| Studio im Plan | `StudioEinhang` L/Studio/StudioKarte.swift:53, nur in `TrainingsPlanView.swift:19` unter `if eigener` | Reihenfolge: Menü `StudioKopf` (:4), Toggle "Feste Uhrzeit", DatePicker "Beginn", `OeffnungsWarnKarte` (:32, orange 14 %). **Toter Zweig:** `TrainingsPlanView` wird nur für den Partner geöffnet (GymStartView.swift:385/:460; TrainingsPlanView.swift:39). Die eigene Studio-Einstellung ist in der Oberfläche nicht erreichbar. | `StudioKarte` F/Gym/StudioKarte.swift:6, am Ende der Startseite (GymStartView.swift:72). Studio + "Ändern" · Besuche/Serie · Warnungen · "Einchecken". Blatt `StudioEditorBlatt` (:55). | Lumen hat MEHR: Karte erreichbar, mit Besuchszähler und Einchecken. Lovea hat die Funktion im Code, aber ohne Zugang. |
| Zeitschätzung | `ZeitKarte` Zeit/ZeitKarte.swift:4, `ZeitSchaetzung.swift` | im Start :95 | F/Gym/ZeitSchaetzung.swift (Logik), Anzeige in Hero-Karte | GLEICH (Logik), Anzeige anders |
| Defekt | `DefektAbschnitt` L/Defekt/DefektKarte.swift:108 (in `WorkoutUebungView` :608), `DefektKarte` :5, `DefektMeldenKnopf` :67 (`.tint(.orange)`, :76), `DefektMeldenBlatt` :82 | zweiter Abschnitt unter Kopf/Notiz/Pause, vor Einstellung und Ausweichen | F/Gym/DefektKarte.swift:5/:91/:105/:132, eingehängt in `UebungsKarte` (:30, nach Haarlinie, vor `GeraeteAbschnitt`). Dazu `AusweichKarte` (:68, "Getauscht, statt …", "Zurück zu Original"). Farben aus `palette`, nicht orange. | GLEICH im Aufbau, Farbe anders (Lovea Orange, Lumen Palette). Lumen zusätzlich `AusweichKarte`. |
| "So geht's" / "Meine Einstellung" | L/Einstellung/EinstellKarte.swift:5/:58, `EinstellAbschnitt` :5, `EinstellBlatt` :31 (`presentationDetents([.medium])`). Aufklappen mit `withAnimation(.snappy)` (EinstellKarte.swift:~22). `healthKarte(HabitFarbe.himmel)`, "Unsicher" in `HabitFarbe.amber`. | dritter Abschnitt in `WorkoutUebungView` (:609) | F/Gym/GeraeteEinstellungKarten.swift:5/:49/:100/:150, `GeraeteAbschnitt` in `UebungsKarte` (:31). Aufklappen `.snappy` mit `ruhig`-Prüfung (:13), `.transition(.opacity)` (:44). | GLEICH (nur Umbenennung und Bewegung-aus-Prüfung) |
| Hinweise-Daten | `Einstellung/hinweise.json` (84 Zeilen) | | F/Gym/EinstellHinweise.swift (100 Zeilen) | GLEICH |

## 3. Laufendes Training

| | Lovea | Lumen Fit | Urteil |
|---|---|---|---|
| (a) Name | `GymSessionView` L/WorkoutView.swift:129 → Übersicht `WorkoutInhalt` :347 → Einzelübung `WorkoutUebungView` :562 | `TrainingLaufView` F/Gym/TrainingLaufView.swift:6 (eine Seite) | AUFBAU ANDERS |
| (c) Weg | Start-Kapsel → `session = id` → `navigationDestination` Push (GymStartView.swift:356). Übung antippen → zweiter Push `WorkoutUebungView` (WorkoutView.swift:~142). | `GymTabView` zeigt `TrainingLaufView` im Segment Training, solange `sitzung.sessionId != nil` (GymTabView.swift:37). Kein Push. | AUFBAU ANDERS |
| (b) Lovea Übersicht | Titel groß (`.largeTitle.bold`, :394 ff., Menü zum Tagwechsel mit `chevron.down.circle.fill`) · Werte Dauer (blau) / Volumen / Sätze / Puls (rot) / kcal (:378-390) · Übungszeilen mit rundem Bild, "Jetzt dran" blau, Zähler "2/3" grün bei fertig (:430-452) · Hinweis "Halte eine Übung gedrückt" (:365) · Abschnitt "Hinzufügen": "Übung hinzufügen" / Laufband / Stairmaster (:539-548) · Beendet: "Beendet" grün + Zeiten + Weiter (:549). Untere Leiste `WorkoutLeiste` (:31): `.borderedProminent` blau, Timer `.title2.bold`, rote Überzeit (:84), ±15 s und Überspringen (:61-70). Toolbar: ⋯ (Startzeit, Verwerfen), "Beenden" mit `popoverTip`. | | |
| (b) Lumen | | Kopf mit Tagname, Timer (Tipp ändert Startzeit), Sätze, kg, Puls/kcal (:70-120) · `NaechsterSatzKarte` (:24) · `UebungsKarte` je Übung (:25-27) · "Übung hinzufügen" (:28) · "Training beenden" rot (:32) · unten `rueckgaengigLeiste` + Hauptknopf "Satz fertig" / "Cardio eintragen" / "Training beenden" (:41-45, :148) | |  |
| Einzelübung Lovea (:562-) | `List`: Kopf mit Bild 56 pt (blau, Tipp = Animation, :659) · Notiz · Pausen-Menü · Schalter "Satz-Zeit" (:602-604) · Defekt (:608) · Einstellung (:609) · Ausweichen (:610) · Tabelle SATZ/VORHER/KG/WDH/RPE/✓ (:698-707) · Sätze · "Satz hinzufügen" (:616). Menü ⋯ (:764). Toast mit Rückgängig `.move(edge:.bottom)+.opacity` (:636), `.animation(.snappy)` (:639). Zeilenfarbe grün 20 % bei fertig (:746). Swipe: kopieren blau, löschen (:747-750). Haken grün (:1025). Rahmen blau beim laufenden Satz (:1068). Anstrengung rot/orange/grün (:1090-1093). | `UebungsKarte` F/Gym/UebungsKarte.swift:5: Kopf mit Bild 48 pt und ⋯-Menü (:77-107) · Defekt · Geräte-Einstellung · `SatzZeile` je Satz · "Satz dazu" + "Rechner" (:45-52). Sätze mit Minus/Plus (`GymSchalter`, GymStil.swift:13) statt Tabelle. Swipe in `SatzWischen` (SatzZeile.swift:148). Rückgängig-Leiste `.move(edge:.bottom)+.opacity` (TrainingLaufView.swift:137). RPE-Farben `AnstrengungBlatt.swift:71-76`: rot/orange. | AUFBAU ANDERS: Lovea Tabelle mit Zahlenfeldern, Lumen Schalter. Gleich: Rückgängig-Toast, Swipe, RPE-Farben. |
| Blätter | `AnstrengungBlatt` WorkoutView.swift:1100, `ScheibenBlatt` :1148, `ZeitenBlatt` GymSession.swift:165, `StartzeitBlatt` :216, `NachtragenBlatt` :505, `UebungsSuche` | `AnstrengungBlatt` F/Gym/AnstrengungBlatt.swift:5, `RechnerBlatt` :5, `NotizBlatt` UebungsKarte.swift:133, `PauseWahlBlatt` :160, `AusweichBlatt` :182, `TagWechselBlatt` TrainingLaufView.swift:180, `TrainingBeendenView` :6, `GymEinstellungenBlatt` TrainingBeendenView.swift:118, `EinheitZeitenBlaetter.swift:5/78/120/194` | Teil GLEICH (Anstrengung, Zeiten, Startzeit, Nachtragen), Teil MEHR in Lumen (Notiz-, Pause-, Tagwechsel-Blatt, Beenden-Blatt, Einstellungen). |
| Pausen-Anzeige | `WorkoutLeiste.zeit` (:76-93): Countdown, danach rot hochzählend | `NaechsterSatzKarte` (F/Gym/NaechsterSatzKarte.swift:6): schwarze Hero-Karte, Zahl 56 pt `.rounded`, nach Ablauf rot (1, 0.42, 0.4) hochzählend (:44-48) | AUFBAU ANDERS (Karte statt Leiste) |
| Beenden | Alerts: "Warst du wirklich so lange…", "Plan aktualisieren?", "Als Trainingstag speichern?", Dialog "Training verwerfen?" (WorkoutView.swift:~150-188) | `TrainingBeendenView` als Blatt (:6, Toggle "Plan so aktualisieren" :93, "Training verwerfen" :35) | AUFBAU ANDERS (Blatt statt Alerts) |

## 4. Plan, Splits

| Ansicht | Lovea | Lumen Fit | Urteil |
|---|---|---|---|
| Eigener Plan / Partner | `TrainingsPlanView` L/TrainingsPlanView.swift:5, `List`: gymSektion (:15, :60) · Zyklus-Hinweis · Studio · "Woche" (`WochenLeiste` :177) · Vorschlag · "Trainingstage" (`TagZeile` :288) · "Plan von Partner" (:35-42). Toolbar "Neuer Tag". Blatt `TagEditor` (:312). Für die eigene Person nicht mehr erreichbar (siehe 2). | Segment "Plan": `PlanView` F/Gym/PlanView.swift:6: Wochenzeilen 1-7 mit Menü (:51-82) · Hinweise (:84) · "Tage" + "Tag hinzufügen" (:~100) · "Mehr": Split-Bibliothek, Eigenen Split anlegen, Übungskatalog (:~125-155). Blätter `PlanTagBlatt` (:27), `SplitBibliothekView` (:28), `SplitFreiBlatt` (:29). | AUFBAU ANDERS: Lovea hat den eigenen Plan nur über Split-Editor (s. u.). Lumen: eigenes Segment. Partner-Plan FEHLT in Lumen. |
| Split-Bibliothek | `SplitBibliothekView` L/GymNeu/SplitAnsichten.swift:163, Push `ziel = .splits` (GymStartView). Reihenfolge: "Geführt erstellen" · "Eigenen Split anlegen" · "Meinen Plan anpassen" (nur wenn Plan da) · "FERTIGE SPLITS FÜR …" · Chips (Art, Tage) · Liste mit `SplitWochenbild` (Kapseln, :25). `.searchable` "Split, Übung oder Muskel". Chips: gewählt `.primary`, sonst `tertiarySystemFill` (:8-22). Animation `Feder.schnell` beim Filtern. | `SplitBibliothekView` F/Gym/SplitBibliothekView.swift:6, als Blatt (`NavigationStack`, Schließen). "Geführt erstellen" · Filter-Chips (`akzent`/`flaeche`) · Liste. `.searchable`. Kein Wochenbild in der Liste. Standard-Filter "fuerdich". | AUFBAU ANDERS: Blatt statt Push; "Eigener Split" liegt in Lumen im Plan, nicht in der Bibliothek; "Meinen Plan anpassen" FEHLT; Wochenbild in der Liste FEHLT. |
| Split-Vorschau | `SplitVorschauView` SplitAnsichten.swift:269, Inhalt :217: Wochenbild · Kürzel · Einheiten mit Übungen (Tipp = `UebungDetail` mit Animation) · "Nur diese Woche testen". Toolbar "Übernehmen" `.semibold`, Dialog "Plan ersetzen". | `SplitDetailView` F/Gym/SplitBibliothekView.swift:87: Wochenzeile mit Häkchen · Einheiten (Supersatz-Link-Symbol) · "Als meinen Plan übernehmen" + "Nur diese Woche testen". | AUFBAU ANDERS: Lumen ohne Übungs-Detail-Link, dafür Supersatz-Symbol; Übernehmen als Zeile statt Toolbar. |
| Geführt | `SplitGefuehrtView` SplitAnsichten.swift:348: Fortschrittsbalken 4 Kapseln (:~375), 3 Fragen, `withAnimation(Feder.schnell)` | `SplitGefuehrtView` F/Gym/SplitGefuehrtView.swift:5; Animation mit `ruhig`-Prüfung (:31, :71) | GLEICH |
| Eigener Split | `SplitFreiView` SplitFreiAnsichten.swift:73 (Push aus Bibliothek) | `SplitFreiBlatt` F/Gym/SplitBibliothekView.swift:166 (Blatt aus Plan "Mehr") | AUFBAU ANDERS (Weg) |
| Split-Editor | `SplitEditorView` L/GymNeu/SplitEditorView.swift:157: Tag-Chips + Plus (:~39), Wochentage (:~64), Übungen aufklappbar mit Steppern, "Übung hinzufügen". Menü ⋯: umbenennen, löschen. Push aus Startseite (Übungsliste antippen) oder Bibliothek. | `PlanTagBlatt` F/Gym/PlanTagBlatt.swift:6 als Blatt: Name · Wochentage · Übungen (Verschieben `onMove` :116, Löschen `onDelete` :111, Swipe :106, Varianten :234) · "Tag löschen" | AUFBAU ANDERS (Blatt, Liste statt Chips) |
| Plantag-Karte | `PlantagKarte` SplitFreiAnsichten.swift:29, Symbol `figure.strengthtraining.traditional`/`moon.zzz` | nicht geprüft | – |

## 5. Verlauf (Trainingstage)

| | Lovea | Lumen Fit | Urteil |
|---|---|---|---|
| Trainingstage | `GymVerlaufView` L/GymSession.swift:261, Weg: Menü ⋯ "Verlauf" (Push) und `VerlaufZiel.training` (VerlaufView.swift:347). Reihenfolge: Picker Ich/Partner (:277) · Kennzahlen Diese Woche / Serie / Gesamt (:285-289) · `MonatsPager` mit `GymMonat` (:291-298) · Einheiten-Liste (:305). Plus-Knopf "Training nachtragen". Monat: Tag gefüllt `Color.blue`, Ring blau (:362-363). | `TrainingVerlaufView` F/Gym/TrainingVerlaufView.swift:6, Push aus "Alle Trainingstage" (GymStartView.swift:250) bzw. `VerlaufZiel.trainingstage` (VerlaufZielSeiten.swift:78). Titel "Trainingstage" (:41). Kennzahlen in `ListenKarte` mit `RollZahl` (:75-81) · Monatsraster in `DiagrammKarte` mit `EinheitMonatsPager` (:~91-100) · "Alle Einheiten" (:~118). Monat grün (`GymFarbe.gruen`, :221). | GLEICH im Aufbau; Partner-Picker FEHLT; Farbe Blau→Grün; Zahlen rollen animiert. |
| Einheit nachlesen | `WorkoutRueckblick` GymSession.swift:406: `List`-Sections: Zeit / Volumen / Sätze / kcal / Puls, dann je Übung Section mit "Sätze bearbeiten" (Push), "Übung hinzufügen". Toolbar "Zeiten". Satznummer orange bei Sonderart (:480). | `EinheitNachlesenView` F/Gym/EinheitNachlesenView.swift:6: Hero-Karte Dauer/Sätze/Volumen (:84-100) · Leerhinweis · Werte-Karte kcal/Puls/Notiz · Übungskarten · "Übung hinzufügen". Toolbar ⋯ (Zeiten ändern, Notiz). Sätze bearbeiten als Blatt `EinheitSaetzeBlatt` (:185). | AUFBAU ANDERS (Hero-Karte, Notiz-Funktion, Blatt statt Push) |
| Nachtragen | `NachtragenBlatt` GymSession.swift:505 | `EinheitNachtragenBlatt` F/Gym/EinheitZeitenBlaetter.swift:120 | GLEICH |

## 6. Verlauf-Seite (Woche / Verlauf / Plan)

| | Lovea | Lumen Fit | Urteil |
|---|---|---|---|
| Name, Weg | `VerlaufView` L/Verlauf/VerlaufView.swift:204; Push `.verlauf` aus Heute-Kasten (HeuteView.swift:500). Ziele per `navigationDestination(for: VerlaufZiel)` (HeuteView.swift:528). | `VerlaufView` F/Fortschritt/VerlaufView.swift:7; Push per `NavigationLink` aus der Link-Liste im Segment Fortschritt (FortschrittSegmentView.swift:59) bzw. `Route.verlauf` | GLEICH im Inhalt, Weg anders |
| Umschalter | Picker Woche/Verlauf/Plan (:215-219) | gleich (:21-25), mit `.animation(Feder.schnell)` beim Wechsel (:34) | GLEICH (Lumen zusätzlich Animation) |
| Woche | `VerlaufZusammenfassung` · `VerlaufStartKnopf` (`Color.loveaRose`, VerlaufWocheAnsichten.swift:65) · `VerlaufHinweis` · Gruppenliste, "Weitere Gruppen" einklappbar (`Feder.schnell`, :82) | Zusammenfassung · Start-Knopf · Hinweis · **Überschrift "Sätze pro Muskel"** + `ListenKarte` (:84-99) · Leerzustand mit Lumi | AUFBAU ANDERS (Überschrift, Karte). Erholungszeichen: Lovea Punkt 8 pt `KoerperFarbe.stufe` (:139), Lumen Form voll/halb/leer in `gruen` (VerlaufWocheAnsichten.swift:115-160). |
| Verlauf | `KonsistenzKarte` (:267) · Highlights · Textlink "Alle Trainingstage" in Rose (:279) | `KonsistenzKarte` · **`KonstanzRasterKarte`** · **`GewichtVerlaufKarte`** · **`StimmungVerlaufKarte`** · Highlights · Knopf "Alle Trainingstage" · **Knopf "Rückblick ansehen"** (:145-171) | Lumen MEHR: 3 Karten und der Rückblick-Knopf |
| Plan | `VerlaufPlan` (VerlaufWocheAnsichten.swift:228), Link "Plan ansehen und ändern" in Rose | `VerlaufPlan` (:288) → `.gym(.plaene)` (VerlaufView.swift:180) | GLEICH |
| Gruppe / Übung | `VerlaufZielSeite` VerlaufView.swift:311, `VerlaufGruppe` :456, `VerlaufUebung` :545 (Zahl groß `.largeTitle.bold`, Klapp "Weitere Statistiken", "Teile diese Woche", "Übungen", e1RM, "Tage") | `VerlaufGruppeSeite` F/Fortschritt/VerlaufZielSeiten.swift:6, `VerlaufUebungSeite` :139, `VerlaufZielAnsicht` :209. Karten statt Trennlinien, `RollZahl`. | GLEICH im Aufbau, Darstellung anders |
| Konsistenz | `KonsistenzKarte` L/Verlauf/KonsistenzKarte.swift:6. Karte immer dunkel (`.environment(\.colorScheme,.dark)` :~58), Farben Karte (0.04,0.04,0.045), Rosa (0.941,0.376,0.620) (:170-178). Titel englisch "Training Consistency", "All time". Paletten-Knopf, Jahres-Menü, Legende, Detail, Raster. Blatt `KonsistenzKategorienBlatt` (:46). | F/Fortschritt/KonsistenzKarte.swift:38. `DiagrammKarte` mit `palette`, Titel "Konsistenz", Standardfarbe `GymFarbe.gruen`, Wortlegende. Sonst gleiche Reihenfolge (:95-132). Blatt (:77). | GLEICH im Aufbau; Farbe (Rosa/schwarz → Grün/Palette) und Sprache anders. |

## 7. Körper

| | Lovea | Lumen Fit | Urteil |
|---|---|---|---|
| Körper-Seite | `KoerperView` L/Koerper/KoerperView.swift:398 (Titel "Körper", Toolbar "Ziele"), Inhalt `KoerperInhalt` :431: 1 `Streifen` (:500) · 2 Bilanz (:450) · 3 `KoerperKarte` Figur vorne/hinten, 300 pt (KoerperKarte.swift:43, :~75) · 4 Ziel-Karte (:466) · 5 "Sätze diese Woche", 3×3 `Feld` (:457, :594) · 6 `naechstesKarte` (`PushKarte`, :486) | Segment Fortschritt `FortschrittSegmentView` F/Fortschritt/FortschrittSegmentView.swift:12: 1 `KoerperWochenLeiste` (:22) · 2 `NaechstesTrainingKarte` + `KraftKurveKarte` (:24-25) · 3 `ZielFestlegenKarte` (:31) · 4 `SaetzeFelderKarte` (:32) · 5 `SaetzeProMuskelKarte` (:34) · 6 `SilhouetteKarte` (:35) · 7 Link-Liste: Verlauf, Messungen, Rückblick, Meilensteine, Lumi (:36, :52-69). Toolbar "Ziele" (:42-45). | AUFBAU ANDERS: Reihenfolge (Nächstes Training und Kraftkurve vor den Feldern, Silhouette ganz unten statt Figur oben); Lumen ohne Bilanz-Text als eigene Zeile (in `KoerperWochenLeiste`); mehr Karten. |
| Wochenstreifen | `Streifen` KoerperView.swift:500: Haken grün `KoerperFarbe.erholt` (:569), `.heavy`-Haken (:570), Ring Rose (`loveaRose`, 2 pt, :558), kommt grau 45 %, verpasst gestrichelt (:559-560) | `KoerperWochenLeiste` F/Fortschritt/KoerperWochenLeiste.swift:7, "Zustand in Form und Füllung, nie nur Farbe" (:4) | GLEICH im Konzept |
| Farben | `KoerperFarbe` KoerperView.swift:381-386: erholt 30D158, fast FF7A59, müde `loveaRose`. Felder: Füllung `farbe.opacity(0.2)`, Strich 1,5 pt oben, Aufbau-Animation `Feder.weich.delay(index·0.035)` (:58-61). | Silhouette: Muster statt Farbe (`SilhouetteStufe`, SilhouetteKarte.swift:~100, `SilhouetteProbe` SilhouetteKarte.swift:181); Diagramme `LumenFarben.tief(.trainieren)` | AUFBAU ANDERS |
| Ziel-Karte | `PushKarte` (:666): Rose-Verlauf `loveaRose` 0.2→0.05 (:720), Radial 0.34 (:721), Rahmen Rose 24 % (:714), Knopf weiß (:704) | `ZielFestlegenKarte` F/Fortschritt/SaetzeFelderKarte.swift:27 (`HeroKarte`, Knopf `palette.akzent`) | GLEICH im Inhalt, Optik anders |
| Muskel-Blatt | `KoerperBlatt` L/Koerper/KoerperBlatt.swift:6 als Blatt `.medium/.large` mit Indikator (HeuteView.swift:530-534; KoerperView.swift:421). Kopf: Mini-Figur 132 pt, Name `.system(28,.bold)`, Zahl 36 pt bold, Erholungsquadrat. Dann "Teile diese Woche", "Übungen" (aufklappbar `Feder.weich`, :155). "Nächstes Mal" Rose 12 % (:206). | `KoerperBlatt` F/Fortschritt/KoerperBlatt.swift:38, Hülle `KoerperBlattView` :13. Gleiche Reihenfolge (:68-79). Name `.title.bold.rounded`, Zahl `RollZahl`, `.haptik(.auswahl)` beim Aufklappen. | GLEICH (Aufbau und Weg: Tipp auf Feld/Figur → Blatt) |
| Messungen | `MessungenView` L/Koerper/Messungen.swift:51: Picker Ich/Partner + Messart · Wert groß + `Chart` (`LineMark`+`PointMark`, ohne Farbe, 180 pt) · "Historie". Toolbar "Messung erfassen". Weg: GymStart-Menü :387, Plan :113. | F/Fortschritt/MessungenView.swift:7: Messart-Picker · Karte Wert + Änderung (`RollZahl`, `LumenFarben.tief(.bewegen)`, `.monotone`, Endpunkt 90 pt) · "… Historie" in `ListenKarte`. Weg: Fortschritt-Liste (FortschrittSegmentView.swift:61). | AUFBAU ANDERS; Partner-Picker FEHLT; Weg anders |
| Messung erfassen | `MessungBlatt` Messungen.swift:114 | `MessungBlatt` MessungenView.swift:139, mit Toast "Gespeichert" | GLEICH |
| Ziele-Befragung | `ZieleBefragung` Koerper/ZieleBefragung.swift:48, 3 Fragen, `.animation(Feder.schnell)` (:23) | `ZieleBefragungView` F/Profil/ZieleBefragung.swift:~97 (Blatt aus Fortschritt :49 und `ZieleView.swift:36`) | GLEICH; Lumen hat zusätzlich den Weg aus dem Profil |

## 8. Funktionen, die Lumen Fit mehr hat (im Bereich)

| Funktion | Datei:Zeile (Lumen) |
|---|---|
| Cardio-Schnellknöpfe auf der Startseite (Laufband, Stairmaster) | Gym/GymStartView.swift:56-66 |
| Einstellungen fürs Training als Blatt | GymStartView.swift:67, TrainingBeendenView.swift:118 |
| Letzte Einheiten (5) mit Direktsprung ins Nachlesen | GymStartView.swift:228 |
| Studio-Karte mit Besuche/Serie und Einchecken, erreichbar | Gym/StudioKarte.swift:6 |
| "Nach 1,5 Stunden" beim vergessenen Auschecken | GymStartView.swift:150 |
| "Anderer Tag" statt Plantag (heute Beine statt Push) | GymStartView.swift:~137-148 |
| Hero-Karte "Nächstes Training" mit Zeitwahl 30/45/60/90 | Fortschritt/NaechstesTrainingKarte.swift:9-50 |
| Kraftkurve | Fortschritt/KraftKurveKarte.swift:30 |
| Sätze pro Muskel (Balken) | Fortschritt/SaetzeProMuskelKarte.swift:6 |
| Silhouette mit Seitenwahl und gruppierter Legende | Fortschritt/SilhouetteKarte.swift:51 |
| Konstanz-Raster, Gewichtsverlauf, Stimmungsverlauf im Verlauf | Fortschritt/VerlaufView.swift:146-154 |
| Rückblick (teilbar), Meilensteine, Lumi-Seite, Fit-Passport | Fortschritt/RueckblickView.swift:4, MeilensteineView.swift:4, LumiSeiteView.swift:4, FitPassportKarte.swift:39 |
| Übungs-Detailseite mit Reitern Übersicht/Historie/So geht's, Route `.uebung(id)` | Gym/UebungDetailView.swift:8, :22 |
| Eigene Übungen anlegen | Gym/GymEigenesFormular.swift:5, GymEigeneUebung.swift |
| Supersatz, "Gerät besetzt: tauschen", Notiz je Übung, Pause je Übung als Blätter | Gym/UebungsKarte.swift:82-96, :133, :160, :182 |
| Übungskatalog mit Filterblatt | Gym/UebungsSucheView.swift:6, :220 |
| Cardio-Abschlussblatt | Gym/CardioView.swift:76 |
| Puls-Messung live (Band/Uhr) | Gym/GymPulsMessung.swift, TrainingLaufView.swift:111 |
| Rückgängig-Leiste 5 s für gelöschte Sätze | TrainingLaufView.swift:124-143 |
| Tipps (TipKit-Ersatz `gymTipp`) | Gym/GymTipps.swift |
| `RollZahl` und Bewegung-aus-Prüfung (`ruhig`/`bewegungAus`) durchgängig | z. B. TrainingVerlaufView.swift:78, SplitGefuehrtView.swift:31 |

## 9. Lovea hat, Lumen fehlt (Bereich)

| Funktion | Datei:Zeile (Lovea) | Urteil |
|---|---|---|
| Partner-Plan, Partner-Verlauf, Partner-Messungen, Zeile "Du/Partner" | TrainingsPlanView.swift:35, GymSession.swift:276, Messungen.swift:61, GymStartView.swift:110 | FEHLT (bewusst, Lumen ist Einzelperson) |
| "Meinen Plan anpassen" in der Bibliothek, Wochenbild je Split | SplitAnsichten.swift:77, :25 | FEHLT |
| Übungsliste und Split-Zeile direkt auf der Startseite | GymStartView.swift:97-105 | FEHLT |
| Körper-Kasten in Heute, Verlauf-Kasten, PlantagKarte oben | HeuteView.swift:472, :499-500 | FEHLT (nicht gelesen, ob Lumen ähnliches anders hat) |
| Menü "Freies Training" auf der Startseite | GymStartView.swift:369 | in Lumen als Eintrag in "Anderer Tag" (GymStartView.swift:~146) |
| Kopieren-Swipe nach rechts (blau) | WorkoutView.swift:747-748 | in Lumen `SatzWischen` mit `kopieren` (SatzZeile.swift:148) – GLEICH |

## Offene Punkte
- Zeilennummern mit "~" sind aus Teilausschnitten geschätzt, nicht einzeln geprüft.
- Nicht verglichen: Lovea `Muskeln`/`MuskelKarte`/`Messungen`-Logik, `GymLive`, `WochenAbweichung`, Lumen `Rechner`/`CardioView`, die Heute-Seiten beider Apps.

## Teil B: Heute, Schlaf, Zyklus, Energie, Habits

Abkürzungen:
- **L** = `/home/tobi/code/lovea-app-ios/Lovea/Sources/Health`
- **F** = `/home/tobi/projects/lumen-fit-ansicht/LumenFit/Sources/Module`
- **FA** = `/home/tobi/projects/lumen-fit-ansicht/LumenFit/Sources/App`
- **FD** = `/home/tobi/projects/lumen-fit-ansicht/LumenFit/Sources/Design`

## 0. Grundaufbau und Wege

| Thema | Lovea | Lumen Fit | Urteil |
|---|---|---|---|
| Wurzel | 5 Tabs Home/Chat/Drawing/Health/MySpace, Health = `HeuteView` (`App/AppRootView.swift:166-181`) | 5 Tabs Heute/Gym/Essen/Schlaf/Coach (`FA/LumenFitTab.swift:4`) | AUFBAU ANDERS |
| Schlaf, Essen, Coach liegen | Seiten im Stack des Health-Tabs, per Push (`L/Heute/HeuteView.swift:466`, `:526-528`) | eigene Tabs (`FA/RouteAnsicht.swift:41-45`); `Router.oeffne` schaltet den Tab um (`FA/Router.swift:14-26`) | AUFBAU ANDERS |
| Ziele | `HealthZiel` (`L/HealthTab.swift:4`), `HeuteZiel` (`HeuteView.swift:419`) | `Route` + `LumenFitTab.fuer` (`FA/LumenFitTab.swift:29`) | AUFBAU ANDERS |
| Aufbau-Schalter | – | `LumenAufbau` `.lumen`/`.lovea` (`FD/LumenAufbau.swift:6`), WIP, noch ohne Leser | Lumen-Extra |
| Kartenfarbe | `healthKarte(farbe)`: Fläche + `farbe.opacity(0.14)` (`L/HealthStil.swift:42-54`) | `lumenKartenFlaeche` + `kartenTint` (`FD/LoveaKarte.swift:21-45`), nur im Thema Lovea, gesetzt nur in `FA/RouteAnsicht.swift:11-13` (Essen/Schlaf/Coach), nicht für Heute | AUFBAU ANDERS |
| Federn | `Feder` (`L/../App/Feder.swift:7-30`): schnell, weich, federnd, jelly | `FD/Feder.swift` (Datei vorhanden, Werte nicht verglichen) | nicht geprüft |

## 1. SCHLAF

### 1a. Ansichten in Lovea und Gegenstück

| Lovea-Ansicht (Datei:Zeile) | Weg dorthin (Datei:Zeile) | Lumen-Gegenstück | Urteil |
|---|---|---|---|
| `SchlafDetailView`, Titel "Schlaf" (`L/SchlafCard.swift:81`, `:136`) | Raster-Kachel "Schlaf" (`HeuteView.swift:803-808`, `:769`) → `pfad.append(HeuteZiel.schlaf)` → `HeuteView.swift:701` (Push). Auch: Coach-Zeile oder Schlafkarte → `HealthZiel.schlaf(tag)` (`L/HealthTab.swift:32`, `Coach/CoachTracking.swift:178`, `Coach/CoachAntwortTeile.swift:~258` `NavigationLink`) | `SchlafTabView` (`F/Schlaf/SchlafTabView.swift:22`), eigener Tab, kein Push | AUFBAU ANDERS: Tab statt Push |
| `SchlafEintragenView` (`L/EnergieKarte.swift:144`) | Blatt: `.sheet(item:)` (`SchlafCard.swift:90`); Knopf "Nacht nachtragen" `plus` (`:86-88`), "Schlaf eintragen"/"Nacht korrigieren" (`:171`), Nachtzeile antippen (`:223`) | `SchlafEintragenView` (`F/Schlaf/SchlafEintragenView.swift:6`), Blatt (`SchlafTabView.swift:77`), Knopf `plus` links (`:72-74`) | GLEICH (Blatt) |
| Schlafziel als Karte in der Detailseite (`SchlafCard.swift:316`, Stepper 360-600, Extra-Tage) | scrollt in der Detailseite mit (`:112`) | `SchlafZielView` (`SchlafEintragenView.swift:117`), Push über Zeile "Schlafziel" (`SchlafTabView.swift:154-158`) | AUFBAU ANDERS: eigene Seite statt Karte |
| Wecker-Seite `WeckerSeite` (`L/Wecker/WeckerSeite.swift`), Zeile `WeckerZeile` (`:253`) | `SchlafCard.swift:111` und `HealthZiel.wecker` (`HealthTab.swift:14`, `:33`) | keine Wecker-Ansicht (keine `struct Wecker*` in `FA`/`F`) | FEHLT |
| Erinnerungen (`ErinnerungenSeite`) | `HealthZiel.erinnerungen` (`HealthTab.swift:16`, `:34`) | keine | FEHLT |

### 1b. Reihenfolge `SchlafDetailView` (Lovea `SchlafCard.swift:108-116`) gegen `SchlafTabInhalt` (Lumen)

| # | Lovea | Lumen | Urteil |
|---|---|---|---|
| 1 | `letzteNacht`-Karte (`SchlafCard.swift:146`): Label "Letzte Nacht", `SchlafNachtLader`+`SchlafNachtDiagramm` (`:~152`), Dauer 34pt, Bett-Zeiten, Quelle, "Stimmt das?" (Punktesystem), Wach-Lücken, Nickerchen, Soll, Schuld, Koffein nach 16 Uhr, Wochenschnitt, Knopf eintragen | `SchlafCard` Heldenkarte (`F/Schlaf/SchlafCard.swift:4`, `:98`): Dauer 56pt, von/bis, Ziel, Lumi, Wach/Nickerchen (`:69-76`) | AUFBAU ANDERS: Hero statt Karte; "Stimmt das?", Koffein-Satz und Eintragen-Knopf in der Karte fehlen; Schuld in eigener Karte (#6) |
| 2 | `SchlafVergleichKarte` (`SchlafCard.swift:109`; "Unsere Schätzung vs Uhr", `L/SchlafVergleichKarte.swift:20`) | `SchlafVergleichKarte` (`F/Schlaf/SchlafVergleichKarte.swift:6`), "Band und Health im Vergleich", nur in `SchlafNachtDetailView.swift:17-19` (Push) | AUFBAU ANDERS: Karte wandert in Detail; Vergleichsquellen andere |
| 3 | `hinweisOhneAutomatik` → `SchlafGenauerHinweis` (`:134`, `:354`) | – | FEHLT |
| 4 | `WeckerZeile()` (`:111`) | – | FEHLT |
| 5 | `SchlafCard` "Ihr beide" (`:5-24`; Wochenbalken `:45-73`) | `SchlafDoppelKarte` (`F/Verbinden/Ansichten/SchlafDoppelKarte.swift:6`, `SchlafTabView.swift:56`) am Ende; nur mit Partner und Freigabe | AUFBAU ANDERS: Reihenfolge (Lumen ganz unten, Lovea Mitte) |
| 6 | `schlafZielKarte` (`:316`) | `ListenKarte "Schlafziel"` als Link (`SchlafTabView.swift:154`) | AUFBAU ANDERS |
| 7 | `naechte` "Letzte 7/30 Nächte" mit Knopf "Alle 30 Nächte zeigen" (`:228-250`) | `SchlafVerlaufView` (`F/Schlaf/SchlafVerlaufView.swift:4`), Push über `Route.schlaf(.verlauf)` (`SchlafTabView.swift:160`); Picker 7/30/alle (`:54`), Zeile klappt auf: Details/Korrigieren (`:96-135`) | AUFBAU ANDERS: eigene Seite, Picker statt Knopf |
| 8 | `leistung` "Schlaf und Training", Bedingung ≥3 Punkte (`:296-313`) | `SchlafLeistungKarte` (`F/Schlaf/SchlafLeistung.swift:42`), im Tab (`SchlafTabView.swift:129-136`) | GLEICH (Bedingung ≥3), Position anders (Lumen vor dem Verlauf-Link) |
| – | – | `phasen` DiagrammKarte "So hast du geschlafen" (`:99`, `:138`) | Lumen mehr |
| – | – | "Woche" Säulen + Wochenvergleich (`:108-111`, `F/Schlaf/SchlafWochenKarte.swift:5`, `:112`) | Lumen mehr |
| – | – | "Erholung" HRV-Karte `SchlafBereichKarte` (`:114-116`, `F/Schlaf/SchlafWerteKarten.swift:67`) | Lumen mehr |
| – | – | "Werte" Chips (`:117-118`, `SchlafWerteKarten.swift:12`) | Lumen mehr |
| – | – | "Schuld und Rhythmus" `SchlafSchuldKarte`, `SchlafRegelKarte` (`:122-126`, `SchlafWerteKarten.swift:139`, `:168`) | Lumen mehr (Lovea: Schuld nur als Textzeile, Regelmäßigkeit fehlt) |
| – | – | Zeile "Quelle: …" → `SchlafNachtDetailView` (`:148-152`, `F/Schlaf/SchlafNachtDetailView.swift:5`): Phasen-Diagramm, Zeiten, Quelle, Vergleich | Lumen mehr |
| – | – | `PartnerKarte(.schlaf)` (`:57`) | Lumen mehr |
| – | – | Leerzustand mit "In Health prüfen" und Ladehinweis (`:185-195`) | Lumen mehr |

### 1c. Diagramme und Bewegung, Schlaf

| Element | Lovea | Lumen | Urteil |
|---|---|---|---|
| Nacht-Phasen | Swift Charts `RectangleMark`, Farben: Wach `.orange`, REM `HabitFarbe.himmel`, Kern `.indigo`, Tief indigo+schwarz 0.4, Unbestimmt indigo 0.45 (`L/SchlafNachtDiagramm.swift:19-27`, `:34-39`), Kapsel-Legende mit Kreisen (`:64-73`) | `Canvas` ohne Charts, Farbe nur `LumenFarben.tief(.erholen)` 0x00699E/0x00E0F0 (`FD`-Quelle `Gemeinsam/Design/Farben.swift:80-84`) plus Muster (Tief voll, Kern senkrecht, REM schräg, Wach Punkte; `F/Schlaf/PhasenBalken.swift:7-31`); `SchlafNachtDiagramm` `F/Schlaf/SchlafNachtDiagramm.swift:5`; Phasenbalken `PhasenBalken.swift:83` | AUFBAU ANDERS (Farbe vs Muster, bewusst) |
| Wochenbalken | `Capsule` 7pt breit, Person-Farben, leer = `farbe.opacity(0.15)` (`L/SchlafCard.swift:45-73`) | `SchlafSaeulen` `Canvas`, `linie` oder `.opacity(0.3)`+Schraffur bei <6 h; wächst mit `withAnimation(Feder.weich)` (`F/Schlaf/SchlafWochenKarte.swift:73`, `:94`) | AUFBAU ANDERS |
| Leistung | `PointMark` `.foregroundStyle(farbe)` indigo, `symbolSize(70)`, `RectangleMark` Fläche `farbe.opacity(0.08)` unter 6 h, `RuleMark` gestrichelt 6 h (`L/Heute/HeuteView.swift:339-364`) | `PointMark` `palette.text`, `symbolSize(60)`, keine Fläche/Regel (`F/Schlaf/SchlafLeistung.swift:48-52`) | AUFBAU ANDERS |
| Karte-Tönung | indigo 14 % (`SchlafCard.swift:23`, `:180`) | `kartenTint(indigo)` (`FA/RouteAnsicht.swift:12`), nur Thema Lovea | GLEICH im Thema Lovea |
| Symbolgewichte | Kopf-Label `.headline`; `chevron` `.footnote.weight(.semibold)`; Zeit `.font(.system(.largeTitle, design:.rounded).weight(.bold))` (`:123`) | Hero `.system(size:,weight:.bold,design:.rounded)` (`F/Schlaf/SchlafCard.swift:48`); `symbolRenderingMode(.hierarchical)` in Chips (`SchlafWerteKarten.swift:33`) | Lumen mehr |
| Bewegung | `withAnimation(Feder.schnell)` beim "Alle 30 Nächte" (`SchlafCard.swift:241`); sonst keine | Säulen wachsen (`SchlafWochenKarte.swift:73`), Verlauf-Zeile `.transition(.opacity.combined(with: .move(edge: .top)))` und Chevron dreht 180° (`SchlafVerlaufView.swift:107-114`, `:147`), Picker `.animation(Feder.schnell)` (`:54`), `contentTransition(.numericText())` bei Dauer (`SchlafEintragenView.swift:55`) | Lumen mehr |

## 2. ESSEN

### 2a. Ansichten

| Lovea-Ansicht (Datei:Zeile) | Weg dorthin (Datei:Zeile) | Lumen-Gegenstück | Urteil |
|---|---|---|---|
| `ErnaehrungView`, Titel "Food" (`L/Ernaehrung/ErnaehrungView.swift:50`, `:106`) | Raster-Kachel "Food" (`HeuteView.swift:926-937`, im Raster `:773`) → `HeuteZiel.ernaehrung` (`:709`), Push. Auch Coach-Zeile → `HealthZiel.ernaehrung` (`HealthTab.swift:35`), Live-Activity-Link (`ErnaehrungView.swift:~157`) | `EssenTabView`, Titel "Essen" (`F/Essen/EssenTabView.swift:18`, `:55`), eigener Tab | AUFBAU ANDERS |
| Toolbar | `barcode.viewfinder` (`ErnaehrungView.swift:108-113`) + Menü `ellipsis` (`:115-134`): Ziele, Auswertung, Nährwerte des Tages, Intervallfasten, Tagebuch anpassen, "Tag von Annika" | Menü `ellipsis` (`EssenTabView.swift:198-209`): Ziele, Auswertung, Nährwerte, **Wochenanalyse**, Intervallfasten, Tagebuch anpassen. Scan als schwebender Glas-Knopf unten rechts (`:288-299`, Overlay `:132`) | AUFBAU ANDERS; Partner-Tag FEHLT |
| `MahlzeitView` (`ErnaehrungMahlzeit.swift:11`) | Push `navigationDestination(item:)` (`ErnaehrungView.swift:136`) | `EssenMahlzeitSeite` (`F/Essen/EssenMahlzeitSeite.swift`), Push (`EssenTabView.swift:61`) | GLEICH |
| `MahlzeitenUebersicht` (`ErnaehrungMahlzeit.swift:83`) | Push, "Mehr" bei "Ernährung" (`ErnaehrungView.swift:139`) | `EssenMahlzeitenUebersicht` (`:62`) | GLEICH |
| `TagesNaehrwerteView` (`TagesNaehrwerte.swift:7`) | Push (`ErnaehrungView.swift:141`) | `EssenTagesNaehrwerteView` (`:63`) | GLEICH |
| `ErnaehrungAnalyseView`, "Analyse" (`ErnaehrungAnalyse.swift:140`, `:177`) | Push (`ErnaehrungView.swift:140`) | `EssenAuswertungView`, Titel "Auswertung" (`F/Essen/EssenAuswertungView.swift:23`) | GLEICH (Titel anders) |
| `FastenView` (`FastenView.swift:8`) | Push (`:142`) | `EssenFastenView` (`F/Essen/EssenFastenView.swift:22`) | GLEICH |
| `ErnaehrungZieleView`, Titel "Ziele" (`ErnaehrungZiele.swift:5`, `:75`) | **Blatt** (`ErnaehrungView.swift:~148`) | `EssenZielDetailView` (`F/Essen/EssenZielDetailView.swift:82`), **Push** (`EssenTabView.swift:66`) | AUFBAU ANDERS: Blatt vs Push |
| `TagebuchAnpassenBlatt` (`ErnaehrungView.swift:665`) | Blatt (`:143`) | `EssenTagebuchAnpassenBlatt` (`:57`) | GLEICH |
| `KoerperwerteBlatt` (`ErnaehrungKoerper.swift:5`) | Blatt (`:~148`) | `EssenKoerperwerteBlatt` (`:58`) | GLEICH |
| Datums-Blatt (`kalenderBlatt`, Detents `.medium/.large`; `:~235`) | Blatt, Tipp auf Titel (`:~149`) | `EssenDatumBlatt` (`:56`) | GLEICH |
| `HinzufuegenBlatt` (`ErnaehrungHinzufuegen.swift:6`) | Blatt (`ErnaehrungView.swift:144`) | `EssenHinzufuegenView` (`:~70`, `EssenHinzufuegenView.swift:94`) | GLEICH |
| `BarcodeScannerBlatt` (`BarcodeScanner.swift:8`) / `KiFotoBlatt` (`KiFoto.swift:136`) / `NaehrwertFotoBlatt` (`NaehrwertFoto.swift:58`) | Blatt | `ScanView` (`F/Essen/ScanView.swift:85`), `EssenKiFotoBlatt` (`:131`), `NaehrwertFotoView` (`:50`) | GLEICH |
| `LebensmittelDetailView` (`LebensmittelDetail.swift:7`), `EigenesLebensmittelEditor`, `RezeptEditor`, Portionsbeispiele | Push/Blatt | `EssenDetailView` (`:69`), `EssenEigenesView` (`:149`), `EssenRezeptEditor`, `EssenPortionsBeispiele` (`:48`), `EssenGerichtView` (`:68`), `EssenMehrtreffer`, `EssenSchnellEintragen` | GLEICH, Lumen mehr (`EssenGerichtView`) |
| Partner-Ansicht (`partnerAnsicht` Toggle, `ErnaehrungView.swift:~126`) | Menüpunkt | – | FEHLT |
| `EssenLiveVorschlagCard` (`ErnaehrungView.swift:12`, `:81-88`) / `AnalyseRueckgaengigLeiste` (`:143`) | oben bzw. unten eingehängt | `EssenLiveModul.swift`, `EssenLiveDienst.swift` vorhanden; Karte/Leiste nicht im Tab | nicht gefunden, vermutlich FEHLT |
| – | – | `WochenanalyseView` (`F/Essen/WochenanalyseView.swift:83`), Push (`EssenTabView.swift:67`) | Lumen mehr |

### 2b. Reihenfolge im Tagebuch

| # | Lovea (`TagebuchAnsicht` `ErnaehrungView.swift:296`; Abschnitte aus `TagebuchAnpassung.standard` `Ernaehrung.swift:343-345`) | Lumen (`EssenTabView.swift:104-131`) | Urteil |
|---|---|---|---|
| 1 | `EssenAnalysenAbschnitt` (KI-Aufträge, `ErnaehrungView.swift:81-83`) | – (steht nach dem Kopf) | AUFBAU ANDERS |
| 2 | `EssenLiveVorschlagCard` (`:84-92`) | – | FEHLT |
| 3 | Kopf: Titel, "Woche N", Pfeile `chevron.left/right` (`:374`) | `EssenTagesKopf` (`:108`) | GLEICH |
| 4 | – | `EssenKiAnalysenAbschnitt` (`:110`) | Reihenfolge anders |
| 5 | "Übersicht" (`:321`, Ring `:435`, Makros `:458`) | `case "uebersicht"` (`:139`), `EssenUebersichtKarte` | GLEICH |
| 6 | "Ernährung" + Mehr (`:331`, Zeilen `:499`) | `case "ernaehrung"` (`:155`) | GLEICH |
| 7 | "Wasserzähler" (`:337`, `:558`) | `case "wasser"` (`:163`, `EssenWasserKarte`) | GLEICH |
| 8 | "Körperwerte" + Mehr (`:341`, `:620`) | `case "koerper"` (`:171`) | GLEICH |
| 9 | – | `LeerZustand` oder `donutKarte` "Makros heute" (`:112-116`, `:242`) | Lumen mehr |
| 10 | – | `proteinKarte` Wochen-Protein (`:118`, `:254`) | Lumen mehr |
| 11 | – | `EssenFastenKarte` (`:119`) | Lumen mehr |
| 12 | – | `favoritenAbschnitt` (`:120`, `:263`) | Lumen mehr |
| 13 | – | `EssenZielKarte` (`:121`) | Lumen mehr |

Die Abschnittsreihenfolge ist in beiden Apps per `anpassung.sichtbar` einstellbar.

### 2c. Diagrammfarben, Gewichte, Bewegung, Essen

| Element | Lovea | Lumen | Urteil |
|---|---|---|---|
| Ring und Balken | YAZIO-Mint `ErnaehrungStil.akzent` `Color(0.13,0.86,0.66)` (`ErnaehrungView.swift:41`); Ring `.orange` bei Drüber (`:445`), Linie 10pt, Bogen 0.75 (`:440-446`) | `palette.aufAkzent` (`F/Essen/EssenUebersichtKarte.swift:50-56`), bei Drüber gestrichelt `dash:[2,14]` statt Orange; Mint nur als Kartenfläche im Thema Lovea (`FD/LoveaKarte.swift:19`) | AUFBAU ANDERS |
| Mahlzeit-Ring | `.stroke(akzent)` 4pt (`ErnaehrungView.swift:511`) | `palette.akzent` 4pt (`EssenMahlzeitenAbschnitt.swift:37-41`) | GLEICH (Farbe themenabhängig) |
| Wasser | Flasche `ErnaehrungStil.wasser` (0.35,0.72,1); `waterbottle(.fill)`, `plus.circle.fill` (`:589-592`) | `palette.akzent`; gleiche Symbole (`EssenWasserKarte.swift:49-51`) | AUFBAU ANDERS (Farbe) |
| Makro-Donut | Analyse `SectorMark` `farbe`, `farbe.opacity(0.65)` … (`ErnaehrungAnalyse.swift:270-271`, `:254-256`) | `MakroDonut`: Grautöne `palette.text.opacity(1-grau*0.75)` plus Muster-Bild (`F/Essen/MakroDonut.swift:63-83`); Auswertung `SectorMark` `palette.text.opacity(m.deckkraft)` (`EssenAuswertungCharts.swift:97-98`) | AUFBAU ANDERS (Muster statt Farbe, bewusst) |
| Kalorien-Chart | `BarMark` `farbe` (Mint), `RuleMark` Ziel (`ErnaehrungAnalyse.swift:217-222`) | `BarMark` `palette.text.opacity(0.85)`, `RuleMark` (`EssenAuswertungCharts.swift:67-72`) | AUFBAU ANDERS |
| Gewicht und Körper | `LineMark`+`PointMark` `farbe` (`ErnaehrungAnalyse.swift:387-390`, `:427-430`) | `LineMark`+`PointMark` `palette.text` (`EssenAuswertungCharts.swift:121-124`) | AUFBAU ANDERS |
| Fasten | Balken `akzent` (geschafft) / `.orange` (`FastenView.swift:180`); Ring 14pt `akzent` (`:84-110`) | Balken `palette.akzent` / `palette.text2.opacity(0.6)` (`EssenFastenView.swift:251`); Ring 14pt `palette.akzent` (`:157-160`) | AUFBAU ANDERS (Orange fehlt) |
| Mahlzeit-Kalorien | `BarMark` `farbe` (`TagesNaehrwerte.swift:137-138`) | `BarMark` `palette.text.opacity(0.75)` (`EssenTagesNaehrwerteView.swift:125`) | AUFBAU ANDERS |
| Schriftgewichte | `.title2.weight(.heavy)` Überschriften (`:260`), `.largeTitle.weight(.black)` Tag (`:383`), `.fontDesign(.rounded)` (`:309`) | `.title2.weight(.heavy)` + `.fontDesign(.rounded)` (`EssenTabView.swift:~143`) | GLEICH |
| Tageswechsel | `.transition(.push(from:))` + `withAnimation(Feder.weich)` (`:105`, `:178`); Reduce Motion: `.opacity` | gleich (`EssenTabView.swift:126`, `:217`, `:225`) | GLEICH |
| Zahlen | `contentTransition(.numericText)` bei Mahlzeit-kcal (`:522`), `TagesNaehrwerte.swift:38` | `.numericText` (`EssenMahlzeitenAbschnitt.swift:52`, `EssenMahlzeitenUebersicht.swift:64`, `EssenKoerperKarte.swift:20`) | GLEICH |
| Auswertung-Aufbau | Charts wachsen nicht | `gezeichnet`-Flag: Charts wachsen mit `Feder.weich` (`EssenAuswertungView.swift:28`, `EssenAuswertungCharts.swift:67`, `EssenFastenView.swift:64`, `:250`) | Lumen mehr |
| KI-Analysen | `.transition(.opacity)`, `.animation(Feder.weich)` (`EssenAnalysenView.swift:28-33`, Leiste `.move(edge:.bottom)` `:230`) | `EssenKiSchritte.swift:30` `.animation(Feder.weich)` | nicht verglichen |

## 3. COACH

### 3a. Ansichten

| Lovea (Datei:Zeile) | Weg dorthin (Datei:Zeile) | Lumen (Datei:Zeile) | Urteil |
|---|---|---|---|
| `CoachChatView`, Titel `modell.name` (`L/Coach/CoachChatView.swift:145`, `:187`) | Raster-Kachel `CoachFormKachel` (`HeuteView.swift:772`; `CoachChatView.swift:16`, `NavigationLink(value: HealthZiel.coach)` `:28`), Push. Sicherheits-Zeile `CoachKachel` (`HeuteView.swift:490`; `CoachChatView.swift:61-70`). Mitteilung: `HeuteView.swift:566-569` | `CoachChatView` (`F/Coach/CoachChatView.swift:4`) in `CoachTabView` (`F/Coach/CoachTabView.swift:5`), Tab; `CoachKachelView` in Heute (`HeuteTabView.swift:93`, `F/Coach/CoachKachelView.swift:20`, Tippen → `router.oeffne(.coach)` `:66`) | AUFBAU ANDERS: Tab statt Push |
| Pause | Vollansicht `pauseAnsicht` mit Toggle Morgen-Nachricht (`:314-336`); Kachel "Pausiert" weckt (`:21-23`) | `pauseLeiste` (`:310`); Kachel weckt (`CoachKachelView.swift:61-64`) | AUFBAU ANDERS |
| Menü `ellipsis` (`:265-310`): Suchen, Angeheftet, Verlauf, Verlauf teilen, Ton, Name ändern, Mein Ziel, Gedächtnis und Training, Erinnerungen entfernen, Pause, Verlauf ausblenden | `topBarTrailing` | Menü `ellipsis.circle` `topBarLeading` (`:121-143`): Suchen, Verlauf, Gedächtnis, Gemerkte Antworten, Mein Ziel, Ton, Morgen-Check, Pause, Verlauf ausblenden, Einstellungen | AUFBAU ANDERS: "Verlauf teilen" und "Name ändern" fehlen im Menü (Export liegt in `CoachLokal.swift:149`); Lumen mehr: Morgen-Check-Schalter |
| `CoachSucheBlatt` (`CoachBlaetter.swift:6`) | Blatt (`:224`) | `CoachSucheBlatt` (`F/Coach/CoachBlaetter.swift:39`), Blatt in `CoachBlattAnsicht` (`:10`) | GLEICH |
| `CoachGemerktBlatt` (`:99`) "Angeheftet" | Blatt (`:228`) | `CoachMerklisteView` (`:78`) "Gemerkte Antworten" | GLEICH (Name anders) |
| `CoachGedaechtnisBlatt` (`CoachGedaechtnisAnsicht.swift:173`) | Blatt (`:229`) | `CoachGedaechtnisAnsicht` (`F/Coach/CoachGedaechtnisAnsicht.swift:4`) | GLEICH |
| `CoachEinstellungenBlatt` (`CoachEinstellungenView.swift:82`) | Blatt (`:230`) | `CoachEinstellungenView` (`F/Coach/CoachEinstellungenView.swift:4`) | GLEICH |
| `CoachExportBlatt` (`CoachBlaetter.swift:58`) | Blatt (`:227`) | – | FEHLT als Ansicht |
| `CoachVerlaufView` (`CoachVerlaufView.swift:15`) | **Push** `navigationDestination(isPresented:)` (`CoachChatView.swift:232`) | `CoachVerlaufView` (`F/Coach/CoachVerlaufView.swift:4`), **Blatt** über `CoachBlatt.verlauf` (`CoachBlaetter.swift:27`) | AUFBAU ANDERS |
| `CoachTagLeser` (`CoachVerlaufView.swift:94`) | Push (`:233`) | `CoachTagLeser` (`CoachVerlaufView.swift:94`) | GLEICH |
| Mein Ziel / Name ändern | `alert` (`:210-220`) | `alert` "Mein Ziel" (`CoachChatView.swift:~108`); Name ändern fehlt | FEHLT (Name) |

### 3b. Reihenfolge im Chat

| # | Lovea | Lumen | Urteil |
|---|---|---|---|
| 1 | Leer: `leerAnsicht` (`:379`): Orb 84, Begrüßung, Satz, Chips (`CoachVorschlagChip`) | Leer: `willkommen` (`:146`): `LumiView` 96, Begrüßung, Satz, Chips | GLEICH (Orb vs Lumi) |
| 2 | – | `CoachMorgenCheckKarte` (`:26`) oben | Lumen mehr |
| 3 | `verlauf` (`:421`): `CoachEintrag` (`:834`), Antworten mit Folgefragen und Aktionsleiste nur bei der letzten | Nachrichten mit Trenner je Tag (`:28-35`, `trenner` `:164`), `CoachAntwortZeile` (`F/Coach/CoachAntwortTeile.swift:211`) | GLEICH |
| 4 | `denkt` (`:523`): Orb aktiv, "denkt nach…", `CoachDenkPunkte` (`:804`), Hinweis nach Sekunden | `CoachDenkAnzeige` (`CoachAntwortTeile.swift:310`) | GLEICH |
| 5 | `unten(fragen:)` (`:543`): Fehler, `CoachLoeschKarte`, `eintragsKarte` (`:562`), `schnellfragenLeiste` (`:646`), Zähler, `eingabe` (`:677`), "KI-Coach, kein Arzt" | `eingabe` per `safeAreaInset` (`:64`, `:242`), `handlungsLeiste` (`:330`), `CoachChipLeiste` (`CoachAntwortTeile.swift:351`), `CoachFehlerZeile` (`:334`), `CoachEintragsKarte` (`F/Coach/CoachAntwortKarten.swift:289`) | GLEICH, Details prüfen |
| 6 | Pfeil "nach unten" (`:594`, Sichtbarkeit `:360`) | `nachUnten` (`:220`, Overlay `:55`) | GLEICH |
| – | Coach-Schlafkarte `CoachSchlafKarte` mit `SchlafNachtDiagramm` + Link auf Schlaf-Detail (`CoachAntwortTeile.swift:253-290`) | `CoachSchlafKarte` (`CoachAntwortKarten.swift:167`) | GLEICH (Ziel = Schlaf-Tab statt Push) |

### 3c. Farben, Gewichte, Bewegung, Coach

| Element | Lovea | Lumen | Urteil |
|---|---|---|---|
