# Lumen Fit – Regeln für Agenten

iOS-App (SwiftUI, Swift 6, iOS 26, iPhone) für Gesundheit und Fitness, für Ahmed, seine Partnerin und Kollegen: Gym, Essen, Schlaf, Schritte, Coach, Fortschritt, Lumi. Design wie Hevy, ein Theme hell/dunkel nach System (seit 10.11.2026); Tabs Startseite, Training, Fortschritt, Freunde, Profil. Client-only: kein Server, keine Konten im Netz. Spec: `SPEC.md` (Wahrheit), Begriffe `CONTEXT.md`, Qualitätslatte `CONSTRAINTS.md`, Plan `tasks/plan.md`, Aufgaben `tasks/todo.md`, Modulaufträge `tasks/auftraege/<id>.md`, 100 Ideen `docs/ideas/lumen-fit.md`, Recherche und Vorlagen `docs/research/`. Lies `CONSTRAINTS.md` vor dem Schreiben von Code und schwäche sie nie ab, damit eine Änderung durchgeht.

## Pfade
- Repo: `/home/tobi/projects/lumen-fit-ios`, GitHub `Tobito320/lumen-fit-ios`, privat. Vault-Anleitung: `~/Documents/Obsidian/Personal/19 Bastelprojekte/iOS-Apps ohne Mac – Ablauf bis TestFlight.md`, Design-Entwurf: `~/Documents/Obsidian/Personal/19 Bastelprojekte/Lumen Fit/design.html`. Vorlage-Repo für die Konfiguration: `~/projects/bahnherz-ios`. Quelle für Fertiges: `~/projects/lovea-app-ios` (nur lesen, Lovea nie ändern, nie dort committen).
- Bundle ID `com.onlyus.lumen-fit`, Widgets `com.onlyus.lumen-fit.widgets`, App Group `group.com.onlyus.lumen-fit`, zusätzlich `group.com.onlyus.lovea` für Band und Kopplung.
- Dateien gehören je einem Modul (`SPEC.md` Abschnitt 12). Fremde Ordner nie ändern; Wünsche an das Grundgerüst in den Abschlussbericht.

## Bau
- Kein Mac, kein Swift lokal. Kompiliert und getestet wird nur in GitHub Actions (`ios-ci.yml`, `macos-26`). Lokal nur: `swift-syntax-check <Dateien>`, `bash scripts/check-schnell.sh`, `bash scripts/pruefe-privat.sh`, `python3 -I docs/research/kontrast.py`.
- Actions laufen nur bei öffentlichem Repo. Immer: `bash scripts/ci-fenster.sh` im Hintergrund (Privat-Check, öffentlich, Push, Lauf, `trap` macht wieder privat). Danach EINMAL blockierend `timeout 590 gh run watch <ID> -R Tobito320/lumen-fit-ios --exit-status`; nie einzeln per `gh run view`, `date` oder `sleep` abfragen. Nie GitHub-Billing vorschlagen. Module bauen nicht selbst in CI; der Integrationsschritt macht es.
- TestFlight nur nach grünem CI: `bash scripts/testflight-fenster.sh` im Hintergrund.

## Datenschutz (wichtig)
- Echte Adressen, Koordinaten, Namen von Personen und Studios stehen nie im Git, nie in Spec, Tests, Fixtures, Kommentaren, Logs oder Commit-Texten (Ausnahme: der 1:1-Auftragstext in `SPEC.md` Abschnitt 0). Im Code sagt man "Partner" und "Freund". Studio-Vorgaben kommen aus `PrivateDaten.beispiel.json` (Repo) oder `PrivateDaten.json` (gitignored, Secret `PRIVATE_DATEN_JSON`). Gate: `bash scripts/namen-gate.sh` muss sauber sein (die Namensliste liegt in `~/.config/lumen-fit/namen.txt`, nie im Git; das Gate meldet nur Pfad:Zeile).
- Gesundheitsdaten verlassen das Gerät nur auf ausdrückliche Freigabe der Person (Kopplung mit Lovea, Freundeskarte) und nur als Zusammenfassung. Passwörter nie im Klartext speichern; Profil und Passwort-Spur liegen im Schlüsselbund, der Start fragt nie nach dem Passwort.
- Nichts senden, kaufen, buchen, kündigen. Kein Wecker, keine Erinnerung, kein AlarmKit (Ahmed: Lumen Fit ist nur Health).

## Code
- Swift 6 strikt, kein Default-MainActor. Reine Logik als `enum` mit `static func`, Zustand `@MainActor @Observable final class`, Datentypen `Sendable`. Bezeichner ASCII, Oberflächentexte Deutsch mit Umlauten, keine Emojis. Keine Swift-Pakete. Test zuerst.
- Konstanten in `@MainActor`-Typen, die `nonisolated` Code liest: `nonisolated static let` (sonst Bauabbruch, Bahnherz-Lehre).
- Weitere Swift-6- und iOS-26-Fallen (Haken im Intent, Darwin-Rückruf, FoundationModels, HealthKit-Ablehnung): `SPEC.md` Abschnitt 10. Typnamen sind im ganzen Ziel eindeutig (`private`/`fileprivate` oder Modulsilbe, `bash scripts/typnamen-doppelt.sh`).
- Fallen (Lovea, Bahnherz): `WidgetBundle`-Datei braucht `import SwiftUI`; `AppIntent.defaultQuery` als `let`; `PreferenceKey.defaultValue` als berechnete `static var`; `Activity`-Objekte nicht Sendable; kein `weak` in `@Observable`; `A ?? B ?? (try? await C)` in zwei Schritte teilen; `private(set)` nicht aus anderer Datei schreiben; kein statischer `DateFormatter` (`FormatStyle`); kein `await` in `XCTAssert`; lange `body`-Ketten teilen; `containerURL` der App-Gruppe ist in Tests `nil`; SecItem kann im unsignierten Simulator `-34018` melden (Port mit Fake).
- Daten: Lovea-Ops und -Faltungen leben lokal weiter (`LokalerRaum`, `SPEC.md` 5.3). Arten aus Lovea unverändert, neue mit Vorsilbe `fit.`. Gespeicherte Typen: neue Felder immer optional oder mit `decodeIfPresent` und Standardwert, sonst sind Daten nach dem TestFlight-Update weg. Jede Änderung an einem gespeicherten Typ bekommt einen Fall in `AlteDateienLadenTests`.
- Portieren aus Lovea nach `SPEC.md` 5.8: erst reine `*Logik`-Dateien samt Tests, dann Stores, dann Oberflächen neu im Lumen-Design; `Person` wird `ProfilID`, `Raum.shared` wird `umgebung.raum`, Singletons werden Stores im `DatenSatz`; oben `// Quelle: Lovea Health/<Pfad>`; `muskelkarte.json` nie übernehmen (AGPL).
- Umgebung in Views: `@Environment(AppUmgebung.self) private var umgebung`. Bausteine statt Eigenbau: `HeroKarte`, `ListenKarte`, `Pille`, `LeerZustand`, `FehlerKarte`, `DiagrammKarte`, `RollZahl`, `lumenToast`, `LumiView`, `LumenBogen`, `Feder`, `HaptikZentrale`.
- Test-Hilfen des Grundgerüsts (`LumenFit/Tests/Grundgeruest/TestHilfen.swift`, nicht ändern, eigene Helfer mit eigenem Namen im Modulordner): `TestUhr`, `FakeHealthLeser`, `SkriptLader`, `FakeMitteiler`, `FakeLiveAnzeige`, `FakeBandDienst`, `FakePartnerAustausch`, `XCTestCase.tempOrdner()`, `TestDaten`, `FixtureOrt` (Fixtures nur darüber). Umgebung in Tests: `AppUmgebung.vorschau(fixtures: FixtureOrt.ordner)`.
- XcodeGen: `group:` einer Quelle nie wie ihr Pfad benennen. Lokal vor jedem Commit `bash scripts/check-schnell.sh`.
- Verträge des Grundgerüsts (`SPEC.md` 5.9): `AppUmgebung.geteilt` ist die eine Instanz; `ModulStart.starteAlle` läuft synchron in `LumenFitApp.init()` und setzt die Ports `coachMotor`, `liveAnzeige`, `trainingSteuerung`, `band`; im Test-Host startet nichts; Start-Argumente `-lumenFitDemo`, `-lumenFitTab`, `-lumenFitTheme`, `-lumenFitLumi`, `-lumenFitRoute`, `-lumenFitFixtures`.
- Bewegung nur bei Ereignissen (Akku-Lehre aus Lovea): keine endlosen Hintergrundanimationen; Reduce Motion, Stromsparmodus und erhöhter Kontrast beachten.

## Arbeitsweise
- Spec zuerst, Plan, Bau (Test zuerst), Review, vor TestFlight `agent-skills:ship`. Matt-Pocock-Skills: `to-spec`, `domain-modeling`, `to-tickets`, `tdd`, `code-review`. Design: `ui-pro-swiftui`, `docs/research/design.md` und `~/Documents/Obsidian/Personal/19 Bastelprojekte/Lumen Fit/design.html`. Ponytail: kleinster korrekter Diff.
- Commit-Nachrichten kurz auf Deutsch, am Ende die vom System vorgegebenen `Co-Authored-By`- und `Claude-Session`-Zeilen für dein Modell. Kleine Commits.
- Ehrlich berichten: alles, was nur der Compiler oder ein Gerät beweist, ist "ungeprüft", bis CI grün ist oder Ahmed es am Handy sieht.
## Bewegung: iOS-Gefühl (Ahmed 10.11.2026)

Ahmed nutzt nur UIs, die flüssig sind. Für jede UI-Bewegung gilt:
- Feder statt fester Dauer: `.spring`, `.smooth`, `.snappy`, `.interactiveSpring`. Kein `.linear` und kein `.easeInOut` für UI-Bewegung (Ausnahme: reines Ein-/Ausblenden und endlose Pulse).
- Jede Animation ist unterbrechbar und lenkt von der aktuellen Stelle und Geschwindigkeit um, kein Neustart, kein Sprung.
- Gesten treiben die Animation: Element folgt dem Finger 1:1 (`DragGesture`, `interactiveSpring`), beim Loslassen geht die Geschwindigkeit (`predictedEndTranslation`) in die Feder (Wischen, Schließen).
- Gummiband über den Rand statt harter Anschlag.
- Details: `RoundedRectangle(cornerRadius:, style: .continuous)`, dezenter Blur, Haptik (`sensoryFeedback`) wo sie passt.
- Eigener Code, keine Fremdbibliothek für Animation. Volltext: Vault `80 System/Memory/Apps bauen – Compiler ohne Mac, Modelle, kein Caveman (08.11.).md`.
- UI-Handwerk (Reel charles.unemployed, Ahmed 10.11.2026):
  - Große Trefferfläche (Fitts): ganze Zeile oder Fläche ist zieh- und tippbar, nicht nur das kleine Bedienelement.
  - Klare Hierarchie: der gewählte oder gezeigte Wert ist das Größte auf dem Bildschirm.
  - Eine Akzentfarbe, nur für das eine Wichtige (Von Restorff).
  - Objektkonstanz: Werte gleiten oder morphen statt hart zu wechseln, das Auge kann folgen.
  - Einrasten: Ende einer Geste landet immer auf einem gültigen Wert.
  - Tabellenziffern (`.monospacedDigit()`) für wechselnde Zahlen, das Layout springt nie.
  - Nur das Delta animieren: nur die Ziffer oder der Teil, der sich ändert, bewegt sich.
  - Trägheit: Wischen gleitet aus und bremst natürlich ab.
  - Mehrkanal-Rückmeldung: Bild plus Haptik (plus leiser Ton, wo es passt) bei jedem Schritt.
  - Affordance: Bedienelemente zeigen schon bei Hover oder Drücken, was gleich passiert.
  - Körperliche Bilder für Wähler (Drehrad, Walze), dann braucht es keine Anleitung.
