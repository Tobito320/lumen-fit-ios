AUFTRAG: Modul „gym“ (Gym-Tab: Training, Logging, Pausen-Timer, Rekorde, Katalog, Splits, Cardio, Studio) der iOS-App Lumen Fit.
Maßgeblich ist `tasks/auftraege/gym.md` im eigenen Worktree; weicht dieser Text von der Datei ab, gilt die Datei.

KONTEXT
Lumen Fit: iOS-App (SwiftUI, Swift 6, iOS 26, iPhone) für Gesundheit und Fitness, client-only (kein Server, keine Konten), Standard-Design monochrom, Figur Lumi. Repo /home/tobi/projects/lumen-fit-ios, Zweig modul/gym im eigenen Worktree, Grundgerüst ist gemergt. Lies zuerst CLAUDE.md, CONSTRAINTS.md, CONTEXT.md, SPEC.md (Abschnitte 5.3, 5.5, 5.8, 5.9, 6, 10 mit den Fallen, 11) und docs/research/design.md. Kein Mac: lokal nur swift-syntax-check, Compiler und Tests laufen im Integrationsschritt in CI (starte kein CI). Test zuerst, kleinster korrekter Diff. Quelle für Fertiges ist /home/tobi/projects/lovea-app-ios/Lovea/Sources (nur lesen, Lovea nie ändern; Portierungsregeln SPEC 5.8). Vorlage für Konfiguration war Bahnherz.

ZIEL
Der Tab Gym macht das Training in Hevy/Strong-Qualität: wenige Tipps pro Satz, "Letztes Mal" in der Zeile, Pause von selbst, Rekord sofort. Plan, Katalog, Cardio und Studio-Besuch gehören dazu. Das Segment "Fortschritt" bettet nur `FortschrittSegmentView` ein (Stub, gehört dem Modul fortschritt).

DEINE ORDNER (nur hier schreiben; alles andere ist tabu)
- LumenFit/Sources/Module/Gym/
- LumenFit/Tests/Module/Gym/
- LumenFit/Tests/Fixtures/Gym/

DU NUTZT AUS DEM GRUNDGERÜST (Namen stehen in SPEC 5.9)
- `AppUmgebung.daten.training` (`TrainingStore`: Port von Loveas `TrainingModell`: `plan`, `sessions`, `laufende`, `heutigerTag`, `planSichern`, `einchecken(tag:)`, `starten`, `saetzeSenden`, `fertig`, `tauschen`, `auschecken`, Cardio, Studio-Besuche; ohne `Person`-Parameter)
- Lovea-Typen im Grundgerüst: `TrainingsPlan`, `TrainingsTag`, `PlanUebung`, `PlanSatz` (hat `typ`, `rpe`, `ok`, `sek`, `pause`), `GymD`, `GymSession`, `UebungsLauf`, `Uebung`, `UebungsKatalog`, `SplitVorlage`, `SplitLogik`, `WochenLogik`, `RuhetagLogik`, `CardioEintrag`
- Ports: `trainingSteuerung` (du setzt sie in `GymModul.start`), `liveAnzeige.training(_:)` mit `TrainingLiveStand`, `band.vibriere(.pauseEnde)`, `healthSchreiber.speichere(training:)`, `ereignisse` (`trainingGestartet`, `satzFertig`, `trainingBeendet`), `uhr`
- Stubs, die du ersetzt: `GymModul`, `GymTabView(bereich:)`, `UebungDetailView(id:)`. Stub, den du einbettest: `FortschrittSegmentView`

AUS LOVEA PORTIEREN (unter Lovea/Sources/Health/, wenn nicht anders angegeben; Modus K kopieren, A anpassen, N neu, - nicht)
- Workout.swift (WorkoutLogik, Anstrengung, WorkoutUhr, WorkoutAktion; Views raus) [A] Tests: WorkoutBedienungTests und die Tests zu WorkoutLogik aus TrainingTests als neue Datei `WorkoutLogikTests` (`TrainingTests` gehört dem Grundgerüst und wird nie erweitert)
- WorkoutPuls.swift (`HKWorkoutSession`, Puls und Energie nur mit Sensor) [A]
- GymLive.swift (Live Activity abgleichen) -> ruft `liveAnzeige.training` [A]
- GymTageLogik.swift [K] Tests: GymTageLogikTests
- UebungRekorde.swift [A] Tests: Rekord-Tests aus TrainingTests und UebungsKatalogTests als neue Datei `UebungRekordeTests`, soweit nicht im Grundgerüst
- UebungenSuchlogik.swift, UebungenSynonyme.swift, UebungsSuche.swift [A] Tests: UebungsSucheTests
- GymNeu/GymStartView.swift, SplitAnsichten.swift, SplitEditorView.swift, SplitFreiAnsichten.swift (Views) [N]
- GymNeu/SplitFrei.swift (Logik) [A] Tests: SplitFreiTests
- Studio/GymOeffnung.swift, StudioKarte.swift, StudioProfil.swift (OHNE die fest verdrahteten Studios und Personen: Vorgaben nur aus `PrivateDaten.json`, sonst freies Textfeld) [A] Tests: StudioTests (mit erfundenen Studios)
- Ausweich/AusweichLogik.swift und ausweich.json (Übung tauschen, wenn das Gerät besetzt ist) [K] Tests: AusweichTests
- Zeit/ZeitSchaetzung.swift (Dauer des Trainings schätzen) [K] Tests: Test dazu, falls vorhanden
- NICHT übernehmen: TrainingsPlanView.swift (alter Plan), GymSession.swift-Karten, Defekt/*, WorkoutView.swift (nur Vorbild) [-]

NEU ZU BAUEN
- `GymSitzung: TrainingSteuerung` (`starte`, `satzFertig`, `pauseAendern`, `beende`), setzt `umgebung.trainingSteuerung` synchron in `GymModul.start` ohne Oberfläche, damit ein Intent die App im Hintergrund starten und `satzFertig` ausführen kann (SPEC 5.9 Vertrag 9); sendet `Ereignis`se und `liveAnzeige.training`
- `LetztesMal`: je Satz der Wert aus dem letzten Training derselben Übung (Gewicht und Wiederholungen), Plus/Minus statt Tippen; `PauseLogik`: Standardpause, +/-15 s, Übungs-Pause, Anzeige mit `Text(timerInterval:)`, am Ende Haptik und `band.vibriere(.pauseEnde)`
- `RekordLogik`: live nach dem Satz Gewicht, Wiederholungen, geschätztes 1RM (Epley), Volumen gegen die Historie; Toast über `.lumenToast(_:)` (Grundgerüst) mit Lumi `stolz`, einmal je Rekord
- `ScheibenRechner` (Stange 20 kg, Scheiben 25 bis 1,25, pro Seite) und `AufwaermRechner` (Prozent vom Arbeitsgewicht) als Sheet; Satztypen, RPE-Skala, Supersets (Kopplung `supersatz` an `PlanUebung`), Notiz je Übung
- Übungskatalog-Suche mit Synonymen, Bilder von `UebungsMedien` mit Cache und Symbol-Rückfall; Splits-Auswahl, Wochenplan, Abweichung "heute Beine statt Push"; Cardio-Eingabe (Dauer, Distanz, Puls); Studio einchecken/auschecken mit Hinweis außerhalb der Öffnungszeiten; Training nach Health schreiben, nur wenn `healthSchreiben` an ist (Dauer immer; Energie und Puls nur, wenn Band-Puls oder eine Uhr sie liefern, sonst weglassen, nie schätzen)
- Demo-Saat `GymModul.demoSaat` mit erfundenen Trainings der letzten 8 Wochen

IDEEN, DIE DU EINBAUST (alle müssen am Ende drin sein)
21. **Letztes Mal in der Zeile** – je Satz steht der Wert vom letzten Training, Gewicht und Wiederholungen mit Plus und Minus statt Tippen.
22. **Satztypen und RPE** – Aufwärmen, normal, Drop, bis Versagen; RPE-Skala zum Antippen.
23. **Pausen-Timer, der von selbst startet** – startet beim Haken, plus und minus 15 Sekunden, eigene Pause je Übung, am Ende Haptik und Band.
24. **Rekord sofort** – direkt nach dem Satz ein Toast bei neuem Gewichts-, Wiederholungs- oder 1RM-Rekord; Lumi hüpft einmal.
25. **Scheiben- und Aufwärmrechner** – welche Scheiben pro Seite, Aufwärmsätze in Prozent vom Arbeitsgewicht.
26. **1.333 Übungen auf Deutsch** – Suche mit Synonymen, Muskel und Gerät; Bilder aus dem Netz im Cache, ohne Bild ein Symbol.
27. **Splits und Wochenplan** – Push/Pull/Legs, Ganzkörper, Upper/Lower aus Vorlagen oder frei; "heute Beine statt Push" erkennt die Abweichung.
28. **Supersets und Notizen** – Übungen koppeln, Notiz je Übung und je Training.
29. **Cardio und Studio-Besuch** – Cardio mit Dauer, Distanz und Puls; Einchecken und Auschecken zählt Besuche und warnt außerhalb der Öffnungszeiten.
30. **Training nach Health schreiben** – beim Beenden entsteht ein Workout in Health (Dauer, Energie, Puls); ein Schalter, Standard aus.

FIXTURES
Fixtures/Gym: `lovea-uebungen-auszug.json`, `free-exercise-db-3.json`, `wger-exerciseinfo-de.json`, `wger-language.json` (kopiert das Grundgerüst), eigene Beispielpläne legst du selbst an.

AKZEPTANZ
- Ein Training von Einchecken bis Beenden ist ohne Tippen von Zahlen möglich (Plus/Minus); der Haken startet die Pause; der Rekord erscheint einmal
- Aufwärmsätze zählen nicht für Volumen und Rekorde (Test); Supersets wechseln die Übung ohne eigene Pause
- `trainingSteuerung` führt `satzFertig` ohne geöffnete Oberfläche aus (Test mit `FakeLiveAnzeige`)
- Kein Studio, kein Name, keine Adresse im Quelltext (Namens-Gate); Studio-Vorgaben nur aus `PrivateDaten.json`
- Dynamic Type: Satz-Kästchen werden ab Accessibility-Größe zur Liste; Tippflächen mindestens 44 pt
- Gemeinsam: alle Ideen oben eingebaut oder mit Grund als nicht umsetzbar gemeldet; nur die eigenen Ordner geändert (`git diff --name-only main...modul/gym`); `swift-syntax-check` OK auf allen neuen Dateien; `bash scripts/check-schnell.sh` sauber (Namens-, Umfang- und Typnamen-Gate); alle Stub-Dateien des Moduls ersetzt ("Kommt bald" kommt nirgends mehr vor); keine Unterdrückungen; alle Texte Deutsch ohne Emojis; jede portierte Datei trägt oben `// Quelle: Lovea Health/<Pfad>`.

TESTS
- `LetztesMalTests`, `PauseLogikTests`, `RekordLogikTests`, `ScheibenRechnerTests`, `AufwaermRechnerTests`, `GymSitzungTests`
- Portierte Lovea-Tests laut Tabelle
- Katalog-Test gegen `lovea-uebungen-auszug.json`

ABSCHLUSSBERICHT
Kurz: geänderte Dateien, welche Idee wie umgesetzt ist, was nur Compiler oder Gerät beweist (ungeprüft), Wünsche ans Grundgerüst (du änderst es nie), Annahmen für SPEC Abschnitt 15.
