AUFTRAG: Modul „essen“ (Essen-Tab: Tagebuch, Scan, Quellen, Ampel, Fasten, Ziele, Analyse) der iOS-App Lumen Fit.
Maßgeblich ist `tasks/auftraege/essen.md` im eigenen Worktree; weicht dieser Text von der Datei ab, gilt die Datei.

KONTEXT
Lumen Fit: iOS-App (SwiftUI, Swift 6, iOS 26, iPhone) für Gesundheit und Fitness, client-only (kein Server, keine Konten), Standard-Design monochrom, Figur Lumi. Repo /home/tobi/projects/lumen-fit-ios, Zweig modul/essen im eigenen Worktree, Grundgerüst ist gemergt. Lies zuerst CLAUDE.md, CONSTRAINTS.md, CONTEXT.md, SPEC.md (Abschnitte 5.3, 5.5, 5.8, 5.9, 6, 10 mit den Fallen, 11) und docs/research/design.md. Kein Mac: lokal nur swift-syntax-check, Compiler und Tests laufen im Integrationsschritt in CI (starte kein CI). Test zuerst, kleinster korrekter Diff. Quelle für Fertiges ist /home/tobi/projects/lovea-app-ios/Lovea/Sources (nur lesen, Lovea nie ändern; Portierungsregeln SPEC 5.8). Vorlage für Konfiguration war Bahnherz.

ZIEL
Der Tab Essen führt ein Tagebuch ohne Konto: Barcode-Scan, BLS offline, Open Food Facts online, Portion-Schieber, Favoriten, Halal- und Zucker-Ampel mit Text, Fasten-Fenster, Etikett-Foto, Ziele aus Körperdaten und eine Wochenanalyse. Essen ist monochrom (Grautöne und Muster).

DEINE ORDNER (nur hier schreiben; alles andere ist tabu)
- LumenFit/Sources/Module/Essen/
- LumenFit/Tests/Module/Essen/
- LumenFit/Tests/Fixtures/Essen/

DU NUTZT AUS DEM GRUNDGERÜST (Namen stehen in SPEC 5.9)
- `AppUmgebung.daten.essen` (`EssenStore`: Port von Loveas `ErnaehrungModell` und `FastenModell`: Tagebuch, Favoriten, Zuletzt, Eigene, Rezepte, Fasten, Körperwerte), `ziele`, `http` (`HTTPLader`), `ereignisse` (`mahlzeitGespeichert`)
- Lovea-Typen im Grundgerüst: `Lebensmittel`, `LebensmittelPortion`, `Naehrwerte`, `EssenEintrag`, `Mahlzeit`, `Rezept`, `ErnaehrungsZiele`, `ErnaehrungLogik`, `LebensmittelBasis` (BLS, `LumenFit/Resources/Daten/lebensmittel-basis.json`), `FastenPlan`, `FastenLogik`
- Design: `ListenKarte`, `Pille`, `LeerZustand`, `FehlerKarte`, `MusterFlaeche`, Glas-Knopf für den Scan, `Palette`, `DiagrammKarte`, `RollZahl`
- Stubs, die du ersetzt: `EssenModul`, `EssenTabView(bereich:)`, `ScanView`

AUS LOVEA PORTIEREN (unter Lovea/Sources/Health/, wenn nicht anders angegeben; Modus K kopieren, A anpassen, N neu, - nicht)
- Ernaehrung/BarcodeKette.swift (BarcodeLogik, BarcodeQuellen; die Quelle `server` entfällt) [A] Tests: BarcodeLogikTests
- Ernaehrung/BarcodeScanner.swift (VisionKit `DataScannerViewController`) [A]
- Ernaehrung/ErnaehrungAnalyse.swift, ErnaehrungPortionen.swift, ErnaehrungRating.swift, Mikronaehrstoffe.swift, TagesNaehrwerte.swift, SuchZusammenfuehrung.swift, ErnaehrungEigene.swift [A] Tests: ErnaehrungAnalyseTests und die Tests zu diesen Dateien in Lovea/Tests (Suche nach dem Dateinamen)
- Ernaehrung/EssenAmpel.swift, EssenAmpelKarte.swift (Halal und Zucker; Pille mit Symbol und Text, keine reine Farbe) [A] Tests: EssenAmpelTests
- Ernaehrung/NaehrwertFoto.swift (Etikett lesen mit Vision `VNRecognizeTextRequest`, ohne Server) [A] Tests: NaehrwertFotoTests
- Ernaehrung/ErnaehrungView.swift, ErnaehrungHinzufuegen.swift, HinzufuegenTeile.swift, ErnaehrungMahlzeit.swift, LebensmittelDetail.swift, EssenAnalysenView.swift, FastenView.swift, ErnaehrungKoerper.swift (Views) [N]
- NICHT übernehmen: EssenServer.swift, EssenAuftrag.swift, EssenAuftragStore.swift, KiFoto.swift, EssenLive.swift (Live Activity, nicht in v1), Essen/EssenClient.swift, Essen/KiZyklus.swift [-]

NEU ZU BAUEN
- `OpenFoodFactsQuelle` über `HTTPLader`: `GET /api/v2/product/<code>.json?fields=...`, User-Agent `LumenFit/<Version> (+https://github.com/Tobito320/lumen-fit-ios)` (keine Mail im Quelltext, SPEC Annahme 26), höchstens 15 Abfragen je Minute, 404 oder `status 0` = unbekannt, kJ-nur-Produkte kcal = kJ / 4,184; Textsuche `search.openfoodfacts.org/search` nur auf "Suchen", höchstens 10 je Minute, ein Wiederholversuch bei HTTP 500
- `LebensmittelSuche`: BLS lokal zuerst, dann Open Food Facts; unbekannter Barcode führt zur Eingabe von Hand; letzter Treffer wird gemerkt
- `MakroDonut` (`SectorMark`) in Grautönen mit Muster und Beschriftung; Portion-Schieber (Gramm, Stück, Portion) mit rollenden Zahlen; Favoriten und Zuletzt; Fasten-Fenster mit Restzeit
- Ziele-Karte "aus deinen Körperdaten" (Rechnung `ErnaehrungsZiele` aus dem Grundgerüst, Erklärung, "übernehmen"); Wochenanalyse in Klartext (Protein gegen Ziellinie, Zucker, Ballaststoffe, Mikronährstoff-Lücken)
- Demo-Saat `EssenModul.demoSaat`; Scan nur in Debug mit Fixture-Code, damit CI-Bilder ohne Kamera gehen

IDEEN, DIE DU EINBAUST (alle müssen am Ende drin sein)
41. **Barcode-Scan** – Kamera erkennt den Code, Treffer aus Speicher, BLS, dann Open Food Facts; unbekannt führt zur Eingabe von Hand.
42. **7.140 Lebensmittel ohne Netz** – BLS 4.0 gebündelt; Haferflocken, Ei und Reis gibt es auch im Flugmodus.
43. **Makro-Donut ohne Farbe** – Protein, Kohlenhydrate, Fett als Grautöne mit Muster und Beschriftung; die Farben bleiben für Gym und Schlaf frei.
44. **Halal- und Zucker-Ampel** – Pille mit Symbol und Text, prüft Zutaten (Gelatine, Alkohol, E-Nummern) und sagt "unklar", wenn Zutaten fehlen.
45. **Favoriten und Zuletzt** – häufige Lebensmittel oben, eigene Gerichte als Favorit speichern.
46. **Portion-Schieber** – Gramm, Stück oder Portion; die Nährwerte rollen mit.
47. **Fasten-Fenster 16:8** – Balken mit Restzeit und Verlauf, ein Tipp startet das Fenster.
48. **Etikett-Foto** – Nährwerttabelle fotografieren, Vision liest die Zahlen, du prüfst und speicherst.
49. **Ziele aus deinen Körperdaten** – Kalorien und Protein aus Größe, Gewicht und Ziel (aufbauen, halten, abnehmen), alles überschreibbar.
50. **Wochenanalyse Essen** – Protein je Tag gegen Ziellinie, Zucker, Ballaststoffe und Mikronährstoff-Lücken in Klartext.

FIXTURES
Fixtures/Essen: `bls-4-0-lovea-auszug.json`, `off-v2-product-4008400402222.json`, `off-v2-product-nicht-gefunden.json`, `off-search-haferflocken.json`, `off-cgi-search-haferflocken.json` (kopiert das Grundgerüst). Alle Netz-Tests laufen mit `SkriptLader` gegen diese Dateien, nie gegen das Netz.

AKZEPTANZ
- Ein bekannter Barcode, ein unbekannter (404 und `status 0`), ein kJ-only-Produkt und ein HTTP-500-Wiederholversuch sind durch Fixtures getestet
- Die Quellen-Seite (Modul profil) kann BLS und Open Food Facts nennen; deine Detailansicht zeigt "Quelle: BLS" oder "Quelle: Open Food Facts" an jedem Lebensmittel
- Die Ampel sagt "unklar", wenn Zutaten fehlen, und zeigt immer Symbol und Text
- Kein Netzaufruf ohne Nutzeraktion (kein Vorladen); Rate-Limits werden eingehalten (Test mit injizierter `Uhr`)
- Kein Server, keine Lovea-Adresse, kein Schlüssel im Quelltext
- Gemeinsam: alle Ideen oben eingebaut oder mit Grund als nicht umsetzbar gemeldet; nur die eigenen Ordner geändert (`git diff --name-only main...modul/essen`); `swift-syntax-check` OK auf allen neuen Dateien; `bash scripts/check-schnell.sh` sauber (Namens-, Umfang- und Typnamen-Gate); alle Stub-Dateien des Moduls ersetzt ("Kommt bald" kommt nirgends mehr vor); keine Unterdrückungen; alle Texte Deutsch ohne Emojis; jede portierte Datei trägt oben `// Quelle: Lovea Health/<Pfad>`.

TESTS
- `OpenFoodFactsQuelleTests`, `LebensmittelSucheTests`, `MakroDonutDatenTests`, `WochenanalyseTests`, `ZielKarteTests`
- Portierte Lovea-Tests laut Tabelle

ABSCHLUSSBERICHT
Kurz: geänderte Dateien, welche Idee wie umgesetzt ist, was nur Compiler oder Gerät beweist (ungeprüft), Wünsche ans Grundgerüst (du änderst es nie), Annahmen für SPEC Abschnitt 15.
