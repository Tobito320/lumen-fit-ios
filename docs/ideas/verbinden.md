# Verbinden: Ideen, wie Leute sich im Gym antreiben

Stand 05.11.2026. Recherche, kein Code. Ziel (Ahmed): "Das mit andere Leute connecten muss krasser gemacht werden, aber keine unnötigen Sachen. App sollte sehr stark auf Gym Fokus."
Regeln für alle Ideen: nur Zusammenfassungen, nur nach Freigabe (`zeigt`), kein Chat (dafür Lovea), keine Nachricht an Fremde (nur an bereits verbundene Personen, nur feste Zeichen, abschaltbar), keine Namen echter Personen im Git.

## Was es schon gibt (gelesen im Code)

- **Server** (`server/verbindungen.js`): Verbindungen zwischen Konten per QR-Code (10 Min gültig, Anfrage, Annehmen), bis 50 aktive. Je Seite `zeigt` (Standard nur `schritte`, `gym`), `ausblenden`, `pause`, `mitteilungen`, `favorit`, `name`. Bereiche: schritte, gym, schlaf, essen, plan, verlauf, tagebuch, koerper, stimmung, gewohnheiten. Jedes Konto lädt eine Zusammenfassung hoch (`partner_stand`), der Server filtert sie je Verbindung beim Abruf. Die zwei Lovea-Konten verbinden sich von selbst. Kein Push, keine Gruppen, keine Reaktionen: nichts geht zwischen Konten außer dieser gefilterten Zusammenfassung.
- **Inhalt der Zusammenfassung** (`ZusammenfassungBauer`): Schritte, Gym-Tage der Woche und Ziel, Plan, Verlauf (letzte 10 Einheiten, dazu `einheiten` mit Übungen und Sätzen in kg/Wdh, nur mit Freigabe `gym` plus `verlauf`), Ereignisse der letzten 48 h (`gymStart`, `gymEnde`, `rekord`, `ziel`, `schlafGut`; ein Rekord ist nur ein Text, ohne Übung und Wert).
- **Im Gym sichtbar** (`GymStartView`): eine Zeile "Partner: gerade im Gym / 54 min · 27 Sätze / geplant: Push" (`GymPartnerLogik.status`), `PartnerKarte(bereich: .gym)`, Menü "Plan von X", Verlauf-Wechsel Ich/Partner, Einheit des Partners zum Nachlesen (`GymPartnerEinheitView`), Punkt für den Partner im Wochenstreifen (`WochenPersonenPunkte`), lokale Mitteilung "Partner ist im Gym" / "hat einen Rekord".
- **Wichtigste Lücke:** Alles im Gym-Tab hängt an **einem** Partner (`umgebung.daten.verbindung.partner`, der Lovea-Platz). Freunde per QR stehen nur in Profil > Verbindungen (Kurzinfo) und können über `partnerStandUeberschreibung` einzeln angesehen werden. Im Gym sieht man sie nicht.
- **Freunde-Seite** (`FreundeView`, Ideen 89/90 in `lumen-fit.md`): Wochenkarte als Bild/Link/QR, Rangliste aus **von Hand importierten** Karten. "Respekt" ist nur lokal auf diesem Gerät, kein Zähler, der andere erfährt nichts. Die Rangliste nutzt die Server-Verbindungen nicht.
- **Freigabe-Stufen** (`FreigabeStufe`): nur "Wenig" (Schritte, Gym) und "Alles". Dazwischen nur einzelne Schalter.

Schon in `lumen-fit.md` gesammelt und deshalb hier nicht doppelt: Partner-Karte (82), Mitteilungen bei Partner-Ereignissen (83), Freigaben je Datenart (84), Freundeskarte (89), Wochen-Rangliste mit Respekt (90). Die Ideen unten bauen darauf auf oder füllen die Lücken.

## Die 5 stärksten

1. **Gym-Crew im Gym-Tab (Nr. 1)**: Die vorhandene Partner-Zeile wird zu einer Liste aller verbundenen Personen. Größter Sprung, kleinster Aufwand: Logik und Daten sind da, nur die Schleife und die Zeile fehlen. Es macht aus dem Gym-Tab sofort einen sozialen Ort ("zwei sind heute schon dran") und deckt "Fokus auf Gym" ab.
2. **Freigabe-Stufe "Gym-Crew" (Nr. 2)**: Gym, Plan und Verlauf teilen, aber nie Schlaf, Essen, Körper. Kollegen geben sonst gar nichts frei, und ohne Freigabe ist jede Funktion leer. Klein und löst das Vertrauensproblem.
3. **Live-Rangliste der Crew (Nr. 3)**: Gym-Tage, Sätze und Volumen der Woche aus den echten Verbindungen statt aus Kartenimport (wie Liftoff und Hevy-Leaderboards). Regelmäßiger Grund, die App zu öffnen, und kommt ohne Server-Änderung aus.
4. **Echtes Respekt (Nr. 4)**: Ein Tipp auf eine Einheit oder einen Rekord, der Zähler erscheint beim anderen (Hevy-Likes, Strava-Kudos). Kudos sind der stärkste kleine Antrieb, weil jemand dein Training sieht. Braucht eine kleine Server-Erweiterung.
5. **Rekord-Pinnwand mit Übung und Wert (Nr. 5)**: "Karim: Kniebeuge 120 kg x 5" statt "hat einen Rekord". Konkret, vergleichbar, löst Respekt und Wettbewerb aus. Ereignis um zwei Felder erweitern.

## Alle Ideen, nach Wirkung durch Aufwand sortiert

Aufwand: klein = nur App, mittel = App plus kleine Server-Erweiterung, groß = neues Konzept auf dem Server. "Nutzt Verbindung" = nutzt die vorhandene Verbindung und `zeigt`-Freigabe.

| Nr | Idee | Was | Warum im Gym | Aufwand | Nutzt Verbindung? |
|---|---|---|---|---|---|
| 1 | Gym-Crew-Liste | Gym-Tab zeigt alle verbundenen Personen mit Status ("gerade im Gym", "54 min", "geplant: Push", "noch nicht"). | Sichtbare Anwesenheit der anderen zieht dich hin (Whoop-Teams, Apple Fitness Freunde). | klein | ja, `status` für jede Person statt nur Partner |
| 2 | Stufe "Gym-Crew" | Dritte Freigabe-Stufe: gym, plan, verlauf; Schlaf, Essen, Körper bleiben zu. | Wer wenig preisgibt, kann trotzdem Gym teilen; mehr Leute machen mit. | klein | ja, `FreigabeStufe` + `zeigt` |
| 3 | Live-Crew-Rangliste | Woche: Gym-Tage, Sätze, Volumen aus den Zusammenfassungen aller Verbindungen, eigene Zeile hervorgehoben. | Wöchentlicher Wettkampf mit Freunden (Liftoff, Strava-Clubs). | klein | ja, `gymTage`, `einheiten` |
| 4 | Respekt senden | Ein Zeichen pro Einheit/Rekord an die Person; Zähler und "von wem" beim Empfänger. | Kudos belohnen das Training sofort (Hevy, Strava). | mittel (Tabelle `reaktionen`, `POST/GET`) | ja, nur an aktive Verbindungen, nicht pausiert |
| 5 | Rekord-Pinnwand | Ereignis `rekord` bekommt Übung und Wert; Gym-Tab zeigt die letzten 48 h der Crew als Liste. | Konkrete Zahlen anderer sind ein Ziel zum Schlagen. | mittel (zwei Felder im Ereignis, Server filtert wie bisher) | ja, Freigabe `gym` |
| 6 | Heute gleicher Tag | Hinweis "Karim trainiert heute auch Push", wenn Plan-Tage zusammenpassen. | Macht aus zwei Trainings eine Verabredung ohne Nachricht. | klein | ja, Freigabe `plan` |
| 7 | Übungs-Vergleich | In der Übung: "Kniebeuge: du 100 x 5, Karim 120 x 5 (vor 2 Tagen)" aus der letzten Einheit des Freundes. | Direkter Maßstab genau in dem Moment, in dem man den Satz macht (Strava-Segment-Gefühl). | klein | ja, `einheiten` + `verlauf` + `gym` |
| 8 | Gemeinsames Wochenziel | Crew-Ring: "9 von 12 Einheiten" aus den Gym-Tagen aller. | Niemand will der sein, der den Ring offen lässt (Apple Fitness Wettkampf, Whoop Teams). | klein | ja, `gymTage`, `gymZiel` |
| 9 | Crew-Heatmap | Monatsraster, jede Person ein Punkt je Tag; aus dem Partnerpunkt (`WochenPersonenPunkte`) für alle. | Lücken und Serien der Gruppe auf einen Blick. | klein | ja, `gymTage` |
| 10 | Rückblick am Sonntag | Lokale Karte: wer wie oft war, bester Rekord der Woche, dein Platz. Keine Mitteilung an andere. | Wochenabschluss gibt dem Wettbewerb einen Punkt. | klein | ja, vorhandene Daten |
| 11 | Faire Wertung | Rangliste nach Verbesserung zum eigenen Schnitt, nicht nach Rohvolumen. | Anfänger und Starke bleiben im selben Spiel; Frust sinkt. | klein | ja |
| 12 | Duell 1:1 | Zwei Personen, eine Woche, ein Maß (Gym-Tage oder Sätze); beide rechnen lokal aus den Zusammenfassungen. | Kleine, persönliche Wette hält mehr als eine große Liste. | mittel (Duell als Einstellung in der Verbindung) | ja, `a_einst`/`b_einst` |
| 13 | Meilenstein-Ereignisse | Neue Ereignisarten: 50./100. Einheit, 4-Wochen-Serie, erste Woche über Ziel. | Gefeierte Meilensteine sehen auch die anderen (Strava-Trophäen). | klein bis mittel (Art im Server freischalten) | ja |
| 14 | Plan übernehmen | Plan eines Freundes als Vorlage in den eigenen Plan kopieren. | Die Hürde, "was soll ich trainieren", fällt weg. | klein | ja, Freigabe `plan` (bisher nur Ansicht) |
| 15 | Bestenliste je Übung | Geschätztes 1RM je Hauptübung in der Crew, Übung wählbar. | Kraftrangliste wie Segmente: ein klares, eigenes Rennen. | mittel (Server speichert Bestwerte je Übung, sonst nur letzte 10 Einheiten) | ja, `gym` |
| 16 | Stummer Stups | Ein fester "Gym heute?"-Knopf an Favoriten, erscheint beim anderen als Hinweis, kein Text. | Der Anstoß am Tag, an dem man sonst nicht geht. | mittel (Ereignis `stups`, Schalter `mitteilungen` gibt es; Push-Weg ungeprüft, ohne Push erst beim Öffnen) | ja, nur Verbindungen mit `mitteilungen` an |
| 17 | "Ich gehe um 18 Uhr" | Eigener Status "heute geplant, Uhrzeit" in der Zusammenfassung, Crew-Zeile zeigt es. | Zeit statt Nachricht: andere können sich anschließen. | mittel (ein Feld im Plan-Teil) | ja, Freigabe `plan` |
| 18 | Gym-Streak der Crew | Serie "Wochen in Folge, in denen alle ihr Ziel geschafft haben"; reißt nur für alle. | Gruppen-Streak schafft Verantwortung ohne Beschämung. | klein | ja, `gymZiel` |
| 19 | Live Activity: "2 weitere im Gym" | Zeile in der Live Activity während des Trainings. | Gesellschaft mitten im Satzpause-Blick. | klein bis mittel (Modul widgets, nicht dieses; Wunsch an Integration) | ja |
| 20 | Crew-Code | Ein Scan verbindet mit der ganzen Gruppe (Crew-Einladung statt 28 Einzelscans bei 8 Personen). | Ohne das scheitert alles daran, dass nicht jeder jeden einzeln koppelt. | groß (Crew-Tabelle, Beitritt, Freigaben je Crew; Schutz vor transitiver Einsicht) | baut auf Verbindungen auf, ersetzt sie nicht |

## Empfohlene Reihenfolge

1. Nr. 1, 2, 3 zusammen (nur App, kein Server-Deploy).
2. Nr. 6, 7, 8, 9 (nur App, nutzen dieselben Zusammenfassungen).
3. Nr. 5, 4 (erste Server-Erweiterung, ein gemeinsamer Deploy: Ereignisfelder plus Reaktionen).
4. Nr. 13, 18, 12 danach.
5. Nr. 20 nur, wenn die Gruppe wirklich wächst; bis 6 Personen reichen QR-Paare.

## Grenzen, die bewusst bleiben

- Kein Feed mit Freitext, kein Kommentar, kein Chat. Reaktionen sind feste Zeichen.
- Gewichte und Sätze anderer nur mit `gym` und `verlauf` freigegeben; Nr. 7 und 15 sind aus bei fehlender Freigabe (leer, kein Platzhalter).
- Rangliste zeigt nie Körpergewicht, Schlaf, Essen.
- Pause einer Verbindung gilt für jede neue Funktion (nichts senden, nichts empfangen).

## Welle 1

Zuerst bauen: Nr. 1 (Gym-Crew-Liste), Nr. 2 (Stufe "Gym-Crew"), Nr. 3 (Live-Crew-Rangliste). Danach Nr. 5 und 4 mit einem Server-Deploy. Alles andere bleibt Vorrat. Ungeprüft: ob `GymStartView` mit mehreren Personen noch ruhig aussieht (nur Gerät/Simulator zeigt es), ob der Server einen Push kennt (Nr. 16).

## Prüfung der 5 stärksten gegen den Code (05.11.2026)

Gelesen: `server/verbindungen.js`, `server/index.js` (`zusammenfassungSauber`, `filtern`, `verlaufSauber`, `einheitenSauber`), `GymPartnerLogik.swift`, `GymLive.swift`, `GymStartView.swift` (Zeile 220 ff.), `LoveaBrueckeDienst.swift`, `ZusammenfassungBauer.swift`, `PartnerAnsichtsDaten.swift`, `KontoDienst.swift`, `KontoVerbindungen.swift`, `FreigabeStufe.swift`.

Zwei Befunde gelten für alles, was "live" wirkt:
- **Abruf nur beim Start und beim Vordergrund** (`KontoDienst` ruft `verbindungenAbgleichen` aus dem Anmelde-Ablauf, `.vordergrund` in `VerbindenModul`). Es gibt keinen Takt. "Partner ist im Gym" kommt also nur, wenn man die App öffnet, und nur für den Lovea-Platz (`PartnerEreignisRegeln` bekommt nur `verbindung.partner`). QR-Freunde lösen heute keine Mitteilung aus.
- **Hochladen mit Pause 120 s** (`partnerPause`, `partnerSenden`). Pro fertigem Satz geht `bruecke.schreibe()` los, aber der Server sieht den Stand erst nach bis zu 2 Minuten (es sei denn `hochladenFreigeben()` setzt die Sperre zurück).

| Nr | Aufwand stimmt? | Fallen |
|---|---|---|
| 1 Crew-Liste | Ja, klein bis mittel. `GET /verbindungen` liefert für jede aktive Person schon `daten` (gefiltert), `GymPartnerLogik.status` nimmt eine `ZusammenfassungDatei`. Neu: Schleife über `umgebung.konto.verbindungen.personen`, die Lovea-Person nicht doppelt (`lovea`-Flag), Zeile je Person. | (a) Veraltete Daten: `status` sagt "noch nicht" oder "nicht im Gym" auch bei Daten von vor 3 Tagen. Besser "zuletzt vor X" nach `geschrieben`. (b) Pause von einer der zwei Seiten macht `daten` leer (`erlaubteBereiche`): Zeile dann "pausiert" statt "nicht freigegeben". (c) `daten == nil` oder nur Schritte freigegeben: Person weglassen. (d) Name ist `profilName`, vom Gegenüber frei gewählt: Länge und Umbruch (`lineLimit(1)` reicht nicht bei 6 Personen, Zeilen untereinander statt `HStack`). |
| 2 Stufe "Crew" | Ja, klein (`FreigabeStufe` um einen Fall, `bereiche` = gym, plan, verlauf). Server ändert sich nicht. | `allCases` treibt den Picker und `FreigabeStufe.von`: Tests in `FreigabenTests` und `VerbindungenLogikTests` anpassen. Der hochgeladene Stand ist die Vereinigung aller Verbindungen (`teilen`); der Server filtert je Leser nach, das bleibt der Schutz. Text im Picker muss sagen: "Sätze und Gewichte der letzten Einheiten" (verlauf + gym zeigt Gewichte, nicht nur Zahl). Standard bleibt "Wenig". |
| 3 Live-Rangliste | Ja, klein, kein Server. Aber: Volumen und Sätze nur mit `gym` + `verlauf` (Stufe "Wenig" liefert nur `gymTageWoche`, `gymTage`, `gymZiel`). Rangliste darum nach Gym-Tagen, Sätze und Volumen nur für Personen mit Crew-Stufe. | `gymTageWoche` stammt vom Tag des Hochladens (`heute.tag`): eine Datei von letzter Woche würde als diese Woche zählen. Immer gegen `Datum.wochenstart` prüfen und alte Zeilen ausgrauen. Server begrenzt `gymTage` auf 7 Einträge, `einheiten` auf `MAX_EINHEITEN`. Kein Körpergewicht, nie auf `koerper` zugreifen. Rangliste mit 2 bis 3 Personen: nur Zeilen, kein Podium. |
| 4 Respekt | Falsch eingeschätzt: nicht "mittel mit Tabelle", sondern kleiner, wenn man es richtig baut. Die Verbindungs-`id` kennen beide Seiten (`eintrag.id`). Respekt kann als Feld `respekt: [{v: verbindungsId, ref: ereignisId oder Tag}]` im **eigenen** Stand liegen. Der Server (`datenFuer` kennt die Zeile) gibt dem Leser nur Einträge mit seiner `v` zurück. Keine neue Tabelle. | Ohne diesen Filter sähen alle Verbindungen, wem man Respekt gibt (Datenschutz). Pause und Entfernen müssen es abschalten (`erlaubt` leer: Feld weg). Ankunft wieder nur beim nächsten Öffnen (kein Push). Maximal 20 Einträge, `ref` höchstens 80 Zeichen, Feld in `zusammenfassungSauber` sauber begrenzen. Mittel, 1 Server-Deploy. |
| 5 Rekord-Pinnwand | Anders und einfacher als geplant: `Ereignis.satzFertig(session, rekord)` trägt weder Übung noch Wert, und `App/Ereignis.swift` gehört dem Grundgerüst. Dafür nicht nötig: der Rekord lässt sich beim Empfänger aus `verlauf.einheiten` (bis 30, mit Sätzen) berechnen: bester Satz je Übung in der letzten Einheit gegen alle früheren. Kein Server, kein neues Ereignisfeld. | Nur mit `gym` + `verlauf`. Übungsnamen sind Freitext (40 Zeichen, `kurz`): zwei Leute schreiben "Bankdrücken" und "Bankdrücken (Langhantel)" verschieden. Nur gleiche Schreibweise vergleichen. Gewicht ist in Zehnteln kg (`kg` = 1200 heißt 120,0). Aufwärmsätze (`typ == "w"`) und Drop-Sätze (`"d"`) nie zählen. Der alte `rekord`-Text ("hat einen neuen Rekord") bleibt für Lovea unverändert. |

Gesamt: Nr. 1, 2, 3 stimmen, Nr. 5 wird einfacher (lokal berechnet), Nr. 4 braucht den Leser-Filter, sonst ein Datenschutzloch.

## Welle 2

Fehlt in Welle 1: alles, was im Satz-Moment selbst wirkt. Bewertung Wirkung/Aufwand (1 bis 5, Wirkung durch Aufwand).

| Nr | Idee | Was | Aufwand und Datenweg | Wirkung | W/A |
|---|---|---|---|---|---|
| 21 | Mitlauf-Zeile | In der Crew-Zeile einer Person, die gerade im Gym ist: "Karim: Bankdrücken, Satz 3 · 80 kg × 8 · vor 1 min". Wer selbst trainiert, sieht sie auch im Trainingsbildschirm oben (eine Zeile, antippbar). | Mittel. Daten sind da: `verlauf.imGym` plus `einheiten` mit `tag == heute` enthält die abgehakten Sätze der laufenden Einheit (`PartnerAnsichtsDaten.einheit` zählt `ok == true`). Fehlt: Hochladen schneller (Pause 120 s auf etwa 20 s, solange `imGym`) und Abruf während des Trainings alle 30 s (`verbindungenNeuLaden`, nur sichtbar und nur wenn jemand `imGym`). Pure Logik `letzterSatz`. Zeitangabe nach `geschrieben`, nicht Satzzeit (die Zusammenfassung hat keine). | 5 | 4 |
| 22 | Ziel-Satz ("Schlag meinen Satz") | In der Übung: bei "Letztes Mal" ein Knopf "Satz von Karim schlagen" (sein bester Satz dieser Übung aus `einheiten`). Gemerkt nur lokal. Schafft man mehr (kg oder Wdh bei gleichem Gewicht), kommt eine lokale Feier. Karim erfährt nichts. | Klein bis mittel, kein Server. Logik `ZielSatzLogik` (Vergleich, Normalisierung des Übungsnamens), Speicher in den Einstellungen des Profils (optionales Feld, `decodeIfPresent`, Fall in `AlteDateienLadenTests`). | 4 | 3 |
| 23 | Rekord-Glückwunsch | Auf einer Rekord-Zeile der Pinnwand (Nr. 5) ein Daumen. Beim anderen erscheint "Ahmed gratuliert" an dieser Zeile. | Mittel, wie Nr. 4: Feld `respekt` im eigenen Stand, Server filtert auf die Verbindungs-`id` des Lesers. Ersetzt Nr. 4 als Bauplan. Nur feste Zeichen. | 4 | 3 |
| 24 | Gleiche Übung | Starte ich eine Übung und eine Person ist gerade bei derselben (aus Nr. 21): kleiner Hinweis "Karim ist gerade bei Beinpresse". Nutzen: Gerät teilen, zusammen Sätze machen. | Klein, setzt Nr. 21 voraus. Vergleich nur über genormten Übungsnamen. | 3 | 4 |
| 25 | Heute zusammen (Abschluss) | Nach dem Beenden: eine Karte "Du und Karim heute": Dauer, Sätze, Gesamtgewicht nebeneinander, Haken "beide da". Nur lokal. | Klein, kein Server: aus der eigenen Einheit und der heutigen `einheit` der Person. Nur wenn beide am selben Tag trainiert haben und `gym` + `verlauf` frei sind. | 3 | 3 |
| 26 | Zuwachs der Woche | Pinnwand-Zeile nicht nur Rekord, sondern "+5 kg seit 4 Wochen" bei Hauptübungen. | Klein, aus `einheiten`. Hängt an Namensnormalisierung. | 2 | 2 |

Nicht aufgenommen, weil unnötig oder gefährlich: Spotter-Ruf und alles, was ohne Push nur beim Öffnen ankäme; Chat; Nachricht an Fremde. "Gemeinsames Wochenziel der Crew" steht schon als Nr. 8 (klein, aus `gymTage` und `gymZiel`) und braucht hier nichts Neues.

## Bau jetzt

Ein Agent, ein Tag, nur CI. Reihenfolge so, dass jedes Teil einzeln grün sein kann. Neue Dateien im Modul Gym (Zeile, Logik) und Verbinden (Stufe); Eingriffe in `Konto/` (Takt, Pause) und `App/` melden statt ändern, falls sie dem Grundgerüst gehören, sonst kleinster Diff. Kein neuer Server-Weg, keine neue Tabelle, kein Deploy.

### 1. Gym-Crew mit Stufe "Crew" (Nr. 1 und Nr. 2)

- **Logik** `Module/Gym/GymCrewLogik.swift` (enum, `static func`): `zeilen(einträge: [VerbindungEintrag], datum:, heute:, jetzt:) -> [CrewZeile]`. `CrewZeile` (Sendable): `id`, `name` (`profilName`), `status` (aus `GymPartnerLogik.status`), `zustand` (`imGym`, `heuteDa`, `geplant`, `noch`, `veraltet`, `pausiert`). Regeln: Lovea-Person nur einmal; Person ohne `daten` oder ohne `gym`/`verlauf`/`plan` weglassen; `ich.pause` oder `daten == nil` mit Pause gibt "pausiert"; `geschrieben` älter als 48 h gibt "zuletzt vor X Tagen" statt "noch nicht"; sortiert: im Gym, heute da, geplant, Rest.
- **Stufe** `FreigabeStufe`: dritter Fall `crew` (Name "Crew", Bereiche `gym`, `plan`, `verlauf`). Hilfetext in `FreigabeAuswahl`: "Training, Plan und Gewichte der letzten Einheiten. Nie Schlaf, Essen, Körper."
- **Oberfläche** `GymStartView.werZeile`: `HStack` durch `VStack` mit einer Zeile je Person (vorhandenes `person(...)`), höchstens 6 sichtbar, dann "+ n". Der Menüpunkt "Plan von X" bleibt für die Lovea-Person.
- **Tests** `GymCrewLogikTests` (Lovea nicht doppelt, Pause, veraltet, Reihenfolge, leer, Namen mit Umlauten), `FreigabenTests` (drei Stufen, `von` erkennt Crew, Standard bleibt Wenig), `typnamen-doppelt.sh`, `namen-gate.sh`.
- **Erfolgskriterium:** CI grün; mit `-lumenFitDemo` zeigt der Gym-Tab zwei bis drei Demo-Personen in der richtigen Reihenfolge; ohne Verbindung sieht der Tab aus wie vorher (Screenshot-Test oder Snapshot ungeprüft bis Gerät).

### 2. Mitlauf-Zeile (Nr. 21, baut auf 1)

- **Logik** `GymMitlaufLogik.letzterSatz(datei, jetzt) -> MitlaufSatz?` (`uebung`, `satzNr`, `kg`, `wdh`, `vorSekunden`): nur wenn `verlauf.imGym == true` (und `imGymSeit` jünger als `TrainingLogik.langNach`) und eine `einheit` mit `tag == heute` Sätze hat; letzte Übung mit Sätzen, letzter Satz ohne `typ == "w"`; `kg` aus Zehnteln; `vorSekunden` aus `datei.geschrieben`. Ohne `gym` + `verlauf`: nil (keine Zeile, kein Platzhalter).
- **Tempo:** Hochladen: in `KontoDienst.partnerSenden` die Pause auf 20 s, solange der gebaute Stand `imGym` ist (kleinster Diff: `partnerPause` als Funktion des Standes). Abruf: im Gym-Tab und im Trainingsbildschirm `.task` mit Schleife alle 30 s `umgebung.konto.verbindungenNeuLaden()`, nur wenn mindestens eine Person `imGym` ist und die Ansicht sichtbar ist; bei Reduce Motion oder Stromsparmodus 60 s. Beendet sich mit der Ansicht (Task-Abbruch), keine Hintergrund-Schleife.
- **Oberfläche:** in der Crew-Zeile unter dem Namen eine zweite Zeile "Bankdrücken · Satz 3 · 80 kg × 8 · vor 1 min", kein Auto-Scroll, keine Animation. Im Trainingsbildschirm eine Zeile oben, wenn jemand `imGym` ist.
- **Tests** `GymMitlaufLogikTests` (läuft, läuft nicht, Aufwärmsatz überspringen, `imGym` zu alt, keine Freigabe, kg-Zehntel, mehrere Übungen), `KontoDienst`-Test für die kürzere Pause nur bei `imGym`.
- **Erfolgskriterium:** CI grün; im Test sieht Person B nach `satzFertig` von A innerhalb von 20 s plus 30 s Abruf den Satz; ohne Freigabe `verlauf` erscheint nichts. Ehrlich: "fast live" (bis etwa 50 s), nicht live. Echte Wirkung am Gerät ungeprüft.

### 3. Rekord-Pinnwand mit Übung und Wert (Nr. 5, lokal berechnet)

- **Logik** `GymRekordPinnwandLogik.rekorde(datei, jetzt) -> [PinnwandRekord]` (`name`, `uebung`, `kg`, `wdh`, `tag`): je Übung aus `verlauf.einheiten` den besten Arbeitssatz (ohne `w`, `d`) der letzten 14 Tage gegen alle früheren Einheiten der Person; Rekord, wenn geschätztes 1RM höher als jeder frühere Wert (Formel aus `RekordLogik.swift` wiederverwenden, dort nachsehen). Übungsname normalisiert (klein, ohne Klammerzusatz, getrimmt). Erste Einheit einer Übung ist kein Rekord. Höchstens 5 Zeilen.
- **Oberfläche:** Abschnitt "Rekorde der Crew" unter den Crew-Zeilen, nur wenn nicht leer: "Karim · Kniebeuge 120 kg × 5 · vor 2 Tagen". Ohne Freigabe `gym` + `verlauf` nichts.
- **Tests** `GymRekordPinnwandLogikTests` (Rekord erkannt, erster Satz kein Rekord, Aufwärmsatz, Namen mit Klammer, Zehntel-kg, älter als 14 Tage, leer).
- **Erfolgskriterium:** CI grün; im Demo-Fixture steht mindestens ein Rekord mit Übung und Wert; kein Name einer echten Person im Git (`namen-gate.sh` sauber).

**Danach (Vorrat, nicht heute):** Nr. 3 Rangliste, Nr. 8 Wochenziel, Nr. 4 und 23 (Respekt über Leser-Filter, ein Server-Deploy), Nr. 22 Ziel-Satz.

Ungeprüft: Wie ruhig `GymStartView` mit 4 bis 6 Personen aussieht (Gerät), ob der 20-Sekunden-Upload bei schlechtem Netz stapelt (`partnerAusstehend` hält nur den letzten Stand, also nein), und ob `Konto/` einem anderen Modul gehört (SPEC Abschnitt 12 nicht gelesen).
