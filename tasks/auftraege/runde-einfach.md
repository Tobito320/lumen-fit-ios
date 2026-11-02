# Auftrag: Runde "Weniger und stabiler" (02.11.2026)

Ahmeds Worte: "Coach sollte nicht angezeigt werden für alle außer [die zwei Lovea-Konten]." und "Keine unnötigen neuen sachen rein bitte. Nur das bestehende stabiler minimaler und schneller zu nutzen und nutzungsfreundlicher machen".

Ziel: Die Punkte unten sind auf einem Zweig gebaut, getestet und einzeln committet. Es kommt keine neue Funktion dazu.
Prüfung: Tests, `bash scripts/check-schnell.sh`, am Ende einmal CI durch die Integration.
Grenzen: nichts senden, nichts kaufen, Lovea-Repo nur lesen, keine neuen Entitlements, keine Swift-Pakete, keine neuen gespeicherten Typen außer wo unten genannt.

## Gemeinsame Regeln für jeden Arbeiter

- Erst `CLAUDE.md` und `CONSTRAINTS.md` lesen. Test zuerst für jede Logik. Kleinster korrekter Diff. Im Zweifel weniger.
- Kein Swift lokal: `swift-syntax-check <Dateien>`, `bash scripts/check-schnell.sh`, `bash scripts/namen-gate.sh`; Server: `npm test` in `server/`. Kein Push, kein CI, kein Deploy, kein TestFlight.
- Gespeicherte Daten dürfen nie verschwinden. Neue Felder optional oder `decodeIfPresent`, Fall in `AlteDateienLadenTests`.
- Keine Personennamen in Code, Kommentaren, Tests, Commit-Texten. Commit-Texte kurz auf Deutsch mit den vorgegebenen Attributionszeilen.
- Nur die Punkte des eigenen Pakets. Muss eine fremde Datei mit, kleinster Eingriff und im Bericht nennen.
- Gelöschte Tests nur zu gelöschter Oberfläche, Begründung im Commit-Text. Logik mit portierten Lovea-Tests bleibt.
- Bericht: Zweig, Commits, geänderte Dateien, neue Tests, was ungeprüft ist (nur der Compiler oder ein Gerät beweist es), Abweichungen vom Auftrag.

## Paket A: Konto, Sichtbarkeit, Wahrheit in Texten

1. Coach nur für die zwei Lovea-Konten. Coach bleibt im Code. Server: `coachSichtbar` in `GET /config`, berechnet wie `loveaVerbinden` nur aus `PERSONEN.includes(konto.lovea_person)`, weder global noch je Konto überschreibbar. `/ki/coach` antwortet anderen Konten mit `nichtErlaubt`, auch wenn `kiCoachErlaubt` global an ist. App: `ServerConfig.coachSichtbar`, Standard false (ohne Server-Antwort kein Coach, gemerkter Stand gilt, damit ein Funkloch den Coach der zwei Konten nicht wegnimmt). Ohne Sichtbarkeit nirgends Coach: Tab-Leiste, Heute-Kachel (beide Aufbauten), "Coach erklärt es" im Schlaf, Sicherheitszeile, Links und Route `.coach` (führen auf Heute, auch ein gemerkter Tab), Texte in Onboarding und Datenschutz, die den Coach nennen.
2. Zähler-Schalter: In "Datenschutz" ein Schalter "Nutzung anonym zählen" (Standard an); aus = es geht kein Zähler raus. Text nennt ihn. Geräteanmeldung bleibt, weil Server-Schalter daran hängen.
3. Zyklus-Oberfläche raus: `LumenFit/Sources/Module/Zyklus` entfernen, soweit es Oberfläche ist; Logik und Daten in `Gemeinsam` und importierte Log-Einträge bleiben. Alter Link führt weiter auf Heute. `NSFaceIDUsageDescription` raus.
4. Berechtigungen ohne Nutzen raus: `NSMotionUsageDescription`, Health-Leserecht Stehen samt Zeile in "Was Lumen Fit liest" (Zahl 15 anpassen).
5. Health-Begründung `NSHealthUpdateUsageDescription` sagt nur noch Training und Gewicht.
6. Freigabe "Training und Verlauf" sagt die Wahrheit, kein neuer Schalter: "Ob du im Gym bist und deine letzten zehn Trainings. Zusammen mit Gym auch Sätze und Gewichte." (`Gemeinsam/Modelle/Verbindungen.swift`). Vorschau "Das sieht ..." muss dazu passen.
7. `stimmungWoche` wird nicht mehr hochgeladen; Text der Freigabe "Stimmung" nennt nur heute.
8. Band-Labor nur im Debug-Bau (`#if DEBUG`, auch die Zeile dorthin).
9. Tote Ansichten raus: `ProfilGruppenKopf`, `ProfilThemaVorschau`.

## Paket B: Doppeltes raus, Fehler beheben

1. Eine Tageszahl: Bereit-Score-Karte fällt weg, Energie-Bank bleibt (beide Aufbauten). Lumis Satz, "Heute locker" und Hinweise funktionieren weiter; Logik mit portierten Tests bleibt, wenn sie intern gebraucht wird. Coach-Eingabe nicht ändern.
2. Konstanz-Raster und Reiter "Plan" im Verlauf raus; Verlauf behält Woche und Verlauf.
3. Gewicht und Maße einheitlich: ein Ort in `Gemeinsam` für Grenzen und Maß-Arten, überall 30 bis 249,9 kg und dieselben Maße: Körperfett, Taille, Hüfte, Brust, Schulter, Oberarm/Bizeps, Oberschenkel. Betrifft Heute, Essen-Körperwerte, Messungen. Alte Werte außerhalb der Grenzen bleiben sichtbar. Bizeps und Oberarm sind ein Maß; Bestand beider bleibt lesbar, nichts wird doppelt angezeigt.
4. Coach-Einstellungen sagen die Wahrheit: "Wer antwortet" kennt den Server-Coach, der Datenschutztext unterscheidet beide Wege.
5. Coach-Suche: Treffer aus älteren Tagen öffnen den Tag im Verlauf.
6. Live Essen merkt "weggewischt" je Tag über den Neustart.
7. Tote Ansichten raus: `CoachWeg`, `EssenEintragZeile`.

## Bewusst nicht in dieser Runde (Ahmed: keine neuen Sachen)

Kalorienbedarf, Deload, Fortschrittsfotos, Einkaufsliste, Ramadan-Plan, Wiederholungsbereich, Satz-Uhr im Lumen-Aufbau, HRV vom Band, KI-Foto-Gedächtnis, Mahlzeiten nach Health, eigener Schalter für Sätze, Coach-Eintragen per Marker.
