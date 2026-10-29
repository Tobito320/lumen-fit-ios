AUFTRAG: Modul „schlaf“ (Schlaf-Tab: Nacht, Phasen, Schuld, HRV im eigenen Bereich, Werte, Woche, Quellen) der iOS-App Lumen Fit.

KONTEXT
Lumen Fit: iOS-App (SwiftUI, Swift 6, iOS 26, iPhone) für Gesundheit und Fitness, client-only (kein Server, keine Konten), Standard-Design monochrom, Figur Lumi. Repo /home/tobi/projects/lumen-fit-ios, Zweig modul/schlaf im eigenen Worktree, Grundgerüst ist gemergt. Lies zuerst CLAUDE.md, CONSTRAINTS.md, CONTEXT.md, SPEC.md (Abschnitte 5.3, 5.8, 5.9, 6, 11) und docs/research/design.md. Kein Mac: lokal nur swift-syntax-check, Compiler und Tests laufen im Integrationsschritt in CI (starte kein CI). Test zuerst, kleinster korrekter Diff. Quelle für Fertiges ist /home/tobi/projects/lovea-app-ios/Lovea/Sources (nur lesen, Lovea nie ändern; Portierungsregeln SPEC 5.8). Vorlage für Konfiguration war Bahnherz.

ZIEL
Der Tab Schlaf zeigt die letzte Nacht als Heldenzahl, die Phasen, die Woche, die Schlafschuld, die HRV im eigenen 60-Tage-Bereich, die Werte-Chips und einen Satz in einfacher Sprache. Lumi schläft nachts. Ohne Daten gibt es einen Leerzustand mit Handlung.

DEINE ORDNER (nur hier schreiben; alles andere ist tabu)
- LumenFit/Sources/Module/Schlaf/
- LumenFit/Tests/Module/Schlaf/
- LumenFit/Tests/Fixtures/Schlaf/

DU NUTZT AUS DEM GRUNDGERÜST (Namen stehen in SPEC 5.9)
- `AppUmgebung.gesundheit` (`naechte`, `vitale`), `daten.ziele.ziele.schlafMinuten`, `daten.raum.ops(arten: ["fit.band.schlaf"])` (Band-Schlaf aus dem Modul verbinden), `router`, `uhr`
- Lovea-Typen im Grundgerüst: `SchlafNacht`, `SchlafAbschnitt`, `SchlafPhase`, `SchlafNachtLogik`, `VitalArt`, `VitalMesswert`, `Datum`
- Design: `LumiView` (`schlaeft`), `MusterFlaeche`, `ListenKarte`, `Pille`, `LeerZustand`, `LumenFarben.tief(.erholen, ...)`
- Stubs, die du ersetzt: `SchlafModul`, `SchlafTabView(bereich:)`, `SchlafVerlaufView`. Stub, den du einbettest: `PartnerKarte(bereich: .schlaf)`

AUS LOVEA PORTIEREN (unter Lovea/Sources/Health/, wenn nicht anders angegeben; Modus K kopieren, A anpassen, N neu, - nicht)
- SchlafNachtDiagramm.swift, SchlafCard.swift (Views) [N]
- SchlafVergleich.swift, SchlafVergleichKarte.swift [A] Tests: SchlafVergleichTests
- SchlafAutomatik.swift (Schlafziel lernen; reine Logik; Schlaf-Erkennung aus CoreMotion nur, wenn sie ohne Wecker und Signal-Kurzbefehle auskommt) [A] Tests: SchlafAutomatikTests
- SchlafErinnerung.swift: NUR die reinen Auswertungen (`SchlafLogik`, z. B. `gewohnheit`); `BettErinnerung.planen` und alles mit Erinnerung entfällt [A] Tests: SchlafLogikTests
- NICHT übernehmen: SchlafPunkte.swift, SchlafSignale.swift, SchlafSignalIntent.swift (Punktesystem aus Kurzbefehl-Signalen), Wecker/* [-]

NEU ZU BAUEN
- `SchlafSchuld` (7 Nächte gegen Ziel, nur fehlende Minuten zählen, Vorschlag "heute 45 Minuten früher"), `Regelmaessigkeit` (Streuung der Einschlafzeit als ruhiger Score), `WochenVergleich` (diese gegen letzte Woche, Wochenende gegen Werktag)
- `PersoenlicherBereich`: 60-Tage-Bereich eines Vitalwerts (Mittelwert und Streuung, mindestens 14 Werte, sonst "zu wenig Daten"), Punkt nach Lage, Satz dazu; `ErholungsKlartext` ("Deine HRV liegt 12 Prozent über deinem Schnitt, du bist bereit") rein regelbasiert
- `SchlafQuellenWahl`: Uhr, Handy oder Band; doppelte Nächte zusammenführen, genaueste Quelle gewinnt; Band-Nächte kommen aus Ops `fit.band.schlaf` (Rumpf `tag`, `start`, `ende`, `phasen`)
- Oberfläche: Heldenkarte mit Zeit und Ziel, `PhasenBalken` (Muster plus Beschriftung), Wochenbalken, Werte-Chips mit Trendpfeil (Symbol plus Zahl), Schlaf-Verlauf; Demo-Saat `SchlafModul.demoSaat`

IDEEN, DIE DU EINBAUST (alle müssen am Ende drin sein)
51. **Letzte Nacht groß** – Schlafzeit als Heldenzahl mit von bis und Ziel; Lumi schläft nachts.
52. **Phasen-Balken** – Tief, Kern, REM und Wach mit Muster und Beschriftung, nie nur Farbe.
53. **Schlafschuld über 7 Nächte** – gegen dein Ziel gerechnet, mit Vorschlag "heute 45 Minuten früher".
54. **HRV im eigenen Bereich** – 60-Tage-Bereich statt fremder Norm; Punkt nach Lage und ein Satz dazu.
55. **Werte-Chips** – Ruhepuls, SpO2, Atmung, Temperatur und VO2max mit Trendpfeil gegen deinen Schnitt.
56. **Wochenübersicht Schlaf** – sieben Balken, Schnitt und Nächte unter 6 Stunden.
57. **Regelmäßigkeit** – wie stark die Einschlafzeit streut, als ruhiger Score statt Vorwurf.
58. **Erholung in einfacher Sprache** – "Deine HRV liegt 12 Prozent über deinem Schnitt, du bist bereit", aus Regeln, auf Wunsch vom Coach erklärt.
59. **Wochen im Vergleich** – diese gegen letzte Woche, Wochenende gegen Werktag.
60. **Beste Schlafquelle** – Uhr, Handy oder Band; doppelte Nächte werden zusammengeführt, die genaueste Quelle gewinnt.

FIXTURES
Fixtures/Schlaf: keine nötig; Tests erfinden Nächte (die Phasen-Form kommt aus `SchlafNachtTests`).

AKZEPTANZ
- Jeder Wert hat Symbol, Zahl und Text, nie nur Farbe; Diagramme haben Descriptor und Kernzeile
- Zu wenig Daten für den 60-Tage-Bereich: der Text sagt es, es wird nichts erfunden
- Doppelte Nächte (Uhr und Handy) erscheinen einmal; die gewählte Quelle steht im Detail
- Kein Wecker, keine Bettzeit-Erinnerung, kein Kurzbefehl-Signal (Umfang-Gate)
- Lumi schläft nur nachts (22 bis 5 Uhr) und im Schlaf-Tab; Reduce Motion: statisch
- Gemeinsam: alle Ideen oben eingebaut oder mit Grund als nicht umsetzbar gemeldet; nur die eigenen Ordner geändert (`git diff --name-only main...modul/schlaf`); `swift-syntax-check` OK auf allen neuen Dateien; Namens-Gate und Umfang-Gate (CONSTRAINTS) leer; alle Stub-Dateien des Moduls ersetzt ("Kommt bald" kommt nirgends mehr vor); keine Unterdrückungen; alle Texte Deutsch ohne Emojis; jede portierte Datei trägt oben `// Quelle: Lovea Health/<Pfad>`.

TESTS
- `SchlafSchuldTests`, `RegelmaessigkeitTests`, `PersoenlicherBereichTests`, `ErholungsKlartextTests`, `SchlafQuellenWahlTests`, `WochenVergleichTests`
- Portierte Lovea-Tests laut Tabelle
- Zeitlogik über Mitternacht und Sommerzeit

ABSCHLUSSBERICHT
Kurz: geänderte Dateien, welche Idee wie umgesetzt ist, was nur Compiler oder Gerät beweist (ungeprüft), Wünsche ans Grundgerüst (du änderst es nie), Annahmen für SPEC Abschnitt 15.
