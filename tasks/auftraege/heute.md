AUFTRAG: Modul „heute“ (Heute-Tab: Ringplatte, Bereit-Score, Plan, Energie, Gewohnheiten, Gewicht, Schritte, Hinweise) der iOS-App Lumen Fit.
Maßgeblich ist `tasks/auftraege/heute.md` im eigenen Worktree; weicht dieser Text von der Datei ab, gilt die Datei.

KONTEXT
Lumen Fit: iOS-App (SwiftUI, Swift 6, iOS 26, iPhone) für Gesundheit und Fitness, client-only (kein Server, keine Konten), Standard-Design monochrom, Figur Lumi. Repo /home/tobi/projects/lumen-fit-ios, Zweig modul/heute im eigenen Worktree, Grundgerüst ist gemergt. Lies zuerst CLAUDE.md, CONSTRAINTS.md, CONTEXT.md, SPEC.md (Abschnitte 5.3, 5.5, 5.8, 5.9, 6, 10 mit den Fallen, 11) und docs/research/design.md. Kein Mac: lokal nur swift-syntax-check, Compiler und Tests laufen im Integrationsschritt in CI (starte kein CI). Test zuerst, kleinster korrekter Diff. Quelle für Fertiges ist /home/tobi/projects/lovea-app-ios/Lovea/Sources (nur lesen, Lovea nie ändern; Portierungsregeln SPEC 5.8). Vorlage für Konfiguration war Bahnherz.

ZIEL
Der Tab Heute ist der ruhige Einstieg: die Ringplatte mit den drei Lumen-Bögen als eine mutige Sache, darunter Bereit-Score, Lumis Satz, Plan-Karte, Energie-Bank, Gewohnheiten, Gewicht, Schritte, Hinweise und der Wochenstreifen. Die Partner-Karte betten nur Verbinden ein (Stub `PartnerKarte(bereich: .heute)`, leer ohne Verbindung).

DEINE ORDNER (nur hier schreiben; alles andere ist tabu)
- LumenFit/Sources/Module/Heute/
- LumenFit/Tests/Module/Heute/
- LumenFit/Tests/Fixtures/Heute/

DU NUTZT AUS DEM GRUNDGERÜST (Namen stehen in SPEC 5.9)
- `AppUmgebung.daten` (`training`, `habits`, `essen`, `ziele`, `meilensteine`), `AppUmgebung.gesundheit` (`GesundheitsStand`: `tage`, `naechte`, `vitale`, `gewichte`), `router`, `ereignisse`, `uhr`, `daten.raum` (liest die Op `fit.lumi.stimmung`, Rumpf `StimmungsEintrag`)
- Design aus dem Grundgerüst: `LumenBogen`, `BogenWert`, `LumenBalken`, `LumiView`, `MusterFlaeche`, `HeroKarte`, `ListenKarte`, `Pille`, `LeerZustand`, `AvatarKapsel`, `Palette`, `Feder`, `HaptikZentrale`, `RollZahl`, `DiagrammKarte`; `LumiView(stimmung:groesse:stufe:)` mit `daten.meilensteine.stufe`
- Lovea-Typen im Grundgerüst: `Habit`, `HabitLogik`, `TrainingsPlan`, `TrainingsTag`, `TrainingLogik`, `SchlafNacht`, `Datum`
- Stubs, die du ersetzt: `HeuteModul`, `HeuteTabView`, `GewichtEintragenView`. Stub, den du einbettest: `PartnerKarte(bereich: .heute)`

AUS LOVEA PORTIEREN (unter Lovea/Sources/Health/, wenn nicht anders angegeben; Modus K kopieren, A anpassen, N neu, - nicht)
- Heute/Tagesform/TagesformRechnung.swift, TagesformQuellen.swift, TagesformKlartext.swift, TagesformGefuehl.swift, TagesformVitalwerte.swift (Daten kommen aus `GesundheitsStand` statt `HealthModell`) [A] Tests: TagesformRechnungTests, TagesformQuellenTests, TagesformKlartextTests, TagesformGefuehlTests (mit TagesformBeispiele.swift als Testdaten)
- Heute/Hinweise.swift, Heute/TagesFormen.swift [A] Tests: HinweiseTests, HeuteVorTests (nur den Teil, der Logik prüft)
- Energie.swift (Logik) [A] Tests: EnergieLogikTests
- SchritteLogik.swift, SchritteDetail.swift (nur Daten und Logik) [A] Tests: SchritteLogikTests
- Heute/GewichtBlatt.swift, HabitsSektion.swift, HabitDetail.swift, HabitFormular.swift, HeuteView.swift, EnergieKarte.swift, SchritteRinge.swift, SchritteAnsichten.swift [N (nur Inhaltsvorbild; Oberfläche im Lumen-Design)]
- NICHT übernehmen: Heute/FreitextKI.swift, FreitextLogik.swift, SchreibZeile.swift (Server-KI), HealthMenu.swift, HealthTab.swift, WiegeErinnerung.swift, Punkte*, Challenge*, Dank*, Besitz* [-]

NEU ZU BAUEN
- `BereitScore`: eigene, offen erklärte Formel (Idee 12) aus Schlaf-Dauer gegen Ziel, HRV im eigenen 60-Tage-Bereich, Ruhepuls gegen Schnitt, Belastung der letzten 3 Tage; Ergebnis 0 bis 100 plus Satz; fehlt ein Wert, wird er ausgelassen und der Satz sagt es
- `HeuteModell` (`@MainActor @Observable`): baut Bögen (Schritte gegen Ziel, Gym-Tage der Woche gegen Ziel, Schlafzeit gegen Ziel), Lumis Stimmung und Morgensatz, lädt `GesundheitsStand.aktualisiere()` beim Erscheinen und bei `Ereignis.vordergrund`; liest die heutige Op `fit.lumi.stimmung` (Morgen-Check des Moduls coach, Idee 67): Wert 1 oder 2 zeigt Lumi `muede` und lässt die Plan-Karte "heute locker" vorschlagen, Wert 4 oder 5 hebt den Bereit-Satz
- `Ringplatte` (schwarz, Streifenmuster, `LumenBogen` mit Lumi in der Mitte), `ScoreKarte`, `PlanKarte` (Knopf ruft `trainingSteuerung.starte`), `EnergieBank`, `WochenStreifen`, `HinweiseKarte` (höchstens drei, wegwischbar)
- Gewohnheiten-Karte mit Haken, Zähler und Serie über `HabitStore`; `GewichtEintragenView` (Zahlenrad, schreibt optional nach Health über `healthSchreiber`, wenn `einstellungen.werte.healthSchreiben`); Schritte-Detail (Tag, Woche, Monat)
- Leerzustand ohne Health: Lumi, ein Satz, Knopf "Health erlauben"; Demo-Saat `HeuteModul.demoSaat`

IDEEN, DIE DU EINBAUST (alle müssen am Ende drin sein)
11. **Ringplatte mit Lumen-Bögen** – Schritte, Gym und Schlaf auf einer schwarzen Platte mit Streifen; die Bögen füllen sich beim Öffnen, Lumi sitzt in der Mitte.
12. **Bereit-Score** – Erholung, Belastung und Schlaf als drei kleine Bögen mit einem Satz dazu; eigene, offen erklärte Formel aus Health-Werten.
13. **Lumis Morgensatz** – ein Satz aus echten Zahlen ("Gut erholt. Heute Beine?"), Lumis Stimmung folgt dem Score.
14. **Plan-Karte mit einem Tipp** – der heutige Trainingstag aus dem Split, ein Knopf startet das Training.
15. **Energie-Bank** – ein Wert von 0 bis 100 für den Akku des Körpers aus Schlaf, Erholung und Belastung, mit Verlauf über den Tag.
16. **Gewohnheiten mit Serie** – Haken per Tipp, Zähl-Gewohnheiten wie Wasser, Serie in Tagen oder Wochen, Verwaltung in einer Zeile.
17. **Gewicht in drei Sekunden** – Blatt mit Zahlenrad, Verlauf mit Ziellinie, auf Wunsch zurück nach Health geschrieben.
18. **Schritte im Detail** – Tag, Woche, Monat, Distanz, Etagen, beste Tage und die Zielmarke.
19. **Hinweise des Tages** – höchstens drei kleine, wegwischbare Karten aus Regeln ("Zweimal unter 6 Stunden: heute locker").
20. **Wochenstreifen** – Montag bis Sonntag mit kleinen Bögen je Tag; ein Tipp öffnet den Tag.

FIXTURES
Keine eigenen Dateien nötig. Test-Daten erfindest du im Test.

AKZEPTANZ
- Heute zeigt mit Demo-Daten alle Karten; ohne Health einen Leerzustand mit Handlung; ohne Verbindung nichts vom Partner
- `BereitScore` hat Tests für volle, teilweise und leere Daten; die Formel steht als Kommentar mit Begründung (nur das Warum) und als Klartext im Detail
- Genau ein Heldenelement (Ringplatte); Hinweise höchstens drei; Zahlen rollen nur beim ersten Anzeigen; Reduce Motion schaltet Bewegung ab
- Nur mit iPhone (keine HRV, kein Ruhepuls, keine Phasen) rechnet `BereitScore` mit Schlaf und Belastung und der Satz nennt, was fehlt; Schritte kommen als Maximum aus Health und Band aus `GesundheitsStand.tage`
- Bögen haben `accessibilityValue` ("Schritte: 8.412 von 10.000"); Lumi-Stimmung steht als Text daneben
- Gemeinsam: alle Ideen oben eingebaut oder mit Grund als nicht umsetzbar gemeldet; nur die eigenen Ordner geändert (`git diff --name-only main...modul/heute`); `swift-syntax-check` OK auf allen neuen Dateien; `bash scripts/check-schnell.sh` sauber (Namens-, Umfang- und Typnamen-Gate); alle Stub-Dateien des Moduls ersetzt ("Kommt bald" kommt nirgends mehr vor); keine Unterdrückungen; alle Texte Deutsch ohne Emojis; jede portierte Datei trägt oben `// Quelle: Lovea Health/<Pfad>`.

TESTS
- `BereitScoreTests`, `MorgensatzTests`, `WochenStreifenTests`, `HeuteModellTests` (mit `FakeHealthLeser` und Temp-Raum)
- Portierte Lovea-Tests laut Tabelle
- Zeitlogik um Mitternacht und Sommerzeit

ABSCHLUSSBERICHT
Kurz: geänderte Dateien, welche Idee wie umgesetzt ist, was nur Compiler oder Gerät beweist (ungeprüft), Wünsche ans Grundgerüst (du änderst es nie), Annahmen für SPEC Abschnitt 15.
