# SPEC: Lumen Fit

Stand: 29.10.2026. Eine iOS-App für Gesundheit und Fitness (Gym, Essen, Schlaf, Schritte, Coach, Fortschritt) in Apple-Monochrom, die Ahmed, seine Partnerin und Kollegen nutzen. Sie nimmt alles Health-Fertige aus der Lovea-App mit und lässt sich mit Lovea verbinden. Diese Spec ist die Wahrheit für den Bau. Recherche-Belege: `docs/research/` (Datenquellen `daten.md`, Design `design.md`, Konfiguration `konfiguration.md`). Begriffe: `CONTEXT.md`. Qualitätslatte: `CONSTRAINTS.md`. Plan: `tasks/plan.md`, Aufgaben: `tasks/todo.md`, Modulaufträge: `tasks/auftraege/`, 100 Ideen: `docs/ideas/lumen-fit.md`.

## 0. Ahmeds Auftrag (wörtlich, 1:1)

Ahmeds Worte vom 29.10.2026:

> Wenn du ganze Health auslagerst dann in eine sehr gute app die man ruhig mit mehr kollegen teilen kann, kein girly Theme (einstellbar in Setting mehrere Themes), standard is monochrome Apple Design. Mit Lovea verknüpfen können. Neue name kein herz oder love ish. Weil das allgemeiner für mehr leute gemacht wird. Mit ganz simple profil erstellen Passwort legen und das wird dann gespeichert. Nach einem update oder so sollte man sich nicht erneut anmelden müssen. Man muss nie mehr erneut anmelden müssen. Einmal profil erstellt dann bleibt es. Coach ai soll besser sein und menschlicher. Wecker und erinnerungen als eine andere app, erstmal hier raus lassen, Lumen fit ist nur Health. Lass mein band irgendwie shared sein dass für lovea ich noch was damit machen kann und dass wenn lovea und health app connected sind dann bekomm ich Benachrichtigungen wenn Annika was hat und ich kann annika sachen sehen usw. Wenn nicht connected dann funktioniert es ganz normal. Mit fortschritte und milestones usw, Figur (Lumi) süß und bunt. Mehr Muster, Animation, weniger Farben, so wie Apple-Farben. Ich würde sagen du kannst jetzt beginnen die app zu oneshoten. Versuch so viel wie möglich fertiges aus der lovea app holen.

Zusatz der Auftragsvorgabe (nicht Ahmeds Worte, Verweise und Grenze, ebenfalls 1:1):

> SPEC: /home/tobi/.claude/buero-stand/lumen-fit-29-10.md. DESIGN (verbindlich, v9): /home/tobi/Documents/Obsidian/Personal/19 Bastelprojekte/Lumen Fit/design.html. Lovea-Quelle zum Übernehmen: /home/tobi/projects/lovea-app-ios (Gym, Essen/Scan, Schlaf, Schritte, Habits, Coach, Verlauf, Widgets; Inventar: 19 Bastelprojekte/Lovea – Funktionen und Auslagerung.md). Lovea selbst NICHT verändern.

Quellen und Grenzen dieser Spec: der ältere Spec-Entwurf `~/.claude/buero-stand/lumen-fit-29-10.md` (enthält noch Wecker, Erinnerungen und einen Konto-Server; die späteren Zeilen und Ahmeds Worte oben gehen vor, siehe Abschnitt 15), das Design `design.html` v9 samt Auswertung `docs/research/design.md`, das Inventar `Lovea – Funktionen und Auslagerung.md`, der Lovea-Quelltext (nur lesen) und die Recherche in `docs/research/`.

## 1. Ziel

Eine eigene iOS-App "Lumen Fit" (Bundle `com.onlyus.lumen-fit`), die Lovea von der gesamten Health-Hälfte (rund 37.600 Zeilen, 11 Start-Objekte, HealthKit, Hintergrundlieferung, Live Activities) befreit und selbst eine sehr gute, ruhige App wird: Gym in Hevy/Strong-Qualität, Essen mit Scan, Schlaf mit Erholung, Tages-Score, Coach mit Ton eines Freundes, Fortschritt mit Meilensteinen, Figur Lumi, fünf Themes mit Mustern. Alles läuft auf dem Gerät. Wer Lovea hat, verbindet beide Apps: dann erscheint die Partner-Seite, sonst läuft alles normal.

Nutzer: Ahmed, seine Partnerin, Kollegen (mehrere Profile, auch mehrere auf einem Gerät). Kein Girly-Look, kein Herz im Namen.

### User Stories (Matt Pocock to-spec, Auszug)

1. Als neuer Nutzer lege ich Name und Passwort an und sehe eine Minute später meinen gefüllten Tag, ohne später je wieder ein Passwort einzugeben.
2. Als Nutzer bleibe ich nach einem TestFlight-Update angemeldet; nach einer Neuinstallation ist mein Profil wieder da und die App bietet mir meine Datensicherung an.
3. Als Kollege nehme ich Monochrom, mein Kollege nimmt Wald; beides sieht nach Apple aus, nicht nach Spielzeug.
4. Als Trainierender sehe ich in jeder Satzzeile, was ich beim letzten Mal gemacht habe, hake mit einem Tipp ab und bekomme die Pause von selbst.
5. Als Trainierender sehe ich nach einem Satz sofort, ob es ein Rekord war.
6. Als Esser scanne ich eine Packung und sehe Makros, Halal- und Zucker-Hinweis, ohne ein Konto.
7. Als Schläfer sehe ich, wie erholt ich bin, im eigenen 60-Tage-Bereich und in einfachen Worten.
8. Als Nutzer frage ich den Coach etwas und bekomme drei kurze Sätze, die meine echten Zahlen kennen und mich nicht belehren.
9. Als Nutzer sehe ich Fortschritt als Kurve, Raster und Medaille, und Lumi freut sich mit.
10. Als Lovea-Nutzer schalte ich "Mit Lovea verbinden" ein und sehe die Partner-Karte und bekomme Mitteilungen; schalte ich es aus oder fehlt Lovea, merke ich nichts davon.
11. Als Band-Besitzer teile ich mein Band mit Lovea: Lovea schickt Vibrations-Wünsche, Lumen Fit führt sie am Band aus (Standard aus, siehe Annahme 9).
12. Als Nutzer lege ich Widgets auf den Home-Bildschirm und hake Gewohnheiten dort ab; im Training sehe ich Satz und Pause auf dem Sperrbildschirm.
13. Als Nutzer lösche ich alles mit meinem Passwort und weiß vorher, was gespeichert war.

## 2. Deutungen des Auftrags (mit Begründung)

| Ahmeds Satz | Deutung | Begründung |
|---|---|---|
| "ganze Health auslagern" | Alle Health-Teile aus Lovea (Gym, Essen/Scan, Schlaf, Schritte, Habits, Heute, Verlauf, Coach, Widgets Gym/Essen/Habit) wandern als fertige Logik in die neue App; Lovea wird danach in einer eigenen Runde verkleinert | Inventar `Lovea – Funktionen und Auslagerung.md`, Spur A; "Lovea selbst NICHT verändern" gilt für diesen Bau |
| "sehr gute app, ruhig mit mehr Kollegen teilen" | Mehrere Profile, nichts Privates im Code, kein Zwang zu Lovea, sauberes Onboarding, Quellenangaben | Kollegen kennen Lovea nicht; Namen und Orte dürfen nicht im Quelltext stehen |
| "kein girly Theme, einstellbar mehrere Themes, Standard monochrome Apple Design" | Fünf Themes (Monochrom Standard, Graphit, Stahl, Glut, Wald), jedes hell und dunkel, Auswahl in "Aussehen" | `design.md` Abschnitt 3 |
| "Mit Lovea verknüpfen können" | Zwei Wege in der gemeinsamen App Group `group.com.onlyus.lovea` (Abschnitt 5.5): Quelle A sofort und ohne Änderung an Lovea (Lumen Fit liest Loveas vorhandenen `widget-stand.json`: Schritte, Gym-Woche, Schlaf der Partnerin) und Vertrag B für Band-Wünsche und Zusammenfassungen (Loveas Hälfte ist eine spätere Lovea-Runde) | Loveas Widgets lesen diesen Stand heute schon aus der Gruppe, Lovea füllt ihn über den eigenen Server; App Groups gelten nur auf einem Gerät; Lovea darf jetzt nicht geändert werden, also wäre Vertrag B allein am ersten Tag leer |
| "Neue name kein herz oder love ish" | Lumen Fit (Marke Lumen); kein Wort mit Herz, Love, Fit-Bindestrich-Gym | `konfiguration.md`; "Forma" wurde abgelehnt |
| "simple profil, Passwort legen, wird gespeichert; nie mehr erneut anmelden" | Lokales Profil: Name plus Passwort; Passwort nur als Salz und Hash im Schlüsselbund; die App fragt beim Start nie nach einem Passwort; das Passwort schützt nur Profilwechsel, Passwort ändern und Löschen | Client-only (Abschnitt 5.4); der ältere Entwurf mit Cloudflare-Konten ist verworfen, Annahme 2 |
| "Coach AI besser und menschlicher" | Coach-Motor auf dem Gerät (Apple Foundation Models) mit regelbasiertem Rückfall, Ton eines Freundes, Gedächtnis, Antwort-Chips mit Handlung, ehrlich über Wissenslücken | Recherche FitWoody/Whoop; kein Server nötig |
| "Wecker und Erinnerungen als andere App, erstmal raus; Lumen Fit ist nur Health" | Keine Wecker, keine Erinnerungen (auch keine Wiege-, Wasser-, Trainings-Erinnerung), keine Töne, kein AlarmKit | Spätere Zeile im Auftrag schlägt die ältere Umfangsliste; Annahme 3 |
| "Lass mein Band shared sein" | Lumen Fit besitzt die Bluetooth-Verbindung; Lovea schickt Vibrations-Wünsche über eine Warteschlange in der gemeinsamen Gruppe (Abschnitt 5.6) | Das Band nimmt nur eine Verbindung (Lovea `TrackerFunk`): zwei Apps gleichzeitig gehen nicht; deshalb opt-in |
| "bei Verbindung Benachrichtigungen, wenn die Partnerin etwas hat; nicht connected: ganz normal" | Lokale Mitteilungen aus Partner-Ereignissen; "verbunden" bedeutet: eine frische Partner-Datei liegt in der gemeinsamen Gruppe; sonst keine Partner-Teile sichtbar | Ohne Server geht nur das, was Lovea in die Gruppe schreibt |
| "Fortschritte und Milestones" | Kraftkurve, Konstanz-Raster, Meilensteine, Medaillen, Lumi-Stufen, Rückblicke | Screenshots FitWoody (Figur, Meilensteine, Werte-Chips) |
| "Figur Lumi süß und bunt" | `LumiView` aus SwiftUI-Formen, fünf Stimmungen, einzig Buntes neben drei Datenfarben | Design v9/v10 |
| "mehr Muster, Animation, weniger Farben, wie Apple-Farben" | Muster je Theme, Bewegung nur bei Ereignissen, drei Datenfarben (Bewegen, Trainieren, Erholen) | `design.md` 1, 3, 6, 9 |
| "du kannst jetzt beginnen, die App zu oneshoten" | Spec, Plan, Module parallel, CI, TestFlight; keine Rückfragen | Ahmed fragt nicht zurück; Unklares steht unter Annahmen |
| "so viel Fertiges wie möglich aus Lovea" | Datenkern, reine Logik und die zugehörigen Tests werden aus Lovea portiert (Abschnitt 5.8); Neues nur, wo Lovea nichts hat | schnell, getestet, bekannt |
| "Gym nicht original" (ältere Spec-Zeile) | Als Bemerkung zum Namen gelesen (kein Name wie "Gym"), nicht als Funktionsvorgabe; das Lovea-Gym wird übernommen und ausgebaut | Die Zeile steht direkt vor der Namensentscheidung |

## 3. Funktionsumfang v1

Fünf Tabs; Profil, Themes und Verbindungen liegen im Profil-Blatt (Avatar-Kapsel oben rechts auf jedem Tab). Zuordnung aller Teile: `docs/research/design.md` Abschnitt 11.

- **Heute:** Ringplatte mit Lumen-Bögen, Bereit-Score, Lumis Morgensatz, Plan-Karte, Energie-Bank, Gewohnheiten mit Serie, Gewicht, Schritte, Hinweise, Wochenstreifen, Partner-Karte (nur verbunden).
- **Gym:** Training starten, Satz-Logging mit "Letztes Mal", Satztypen, RPE, Pausen-Timer, Live-Rekord, Scheiben- und Aufwärmrechner, Übungskatalog (1.333), Splits und Wochenplan, Supersets, Cardio, Studio-Besuche, Segment "Fortschritt".
- **Fortschritt** (Segment in Gym, Seiten über Heute): Kraftkurve, Sätze je Muskel, Erholungs-Silhouette, Vorschlag fürs nächste Training, Konstanz-Raster, Gewichtsverlauf, Meilensteine, Lumi-Stufen, Rückblicke, FitPassport.
- **Essen:** Tagebuch, Barcode-Scan, BLS offline, Open Food Facts, Makro-Donut, Halal- und Zucker-Ampel, Favoriten, Fasten, Etikett-Foto, Ziele, Wochenanalyse.
- **Schlaf:** letzte Nacht, Phasen, Schlafschuld, HRV im eigenen Bereich, Werte-Chips, Woche, Regelmäßigkeit, Quellenwahl, Partner-Zeile (nur verbunden).
- **Coach:** Chat, Gedächtnis, Chips, Schnellfragen, Morgen-Check, Daumen und Merkliste.
- **Profil-Blatt:** Onboarding, Aussehen, Ziele, Körperdaten, Health-Zugriff, Datensicherung, Quellen, Datenschutz, Export, Verbindungen (Lovea, Band, Freunde).
- **Widgets und Live Activity:** Bögen, Plan und Serie, Sperrbildschirm, Training-Live-Activity mit "Satz fertig", Gewohnheiten, Essen, Siri-Kurzbefehle, Spotlight, Steuerelement.

Bewusst nicht in v1: Abschnitt 17.

## 4. Datenquellen (alle ohne Schlüssel; Details und Messungen: `docs/research/daten.md`)

| Bereich | Primär | Rückfall | Pflicht |
|---|---|---|---|
| Lebensmittel generisch | BLS 4.0, gebündelt (7.140 Einträge, aus Lovea `lebensmittel-basis.json`) | Eingabe von Hand | Namensnennung CC BY 4.0 (Quellen-Seite, Idee 78) |
| Lebensmittel Barcode | Open Food Facts v2 `GET /api/v2/product/<code>.json?fields=...` | letzter gespeicherter Treffer, Eingabe von Hand | eigener User-Agent `LumenFit/<Version> (Kontakt)`, höchstens 15 Abfragen je Minute, ODbL-Nennung; unbekannter Code: HTTP 404 oder 200 mit `status 0`; kJ-nur-Produkte: kcal = kJ / 4,184 |
| Lebensmittel Textsuche | BLS lokal, danach `search.openfoodfacts.org/search` nur auf "Suchen" | alte `cgi/search.pl` (flackert), Wiederholversuch bei HTTP 500 | höchstens 10 Suchen je Minute |
| Übungskatalog | Lovea `uebungen.json` (1.333, deutsche Namen, offline) | wger `exerciseinfo` (CC-BY-SA) nur als spätere Ergänzung | – |
| Übungsbilder | `static.exercisedb.dev/media/<id>.gif`, nur laden und cachen, nie bündeln (wie Lovea) | SF-Symbol je Muskel; free-exercise-db (Unlicense) als spätere zweite Quelle | Medien-Lizenz ungeklärt (Annahme 14) |
| Schritte, Schlaf, HRV, Ruhepuls, Atmung, SpO2, VO2max, Gewicht, Workouts | HealthKit | Daten fehlen: Leerzustand mit Handlung | Texte `NSHealthShareUsageDescription` und `NSHealthUpdateUsageDescription` |
| Training live (Puls, Energie) | `HKWorkoutSession` plus `HKLiveWorkoutBuilder` | ohne Sensor kein Puls (Normalfall) | – |
| Barcode live | VisionKit `DataScannerViewController` | Foto: Vision `VNDetectBarcodesRequest`; Text: `VNRecognizeTextRequest` | NSCameraUsageDescription |
| Coach | Apple Foundation Models (`SystemLanguageModel`, `LanguageModelSession`, `@Generable`; iOS 26, nur mit Apple Intelligence, Deutsch mit `supportsLocale` prüfen) | regelbasierte deutsche Textbausteine aus Lovea (`CoachRegeln`, `CoachLokal`, `CoachTraining`, `CoachGesundheit`) | Typnamen am Compiler und in der Apple-Doku prüfen |
| Band | CoreBluetooth (`TrackerFunk` aus Lovea) | – | NSBluetoothAlwaysUsageDescription, Hintergrund `bluetooth-central` |
| Partner-Werte, sofort | Loveas vorhandener `widget-stand.json` in `group.com.onlyus.lovea`, nur lesen (Quelle A, Abschnitt 5.5) | Vertrag B (`partner.json`), sonst nicht verbunden | nur Schritte, Gym-Woche, Schlaf und Ziele dekodieren, nie Ort, Wetter, Akku, Status, Punkte oder Bilder |
| Lovea-Kopplung, geteiltes Band | JSON-Dateien in `group.com.onlyus.lovea` (Vertrag B, Abschnitt 5.5) | nicht verbunden: alles lokal | – |
| Widgets, Live Activity | WidgetKit, ActivityKit, App Intents | – | App Group `group.com.onlyus.lumen-fit` |

**Wer liefert was (Realismus).** Nur mit iPhone gibt es Schritte, Distanz, Etagen und eine Schlafzeit, aber keine Schlafphasen. Phasen, HRV, Ruhepuls, Atmung, SpO2, Temperatur und VO2max liefern nur eine Apple Watch oder ein Gerät, das nach Health schreibt; Loveas Band-Schritte und -Schlaf landen nicht in Health (Lovea liest Health nur, `HealthModell` ohne `toShare`). Ohne diese Quellen zeigen Chips und Diagramme einen ehrlichen Leerzustand mit Handlung, der Bereit-Score rechnet mit den vorhandenen Werten und sagt, was fehlt (nie erfinden). Für den Besitzer des Bands ist das Band die Quelle für Schritte und Schlaf (Lovea nimmt dort das Maximum aus Band und Health): seine Tage und Nächte kommen als Ops `fit.band.tag` und `fit.band.schlaf` (Abschnitt 5.3). HealthKit verrät nie, ob Lesen abgelehnt wurde (Datenschutz): "keine Daten" ist die einzige ehrliche Aussage, `HealthZugriff.verweigert` ist nur für Schreibtypen feststellbar; `getRequestStatusForAuthorization` sagt nur, ob das Blatt noch erscheinen muss.

Verworfen (Begründung in `daten.md`): USDA FoodData Central (englisch, geteilter Demo-Schlüssel), Pollinations (Limit, Gesundheitsdaten an Dritte), Groq und Cerebras (Schlüssel nötig), Open-Meteo (nicht im Auftrag).

## 5. Architektur

### 5.1 Stack

Swift 6 (strikte Nebenläufigkeit), iOS 26.0 (Liquid Glass), nur iPhone, SwiftUI, Observation (`@Observable`), Swift Charts, HealthKit, CoreBluetooth, VisionKit und Vision, WidgetKit, ActivityKit, App Intents, CoreSpotlight, UserNotifications, BackgroundTasks, Security (Schlüsselbund), CommonCrypto (PBKDF2), CoreImage (QR), FoundationModels (nur mit `#if canImport(FoundationModels)` und Laufzeitprüfung). Keine Swift-Pakete (wie Lovea und Bahnherz: vermeidet Paketnetz-Fehler). Kein Server, kein Push.

### 5.2 Schichten

1. `Gemeinsam/` (Foundation und SwiftUI, von App UND Widget-Erweiterung kompiliert, kein App-Zustand): Zeit (`Datum`), Daten (`Op`, `JSONValue`), Speicher (`JSONDatei`, `AppGruppe`), Modelle der ported Lovea-Typen, Navigation (`Route`, `RouteURL`), Design (Farben, Themes, Muster, Lumi, Bögen), Brücke (Dateivertrag mit Lovea), Widgets (Snapshot, Intents, Aktivität; gehört dem Modul widgets).
2. `LumenFit/Sources/Konto/`: Schlüsselbund-Port, Passwort-Hash, `ProfilStore`.
3. `LumenFit/Sources/Daten/`: `LokalerOpLog`, `LokalerRaum`, die Stores (`TrainingStore`, `EssenStore`, `HabitStore`, `MeilensteinStore`, `CoachStore`, `EinstellungenStore`, `ZieleStore`, `VerbindungStore`), `DatenSatz` (alle Stores eines Profils).
4. `LumenFit/Sources/Gesundheit/`: `HealthLeser` (HealthKit hinter einem Port), `GesundheitsStand`, `HealthSchreiber`.
5. `LumenFit/Sources/App/`: `@main`, Root mit Tabs, `Router`, `AppUmgebung`, `EreignisKanal`, `ModulStart`, Demo.
6. `LumenFit/Sources/Design/`: App-seitige Bausteine (Feder, Haptik, Hero- und Listenkarte, Avatar-Kapsel, Hintergrund).
7. `LumenFit/Sources/Module/<Modul>/`: neun Module (Abschnitt 12) mit Oberflächen und Logik; `LumenFitWidgets/Sources/` das Widget-Ziel.

Reine Logik als `enum` mit `static func` oder `struct`; Zustand als `@MainActor @Observable final class`; alle Datentypen `Sendable`.

### 5.3 Daten: ein lokaler Op-Log je Profil (Entscheidung, Annahme 4)

Lovea speichert Gym, Essen, Habits und Körperwerte als Ereignisse ("Ops", Art als Text wie `gym.checkin`, `essen`, `cardio.setzen`) und rechnet den Stand in reinen "Faltungen" (`TrainingFaltung`, `ErnaehrungFaltung`, `FastenFaltung`, `HabitFaltung`). Genau diese Schicht ist der größte Teil des "Fertigen" und hat die meisten Tests. Lumen Fit übernimmt sie unverändert in der Form und ersetzt nur den Transport:

- `Op` (aus Lovea `Sync/Op.swift`): `id`, `art`, `von`, `zeit`, `d` (JSON-Rumpf). `von` ist die `ProfilID` (statt Loveas `Person`); `seq` entfällt.
- `LokalerOpLog` (neu, Vorbild Loveas `OpLog`): eine Zeile JSON je Op in `<Profilordner>/ops.jsonl`, nur anhängen, doppelte `id` überspringen, eine kaputte letzte Zeile wird übersprungen und gesichert. Kein Server, keine `seq`, kein Entwurfs- und Zeichen-Sonderfall.
- `LokalerRaum` (neu): dieselbe kleine Oberfläche, die Loveas Health-Code von `Raum.shared` braucht: `senden(art, daten)`, `einreihen(op)`, `beobachten(arten) { op in }` (spielt beim Anmelden zuerst alle vorhandenen Ops der Arten ab, dann live), `ops(arten:)`, `leer()` (wartet, bis geschriebene Ops gefaltet sind). Ein Raum je `DatenSatz`, keine Singletons (`static let shared` entfällt überall; Stores bekommen den Raum per Initialisierer).
- Arten aus Lovea bleiben unverändert, damit ein späterer Import aus Loveas `ops.jsonl` ohne Umbau läuft. Neue Arten von Lumen Fit tragen die Vorsilbe `fit.` (`fit.lumi.meilenstein`, `fit.coach.nachricht`, `fit.coach.merke`, `fit.lumi.stimmung`).
- Op-Katalog `fit.*` (Rumpf-Typen gehören dem Grundgerüst, `Gemeinsam/Modelle/Lumi.swift`, `Coach.swift`, `Gesundheit.swift`; Schreiber ändern den Rumpf nie, Leser benutzen den Typ; gleiche `id` bzw. gleicher `tag` ersetzt, die letzte Op gewinnt):

  | Art | Rumpf | Schreibt | Liest |
  |---|---|---|---|
  | `fit.lumi.meilenstein` | `MeilensteinStand` (`id`, `erreicht`) | fortschritt über `MeilensteinStore.markiere` | `MeilensteinStore` (Grundgerüst), fortschritt |
  | `fit.lumi.stimmung` | `StimmungsEintrag` (`tag`, `wert` 1 bis 5, `stimmung`) | coach (Morgen-Check) | heute (Lumis Stimmung, Plan-Karte), widgets (Snapshot) |
  | `fit.coach.nachricht` | `CoachNachricht` | coach über `CoachStore.haenge` | `CoachStore` |
  | `fit.coach.merke` | `MerkEintrag` (`text`, `entfernt`) | coach über `CoachStore.merke` und `vergiss` | `CoachStore` |
  | `fit.band.schlaf` | `BandSchlafOp` (`tag`, `start`, `ende`, `phasen: [SchlafAbschnitt]`) | verbinden (`TrackerSchlaf`) | schlaf (`SchlafQuellenWahl`) |
  | `fit.band.tag` | `BandTagOp` (`tag`, `schritte`, `meter`) | verbinden (`TrackerTage`) | `GesundheitsStand`: je Tag das Maximum aus Health und Band, nie die Summe (wie Lovea `HealthLogik.schritteTag`) |

- Alles, was nicht aus Lovea kommt und klein ist, liegt als Datei im Profilordner (`JSONDatei`, atomar, defekte Datei wird `.defekt` gesichert): `einstellungen.json`, `ziele.json`, `freigaben.json`, `freunde.json`, `schlaf-cache.json`.
- Profilordner: `<AppGruppe.ordner>/profile/<ProfilID>/`. Widgets lesen nur `widget-stand.json` im Gruppenordner (Snapshot des aktiven Profils, geschrieben vom Modul widgets).
- Neue Felder in gespeicherten Typen sind immer optional (`decodeIfPresent`); jede Änderung bekommt einen Fall in `AlteDateienLadenTests` (eingefrorene Datei vom letzten Stand).

Warum so (Ponytail): wenig neuer Code, die Lovea-Tests laufen mit, "Import aus Lovea" und eine spätere Synchronisation sind schon die Form der Daten, der Log ist anhängend und damit robust gegen Abbruch. Offen: Dauer der Faltung bei 20.000 Ops auf dem Gerät (Lovea nutzt dasselbe Muster, hier nicht gemessen).

### 5.4 Profil, Passwort, nie wieder anmelden (Idee 1, 2, 71, 72)

- `Profil`: `id` (UUID), `name`, `erstellt`, `passwort` (`PasswortSpur`: Salz 16 Byte, Hash 32 Byte, Runden). Das Passwort selbst wird nie gespeichert.
- Hash: PBKDF2-HMAC-SHA256 über CommonCrypto (`CCKeyDerivationPBKDF`), 600.000 Runden (OWASP 2023, in der Spur gespeichert, damit sie steigen können), Vergleich in konstanter Zeit. Mindestlänge 4 Zeichen ("ganz simple"); das Passwort schützt nur lokale Handlungen, kein Konto im Netz.
- Ablage: Schlüsselbund hinter dem Port `Schluesselbund`. Zwei Einträge: `konto.profile` (Liste der Profile als JSON) und `konto.aktiv` (UUID). Attribute: `kSecAttrAccessibleAfterFirstUnlock`, `kSecAttrSynchronizable = true` (iCloud-Schlüsselbund, wenn der Nutzer ihn an hat; sonst lokal), Dienst `com.onlyus.lumen-fit.konto`. Kein eigenes Entitlement. Lesen und Löschen immer mit `kSecAttrSynchronizable: kSecAttrSynchronizableAny` (sonst findet die Abfrage die synchronisierbaren Einträge nicht); schlägt das Schreiben als synchronisierbar fehl (iCloud-Schlüsselbund aus), wird lokal geschrieben. Beide Wege sind Tests am Fake. Die Liste enthält Name und Passwort-Spur, nie das Passwort.
- Start: gibt es im Schlüsselbund ein aktives Profil, zeigt die App direkt die Tabs. Es gibt nirgends einen Anmeldebildschirm. Das Onboarding hängt am Schlüsselbund-Profil, nicht an Datendateien (nach einer Neuinstallation überlebt der Schlüsselbund meist, der Container nicht).
- Passwort gefragt wird nur bei: Profil wechseln, Passwort ändern, Profil oder alle Daten löschen, Datensicherung einspielen in ein anderes Profil. Falsches Passwort: Haptik `.error`, Schütteln, "Passwort stimmt nicht. Versuch es nochmal."
- Neuinstallation: Profil ist wieder da, `profile/<ID>/` fehlt: Willkommen-zurück-Karte "Datensicherung einspielen?" (Idee 74), Health-Verlauf kommt aus Health (Idee 8), Trainings und Essen nur aus der Sicherung. Das ist eine Grenze (Annahme 5).
- Unsignierter CI-Simulator: `SecItem*` kann `-34018` melden. Der Port hat deshalb `SpeicherSchluesselbund` (im Speicher) als Fake und Rückfall; in signierten Builds greift immer `KeychainSchluesselbund`.
- Passwort vergessen: kein Rückweg per Mail (kein Server). "Profil zurücksetzen" löscht Profil und Daten nach Bestätigung; mit Datensicherung geht man neu an.

### 5.5 Lovea-Brücke: Dateivertrag in der gemeinsamen Gruppe (Idee 81 bis 84, 86)

Eine App Group gilt nur auf einem Gerät. Die Partnerin ist auf einem anderen Gerät; ihre Daten erreichen Ahmeds Gerät nur über Loveas eigenen Server, und Lovea legt sie auf Ahmeds Gerät schon heute in der Gruppe ab (Quelle A). Lovea darf in diesem Bau nicht geändert werden; darum gibt es zwei Wege: Quelle A funktioniert am ersten Tag, Vertrag B (Band-Wünsche, Zusammenfassungen von Lumen Fit an Lovea) wartet auf eine spätere Lovea-Runde (Abschnitt 16).

**Quelle A: Loveas vorhandener `widget-stand.json`** (Ordner `<group.com.onlyus.lovea>/`, nur lesen). Lovea schreibt ihn für ihre Widgets (gedrosselt, bei jeder relevanten Änderung) mit Werten je Person unter deren Kennung: `schritteHeute`, `zielSchritte`, `gymLetzte7` (Montag bis Sonntag, je `datum` und `erledigt`), `zielGymWoche`, `schlafMinutenHeute`, `zielSchlafMinuten`; `eigenePerson` nennt die Person dieses Geräts, die andere Kennung ist die Partnerin. `LoveaBruecke` (Grundgerüst) dekodiert nur diese Felder, alle optional, und macht aus der anderen Kennung eine `ZusammenfassungDatei`: `profilName` = Kennung mit großem Anfangsbuchstaben (Laufzeitwert, nie im Quelltext), `freigaben` = vorhandene Felder, `heute.schritte`, `heute.gymTageWoche` (Anzahl `erledigt`), `heute.schlafMinuten`, `geschrieben` = Änderungsdatum der Datei, `ereignisse` zustandslos aus dem einen Stand: `gymEnde-<tag>` wenn der heutige Gym-Tag `erledigt` ist, `ziel-<tag>` wenn Schritte mindestens das Ziel sind, `schlafGut-<tag>` wenn die Schlafminuten mindestens das Ziel sind (die `id` macht jedes Ereignis einmal je Tag; die Mitteilungs-Regeln merken sich die Ids). Ort, Wetter, Akku, Status, Herzen, Punkte und Bilder aus der Datei werden nie dekodiert. Das Format gehört Lovea: unbekannt oder kaputt heißt "nicht verbunden", nie ein falscher Wert. Test mit `lovea-widget-stand-beispiel.json` (erfundene Kennungen).

**Vertrag B** (Ordner `<group.com.onlyus.lovea>/LumenFit/`, `containerURL(forSecurityApplicationGroupIdentifier:)`, nil ohne Signierung: dann gilt "nicht verbunden"). `partner.json` mit `version` 1 gewinnt gegen Quelle A.

| Datei | Schreibt | Liest | Inhalt (`version` 1) |
|---|---|---|---|
| `zusammenfassung.json` | Lumen Fit | Lovea | `geschrieben`, `profilName`, `freigaben` (Teilmenge von schritte, gym, schlaf, essen; Standard leer), `heute` (`tag`, `schritte?`, `gymTageWoche?`, `schlafMinuten?`, `kcal?`; nur freigegebene Felder), `ereignisse` (`id`, `art` aus gymStart, gymEnde, ziel, rekord, schlafGut; `zeit`, `text`) |
| `partner.json` | Lovea | Lumen Fit | gleiche Form; `profilName` ist der Name des Partners |
| `band-wuensche.json` | Lovea | Lumen Fit | `wuensche` (`id`, `muster` aus kurz, lang, doppelt, ruf, pauseEnde; `zeit`, `von`) |
| `band-erledigt.json` | Lumen Fit | Lovea | `ids` (letzte 200 ausgeführte Wünsche) |
| `band-status.json` | Lumen Fit | Lovea | `geschrieben`, `verbunden`, `akkuProzent?`, `name?` |

Regeln:
- Schreiben atomar. Lesen verträgt fehlende und kaputte Dateien (= nicht verbunden) und unbekannte `version` (= Hinweis "Lovea ist neuer, bitte Lumen Fit aktualisieren", sonst nichts).
- **Verbunden** heißt genau: Einstellung `loveaVerbunden` an, und entweder `partner.json` liegt da (`version` 1) oder Quelle A liefert eine Partnerin; `geschrieben` (bei Quelle A das Änderungsdatum) ist höchstens 48 Stunden alt. Sonst zeigt keine Oberfläche etwas vom Partner, nicht einmal einen Platzhalter ("wenn nicht connected dann funktioniert es ganz normal").
- Datenschutz: nur Zusammenfassungen, nie Rohdaten (keine Sätze, keine Herzfrequenz, keine Mahlzeiten); jede Art hat ihre eigene Freigabe, Standard aus (Idee 84).
- Darwin-Benachrichtigungen als Anstoß (`CFNotificationCenterGetDarwinNotifyCenter`): `com.onlyus.lumen-fit.zusammenfassung`, `com.onlyus.lumen-fit.band-status` (an Lovea), `com.onlyus.lovea.partner`, `com.onlyus.lovea.band-wunsch` (an Lumen Fit). Namen sind eine Annahme; sie wecken keine beendete App, gelesen wird beim Öffnen (`Ereignis.vordergrund`) und im Hintergrund-Abruf (`com.onlyus.lumen-fit.aktualisieren`, Aufgaben melden Module mit `AppUmgebung.beiAbruf`). Lovea sendet für Quelle A keine Darwin-Benachrichtigung; das Lesen beim Vordergrund und im Abruf genügt. Zusätzlicher Weckruf: die HealthKit-Hintergrundlieferung (`HealthLeser.beobachte` für Schritte, Schlaf und Training, Entitlement vorhanden) startet die App im Hintergrund, wenn neue Health-Daten ankommen; `ModulStart.starteAlle` meldet die Beobachtung synchron an, `Ereignis.healthAktualisiert` und alle `beiAbruf`-Aufgaben laufen dann, der Partner-Stand wird gelesen, die Mitteilung kommt. Die Häufigkeit bestimmt iOS (ungeprüft); gelesen wird nur die Datei, nie Health, damit es auch bei gesperrtem Gerät geht.
- Mitteilungen "Partner ist im Gym" entstehen deshalb nur, wenn Lumen Fit läuft oder der Abruf es weckt; Echtzeit liefert Loveas eigener Push (Annahme 8).
- Ohne Signierung (Tests): `LoveaBruecke(ordner:)` bekommt einen Temp-Ordner; der Vertrag wird gegen Fixtures in `LumenFit/Tests/Fixtures/Verbinden/` getestet.

### 5.6 Band: geteilt und opt-in (Idee 85 bis 88)

Lovea `TrackerFunk` zeigt: das Band nimmt nur eine Verbindung und sendet nach dem Trennen erst, wenn man es antippt. Solange Lovea seinen Band-Code behält, würden zwei Apps um die Verbindung kämpfen. Darum: Lumen Fit schaltet das Band nur auf Wunsch ein (`bandAktiv`, Standard aus; ohne Schalter wird kein `CBCentralManager` angelegt, damit auch keine Bluetooth-Frage kommt). Ist es an, hält Lumen Fit die Verbindung (Wiederherstellungs-Kennung, Hintergrund `bluetooth-central`), führt Wünsche aus `band-wuensche.json` aus und meldet Status und Akku. Das Band-Protokoll (`TrackerProtokoll`, `TrackerFunk`, `TrackerModell`, `BandPuls`, `BandNachrichtVibration`, `BandRegeln`) kommt aus Lovea. Auf dem Gerät offen: ob iOS dem zweiten Prozess `retrieveConnectedPeripherals` erlaubt und das Band es duldet (Testliste). Wecker, Töne und AlarmKit aus Loveas `Wecker/` kommen nicht mit. Der Schlaf, den das Band meldet (`TrackerSchlaf`), geht als Op `fit.band.schlaf` (`BandSchlafOp`), seine Schritte (`TrackerTage`, je Viertelstunde das Maximum, nie summieren) gehen als Op `fit.band.tag` (`BandTagOp`) in den Raum (Katalog in 5.3); das Modul schlaf liest die Nächte in seiner Quellenwahl (Idee 60), `GesundheitsStand` nimmt je Tag das Maximum aus Health und Band. Verbindungsweg im zweiten Prozess: zuerst `retrieveConnectedPeripherals(withServices:)` (eine Verbindung, die Lovea schon hält, wird womöglich mitbenutzt; ob iOS und das Band das erlauben, wird am Gerät geprüft, Annahmen 9 und 24), dann `retrievePeripherals(withIdentifiers:)`, zuletzt Scan; die Peripherie-Kennung ist je App verschieden, Lovea-Kennungen sind nicht übertragbar. Die Akku-Warnung ist ein Status in der App und im Band-Blatt, keine geplante Mitteilung.

### 5.7 Coach-Motor (Idee 61 bis 70)

`protocol CoachMotor` mit zwei Umsetzungen: `ModellCoachMotor` (Foundation Models, wenn `SystemLanguageModel.default.availability` verfügbar und Deutsch unterstützt ist) und `RegelCoachMotor` (Lovea-Textbausteine, immer verfügbar). Die Auswahl macht `CoachWahl.motor(...)`. Persona-Regeln stehen als Test-Fälle fest (Idee 63): höchstens drei kurze Sätze plus höchstens eine Frage, ansprechen mit "du", echte Zahlen aus dem Kontext statt Floskeln, kein "Als KI", keine Diagnosen, an schweren Tagen (wenig Schlaf, niedrige Erholung, Rückschlag) verständnisvoll und ohne Vorwurf, bei Beschwerden der Hinweis auf Ärztin oder Arzt, bei fehlenden Daten nachfragen statt raten. Kontext wird als `CoachKontext` übergeben (Tagesstand, letztes Training, Schlaf, Essen, Ziele, Merkzettel), mit Foundation-Models-`Tool`s für Nachladen. Antwort ist strukturiert: Text plus Chips mit Handlung (`CoachAktion`). Kein Netz, keine Weitergabe von Gesundheitsdaten.

### 5.8 Portierung aus Lovea (Regeln für alle Module)

Quelle ist `~/projects/lovea-app-ios/Lovea/Sources` (nur lesen; Lovea nie ändern, nie dort committen). Dateien liegen unter `Health/`, wenn nicht anders angegeben.

Modus je Datei: **K** kopieren (nur Umbenennungen), **A** anpassen (Aufrufe ersetzen), **N** neu schreiben (Lovea nur Vorbild), **-** nicht übernehmen.

Ersetzungen (gehören dem Grundgerüst; Module bauen keine eigenen):

| In Lovea | In Lumen Fit |
|---|---|
| `Person` (zwei Fälle mit Vornamen, `.partner`, `allCases`) | `ProfilID`; Code, der beide Personen faltet, faltet nur das aktive Profil; `.partner` und beide Fälle entfallen |
| `Raum.shared.senden / beobachten / ich / leer` | `umgebung.raum` (`LokalerRaum`), per Initialisierer |
| `X.shared` Singletons | Stores in `DatenSatz`, per Initialisierer |
| `HealthModell` (HealthKit-Abfragen) | `HealthLeser` und `GesundheitsStand` |
| `LoveaServer`, `EssenClient`, `EssenServer`, `KiFoto`, `KiZyklus`, `/ki/*`, `/coach/*` | `HTTPLader` plus freie Quellen (Abschnitt 4), Coach-Motor (5.7) |
| `PunkteModell`, `Challenge*`, `Besitz*`, `Dank*`, `FigurenModell`, Chat, Anwesenheit | entfallen; Figur ist `LumiView` |
| `UserDefaults`-Schlüssel `lovea.*` | `EinstellungenStore` oder Datei im Profilordner |
| Wecker, Erinnerungen, `SchlafErinnerung`, `WiegeErinnerung`, `CoachWecker`, Töne, AlarmKit | entfallen |
| `StartProtokoll`, `Absturzfänger`, Lovea-Design-Set | entfallen bzw. Grundgerüst-Design |

Regeln:
1. Zuerst die reinen `*Logik`-Dateien und ihre Tests, dann Stores, dann Oberflächen. Oberflächen werden im Lumen-Design neu geschrieben (Modus N); Lovea-Views sind nur Inhaltsvorbild.
2. Die Tests einer Datei kommen mit (gleiche Namen, `@testable import LumenFit`). Nicht mitnehmen: `RenderGalerie*`, `*RenderTests`, alles zu Chat, Figuren, Punkte, Wecker. Bei Umbenennung Tests anpassen, nie löschen oder abschwächen.
3. Private Werte im Lovea-Code (Personennamen, konkrete Studios mit Öffnungszeiten, persönliche Ziele, Orte) nie übernehmen. Studios kommen aus `PrivateDaten.json` (Beispiel: `PrivateDaten.beispiel.json`) oder sind erfunden (Tests). Gate: `bash scripts/namen-gate.sh` muss sauber sein (die Namensliste liegt in `~/.config/lumen-fit/namen.txt`, nie im Git; Treffer erscheinen nur als Pfad:Zeile).
4. Jede portierte Datei trägt oben eine Zeile `// Quelle: Lovea Health/<Pfad>` (Nachweis, spätere Lovea-Auslagerung).
5. Lovea-Ressourcen: `uebungen.json`, `splits.json`, `lebensmittel-basis.json` (BLS, CC BY 4.0) kommen mit. `muskelkarte.json` kommt NICHT mit (stammt aus openGym unter AGPL-3.0, die Freigabe galt nur für die private App; Weitergabe an Kollegen wäre Verteilung, Annahme 13): die Erholungs-Silhouette wird selbst aus SwiftUI-Formen gezeichnet.
6. Im Zweifel zeigt Loveas Test, was gelten soll; weicht Lumen Fit ab, steht der Grund im Commit.
7. Ressourcen eines Moduls (JSON, Listen) liegen in dessen `Sources`-Ordner (XcodeGen nimmt sie als Resources, im Bundle liegen sie flach: eindeutiger Dateiname mit Modul-Präfix). Die drei großen Daten-JSON des Datenkerns liegen im Grundgerüst unter `LumenFit/Resources/Daten/`.
8. Typnamen sind im ganzen Ziel eindeutig, denn neun Module bauen parallel und sehen einander nicht: neue Typen eines Moduls stehen in den Aufträgen oder sind `private`/`fileprivate` oder tragen die Modulsilbe als Vorsilbe (`HeuteZahlenrad`); Erweiterungen auf Fremdtypen sind `fileprivate`; Testklassen heißen nach ihrem Thema und nie wie eine Grundgerüst-Klasse. Prüfung: `bash scripts/typnamen-doppelt.sh` (läuft in `check-schnell.sh`, im Job `patterns` und vor dem Zusammenführen, Ablauf I1).

Datenkern (Eigentümer: Grundgerüst; alles hier ist von mehreren Modulen gelesen und deshalb nicht Sache eines Moduls):

| Lovea-Datei | Ziel | Modus | Tests mitnehmen |
|---|---|---|---|
| `Sync/Op.swift`, `Sync/JSONValue.swift` | `Gemeinsam/Daten/` | A (`von`: `ProfilID`, ohne `seq`) | `OpTests` falls vorhanden |
| `Kalender/Logik/Datum.swift` | `Gemeinsam/Zeit/Datum.swift` | K | `DatumTests` |
| `Training.swift` (Typen, `TrainingLogik`, `TrainingFaltung`) | `Gemeinsam/Modelle/Training.swift` | A | `TrainingTests`, `GymLueckenTests` |
| `TrainingModell.swift` | `LumenFit/Sources/Daten/TrainingStore.swift` | A (ohne Anwesenheit, Figur, Punkte; `HealthModell`-Aufrufe über `HealthLeser`) | `GymTageLogikTests`, `RuhetageTests` |
| `GymNeu/Splits.swift`, `GymNeu/WochenAbweichung.swift`, `Ruhetage.swift`, `Cardio.swift` (Modell, ohne Views) | `Gemeinsam/Modelle/` | A | `SplitsTests`, `RuhetageTests`, `CardioTests` |
| `Uebungen.swift` (`Uebung`, `UebungsKatalog`, `UebungsMedien`) und `uebungen.json` | `Gemeinsam/Modelle/Uebungen.swift`, `LumenFit/Resources/Daten/uebungen.json` | A | `UebungsKatalogTests` |
| `Ernaehrung/Ernaehrung.swift` (Typen, `ErnaehrungFaltung`, `ErnaehrungLogik`), `Ernaehrung/LebensmittelBasis.swift` und `lebensmittel-basis.json`, `Ernaehrung/ErnaehrungZiele.swift` | `Gemeinsam/Modelle/`, `LumenFit/Resources/Daten/` | A (BLS bleibt, Server-Teile raus) | `ErnaehrungTests`, `ErnaehrungMahlzeitTests`, `EssenModelleTests`, `LebensmittelBasisTests`, `LebensmittelIndexTests` |
| `Ernaehrung/ErnaehrungModell.swift`, `Ernaehrung/Fasten.swift` (Modell und `FastenLogik`) | `LumenFit/Sources/Daten/EssenStore.swift` | A | `FastenTests` |
| `Habit.swift`, `HabitLogik.swift` | `Gemeinsam/Modelle/`, `LumenFit/Sources/Daten/HabitStore.swift` | A | `HabitLogikTests` |
| `SchlafNacht.swift` (Typen, `SchlafNachtLogik`) | `Gemeinsam/Modelle/SchlafNacht.swift` | A (wird `Codable`) | `SchlafNachtTests` |
| `Koerper/Muskeln.swift` (`MuskelGruppe`, `MuskelTeil`, `MuskelLogik`) | `Gemeinsam/Modelle/Muskeln.swift` | A | `MuskelnTests` |
| `HealthModell.swift` (nur die HealthKit-Abfragen für Schritte, Distanz, Etagen, Energie, Schlaf, Vitalwerte, Gewicht, Workouts) | `LumenFit/Sources/Gesundheit/HKHealthLeser.swift` | N (Vorbild) | – |

Alles andere aus Lovea gehört dem Modul, das es braucht; die Tabelle je Modul steht im Modulauftrag.

### 5.9 Grundgerüst (vor den Modulen, ein eigener Schritt)

Das Grundgerüst baut ALLE gemeinsam genutzten Teile und legt für jedes Modul feste Stub-Dateien an, die bereits überall eingehängt sind. So bleiben `project.yml`, Tab-Leiste, Routen, Widget-Bundle und Info.plist unverändert, wenn die Module später parallel arbeiten. Idee-Nummern des Grundgerüsts: 1 bis 10 (Modul-ID `grundgeruest`). Der Auftrag dazu: `tasks/auftraege/grundgeruest.md`.

**Dateien des Grundgerüsts (Eigentümer: nur das Grundgerüst):**

```
project.yml  .gitignore  .github/workflows/{ios-ci.yml,testflight.yml}
scripts/{pruefe-privat,namen-gate,typnamen-doppelt,check-schnell,ci-fenster,ci-fehler,symbole-sammeln,testflight-fenster}.sh   (alle fertig in docs/research/vorlagen, inklusive Namens-, Typnamen- und Umfang-Gate)
signing/  (gitignored; Skripte aus docs/research/vorlagen/signing-skripte, asc.mjs aus Bahnherz kopieren)
LumenFit/LumenFit.entitlements  LumenFitWidgets/LumenFitWidgets.entitlements
LumenFit/Resources/{Assets.xcassets (AppIcon ohne Alpha, AccentColor), PrivateDaten.beispiel.json, Daten/{uebungen,splits,lebensmittel-basis}.json}
Gemeinsam/Zeit/{Datum,Uhr}.swift      Gemeinsam/Daten/{Op,JSONValue}.swift      Gemeinsam/Speicher/{JSONDatei,AppGruppe}.swift
Gemeinsam/Modelle/{Profil,Einstellungen,Ziele,Gesundheit,Training,Splits,WochenAbweichung,Ruhetage,Cardio,Uebungen,Ernaehrung,LebensmittelBasis,ErnaehrungZiele,Habit,HabitLogik,SchlafNacht,Muskeln,Lumi,Coach,Verbindung,LiveStand}.swift
Gemeinsam/Navigation/{Route,RouteURL}.swift
Gemeinsam/Design/{Farben,Abstand,Theme,Muster,LumiStimmung,LumiView,LumenBogen,LumenBalken}.swift
Gemeinsam/Bruecke/{LoveaVertrag,LoveaBruecke}.swift (beide Quellen aus 5.5, auch den Leser für Loveas `widget-stand.json`)      Gemeinsam/Widgets/{WidgetSnapshot,TrainingAktivitaet}.swift (Stubs, danach Modul widgets)
LumenFit/Sources/App/{LumenFitApp,AppRootView,LumenFitTab,Router,RouteAnsicht,AppUmgebung,Ereignis,ModulStart,Demo}.swift
LumenFit/Sources/Konto/{Schluesselbund,KeychainSchluesselbund,SpeicherSchluesselbund,Passwort,ProfilStore}.swift
LumenFit/Sources/Daten/{LokalerOpLog,LokalerRaum,DatenSatz,TrainingStore,EssenStore,HabitStore,MeilensteinStore,CoachStore,EinstellungenStore,ZieleStore,VerbindungStore}.swift
LumenFit/Sources/Gesundheit/{HealthLeser,HKHealthLeser,HealthSchreiber,HKHealthSchreiber,GesundheitsStand}.swift
LumenFit/Sources/Dienste/{HTTPLader,Mitteiler,Ports}.swift
LumenFit/Sources/Design/{Feder,HaptikZentrale,Bausteine,HeroKarte,AvatarKapsel,Hintergrund}.swift
LumenFit/Sources/Module/<Modul>/*  (Stubs, Tabelle unten)      LumenFitWidgets/Sources/LumenFitWidgetsBundle.swift
LumenFitWidgets/Sources/Widgets/{BoegenWidget,PlanSerieWidget,SperrbildschirmWidget,EssenRestWidget,HabitenWidget,TrainingLiveWidget,SchnellzugriffSteuerung}.swift  (Stubs, vom Bundle gelistet)
LumenFit/Tests/Grundgeruest/*  (TestHilfen, FixtureOrt, InfoPlistTests, Port-Tests der Datenkern-Dateien)
LumenFit/Tests/Fixtures/<Modul>/  (Ordner je Modul; Kopien aus docs/research/fixtures nach Tabelle in 11)
```

**Öffentliche Typen und Schnittstellen** (verbindlich; die Module bauen darauf; Signaturen sind Swift-6-Skizze mit `fatalError()`-Rümpfen und wurden mit `swift-syntax-check` auf Syntax geprüft, Typen prüft erst der Compiler in CI). Typen, die aus Lovea kommen (`Op`, `TrainingsPlan`, `PlanUebung`, `PlanSatz`, `GymD`, `GymSession`, `UebungsLauf`, `Uebung`, `Lebensmittel`, `EssenEintrag`, `Mahlzeit`, `Naehrwerte`, `Rezept`, `FastenPlan`, `Habit`, `SchlafNacht`, `MuskelGruppe` und ihre Logik-Enums), behalten Namen und Felder von Lovea (nur `Person` wird `ProfilID`); sie sind hier nicht noch einmal skizziert.

```swift
// ===== Gemeinsam/Modelle: Profil, Einstellungen, Ziele (von App und Widgets kompiliert) =====
import Foundation

struct ProfilID: Hashable, Codable, Sendable, RawRepresentable, Identifiable {
    var rawValue: String
    var id: String { rawValue }
    init(rawValue: String) { self.rawValue = rawValue }
    static func neu() -> ProfilID { ProfilID(rawValue: UUID().uuidString) }
}

struct PasswortSpur: Codable, Hashable, Sendable { var salz: Data; var hash: Data; var runden: Int }

struct Profil: Codable, Hashable, Identifiable, Sendable {
    var id: ProfilID
    var name: String
    var erstellt: Date
    var passwort: PasswortSpur
}

enum ThemaID: String, Codable, CaseIterable, Sendable { case monochrom, graphit, stahl, glut, wald }
enum Erscheinung: String, Codable, CaseIterable, Sendable { case system, hell, dunkel }
enum GewichtsEinheit: String, Codable, Sendable { case kg, lb }

/// Alle Felder haben Standardwerte; `init(from:)` nutzt `decodeIfPresent`.
struct Einstellungen: Codable, Equatable, Sendable {
    var thema: ThemaID = .monochrom
    var erscheinung: Erscheinung = .system
    var haptik = true
    var gewichtsEinheit: GewichtsEinheit = .kg
    var healthSchreiben = false          // Training und Gewicht nach Health (Idee 17, 30)
    var bandAktiv = false                // Idee 85, Annahme 9
    var loveaVerbunden = false           // Idee 81
    var mitteilungen: [String: Bool] = [:]
    var healthGefragt = false
    init() {}
    init(from decoder: Decoder) throws { fatalError() }
}

enum Zielart: String, Codable, Sendable { case aufbauen, halten, abnehmen }
enum Geschlecht: String, Codable, Sendable { case weiblich, maennlich, divers }

struct Ziele: Codable, Equatable, Sendable {
    var schritte = 10_000
    var aktiveKcal = 600
    var kalorien = 2_400
    var proteinGramm = 140
    var schlafMinuten = 480
    var gymTageProWoche = 3
    var wasserMl = 2_500
    var gewichtKg: Double?
    var art: Zielart = .halten
}

struct Koerperdaten: Codable, Equatable, Sendable {
    var groesseCm: Int?; var geburtsjahr: Int?; var geschlecht: Geschlecht?
}

// ===== Gemeinsam/Modelle: Gesundheit (Tageswerte aus Health; SchlafNacht kommt aus Lovea und wird Codable) =====
enum VitalArt: String, Codable, CaseIterable, Sendable { case ruhepuls, hrv, sauerstoff, atemfrequenz, temperatur, vo2max }

struct VitalMesswert: Codable, Hashable, Sendable { var art: VitalArt; var tag: String; var wert: Double }

struct TagesWerte: Codable, Hashable, Identifiable, Sendable {
    var tag: String
    var schritte: Int
    var distanzMeter: Double
    var etagen: Int
    var aktiveKcal: Double
    var trainingMinuten: Int
    var stehStunden: Int?
    var id: String { tag }
}

struct GewichtsMesswert: Codable, Hashable, Sendable { var tag: String; var kg: Double }

struct HealthWorkout: Codable, Hashable, Identifiable, Sendable {
    var id: String; var art: String; var start: Date; var ende: Date; var kcal: Double?; var puls: Double?
}

enum HealthTyp: String, CaseIterable, Sendable {
    case schritte, distanz, etagen, aktiveEnergie, training, stehen, schlaf, ruhepuls, hrv, sauerstoff, atmung, temperatur, vo2max, gewicht, puls
}

enum HealthZugriff: Sendable { case unbekannt, angefragt, verweigert, nichtVerfuegbar }

// ===== Gemeinsam/Modelle: Lumi, Coach, Verbindung, Live =====
enum LumiStimmung: String, Codable, CaseIterable, Sendable { case bereit, muede, stolz, schlaeft, denkt }

/// Antwort des Morgen-Checks (Op `fit.lumi.stimmung`): 1 bis 5, 1 = schwer, 5 = top.
struct StimmungsEintrag: Codable, Hashable, Sendable { var tag: String; var wert: Int; var stimmung: LumiStimmung }

/// Lumis Stufe 1 bis 9 aus der Zahl erreichter Meilensteine (25 Medaillen). Fortschritt zeigt den Pfad, rechnet die Stufe nicht neu.
enum LumiStufe {
    nonisolated static let schwellen = [0, 1, 3, 5, 8, 11, 15, 19, 23]    // erreichte Meilensteine ab Stufe 1 ... 9
    static func stufe(erreicht: Int) -> Int { fatalError() }
}

struct MerkEintrag: Codable, Hashable, Sendable { var text: String; var entfernt: Bool }                                   // Op fit.coach.merke
struct BandSchlafOp: Codable, Hashable, Sendable { var tag: String; var start: Date; var ende: Date; var phasen: [SchlafAbschnitt] }   // Op fit.band.schlaf
struct BandTagOp: Codable, Hashable, Sendable { var tag: String; var schritte: Int; var meter: Int }                       // Op fit.band.tag

struct MeilensteinStand: Codable, Hashable, Identifiable, Sendable { var id: String; var erreicht: Date }   // Op fit.lumi.meilenstein

enum CoachRolle: String, Codable, Sendable { case nutzer, coach }

enum CoachAktion: Codable, Hashable, Sendable {
    case antworten(String), gewohnheitAnlegen(name: String), planMorgenLeicht, oeffne(Route), nichts
}

struct CoachChip: Codable, Hashable, Identifiable, Sendable { var id: String; var text: String; var aktion: CoachAktion }

struct CoachNachricht: Codable, Hashable, Identifiable, Sendable {
    var id: String; var rolle: CoachRolle; var text: String; var zeit: Date; var chips: [CoachChip]; var daumen: Bool?
}

struct CoachKontext: Codable, Sendable {
    var tag: String; var bereitschaft: Int?; var schlafMinuten: Int?; var schritte: Int?
    var letztesTraining: String?; var stimmung: LumiStimmung; var ziele: Ziele; var merkzettel: [String]
}

struct CoachAnfrage: Sendable { var frage: String; var verlauf: [CoachNachricht]; var kontext: CoachKontext }
struct CoachAntwort: Sendable { var text: String; var chips: [CoachChip] }

enum FreigabeArt: String, Codable, CaseIterable, Sendable { case schritte, gym, schlaf, essen }
enum PartnerBereich: Sendable { case heute, schlaf }
enum PartnerEreignisArt: String, Codable, Sendable { case gymStart, gymEnde, ziel, rekord, schlafGut }
enum BandMuster: String, Codable, Sendable { case kurz, lang, doppelt, ruf, pauseEnde }

struct TagesZusammenfassung: Codable, Equatable, Sendable {
    var tag: String; var schritte: Int?; var gymTageWoche: Int?; var schlafMinuten: Int?; var kcal: Int?
}

struct PartnerEreignis: Codable, Hashable, Identifiable, Sendable { var id: String; var art: PartnerEreignisArt; var zeit: Date; var text: String }

/// Form von `zusammenfassung.json` (Lumen Fit schreibt) und `partner.json` (Lovea schreibt).
struct ZusammenfassungDatei: Codable, Equatable, Sendable {
    var version: Int; var geschrieben: Date; var profilName: String
    var freigaben: [FreigabeArt]; var heute: TagesZusammenfassung; var ereignisse: [PartnerEreignis]
}

struct BandWunsch: Codable, Hashable, Identifiable, Sendable { var id: String; var muster: BandMuster; var zeit: Date; var von: String }
struct BandStatusDatei: Codable, Equatable, Sendable { var version: Int; var geschrieben: Date; var verbunden: Bool; var akkuProzent: Int?; var name: String? }

enum PartnerStand: Equatable, Sendable {
    case nichtVerbunden
    case verbunden(ZusammenfassungDatei)
    case veraltet(ZusammenfassungDatei)
    case unbekannteVersion
}

struct FreundKarte: Codable, Hashable, Identifiable, Sendable {
    var id: String; var name: String; var woche: String; var schritte: Int; var gymTage: Int
    var schlafSchnittMinuten: Int?; var erstellt: Date; var respekt: Bool
}

/// Was die Live Activity und das Pausen-Ende brauchen (ActivityKit-Typ gehört dem Modul widgets).
struct TrainingLiveStand: Codable, Hashable, Sendable {
    var uebung: String; var satz: Int; var von: Int; var pauseEnde: Date?; var start: Date; var planName: String?
}
```

```swift
// ===== Gemeinsam/Zeit, Speicher, Navigation (von App und Widgets kompiliert) =====
import Foundation

enum Datum {                                       // aus Lovea Kalender/Logik/Datum.swift
    nonisolated static let zone: TimeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
    static func text(_ datum: Date) -> String { fatalError() }            // "2026-10-29"
    static func datum(_ tag: String) -> Date? { fatalError() }
    static func addTage(_ tag: String, _ n: Int) -> String { fatalError() }
    static func wochentag(_ tag: String) -> Int { fatalError() }          // 1 = Montag ... 7 = Sonntag
    static func wochenstart(_ tag: String) -> String { fatalError() }
}

typealias Uhr = @Sendable () -> Date

struct JSONDatei<Wert: Codable & Sendable>: Sendable {       // unverändert aus Bahnherz
    let url: URL
    init(_ url: URL) { self.url = url }
    func lade() -> Wert? { fatalError() }
    @discardableResult func speichere(_ wert: Wert) -> Bool { fatalError() }
    func loesche() {}
}

enum AppGruppe {
    nonisolated static let eigene = "group.com.onlyus.lumen-fit"
    nonisolated static let lovea = "group.com.onlyus.lovea"
    static func ordner(fallback: URL? = nil) -> URL { fatalError() }      // eigene Gruppe, sonst Application Support
    static func loveaOrdner() -> URL? { fatalError() }                    // nil ohne Signierung = nicht verbunden
}

enum GymBereich: String, Codable, Sendable { case training, plaene, fortschritt }
enum EssenBereich: String, Codable, Sendable { case heute, scan, favoriten }
enum SchlafBereich: String, Codable, Sendable { case letzteNacht, verlauf, werte }
enum ProfilBereich: String, Codable, Sendable {
    case uebersicht, einstellungen, aussehen, ziele, verbindungen, datensicherung, quellen, meilensteine, lumi
}

enum Route: Hashable, Codable, Sendable {
    case heute
    case gym(GymBereich)
    case essen(EssenBereich)
    case schlaf(SchlafBereich)
    case coach(frage: String?)
    case profil(ProfilBereich)
    case verlauf
    case gewichtEintragen
    case uebung(id: String)
    case freund(daten: String?)          // Freundeskarte importieren (Nutzlast des Links) oder die Freunde-Seite öffnen
}

/// lumenfit://heute | gym?bereich=training|plaene|fortschritt | essen?bereich=heute|scan|favoriten | schlaf?bereich=letzteNacht|verlauf|werte
/// | coach?frage=... | profil?bereich=uebersicht|einstellungen|aussehen|ziele|verbindungen|datensicherung|quellen|meilensteine|lumi
/// | verlauf | gewicht | uebung?id=... | freund?d=<Nutzlast, base64url>   (fehlender oder unbekannter bereich = erster Fall)
enum RouteURL {
    nonisolated static let schema = "lumenfit"
    static func route(aus url: URL) -> Route? { fatalError() }
    static func url(fuer route: Route) -> URL { fatalError() }
}
```

```swift
// ===== Gemeinsam/Design (SwiftUI, von App und Widgets kompiliert; Werte: docs/research/design.md) =====
import SwiftUI

enum Datenbereich: String, CaseIterable, Sendable {
    case bewegen, trainieren, erholen
    var symbolName: String { fatalError() }      // figure.run, figure.strengthtraining.traditional, bed.double.fill
    var name: String { fatalError() }
}

struct Palette: Sendable {
    let grund: Color, flaeche: Color, text: Color, text2: Color, rand: Color, haar: Color, akzent: Color, aufAkzent: Color
}

enum LumenFarben {
    static func palette(thema: ThemaID, dunkel: Bool, kontrastHoch: Bool) -> Palette { fatalError() }
    static func ring(_ bereich: Datenbereich, dunkel: Bool) -> Color { fatalError() }                           // nur auf der Platte
    static func tief(_ bereich: Datenbereich, dunkel: Bool, kontrastHoch: Bool) -> Color { fatalError() }      // Text und Linien auf Flächen
    nonisolated static let ringPlatte = Color(red: 0, green: 0, blue: 0)
}

extension EnvironmentValues {
    @Entry var palette: Palette = LumenFarben.palette(thema: .monochrom, dunkel: false, kontrastHoch: false)
}

extension View {
    /// Setzt Palette, Tint, Erscheinung und Muster-Thema aus Thema und Erscheinung.
    func lumenTheme(_ thema: ThemaID, erscheinung: Erscheinung) -> some View { self }
}

enum Abstand { nonisolated static let xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12, l: CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 32, tippflaeche: CGFloat = 44 }
enum Rundung { nonisolated static let klein: CGFloat = 10, feld: CGFloat = 12, karte: CGFloat = 16 }

enum MusterOrt: Sendable { case kopf, karte, hero }

struct MusterFlaeche: View {
    let thema: ThemaID; let ort: MusterOrt
    var body: some View { Color.clear }
}

struct LumiView: View {                         // Form und Farben: v10 aus design.html, Vorlagen docs/research/lumi/*.svg
    let stimmung: LumiStimmung; let groesse: CGFloat
    var stufe: Int = 1                          // 1 bis 9 (`MeilensteinStore.stufe`): +3 % Größe je Stufe, ab 3 Hof, ab 6 Funken
    var body: some View { Color.clear }
}

struct BogenWert: Identifiable, Sendable {
    var id: Datenbereich; var anteil: Double; var zahl: String; var beschriftung: String
}

struct LumenBogen<Mitte: View>: View {          // 270 Grad offen, Spur, Zahl daneben (design.md Abschnitt 2)
    let werte: [BogenWert]; let mitte: Mitte
    var body: some View { Color.clear }
}

struct LumenBalken: View {                      // Ersatz mit denselben Daten
    let werte: [BogenWert]
    var body: some View { Color.clear }
}
```

```swift
// ===== Ports (LumenFit/Sources/Dienste, Konto, Gesundheit): jede Fremdwelt hinter einem Protokoll mit Fake in den Tests =====
import Foundation

protocol Schluesselbund: Sendable {
    func lese(_ schluessel: String) -> Data?
    func schreibe(_ daten: Data, fuer schluessel: String) throws
    func entferne(_ schluessel: String)
}

protocol HealthLeser: Sendable {
    func zugriff(fuer typen: Set<HealthTyp>) async -> HealthZugriff
    func tagesWerte(von: String, bis: String) async -> [TagesWerte]
    func schlafNaechte(von: String, bis: String) async -> [SchlafNacht]
    func vitalwerte(_ art: VitalArt, von: String, bis: String) async -> [VitalMesswert]
    func gewichte(von: String, bis: String) async -> [GewichtsMesswert]
    func workouts(von: String, bis: String) async -> [HealthWorkout]
    /// `HKObserverQuery` mit Hintergrundlieferung: ruft `aenderung` bei neuen Daten, auch wenn iOS die App dafür im Hintergrund startet. Der Fake tut nichts.
    func beobachte(_ typen: Set<HealthTyp>, bei aenderung: @escaping @Sendable () -> Void)
}

protocol HealthSchreiber: Sendable {
    func speichere(training: GymSession) async -> Bool
    func speichere(gewichtKg: Double, am datum: Date) async -> Bool
}

protocol HTTPLader: Sendable { func lade(_ anfrage: URLRequest) async throws -> (Data, HTTPURLResponse) }

protocol Mitteiler: Sendable {
    func erlaubnisHolen() async -> Bool
    func zeige(id: String, titel: String, text: String, route: Route?) async
}

/// Gesetzt vom Modul widgets (ActivityKit). Standard: tut nichts.
protocol LiveAnzeige: Sendable { func training(_ stand: TrainingLiveStand?) async }

/// Gesetzt vom Modul gym. Die Live-Activity-Knöpfe und Siri-Kurzbefehle rufen sie auf.
@MainActor protocol TrainingSteuerung: AnyObject {
    func starte(planTag: String?)
    func satzFertig()
    func pauseAendern(sekunden: Int)
    func beende()
}

struct BandStatus: Equatable, Sendable { var verbunden: Bool; var akkuProzent: Int?; var name: String? }

/// Gesetzt vom Modul verbinden. Standard: nicht verbunden, `vibriere` tut nichts.
protocol BandDienst: Sendable {
    func status() async -> BandStatus
    func verbinde() async
    func trenne() async
    func vibriere(_ muster: BandMuster) async
}

/// Gesetzt vom Modul coach (Auswahl `CoachWahl`). Standard: Rückfalltext "Der Coach ist gleich da".
protocol CoachMotor: Sendable {
    var name: String { get }
    func verfuegbar() async -> Bool
    func antworte(_ anfrage: CoachAnfrage) async throws -> CoachAntwort
}

/// Dateivertrag mit Lovea (Abschnitt 5.5); die Umsetzung `LoveaBruecke(ordner:)` gehört dem Grundgerüst, die Regeln dem Modul verbinden.
protocol PartnerAustausch: Sendable {
    func partner(jetzt: Date) -> PartnerStand
    func schreibe(zusammenfassung: ZusammenfassungDatei)
    func wuensche() -> [BandWunsch]
    func melde(erledigt ids: [String])
    func schreibe(status: BandStatusDatei)
}
```

```swift
// ===== App-Hülle und Daten (LumenFit/Sources) =====
import Foundation
import Observation
import SwiftUI

enum Ereignis: Sendable {
    case profilGewechselt(ProfilID)
    case einstellungenGeaendert
    case trainingGestartet(session: String)
    case satzFertig(session: String, rekord: Bool)
    case trainingBeendet(session: String)
    case mahlzeitGespeichert(tag: String)
    case gewichtGespeichert(tag: String)
    case habitGeaendert(tag: String)
    case meilensteinErreicht(id: String)
    case partnerAktualisiert
    case healthAktualisiert
    case vordergrund                  // scenePhase wird .active (auch Rückkehr aus dem Hintergrund)
}

@MainActor final class EreignisKanal {
    func senden(_ ereignis: Ereignis) {}
    func strom() -> AsyncStream<Ereignis> { AsyncStream { _ in } }
}

enum LumenFitTab: String, CaseIterable, Hashable, Sendable, Identifiable {
    case heute, gym, essen, schlaf, coach
    var id: String { rawValue }
    var titel: String { fatalError() }
    var symbolName: String { fatalError() }
    static func fuer(_ route: Route) -> LumenFitTab? { fatalError() }
}

@MainActor @Observable final class Router {
    var tab: LumenFitTab = .heute
    var pfade: [LumenFitTab: [Route]] = [:]
    var blatt: Route?
    func oeffne(_ route: Route) {}
    @discardableResult func oeffne(url: URL) -> Bool { false }
}

enum Passwort {
    static func spur(fuer passwort: String, runden: Int = 600_000) -> PasswortSpur { fatalError() }
    static func stimmt(_ passwort: String, mit spur: PasswortSpur) -> Bool { fatalError() }
}

@MainActor @Observable final class ProfilStore {
    private(set) var profile: [Profil] = []
    private(set) var aktiv: Profil?
    var hatProfil: Bool { aktiv != nil }
    init(schluesselbund: any Schluesselbund, ereignisse: EreignisKanal) {}
    func anlegen(name: String, passwort: String) throws -> Profil { fatalError() }
    func wechsle(zu id: ProfilID, passwort: String) -> Bool { false }
    func pruefe(passwort: String, fuer id: ProfilID) -> Bool { false }
    func benenne(um name: String) {}
    func aenderePasswort(alt: String, neu: String) -> Bool { false }
    func loesche(_ id: ProfilID, passwort: String) -> Bool { false }
}

@MainActor @Observable final class LokalerRaum {
    let profil: ProfilID
    init(ordner: URL, profil: ProfilID) { self.profil = profil }
    func senden<T: Encodable>(_ art: String, _ d: T) {}
    func einreihen(_ op: Op) {}
    func beobachten(_ arten: Set<String>, _ f: @escaping (Op) -> Void) {}
    func ops(arten: Set<String>) -> [Op] { [] }
    func leer() async {}
}

@MainActor @Observable final class EinstellungenStore { var werte = Einstellungen(); func aendere(_ f: (inout Einstellungen) -> Void) {} }
@MainActor @Observable final class ZieleStore { var ziele = Ziele(); var koerper = Koerperdaten(); func setze(_ ziele: Ziele) {} }

@MainActor @Observable final class MeilensteinStore {
    private(set) var erreicht: [MeilensteinStand] = []
    func markiere(_ id: String) {}
    var stufe: Int { 1 }
}

@MainActor @Observable final class CoachStore {
    private(set) var verlauf: [CoachNachricht] = []
    private(set) var merkzettel: [String] = []
    func haenge(_ nachricht: CoachNachricht) {}
    func merke(_ text: String) {}
    func vergiss(_ text: String) {}
}

@MainActor @Observable final class VerbindungStore {
    private(set) var partner: PartnerStand = .nichtVerbunden
    var freigaben: Set<FreigabeArt> = []
    var freunde: [FreundKarte] = []
    var verbunden: Bool { if case .verbunden = partner { true } else { false } }
    func aktualisiere(jetzt: Date) {}
}

/// Ports von Lovea-Modellen (TrainingModell, ErnaehrungModell, Habit-Teil von HealthModell): gleiche Lese- und Schreib-Methoden
/// wie dort, ohne `Person`-Parameter, mit `raum` per Initialisierer. Hier nur der Rahmen.
@MainActor @Observable final class TrainingStore { init(raum: LokalerRaum, einstellungen: EinstellungenStore) {} }
@MainActor @Observable final class EssenStore { init(raum: LokalerRaum, ziele: ZieleStore) {} }
@MainActor @Observable final class HabitStore { init(raum: LokalerRaum) {} }

/// Alle Stores eines Profils. Wechselt das Profil, entsteht ein neuer `DatenSatz`.
@MainActor @Observable final class DatenSatz {
    let profil: ProfilID
    let ordner: URL
    let raum: LokalerRaum
    let einstellungen: EinstellungenStore
    let ziele: ZieleStore
    let training: TrainingStore
    let essen: EssenStore
    let habits: HabitStore
    let meilensteine: MeilensteinStore
    let coach: CoachStore
    let verbindung: VerbindungStore
    init(profil: ProfilID, ordner: URL, ereignisse: EreignisKanal, uhr: @escaping Uhr) { fatalError() }
}

@MainActor @Observable final class GesundheitsStand {
    private(set) var zugriff: HealthZugriff = .unbekannt
    private(set) var tage: [String: TagesWerte] = [:]
    private(set) var naechte: [String: SchlafNacht] = [:]
    private(set) var vitale: [VitalArt: [VitalMesswert]] = [:]
    private(set) var gewichte: [GewichtsMesswert] = []
    /// `band` liefert die Tage der Ops `fit.band.tag` des aktiven Profils (AppUmgebung verdrahtet es); je Tag gilt das Maximum, nie die Summe.
    init(leser: any HealthLeser, uhr: @escaping Uhr, band: @escaping @MainActor () -> [BandTagOp] = { [] }) {}
    /// Erster Aufruf holt 60 Tage (Idee 8), spätere nur das Neue.
    func aktualisiere() async {}
}

@MainActor @Observable final class AppUmgebung {
    let profil: ProfilStore
    let router: Router
    let ereignisse: EreignisKanal
    let gesundheit: GesundheitsStand
    let uhr: Uhr
    let ordner: URL
    let schluesselbund: any Schluesselbund
    let http: any HTTPLader
    let mitteiler: any Mitteiler
    let healthSchreiber: any HealthSchreiber
    let bruecke: any PartnerAustausch
    var coachMotor: any CoachMotor              // setzt das Modul coach in start()
    var liveAnzeige: any LiveAnzeige            // setzt das Modul widgets
    var trainingSteuerung: any TrainingSteuerung  // setzt das Modul gym
    var band: any BandDienst                    // setzt das Modul verbinden
    private(set) var daten: DatenSatz?          // nil, solange es kein Profil gibt
    /// Die eine Instanz der laufenden App; im Test-Host (XCTestConfigurationFilePath) eine Vorschau ohne Modulstarts.
    static let geteilt: AppUmgebung = fatalError()
    /// Module melden Aufgaben für den Hintergrund-Abruf an (BGTask `com.onlyus.lumen-fit.aktualisieren`); das Grundgerüst führt alle aus (höchstens 20 s) und plant neu.
    func beiAbruf(_ aufgabe: @escaping @MainActor () async -> Void) {}
    static func vorschau(fixtures: URL? = nil, uhr: @escaping Uhr = { Date() }) -> AppUmgebung { fatalError() }
    static func live() -> AppUmgebung { fatalError() }
    #if DEBUG
    static func demo(fixtures: URL?) -> AppUmgebung { fatalError() }      // Start-Argument -lumenFitDemo YES
    #endif
}

enum ModulStart {
    /// Synchron in `LumenFitApp.init()`: BGTask-Kennungen einmal und vor Ende des App-Starts registrieren; im Test-Host startet nichts.
    @MainActor static func starteAlle(_ umgebung: AppUmgebung) {}
    @MainActor static func saeDemo(_ umgebung: AppUmgebung) {}
}
```

```swift
// ===== LumenFit/Sources/Design: App-seitige Bausteine (Namen verbindlich, aus Bahnherz kopiert und angepasst) =====
import SwiftUI

enum Feder {                                    // gleiche Federn wie Bahnherz und Lovea
    nonisolated static let schnell: Animation = .snappy(duration: 0.28)
    nonisolated static let weich: Animation = .smooth(duration: 0.38)
    nonisolated static let federnd: Animation = .bouncy(duration: 0.42, extraBounce: 0.12)
    nonisolated static let jelly: Animation = .spring(response: 0.32, dampingFraction: 0.55)
}

enum HaptikArt: Sendable { case auswahl, start, stopp, satzFertig, mehr, weniger, pauseEnde, erfolg, stufe, fehler, warnung }

extension View {
    /// `.sensoryFeedback` mit Schalter aus den Einstellungen; nur bei klarer Ursache benutzen.
    func haptik<Ausloeser: Equatable>(_ art: HaptikArt, bei ausloeser: Ausloeser) -> some View { self }
}

struct HeroKarte<Inhalt: View>: View {          // die eine mutige Karte je Bildschirm; platte: schwarze Ringplatte
    let platte: Bool; let inhalt: Inhalt
    var body: some View { inhalt }
}

struct ListenKarte<Inhalt: View>: View {        // flache Karte, Zeilen mit Haarlinie
    let inhalt: Inhalt
    var body: some View { inhalt }
}

struct Pille: View { let text: String; let symbolName: String?; var body: some View { Text(text) } }

struct LeerZustand: View {                      // Lumi, ein Satz, eine Handlung
    let stimmung: LumiStimmung; let satz: String; let handlung: String?; let aktion: (@MainActor () -> Void)?
    var body: some View { Text(satz) }
}

struct FehlerKarte: View { let titel: String; let hilfe: String; var body: some View { Text(titel) } }

struct AvatarKapsel: View {                     // öffnet .profil(.uebersicht)
    var body: some View { Color.clear }
}

struct DiagrammKarte<Inhalt: View>: View {      // Titel ist die Aussage, darunter die Kernzeile; den Descriptor setzt der Aufrufer am Chart
    let aussage: String; let kernzeile: String; let inhalt: Inhalt
    var body: some View { inhalt }
}

struct RollZahl: View {                         // rollt nur beim ersten Anzeigen (0,8 s), danach 0,38 s bei Änderung; Reduce Motion: sofort
    let wert: Double; let format: FloatingPointFormatStyle<Double>
    var body: some View { Text(wert, format: format) }
}

struct ToastInhalt: Equatable, Sendable { var titel: String; var zeile: String?; var stimmung: LumiStimmung }

extension View {
    /// Toast mit Lumi, steht 3 s, einmal je Wert (Rekord, Meilenstein); gleitet ein, Haptik `.erfolg`.
    func lumenToast(_ inhalt: Binding<ToastInhalt?>) -> some View { self }
}
```

**Test-Hilfen des Grundgerüsts** (`LumenFit/Tests/Grundgeruest/TestHilfen.swift`, nicht ändern; eigene Helfer mit eigenem Namen im Modulordner): `TestUhr` (`lesen`, `vor(sekunden:)`), `FakeHealthLeser` (feste Reihen), `SkriptLader` (liefert Antworten aus Fixture-Dateien, zählt Aufrufe), `SpeicherSchluesselbund` (liegt in `Sources/Konto/`, weil er auch der Rückfall ist), `FakeMitteiler`, `FakeLiveAnzeige`, `FakeBandDienst`, `FakeCoachMotor`, `FakePartnerAustausch`, `XCTestCase.tempOrdner()` (frischer Ordner, wird gelöscht), `TestDaten` (erfundenes Profil "Beispiel", Beispiel-Ops für Gym, Essen, Habits), `FixtureOrt` (Fixtures nur darüber). Umgebung in Tests: `AppUmgebung.vorschau(fixtures: FixtureOrt.ordner)`; in Views: `@Environment(AppUmgebung.self) private var umgebung`.

**Abweichungen und Ergänzungen des Grundgerüsts (gebaut, CI grün; Namen und Parameter der Skizzen oben gelten sonst unverändert)**
- `Op` hat kein `seq` (`Op(id:art:von:zeit:d:)`). Wo Lovea nach `seq` entschied, gewinnt die zuletzt eingetroffene Op (`HealthFaltung.gewinner`, `HabitFaltung`); `TagesEintrag.seq` und `ZielAenderung.seq` bleiben als optionale Felder (im lokalen Log immer `nil`). Die Anlege-Reihenfolge der Habits ist die des Eintreffens.
- `Datum.datum(_:)` liefert bei kaputtem Text den 01.01.1970 statt eines Absturzes. `RouteURL` kodiert Werte selbst (nur `A-Z a-z 0-9 - . _ ~` bleiben); ein leerer Text zählt als fehlend. `Einstellungen` und `Ziele` lesen unbekannte oder falsch typisierte Werte als Standard.
- `SplitLogik.fuer(_:)` und `vorschlag(_:...)` nehmen `Geschlecht?` statt `Person` (weiblich: Gruppe "w", sonst "m"); "Für dich" sind die Splits mit ids `m-empf…`.
- Zusätzlich im Grundgerüst, weil andere Dateien sie brauchen: `MessPunkt`, `MessLogik`, `GewichtLogik`, `GewichtMittel` (`HealthLogik.swift`), `GymTageLogik`, `Mikro`, `HaushaltsMasse`, `UebungsKatalog.suchen` mit `UebungenSynonyme`, `BundleAnker` (App, für `Bundle(for:)` in Tests).
- Nicht im Grundgerüst, sondern bei den Modulen: `WorkoutLogik`, `RekordLogik`, `ZeitSchaetzung` (damit auch `GymStartLogik.umfang`), `SplitFrei`, `GymStartStand`, `KoerperWoche`, `FoodRating`, Orte und Studio, die Ansichts-Typen von Essen. Die zugehörigen Lovea-Tests stehen in `tasks/auftraege/*.md` unter "VOM GRUNDGERÜST NICHT PORTIERT".
- Test-Hilfen zusätzlich: `ProfilID.testA`, `.testB`, `.testAlle`; `SkriptLader(fixture:_:)` und `SkriptLader.fehler(_:)`; `TestDaten.gymOps`, `essenOps`, `habitOps`, `op(_:_:von:zeit:id:)`; `FixtureOrt.url/daten`.

**Stubs je Modul** (Grundgerüst legt die Dateien an; das Modul ersetzt ihren Inhalt und darf in seinem Ordner weitere Dateien anlegen). Jedes `*Modul` hat `@MainActor static func start(_ umgebung: AppUmgebung)` (idempotent) und `@MainActor static func demoSaat(_ umgebung: AppUmgebung)` (füllt für `-lumenFitDemo` ein glaubwürdiges Bild; erfundene Werte). Der Stub einer Ansicht zeigt Lumi mit "Kommt bald".

| Modul | Ordner unter `LumenFit/Sources/Module/` | Stub-Dateien und feste Typnamen |
|---|---|---|
| heute | `Heute/` | `HeuteModul`, `HeuteTabView`, `GewichtEintragenView` (Route `.gewichtEintragen`) |
| gym | `Gym/` | `GymModul` (setzt `trainingSteuerung`), `GymTabView(bereich: GymBereich = .training)` (bettet `FortschrittSegmentView` im Segment Fortschritt ein), `UebungDetailView(id:)` (Route `.uebung`) |
| fortschritt | `Fortschritt/` | `FortschrittModul`, `FortschrittSegmentView`, `VerlaufView` (Route `.verlauf`), `LumiSeiteView` (`.profil(.lumi)`), `MeilensteineView` (`.profil(.meilensteine)`), `RueckblickView` |
| essen | `Essen/` | `EssenModul`, `EssenTabView(bereich: EssenBereich = .heute)` (`.scan` öffnet den Scanner), `ScanView` |
| schlaf | `Schlaf/` | `SchlafModul`, `SchlafTabView(bereich: SchlafBereich = .letzteNacht)`, `SchlafVerlaufView` |
| coach | `Coach/` | `CoachModul` (setzt `coachMotor`), `CoachTabView(frage: String? = nil)` |
| profil | `Profil/` | `ProfilModul`, `OnboardingView`, `ProfilBlattView`, `AussehenView`, `ZieleView`, `DatensicherungView`, `QuellenView` |
| verbinden | `Verbinden/` | `VerbindenModul` (setzt `band`), `VerbindungenView`, `PartnerKarte(bereich: PartnerBereich)` (leer, wenn nicht verbunden; Heute und Schlaf betten sie ein), `FreundeView(daten: String? = nil)` (Route `.freund`) |
| widgets | `Widgets/` | `WidgetsModul` (setzt `liveAnzeige`); im Widget-Ziel die sieben Stub-Widgets aus der Dateiliste (das Bundle listet sie schon, das Modul füllt sie), in `Gemeinsam/Widgets/` `WidgetSnapshot` und `TrainingAktivitaet` |

`RouteAnsicht` (Grundgerüst, `AppRootView` benutzt es in `.navigationDestination(for: Route.self)` und für Blätter) bildet jede `Route` auf genau einen dieser Typen ab. Die Avatar-Kapsel (Grundgerüst) öffnet `.profil(.uebersicht)`.

**Verträge des Grundgerüsts:**
1. `AppUmgebung.geteilt` ist die eine Instanz (auch für Intents und Widgets-App-Seite); zwei Instanzen würden dieselben Dateien getrennt schreiben.
2. `ModulStart.starteAlle` läuft synchron in `LumenFitApp.init()`; die Ports `coachMotor`, `liveAnzeige`, `trainingSteuerung`, `band` werden dort gesetzt, nirgends sonst.
3. Daten werden über `DatenSatz` gelesen und geschrieben. Ein Modul schreibt in seine Ops-Arten; fremde Arten liest es nur.
4. Fixtures nur über `FixtureOrt` (Grundgerüst-Test-Hilfe), Dateinamen projektweit eindeutig (Präfix Modulname).
5. Ein Modul ändert nie Dateien außerhalb seiner Ordner; Wünsche an das Grundgerüst stehen im Abschlussbericht.
6. Start-Argumente für CI und Demo (Vertrag mit `ios-ci.yml`, nur Debug): `-lumenFitDemo YES` (gefüllte Demo-Daten eines erfundenen Profils, ohne Onboarding), `-lumenFitTab <heute|gym|essen|schlaf|coach>`, `-lumenFitTheme <monochrom|graphit|stahl|glut|wald>`, `-lumenFitLumi YES` (Ansicht aller fünf Stimmungen), `-lumenFitRoute <lumenfit://-Link>`, `-lumenFitFixtures <Ordner>` (Fixture-Quellen statt Netz). Ohne Argumente startet das Onboarding.
7. `Info.plist` und Entitlements sind fertig (HealthKit, zwei App Groups, Bluetooth, Kamera, Bewegung, Live Activities, Hintergrund `bluetooth-central` und `fetch`); ein Modul, das einen weiteren Schlüssel braucht, meldet es im Abschlussbericht.
8. `LumenFitApp` verdrahtet allein (Grundgerüst; Module ändern es nie): `.onOpenURL` und `.onContinueUserActivity(CSSearchableItemActionType)` rufen `router.oeffne(url:)` (die `uniqueIdentifier` eines Spotlight-Eintrags ist ein `lumenfit://`-Link, Widgets und Live Activity nutzen `widgetURL`); `scenePhase == .active` sendet `Ereignis.vordergrund`; der BGTask führt die über `beiAbruf` angemeldeten Aufgaben aus.
9. Intents: ein `LiveActivityIntent` läuft im Prozess der App, nicht im Widget. Er liegt in `Gemeinsam/Widgets/` (beide Ziele kompilieren ihn), enthält keinen App-Typ und ruft in `perform()` einen statischen `@MainActor`-Haken (wie Loveas `GymSchrittIntent.ausfuehren`), den `WidgetsModul.start` setzt; im Widget-Prozess bleibt er nil. `GymModul.start` setzt `trainingSteuerung` synchron und ohne Oberfläche, damit ein Intent die App im Hintergrund starten und `satzFertig` ausführen kann. Intents, die im Widget-Prozess laufen (`HabitAbhakenIntent`), schreiben nur Dateien in die Gruppe.
10. Darwin-Benachrichtigungen: der Rückruf ist eine C-Funktion ohne Erfassung; Zustand über einen `Unmanaged`-Zeiger, danach `Task { @MainActor in ... }`.

## 6. Design-System

Vollständig und verbindlich in `docs/research/design.md` (847 Zeilen, Kontraste nachgerechnet mit `docs/research/kontrast.py`); Ausgangspunkt ist `design.html` v9. Kern:

- **Stimmung:** Apple-monochrom. Standard-Theme Monochrom folgt dem System (hell/dunkel). Fünf Themes (Monochrom, Graphit, Stahl, Glut, Wald), jedes hell und dunkel, Tokens `grund`, `flaeche`, `text`, `text2`, `rand`, `haar`, `akzent`, `aufAkzent`. Erhöhter Kontrast ist Pflicht: `text2` wird `text`, Muster aus.
- **Drei Datenfarben wie Apple-Fitness:** Bewegen `#FA114F` (Schritte, Cardio, Energie), Trainieren `#2DBE4F` / dunkel `#A6FF00` (Gym), Erholen `#0A9FE0` / dunkel `#00E0F0` (Schlaf, HRV, Gewicht). Text und dünne Linien nehmen die Tief-Varianten (4,5:1), die Original-Werte stehen nur auf der schwarzen Ringplatte. Essen ist monochrom. Farbe trägt nie allein: Symbol, Zahl oder Muster dabei.
- **Lumen-Bögen statt Aktivitätsringe:** HIG "Activity rings" verbietet ringähnliche Elemente für andere Daten. Deshalb offene 270-Grad-Bögen mit Spur, Beschriftung und Zahl daneben, Lumi in der Mitte, Balken-Ersatz `LumenBalken`, kein Bogen im App-Icon (Annahme 15).
- **Muster je Theme:** Punkte (Monochrom), Diagonalen (Graphit), Raster (Stahl), Wellen (Glut), Höhenlinien (Wald) in Kopf, Karten (45 %) und Hauptkarte (Streifen); ein `Canvas` mit `drawingGroup()`, kein `TimelineView`; nicht hinter Diagrammen, nicht bei erhöhtem Kontrast.
- **Schrift:** SF Pro, Zahlen SF Rounded `.bold` mit `.monospacedDigit()` und `.contentTransition(.numericText())`, nur Textstile (Dynamic Type bis Accessibility 3), kleinste Schrift 12 pt, kein Gewicht unter `.regular`.
- **Liquid Glass nur für Steuerung:** Tab-Leiste, Toolbar, Sheets vom System, höchstens zwei Glas-Gruppen je Bildschirm (Scan- und Plus-Knopf, Avatar). Karten, Zeilen, Chips und der Hauptknopf (`.borderedProminent`) sind deckend. Karten flach, ohne Schatten.
- **Bewegung nur bei Ereignissen:** Tabelle in `design.md` Abschnitt 9; einzige Dauerbewegung ist die Coach-Tippanzeige (höchstens 15 s). Reduce Motion, Stromsparmodus und erhöhter Kontrast schalten Bewegung, Einfahren und Muster ab. Haptik über `.sensoryFeedback` mit Schalter.
- **Lumi:** Form und Farben sind **v10 aus `design.html`** (Ahmed: "Mag ich ist sehr gut", Lumi-Design fest), nicht der ältere Flammenpfad aus `design.md` Abschnitt 10: Locken-Tropfen, große Augen mit Doppel-Glanz, Bäckchen, Ärmchen, Füßchen, Glanzlicht, Halo. Die drei SVG-Vorlagen liegen in `docs/research/lumi/` (`lumi-bereit.svg`, `lumi-muede.svg`, `lumi-stolz.svg`, viewBox 100 x 104); der Körper wird als SwiftUI-`Path` und Formen daraus gebaut, `schlaeft` und `denkt` leiten sich von `muede` und `bereit` ab. Fünf Stimmungen (`bereit`, `muede`, `stolz`, `schlaeft`, `denkt`), Größen 24 bis 190, Stufen 1 bis 9 über `LumiView(stufe:)`, auf hellen Flächen 2-pt-Kontur, Stimmung steht auch als Text.
- **Navigation:** fünf Tabs mit Einwort-Beschriftung, höchstens Tab > Liste > Detail, Profil über die Avatar-Kapsel.
- **Texte:** Deutsch, liebevoll, klar, kurz; Fehler sagen, was schiefging und was jetzt hilft; Leerzustände mit Lumi, einem Satz und einer Handlung.
- **Abweichungen vom Entwurf v9** mit Grund: `design.md` Abschnitt 17 (zum Beispiel Essen-Donut monochrom, Hero-Nebentext ohne Dimmen, Muster-Einfahren 1,1 s statt 7 s).

## 7. Konfiguration wie Bahnherz

Vollständig in `docs/research/konfiguration.md`; die fertigen Dateien liegen in `docs/research/vorlagen/` und werden vom Grundgerüst an ihren Platz kopiert (Zuordnung dort Abschnitt 3). Kern:

| Was | Wert |
|---|---|
| App-Name | Lumen Fit (Anzeigename), SKU `lumen-fit` |
| Repo | `~/projects/lumen-fit-ios`, GitHub `Tobito320/lumen-fit-ios`, privat (zeitweise öffentlich für CI) |
| Bundle IDs | `com.onlyus.lumen-fit`, `com.onlyus.lumen-fit.widgets`, `com.onlyus.lumen-fit.tests` |
| XcodeGen | Name `LumenFit`; Ziele `LumenFit`, `LumenFitWidgets`, `LumenFitTests`; Quellen `LumenFit/Sources`, `LumenFit/Resources`, `Gemeinsam` |
| App Groups | `group.com.onlyus.lumen-fit` (eigener Stand, Widgets) und `group.com.onlyus.lovea` (Brücke); Widgets nur die eigene |
| Entitlements | `application-groups` und die drei HealthKit-Schlüssel; kein Push, kein AlarmKit; CI-Job `patterns` prüft das |
| Info.plist | beide Health-Texte, Bluetooth, Kamera, Bewegung, Live Activities, Hintergrund `bluetooth-central` und `fetch`, BGTask `com.onlyus.lumen-fit.aktualisieren`, URL-Schema `lumenfit`, beide iPad-Ausrichtungen gesetzt (Fehler 90474) |
| CI | `ios-ci.yml` und `testflight.yml` auf `macos-26`, Cache, Warnungszähler, `rm -rf derived/Build` vor dem Test-Bau, Screenshot-Schritt mit den Start-Argumenten aus 5.9 |
| Signierung | Manual Signing nur in Release; Profile "Lumen Fit App Store" und "Lumen Fit Widgets App Store"; neun Secrets (`konfiguration.md` Abschnitt 7.1) |
| Privatdatei | `LumenFit/Resources/PrivateDaten.json` (gitignored), Beispiel im Repo, Secret `PRIVATE_DATEN_JSON`, `scripts/pruefe-privat.sh` prüft die Historie |
| Namens-Gate | `scripts/namen-gate.sh`, Namensliste in `~/.config/lumen-fit/namen.txt` (außerhalb des Git, gilt in jedem Worktree); läuft in `check-schnell.sh` und vor jedem öffentlichen Fenster (`ci-fenster.sh`, streng); CI sieht die Liste nicht |

`PrivateDaten.json` (Annahme 17): Form `{version, personen:[{id, name, orte:[{name, art, adresse, breite, laenge}]}]}`. Einziger Zweck in v1: Studio-Vorgaben für Idee 29 (`art: "gym"`, Name und Öffnungszeiten-Hinweis); das Modul gym liest sie, wenn der Profilname einer `personen[].name` entspricht, und sie dürfen nie in Quelltext, Tests, Fixtures oder Commit-Texte wandern. Ohne Datei ist das Studio ein freies Textfeld.

Lehren aus Bahnherz, die gelten: `nonisolated static let` für Konstanten in `@MainActor`-Typen, die `nonisolated` Code liest; `rm -rf derived/Build`; beide Ausrichtungen in der Info.plist; Apps und App Groups legt nur das Portal an (einmal Apple-Login durch Ahmed im Agenten-Chrome, danach klickt der Agent); Tester: erst `visibleApps` für eingeschränkte Nutzer, dann Gruppe, dann je Person `betaTesters`; erste TestFlight-Läufe scheitern am Upload, nicht am Build (Log lesen).

## 8. Commands

```bash
# Lokal (Arch Linux, kein Mac, kein Swift-Compiler)
swift-syntax-check <Dateien>                  # Syntax, Sekunden
bash scripts/check-schnell.sh                 # Syntax, JSON, Shell, actionlint, Namens-Gate, Privat-Check
bash scripts/pruefe-privat.sh                 # Historie auf Privatwerte und Signierdateien
bash scripts/namen-gate.sh                    # keine Personennamen und Studios in Code, Tests, Fixtures, Commit-Texten
bash scripts/typnamen-doppelt.sh              # jeder Typname nur einmal (neun Module bauen parallel)
python3 -I docs/research/kontrast.py          # Kontrast der Tokens, Exit 0 = alle Pflichtpaare bestehen

# In CI (macOS-Runner, steht in ios-ci.yml)
xcodegen generate
xcodebuild test -project LumenFit.xcodeproj -scheme LumenFit -destination "platform=iOS Simulator,id=$IPHONE_ID" CODE_SIGNING_ALLOWED=NO   # IPHONE_ID ermittelt ios-ci.yml per simctl

# GitHub (Repo ist privat; Actions laufen nur öffentlich)
bash scripts/ci-fenster.sh                    # im Hintergrund: Privat-Check, öffentlich, Push, Lauf, danach wieder privat
timeout 590 gh run watch <ID> -R Tobito320/lumen-fit-ios --exit-status    # einmal blockierend, bei Zeitablauf wiederholen
bash scripts/testflight-fenster.sh            # nur nach grünem CI
```

## 9. Projektstruktur

```
lumen-fit-ios/
  SPEC.md CONTEXT.md CONSTRAINTS.md AGENTS.md CLAUDE.md project.yml .gitignore
  tasks/{plan.md,todo.md,auftraege/<modul>.md}      docs/{ideas/lumen-fit.md,research/}
  scripts/   .github/workflows/{ios-ci.yml,testflight.yml}   signing/ (gitignored)
  Gemeinsam/                      # von App und Widgets kompiliert
    Zeit/ Daten/ Speicher/ Modelle/ Navigation/ Design/ Bruecke/ Widgets/
  LumenFit/
    Sources/{App,Konto,Daten,Gesundheit,Dienste,Design}/   Sources/Module/{Heute,Gym,Fortschritt,Essen,Schlaf,Coach,Profil,Verbinden,Widgets}/
    Resources/{Assets.xcassets,PrivateDaten.beispiel.json,Daten/}
    Tests/{Grundgeruest,Module/<Modul>,Fixtures/<Modul>}
  LumenFitWidgets/Sources/{LumenFitWidgetsBundle.swift,Widgets/}
```

## 10. Code-Stil

Bezeichner ASCII ohne Umlaute (`muede`, `schlaeft`), deutsche Fachbegriffe wie im Glossar, Texte in der Oberfläche mit Umlauten. Reine Logik als `enum` mit `static func` (testbar ohne Oberfläche), Zustand als `@MainActor @Observable final class`, Datentypen `Sendable`, keine statischen `DateFormatter` (stattdessen `FormatStyle`), kein Default-MainActor. Ein Kommentar nur für das Warum.

```swift
enum SchlafSchuld {
    /// Summe der fehlenden Minuten gegen das Ziel, nur Nächte unter dem Ziel zählen.
    static func minuten(nachtMinuten: [Int], ziel: Int) -> Int {
        nachtMinuten.reduce(0) { $0 + max(0, ziel - $1) }
    }
}

final class SchlafSchuldTests: XCTestCase {
    func testNurFehlendeMinutenZaehlen() {
        XCTAssertEqual(SchlafSchuld.minuten(nachtMinuten: [420, 500, 360], ziel: 480), 60 + 120)
    }
}
```

### Fallen (Swift 6, iOS 26), vor dem Schreiben lesen

- `HKHealthStore` und `CBCentralManager` sind nicht `Sendable`: nur im Port-Objekt halten (`HKHealthLeser`, `TrackerFunk` mit eigener serieller Queue und `Sendable`-Ereignissen); `@unchecked Sendable` nur mit einzeiligem Grund.
- `Activity<...>` ist nicht `Sendable`; `Activity.request` geht nur im Vordergrund (Siri, Steuerelement und Kurzbefehle öffnen die App: `openAppWhenRun`).
- App Intents: `perform()` auf `@MainActor`, wenn sie Stores berühren; `AppShortcutsProvider` nur im App-Ziel; jede Phrase enthält `\(.applicationName)`; Intent-Typen in `Gemeinsam/` enthalten keine App-Typen (Vertrag 9).
- FoundationModels: alle Aufrufe in einer Datei hinter `#if canImport(FoundationModels)`; das Kontextfenster ist klein (rund 4.000 Token): Verlauf kürzen, jede Fehlerart (Kontext zu groß, Sicherheitsfilter, Sprache nicht unterstützt, Modell nicht bereit) fällt auf den Regelmotor.
- `ImageRenderer` nur auf dem `MainActor`, `scale` setzen. `DataScannerViewController.isSupported` und `isAvailable` prüfen (im Simulator nie verfügbar). `SectorMark` für den Donut, `accessibilityChartDescriptor` am Chart.
- Countdown nur mit `Text(timerInterval:)` und `ProgressView(timerInterval:)` (das System tickt, kein Update nötig).
- BGTask-Kennungen früh registrieren (Vertrag 2); der Abruf ist nicht garantiert, nichts darf davon abhängen.
- `UserDefaults` ist kein Speicher für Profildaten (Lovea-Altlast beim Band: dort nur für Gerätekennung und Schalter).
- `@Entry`-Standardwerte und alle Konstanten, die `nonisolated` Code liest, sind `Sendable` bzw. `nonisolated static let`.

## 11. Teststrategie

- **Ein Test-Ziel** `LumenFitTests` (XCTest, `@testable import LumenFit`), eine Datei je Thema, Fixtures als Ordnerreferenz im Test-Bundle (`Fixtures/<Modul>/<datei>`), Dateinamen projektweit eindeutig (Präfix Modulname), geladen nur über `FixtureOrt`. Ein Rauchtest als UI-Test höchstens im Integrationsschritt.
- **Portierte Tests** aus Lovea sind der Grundstock (Abschnitt 5.8); sie laufen mit dem Code, den sie schützen.
- **Nähte (Matt Pocock to-spec, wenige und hohe):** (1) `LokalerRaum` mit Temp-Ordner: Faltungen und Stores gegen echte Ops; (2) `HealthLeser` mit `FakeHealthLeser`; (3) `HTTPLader` mit `SkriptLader` und den echten, gekürzten Antworten aus `docs/research/fixtures`; (4) `Schluesselbund` mit `SpeicherSchluesselbund`; (5) `PartnerAustausch` mit `LoveaBruecke(ordner: Temp)` und Fixtures; (6) injizierte `Uhr`; (7) `Mitteiler`, `BandDienst`, `CoachMotor`, `LiveAnzeige` als Fakes.
- **Fixture-Zuordnung** (kopiert das Grundgerüst aus `docs/research/fixtures`): `Essen/` bekommt `bls-4-0-lovea-auszug.json`, `off-v2-product-4008400402222.json`, `off-v2-product-nicht-gefunden.json`, `off-search-haferflocken.json`, `off-cgi-search-haferflocken.json`; `Gym/` bekommt `lovea-uebungen-auszug.json`, `free-exercise-db-3.json`, `wger-exerciseinfo-de.json`, `wger-language.json`; `open-meteo-forecast-berlin.json` und `usda-fdc-search-oats.json` bleiben unbenutzt. `Verbinden/` schreibt das Modul selbst (`zusammenfassung-beispiel.json`, `partner-beispiel.json`, `band-wuensche-beispiel.json`, `lovea-widget-stand-beispiel.json` mit erfundenen Kennungen); die Fixtures für die Leser in `LoveaBruecke` legt das Grundgerüst unter `LumenFit/Tests/Fixtures/Grundgeruest/` an.
- **Gute Tests** prüfen Verhalten an der Naht (Eingabe, Ausgabe, Zustandsänderung). Zeitlogik an Sommer-/Winterzeit-Rändern und um Mitternacht. Jede neue Logik bekommt zuerst einen roten Test.
- **Automatische Prüfungen:** Symbole (`UIImage(systemName:) != nil`, `SymbolNamenTests`), Kontrast der Tokens (`FarbenKontrastTests`, Port von `kontrast.py`), `InfoPlistTests` (Schlüssel, keine AlarmKit), Warnungen null, Privat-Check, Namens-Gate, `AlteDateienLadenTests`, Schlüsselbund-Fake gegen Neuinstallations-Fall, Passwort-Hash gegen bekannte Werte.
- **Ungeprüft ohne Gerät:** Aussehen (Glas, Canvas-Muster, Charts), HealthKit-Werte, Foundation Models, Kamera-Scan, Band, Live Activity und Widgets im Hintergrund, App-Group-Austausch mit Lovea, Schlüsselbund nach Neuinstallation, Review-Urteil zu den Bögen. Diese Punkte stehen als Testliste in `tasks/plan.md`.

## 12. Module und Bauplan

Das Anliegen bündelt neun unabhängig testbare Fähigkeiten. Jedes Modul hängt nur vom Grundgerüst ab (keine Kanten zwischen Modulen zur Bauzeit; Querverweise gehen über die Stub-Typnamen aus 5.9).

| Modul-ID | Verantwortung | Ideen | Ordner (nur dieses Modul) |
|---|---|---|---|
| heute | Heute-Tab: Ringplatte, Score, Plan, Energie, Habits, Gewicht, Schritte, Hinweise | 11 bis 20 | `LumenFit/Sources/Module/Heute/`, `LumenFit/Tests/Module/Heute/`, `LumenFit/Tests/Fixtures/Heute/` |
| gym | Gym-Tab: Training, Logging, Timer, Rekorde, Katalog, Pläne, Cardio, Studio | 21 bis 30 | `LumenFit/Sources/Module/Gym/`, `LumenFit/Tests/Module/Gym/`, `LumenFit/Tests/Fixtures/Gym/` |
| fortschritt | Kraftkurve, Körperkarte, Raster, Gewicht, Meilensteine, Lumi-Seite, Rückblicke | 31 bis 40 | `LumenFit/Sources/Module/Fortschritt/`, `LumenFit/Tests/Module/Fortschritt/`, `LumenFit/Tests/Fixtures/Fortschritt/` |
| essen | Essen-Tab: Tagebuch, Scan, Quellen, Ampel, Fasten, Ziele, Analyse | 41 bis 50 | `LumenFit/Sources/Module/Essen/`, `LumenFit/Tests/Module/Essen/`, `LumenFit/Tests/Fixtures/Essen/` |
| schlaf | Schlaf-Tab: Nacht, Phasen, Schuld, HRV, Werte, Woche, Quellen | 51 bis 60 | `LumenFit/Sources/Module/Schlaf/`, `LumenFit/Tests/Module/Schlaf/`, `LumenFit/Tests/Fixtures/Schlaf/` |
| coach | Coach-Tab: Motoren, Ton, Gedächtnis, Chips, Morgen-Check | 61 bis 70 | `LumenFit/Sources/Module/Coach/`, `LumenFit/Tests/Module/Coach/`, `LumenFit/Tests/Fixtures/Coach/` |
| profil | Onboarding, Profil-Blatt, Aussehen, Ziele, Sicherung, Quellen, Datenschutz, Export | 71 bis 80 | `LumenFit/Sources/Module/Profil/`, `LumenFit/Tests/Module/Profil/`, `LumenFit/Tests/Fixtures/Profil/` |
| verbinden | Lovea-Brücke, Partner-Karte, Mitteilungen, Band, Freundeskarten | 81 bis 90 | `LumenFit/Sources/Module/Verbinden/`, `LumenFit/Tests/Module/Verbinden/`, `LumenFit/Tests/Fixtures/Verbinden/` |
| widgets | Widgets, Live Activity, Intents, Siri, Spotlight, Steuerelement | 91 bis 100 | `LumenFit/Sources/Module/Widgets/`, `LumenFit/Tests/Module/Widgets/`, `LumenFit/Tests/Fixtures/Widgets/`, `LumenFitWidgets/Sources/Widgets/`, `Gemeinsam/Widgets/` |
| grundgeruest | Projekt, Datenkern, Design, Konto, Stubs (kein Modul, vor den Modulen) | 1 bis 10 | Abschnitt 5.9 |

Bauordnung: Grundgerüst, danach alle neun Module gleichzeitig in eigenen Worktrees (Zweig `modul/<id>`), danach Integration (Zusammenführen, CI, Barrierefreiheits-Durchgang, Signierung, TestFlight). Die Ordnerlisten sind paarweise disjunkt (Skriptprüfung steht in `tasks/plan.md`). Tickets mit Blockierkanten: `tasks/todo.md`; vollständige Aufträge: `tasks/auftraege/<id>.md` (die Datei im Worktree ist maßgeblich; das Grundgerüst zieht sie nach dem echten Code nach).

## 13. Akzeptanzkriterien (gesamt)

1. `ios-ci.yml` läuft grün (xcodegen, alle Tests, 0 Compiler-Warnungen) auf dem zusammengeführten Stand; `testflight.yml` lädt einen Build; die Tester der Gruppe "Wir" installieren ihn.
2. Profil anlegen (Name, Passwort), App neu starten und per TestFlight aktualisieren: kein Anmeldebildschirm. Nach Löschen und Neuinstallation erkennt die App das Profil und bietet die Datensicherung an (am Gerät zu prüfen).
3. Alle 100 Ideen sind eingebaut oder in `tasks/todo.md` mit Grund als "nicht umsetzbar" markiert; keine fehlt stumm.
4. Fünf Themes, hell und dunkel, wechseln sofort; `FarbenKontrastTests` grün; Standard ist Monochrom.
5. Gym: Training starten, Satz mit "Letztes Mal", Satztyp, RPE, Pause startet von selbst, Rekord-Toast, Scheibenrechner; Live Activity mit "Satz fertig".
6. Essen: Scan oder Texteingabe findet ein Lebensmittel aus BLS oder Open Food Facts, Ampel mit Symbol und Text, Quellen-Seite nennt BLS (CC BY 4.0) und Open Food Facts (ODbL).
7. Schlaf und Heute zeigen Werte aus Health, im Leerzustand eine Handlung; Diagramme haben `accessibilityChartDescriptor` und eine Kernzeile.
8. Coach antwortet mit beiden Motoren; die Ton-Tests (Länge, "du", keine Diagnose, kein "Als KI") sind grün.
9. Nicht verbunden: keine Partner-Teile, keine Platzhalter, keine Fehlermeldung. Verbunden (Fixture-Dateien für Quelle A und Vertrag B): Partner-Karte, Mitteilungen, Freigaben. Am Gerät mit installiertem Lovea: die Partner-Karte zeigt ohne Änderung an Lovea Schritte, Gym und Schlaf der Partnerin.
10. Das Band ist standardmäßig aus; ohne den Schalter entsteht kein `CBCentralManager`.
11. Kein Wecker, keine Erinnerung: `git grep -n -E 'AlarmKit|UNCalendarNotificationTrigger' -- LumenFit/Sources LumenFitWidgets/Sources Gemeinsam` ist leer (läuft in `check-schnell.sh` und im Job `patterns`; Tests dürfen den Schlüsselnamen prüfen), `NSAlarmKitUsageDescription` fehlt.
12. Barrierefreiheit: VoiceOver-Sätze, Dynamic Type bis Accessibility 3, Reduce Motion, erhöhter Kontrast, Tippflächen mindestens 44 pt.
13. Kein Git-Commit und kein Log enthält einen Personennamen, eine Adresse oder einen Ort aus `PrivateDaten.json`; `bash scripts/pruefe-privat.sh` und das Namens-Gate sind sauber.
14. Lovea ist unverändert (`git -C ~/projects/lovea-app-ios rev-parse HEAD` und `status --short` vor und nach dem Bau gleich).
15. Die App sendet nichts an Menschen, kauft nichts, speichert keine Zugangsdaten außer dem eigenen Profil.
16. Typnamen sind eindeutig (`bash scripts/typnamen-doppelt.sh`), jede `fit.*`-Op hat genau einen Rumpf-Typ aus 5.3.

## 14. Grenzen

- **Immer:** Test zuerst; `CONSTRAINTS.md` lesen; nur eigene Modulordner ändern; Texte Deutsch ohne Emojis; Fehler mit Handlung; Reduce Motion beachten; ehrlich berichten, was nur ein Compiler oder ein Gerät beweist.
- **Vorher klären (Agent entscheidet selbst und notiert unter Annahmen):** neue Info.plist-Schlüssel, Änderungen an gemeinsamen Dateien, Abweichungen vom Design.
- **Nie:** Lovea ändern; Nachrichten oder Mails an Menschen senden; kaufen, bezahlen, Abos; Einwilligungen annehmen; Geheimnisse, Namen Dritter oder Adressen ins Git; Passwörter im Klartext speichern; Wecker oder Erinnerungen bauen; `/mnt/windows` verändern; GitHub-Billing vorschlagen.

## 15. Annahmen

1. **Name:** "Lumen Fit" (Marke Lumen, ohne Herz) ist der Arbeitsname; ist er im App Store vergeben, kommt ein Zusatz (Anzeigename auf dem Gerät bleibt).
2. **Client-only statt Konto-Server:** Der ältere Spec-Entwurf nannte Cloudflare Worker und D1 mit Konten. Verworfen, weil Ahmeds Satz nur ein einfaches Profil mit Passwort verlangt, die drei Recherchen kein Backend brauchen und der Auftrag "ganz normal" ohne Verbindung verlangt. Kein Teil der 100 Ideen braucht einen Server. Konto-Server und Live-Feed sind Nicht-Ziele (Abschnitt 17).
3. **Wecker, Erinnerungen, Töne, Wiege-Erinnerung:** nicht in Lumen Fit, auch nicht als Einzelfunktion (kein Wasser-, Trainings- oder Schlaf-Erinnern). Der Morgen-Check (Idee 67) erscheint nur beim Öffnen, nie als geplante Mitteilung. Die spätere Zeile im Auftrag schlägt die ältere Umfangsliste.
4. **Datenkern = lokaler Op-Log:** Loveas Ops, Faltungen und Tests werden übernommen, der Transport wird lokal (Abschnitt 5.3). Die Faltungs-Dauer bei sehr vielen Ops ist nicht gemessen.
5. **Neuinstallation:** Profil und Passwort-Spur überleben meist (Schlüsselbund); Trainings, Essen und Habits nicht, es sei denn eine Datensicherung wird eingespielt. Health-Verlauf kommt aus Health zurück. Ob iOS den Eintrag nach dem Löschen behält, ist am Gerät zu prüfen.
6. **Passwort:** Mindestlänge 4; es schützt nur lokale Handlungen (Wechsel, Ändern, Löschen); es gibt keinen Rückweg per Mail. Der Start fragt nie danach.
7. **Lovea-Kopplung:** Dateivertrag in `group.com.onlyus.lovea` (5.5). Die App-ID von Lumen Fit bekommt beide Gruppen, Loveas App-IDs bleiben unberührt. Loveas Hälfte (Dateien schreiben und lesen, Paar-Karten, Verkleinerung) ist eine spätere Lovea-Runde.
8. **Kein Push:** Mitteilungen über Partner-Ereignisse sind lokal und kommen, wenn Lumen Fit läuft oder der Hintergrund-Abruf es weckt. Echtzeit liefert Loveas eigener Push. Echter Push für Lumen Fit bräuchte Server, `PUSH_NOTIFICATIONS` und neue Profile.
9. **Band:** opt-in, Standard aus, solange Lovea den Band-Code behält (das Band nimmt eine Verbindung). Ob iOS zwei Apps dieselbe Verbindung teilen lässt, ist ungeprüft; die Warteschlange über die Gruppe ist der sichere Weg.
10. **Coach:** Apple Foundation Models nur mit Apple Intelligence; nicht jedes Gerät hat sie, deshalb ist der Regel-Coach vollwertig. Typnamen von FoundationModels sind am Compiler und in der Apple-Doku zu prüfen. Der Coach gibt keine medizinischen Ratschläge.
11. **Freunde:** ohne Server nur als geteilte Wochenkarte (Bild, Link, QR); keine Live-Rangliste.
12. **Zeit und Sprache:** Zeitzone Europe/Berlin (wie Lovea), App-Sprache Deutsch.
13. **Muskelkarte:** `muskelkarte.json` (AGPL-3.0, openGym) wird nicht übernommen; die Silhouette wird neu gezeichnet. Ahmed kann das umkehren, wenn er die Lizenz geklärt hat.
14. **Übungsbilder:** wie in Lovea von der ExerciseDB-CDN geladen und gecacht, nie gebündelt; die Medien-Lizenz ist ungeklärt. Ohne Bild erscheint ein Symbol.
15. **Bögen statt Ringe:** Ob App Review die Lumen-Bögen beanstandet, ist ungeprüft; Ersatz `LumenBalken` ist vorbereitet.
16. **Design-Annahmen** aus `design.md` Abschnitt 18 (neun Punkte: neu entworfene Modi, Dunkel-Vorwahl von Graphit und Glut, keine Personennamen, schwarze Ringplatte, Lumi-Stufenmodell, deckender Hauptknopf, Gewichtsverlauf in Erholen, Habits/Cardio/Check-in-Orte, monochromer Donut) gelten hier mit.
17. **`PrivateDaten.json`:** Form wie Bahnherz, einziger Zweck Studio-Vorgaben; ohne Datei läuft alles. Braucht Ahmed sie nicht, streicht der Integrationsschritt sie nach `konfiguration.md` 7.3.
18. **"Gym nicht original":** als Bemerkung zum Namen gelesen, nicht als Funktionsvorgabe.
19. **Health schreiben:** Training, Gewicht nach Health nur auf Schalter, Standard aus (Idee 17, 30).
20. **Apple-Login:** App-Eintrag und App Group legt das Portal an; Ahmed loggt sich einmal im Agenten-Chrome ein (Fernfunk-Aufgabe, wenn CI grün ist), danach klickt der Agent allein.
21. **Vornamen im Zitat:** Der 1:1-Auftragstext oben enthält den Vornamen der Partnerin; Ahmed steht als Auftraggeber im Text. Alles andere in Spec, Plan, Ideen und Code sagt "Partner" und "Freund", der Quelltext enthält gar keinen Namen (Namens-Gate).
22. **Import aus Lovea:** wegen der gleichen Op-Form später möglich (Lovea-Export als `ops.jsonl`), nicht in v1.
23. **Quelle A (Loveas `widget-stand.json`):** das Format gehört Lovea und kann sich ändern; Lumen Fit liest nur Schritte, Gym-Woche, Schlaf und Ziele, alles optional, und zeigt bei Abweichung "nicht verbunden". Die Partnerin sieht in Lumen Fit nichts, was Lovea nicht ohnehin auf demselben Gerät zeigt. Echtzeit-Mitteilungen gibt es nur beim Öffnen und im Hintergrund-Abruf.
24. **Band-Schritte und -Schlaf:** der Schlaf des Bandbesitzers kommt nur vom Band (Lovea schreibt ihn nicht nach Health), seine Schritte kommen vom Band und vom iPhone (das Maximum zählt). Solange das Band in Lumen Fit aus ist, gibt es keine Band-Nächte und die iPhone-Schritte zählen allein. Ob Lumen Fit die Verbindung mitbenutzen kann, die Lovea hält, ist am Gerät zu prüfen (Testliste 11).
25. **Lumi-Form:** v10 aus `design.html` gilt; `design.md` Abschnitt 10 beschreibt nur noch die Stimmungen und Größen. Stufen-Schwellen (0, 1, 3, 5, 8, 11, 15, 19, 23 Meilensteine) sind eine Annahme.
26. **Open-Food-Facts-Kennung:** der User-Agent trägt die Repo-Adresse statt einer Mail (keine Mail im Quelltext); eine Mail käme nur über `PrivateDaten.json`.
27. **Namens-Gate:** die Namensliste liegt außerhalb des Git, damit nirgends im Repo ein Name steht (einzige Ausnahme: das Zitat in Abschnitt 0); CI sieht sie nicht, das Gate läuft lokal und streng vor jedem öffentlichen Fenster.
28. **Health-Zugriff-Seite:** zeigt "Daten da" oder "keine Daten", nie "erlaubt" oder "abgelehnt" für Lesetypen (HealthKit verrät es nicht).
29. **Sicherung auf neues Gerät:** beim Einspielen werden die Ops dem Zielprofil zugeordnet (`von` wird umgeschrieben), sonst wären sie für das neue Profil unsichtbar. Die Sicherung ist eine Datei, kein Dienst: wer sie nie zieht, verliert Trainings bei einer Neuinstallation.
30. **Kein `seq` im lokalen Log:** Faltungen entscheiden nach Eintreffen der Ops (die zuletzt eingetroffene gewinnt). Das ist im einen lokalen Log eindeutig; bei einem späteren Import fremder Ops (Annahme 22) muss die Reihenfolge der Quelle erhalten bleiben.
31. **App-Icon:** ein einzelner offener Bogen mit grünem Punkt auf Schwarz, wie `design.md` Abschnitt 10 es erlaubt (einzelne Form, kein Ringsatz). Die Zeile in Abschnitt 6 ("kein Bogen im App-Icon", Annahme 15) widerspricht dem; ob Review den Bogen beanstandet, ist ungeprüft, der Ersatz ist ein Lumi-Icon (nur die PNG tauschen).

## 16. Offene Punkte und Folgearbeit

Für Ahmed (Fernfunk-Aufgabe, nicht Lovea-Notiz): einmal Apple-Login im Agenten-Chrome, wenn der Agent meldet, dass CI grün ist (Schritt I3 in `tasks/plan.md`).

Folgearbeit in Lovea (eigene Runde, nicht Teil dieses Baus; bis dahin liefert Quelle A die Partner-Karte): `zusammenfassung.json` lesen und `partner.json` schreiben, `band-wuensche.json` schreiben und `band-status.json` lesen, Band-Code und Health-Module entfernen, Paar-Karte Schritte-Duell auf die Dateien umstellen, App-ID von Lumen Fit prüfen (beide Gruppen).

## 17. Nicht-Ziele

Wecker, Erinnerungen, Töne (eigene App); Konto-Server, Anmeldung über das Netz, Passwort-Reset per Mail; Live-Freunde-Feed, Wettbewerbe, Push von Gerät zu Gerät; Apple Watch, iPad, Mac, Android; Fitness+-artige Videos; ECG, biologisches Alter, Blutdruck, Glukose; Foto-Erkennung ganzer Mahlzeiten durch ein Modell; Kaufen, Abos, Werbung; Zyklus-Daten (bleiben in Lovea); Chat, Snaps, Karte, Kalender, Dates, Figur, Shop, Spiele (bleiben in Lovea).
