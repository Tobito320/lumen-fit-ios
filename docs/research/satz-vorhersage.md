# Satz-Vorschlag: Formeln, Regeln, Quellen

Stand 09.11.2026. Auftrag: "smart prediction helping with each sets for reps and kg calculations from the strength messured. For maximum growth",
dazu der Wunsch "mehr Gewicht, weniger Wiederholungen". Code: `LumenFit/Sources/Module/Gym/SatzVorhersageLogik.swift` (rein, getestet in
`LumenFit/Tests/Module/Gym/SatzVorhersageLogikTests.swift`), Anzeige `SatzVorhersageAnzeige.swift`. Recherche mit Quellen unten; was keine Studie
belegt, steht als Entscheidung da.

## Stärke (geschätztes 1RM)

- **Formel:** Epley, 1RM = kg × (1 + n / 30), n = Wiederholungen bis zum Versagen = Wiederholungen + Reserve (RIR). Eine Wiederholung ist das
  Gewicht selbst, wie beim 1RM-Rekord (`RekordLogik.e1rm`). Von 4 bis 10 Wiederholungen liegt Epley höchstens 1,1 Prozentpunkte neben der
  RPE-Tabelle von Tuchscherer (RPE-10-Spalte 89,2 / 86,3 / 83,7 / 81,1 / 78,6 / 76,2 / 73,9 % für 4 bis 10). Mittelwerte mehrerer Formeln bringen
  bei 6 bis 12 Wiederholungen kaum etwas (Epley und Brzycki liegen dort innerhalb 3 %).
- **Genauigkeit:** Formeln sind unter 10 Wiederholungen genauer (Mayhew 2008, JSCR 22:1570; Reynolds 2006, JSCR, R² 0,993 aus 5RM, 0,976 aus 10RM,
  0,955 aus 20RM). Darum zählen für die Stärke zuerst Sätze mit höchstens 12 Wiederholungen bis zum Versagen; gibt es keine (viele Wiederholungen an
  Maschinen), zählen alle.
- **Reserve:** RPE 10 = 0 RIR (Zourdos 2016, JSCR 30:267; Helms 2016, SCJ). Gespeichert ist RPE = 10 − RIR (`Anstrengung`). Ohne Angabe nimmt der
  Vorschlag 2 Wiederholungen Reserve an (Entscheidung: Studien zeigen, dass Menschen ihre Reserve um rund eine Wiederholung unterschätzen,
  Halperin 2022, Sports Med; eine Annahme ohne Angabe gibt es in der Literatur nicht). "Bis zum Versagen" ist 0.

## Bereiche und Reserve-Ziel

| Art (aus Katalog und Name) | Schwer (Standard) | Klassisch | Reserve-Ziel (letzter Satz) |
|---|---|---|---|
| Freie Grundübung (Langhantel, Kurzhantel, SZ, Kettlebell, Körpergewicht) | 4 bis 8 | 6 bis 10 | 2 (1) |
| Grundübung an Maschine, Kabel, Multipresse, Schlitten | 6 bis 10 | 8 bis 12 | 1 (0) |
| Isolation | 6 bis 10 | 8 bis 12 | 1 (0) |
| Kleine Muskeln (Waden, Unterarme, Bauch, Nacken) | 8 bis 12 | 10 bis 15 | 1 (0) |

Muskelaufbau ist über weite Lastbereiche gleich, solange die Sätze nah ans Versagen gehen (Schoenfeld 2017, JSCR; Lopez 2021, MSSE; Schoenfeld 2021,
Sports). Nähe zum Versagen zählt für Wachstum mehr als für Kraft (Robinson 2024, Sports Med); 1 bis 2 Reserve waren so gut wie Versagen (Refalo 2024,
J Sports Sci). "Schwer" folgt dem Wunsch nach mehr Gewicht und weniger Wiederholungen und liegt noch im wirksamen Bereich.

## Erster Satz einer Übung (doppelte Progression)

Aus der letzten Einheit derselben Übung (schwerster Arbeitssatz, ohne Aufwärm- und Dropsätze):
1. **Oben im Bereich** (bester Satz am oberen Rand, alle Sätze mit diesem Gewicht höchstens eine darunter): ein Geräteschritt mehr Gewicht
   (Langhantel 2,5, Kurzhantel 2, Maschine und Kabel 5 kg, wie Plus und Minus). Wiederholungen aus der Stärke bei Ziel-Reserve.
2. **Weit darüber** (mehr als eine über dem Bereich): so viel schwerer, dass oben im Bereich herauskommt, höchstens 10 % oder ein Schritt.
3. **Schritt zu groß** (man fiele unter den Bereich, typisch bei 5-kg-Stufen an leichten Maschinen): erst eine Wiederholung mehr; ab drei über dem
   Bereich trotzdem hoch. (Plotkin 2022, PeerJ: Wiederholungs- und Gewichtssteigerung wirken beide.)
4. **Unter dem Bereich:** leichter in Geräteschritten, bis der untere Rand mit Ziel-Reserve passt (höchstens 30 % weniger).
5. **Im Bereich:** gleiches Gewicht, eine Wiederholung mehr; war der Satz bis zum Versagen, erst halten.
6. **Nach Pause** (letzte Einheit über 14 Tage her): 5 % leichter, über 28 Tage 10 % (Entscheidung, auf den Schritt abgerundet).

## Nächster Satz im Training (Autoregulation)

Die Stärke von heute kommt aus dem zuletzt abgehakten Satz (Gewicht, Wiederholungen, Reserve), abzüglich der Ermüdung bis zum nächsten Satz.
Leichte Rampensätze (unter 80 % des vorgeschlagenen Arbeitsgewichts, oft nicht als Aufwärmen markiert, etwa 45 → 65 → 65 kg am Latzug) zählen
dafür nicht; bis zum ersten schweren Satz gilt der Vorschlag aus der letzten Einheit.

| Reserve des letzten Satzes | Verlust je Satz bei 3 bis 4 min Pause |
|---|---|
| 0 (Versagen) | 1,5 |
| 1 | 1,0 |
| 2 | 0,75 |
| 3 und mehr | 0,5 |

Quelle: Refalo 2023 (Sports Med Open, Bankdrücken 75 %, 4 min Pause: Versagen 14 → 6, 1 RIR 13 → 8, 3 RIR 10 → 7 über 6 Sätze). Kürzere Pausen
kosten mehr: Faktor 1,6 unter 90 s, 1,25 unter 150 s, 1,0 unter 210 s, 0,9 darüber (Miranda 2009, JSSM: 1 min −2,1 gegen 3 min −1,2 je Satz;
Singer 2024: über 90 s kaum Unterschied). War der Satz leicht (mehr als eine über dem Bereich), ein Schritt mehr Gewicht; fallen die Wiederholungen
unter den Bereich, leichter (wie APRE, Mann 2010, JSCR, nur vorsichtiger).

## Stillstand und Deload

Stillstand: mindestens fünf Einheiten, die beste Stärke der letzten drei liegt nicht über dem Bestwert davor, und keine der drei war deutlich leichter
(unter 93 % des Bestwerts, dann war der Deload schon da oder es war ein schlechter Tag). Dann eine Einheit 10 % leichter mit zwei Wiederholungen
mehr Reserve, gern ein Satz weniger. Danach geht es vom Stand vor dem Deload weiter. Praxis: Deloads alle 5,6 ± 2,3 Wochen für rund eine Woche,
Volumen und Nähe zum Versagen runter (Rogerson 2024, Sports Med Open; Bell 2023, Sports Med Open). Feste Prozentzahlen hat keine Studie
(Entscheidung).

## Aufwärmen

Aus dem vorgeschlagenen Arbeitsgewicht: eine Aufwärmzeile 60 % × 6, zwei Zeilen 65 % × 5 und 85 % × 2, ab drei wie "Aufwärmsätze einfügen"
(40 % × 10, 60 % × 5, 80 % × 3). Schwerere Aufwärmsätze helfen mehr als leichte (Ribeiro 2020, IJERPH). Gerundet auf den Geräteschritt.
Dropsatz: 20 % leichter als der Satz davor.

## Anzeige (09.11.2026, Wunsch: simpel wie Hevy)

Dezent in der Satz-Zeile wie Hevys "Previous"-Spalte: neben "Letztes Mal" steht "Ziel 32,5 kg × 8", ein Tipp trägt Gewicht und Wiederholungen ein. Grund und Reserve hört VoiceOver. Nur am ersten offenen Satz jeder Übung und nur, solange die Zeile anders steht; kein Scheiben- oder Aufwärmrechner.

## Quellen

Epley 1985 (über Ribeiro 2024, Int J Strength Cond, 10.47206/ijsc.v4i1.327) · Mayhew 2008, 10.1519/JSC.0b013e31817b02ad ·
Reynolds 2006, 10.1519/R-15304.1 · Zourdos 2016, 10.1519/JSC.0000000000001049 · Helms 2016, 10.1519/SSC.0000000000000218 ·
Halperin 2022, 10.1007/s40279-021-01559-x · Refalo 2023, 10.1186/s40798-023-00554-y · Refalo 2024, 10.1080/02640414.2024.2321021 ·
Miranda 2009, PMC3763284 · Singer 2024, 10.3389/fspor.2024.1429789 · Mann 2010, 10.1519/JSC.0b013e3181def4a6 ·
Schoenfeld 2017, 10.1519/JSC.0000000000002200 · Schoenfeld 2021, 10.3390/sports9020032 · Lopez 2021, 10.1249/MSS.0000000000002585 ·
Robinson 2024, 10.1007/s40279-024-02069-2 · Plotkin 2022, 10.7717/peerj.14142 · Rogerson 2024, 10.1186/s40798-024-00691-y ·
Bell 2023, 10.1186/s40798-023-00633-0 · Ribeiro 2020, 10.3390/ijerph17186882 · RPE-Tabelle Tuchscherer (Zweitquelle).

Ungeprüft: die RPE-Tabelle stammt aus einer Zweitquelle; die Ermüdungszahlen kommen je aus einer Studie; Reserve-Annahme, Stillstandsregel,
Deload-Prozente, Geräteschritte und Aufwärmprozente sind Entscheidungen, keine Studienergebnisse.
