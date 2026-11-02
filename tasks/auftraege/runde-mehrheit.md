# Auftrag: Runde "Mehrheit" (02.11.2026)

Ahmeds Worte: "Plan mit mir lumen fit ein app für mehrheit zu machen. Sodass es einfach funktioniert und easy to use ist", "Regelmäßig im gym.", "Tabs reihenfolge sollte so bleiben.", "Man sollte auswählen können was man haben möchte, optionen. Essen, schlaf. Wenn man das möchte oder nicht wird dann ausgeblendet und nicht mehr gezeigt", "es fragt auch nicht nach schlaf wenn man das ausgewählt hat aber man kann im settings das noch anpassen später", "wie kann es sein dass ich meine band 24/7 trage und schlaf immernoch falsch getracked wird", "Studio eintragen sollte easy sein, ich schreibe fit und es zeigt schon das näherste von meiner aktuellen Location", "wie kinetic app so milestones/badges haben zu bestimmten bereichen anhand von zielen", "Bau rest".

Ziel: Wer regelmäßig ins Gym geht, startet in unter 2 Minuten das erste Training und sieht nur, was er gewählt hat.
Grenzen: Tab-Reihenfolge bleibt. Lovea-Aufbau bleibt optisch, wie er ist, außer dass ausgeschaltete Bereiche verschwinden. Keine neuen Entitlements, keine Swift-Pakete, Lovea-Repo nur lesen. Nichts wird gelöscht, was gespeicherte Daten betrifft: Ausblenden löscht nie Daten. Keine Studio- oder Personennamen und keine Koordinaten in Git, Tests, Logs.

## Gemeinsame Regeln für jeden Arbeiter

- Erst `CLAUDE.md` und `CONSTRAINTS.md` lesen. Test zuerst für jede Logik. Kleinster korrekter Diff.
- Kein Swift lokal: `swift-syntax-check <Dateien>`, `bash scripts/check-schnell.sh`, `bash scripts/namen-gate.sh`, `bash scripts/typnamen-doppelt.sh`. Kein Push, kein CI, kein Deploy, kein TestFlight.
- Gespeicherte Typen: neue Felder optional oder `decodeIfPresent`, Fall in `AlteDateienLadenTests`.
- Verschieben heißt: Funktion bleibt erreichbar, eine Ebene tiefer unter "Mehr" oder "Details". Keine Funktion verschwindet ohne Auftrag.
- Commit-Texte kurz auf Deutsch mit den vorgegebenen Attributionszeilen, keine Personennamen.
- Nur das eigene Paket. Fremde Datei nur als kleinster Eingriff, im Bericht nennen.
- Bericht: Zweig, Commits, Dateien, Tests, Prüfausgaben, was nur Compiler oder Gerät beweisen, Abweichungen.

## Paket C: Bereiche wählen und erster Start

1. `Einstellungen`: `gymAn`, `essenAn`, `schlafAn`, je Bool, `decodeIfPresent` Standard true, damit Bestandsprofile alles behalten. Mindestens einer bleibt an. Heute bleibt immer; bei ausgeschaltetem Bereich verschwinden Tab, Karten und Einträge dieses Bereichs überall in der App. Tab-Reihenfolge sonst unverändert. Links und gemerkter Tab auf einen ausgeschalteten Bereich führen auf Heute. Daten bleiben.
2. Einstellungen im Profil: Zeile "Bereiche" oben mit drei Schaltern, Erklärung "Ausblenden löscht nichts".
3. Health fragt nur, was gewählt ist: Abfrage und Hintergrundlieferung ohne Schlaf-Typen bei `schlafAn == false`, ohne Gym-Typen bei `gymAn == false`. Einschalten im Profil fragt die fehlenden Rechte. Health-Zugriff-Seite listet nur Aktives.
4. Gemeinsame Abfrage `Einstellungen.zeigt(_:)` oder ähnlich, die andere Pakete nutzen. In Heute, Ringplatte, Wochenstreifen, Hinweisen, Lovea-Kacheln: Ausgeschaltetes weglassen; Ringe zeichnen nur Aktives.
5. Erster Start: Lumi, Name (ohne Passwort), Bereiche, Gym-Tage nur wenn Gym an, Health nur mit gewählten Typen; danach bei Gym an direkt "Geführt erstellen" oder fertigen Split wählen.
6. Passwort freiwillig: neues Profil ohne Passwort. Unter Konto "Passwort festlegen". Ohne Passwort fragen Wechseln und Alles löschen nur nach Bestätigung. Bestehende Profile behalten ihr Passwort. Profil im Schlüsselbund lädt alt und neu; Fall in `AlteDateienLadenTests`.

## Paket D: Gym, Training, Studio, Fortschritt

1. Gym-Start: großer Start-Knopf ganz oben, darunter Wochenleiste und Tageskarte, Letzte Einheiten. "Diese Woche" verlegen, Testwoche, Laufband/Stairmaster, Training nachtragen unter einem Eintrag "Mehr".
2. Training: "Als Nächstes", Pause, Satzzeile mit letztem Mal bleiben. Übungs-Menü oben nur Notiz, Tauschen, Rechner, Auslassen; Rest unter "Mehr". RPE-Standard aus; wer es schon angefasst hat, behält seine Wahl. Blatt "Fertig?" bleibt, Beenden in einem Tipp plus Zusammenfassung.
3. Studio-Suche: Beim Eintragen tippt man Text ("fit"), die App zeigt die nächsten Treffer von der aktuellen Position, nach Entfernung sortiert, mit Name und Entfernung; ein Tipp übernimmt. Technik: MapKit-Suche (`MKLocalSearch` oder Completer) mit Region um die Position, Standort nur auf dem Weg dorthin (`NSLocationWhenInUseUsageDescription`, Frage erst beim Öffnen der Suche). Ohne Erlaubnis oder Netz: Suche ohne Entfernung, freies Textfeld bleibt, nie Sperre. Es wird nur der Name gespeichert, keine Koordinaten; Öffnungszeiten bleiben von Hand und optional, fehlen sie, gibt es keine Warnung. Datenschutztext nennt, dass die Suchanfrage an Apple geht. Port mit Fake, Sortierung und Filter als reine Logik mit Tests, keine echten Studios.
4. Studio und Geräte aus, bis ein Studio eingetragen ist: Studio-Karte, "Meine Einstellung", Defekt und So-geht's-Studio-Bezug erscheinen erst dann; Einstieg unter "Mehr". Für Bestandsprofile mit Studio bleibt alles sichtbar.
5. Fortschritt: Kraftkurve und Sätze je Muskel zuerst, Körperkarte danach. Rückblick, Messungen, Medaillen, Lumi als Wege unten bleiben.

## Paket G: Schlaf vom Band falsch

Fehler suchen, nicht raten (Skill `sp-debugging`). Ahmeds Satz: Band 24/7 getragen, Schlaf wird falsch erfasst; was genau falsch ist, sagt er nicht. Kette vom Bytes-Lesen bis zur Anzeige prüfen, gegen die Implementierung in Lovea (`~/projects/lovea-app-ios`, nur lesen) und Geräte-Beleg im Code. Beheben, was belegt ist, mit Test. Was nur ein Gerät beweist, klar benennen und sagen, welche genaue Beobachtung oder Rohdatenzeile es entscheidet.

## Paket E (nach Paket C): Heute, Essen, Schlaf, Einstellungen

1. Heute: Ringe, Plan für heute, Gewohnheiten, Gewicht, Hinweis nur bei Bedarf. Rest unter "Mehr" (Einsichten, Freitext, Energie-Details, Schritte, Woche), nur normaler Aufbau.
2. Essen: Kalorien und Protein oben, vier Mahlzeiten, Plus, Scan. Unter "Mehr": Körperwerte, Donut, Protein der Woche. Fasten aus, bis eingeschaltet, Schalter in "Tagebuch anpassen"; wer Fasten-Daten hat, behält es an.
3. Schlaf: letzte Nacht, Woche, Erholung; Rest unter "Details".
4. Band nur sichtbar, wenn eingerichtet oder aktiv, sonst eine Zeile "Band einrichten" unter Geräte.
5. Teilen je Person: "Wenig" (Schritte und Gym) oder "Alles"; einzelne Schalter eingeklappt, nichts weg. Vorschau bleibt.
6. Widgets kürzen auf Gym-Woche, Plan und Serie, Bögen; Live Training bleibt. Vorher prüfen, was mit bereits platzierten Widgets passiert, und im Bericht nennen.

## Paket F (nach Paket C): Medaillen je Bereich

Bezug laut Ahmed: "milestones/badges zu bestimmten bereichen anhand von zielen". Die bestehenden 25 Medaillen und IDs bleiben, erreichte gehen nie verloren. Meilensteine-Seite nach Bereich: Gym, Schritte, Schlaf, Essen, Körper; ausgeschaltete Bereiche unsichtbar, Lumi-Stufen zählen weiter. Neue Abzeichen an den eigenen Zielen: Wochenziel Gym 4, 12, 26 Wochen, Schrittziel 7 und 30 Tage, Schlafziel 7 und 30 Nächte, Proteinziel 7 und 30 Tage, Kalorienziel im Rahmen 7 Tage ohne Abnehm-Druck. Stufen Bronze, Silber, Gold statt Einzelkacheln, wo es dieselbe Reihe ist. Jede Karte zeigt Fortschritt. Fehlt das Ziel, erscheint die Medaille nicht. Reine Logik mit Tests, Wächter vergibt nur einmal.
