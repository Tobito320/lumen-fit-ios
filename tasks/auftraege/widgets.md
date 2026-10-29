AUFTRAG: Modul „widgets“ (Widgets: Home- und Sperrbildschirm, Live Activity, Intents, Siri, Spotlight, Steuerelement) der iOS-App Lumen Fit.

KONTEXT
Lumen Fit: iOS-App (SwiftUI, Swift 6, iOS 26, iPhone) für Gesundheit und Fitness, client-only (kein Server, keine Konten), Standard-Design monochrom, Figur Lumi. Repo /home/tobi/projects/lumen-fit-ios, Zweig modul/widgets im eigenen Worktree, Grundgerüst ist gemergt. Lies zuerst CLAUDE.md, CONSTRAINTS.md, CONTEXT.md, SPEC.md (Abschnitte 5.3, 5.8, 5.9, 6, 11) und docs/research/design.md. Kein Mac: lokal nur swift-syntax-check, Compiler und Tests laufen im Integrationsschritt in CI (starte kein CI). Test zuerst, kleinster korrekter Diff. Quelle für Fertiges ist /home/tobi/projects/lovea-app-ios/Lovea/Sources (nur lesen, Lovea nie ändern; Portierungsregeln SPEC 5.8). Vorlage für Konfiguration war Bahnherz.

ZIEL
Das Widget-Ziel und seine App-Seite: Widgets in den Themes der App, die Live Activity fürs Training mit "Satz fertig" auf dem Sperrbildschirm, interaktive Gewohnheiten, Siri-Kurzbefehle, Spotlight und ein Steuerelement. Widgets lesen nur einen Snapshot aus der eigenen App Group.

DEINE ORDNER (nur hier schreiben; alles andere ist tabu)
- LumenFit/Sources/Module/Widgets/
- LumenFit/Tests/Module/Widgets/
- LumenFit/Tests/Fixtures/Widgets/
- LumenFitWidgets/Sources/Widgets/
- Gemeinsam/Widgets/

DU NUTZT AUS DEM GRUNDGERÜST (Namen stehen in SPEC 5.9)
- `LiveAnzeige` und `TrainingLiveStand` (du setzt `umgebung.liveAnzeige` in `WidgetsModul.start`), `TrainingSteuerung` (Intents rufen `AppUmgebung.geteilt.trainingSteuerung`), `HabitStore`, `daten` (für den Snapshot), `AppGruppe.ordner()`, `Route`/`RouteURL` (Deep Links), `ereignisse` (Snapshot bei jeder Änderung neu schreiben)
- Gemeinsam aus dem Grundgerüst: `Palette`, `LumenFarben`, `LumenBogen`, `LumiView`, `Datenbereich`, `ThemaID`, `Habit`, `HabitLogik`, `UebungsKatalog`
- Stubs, die du ersetzt: `WidgetsModul`, `Gemeinsam/Widgets/WidgetSnapshot.swift`, `Gemeinsam/Widgets/TrainingAktivitaet.swift` und die sieben Stub-Widgets in `LumenFitWidgets/Sources/Widgets/`: `BoegenWidget`, `PlanSerieWidget`, `SperrbildschirmWidget`, `EssenRestWidget`, `HabitenWidget`, `TrainingLiveWidget`, `SchnellzugriffSteuerung`. `LumenFitWidgetsBundle.swift` (Grundgerüst) listet sie schon; du änderst das Bundle nie, ein weiteres Widget wäre ein Wunsch im Abschlussbericht

AUS LOVEA PORTIEREN (unter Lovea/Sources/Health/, wenn nicht anders angegeben; Modus K kopieren, A anpassen, N neu, - nicht)
- LoveaWidgets/Shared/GymAktivitaet.swift (ActivityAttributes), GymSchrittIntent.swift (LiveActivityIntent), WidgetPendingOp.swift, WidgetStand.swift, WidgetGruppe.swift, WidgetDatum.swift, WidgetStil.swift, LockscreenLogik.swift [A (kein Partner, keine Punkte, Gruppe `group.com.onlyus.lumen-fit`)] Tests: Tests in Lovea/Tests mit Namen *Widget* oder *Lockscreen*, soweit sie diese Logik prüfen
- LoveaWidgets/Sources/GymLiveWidget.swift, GymWocheWidget.swift, HabitWidget.swift, LockscreenWidgets.swift, WidgetStandProvider.swift, WidgetLesen.swift, WidgetOpPoster.swift [A / N (Design der Tokens)]
- NICHT übernehmen: EssenAktivitaet.swift, EssenLiveWidget.swift, PartnerWidget.swift, PartnerJetztWidget.swift, FotoFrageWidget.swift, GymDuellWidget.swift, SchritteDuellWidget.swift, PunkteChallengeWidget.swift, DenkAnDichIntent.swift, GymHeuteIntent.swift (bleiben in Lovea) [-]

NEU ZU BAUEN
- `WidgetSnapshot` (Codable, alle Felder optional: Thema, Bögen, Plan, Serie, Kalorien-Rest, Habits, Lumi-Stimmung) und `WidgetSnapshotSchreiber` (schreibt `widget-stand.json` im Gruppenordner bei jedem `Ereignis`, höchstens alle 30 s, ruft `WidgetCenter.shared.reloadAllTimelines`); Widgets: klein Bögen, mittel Plan und Serie, Sperrbildschirm rund/rechteckig/Zeile, Essen-Rest; getönter Modus nutzt nur Text und Symbole
- `TrainingAktivitaet` (ActivityAttributes in `Gemeinsam/Widgets/`), `LiveActivityDienst: LiveAnzeige` (`Activity.request/update/end`, nur bei Satzwechsel aktualisieren), Live-Activity-Oberfläche (kompakt: Lumi und Dauer; erweitert: Übung, Satz n von m, Pause-Countdown mit `Text(timerInterval:)`; Sperrbildschirm: Fortschrittsbalken in Trainieren-Tief)
- `SatzFertigIntent: LiveActivityIntent` (läuft in der App, ruft `trainingSteuerung.satzFertig()`); `HabitAbhakenIntent` für das interaktive Widget schreibt eine Op in `widget-ops.jsonl` der Gruppe, die die App beim Vordergrund und per Darwin-Anstoß in den Raum übernimmt (idempotent über Op-Id)
- `LumenFitKurzbefehle: AppShortcutsProvider` (Training starten, Gewicht eintragen, Essen scannen; öffnen die passende `Route` oder rufen `trainingSteuerung`), Spotlight-Index (`CSSearchableItem` für Übungen, Pläne, Favoriten; Tipp öffnet `lumenfit://uebung?id=...`), Steuerelement (`ControlWidgetButton` für Training starten und Scan, Aktionstaste tauglich); Demo-Saat `WidgetsModul.demoSaat` (Snapshot mit Demo-Werten)

IDEEN, DIE DU EINBAUST (alle müssen am Ende drin sein)
91. **Widget Bögen** – klein: drei Bögen mit den Schritten in der Mitte, im Theme deiner App.
92. **Widget Plan und Serie** – mittel: heutiger Plan, Serie und Bögen.
93. **Sperrbildschirm-Widgets** – rund (Schritte), rechteckig (Schlaf und Erholung), Zeile (Gym-Serie).
94. **Live Activity Training** – Dynamic Island und Sperrbildschirm mit Übung, Satz 3 von 4, Pausen-Countdown und Fortschrittsbalken.
95. **Satz fertig vom Sperrbildschirm** – ein Knopf in der Live Activity setzt den Haken, ohne die App zu öffnen.
96. **Gewohnheiten zum Abhaken** – interaktives Widget, Haken direkt auf dem Home-Bildschirm.
97. **Widget Essen** – Rest-Kalorien und Protein heute, ein Tipp öffnet den Scan.
98. **Siri und Kurzbefehle** – "Training starten", "Gewicht eintragen" und "Essen scannen" als App-Kurzbefehle ohne Einrichtung.
99. **Spotlight** – Übungen, Pläne und Favoriten tauchen in der iPhone-Suche auf und öffnen die Seite.
100. **Steuerelement im Kontrollzentrum** – Knopf für Training starten oder Scan, auch für die Aktionstaste.

FIXTURES
Fixtures/Widgets: `widget-snapshot-beispiel.json` (erfunden); Tests für Snapshot-Schreiber mit Temp-Ordner.

AKZEPTANZ
- Widgets lesen nur `widget-stand.json`; ohne Datei zeigen sie einen ruhigen Leerzustand (kein Absturz, `containerURL` ist in Tests nil)
- `SatzFertigIntent` und `HabitAbhakenIntent` sind getestet (Fake-Steuerung, Temp-Gruppe, doppelte Op-Id wird übersprungen)
- Live Activity wird nur während eines Trainings gestartet und nach `trainingBeendet` beendet; Updates nur bei Satzwechsel
- Textgröße nie unter 12 pt; Datenfarben nur in Tief-Variante; Muster entfällt im getönten Modus
- Kein Partner-Widget, keine Punkte, kein Essen-Live; die Ziel-Entitlements bleiben unverändert
- Gemeinsam: alle Ideen oben eingebaut oder mit Grund als nicht umsetzbar gemeldet; nur die eigenen Ordner geändert (`git diff --name-only main...modul/widgets`); `swift-syntax-check` OK auf allen neuen Dateien; Namens-Gate und Umfang-Gate (CONSTRAINTS) leer; alle Stub-Dateien des Moduls ersetzt ("Kommt bald" kommt nirgends mehr vor); keine Unterdrückungen; alle Texte Deutsch ohne Emojis; jede portierte Datei trägt oben `// Quelle: Lovea Health/<Pfad>`.

TESTS
- `WidgetSnapshotTests`, `SnapshotSchreiberTests`, `SatzFertigIntentTests`, `HabitAbhakenIntentTests`, `LiveActivityDienstTests` (mit Fake-Fabrik), `SpotlightIndexTests`
- Portierte Lovea-Tests laut Tabelle
- Widget-Oberflächen nur als Compile-Beleg in CI; Aussehen steht in der Testliste

ABSCHLUSSBERICHT
Kurz: geänderte Dateien, welche Idee wie umgesetzt ist, was nur Compiler oder Gerät beweist (ungeprüft), Wünsche ans Grundgerüst (du änderst es nie), Annahmen für SPEC Abschnitt 15.
