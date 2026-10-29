AUFTRAG: Grundgerüst der iOS-App Lumen Fit (vor allen Modulen).
Maßgeblich ist `tasks/auftraege/grundgeruest.md` im eigenen Worktree; weicht dieser Text von der Datei ab, gilt die Datei.

KONTEXT
Lumen Fit: iOS-App (SwiftUI, Swift 6, iOS 26, iPhone) für Gesundheit und Fitness, client-only (kein Server, keine Konten), Standard-Design monochrom, Figur Lumi. Repo /home/tobi/projects/lumen-fit-ios, Zweig main. Lies zuerst CLAUDE.md, CONSTRAINTS.md, CONTEXT.md, SPEC.md (ganz, besonders 5.3 bis 5.9 und 7) und docs/research/ (konfiguration.md, design.md, daten.md). Kein Mac: lokal nur `swift-syntax-check` und `bash scripts/check-schnell.sh`; Kompilieren und Testen nur in CI über `scripts/ci-fenster.sh` (im Hintergrund, danach einmal `timeout 590 gh run watch <ID> -R Tobito320/lumen-fit-ios --exit-status`, nie einzeln abfragen). Test zuerst, kleinster korrekter Diff. Quelle für Fertiges: /home/tobi/projects/lovea-app-ios/Lovea/Sources (nur lesen, Lovea nie ändern).

ZIEL
Alles Gemeinsame, damit neun Module danach parallel in eigenen Worktrees bauen können, ohne eine gemeinsame Datei anzufassen: Projekt und CI, Datenkern aus Lovea (Op, Faltungen, lokaler Log, Stores), Konto mit Schlüsselbund, Gesundheits-Port, Design-System, App-Hülle mit Routen, Stubs für jedes Modul, Demo-Start für CI-Bilder, Widget-Hülle. Am Ende ist die leere App mit allen Stubs grün in CI.

DEINE ORDNER (alles, was SPEC 5.9 in der Dateiliste "Grundgerüst" nennt, und nur das; die Ordner der Module legst du nur als Stub-Dateien an)
- Wurzel: project.yml, .gitignore, .github/workflows/, scripts/, signing/ (gitignored), LumenFit/LumenFit.entitlements, LumenFitWidgets/LumenFitWidgets.entitlements
- Gemeinsam/ (Zeit, Daten, Speicher, Modelle, Navigation, Design, Bruecke; Widgets nur die zwei Stubs)
- LumenFit/Sources/{App,Konto,Daten,Gesundheit,Dienste,Design}/, LumenFit/Resources/, LumenFit/Tests/Grundgeruest/, LumenFit/Tests/Fixtures/<Modul>/ (Ordner und Kopien)
- Stubs in LumenFit/Sources/Module/<Modul>/ und LumenFitWidgets/Sources/ nach Tabelle SPEC 5.9

TICKETS (Reihenfolge und Kanten stehen in tasks/todo.md; G2, G4, G6 dürfen parallel laufen, wenn jedes nur seine Dateien anfasst)
- G1 Repo-Gerüst: Vorlagen aus docs/research/vorlagen kopieren (Zuordnung konfiguration.md Abschnitt 3; asc.mjs aus ~/projects/bahnherz-ios/signing/ nach signing/), `chmod +x`, die Vorlagen bringen Namens-Gate (`namen-gate.sh`), Typnamen-Gate (`typnamen-doppelt.sh`) und Umfang-Gate in `check-schnell.sh` und `ios-ci.yml` schon mit (nur kopieren; die Namensliste liegt in `~/.config/lumen-fit/namen.txt`, nie im Git), Icon ohne Alpha (konfiguration.md Abschnitt 6 Schritt 7; Entwurf: ein offener Bogen mit Punkt, kein Ringsatz), `git init`-Stand prüfen, `gh repo create Tobito320/lumen-fit-ios --private --source . --remote origin`, erste CI mit leerer App grün.
- G2 Datenkern: Port nach der Tabelle "Datenkern" in SPEC 5.8 (Modus A/K, Tests mit), dazu `LokalerOpLog` und `LokalerRaum` (neu, Vorbild Loveas OpLog/Raum, SPEC 5.3), `JSONDatei` und `AppGruppe`, die `fit.*`-Rumpf-Typen und `LumiStufe` (`StimmungsEintrag`, `MerkEintrag`, `BandSchlafOp`, `BandTagOp`, `MeilensteinStand`, SPEC 5.3 und 5.9; `SchlafNacht` und `SchlafAbschnitt` werden `Codable`).
- G3 Stores: `TrainingStore`, `EssenStore`, `HabitStore` als Ports der Lovea-Modelle ohne Person, Singleton, Server, Figur und Punkte; `MeilensteinStore`, `CoachStore`, `EinstellungenStore`, `ZieleStore`, `VerbindungStore` neu und klein; `DatenSatz`.
- G4 Konto: `Schluesselbund` (Port), `KeychainSchluesselbund` (SecItem, AfterFirstUnlock, synchronisierbar; Lesen und Löschen mit `kSecAttrSynchronizableAny`, Schreiben erst synchronisierbar und bei Fehler lokal, SPEC 5.4), `SpeicherSchluesselbund` (Fake und Rückfall bei -34018), `Passwort` (PBKDF2 über CommonCrypto, 600.000 Runden, konstante Zeit), `ProfilStore`; Neuinstallations-Fall.
- G5 Gesundheit: `HealthLeser`, `HKHealthLeser` (Vorbild Loveas `HealthModell`), `FakeHealthLeser`, `HealthSchreiber`, `HealthLeser.beobachte` (`HKObserverQuery` samt `enableBackgroundDelivery` für Schritte, Schlaf, Training; der Handler ruft den `completionHandler` nach der Arbeit; `ModulStart.starteAlle` meldet es synchron an und löst `Ereignis.healthAktualisiert` und die `beiAbruf`-Aufgaben aus, SPEC 5.5), `GesundheitsStand` (60 Tage beim ersten Mal; Initialisierer mit `band:`, je Tag das Maximum aus Health und `BandTagOp`; `HealthZugriff.verweigert` nur für Schreibtypen, SPEC 4).
- G6 Design: `Farben`, `Theme`, `Muster`, `LumiView` (nach den drei SVG-Vorlagen `docs/research/lumi/*.svg`, Stand v10, nicht nach dem Flammenpfad aus design.md Abschnitt 10; mit `stufe:`), `LumenBogen`, `LumenBalken`, `Abstand`, `Feder`, `HaptikZentrale`, `Bausteine` (mit `DiagrammKarte`, `RollZahl`, `lumenToast` und `ToastInhalt`), `HeroKarte`, `AvatarKapsel`, `Hintergrund`, Port von `kontrast.py` als `FarbenKontrastTests`, Symbol-Test.
- G7 Hülle: `LumenFitApp`, `AppRootView` (Onboarding wenn `!profil.hatProfil`, sonst Tabs), `LumenFitTab`, `Router`, `Route`, `RouteURL`, `RouteAnsicht`, `AppUmgebung` (`geteilt`, `vorschau`, `live`, `demo`), `EreignisKanal`, `ModulStart`, `Demo` mit den Start-Argumenten aus SPEC 5.9, `LoveaVertrag` und `LoveaBruecke` (beide Quellen aus SPEC 5.5: Loveas `widget-stand.json` nur lesen und `partner.json`; Fixtures in `LumenFit/Tests/Fixtures/Grundgeruest/`), `Route.freund(daten:)` samt `RouteURL`, `Ereignis.vordergrund`, `AppUmgebung.beiAbruf` mit dem BGTask-Handler, `LumenFitApp` mit `.onOpenURL`, `.onContinueUserActivity(CSSearchableItemActionType)` und `scenePhase` (SPEC 5.9 Vertrag 8), alle Stubs (Typnamen exakt wie in SPEC 5.9), Widget-Bundle mit den sieben Stub-Widgets, Test-Hilfen, Fixtures-Kopien, `InfoPlistTests`, `AlteDateienLadenTests`.

IDEEN, DIE DU EINBAUST (1 bis 10; Titel und Nutzen in docs/ideas/lumen-fit.md)
1 Profil für immer (G4), 2 Mehrere Profile pro Gerät (G4), 3 Fünf Themes (G6), 4 Muster (G6), 5 Lumi (G6), 6 Lumen-Bögen (G6), 7 Haptik und Federn (G6), 8 Erster Tag schon voll (G5), 9 Jede Seite hat einen Link (G7), 10 Fehler, die helfen (G2 und G7).

REGELN, DIE DU BEACHTEST
- Die öffentlichen Typen in SPEC 5.9 sind verbindlich: Namen, Parameter, Stub-Dateinamen. Lovea-Typen behalten Namen und Felder (nur `Person` wird `ProfilID`). Abweichungen nur mit Grund im Commit und in SPEC 5.9 nachgezogen.
- Beim Portieren: SPEC 5.8 (Ersetzungstabelle, Regeln 1 bis 8). Keine Personennamen, keine Studios, keine Orte in den Code; `bash scripts/namen-gate.sh` muss sauber sein.
- Stubs zeigen `LeerZustand` mit Lumi und "Kommt bald". Jede `Route` führt zu genau einem Stub-Typ.
- `ModulStart.starteAlle` läuft synchron in `LumenFitApp.init()`; im Test-Host (XCTestConfigurationFilePath) startet nichts.
- `nonisolated static let` für Konstanten in `@MainActor`-Typen, die nonisolated Code liest; `rm -rf derived/Build` im CI-Test-Schritt; beide iPad-Ausrichtungen in der Info.plist.
- Private Daten nie ins Git; `PrivateDaten.json` nur als Beispiel im Repo.
- Kein Wecker, keine Erinnerung, kein AlarmKit.

AKZEPTANZ
- `ios-ci.yml` grün auf `main` (xcodegen, alle Tests, 0 Warnungen), `scripts/pruefe-privat.sh`, Namens-Gate und Typnamen-Gate sauber.
- Jeder Stub aus SPEC 5.9 existiert; `RouteAnsicht` kennt jede Route; die leere App startet im Simulator mit allen fünf Tabs (Screenshot-Schritt der CI liefert Bilder).
- Alle portierten Lovea-Tests der Datenkern-Tabelle laufen; `AlteDateienLadenTests` und die Neuinstallations-Fälle (Schlüsselbund-Profil da, Ordner fehlt) sind grün.
- Die Skizzen in SPEC 5.9 sind durch echten Code ersetzt; `swift-syntax-check` OK.
- Tag `grundgeruest-fertig`, Zweige `modul/<id>` und Worktrees angelegt, Modulaufträge gegen den echten Code auf Typnamen geprüft (Abweichungen in den Aufträgen nachgezogen).

TESTS
- Port-Tests der Datenkern-Dateien; `LokalerOpLogTests` (Anhängen, doppelte Id, kaputte letzte Zeile), `LokalerRaumTests` (Replay, live), `PasswortTests`, `ProfilStoreTests`, `RouteURLTests` (alle Formen aus SPEC 5.9), `DatumTests`, `JSONDateiTests`, `FarbenKontrastTests`, `SymbolNamenTests`, `InfoPlistTests`, `LoveaBrueckeTests` (beide Quellen, mit Fixtures), `LumiStufeTests`, `AppUmgebungTests`.

ABSCHLUSSBERICHT
Geänderte Dateien, Abweichungen von SPEC 5.9 samt Grund, ungeprüfte Punkte (nur Gerät oder Compiler), Ergebnis des ersten CI-Laufs (Zahlen).
