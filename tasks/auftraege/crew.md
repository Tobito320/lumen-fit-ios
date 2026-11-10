# Auftrag Crew (09.11.2026): Freunde, Herausforderungen, Reaktionen, Rangliste

Ahmed: "we want in lumen fit like friends challenging and a lot of stuff features for friends". Recherche: `docs/ideas/verbinden.md` (Welle 1 bis 3).
Grenzen aus Welle 1 bleiben: kein Freitext, kein Chat, keine Fremden, nur aktive Verbindungen, Pause einer Verbindung stoppt alles, keine Namen echter
Personen im Git, Gesundheitsdaten nur als Zusammenfassung und nur mit Freigabe. Kein Remote-Push (keine neue Entitlement), Neues kommt beim Öffnen an.

## Was es schon gibt (nicht neu bauen, nur nutzen)

- Verbindungen per QR (`server/verbindungen.js`, App `Konto/KontoVerbindungen.swift`, `Module/Verbinden/Verbindungen*.swift`), je Person Freigaben.
- Gym-Tab: Crew-Zeilen (`Module/Gym/GymCrewLogik.swift`, `GymCrewZeilen.swift` mit `GymCrewAbschnitt`, `GymCrewQuelle`), Mitlauf (`GymMitlaufLogik`),
  Rekord-Pinnwand (`GymRekordPinnwandLogik`, `GymRekordPinnwandView`), Einheit eines Partners (`GymPartnerEinheitView`), Demo-Crew (`GymCrewDemo`, `VerbindenDemo.crew`).
- Zusammenfassung je Person (`ZusammenfassungDatei`, Server filtert je Verbindung): `heute.gymTage`, `gymZiel`, `gymTageWoche`, `verlauf.imGym`,
  `verlauf.trainings`, `verlauf.einheiten` (bis 30, Sätze in Zehntel-kg, nur mit gym + verlauf), `verlauf.serieWochen`.

## Neu

1. **Crew-Seite** (Hub): Für dich (neue Reaktionen, Einladungen), Jetzt im Gym (Live), Herausforderungen, Rangliste der Woche, Rekorde der Crew mit
   Reaktion, letzte Trainings der Crew mit Reaktion, Freunde einladen (Code zeigen, Code scannen, Link teilen).
2. **Herausforderungen**: Duell 1:1 oder Gruppe gegeneinander, oder gemeinsames Ziel (Strava "Group Goal"). Maß: Gym-Tage, Sätze, Volumen, Rekorde,
   oder Übung (Steigerung des geschätzten 1RM in Promille gegen den eigenen Stand vor dem Start, fair für jedes Niveau). Dauer: bis Sonntag, 7, 14, 28 Tage.
   Einladen nur aktive, nicht pausierte Verbindungen, Annehmen nötig. Jede App rechnet ihren eigenen Wert und meldet nur die Zahl.
3. **Reaktionen**: feste Zeichen Respekt, Stark, Anfeuern (live), Stups ("Gym heute?", einmal am Tag je Person). Nur an aktive Verbindungen, die mir
   Gym zeigen. Beim Empfänger: "Für dich" auf der Crew-Seite und Zahl am Crew-Einstieg.
4. **Freund-Seite**: Kopf mit Status, Woche (Tage, Sätze, Volumen, Serie), Live-Einheit, Rekorde, letzte Trainings (Tipp: `GymPartnerEinheitView`),
   Vergleich gemeinsamer Übungen (bestes geschätztes 1RM du gegen Person), Knöpfe Herausfordern, Anfeuern oder Stups, Einstellungen der Verbindung.
5. **Link teilen**: Einladung 24 h gültig als https-Link (Seite des Servers leitet auf `lumenfit://freund?d=<Token>` weiter), der bestehende Ablauf
   (`VerbindungScanBlatt`) übernimmt.
6. **Crew-Bestwert in der Übung** ("Schlag meinen Satz"): im laufenden Training unter dem Übungsnamen der beste Satz der Crew für diese Übung
   ("Crew-Bestwert: Name 80 kg × 8"), nur mit Freigabe gym + verlauf, sonst nichts.

## Server (`server/freunde.js`, Tests `server/freunde.test.js`, Tabellen in `server/schema.sql`, Routen in `index.js` nur angehängt)

Alle Wege mit Konto (`h.kontoPruefen`), außer `GET /f/<token>`. Antworten JSON. Fremde und unbekannte Ids sind nicht zu unterscheiden (404).
Konto-Ids anderer Personen gehen nie hinaus: verbundene Personen erscheinen mit ihrer Verbindungs-Id, andere Teilnehmer mit einer Teilnehmer-Id
(SHA-256 aus Herausforderung und Konto, 16 Hex-Zeichen).

```sql
-- Crew (freunde.js): Herausforderungen zwischen verbundenen Konten. Jede App meldet nur ihre eigene Zahl je Herausforderung, nie Rohdaten.
CREATE TABLE IF NOT EXISTS herausforderungen (
  id TEXT PRIMARY KEY, ersteller TEXT NOT NULL,
  art TEXT NOT NULL,            -- tage | saetze | volumen | rekorde | uebung
  modus TEXT NOT NULL,          -- gegen | gemeinsam
  ziel INTEGER,                 -- nur gemeinsam: Summe aller
  uebung TEXT,                  -- nur art uebung: Übungsname, bis 40 Zeichen
  start TEXT NOT NULL, ende TEXT NOT NULL, erstellt TEXT NOT NULL,
  abgebrochen INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS herausforderung_teilnehmer (
  herausforderung TEXT NOT NULL, konto TEXT NOT NULL,
  status TEXT NOT NULL,         -- eingeladen | dabei | abgelehnt | ausgetreten
  wert INTEGER NOT NULL DEFAULT 0, aktualisiert TEXT,
  PRIMARY KEY (herausforderung, konto)
);
CREATE INDEX IF NOT EXISTS herausforderung_teilnehmer_konto ON herausforderung_teilnehmer (konto);
-- Feste Reaktionen zwischen aktiven Verbindungen, nach 30 Tagen gelöscht.
CREATE TABLE IF NOT EXISTS reaktionen (
  id TEXT PRIMARY KEY, von TEXT NOT NULL, an TEXT NOT NULL,
  art TEXT NOT NULL,            -- respekt | stark | anfeuern | stups
  ziel TEXT NOT NULL,           -- worauf, bis 80 Zeichen: rekord:<tag>:<übung> | einheit:<tag> | live:<tag> | stups:<tag>
  text TEXT NOT NULL DEFAULT '',-- Anzeige vom Sender, bis 80 Zeichen, z. B. "Kniebeuge 120 kg × 5"
  zeit TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS reaktionen_eindeutig ON reaktionen (von, an, art, ziel);
CREATE INDEX IF NOT EXISTS reaktionen_an ON reaktionen (an, zeit);
```

| Weg | Körper | Antwort | Regeln |
|---|---|---|---|
| `GET /freunde` | | `{herausforderungen, reaktionen, gesendet}` (unten) | Herausforderungen, in denen ich `eingeladen` oder `dabei` bin, Ende höchstens 14 Tage her. Reaktionen an mich der letzten 30 Tage, nur von Konten, mit denen ich jetzt aktiv verbunden bin (keine Pause auf einer Seite). `gesendet`: meine der letzten 30 Tage (`an` als Verbindungs-Id, `art`, `ziel`). |
| `POST /freunde/herausforderungen` | `{art, modus, tage? (1-28) oder ende? (ISO, 1 h bis 28 Tage), ziel? (gemeinsam: 1 bis 10^7), uebung? (art uebung: 1-40 Zeichen), einladen: [Verbindungs-Id] (1-9)}` | 201 `{id}` | Jede Id eine aktive Verbindung von mir, keine Seite pausiert, sonst 400. Höchstens 10 laufende, in denen ich dabei bin (429). Drossel 10/min. Ich `dabei`, Eingeladene `eingeladen`. Start jetzt. Aufräumen: Ende älter als 30 Tage löschen. |
| `POST /freunde/herausforderungen/<id>/annehmen` | | `{ok}` | nur `eingeladen`, nicht beendet, nicht abgebrochen (sonst 409). |
| `POST .../<id>/ablehnen` | | `{ok}` | nur `eingeladen`. |
| `POST .../<id>/verlassen` | | `{ok}` | `dabei` wird `ausgetreten`; der Ersteller bricht damit ab (`abgebrochen = 1`). |
| `PUT /freunde/werte` | `{werte: [{id, wert}]}` (bis 20) | `{ok, gesetzt}` | nur wo ich `dabei` bin, nicht abgebrochen, jetzt <= Ende + 24 h; `wert` ganze Zahl 0 bis 10^9. Anderes still übergehen. |
| `POST /freunde/reaktionen` | `{an: Verbindungs-Id, art, ziel, text?}` | 201 `{ok}` | Verbindung aktiv, meine, keine Pause, und `erlaubteBereiche(zeile, meineSeite)` enthält `gym`. `art` aus den vier. `ziel` 1-80 Zeichen, `text` 0-80, ohne Steuerzeichen. `stups` nur mit `ziel` = `stups:<heute>`. Doppelt = still ok (eindeutiger Index). Drossel 30/min. Aufräumen > 30 Tage. |
| `DELETE /freunde/reaktionen` | `{an, art, ziel}` | `{ok}` | nur eigene. |
| `POST /freunde/einladung` | | 201 `{token, laeuftAb, sekunden}` | wie `/verbindungen/einladung`, aber 24 h gültig, Tabelle `einladungen` (der bestehende Ablauf `ansehen`/`anfrage` gilt unverändert), höchstens 3 offene Link-Einladungen je Konto (älteste fliegt). Drossel 10/min. In `verbindungen.js` `einladungAnlegen` löscht nur noch die kurzen eigenen Codes (`laeuft_ab <= jetzt + 10 min`) und alles Abgelaufene, damit ein neuer QR-Code den Link nicht tötet. |
| `GET /f/<token>` | | HTML | ohne Konto. Token-Form wie `TOKEN_FORM` (sonst 404-Seite). Kein DB-Zugriff. Knopf "In Lumen Fit öffnen" auf `lumenfit://freund?d=<token>`, dazu `<meta http-equiv="refresh">` dorthin. Kopf: `Cache-Control: no-store`, `X-Robots-Tag: noindex`, `Referrer-Policy: no-referrer`, CSP `default-src 'none'; style-src 'unsafe-inline'`. Kein Name, kein Wert. |
| `GET /admin/freunde` | `?konto=<id>` | `{stand, konten, verbindungen, herausforderungen}` | nur `X-Admin-Key` (Prüfung in `index.js` `verwalten`), für den MCP `lumenfit` (gymcoach, 09.11.). Je Konto nur Zahlen: `freunde`, `anfragen_raus`, `anfragen_rein`, `einladungen_offen`, `herausforderungen_laufend`, `herausforderungen_eingeladen`, `reaktionen_raus_30t`, `reaktionen_rein_30t`, `letzte_aktivitaet` (ISO oder null). `verbindungen`: `anfrage` und `aktiv` mit `id, a, b, status, auto, a_sieht, b_sieht, erstellt, geaendert` (`a_sieht`: Bereiche, die a von b gerade sieht). `herausforderungen`: `id, art, modus, status, ende, ersteller, teilnehmer [{konto, status}]`. Keine Namen, keine Werte, kein Übungsname, kein Reaktionstext. `?konto=` filtert, unbekannt 404, falsche Form 400. |

Form von `GET /freunde`:

```json
{
  "herausforderungen": [{
    "id": "…32 hex…", "art": "saetze", "modus": "gegen", "ziel": null, "uebung": null,
    "start": "ISO", "ende": "ISO", "status": "laeuft|beendet|abgebrochen", "ersteller": true, "ich": "eingeladen|dabei",
    "teilnehmer": [{"id": "Verbindungs-Id oder Teilnehmer-Id", "verbunden": true, "ich": false, "name": "Profilname", "status": "eingeladen|dabei", "wert": 12, "aktualisiert": "ISO|null"}]
  }],
  "reaktionen": [{"id": "…", "von": "Verbindungs-Id", "name": "Profilname", "art": "respekt", "ziel": "rekord:2026-11-09:kniebeuge", "text": "Kniebeuge 120 kg × 5", "zeit": "ISO"}],
  "gesendet": [{"an": "Verbindungs-Id", "art": "respekt", "ziel": "…"}]
}
```

Namen: `name` ist der Profilname aus der Zusammenfassung der Person, sonst `konten.name`, gekürzt auf 40. Die eigene Zeile hat `ich: true`.
Teilnehmer mit `abgelehnt` oder `ausgetreten` stehen nicht in der Liste.

Tests (`node --test`, mit `fake-d1.js` wie `verbindungen.test.js`): Erstellen nur mit eigenen aktiven Verbindungen, Pause blockiert, Fremde Id 404,
Annehmen/Ablehnen/Verlassen, Ersteller-Abbruch, Werte nur wenn dabei und bis Ende + 24 h, Reaktion nur mit Gym-Freigabe, Stups einmal am Tag,
Reaktion von entfernter Verbindung nicht mehr sichtbar, keine Konto-Id in irgendeiner Antwort (Test sucht die Ids im JSON), Link-Einladung 24 h und
QR-Code löscht sie nicht, `/f/<token>` ohne Konto mit Kopfzeilen, kaputtes Token 404, Drossel.

## App (`LumenFit/Sources/Module/Verbinden/Freunde/`, Tests `LumenFit/Tests/Module/Verbinden/`)

Typnamen mit Vorsilbe `Crew` (Ziel weit eindeutig, `bash scripts/typnamen-doppelt.sh`). Reine Logik als `enum` mit `static func`, Zustand
`@MainActor @Observable final class`, Datentypen `Sendable`, Codable tolerant (`decodeIfPresent`, unbekannte Art: Eintrag fällt weg).

- `CrewModelle.swift`: `CrewAntwort`, `CrewHerausforderung`, `CrewTeilnehmer`, `CrewMass` (tage, saetze, volumen, rekorde, uebung; Titel, Einheit,
  Symbol), `CrewModus` (gegen, gemeinsam), `CrewReaktion`, `CrewReaktionArt` (respekt `hand.thumbsup.fill` "Respekt", stark `flame.fill` "Stark",
  anfeuern `megaphone.fill` "Anfeuern", stups `hand.point.right.fill` "Gym heute?"), `CrewGesendet`. Datum ISO (`LoveaVertrag.decoder()`).
- `CrewLogik.swift` (rein, getestet): eigene Wochenwerte aus `[GymSession]` (Tage, Sätze `zaehlt`, Volumen kg, Rekorde über `RekordLogik`);
  Wochenwerte einer Person aus `ZusammenfassungDatei` (Tage aus `gymTage` gegen `Datum.wochenstart`, Sätze/Volumen aus `verlauf.einheiten` dieser Woche,
  Rekorde über `GymRekordPinnwandLogik.rekorde` dieser Woche; fehlt die Freigabe: nil, nie 0 behaupten); Rangliste je Maß (eigene Zeile markiert,
  gleiche Werte gleicher Rang); eigener Wert einer Herausforderung aus `[GymSession]` im Zeitraum (Übung: Promille-Steigerung des besten e1RM
  gegen den besten Wert vor dem Start, ohne Wert davor gegen die erste Einheit im Zeitraum; Übung über Katalog-Name normalisiert wie
  `GymRekordPinnwandLogik`); Stand einer Herausforderung (führt, gleich, hinten, gewonnen, verloren, gemeinsam: Prozent vom Ziel); Ziel-Texte der
  Reaktionen (`rekord:<tag>:<übung normal>`, `einheit:<tag>`, `live:<tag>`, `stups:<tag>`, höchstens 80 Zeichen); neue Reaktionen seit einem Zeitpunkt;
  Vergleich gemeinsamer Übungen (bestes e1RM aus eigenen Sessions und aus `einheiten` der Person); Crew-Bestwert einer Übung; Ziel-Vorschlag für
  "gemeinsam" (Summe der Wochenwerte aller × Wochen, gerundet).
- `CrewDienst.swift`: `@MainActor @Observable final class CrewDienst` mit `static func von(_ umgebung: AppUmgebung) -> CrewDienst` (eine Instanz je
  `umgebung.konto`, statischer Speicher, kein Eingriff in `App/` oder `Konto/`). Netz nur über `umgebung.konto.sendeMitKonto(...)` mit
  `registrierteKennung()` bzw. `kennungBereit()`. `antwort` mit Datei-Cache `crew-server.json` in `umgebung.konto.ordner` (Datei weg, wenn das
  letzte Profil weg ist, ist nicht deine Sache). `laden()` holt `GET /freunde` und meldet danach die eigenen Werte laufender Herausforderungen
  (`PUT /freunde/werte`, nur wenn sich ein Wert geändert hat). Aufrufe für Erstellen, Annehmen, Ablehnen, Verlassen, Reagieren (optimistisch, bei
  Fehler zurück), Reaktion zurücknehmen, Einladungslink (https aus `KontoZugang.lade()?.server` plus `/f/<token>`). Demo (`-lumenFitDemo`, nur
  DEBUG): feste Beispiel-Antwort ohne Netz (zwei Herausforderungen, drei Reaktionen, Namen "Beispiel Freund A/B/C" wie `GymCrewDemo`).
  "Gesehen bis" für Reaktionen in `@AppStorage("fit.crew.gesehen")`.
- Ansichten: `FreundeTabView.swift` (Wurzel des Tabs Freunde, Aufteilung B vom 10.11.: Für dich, Trainingspartner mit eurer Woche, Rangliste,
  Herausforderungen, Rekorde, Freunde mit Status und Einladen; kein Feed; ohne Freunde steht das Einladen oben; kein eigener NavigationStack), `CrewFreundSeite.swift`, `CrewHerausforderungBlatt.swift` (Erstellen: Art Duell / Gruppe / Gemeinsam,
  Maß, Übung aus den eigenen Übungen, Dauer, Personen, Ziel mit Vorschlag, Hinweis "Alle in dieser Herausforderung sehen deinen Namen und deinen
  Wert."), `CrewHerausforderungSeite.swift` (Stand mit Balken, Tage übrig, Annehmen, Ablehnen, Verlassen), `CrewEinstieg.swift` (Zeile im Gym-Tab:
  "Crew", darunter "2 im Gym · Duell: du führst · 1 neu", Chevron, öffnet die Crew-Seite per `NavigationLink`; auch ohne Personen sichtbar mit
  "Freunde einladen und herausfordern"), `CrewBestwertZeile.swift` (eine Zeile für die Übung im Training, nichts ohne Wert).
- Einhängen (kleinste Diffs): `GymCrewAbschnitt` (in `Module/Gym/GymCrewZeilen.swift`) zeigt oben `CrewEinstieg`, auch ohne Crew-Zeilen.
  Crew-Zeilen werden antippbar (Freund-Seite), `GymCrewZeilen(grenze:)` zeigt im Tab Freunde alle. `GymRekordPinnwandView` bekommt den
  Respekt-Knopf je Zeile. `CrewBestwertZeile` in `UebungsKarte.kopf` (unter dem Untertitel, beim Umsortieren aus). Den Tab hängt lumenfit ein
  (`LumenFitTab`, Router, `RouteAnsicht`, `AppRootView`); Startseite ohne Freunde (Ahmed 10.11.).
- Design: Bausteine des Grundgerüsts (`HeroKarte`, `ListenKarte`, `Pille`, `LeerZustand`, `FehlerKarte`, `lumenToast`, `RollZahl`, `Haarlinie`,
  `GymZeile`), Farben aus `palette`, Abstände `Abstand`, Tippflächen 44 pt, VoiceOver-Label je Zeile, keine Emojis, Texte Deutsch, keine
  Endlos-Animation, Reduce Motion beachten. Beide Aufbauten: Lumen und Lovea (`@Environment(\.lumenAufbau)`), die Crew-Seite darf in beiden gleich sein.
- Tests (XCTest wie das Repo, oder Swift Testing für reine Logik): CrewLogik (Woche eigene und fremde, Freigabe fehlt = nil, alte Woche zählt nicht,
  Rangliste mit Gleichstand, Herausforderungswerte je Maß, Übung Promille mit und ohne Wert davor, Stand gewonnen/verloren/gemeinsam, Ziel-Texte
  begrenzt, neue Reaktionen, Vergleich, Bestwert), CrewModelle (tolerantes Lesen, unbekannte Art fällt weg, fehlende Felder), Demo nur in DEBUG.

## Nicht jetzt (Vorrat)

Crew-Streak über Wochen, gemeinsame Einheit per Code, Ränge/Stufen, Plan eines Freundes übernehmen, Route `lumenfit://crew` (braucht `App/`),
Mitteilung im Hintergrund (braucht den Hintergrund-Abruf in `App/`): als Wunsch an die Sitzung lumenfit.
