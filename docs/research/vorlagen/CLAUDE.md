# Lumen Fit – Regeln für Agenten

iOS-App (SwiftUI, Swift 6, iOS 26, iPhone) für Fitness und Gesundheit, für Ahmed, seine Partnerin und Kollegen: Gym, Essen, Schlaf, Schritte, Coach, Lumi. Standard-Design monochrom wie Apple, Themes einstellbar. Client-only, solange `SPEC.md` nichts anderes sagt. Spec: `SPEC.md` (Wahrheit), Qualitätslatte `CONSTRAINTS.md`, Plan `tasks/plan.md`, Aufgaben `tasks/todo.md`, Konfiguration `docs/research/konfiguration.md`. Lies `CONSTRAINTS.md` vor dem Schreiben von Code und schwäche sie nie ab, damit eine Änderung durchgeht.

## Pfade
- Repo: `/home/tobi/projects/lumen-fit-ios`, GitHub `Tobito320/lumen-fit-ios`, privat. Vault-Anleitung: `~/Documents/Obsidian/Personal/19 Bastelprojekte/iOS-Apps ohne Mac – Ablauf bis TestFlight.md`. Vorlage-Repos: `~/projects/bahnherz-ios` (Konfiguration), `~/projects/lovea-app-ios` (Quelle für Gym, Essen, Schlaf, Schritte, Coach; Lovea nie ändern).
- Bundle ID `com.onlyus.lumen-fit`, Widgets `com.onlyus.lumen-fit.widgets`, App Group `group.com.onlyus.lumen-fit` (zusätzlich `group.com.onlyus.lovea` für Band und Kopplung).

## Bau
- Kein Mac, kein Swift lokal. Kompiliert und getestet wird nur in GitHub Actions (`ios-ci.yml`, `macos-26`). Lokal nur: `swift-syntax-check <Dateien>`, `bash scripts/check-schnell.sh`, `bash scripts/pruefe-privat.sh`.
- Actions laufen nur bei öffentlichem Repo. Immer: `bash scripts/ci-fenster.sh` im Hintergrund (Privat-Check, öffentlich, Push, Lauf, trap macht wieder privat). Danach EINMAL blockierend `timeout 590 gh run watch ID -R Tobito320/lumen-fit-ios --exit-status`; nie einzeln per `gh run view`, `date` oder `sleep` abfragen. Nie GitHub-Billing vorschlagen.
- TestFlight nur nach grünem CI: `bash scripts/testflight-fenster.sh` im Hintergrund.

## Datenschutz (wichtig)
- Echte Adressen, Koordinaten, Namen Dritter stehen nie im Git, nie in Spec, Tests, Fixtures, Kommentaren, Logs oder Commit-Texten. Sie kommen aus `PrivateDaten.beispiel.json` (Repo) oder `PrivateDaten.json` (gitignored, Secret `PRIVATE_DATEN_JSON`).
- Gesundheitsdaten verlassen das Gerät nur auf ausdrückliche Freigabe der Person (Kopplung mit Lovea, Freunde). Passwörter nie im Klartext speichern; Profil und Anmeldung liegen im Schlüsselbund und überleben Updates.
- Nichts senden, kaufen, buchen, kündigen.

## Code
- Swift 6 strikt, kein Default-MainActor. Reine Logik als `enum` mit `static func`, Zustand `@MainActor @Observable final class`, Datentypen `Sendable`. Bezeichner ASCII, Oberflächentexte Deutsch mit Umlauten, keine Emojis. Keine Swift-Pakete. Test zuerst.
- Konstanten in `@MainActor`-Typen, die `nonisolated` Code liest: `nonisolated static let` (sonst Bauabbruch, Bahnherz-Lehre).
- Fallen (Lovea, Bahnherz): `WidgetBundle`-Datei braucht `import SwiftUI`; `AppIntent.defaultQuery` als `let`; `PreferenceKey.defaultValue` als berechnete `static var`; `Activity`-Objekte nicht Sendable; kein `weak` in `@Observable`; `A ?? B ?? (try? await C)` in zwei Schritte teilen; kein statischer `DateFormatter` (`FormatStyle`); kein `await` in `XCTAssert`; lange `body`-Ketten teilen; `containerURL` der App-Gruppe ist in Tests `nil`.
- Entitlements nur `application-groups` und die drei HealthKit-Schlüssel (CI-Job `patterns` prüft das). Mit HealthKit verlangt Apple beide Texte `NSHealthShareUsageDescription` und `NSHealthUpdateUsageDescription`.
- Gespeicherte Typen (Codable-Dateien, `JSONDatei`): neue Felder immer optional oder mit `decodeIfPresent` und Standardwert, sonst sind Daten nach dem TestFlight-Update weg. Jede Änderung an einem gespeicherten Typ bekommt einen Fall in `AlteDateienLadenTests` (eingefrorene Datei vom letzten Stand).
- XcodeGen: `group:` einer Quelle nie wie ihr Pfad benennen. Lokal vor jedem Commit `bash scripts/check-schnell.sh`.
- Bewegung nur bei Ereignissen (Akku-Lehre aus Lovea): keine endlosen Hintergrundanimationen.

## Arbeitsweise
- Spec zuerst, Plan, Bau (Test zuerst), Review, vor TestFlight `agent-skills:ship`. Design: `docs/research/design.md` und `~/Documents/Obsidian/Personal/19 Bastelprojekte/Lumen Fit/design.html`. Ponytail: kleinster korrekter Diff.
- Commit-Nachrichten kurz auf Deutsch, am Ende die vom System vorgegebenen `Co-Authored-By`- und `Claude-Session`-Zeilen für dein Modell.
- Ehrlich berichten: alles, was nur der Compiler oder ein Gerät beweist, ist "ungeprüft", bis CI grün ist oder Ahmed es am Handy sieht.
