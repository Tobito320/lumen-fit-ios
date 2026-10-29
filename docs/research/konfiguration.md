# Lumen Fit: Konfiguration als Vorlage (aus Bahnherz)

Stand: 29.10.2026. Zweck: Lumen Fit übernimmt Bau, CI, Signierung und TestFlight-Weg von Bahnherz, mit den Änderungen für Health (HealthKit, Band, Kopplung mit Lovea). Dieses Dokument enthält keine Geheimnisse und keine Privatwerte, nur Secret-Namen und öffentliche Kennungen.

Fertige Dateien liegen in `docs/research/vorlagen/` (Zuordnung in Abschnitt 3). Sie sind aus den Bahnherz-Dateien erzeugt, geändert und lokal geprüft (Abschnitt 9).

## 1. Quellen

Lokal gelesen:
- Bahnherz: `~/projects/bahnherz-ios/` mit `project.yml`, `.github/workflows/ios-ci.yml`, `.github/workflows/testflight.yml`, `signing/asc.mjs`, `signing/profile-und-secrets.sh`, `signing/testflight-gruppe.sh`, `scripts/*.sh`, `CLAUDE.md`, `CONSTRAINTS.md`, `.gitignore`, beide `.entitlements`, `docs/research/lovea-konfiguration.md`. Online: https://github.com/Tobito320/bahnherz-ios (privat).
- Lovea (nur lesen): `~/projects/lovea-app-ios/project.yml`, `Lovea/Lovea.entitlements` (HealthKit-Schlüssel), `LoveaWidgets/LoveaWidgets.entitlements`. Online: https://github.com/Tobito320/lovea-app-ios (privat). Signierordner nur lesen: `/mnt/windows/Users/ahmed/code/lovea-app-ios/signing/`.
- Vault: `19 Bastelprojekte/iOS-Apps ohne Mac – Ablauf bis TestFlight.md` (Abschnitte 2 bis 8, 11, 12).
- Auftrag und Spec: `~/.claude/buero-stand/lumen-fit-29-10.md`.

Live gegen App Store Connect gelesen am 29.10.2026 (nur GET, https://api.appstoreconnect.apple.com, Doku https://developer.apple.com/documentation/appstoreconnectapi):
- `com.onlyus.lumen-fit` existiert noch nicht (0 Treffer). GitHub-Repo `Tobito320/lumen-fit-ios` existiert noch nicht ("Could not resolve to a Repository"); lokal nur ein leeres `git init` ohne Commit.
- Die Bundle ID von Lovea hat die Fähigkeiten `APP_GROUPS`, `HEALTHKIT`, `PUSH_NOTIFICATIONS`, `USERNOTIFICATIONS_COMMUNICATION`, `IN_APP_PURCHASE` (daraus: der API-Typname für HealthKit ist `HEALTHKIT`).
- Ein Zertifikat, Typ DISTRIBUTION, läuft bis 2027-09-22 (teamweit, wiederverwenden).
- Apps im Team: Lovea, Bahnherz, Lumen Wallet, Lumen Connect, Lumen Cloud. Zwei Nutzer: Konto-Inhaber (`allAppsVisible` true) und ein Nutzer mit Rolle DEVELOPER und `allAppsVisible` false (Partnerin, braucht Sichtbarkeit für jede neue App).
- Bahnherz: die drei letzten `testflight.yml`-Läufe (26.10.2026) waren `success`. Der Weg ist also bewiesen.
- Lovea-Gruppe "Wir" hat zwei Tester im Status INSTALLED (Quelle der Tester für Lumen Fit).

Aus Bahnherz-Dokument übernommen, nicht neu geöffnet: XcodeGen-Spezifikation https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md.

## 2. Namen und Kennungen

| Was | Wert |
|---|---|
| App-Name für Ahmed | Lumen Fit |
| Repo lokal / GitHub | `~/projects/lumen-fit-ios` / `Tobito320/lumen-fit-ios` (privat) |
| Bundle ID App / Widgets / Tests | `com.onlyus.lumen-fit` / `com.onlyus.lumen-fit.widgets` / `com.onlyus.lumen-fit.tests` |
| XcodeGen-Name, Ziele, Schema | `LumenFit`, `LumenFitWidgets`, `LumenFitTests` |
| Quellordner | `LumenFit/Sources`, `LumenFit/Resources`, `LumenFit/Tests`, `LumenFitWidgets/Sources`, `Gemeinsam/` |
| `PRODUCT_NAME` | gleich Ziel-Name (`LumenFit`, `LumenFitWidgets`), Anzeigename "Lumen Fit" per `INFOPLIST_KEY_CFBundleDisplayName` (F-5/F-8: Produkt- und Modulname dürfen nicht vom Ziel abweichen) |
| App Group (neu) | `group.com.onlyus.lumen-fit` |
| App Group von Lovea (mitnutzen) | `group.com.onlyus.lovea` |
| URL-Schema | `lumenfit://` (URL-Name `com.onlyus.lumen-fit`) |
| BGTask-Kennung | `com.onlyus.lumen-fit.aktualisieren` |
| Profile in Apple | "Lumen Fit App Store", "Lumen Fit Widgets App Store" (Typ `IOS_APP_STORE`) |
| Profil-Variablen in `project.yml` | `$(LUMENFIT_APP_PROFILE)`, `$(LUMENFIT_WIDGETS_PROFILE)` |
| Dateien der Profile in `signing/` | `LumenFit_App_Store.mobileprovision`, `LumenFit_Widgets_App_Store.mobileprovision` |
| Team-ID | in `DEVELOPMENT_TEAM` (Secret), steht im Betreff von `distribution.pem` (Feld UID); Vault nennt sie in Abschnitt 2 |
| Zertifikat-Ressourcen-ID | `7Y36JLKMH5` (in `profile-und-secrets.sh`, öffentliche Kennung, kein Geheimnis) |
| SKU in App Store Connect | `lumen-fit` |
| Interne TestFlight-Gruppe | "Wir", automatische Verteilung |
| Launch-Argumente für CI | `-lumenFitDemo`, `-lumenFitTab`, `-lumenFitTheme`, `-lumenFitLumi`, `-lumenFitRoute`, `-lumenFitFixtures` (Vertrag mit der App, steht im Kopf des Screenshot-Schritts in `ios-ci.yml`) |

Die Bundle ID mit Bindestrich ist gültig. Das Ziel heißt ohne Bindestrich und Leerzeichen, weil es Modulname wird.

## 3. Zuordnung Vorlage zu Ziel im Repo

Alle Vorlagen liegen unter `docs/research/vorlagen/`. Der Ordner heißt `signing-skripte` (nicht `signing`), weil `.gitignore` jeden Ordner `signing/` ausschließt.

| Vorlage | Ziel im Repo |
|---|---|
| `project.yml` | `project.yml` |
| `github-workflows/ios-ci.yml` | `.github/workflows/ios-ci.yml` |
| `github-workflows/testflight.yml` | `.github/workflows/testflight.yml` |
| `gitignore.txt` | `.gitignore` |
| `entitlements/LumenFit.entitlements.vorlage` | `LumenFit/LumenFit.entitlements` |
| `entitlements/LumenFitWidgets.entitlements.vorlage` | `LumenFitWidgets/LumenFitWidgets.entitlements` |
| `PrivateDaten.beispiel.json` | `LumenFit/Resources/PrivateDaten.beispiel.json` |
| `CLAUDE.md` | `CLAUDE.md` und gleichlautend `AGENTS.md` (Claude liest die eine, Codex die andere) |
| `scripts/*.sh` | `scripts/` |
| `signing-skripte/*` (ohne `asc.mjs`) | `signing/` (dort ignoriert `.gitignore` sie; die Kopien unter `docs/research/vorlagen/` sind dagegen im Git und enthalten nur öffentliche Kennungen) |
| `~/projects/bahnherz-ios/signing/asc.mjs` (nicht in `vorlagen/`) | `signing/asc.mjs` unverändert kopieren. Die Datei enthält Key-ID, Issuer-ID und den Pfad zur `.p8` in Ahmeds Lovea-Ordner und darf nie ins Git: sonst schlägt `pruefe-privat.sh` an und das Repo kann nie öffentlich werden |

Danach ausführbar machen (`chmod +x scripts/*.sh signing/*.sh`) und `bash scripts/check-schnell.sh` laufen lassen.

Zusätzlich nach dem Kopieren anlegen (kommt nicht aus Bahnherz): `LumenFit/Resources/Assets.xcassets/AppIcon.appiconset/` (Icon 1024 ohne Alpha, Abschnitt 6, Schritt 7), `LumenFit/Tests/Fixtures/System/` bleibt leer (Datei `symbole.txt` erzeugt CI), `CONSTRAINTS.md` aus Bahnherz übernehmen und anpassen (Namen, Wegfall Orte und Fahrplan; Entitlement-Regel um HealthKit erweitern; Kontrast-Ausnahme W1 entfällt).

## 4. Was gegenüber Bahnherz geändert ist

| Thema | Bahnherz | Lumen Fit | Grund |
|---|---|---|---|
| Entitlements App | `aps-environment`, `application-groups` | `application-groups` (zwei Gruppen), `com.apple.developer.healthkit`, `...healthkit.access` (leeres Array), `...healthkit.background-delivery` | Health; Lovea nutzt dieselben drei HealthKit-Schlüssel und liefert damit aus. Kein Push (Abschnitt 8) |
| Entitlements Widgets | `application-groups` | `application-groups` (nur die eigene Gruppe) | Widgets lesen nur den eigenen Stand |
| CI-Job `patterns`, Entitlement-Prüfung | erlaubt `application-groups`, `aps-environment` | erlaubt `application-groups` und alles mit `com.apple.developer.healthkit` | Ein Schlüssel mehr als im Profil bricht das Archiv |
| Info.plist | Standort, Kalender, AlarmKit, Fetch | Health (beide Texte), Bluetooth (Band), Kamera (Barcode, Essen-Foto), Bewegung (Schritte), Hintergrund `bluetooth-central` und `fetch`, Live Activity | Alle Texte Deutsch; Wecker und Erinnerungen sind laut Auftrag nicht in Lumen Fit, also kein AlarmKit |
| Privatdatei | `BekannteOrte.json`, Secret `BEKANNTE_ORTE_JSON`, Haltestellen-Prüfung | `PrivateDaten.json`, Secret `PRIVATE_DATEN_JSON`, ohne Haltestellen | Form und Inhalt sind eine Annahme (Abschnitt 7); Bei Wegfall siehe Abschnitt 7.3 |
| `pruefe-privat.sh` | bricht ohne Suchbegriffe mit 2 ab | meldet bei einer Datei ohne Adressen nur einen Hinweis | Die Datei kann nur Namen enthalten |
| `testflight.yml`, Push-Schritt | schreibt `PushSchluessel.txt` aus Secret | entfällt | Kein Server-Push |
| `testflight.yml`, Profilprüfung | prüft eine App Group | prüft je Profil eine Liste: App = eigene Gruppe, Lovea-Gruppe, HealthKit; Widgets = eigene Gruppe | Fail-fast vor dem Archiv |
| `ios-ci.yml`, Screenshots | Tabs start, reise, abfahrten, navi, profil; Maskottchen; Fahrplan-Links | Tabs heute, gym, essen, schlaf, coach; alle fünf Themes; Lumi in allen Stimmungen; Onboarding; sechs Tiefenseiten; hell und dunkel | Muster und Themes sind Kern des Designs, CI ist der einzige Blick darauf |
| `ios-ci.yml`, Privatprüfung der Navi-Karte | nur im privaten Repo | entfällt | Lumen Fit hat keine Karte mit echten Straßen |
| `signing/testflight-gruppe.sh` | Gruppe mit Testern im POST | Sichtbarkeit zuerst, Gruppe, dann je Person `POST /v1/betaTesters` | Lehre 5 (Abschnitt 5) |
| `signing/profile-und-secrets.sh` | prüft nur die App Group | prüft eine Pflichtliste je Profil | wie oben |
| `signing/` neu | nur `asc.mjs`, Profil-, Gruppen-Skript | zusätzlich `bundle-ids-anlegen.sh`, `secrets-setzen.sh`, `privat-secret.sh` | Alles von Linux aus ohne Handarbeit, außer Portal |
| `testflight-fenster.sh` | prüft per Sleep-Schleife | `gh run watch --exit-status` | Keine Abfrageschleifen |
| Server (Cloudflare) | Ordner `server/`, Ignore-Zeilen | entfällt | Client-only |
| Unverändert | Swift 6.0, iOS 26, `TARGETED_DEVICE_FAMILY` 1, XcodeGen, `macos-26`, `actions/checkout@v5`, Cache `actions/cache@v4`, Warnungszähler, `actionlint`, 0 Swift-Pakete, Test-Ziel mit Fixtures als Ordnerreferenz, Release-Bau ohne Signatur, Manual Signing nur in `Release` | | bewiesen grün |

## 5. Lehren aus Bahnherz und wo sie in der Vorlage stehen

| Nr. | Lehre | Stand in der Vorlage |
|---|---|---|
| 1 | `nonisolated static let` für Konstanten in `@MainActor`-Typen, die `nonisolated` Code liest | `CLAUDE.md` (Abschnitt Code) |
| 2 | Vor dem Test-Bau `rm -rf derived/Build`, sonst "Undefined symbols" aus altem Cache | `ios-ci.yml`, Schritt "Test on iPhone" (Zeile ist enthalten, nur der Modul-Cache bleibt) |
| 3 | Beide Ausrichtungen setzen, sonst Upload-Fehler 90474 | `project.yml`: `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` Portrait und `_iPad` mit allen vier |
| 4 | API kann weder Apps noch App Groups anlegen | Abschnitt 6, Schritt 4 (Portal, Agenten-Chrome) |
| 5 | Interne Tester: Gruppe, dann je Person `POST /v1/betaTesters`; Partnerin braucht vorher `POST /v1/users/<id>/relationships/visibleApps` sonst 409 | `signing/testflight-gruppe.sh` (Reihenfolge so eingebaut) |
| 6 | Erste TestFlight-Läufe scheitern am Upload, nicht am Bau | `scripts/testflight-fenster.sh` gibt bei Rot das Ende von `--log-failed` aus; Abschnitt 6, Schritt 10 |

Weitere Fallen, die in der Vorlage schon gelöst sind: Profil pro Ziel in `project.yml` statt global auf der `xcodebuild`-Zeile; beide Profile in den Export-Plist; `.p12` im macOS-lesbaren Format (F-13); Icon ohne Alpha (F-14, Fehler 90717); `GENERATE_INFOPLIST_FILE` und `ITSAppUsesNonExemptEncryption` (F-7, F-17); beide Health-Texte (sonst "Missing purpose string"); `import SwiftUI` in der `WidgetBundle`-Datei.

## 6. Reihenfolge (von der Vorlage bis TestFlight)

Warten auf CI immer so: `scripts/ci-fenster.sh` im Hintergrund starten (`run_in_background`), danach einmal `timeout 590 gh run watch <ID> -R Tobito320/lumen-fit-ios --exit-status`, bei Zeitablauf denselben Aufruf wiederholen. Nie einzeln abfragen. Nie GitHub-Billing vorschlagen.

1. Repo: `gh repo create Tobito320/lumen-fit-ios --private --source ~/projects/lumen-fit-ios --remote origin` (noch nicht erledigt, das Repo existiert nicht).
2. Vorlagen kopieren (Abschnitt 3), `PrivateDaten.json` lokal anlegen (gitignored), `bash scripts/check-schnell.sh`.
3. Bundle IDs: `bash signing/bundle-ids-anlegen.sh` (legt `com.onlyus.lumen-fit` und `.widgets` an, schaltet `APP_GROUPS`, für die App zusätzlich `HEALTHKIT`). `HEALTHKIT` per API ist hier noch nicht erprobt (Lovea hat es, der Weg dorthin ist nicht belegt): bei einer 4xx-Meldung die Fähigkeit im Portal einschalten.
4. Handarbeit im Apple-Portal, einmal (Lehre 4). Ahmed loggt sich einmal im Agenten-Chrome ein (`claude-chrome fenster`, Fenster auf seinen Workspace), danach klickt der Agent allein:
   1. https://developer.apple.com/account/resources/identifiers/list/applicationGroup: Gruppe `group.com.onlyus.lumen-fit` anlegen (das Portal setzt `group.` selbst).
   2. Identifiers, App-ID `com.onlyus.lumen-fit`, App Groups, Configure: `group.com.onlyus.lumen-fit` und `group.com.onlyus.lovea` ankreuzen, Save, Confirm. Lovea-App-IDs nicht anfassen.
   3. Identifiers, App-ID `com.onlyus.lumen-fit.widgets`, App Groups, Configure: nur `group.com.onlyus.lumen-fit`.
   4. https://appstoreconnect.apple.com, Apps, Plus, Neue App: iOS, Name "Lumen Fit" (muss im ganzen App Store eindeutig sein, sonst Zusatz), Sprache Deutsch, Bundle ID `com.onlyus.lumen-fit`, SKU `lumen-fit`, Vollzugriff. Zeigt die Liste "No Apps": Seite neu laden (F-16). Das ist keine Bestellung und kostet nichts.
5. Profile (nach 4, sonst fehlt die Gruppe): `bash signing/profile-und-secrets.sh`. Das Skript löscht gleichnamige alte Profile, legt beide neu an, prüft die Pflichtliste (Gruppen, HealthKit) und setzt `APPSTORE_PROFILE_BASE64` und `APPSTORE_WIDGETS_PROFILE_BASE64` nur bei Erfolg.
6. Secrets: `bash signing/secrets-setzen.sh` (sechs Stück), `bash signing/privat-secret.sh` (`PRIVATE_DATEN_JSON`). Prüfung: `gh secret list --repo Tobito320/lumen-fit-ios` zeigt genau neun Namen (Abschnitt 7.1).
7. Icon 1024x1024 ohne Alpha, wie in `~/projects/bahnherz-ios/docs/research/lovea-konfiguration.md` Abschnitt 7.7: `rsvg-convert -w 1024 -h 1024 design/app-icon.svg -o /tmp/icon-raw.png`, dann `magick /tmp/icon-raw.png -background '#ffffff' -alpha remove -alpha off -type TrueColor -depth 8 PNG24:LumenFit/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png`; `file` muss RGB zeigen, nicht RGBA. `Contents.json`: `{"images":[{"filename":"icon-1024.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}`.
8. CI: `bash scripts/ci-fenster.sh` im Hintergrund, warten wie oben. Erst bei grün weiter.
9. Tester: `bash signing/testflight-gruppe.sh` (Sichtbarkeit für Partnerin, Gruppe "Wir", Tester aus der Lovea-Gruppe). Gibt nur Statuscodes aus.
10. TestFlight: `bash scripts/testflight-fenster.sh` im Hintergrund. Bei Rot zuerst das Log lesen (Lehre 6). Build-Nummer ist `github.run_number`, Builds laufen 90 Tage.
11. Danach das Repo prüfen: `gh repo view Tobito320/lumen-fit-ios --json visibility` muss `PRIVATE` zeigen (Trap setzt es zurück).

Apple verschickt beim Anlegen eines Testers selbst eine Einladung; der Agent schreibt keine eigenen Mails oder Nachrichten an Menschen.

## 7. Secrets

### 7.1 Liste (neun)

| Secret | Inhalt | Gesetzt von |
|---|---|---|
| `DEVELOPMENT_TEAM` | Team-ID | `secrets-setzen.sh` (aus `distribution.pem`) |
| `APPLE_CERT_P12_BASE64` | `.p12` als Base64, neu gebaut aus Lovea-Schlüssel und -Zertifikat | `secrets-setzen.sh` |
| `APPLE_CERT_PASSWORD` | zufälliges Passwort der neuen `.p12`, nie ausgegeben | `secrets-setzen.sh` |
| `APPSTORE_PROFILE_BASE64` | Profil "Lumen Fit App Store" | `profile-und-secrets.sh` |
| `APPSTORE_WIDGETS_PROFILE_BASE64` | Profil "Lumen Fit Widgets App Store" | `profile-und-secrets.sh` |
| `ASC_KEY_ID` | Key-ID des teamweiten API-Schlüssels | `secrets-setzen.sh` (aus `asc.mjs`) |
| `ASC_ISSUER_ID` | Issuer-ID | `secrets-setzen.sh` (aus `asc.mjs`) |
| `ASC_KEY_P8_BASE64` | API-Schlüssel `.p8` als Base64 | `secrets-setzen.sh` |
| `PRIVATE_DATEN_JSON` | Inhalt von `PrivateDaten.json`, eine Zeile | `privat-secret.sh` |

Die vorhandenen Secrets von Bahnherz und Lovea lassen sich nicht auslesen (GitHub gibt Werte nie heraus), deshalb werden alle neu gesetzt. Gleich bleibt, woher sie kommen: Zertifikat und API-Schlüssel sind teamweit. Das Passwort der `.p12` ist ein maschinell erzeugtes Zufallsgeheimnis für eine Datei, die nur auf dem Runner gelesen wird, kein persönliches Passwort.

### 7.2 Annahme zur Privatdatei

Der Auftrag verlangt "Private Daten nie in Git". Lumen Fit hat laut Spec Konten und Profile, aber noch keine Datei mit Adressen. Als Muster gilt Bahnherz: `PrivateDaten.json` (gitignored) mit `{"version":1,"personen":[{"id","name","orte":[{"name","art","adresse","breite","laenge"}]}]}`. Der Check in `testflight.yml` verlangt nur `version` 1 und mindestens eine Person mit Namen. Das Modul, das die Datei liest (z. B. Studio-Standort, Voreinstellungen der Mitnutzer), legt die Form endgültig fest, die Vorlage ändert sich dann in `testflight.yml` (jq-Ausdruck), `pruefe-privat.sh` (jq-Pfade) und `PrivateDaten.beispiel.json`.

### 7.3 Wenn die App am Ende keine Privatdatei braucht

Dann entfernen: Schritt "Privatdaten schreiben" und `PRIVATE_DATEN_JSON` in der Secret-Prüfung von `testflight.yml`; Job-Zeile `PrivateDaten.json` in `ios-ci.yml` (`patterns`); Zeile in `.gitignore`; `privat-secret.sh`; `scripts/pruefe-privat.sh` kann bleiben (prüft dann nur Signierdateien und Schlüssel, Datei fehlt: `PRIVAT_STRENG=1` in `ci-fenster.sh` und `testflight-fenster.sh` auf 0 setzen). Es bleiben acht Secrets.

## 8. Entscheidungen und Annahmen (für SPEC.md, Abschnitt "Annahmen")

1. Lovea-Gruppe mitnutzen. Ahmed will das Band mit Lovea teilen und bei Kopplung Partnerin-Benachrichtigungen sehen; die Spec nennt "gemeinsame App Group". Lumen Fit trägt deshalb `group.com.onlyus.lumen-fit` und `group.com.onlyus.lovea` ein. Das braucht keine Änderung an Lovea: eine Gruppe darf mehreren App-IDs zugewiesen werden, nur die App-ID von Lumen Fit wird geändert. Spätere Lovea-Seite (Lesen der Warteschlange) ist eine eigene Lovea-Runde. Wer das nicht will: Lovea-Gruppe aus `LumenFit.entitlements.vorlage`, aus der Pflichtliste in `profile-und-secrets.sh` und `testflight.yml` und aus Abschnitt 6, Schritt 4.2 streichen. Auf einem Gerät ungeprüft: ob zwei Apps dieselbe Bluetooth-Verbindung teilen können (offener Punkt der Spec).
2. Kein Push. Benachrichtigungen "Partnerin hat etwas" gehen mit der Vorlage nur lokal und nur auf demselben Gerät oder über Hintergrundabruf (`fetch`). Echte Push-Nachrichten von Partner-Gerät an Ahmeds Gerät brauchen einen Sender (Server oder Lovea) und eine Änderung der Konfiguration: Fähigkeit `PUSH_NOTIFICATIONS` per `bundleIdCapabilities`, Schlüssel `aps-environment` = `production` in `LumenFit.entitlements`, `aps-environment` in die Erlaubnisliste im Job `patterns`, `remote-notification` in `UIBackgroundModes`, Profil neu erzeugen. Nicht erprobt für Lumen Fit; Lovea hat genau diese Schlüssel (Lovea.entitlements).
3. Kein Keychain-Sharing-Entitlement. Profil und Anmeldung liegen im Standard-Schlüsselbund der App und überleben Updates. Neu installieren nach Löschen: nicht belegt (iOS behält Schlüsselbund-Einträge in der Regel, das ist nicht Teil dieser Konfiguration).
4. Gesundheitstexte bewusst allgemein, weil die Kopplung mit Lovea erst Phase 2 ist.
5. Eigener Name im App Store: "Lumen Fit". Ist er vergeben, nimmt der Agent einen Zusatz (z. B. "Lumen Fit Training") und notiert es in der Spec. Der Anzeigename auf dem iPhone bleibt "Lumen Fit".
6. `CURRENT_PROJECT_VERSION` setzt der Workflow aus `github.run_number`; `MARKETING_VERSION` steht fest auf 0.1.0.

## 9. Was geprüft ist und was nicht

Lokal geprüft (29.10.2026):
- `actionlint` (mit `shellcheck` auf den `run`-Blöcken) ohne Fund für beide Workflows (nur das Label `macos-26` ist dem lokalen actionlint unbekannt, in CI kennt er es).
- `bash -n` und `shellcheck -S warning` ohne Fund für alle Skripte; die Infos SC2317/SC2020 stammen aus dem Original.
- `project.yml` als YAML lesbar, Schema und Ziele wie erwartet; beide `.entitlements.vorlage` als Plist lesbar; `PrivateDaten.beispiel.json` gültiges JSON.
- `pruefe-privat.sh` in einem Wegwerf-Repo: "sauber" bei sauberem Stand, "FUND" im Arbeitsbaum und in der Historie nach dem Einchecken eines Adressstücks.
- Wegwerf-Repo mit dem ganzen `docs/`-Baum, `.gitignore` und einer echten `PrivateDaten.json` (nicht eingecheckt): `PRIVAT_STRENG=1 pruefe-privat.sh` meldet "sauber", Exit 0. Die Beispieldatei darf nicht dieselben Werte wie die echte haben, sonst schlägt der Check zu Recht an.
- Lesende Teile von `secrets-setzen.sh` ohne Schreiben: Key-ID 10, Issuer-ID 36, Team-ID 10 Zeichen; `.p8`, `Lovea-Distribution.key` und `distribution.pem` liegen im Lovea-Ordner; der `.p12`-Export mit den Algorithmen aus F-13 läuft durch (Wegwerfdatei, gelöscht).
- Lesende Teile von `testflight-gruppe.sh` gegen die echte API (Tester-Abfrage der Lovea-Gruppe liefert Zeilen mit drei Feldern, die Nutzerabfrage liefert genau einen Nutzer mit eingeschränkter Sicht). Es wurde nichts geschrieben: keine Bundle ID, kein Profil, keine Gruppe, kein Secret, kein Tester.

Nicht geprüft (nur CI, Portal oder Gerät beweisen es):
- `xcodegen generate`, Kompilierung, Tests, Archiv, Export, Upload mit dieser `project.yml` (erst im ersten CI-Lauf).
- Der Screenshot-Schritt hängt an den Launch-Argumenten und `lumenfit://`-Pfaden, die die App noch liefern muss; fehlen sie, entstehen Bilder vom Startbildschirm (der Schritt röt den Lauf nie).
- `HEALTHKIT` und `APP_GROUPS` per `POST /v1/bundleIdCapabilities` für diese App; `bundle-ids-anlegen.sh` meldet jede API-Fehlermeldung im Klartext.
- Dass `com.apple.developer.healthkit.background-delivery` ohne eigenen Portal-Schalter im Profil landet. Bei Lovea steht es in Entitlements und Profil; die Pflichtliste der Profile prüft deshalb nur `com.apple.developer.healthkit`.
- `POST /v1/users/<id>/relationships/visibleApps` mit dem Rumpf aus `testflight-gruppe.sh` (Form aus Lehre 5 abgeleitet, Antwortcode wird gemeldet).
- Ob der Name "Lumen Fit" im App Store frei ist.
- Die Annahmen in Abschnitt 8.

## 10. Server-Secrets (Cloudflare Worker `lumen-fit`, Ordner `server/`)

Stand 29.10.2026. Keine Werte hier, nur Namen und Orte. Die drei Secrets liegen als Worker-Secrets je Umgebung (`test`, `live`), gesetzt mit `wrangler secret put NAME --env test|live` (Wert über stdin, nie als Argument), nie im Repo, nie in Logs.

| Secret | Zweck | Lokale Quelle (Arch, `chmod 600`) | Wer kennt es |
|---|---|---|---|
| `APP_KEY` | Header `X-App-Key` der App für `POST /konto`, `GET /config`, `/lovea/*` | `~/.config/lumenfit/app.key` | App (später in `PrivateDaten.json`), Server |
| `ADMIN_KEY` | Header `X-Admin-Key` für `/admin/*` | `~/.config/lumenfit/admin.key` | nur MCP `lumenfit` und Server, nie die App |
| `LOVEA_KEY` | Lovea-Zugang für den Proxy `/lovea/agent/ops` | `~/.config/lovea/lovea-app.key` (Lovea-Datei, nur gelesen) | nur der Server; die App bekommt ihn nie |

Neu setzen oder drehen: Datei ändern, dann je Umgebung `tr -d '\n' < DATEI | npx wrangler secret put NAME --env live` im Ordner `server/`. `APP_KEY` drehen heißt neue App-Fassung (der Schlüssel steckt im Bundle); `ADMIN_KEY` und `LOVEA_KEY` lassen sich ohne Build tauschen.

Konto-Geheimnisse (eines je Gerät) erzeugt die App selbst und legt sie in ihre Keychain; der Server speichert nur den SHA-256-Hash.

Datenbanken (D1, kostenlos): `lumen-fit-test` (`ed3e9d71-fefa-4b6b-87ff-aa6aedb7d57b`), `lumen-fit-live` (`32a9321e-b0ed-422e-93d2-9badf89d4331`). Schema: `server/schema.sql`, einspielen mit `npx wrangler d1 execute lumen-fit-<env> --env <env> --remote --file schema.sql`.

Deploy: `cd server && npm test && npm run deploy:test` (und `deploy:live`). Immer mit `--env`; die Datei hat bewusst keine Bindungen ohne Umgebung.
