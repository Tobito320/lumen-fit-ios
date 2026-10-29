# Constraints

Last reviewed: 2026-10-29 durch Claude (Planungsschritt), Eigentümer Ahmed. Noch kein Code, noch kein CI-Lauf: Zahlen, die erst ein grüner Lauf liefert, stehen unter "Gemessen" und werden gemessen eingetragen, nicht erfunden.

Erkannt (Detect): XcodeGen-Projekt geplant (Swift 6, iOS 26, XCTest), CI GitHub Actions `macos-26`, Agenten Claude Code (`CLAUDE.md`) und Codex (`AGENTS.md`), kein lokaler Compiler (Arch Linux). Lokal vorhanden: `swift-syntax-check`, `rg`, `jq`, `python3`, `actionlint`, `shellcheck`. Es fehlen `gitleaks`, `xcodegen`, `yamllint`. Interview entfällt (nicht-interaktiver Lauf): es gelten die Standardwerte der Methode, begründet unten.

Dimensionen: Typen/Build, Warnungen, Tests, Geheimnisse und Privatdaten, Barrierefreiheit (per Test und Review), Architektur-Grenzen (Modulordner), Herkunft (Lovea-Port), Umfang (kein Wecker). Abgewählt: Lighthouse und axe (native App), Semgrep und osv-scanner (keine Swift-Pakete, kein Server), Stryker (kein Swift-Werkzeug).

## Floor (immer, ohne Einrichtung)

- Keine neuen Unterdrückungen: `@preconcurrency` ohne Begründung im Kommentar, `nonisolated(unsafe)`, `@unchecked Sendable` ohne einzeiligen Grund im Kommentar, `try!`, `fatalError` in Produktionscode (Ausnahme: die Skizzen des Grundgerüsts vor ihrem Ersatz)
- Keine unfertigen Stubs im gemergten Stand: kein `fatalError("...")`, kein leerer `catch {}`, kein `// TODO` anstelle von Code (Stub-Dateien der Module zeigen "Kommt bald", bis das Modul sie ersetzt)
- Keine übersprungenen oder gelöschten Tests ohne Begründung in der Commit-Nachricht; kein `XCTSkip`, außer `SymbolNamenTests`, wenn `symbole.txt` fehlt. Portierte Lovea-Tests werden angepasst, nie gelöscht oder abgeschwächt
- Keine Geheimnisse, keine Personennamen und keine Orte oder Adressen in Quelltext, Tests, Fixtures, Logs oder Commit-Texten
- Diese Datei wird nicht abgeschwächt, damit eine Änderung durchgeht

## Erzwungen mit Zahlen

| Dimension | Regel | Geprüft mit | Läuft | Warum diese Zahl |
|---|---|---|---|---|
| Syntax | `swift-syntax-check` meldet OK für jede geänderte Swift-Datei | `swift-syntax-check <Dateien>` | heute, in der Editierschleife (Sekunden) | Ohne lokalen Compiler fängt das Tippfehler vor dem 15-Minuten-CI-Lauf |
| Build und Typen | Kompiliert ohne Fehler, Swift 6 strikte Nebenläufigkeit | `xcodebuild test` in `ios-ci.yml` | CI pro Push (ab Grundgerüst) | Einziger Compiler-Beleg ohne Mac |
| Warnungen | 0 Compiler-Warnungen | Warnungszähler in `ios-ci.yml` | CI | Lovea und Bahnherz halten 0; ein Zähler über 0 wird sonst nie wieder 0 |
| Tests | Alle Tests grün | `xcodebuild test -scheme LumenFit` | CI und Aufgabenende im Modul | Test zuerst ist die Grundregel |
| Neue Logik | Jede neue Logik-Datei hat im selben Commit eine Testdatei desselben Themas; jede portierte Logik-Datei bringt ihre Lovea-Tests mit | Review und `/constraints guard` | Review | Ohne Coverage-Zahl ist die Datei-Paarung die ehrliche Messlatte |
| Privatdaten | `PrivateDaten.json` nicht im Git; kein Wert daraus in der Historie | `bash scripts/pruefe-privat.sh` und Job `patterns` | CI und vor jedem öffentlichen Fenster | Repo wird zeitweise öffentlich |
| Namens-Gate | `rg -n -i -w 'annika\|ahmed\|kausar\|mohammed\|fitx\|absolut' LumenFit Gemeinsam LumenFitWidgets` ist leer | `scripts/check-schnell.sh` und Job `patterns` | CI und lokal | Lovea-Code enthält Namen und Studios; beim Portieren dürfen sie nicht mitkommen |
| Umfang | Kein Wecker, keine Erinnerung: `rg -n 'AlarmKit\|UNCalendarNotificationTrigger' LumenFit Gemeinsam LumenFitWidgets` ist leer, `NSAlarmKitUsageDescription` fehlt | `scripts/check-schnell.sh`, `InfoPlistTests` | CI und lokal | Ahmed: "Lumen fit ist nur Health" |
| Lovea unverändert | `git -C ~/projects/lovea-app-ios rev-parse HEAD` und `status --short` vor und nach dem Bau gleich | Integrationsschritt | einmal je Modul | "Lovea selbst NICHT verändern" |
| Herkunft | Jede aus Lovea portierte Datei hat oben `// Quelle: Lovea Health/<Pfad>` | `rg -L '^// Quelle: Lovea' <Datei>` im Review | Review | Nachweis für die spätere Auslagerung aus Lovea |
| Signierdateien | Keine `.p12`, `.p8`, `.mobileprovision`, `.key`, `.pem`, `.cer`, `.csr` im Git | Job `patterns` | CI | wie Bahnherz |
| Workflows | `actionlint` ohne Fehler | Job `patterns` | CI | Tippfehler in Workflows kosten einen Lauf |
| Kontrast (extern: WCAG 2.2) | Text mindestens 4,5:1 (unter 18 pt), Bedienelemente mindestens 3,0:1 | `python3 -I docs/research/kontrast.py` und Test `FarbenKontrastTests` | Skript heute, Test ab Grundgerüst | HIG und WCAG AA, ein von Apple/W3C vorgegebener Maßstab |
| Symbole | Jeder SF-Symbol-Name existiert | Test `SymbolNamenTests` mit `scripts/symbole-sammeln.sh` | CI | Ein falscher Name bleibt sonst zur Laufzeit leer |
| Abhängigkeiten | 0 Swift-Pakete | Job `patterns` (kein `packages:` in `project.yml`, keine `Package.resolved`) | CI | Vermeidet Paketnetz-Fehler |
| Fähigkeiten | Entitlements nur `com.apple.security.application-groups` und die drei Schlüssel `com.apple.developer.healthkit*` | Job `patterns` (grep auf `*.entitlements`) | CI | Eine größere Entitlement-Liste als das Profil bricht das Archiv |
| Gespeicherte Typen | Neue Felder optional oder `decodeIfPresent`; Fall in `AlteDateienLadenTests` | Review und Test | CI | Sonst sind Daten nach dem TestFlight-Update weg |
| Modul-Grenzen | Ein Modul ändert nur die Dateien seiner Ordner (`SPEC.md` Abschnitt 12) | `git diff --name-only main...modul/<id>` gegen die Ordnerliste | Review und Integration | Parallelbau ohne Merge-Konflikte |
| Barrierefreiheit | Jedes Symbol ohne Text hat ein Label; Tippflächen mindestens 44 pt; VoiceOver-Satz je Zeile; Diagramme mit Descriptor und Kernzeile; Reduce Motion beachtet | Review-Checkliste in `tasks/plan.md` (Integration) | Review | axe und Lighthouse brauchen eine URL; es gibt keine |

In den Tabellenzellen steht `\|` für das Alternativzeichen `|` des Regex.

Mindestens eine Prüfung ist extern: Kontrast (W3C-Formel), `actionlint`, der Apple-Compiler. Die Tests des Projekts allein genügen nicht.

## Gemessen, noch nicht erzwungen

| Metrik | Heute | Richtung |
|---|---|---|
| Anzahl Tests | noch nicht gemessen (kein CI-Lauf) | darf nicht fallen; Ziel: alle portierten Lovea-Logik-Tests laufen mit |
| Testabdeckung (`xcodebuild -enableCodeCoverage YES`, `xccov`) | nicht gemessen | einmal messen, dann halten (Toleranz 0,5 Prozent) |
| CI-Dauer `test-iphone` | nicht gemessen | darf nicht wachsen ohne Grund |
| Faltung des Op-Logs bei 20.000 Ops | nicht gemessen | unter 300 ms auf dem Gerät (Ziel, am Gerät zu messen) |

## Ausnahmen

Keine. (Bahnherz hatte W1 für eine Dekorfarbe; Lumen Fit hat keine Farbe ohne Kontrastnachweis.)

| ID | Regel | Pfad | Grund | Owner | Läuft ab |
|---|---|---|---|---|---|

## Bewacht (`/constraints guard`)

Beim Review prüfen: wurde eine Schwelle gesenkt, ein Test übersprungen oder gelöscht, eine Unterdrückung ergänzt, ein Stub statt Code gelassen, ein portierter Test abgeschwächt, ein Name oder Ort eingeschleppt, eine Ausnahme hinzugefügt? Verschärfen darf leise geschehen, Lockern nur laut (Eintrag in "Ausnahmen" mit Owner und Ablaufdatum).
