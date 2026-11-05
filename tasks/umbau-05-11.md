# Umbau 05.11.2026: Gym zuerst (Auftrag fitumbau)

Ahmeds Worte stehen in `~/.claude/buero-stand/fitumbau-05-11.md`. Basis: `main` = c50b9cf (alle Builds bis design-einfacher).

## Ziel
Lumen Fit wird eine Gym-App mit Essen als zweitem Bereich. Coach und Journal fallen weg, der Foto-Scan bleibt und geht für alle,
die Essen-Suche bekommt die starke Datenbank aus Lovea zurück, Schlaf und Geräte sieht nur, wem der Server es erlaubt.

## Entscheidungen
1. **Coach raus**: Tab, Chat, Ansichten, Store, Motor-Port, Routen, Morgen-Check, Gedächtnis, Server-Weg `/ki/coach` und `/admin/coach-probe`. Bleibt: `/ki/foto` und der Foto-Scan im Essen-Modul.
2. **Foto-Scan**: Server-Standard `kiFotoErlaubt: true` für alle (ein Konto-Schalter `false` sperrt). Limit hart auf dem Server: Konten mit Lovea-Person (Ahmed, Annika) ohne Limit, alle anderen 5 Fotos je Tag (Berliner Tag). Über dem Limit: 429 `tageslimit` ohne OpenAI-Aufruf, die App sagt freundlich "Heute sind deine 5 Fotos verbraucht, morgen geht es weiter". `/config` liefert `kiFotoLimit` (Zahl oder null = ohne).
3. **Essen-Suche**: Die starke Quelle war Loveas eigene Produktdatenbank (Open Food Facts DACH, 309.000 Produkte, D1 `lovea-essen-live`, FTS5 mit Beliebtheit). Lumen Fit fragte stattdessen die öffentliche OFF-Suche (findet bei "döner" türkische und spanische Produkte, bei "ehrmann high protein" kein Ehrmann). Der Lumen-Worker bindet die D1 lesend (`ESSEN`) und bietet `GET /essen/suche?q=&n=` und `GET /essen/barcode/<code>` (gleiche Antwort wie Lovea `server/essen.js`). Die App sucht beim Tippen (entprellt 250 ms) lokal BLS und auf dem Server; OFF bleibt nur Rückfall für Barcodes, die die D1 nicht kennt. Messung: `docs/research/essen-suche-messung.md`.
4. **Journal raus**: Freitext ("Schreib, was war"), `FreitextKI`, `FreitextChips`, `FreitextLogik`, `SchreibKarte`. Gespeicherte Freitext-Daten bleiben lesbar (kein Absturz bei alten Dateien), werden nur nicht mehr gezeigt.
5. **Schlaf, Armband, AirPods**: neuer Server-Schalter `schlafSichtbar` (Standard: Konten mit Lovea-Person; je Konto überschreibbar, ohne Build). Ohne ihn: kein Schlaf-Tab, keine Band- und AirPods-Seiten, keine Schlaf-Karten auf Heute, Bereich "Schlaf" nicht wählbar.
6. **Tabs**: Gym wird zwei Tabs.
   - **Training** (Hantel): heute trainieren, laufendes Training, letzte Einheiten. Keine Segmentleiste mehr: ein Tipp auf den Tab führt sofort ins Training.
   - **Plan** (Liste): Plan | Fortschritt als Segment.
   - Begründung: im Gym zählt der eine Griff zum laufenden Training; Planen und Zurückschauen passiert vorher oder danach und darf einen Tab weiter liegen.
   - Alle: Heute, Training, Plan, Essen. Mit `schlafSichtbar`: dazu Schlaf.
7. **Heute ohne "Mehr"**: Einsichten, Energie, Schritte, Woche stehen direkt auf Heute, jeweils einmal. Reihenfolge: Tagesleiste, Ringplatte, Plan-Karte, Hinweise, Einsichten, Energie, Schritte, Woche, Gewohnheiten, Gewicht, Partner.
8. **Verbinden krasser, nur fürs Gym**: Ideen in Wellen in `docs/ideas/verbinden.md`, gebaut werden nur die besten 2 bis 3 Gym-Ideen.

## Nicht
Kein Löschen gespeicherter Daten, keine Änderung an Lovea, keine neuen Abos oder Schlüssel, kein Wecker.

## Plan (Zweige von main)
| Teil | Zweig | Wer | Dateien |
|---|---|---|---|
| S Server: Foto-Limit, Essen-D1, schlafSichtbar, Coach-Wege weg | `umbau-server` | Planer | `server/` |
| A App: Coach und Journal raus, Tabs, Heute ohne Mehr, Schlaf-Schalter | `umbau-app` | Sonnet-Arbeiter | App, Router, Gemeinsam, Heute, Gym-Tab, Schlaf, Profil, Verbinden (nur Sichtbarkeit) |
| B App: Essen-Suche über Server, Foto-Limit-Text | `umbau-essen` | Sonnet-Arbeiter | `Module/Essen` |
| C Verbinden: Ideen-Wellen, dann Bau | `umbau-verbinden` | Arbeiter nach A | `Module/Verbinden`, `Module/Gym` (Partner) |

Reihenfolge: S, A und B parallel; C nach A. Dann Integration in `main`, CI, Server deploy (test, live), TestFlight.

## Erfolg
- CI grün (Build, 0 Warnungen, Tests), `check-schnell.sh` und `namen-gate.sh` sauber.
- Server-Tests grün; `/essen/suche?q=döner` liefert Döner-Produkte; Foto über Limit liefert 429 ohne OpenAI-Aufruf (Test).
- Kein `Coach` mehr in `LumenFit/Sources` außer alter Dekodierung.
