AUFTRAG: Modul „fortschritt“ (Fortschritt: Kraftkurve, Körperkarte, Raster, Gewicht, Meilensteine, Lumi-Seite, Rückblicke) der iOS-App Lumen Fit.
Maßgeblich ist `tasks/auftraege/fortschritt.md` im eigenen Worktree; weicht dieser Text von der Datei ab, gilt die Datei.

KONTEXT
Lumen Fit: iOS-App (SwiftUI, Swift 6, iOS 26, iPhone) für Gesundheit und Fitness, client-only (kein Server, keine Konten), Standard-Design monochrom, Figur Lumi. Repo /home/tobi/projects/lumen-fit-ios, Zweig modul/fortschritt im eigenen Worktree, Grundgerüst ist gemergt. Lies zuerst CLAUDE.md, CONSTRAINTS.md, CONTEXT.md, SPEC.md (Abschnitte 5.3, 5.5, 5.8, 5.9, 6, 10 mit den Fallen, 11) und docs/research/design.md. Kein Mac: lokal nur swift-syntax-check, Compiler und Tests laufen im Integrationsschritt in CI (starte kein CI). Test zuerst, kleinster korrekter Diff. Quelle für Fertiges ist /home/tobi/projects/lovea-app-ios/Lovea/Sources (nur lesen, Lovea nie ändern; Portierungsregeln SPEC 5.8). Vorlage für Konfiguration war Bahnherz.

ZIEL
Das Segment "Fortschritt" im Gym-Tab und die Seiten Verlauf, Lumi, Meilensteine und Rückblick zeigen, dass es vorangeht: Kurven, Raster, Erholungs-Silhouette, Medaillen und Lumis Stufen. Jede Seite hat eine Aussage als Titel und ist auch ohne Farbe lesbar.

DEINE ORDNER (nur hier schreiben; alles andere ist tabu)
- LumenFit/Sources/Module/Fortschritt/
- LumenFit/Tests/Module/Fortschritt/
- LumenFit/Tests/Fixtures/Fortschritt/

DU NUTZT AUS DEM GRUNDGERÜST (Namen stehen in SPEC 5.9)
- `AppUmgebung.daten` (`training.sessions`, `essen` Körperwerte, `habits`, `meilensteine`: `MeilensteinStore.markiere/erreicht/stufe`), `gesundheit.gewichte`, `ereignisse` (hören auf `trainingBeendet`, `satzFertig`, `gewichtGespeichert`, `habitGeaendert`), `router`
- Lovea-Typen im Grundgerüst: `MuskelGruppe`, `MuskelTeil`, `MuskelLogik`, `ErholungsStufe`, `GymSession`, `UebungsLauf`, `PlanSatz`, `Datum`
- Design: `LumiView`, `MusterFlaeche`, `ListenKarte`, `Pille`, `LeerZustand`, `Palette`, `LumenFarben.tief`, `DiagrammKarte` (Aussage als Titel, Kernzeile), `LumiStufe` (Grundgerüst, `schwellen` und `stufe(erreicht:)`)
- Stubs, die du ersetzt: `FortschrittModul`, `FortschrittSegmentView`, `VerlaufView`, `LumiSeiteView`, `MeilensteineView`, `RueckblickView`

AUS LOVEA PORTIEREN (unter Lovea/Sources/Health/, wenn nicht anders angegeben; Modus K kopieren, A anpassen, N neu, - nicht)
- Koerper/ErholungsLogik.swift [A] Tests: ErholungsKarteTests
- Koerper/Messungen.swift (MessArt, MessPunkt, MessLogik; Views N) [A] Tests: GewichtLogikTests, soweit nicht im Grundgerüst
- Koerper/KoerperKarte.swift, KoerperBlatt.swift, KoerperView.swift, MuskelKarte.swift, MuskelSeite.swift [N (Silhouette neu aus SwiftUI-Formen; `muskelkarte.json` NICHT verwenden, AGPL)]
- Verlauf/KonsistenzLogik.swift, KonsistenzKategorien.swift [A] Tests: KonsistenzLogikTests, KonsistenzKategorienTests
- Verlauf/VerlaufWocheLogik.swift [A] Tests: VerlaufOhneSaetzeTests, VerlaufRuhigTests
- Verlauf/KonsistenzKarte.swift, KonsistenzKategorienBlatt.swift, VerlaufView.swift, VerlaufWocheAnsichten.swift [N]
- NICHT übernehmen: Punkte*, Challenge*, Besitz*, Dank*, Koerper/ZieleBefragung.swift (gehört dem Modul profil) [-]

NEU ZU BAUEN
- `KraftKurve` (bestes Gewicht, 1RM nach Epley, Volumen je Übung und Woche) und `SaetzeProMuskel` (Woche gegen Zielzahl, Aufwärmsätze zählen nicht) mit Swift Charts, `accessibilityChartDescriptor` und Kernzeile
- `Silhouette` aus SwiftUI-Formen (vorne/hinten, 12 Muskelgruppen) mit Erholungs-Prozent je Gruppe aus `ErholungsLogik`; Muster plus Liste daneben, nie nur Farbe
- `NaechstesTraining`: aus Erholung je Muskel, heutigem Plantag und verfügbarer Zeit ein Vorschlag mit Begründung ("Heute Beine, 45 Minuten")
- Konstanz-Raster (18 x 7, vier Stufen mit Muster), Gewichtsverlauf (gleitender Mittelwert, Ziellinie, Prognose in Wochen, nur wenn der Trend zum Ziel zeigt)
- `MeilensteinKatalog` (25 Medaillen als Daten: Id, Titel, Bedingung, Symbol) und `MeilensteinPruefung` (hört auf `Ereignis`se, schreibt über `meilensteine.markiere`, sendet `meilensteinErreicht`; ein neuer Meilenstein zeigt einmal den Toast `.lumenToast(_:)` mit Lumi `stolz` und Haptik `.erfolg`, eine neue Lumi-Stufe `.stufe`), Serie in Wochen, `LumiSeiteView` mit Pfad und nächstem Ziel (die Stufe 1 bis 9 rechnet `LumiStufe` im Grundgerüst, du zeigst sie und die Schwellen)
- `Rueckblick` Woche und Monat als Karte, per `ImageRenderer` als Bild teilbar; `FitPassport` Langzeitkarte ohne Namen Dritter; Demo-Saat `FortschrittModul.demoSaat`

IDEEN, DIE DU EINBAUST (alle müssen am Ende drin sein)
31. **Kraftkurve je Übung** – Linie mit Fläche und Endpunkt für bestes Gewicht, geschätztes 1RM und Volumen; der Titel nennt die Aussage ("Bankdrücken: 70 kg, plus 10").
32. **Sätze je Muskel gegen Ziel** – Wochenbalken je Muskelgruppe mit Zielzahl und Wert rechts.
33. **Erholungs-Silhouette** – selbst gezeichnete Körperkarte zeigt je Muskel die Erholung in Prozent, die Liste daneben sagt es in Worten.
34. **Vorschlag fürs nächste Training** – frischeste Muskeln plus verfügbare Zeit ergeben "Heute Beine, 45 Minuten" samt Begründung.
35. **Konstanz-Raster** – 18 Wochen mal 7 Tage in vier Stufen, auch ohne Farbe lesbar.
36. **Gewichtsverlauf mit Trend** – gleitender Mittelwert, Ziellinie und Prognose "in 9 Wochen am Ziel".
37. **Meilensteine und Medaillen** – 25 Medaillen (erste Woche, 10/50/100 Gym-Tage, Volumen, Schlafserie), schwarz mit Rand; gesperrte stehen grau mit Text.
38. **Lumi-Stufen 1 bis 9** – Lumi wächst mit den Meilensteinen; Pfad, Wochenserie und nächstes Ziel mit Balken.
39. **Wochen- und Monatsrückblick** – Sonntagskarte mit Gym-Tagen, Volumen, Schlafschnitt und dem besten Moment; als Bild teilbar.
40. **FitPassport** – eine teilbare Karte mit Langzeitwerten (Kraft, Schlaf, Konstanz), ohne Namen Dritter.

FIXTURES
Fixtures/Fortschritt: keine nötig; Tests erfinden Trainings.

AKZEPTANZ
- Jedes Diagramm hat eine Aussage als Titel, Descriptor und Kernzeile; Konstanz-Raster ist ohne Farbe lesbar (Muster oder Stufenzahl)
- Die Silhouette nutzt keine Daten aus `muskelkarte.json`; jede Muskelgruppe hat Text mit Prozent
- Meilensteine werden nie doppelt vergeben und überleben einen Neustart (Op `fit.lumi.meilenstein`); gesperrte Medaillen zeigen Text
- Leerzustände mit Lumi, einem Satz und einer Handlung (z. B. "Noch kein Training. Tipp auf Starten, Lumi zählt mit.")
- Gemeinsam: alle Ideen oben eingebaut oder mit Grund als nicht umsetzbar gemeldet; nur die eigenen Ordner geändert (`git diff --name-only main...modul/fortschritt`); `swift-syntax-check` OK auf allen neuen Dateien; `bash scripts/check-schnell.sh` sauber (Namens-, Umfang- und Typnamen-Gate); alle Stub-Dateien des Moduls ersetzt ("Kommt bald" kommt nirgends mehr vor); keine Unterdrückungen; alle Texte Deutsch ohne Emojis; jede portierte Datei trägt oben `// Quelle: Lovea Health/<Pfad>`.

TESTS
- `KraftKurveTests`, `SaetzeProMuskelTests`, `NaechstesTrainingTests`, `MeilensteinPruefungTests`, `LumiPfadTests` (Pfad und nächstes Ziel aus `LumiStufe.schwellen`; `LumiStufeTests` gehört dem Grundgerüst), `RueckblickTests`
- Portierte Lovea-Tests laut Tabelle

ABSCHLUSSBERICHT
Kurz: geänderte Dateien, welche Idee wie umgesetzt ist, was nur Compiler oder Gerät beweist (ungeprüft), Wünsche ans Grundgerüst (du änderst es nie), Annahmen für SPEC Abschnitt 15.
