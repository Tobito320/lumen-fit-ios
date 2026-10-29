AUFTRAG: Modul „verbinden“ (Verbinden: Lovea-Brücke, Partner-Karte, Mitteilungen, Band, Freundeskarten) der iOS-App Lumen Fit.
Maßgeblich ist `tasks/auftraege/verbinden.md` im eigenen Worktree; weicht dieser Text von der Datei ab, gilt die Datei.

KONTEXT
Lumen Fit: iOS-App (SwiftUI, Swift 6, iOS 26, iPhone) für Gesundheit und Fitness, client-only (kein Server, keine Konten), Standard-Design monochrom, Figur Lumi. Repo /home/tobi/projects/lumen-fit-ios, Zweig modul/verbinden im eigenen Worktree, Grundgerüst ist gemergt. Lies zuerst CLAUDE.md, CONSTRAINTS.md, CONTEXT.md, SPEC.md (Abschnitte 5.3, 5.5, 5.8, 5.9, 6, 10 mit den Fallen, 11) und docs/research/design.md. Kein Mac: lokal nur swift-syntax-check, Compiler und Tests laufen im Integrationsschritt in CI (starte kein CI). Test zuerst, kleinster korrekter Diff. Quelle für Fertiges ist /home/tobi/projects/lovea-app-ios/Lovea/Sources (nur lesen, Lovea nie ändern; Portierungsregeln SPEC 5.8). Vorlage für Konfiguration war Bahnherz.

ZIEL
Lumen Fit verbindet sich mit Lovea über den Dateivertrag (SPEC 5.5), teilt das Band (SPEC 5.6, Standard aus) und tauscht Wochenkarten mit Freunden ohne Server. Nicht verbunden: nichts davon ist sichtbar.

DEINE ORDNER (nur hier schreiben; alles andere ist tabu)
- LumenFit/Sources/Module/Verbinden/
- LumenFit/Tests/Module/Verbinden/
- LumenFit/Tests/Fixtures/Verbinden/

DU NUTZT AUS DEM GRUNDGERÜST (Namen stehen in SPEC 5.9)
- `AppUmgebung.bruecke` (`PartnerAustausch`; Umsetzung `LoveaBruecke(ordner:)` aus dem Grundgerüst), `daten.verbindung` (`VerbindungStore`: `partner`, `freigaben`, `freunde`, `verbunden`, `aktualisiere`), `band` (`BandDienst`; du setzt es in `VerbindenModul.start`), `mitteiler`, `daten.einstellungen` (`loveaVerbunden`, `bandAktiv`, `mitteilungen`), `daten.training`, `gesundheit`, `daten.essen`, `daten.raum` (Band-Schlaf als Op `fit.band.schlaf`), `ereignisse` (`Ereignis.vordergrund`, `.healthAktualisiert`), `AppUmgebung.beiAbruf`
- Typen im Grundgerüst: `ZusammenfassungDatei`, `TagesZusammenfassung`, `PartnerEreignis`, `PartnerEreignisArt`, `PartnerStand`, `FreigabeArt`, `PartnerBereich`, `BandWunsch`, `BandMuster`, `BandStatus`, `BandStatusDatei`, `FreundKarte`
- Stubs, die du ersetzt: `VerbindenModul`, `VerbindungenView`, `PartnerKarte(bereich:)`, `FreundeView`

AUS LOVEA PORTIEREN (unter Lovea/Sources/Health/, wenn nicht anders angegeben; Modus K kopieren, A anpassen, N neu, - nicht)
- Tracker/TrackerProtokoll.swift, TrackerFunk.swift (CoreBluetooth, Wiederherstellung; `@unchecked Sendable` nur mit einzeiligem Grund), TrackerModell.swift [A] Tests: TrackerProtokollTests, TrackerModusTests
- Tracker/BandPuls.swift, BandNachrichtVibration.swift, BandRegeln.swift, BandLabor.swift, BandRegelnBlatt.swift, BandLaborAnsicht.swift [A] Tests: BandNachrichtVibrationTests, BandRegelnTests, BandLaborTests
- Tracker/TrackerSchlaf.swift (schreibt Op `fit.band.schlaf`, Rumpf `BandSchlafOp`), TrackerTage.swift (schreibt Op `fit.band.tag`, Rumpf `BandTagOp`; `GesundheitsStand` nimmt das Maximum aus Health und Band; `UserDefaults` für Tage und Nächte entfällt), TrackerEnergie.swift [A] Tests: TrackerSchlafTests, TrackerTageTests, TrackerEnergieTests
- Tracker/TrackerAkkuLog.swift, TrackerAkkuWarnung.swift, TrackerVerlauf.swift, TrackerVerlaufKarten.swift, TrackerSeite.swift, TrackerEinstellungen.swift, TrackerMeldung.swift [A (Views N)] Tests: TrackerAkkuLogTests, TrackerAkkuWarnungTests, TrackerVerlaufTests
- NICHT übernehmen: alles zu Wecker, Alarm und Erinnerung (prüfe TrackerArm.swift, TrackerModus.swift auf Wecker-Anteile; TrackerArmTests nur ohne Wecker) [-]

NEU ZU BAUEN
- `LoveaBrueckeDienst`: baut `zusammenfassung.json` aus den Stores und nur den freigegebenen Datenarten (Standard keine), schreibt sie bei Ereignissen und bei `Ereignis.vordergrund`, sendet die Darwin-Benachrichtigung; `VerbindenModul.start` meldet außerdem eine `AppUmgebung.beiAbruf`-Aufgabe an, die auch bei `Ereignis.healthAktualisiert` (Health-Hintergrundlieferung weckt die App) und im BGTask läuft: `VerbindungStore.aktualisiere`, `PartnerEreignisRegeln`, `mitteiler`, `zusammenfassung.json` schreiben; sie liest nur Dateien, nie Health, damit sie auch bei gesperrtem Gerät geht (SPEC 5.5); `VerbindungStore.aktualisiere` fragt `bruecke.partner(jetzt:)`: `LoveaBruecke` (Grundgerüst) liest Quelle A (Loveas `widget-stand.json`) und Vertrag B (`partner.json`), verbunden = Schalter an, eine der beiden Quellen höchstens 48 h alt (SPEC 5.5); du schreibst die Regeln darüber, nicht den Leser
- `PartnerEreignisRegeln`: neues Ereignis (Gym gestartet, beendet, Ziel, Rekord, Schlaf gut) wird eine lokale Mitteilung über `mitteiler`, je Art abschaltbar, nie doppelt (Ereignis-Id merken); `PartnerKarte(bereich:)` zeigt nur freigegebene Zusammenfassungen und ist leer (kein Platzhalter), wenn nicht verbunden; Freigaben-Seite mit Vorschau "das sieht dein Partner"
- `BandDienstImpl: BandDienst`: ohne `bandAktiv` kein `CBCentralManager`; mit Schalter Verbinden, Status, Akku (Warnung unter 15 Prozent), `vibriere(_:)`; `BandWunschSchlange` führt Wünsche aus `band-wuensche.json` aus, meldet `band-erledigt.json` und `band-status.json`; Pausen-Ende-Muster einstellbar
- `FreundeKarte` erzeugen und lesen (Bild per `ImageRenderer`, Link `lumenfit://freund?d=...` mit Prüfsumme (HMAC mit festem Schlüssel: schützt vor Beschädigung und Tippfehlern, beweist nicht die Herkunft, Annahme), QR per CoreImage; das Bild trägt den QR; geöffnet über `Route.freund(daten:)` und `FreundeView(daten:)`), Import als `FreundKarte`, Wochen-Rangliste mit "Respekt"
- Demo-Saat `VerbindenModul.demoSaat` (nur mit Fixture-Datei "verbunden", sonst nichts sichtbar)

IDEEN, DIE DU EINBAUST (alle müssen am Ende drin sein)
81. **Mit Lovea verbinden** – ein Schalter; verbunden heißt, die gemeinsame Gruppe hat eine frische Partner-Datei; ohne Verbindung läuft alles wie gewohnt.
82. **Partner-Karte** – Heute und Schlaf zeigen, was die verbundene Person freigibt, sonst gar nichts, nicht einmal einen Platzhalter.
83. **Mitteilungen bei Partner-Ereignissen** – "Partner ist im Gym" oder "Ziel erreicht" als lokale Mitteilung, je Art abschaltbar.
84. **Freigaben je Datenart** – Schritte, Gym, Schlaf und Essen einzeln teilen, Standard aus, mit Vorschau, was der andere sieht.
85. **Band verbinden** – CoreBluetooth mit Schritten, Puls und Akku; Standard aus, solange Lovea das Band noch selbst hält.
86. **Band geteilt** – Vibrationswünsche von Lovea landen in einer Warteschlange der gemeinsamen Gruppe, Lumen Fit führt sie am Band aus.
87. **Pause am Handgelenk** – das Pausen-Ende vibriert am Band, Muster einstellbar.
88. **Band-Akku im Blick** – Prozent, Verbindung, Warnung unter 15 Prozent und Verlauf der letzten Tage.
89. **Freundeskarte** – Wochenzusammenfassung als Bild, Link oder QR teilen; der Empfänger sieht sie als Karte, ganz ohne Server.
90. **Wochen-Rangliste mit Respekt** – aus importierten Freundeskarten, Schritte und Gym-Tage; "Respekt" statt Like.

FIXTURES
Fixtures/Verbinden schreibst du selbst: `zusammenfassung-beispiel.json`, `partner-beispiel.json`, `partner-veraltet.json`, `partner-version-2.json`, `band-wuensche-beispiel.json`, `lovea-widget-stand-beispiel.json` (Form von Loveas `widget-stand.json` mit erfundenen Kennungen; der Leser selbst und seine Grundfälle liegen im Grundgerüst, du testest die Regeln darüber) (erfundene Namen wie "Beispiel Partner").

AKZEPTANZ
- Nicht verbunden (keine Datei, Schalter aus, veraltete Datei, falsche Version): keine Oberfläche zeigt etwas vom Partner und es gibt keine Fehlermeldung (Tests je Fall)
- Verbunden: Partner-Karte, Mitteilung genau einmal je Ereignis, Freigaben begrenzen den Inhalt von `zusammenfassung.json` (Test: ohne Freigabe fehlen die Felder)
- Band: ohne `bandAktiv` entsteht kein Bluetooth-Objekt (Test mit Fake-Fabrik); Wünsche werden einmal ausgeführt und als erledigt gemeldet
- Freundeskarte: Roundtrip erzeugen/lesen, manipulierte Nutzlast wird abgelehnt; keine Namen Dritter im Quelltext
- Keine Datei außerhalb des Vertrags wird in der Lovea-Gruppe angelegt; Lovea selbst bleibt unberührt; Loveas `widget-stand.json` wird nur gelesen (Quelle A), nie geschrieben
- Mit der Fixture `lovea-widget-stand-beispiel.json` (erfundene Kennungen) zeigt die Partner-Karte Schritte, Gym und Schlaf der anderen Kennung und kein Ort, Wetter oder Akku; die Mitteilung "Partner war im Gym" erscheint genau einmal je Tag
- Band-Verbindung im zweiten Prozess: erst `retrieveConnectedPeripherals(withServices:)`, dann `retrievePeripherals(withIdentifiers:)`, zuletzt Scan (Test mit `FakeZentrale`: Reihenfolge der Aufrufe)
- Gemeinsam: alle Ideen oben eingebaut oder mit Grund als nicht umsetzbar gemeldet; nur die eigenen Ordner geändert (`git diff --name-only main...modul/verbinden`); `swift-syntax-check` OK auf allen neuen Dateien; `bash scripts/check-schnell.sh` sauber (Namens-, Umfang- und Typnamen-Gate); alle Stub-Dateien des Moduls ersetzt ("Kommt bald" kommt nirgends mehr vor); keine Unterdrückungen; alle Texte Deutsch ohne Emojis; jede portierte Datei trägt oben `// Quelle: Lovea Health/<Pfad>`.

TESTS
- `LoveaBrueckeDienstTests`, `PartnerStandTests`, `PartnerEreignisRegelnTests`, `FreigabenTests`, `BandWunschSchlangeTests`, `BandDienstImplTests` (mit `FakeZentrale`), `FreundeKarteTests`
- Portierte Lovea-Tests laut Tabelle

ABSCHLUSSBERICHT
Kurz: geänderte Dateien, welche Idee wie umgesetzt ist, was nur Compiler oder Gerät beweist (ungeprüft), Wünsche ans Grundgerüst (du änderst es nie), Annahmen für SPEC Abschnitt 15.
