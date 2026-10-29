AUFTRAG: Modul „coach“ (Coach-Tab: zwei Motoren, Ton, Gedächtnis, Chips, Morgen-Check) der iOS-App Lumen Fit.
Maßgeblich ist `tasks/auftraege/coach.md` im eigenen Worktree; weicht dieser Text von der Datei ab, gilt die Datei.

KONTEXT
Lumen Fit: iOS-App (SwiftUI, Swift 6, iOS 26, iPhone) für Gesundheit und Fitness, client-only (kein Server, keine Konten), Standard-Design monochrom, Figur Lumi. Repo /home/tobi/projects/lumen-fit-ios, Zweig modul/coach im eigenen Worktree, Grundgerüst ist gemergt. Lies zuerst CLAUDE.md, CONSTRAINTS.md, CONTEXT.md, SPEC.md (Abschnitte 5.3, 5.5, 5.8, 5.9, 6, 10 mit den Fallen, 11) und docs/research/design.md. Kein Mac: lokal nur swift-syntax-check, Compiler und Tests laufen im Integrationsschritt in CI (starte kein CI). Test zuerst, kleinster korrekter Diff. Quelle für Fertiges ist /home/tobi/projects/lovea-app-ios/Lovea/Sources (nur lesen, Lovea nie ändern; Portierungsregeln SPEC 5.8). Vorlage für Konfiguration war Bahnherz.

ZIEL
Der Coach antwortet wie ein Freund: kurz, mit deinen echten Zahlen, ehrlich über das, was er nicht weiß. Zwei Motoren (Apple Foundation Models auf dem Gerät, regelbasierter Rückfall), ein Gedächtnis, Antwort-Chips mit Handlung, Schnellfragen, Morgen-Check, Daumen und Merkliste. Kein Server, keine Diagnosen.

DEINE ORDNER (nur hier schreiben; alles andere ist tabu)
- LumenFit/Sources/Module/Coach/
- LumenFit/Tests/Module/Coach/
- LumenFit/Tests/Fixtures/Coach/

DU NUTZT AUS DEM GRUNDGERÜST (Namen stehen in SPEC 5.9)
- `AppUmgebung.daten.coach` (`CoachStore`: `verlauf`, `merkzettel`, `haenge`, `merke`, `vergiss`), `coachMotor` (du setzt ihn in `CoachModul.start`), `habits`, `training`, `ziele`, `gesundheit`, `router`, `ereignisse`
- Typen im Grundgerüst: `CoachMotor`, `CoachAnfrage`, `CoachAntwort`, `CoachKontext`, `CoachNachricht`, `CoachChip`, `CoachAktion`, `CoachRolle`, `LumiStimmung`, `Route`
- Design: `LumiView` (`denkt`), `ListenKarte`, `Pille`, `LeerZustand`, Eingabefeld, `Palette`
- Stubs, die du ersetzt: `CoachModul`, `CoachTabView(frage:)`

AUS LOVEA PORTIEREN (unter Lovea/Sources/Health/, wenn nicht anders angegeben; Modus K kopieren, A anpassen, N neu, - nicht)
- Coach/CoachLokal.swift [K] Tests: CoachLokalTests
- Coach/CoachMarker.swift (Marker für Gewohnheit und Plan; Kalender-, Wecker- und Erinnerungs-Marker entfallen) [A] Tests: CoachMarkerTests
- Coach/CoachRegeln.swift, CoachText.swift, CoachTage.swift, CoachTraining.swift, CoachGesundheit.swift, CoachVorschlaege.swift, CoachTracking.swift [A] Tests: CoachRegelnTests, CoachTextTests, CoachTageTests, CoachTrainingTests, CoachVorschlagTests, CoachTrackingTests
- Coach/CoachGedaechtnis.swift (-> `CoachStore.merkzettel`) [A] Tests: CoachGedaechtnisTests
- Coach/CoachHintergrund.swift (Serveranteile raus) [A] Tests: CoachHintergrundTests
- Coach/CoachChatView.swift, CoachVerlaufView.swift, CoachBlaetter.swift, CoachEinstellungenView.swift, CoachGedaechtnisAnsicht.swift, CoachAntwortTeile.swift (Views) [N]
- Coach/CoachModell.swift (nur Vorbild: Fluss, Entwurf, Fehler; `senden` und `CoachDaten.eingabe` werden `CoachMotor` und `CoachKontext`) [N]
- NICHT übernehmen: CoachWecker.swift, CoachKalender.swift, CoachKalenderKarte.swift, CoachKalenderSpeicher.swift (Wecker und Kalender sind nicht Fit); prüfe CoachWerkzeugTextTests und lass nur Teile ohne Wecker und Kalender mitlaufen [-]

NEU ZU BAUEN
- `RegelCoachMotor: CoachMotor` (immer verfügbar) auf den portierten Regeln und Bausteinen; `ModellCoachMotor: CoachMotor` mit `#if canImport(FoundationModels)`: `SystemLanguageModel.default.availability`, Deutsch mit `supportsLocale`, `LanguageModelSession` mit Persona als Anweisung, strukturierte Antwort (`@Generable`: Text plus Chips) und `Tool`s zum Nachladen (letztes Training, Rekorde, Schlaf, Essen). Typnamen vorher gegen `developer.apple.com/tutorials/data/documentation/foundationmodels/*.json` prüfen (`agent-skills:source-driven-development`); alle FoundationModels-Aufrufe in einer Datei, damit ein Fehler dort den Rest nicht verdeckt
- `CoachWahl.motor(...)`: Modell, wenn verfügbar und Deutsch, sonst Regeln; Wechsel mitten im Gespräch ohne Verlust
- `CoachPersona`: höchstens drei kurze Sätze plus höchstens eine Frage, "du", echte Zahlen statt Floskeln, kein "Als KI", keine Diagnosen, an schweren Tagen verständnisvoll, bei Beschwerden Hinweis auf Ärztin oder Arzt, bei fehlenden Daten nachfragen statt raten; `CoachAntwortPruefung` prüft jede Antwort gegen diese Regeln (Länge, Anrede, Verbotsliste) und fällt bei Verstoß auf den Regelmotor zurück
- Gedächtnis (Merkzettel anzeigen, löschen), Chips mit Handlung (`gewohnheitAnlegen` über `HabitStore`, `planMorgenLeicht` über `TrainingStore.planSichern`, `oeffne(Route)` über `router`), Schnellfragen nach Tageszeit, Morgen-Check (beim ersten Öffnen am Morgen eine Frage 1 bis 5, Antwort setzt Lumis Stimmung als Op `fit.lumi.stimmung` (Rumpf `StimmungsEintrag`, SPEC 5.3; das Modul heute liest sie), nie als Mitteilung), Daumen und Merkliste, Tippanzeige höchstens 15 s
- Demo-Saat `CoachModul.demoSaat` (ein kurzer Verlauf)

IDEEN, DIE DU EINBAUST (alle müssen am Ende drin sein)
61. **Coach auf dem Gerät** – Apples Sprachmodell antwortet auf Deutsch ohne Server; Gesundheitsdaten verlassen das iPhone nicht.
62. **Rückfall ohne Apple Intelligence** – gleiche Tipps aus Textbausteinen und Regeln, damit jedes Gerät einen brauchbaren Coach hat.
63. **Ton wie ein Freund** – kurze Sätze, eine Frage, echte Zahlen; an schweren Tagen verständnisvoll, nie belehrend; die Tonregeln sind Tests.
64. **Coach merkt sich Ziele** – Ziele, Verletzungen und Vorlieben liegen lokal, sichtbar und löschbar.
65. **Chips mit Handlung** – "Mach ich" legt eine Gewohnheit an, "Morgen leicht" ändert den Plan, "Zeig mir" springt zur Seite.
66. **Coach kennt dein Training** – bekommt letztes Training, Rekorde, Schlaf und Essen als Kontext, ohne dass du etwas kopierst.
67. **Morgen-Check** – eine Frage beim ersten Öffnen am Morgen (1 bis 5), die Antwort färbt Lumis Stimmung und den Plan-Vorschlag.
68. **Schnellfragen nach Tageszeit** – morgens "Wie fühle ich mich?", abends "Was esse ich noch?"; ein Tipp statt Tippen.
69. **Daumen und Merkliste** – Antworten bewerten und merken; der Coach lernt Länge und Ton.
70. **Ehrlich, was er nicht weiß** – fehlen Daten, fragt er nach; keine Diagnosen, bei Beschwerden der Hinweis auf Ärztin oder Arzt.

FIXTURES
Fixtures/Coach: eine `coach-kontext-beispiel.json` mit erfundenen Zahlen; keine Netz-Fixtures.

AKZEPTANZ
- Beide Motoren erfüllen `CoachMotor`; `CoachWahl` wählt ohne Apple Intelligence den Regelmotor; keine Anfrage verlässt das Gerät
- Ton-Tests grün: Länge, "du", keine Diagnose, kein "Als KI", fehlende Daten führen zu einer Rückfrage
- Chips lösen echte Handlungen aus (Test: Gewohnheit existiert danach, Plan ist leichter)
- Kein Wecker, keine Erinnerung, kein Kalender-Marker (Umfang-Gate); der Morgen-Check erscheint nur beim Öffnen
- Fehlerfall (Modell nicht bereit): Text "Gerade nicht erreichbar, ich merke mir deine Frage" mit Lumi, nie ein rohes Fehlerwort
- Gemeinsam: alle Ideen oben eingebaut oder mit Grund als nicht umsetzbar gemeldet; nur die eigenen Ordner geändert (`git diff --name-only main...modul/coach`); `swift-syntax-check` OK auf allen neuen Dateien; `bash scripts/check-schnell.sh` sauber (Namens-, Umfang- und Typnamen-Gate); alle Stub-Dateien des Moduls ersetzt ("Kommt bald" kommt nirgends mehr vor); keine Unterdrückungen; alle Texte Deutsch ohne Emojis; jede portierte Datei trägt oben `// Quelle: Lovea Health/<Pfad>`.

TESTS
- `CoachWahlTests`, `CoachPersonaTests` (Ton), `CoachAntwortPruefungTests`, `RegelCoachMotorTests` (gegen `CoachKontext`), `MorgenCheckTests`, `ChipAktionTests`
- Portierte Lovea-Tests laut Tabelle
- `ModellCoachMotor` nur als Compile-Beleg in CI; ein Gerätetest steht in der Testliste

ABSCHLUSSBERICHT
Kurz: geänderte Dateien, welche Idee wie umgesetzt ist, was nur Compiler oder Gerät beweist (ungeprüft), Wünsche ans Grundgerüst (du änderst es nie), Annahmen für SPEC Abschnitt 15.
