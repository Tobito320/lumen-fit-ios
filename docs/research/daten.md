# Lumen Fit – Datenquellen-Recherche (Stand 2026-10-29, live mit curl von diesem Rechner geprüft)

Frage: Welche kostenlosen Quellen, Apple-Frameworks und APIs braucht Lumen Fit laut Auftrag, ohne Schlüssel wo möglich, und welche ist primär, welche Rückfall?

Grundlage: Auftrag (Gym, Essen mit Scan, Schlaf, Schritte, Habits, Coach, Verlauf, Widgets, Live Activity, Band, Lovea-Kopplung, Profil mit Passwort), Lovea-Quellcode `~/projects/lovea-app-ios` (was dort schon läuft). Messungen: eine Anfrage je Pfad bis wenige Wiederholungen. Rate-Limits wurden nicht provoziert (IP-Sperre vermeiden), sondern aus der Anbieter-Doku gelesen.

## Ergebnis in einem Satz

Nur Apple-Frameworks plus drei freie Datenquellen, alle ohne Schlüssel: Essen = BLS 4.0 (offline, aus Lovea) + Open Food Facts (online), Übungen = Lovea-Katalog (offline) + Bilder von der ExerciseDB-CDN mit Rückfall free-exercise-db (Unlicense). Coach = Apple Foundation Models auf dem Gerät mit regelbasiertem Rückfall. Kein eigener Server nötig für v1.

## Empfehlung auf einen Blick

| Bereich | Primär | Rückfall |
|---|---|---|
| Lebensmittel generisch (Haferflocken, Ei, Reis) | BLS 4.0 gebündelt, offline, 7.140 Einträge | USDA FoodData Central (nur englisch, Schlüssel nötig, nicht empfohlen) |
| Lebensmittel verpackt (Barcode) | Open Food Facts v2 `GET /api/v2/product/<code>.json` | zuletzt gespeicherter Treffer im Gerät; Eingabe von Hand; (optional später Lovea-Worker mit OFF-DACH-Kopie) |
| Lebensmittel Textsuche | BLS lokal zuerst, dann `search.openfoodfacts.org/search` nur auf Absenden | alte Suche `world.openfoodfacts.org/cgi/search.pl` (flackert, siehe unten) |
| Übungskatalog (Namen, Muskeln, Geräte) | Lovea `uebungen.json`, 1.333 Übungen mit deutschen Namen, offline | wger API `language__code=de` (636 Übungen mit deutschem Text, CC-BY-SA) |
| Übungsbilder | ExerciseDB-CDN `static.exercisedb.dev/media/<id>.gif`, einmal laden, in Caches | free-exercise-db JPGs (Unlicense), 876 Übungen, nur 132 exakte Namenstreffer mit Lovea |
| Schritte, Schlaf, Puls, HRV, Gewicht, Training | HealthKit (Apple) | manuelle Eingabe in der App |
| Gym-Training live (Puls, Kalorien) | HKWorkoutSession + HKLiveWorkoutBuilder (iOS 26) | ohne Live-Daten: Training nur in der App-Datenbank |
| Coach (menschlich, kurz) | Foundation Models (SystemLanguageModel, Gerät, iOS 26) | regelbasierte deutsche Textbausteine; Cloud-Modell nur über Lovea-Worker, wenn gekoppelt |
| Karten, Widgets, Live Activity | WidgetKit, ActivityKit, App Intents | (keiner nötig) |
| Band (Bluetooth) | CoreBluetooth, `retrieveConnectedPeripherals` über App Group | Anfragen-Warteschlange in App Group plus Darwin-Benachrichtigung |
| Profil und Anmeldung bleibt | Keychain `kSecAttrAccessibleAfterFirstUnlock` plus `kSecAttrSynchronizable` | (keiner) |
| Wetter für Draußen-Cardio (optional, nicht im Auftrag) | Open-Meteo | weglassen |

## 1. Essen

### 1a. BLS 4.0 (Bundeslebensmittelschlüssel) – primär für Grundlebensmittel

- Quelle: https://www.blsdb.de/ (Max Rubner-Institut). Seite sagt wörtlich: Version 4.0 "erstmals ohne Lizenzbarrieren", 7.140 Lebensmittel, 138 Nährstoffe. Lizenz laut Lovea-Import-Skript: CC BY 4.0, Namensnennung "MRI" in der App unter Einstellungen/Quellen nötig.
- Schon fertig in Lovea: `~/projects/lovea-app-ios/Lovea/Sources/Health/Ernaehrung/lebensmittel-basis.json` (5,3 MB, 7.140 Einträge, alle `quelle: "bls"`, pro 100 g mit kcal, Protein, Kohlenhydrate, Fett, Zucker, Ballaststoffe, Salz, gesättigte Fette, Mikronährstoffe). Import-Skript `tools/bls-import/bls_import.py` plus Portionsregeln `tools/bls-import/portionen.json` (Test `test_bls_import.py`). Suche (Präfix und Suffix für deutsche Komposita): `LebensmittelBasis.swift`.
- Antwortzeit: lokal, 0 ms Netz. Läuft im Gym ohne Empfang.
- Fixture: `fixtures/bls-4-0-lovea-auszug.json` (3 Einträge, Mikros gekürzt).
- Risiko: nur Grundlebensmittel, keine Marken.

### 1b. Open Food Facts – primär für Barcode und Marken

- Basis: `https://world.openfoodfacts.org/api/v2/product/<barcode>.json?fields=...`. Kein Schlüssel. CORS offen.
- Messung (heute, 6 Aufrufe): HTTP 200 in 0,12 bis 0,15 s, Antwort 2,8 bis 3,3 KB mit `fields`. Beispiel 4008400402222 (Duplo-Packung): `energy-kcal_100g` 539, `carbohydrates_100g` 57,5, Portionswerte `_serving` vorhanden. Fixture: `fixtures/off-v2-product-4008400402222.json`.
- Unbekannter, aber gültig aufgebauter Barcode: HTTP 404 mit `{"status":0,"status_verbose":"product not found"}`. Ungültiger Code (nur Nullen): HTTP 200 mit `status:0` – beides als "unbekannt" behandeln, nicht als Fehler. Fixture: `fixtures/off-v2-product-nicht-gefunden.json`. Von 5 Test-Barcodes (DE) waren 4 vorhanden, 1 (4014400900057) unbekannt: Lücken sind normal, Handeingabe nötig.
- Parsing-Fallen (aus echten Antworten): `energy-kcal_100g` fehlt bei manchen Produkten, dann nur `energy-kj_100g` (kcal = kJ / 4,184); Suchtreffer haben nicht immer alle Nährwerte; in der alten Suche ist `count` ein String, in der neuen eine Zahl. Lovea fängt das schon in `ErnaehrungLogik.offProdukt` und `offSuche` ab (Datei `Lovea/Sources/Health/Ernaehrung/ErnaehrungModell.swift`, `enum OFFClient`).
- Limits (Doku https://openfoodfacts.github.io/openfoodfacts-server/api/): 15 Anfragen/min je IP für Produkt-Lesen, 10/min je IP für Suchen. Bei Mobil-App zählt es je Nutzer-IP, also je Gerät: für Scan im Alltag unkritisch. Keine Suche beim Tippen. Pflicht: eigener User-Agent im Format `AppName/Version (Kontakt)`, Daten unter ODbL (Quelle nennen, Nutzungsformular der OFF-Doku ausfüllen). Massenabruf nur über Dump.
- Dump: `https://static.openfoodfacts.org/data/openfoodfacts-products.jsonl.gz` leitet (302) auf S3 weiter. Lovea hat daraus eine DACH-Kopie in D1 (`server/essen.js`, `tools/essen-import`); für v1 ohne Server nicht nötig.

### 1c. Open Food Facts Textsuche

- Neu: `https://search.openfoodfacts.org/search?q=<text>&page_size=30&langs=de&fields=code,product_name,brands,nutriments`. HTTP 200 in 0,13 bis 0,21 s, 27 KB ohne `fields`, 1,5 KB mit. Suchtreffer enthalten `nutriments` mit `_100g`-Werten. "haferflocken" ergab 381 Treffer. Fixture: `fixtures/off-search-haferflocken.json`.
- Beobachtet: genau 1 von 10 Aufrufen heute lieferte HTTP 500 (nginx-Fehlerseite, erster Aufruf nach Pause, nach 1,3 s); Wiederholung klappte sofort. Client braucht einen Wiederholversuch und eine Fehleranzeige.
- Rückfall alt: `https://world.openfoodfacts.org/cgi/search.pl?search_terms=...&json=1`. Heute 2 von 7 Aufrufen lieferten JSON (0,64 s); die anderen 5 HTTP 503 "Page temporarily unavailable" (HTML statt JSON), darunter 3 Wiederholungen hintereinander. Fixture: `fixtures/off-cgi-search-haferflocken.json`. Nur als letzte Stufe, nie als Hauptweg.

### 1d. Verworfen oder nur Notiz

- USDA FoodData Central (`https://api.nal.usda.gov/fdc/v1/foods/search`): Mit `DEMO_KEY` HTTP 200 in 1,3 s, Header `x-ratelimit-limit: 10`; eigener Schlüssel (kostenlos) wäre in der App für alle Nutzer geteilt, Namen sind englisch, deutsche Produkte fehlen. Nicht empfohlen. Fixture: `fixtures/usda-fdc-search-oats.json` (nur zur Referenz).
- Open EAN/GTIN-Datenbank (opengtindb.org): Lovea nutzt sie serverseitig nur für Produktnamen, Schlüssel nötig, in v1 weglassen.

## 2. Übungen und Gym

### 2a. Katalog – primär Lovea, offline

- `~/projects/lovea-app-ios/Lovea/Sources/Health/uebungen.json` (342 KB): 1.333 Übungen, Felder `id`, `name` (deutsch), `en`, `muskel`, `koerper`, `geraet`, `neben`. Muskelgruppen u. a. Bauch 169, Brust 158, Bizeps 151, Po 148; Geräte u. a. Körpergewicht 326, Kurzhantel 296, Kabelzug 159, Langhantel 154. Generierung: `tools/uebungen-katalog.sh`, `tools/uebungen-laden.sh`, Namen `tools/uebungen-namen-de.json`. Suchlogik `UebungenSuchlogik.swift`, Synonyme `UebungenSynonyme.swift`. Fixture: `fixtures/lovea-uebungen-auszug.json`.
- Muskelkarte (Körperumrisse): `Lovea/Sources/Health/Koerper/muskelkarte.json`. Herkunft laut `tools/opengym/NOTICE.md`: openGym (AGPL-3.0) auf Basis MuscleMap (MIT). Lovea-Besitzer gab die Übernahme "für die private App" frei: Lumen Fit wird mit Kollegen geteilt, also AGPL-Pflichten vor der Weitergabe klären oder die Muskelkarte neu zeichnen (SwiftUI-Pfade). Hinweis, kein Blocker für TestFlight an Ahmed und Partnerin.

### 2b. Bilder – primär ExerciseDB-CDN, Rückfall free-exercise-db

- ExerciseDB-GIF: `https://static.exercisedb.dev/media/2gPfomN.gif` HTTP 200, 0,41 s, 93 KB, `image/gif`. Das ist, was Lovea heute lädt (`UebungsMedien` in `Uebungen.swift`: einmal laden, in Caches halten, Plan vorladen). Die API selbst ist zu: `https://v2.exercisedb.dev/api/v1/exercises` liefert 429 (Vercel-Sicherheitsprüfung), `https://exercisedb-api.vercel.app/...` 402 DEPLOYMENT_DISABLED, `https://exercisedb.dev/api/v1/exercises` liefert HTML. Der Katalog darf deshalb nicht von der API abhängen. Code ist AGPL-3.0 (https://github.com/ExerciseDB/exercisedb-api); die Lizenz der Medien ist nicht klar: GIFs nicht in Git und nicht ins Bundle legen (wie Lovea), bei Ausfall zeigt die App SF-Symbol oder Rückfallbild.
- Rückfall: free-exercise-db, https://github.com/yuhonas/free-exercise-db, Lizenz Unlicense (gemeinfrei), 876 Übungen, 2 JPG je Übung (`images`). Katalog `https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json` HTTP 200, 0,17 s, 1.005 KB. Bild `.../exercises/3_4_Sit-Up/0.jpg` HTTP 200, 0,21 s, 38 KB (auch über `cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@main/exercises/...`, 0,14 s). Zuordnung zu Lovea per englischem Namen: nur 132 von 1.333 exakt, der Rest braucht Fuzzy-Abgleich (Muskel plus Gerät) und bleibt dennoch lückenhaft. Fixture: `fixtures/free-exercise-db-3.json`.
- wger: `https://wger.de/api/v2/exerciseinfo/?language__code=de&limit=50&format=json` HTTP 200 in 0,13 s, 636 Übungen mit deutscher Übersetzung (Sprach-ID de = 1, en = 2; Achtung: der Filter `language=1` allein filtert nicht, `language__code=de` schon). Lizenz CC-BY-SA 4.0 (Share-Alike: Texte nur mit Namensnennung, Abwandlungen gleiche Lizenz). Von 100 Übungen hatten 46 ein Bild. Kein Schlüssel für Lesen, Drosselung im Header nicht sichtbar. Nur als Rückfall für Texte. Fixtures: `fixtures/wger-exerciseinfo-de.json`, `fixtures/wger-language.json`.

### 2c. Training live

- HKWorkoutSession (iOS 17) und HKLiveWorkoutBuilder (laut Apple-Doku iOS 26.0) laufen auf dem iPhone, damit gibt es Live-Puls und Kalorien im Gym auch ohne Watch, wenn ein Pulsgerät (Watch oder Band mit Health-Eintrag) liefert. Lovea-Code zum Übernehmen: `Health/WorkoutPuls.swift`, `GymLive.swift`, `GymSession.swift`.
- WorkoutKit (iOS 17) `CustomWorkout`: Pläne zur Watch senden, optional.

## 3. Apple-Frameworks (Doku live abgefragt, developer.apple.com/tutorials/data/documentation/...json, alle HTTP 200 in 0,2 bis 0,55 s)

| Zweck | Framework / Symbol | iOS ab |
|---|---|---|
| Schritte, Distanz, Aktivenergie, Trainingsminuten | HealthKit `stepCount`, `distanceWalkingRunning`, `activeEnergyBurned`, `appleExerciseTime` | 8 bis 9.3 |
| Schlaf | `HKCategoryValueSleepAnalysis`, Handgelenktemperatur `appleSleepingWristTemperature` | 8, 16 |
| Erholung (Tagesform) | `heartRateVariabilitySDNN`, `restingHeartRate`, `respiratoryRate`, `oxygenSaturation`, `vo2Max` | 8 bis 11 |
| Ernährung zurückschreiben | `dietaryProtein` u. a. | 8 |
| Gewicht, Körperfett | `bodyMass`, `bodyFatPercentage` | 8 |
| Stimmung (optional) | `HKStateOfMind` | 18 |
| Änderungen beobachten | `HKObserverQuery`, `HKAnchoredObjectQuery` | 8 |
| Barcode live | VisionKit `DataScannerViewController` | 16 |
| Barcode/Text aus Foto | Vision `VNDetectBarcodesRequest`, `VNRecognizeTextRequest` (Nährwerttabelle abfotografieren) | 11, 13 |
| Coach | FoundationModels `SystemLanguageModel`, `LanguageModelSession`, `@Generable` | 26 |
| Diagramme | Swift Charts | 16 |
| Widgets, Live Activity | WidgetKit, ActivityKit | 14, 16.1 |
| Siri, Verknüpfungen | App Intents | 16 |
| Band | CoreBluetooth, `retrieveConnectedPeripherals(withServices:)` | 7 |
| Profil bleibt nach Update | Keychain `kSecAttrAccessibleAfterFirstUnlock` + `kSecAttrSynchronizable` (iCloud-Schlüsselbund) + `kSecAttrAccessGroup` | 4, 7, 3 |
| Mit Lovea teilen | App Group `group.com.onlyus.lumen-fit`, `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)`, `UserDefaults(suiteName:)` | 7 |

Hinweise:
- Lovea nutzt schon: `activeEnergyBurned`, `stepCount`, `restingHeartRate`, `heartRate`, `heartRateVariabilitySDNN`, `distanceWalkingRunning`, `appleExerciseTime`, `walkingHeartRateAverage`, `vo2Max`, `sleepAnalysis`, `respiratoryRate`, `oxygenSaturation`, `bodyMass`, `bodyFatPercentage`, `basalEnergyBurned` (Code: `Health/HealthModell.swift`, `Health/Heute/Tagesform/TagesformVitalwerte.swift`, `Health/SchritteRinge.swift`). Das lässt sich 1:1 verschieben.
- HealthKit lässt sich nicht testen ohne echtes Gerät: Lesezugriff verweigert sieht für die App wie "keine Daten" aus. Die App braucht überall einen leeren Zustand mit Hinweis ("In Health freigeben").
- `NSHealthShareUsageDescription` und `NSHealthUpdateUsageDescription` in der Info.plist, Capability HealthKit im App-Eintrag und in der Entitlements-Datei (nicht geprüft, ob `signing/asc.mjs` sie setzt).
- Foundation Models: nur auf Geräten mit Apple Intelligence (Gerät, Sprache, Einstellung an). `SystemLanguageModel.default.availability` prüfen, `supportsLocale(_:)` für Deutsch prüfen, `contextSize` begrenzt den Verlauf (Doku: "maximum context size in tokens"). Wenn nicht verfügbar, greift der Rückfall.

## 4. Coach – menschlich, ohne eigenen Server

Befund aus Lovea: Der Coach läuft dort über den eigenen Worker (`server/ki.js`, `ki-kette.js`, `coach.js`, Modell `gpt-6-luna` über OpenAI; Workers AI, Groq, Cerebras nur für "unkritische" Aufrufe, weil Gesundheitsdaten nach Art. 9 DSGVO nicht an kostenlose Anbieter gehen). Das braucht Schlüssel und Server, also nicht client-only.

Geprüft ohne Schlüssel von diesem Rechner:
- Groq `https://api.groq.com/openai/v1/models` ohne Schlüssel HTTP 401; Cerebras `https://api.cerebras.ai/v1/models` HTTP 403: Schlüssel nötig, in einer Client-App nicht sicher unterzubringen.
- Pollinations `https://text.pollinations.ai/<prompt>`: 1 Antwort in 6,0 s (guter deutscher Satz); der zweite Aufruf direkt danach HTTP 402 `FREE_LIMIT: 1 reply every 30 seconds per IP`. Schlüssellos, aber 1 Antwort/30 s, Daten gehen an Dritte: für Gesundheitsdaten ungeeignet. Verworfen.

Empfehlung:
1. Primär: Foundation Models auf dem Gerät (privat, kostenlos, kein Netz). Prompt mit Name, Ziel, Tageswerten, kurzen Sätzen, Du-Form, kein Fachjargon; `@Generable` für Rückfragen und Tagesbericht.
2. Rückfall bei Geräten ohne Apple Intelligence: regelbasierte Textbausteine (Lovea hat `Health/Coach/CoachLokal.swift`, `CoachMarker.swift`, `CoachTraining.swift`, `CoachGesundheit.swift`) mit Werten befüllt, damit der Coach nie leer ist.
3. Optional später: wenn Lovea gekoppelt ist, kann der Lovea-Worker (`/ki/coach`) das große Modell bedienen; als eigene Stufe hinter einem Schalter, nie Standard.
Ahmed, Partnerin und Kollegen: Ob jedes Gerät Apple Intelligence hat, ist offen (Annahme in SPEC.md eintragen: Rückfall muss gut genug sein).

## 5. Weitere Quellen

- Open-Meteo (nur wenn Cardio draußen Wetter zeigen soll, nicht im Auftrag): `https://api.open-meteo.com/v1/forecast?...&current=temperature_2m,weather_code,is_day,wind_speed_10m,precipitation` HTTP 200 in 0,12 bis 0,15 s, 1 KB, ohne Schlüssel. Kostenlos nur nicht-kommerziell, 5.000 Aufrufe/Stunde, 10.000/Tag je IP (https://open-meteo.com/en/pricing). Lovea nutzt es schon (`Lovea/Sources/Karte/WetterModell.swift`, WMO-Code-zu-Symbol-Tabelle). Empfehlung: in v1 weglassen. Fixture: `fixtures/open-meteo-forecast-berlin.json` (neutraler Punkt Berlin, kein privater Ort).
- Ferien/Feiertage, Karten, Chat-Medien: gehören zu Lovea, nicht zu Lumen Fit.

## 6. Konsequenzen für SPEC.md

- Kein Server in v1: Profil (Name, Passwort-Hash PBKDF2) lokal, Sitzung/Profil-Token im Schlüsselbund (AfterFirstUnlock, synchronisierbar, Zugriffsgruppe), damit kein erneutes Anmelden nach Update oder Neuinstallation. Freunde/Kollegen-Teilen und Lovea-Kopplung brauchen später einen Server oder CloudKit/App Group (nur auf demselben Gerät); als Schnittstelle vorbereiten, nicht bauen.
- Annahmen eintragen: Rückfall-Coach ohne Apple Intelligence; Muskelkarte (AGPL) bis zur Weitergabe an Kollegen klären; ExerciseDB-Medien nur geladen, nie im Repo oder Bundle; OFF-User-Agent `LumenFit/1.0 (Kontakt)`; Namensnennung BLS (MRI, CC BY 4.0), Open Food Facts (ODbL), wger (CC-BY-SA 4.0, falls genutzt) in den Einstellungen unter Quellen.
- Tests mit den Fixtures in `docs/research/fixtures/` (Dateien unten). Keine Fixture enthält Namen, Adressen, Orte oder Schlüssel; der USDA-`DEMO_KEY` ist öffentlich und steht nicht in den Dateien.

## Fixtures (alle gekürzte echte Antworten vom 2026-10-29)

`/home/tobi/projects/lumen-fit-ios/docs/research/fixtures/`
- `off-v2-product-4008400402222.json`, `off-v2-product-nicht-gefunden.json`
- `off-search-haferflocken.json`, `off-cgi-search-haferflocken.json`
- `usda-fdc-search-oats.json`
- `wger-exerciseinfo-de.json`, `wger-language.json`
- `free-exercise-db-3.json`
- `lovea-uebungen-auszug.json`, `bls-4-0-lovea-auszug.json`
- `open-meteo-forecast-berlin.json`

## Was nicht geprüft wurde

- HealthKit, Foundation Models, VisionKit, ActivityKit laufen nur auf iOS-Geräten: hier nur Existenz und Mindestversion aus der Apple-Doku, kein Lauf. Erste echte Prüfung kommt mit TestFlight.
- Rate-Limits (OFF 15/min, 10/min) wurden nicht ausgereizt, nur aus der Doku zitiert.
- Lizenz der ExerciseDB-Medien (GIF) nicht abschließend geklärt.
- Die Rückfalllisten gelten für Deutschland; andere Länder nicht gemessen.
