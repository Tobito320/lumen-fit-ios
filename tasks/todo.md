# Aufgabenliste: Lumen Fit

Checkliste nach `tasks/plan.md`. "Blockiert von" sind die Kanten (Matt Pocock to-tickets): eine Aufgabe startet erst, wenn alle Blocker erledigt sind. Aufgaben ohne Blocker sind sofort startbar. Jede der 100 Ideen hat eine eigene Zeile unter ihrem Ticket; sie wird erst abgehakt, wenn sie eingebaut ist und ihr Test in CI grün ist. Die Zeilen unter den Modulen entstehen aus `docs/ideas/lumen-fit.md`; Ordner und Aufträge stehen in `tasks/auftraege/<id>.md`. Planung (Phase 0) ist mit dem Commit "Spec, Ideen, Plan" erledigt.

## Phase 0: Planung

- [x] Recherche: Vorbilder, Datenquellen, Design, Konfiguration (`docs/research/`)
- [x] `SPEC.md`, `CONTEXT.md`, `CONSTRAINTS.md`, `AGENTS.md`/`CLAUDE.md`, `docs/ideas/lumen-fit.md`, `tasks/plan.md`, `tasks/todo.md`, `tasks/auftraege/*`

## Phase 1: Grundgerüst (Modul-ID grundgeruest, Auftrag `tasks/auftraege/grundgeruest.md`)

- [x] **G1: Repo-Gerüst und leere App grün**. Blockiert von: keine.
  - Umfang: Vorlagen aus `docs/research/vorlagen` an ihren Platz, `project.yml`, beide Workflows, Skripte, Entitlements, Assets mit Icon ohne Alpha, `PrivateDaten.beispiel.json`; GitHub-Repo privat anlegen; erste grüne CI mit leerer App
- [x] **G2: Datenkern: Datum, Op, Raum, portierte Lovea-Typen und Tests**. Blockiert von: G1.
  - Umfang: Zeit, Daten, Speicher, Modelle und `LokalerOpLog`, `LokalerRaum` mit den Lovea-Tests der Datenkern-Tabelle (SPEC 5.8)
  - [ ] Idee 10: Fehler, die helfen
- [x] **G3: Stores und DatenSatz**. Blockiert von: G2.
  - Umfang: `TrainingStore`, `EssenStore`, `HabitStore`, `MeilensteinStore`, `CoachStore`, `EinstellungenStore`, `ZieleStore`, `VerbindungStore`, `DatenSatz`
- [x] **G4: Konto: Schlüsselbund, Passwort, ProfilStore**. Blockiert von: G1.
  - Umfang: Port `Schluesselbund` mit Keychain und Speicher-Fake, PBKDF2, mehrere Profile, Neuinstallations-Fall
  - [ ] Idee 1: Profil für immer
  - [ ] Idee 2: Mehrere Profile pro Gerät
- [x] **G5: Gesundheit: HealthLeser, GesundheitsStand, HealthSchreiber**. Blockiert von: G2.
  - Umfang: HealthKit hinter dem Port, Fake, 60 Tage beim ersten Mal
  - [ ] Idee 8: Erster Tag schon voll
- [x] **G6: Design-System**. Blockiert von: G1.
  - Umfang: Farben, Themes, Muster, `LumiView`, `LumenBogen`, `LumenBalken`, Feder, Haptik, Bausteine; `FarbenKontrastTests`
  - [ ] Idee 3: Fünf Themes in Hell und Dunkel
  - [ ] Idee 4: Muster in jedem Theme
  - [ ] Idee 5: Lumi, die süße Figur
  - [ ] Idee 6: Lumen-Bögen
  - [ ] Idee 7: Haptik und Federn aus einem Guss
- [x] **G7: App-Hülle, Routen, Stubs, Demo, Widget-Hülle, grüne CI**. Blockiert von: G3, G4, G5, G6.
  - Umfang: `AppUmgebung`, `Router`, `RouteURL`, `RouteAnsicht`, `ModulStart`, Stubs aller Module, Demo-Start-Argumente, Widget-Bundle mit Stub-Widgets, Lovea-Brücke-Dateien (`LoveaBruecke`), Test-Hilfen, Fixtures-Ordner
  - [ ] Idee 9: Jede Seite hat einen Link

### Checkpoint A: Grundgerüst
- [x] CI grün (348 Tests, 0 Fehler, 0 Warnungen), Privat-Check und Namens-Gate sauber, `FarbenKontrastTests` grün
- [x] Jeder Stub aus SPEC 5.9 existiert und ist eingehängt (`RouteAnsicht` kennt jede Route); Tag `grundgeruest-fertig` (lokal, Push mit dem nächsten CI-Fenster)
- [x] Alle portierten Lovea-Tests der Datenkern-Tabelle laufen (Rest je Modul: "VOM GRUNDGERÜST NICHT PORTIERT" in `tasks/auftraege/*.md`)
- [x] Modulaufträge gegen den echten Code geprüft (Typnamen), Zweige `modul/<id>` und Worktrees angelegt (`/home/tobi/projects/lumen-fit-ios-wt/<id>`)

## Phase 2: Module (alle neun parallel, Blockiert von: Checkpoint A)

### Modul heute: Heute-Tab: Ringplatte, Bereit-Score, Plan, Energie, Gewohnheiten, Gewicht, Schritte, Hinweise
Ideen 11 bis 20. Zweig `modul/heute`. Auftrag: `tasks/auftraege/heute.md`. Ordner: `LumenFit/Sources/Module/Heute/`, `LumenFit/Tests/Module/Heute/`, `LumenFit/Tests/Fixtures/Heute/`.

- [ ] **heute H1 Ringplatte, Bereit-Score, Morgensatz, Energie-Bank**. Blockiert von: Checkpoint A.
  - [ ] Idee 11: Ringplatte mit Lumen-Bögen
  - [ ] Idee 12: Bereit-Score
  - [ ] Idee 13: Lumis Morgensatz
  - [ ] Idee 15: Energie-Bank
- [ ] **heute H2 Plan-Karte, Hinweise, Wochenstreifen**. Blockiert von: Checkpoint A.
  - [ ] Idee 14: Plan-Karte mit einem Tipp
  - [ ] Idee 19: Hinweise des Tages
  - [ ] Idee 20: Wochenstreifen
- [ ] **heute H3 Gewohnheiten, Gewicht, Schritte-Detail**. Blockiert von: Checkpoint A.
  - [ ] Idee 16: Gewohnheiten mit Serie
  - [ ] Idee 17: Gewicht in drei Sekunden
  - [ ] Idee 18: Schritte im Detail

### Modul gym: Gym-Tab: Training, Logging, Pausen-Timer, Rekorde, Katalog, Splits, Cardio, Studio
Ideen 21 bis 30. Zweig `modul/gym`. Auftrag: `tasks/auftraege/gym.md`. Ordner: `LumenFit/Sources/Module/Gym/`, `LumenFit/Tests/Module/Gym/`, `LumenFit/Tests/Fixtures/Gym/`.

- [ ] **gym Y1 Satz-Logging, Satztypen, RPE, Pausen-Timer, Live-Rekord**. Blockiert von: Checkpoint A.
  - [ ] Idee 21: Letztes Mal in der Zeile
  - [ ] Idee 22: Satztypen und RPE
  - [ ] Idee 23: Pausen-Timer, der von selbst startet
  - [ ] Idee 24: Rekord sofort
- [ ] **gym Y2 Katalog, Splits und Wochenplan, Supersets und Notizen**. Blockiert von: Checkpoint A.
  - [ ] Idee 26: 1.333 Übungen auf Deutsch
  - [ ] Idee 27: Splits und Wochenplan
  - [ ] Idee 28: Supersets und Notizen
- [ ] **gym Y3 Rechner, Cardio und Studio, Health-Schreiben, TrainingSteuerung**. Blockiert von: Checkpoint A.
  - [ ] Idee 25: Scheiben- und Aufwärmrechner
  - [ ] Idee 29: Cardio und Studio-Besuch
  - [ ] Idee 30: Training nach Health schreiben

### Modul fortschritt: Fortschritt: Kraftkurve, Körperkarte, Raster, Gewicht, Meilensteine, Lumi-Seite, Rückblicke
Ideen 31 bis 40. Zweig `modul/fortschritt`. Auftrag: `tasks/auftraege/fortschritt.md`. Ordner: `LumenFit/Sources/Module/Fortschritt/`, `LumenFit/Tests/Module/Fortschritt/`, `LumenFit/Tests/Fixtures/Fortschritt/`.

- [ ] **fortschritt F1 Kraftkurve, Sätze je Muskel, Konstanz-Raster, Gewichtsverlauf**. Blockiert von: Checkpoint A.
  - [ ] Idee 31: Kraftkurve je Übung
  - [ ] Idee 32: Sätze je Muskel gegen Ziel
  - [ ] Idee 35: Konstanz-Raster
  - [ ] Idee 36: Gewichtsverlauf mit Trend
- [ ] **fortschritt F2 Erholungs-Silhouette, Vorschlag fürs nächste Training**. Blockiert von: Checkpoint A.
  - [ ] Idee 33: Erholungs-Silhouette
  - [ ] Idee 34: Vorschlag fürs nächste Training
- [ ] **fortschritt F3 Meilensteine, Lumi-Stufen, Rückblick, FitPassport**. Blockiert von: Checkpoint A.
  - [ ] Idee 37: Meilensteine und Medaillen
  - [ ] Idee 38: Lumi-Stufen 1 bis 9
  - [ ] Idee 39: Wochen- und Monatsrückblick
  - [ ] Idee 40: FitPassport

### Modul essen: Essen-Tab: Tagebuch, Scan, Quellen, Ampel, Fasten, Ziele, Analyse
Ideen 41 bis 50. Zweig `modul/essen`. Auftrag: `tasks/auftraege/essen.md`. Ordner: `LumenFit/Sources/Module/Essen/`, `LumenFit/Tests/Module/Essen/`, `LumenFit/Tests/Fixtures/Essen/`.

- [ ] **essen E1 Suche, BLS, Tagebuch, Portion, Favoriten, Donut**. Blockiert von: Checkpoint A.
  - [ ] Idee 42: 7.140 Lebensmittel ohne Netz
  - [ ] Idee 43: Makro-Donut ohne Farbe
  - [ ] Idee 45: Favoriten und Zuletzt
  - [ ] Idee 46: Portion-Schieber
- [ ] **essen E2 Barcode-Scan, Open Food Facts, Etikett-Foto**. Blockiert von: Checkpoint A.
  - [ ] Idee 41: Barcode-Scan
  - [ ] Idee 48: Etikett-Foto
- [ ] **essen E3 Ampel, Fasten, Ziele, Wochenanalyse**. Blockiert von: Checkpoint A.
  - [ ] Idee 44: Halal- und Zucker-Ampel
  - [ ] Idee 47: Fasten-Fenster 16:8
  - [ ] Idee 49: Ziele aus deinen Körperdaten
  - [ ] Idee 50: Wochenanalyse Essen

### Modul schlaf: Schlaf-Tab: Nacht, Phasen, Schuld, HRV im eigenen Bereich, Werte, Woche, Quellen
Ideen 51 bis 60. Zweig `modul/schlaf`. Auftrag: `tasks/auftraege/schlaf.md`. Ordner: `LumenFit/Sources/Module/Schlaf/`, `LumenFit/Tests/Module/Schlaf/`, `LumenFit/Tests/Fixtures/Schlaf/`.

- [ ] **schlaf S1 Nacht, Phasen, Woche, Vergleich, Quellenwahl**. Blockiert von: Checkpoint A.
  - [ ] Idee 51: Letzte Nacht groß
  - [ ] Idee 52: Phasen-Balken
  - [ ] Idee 56: Wochenübersicht Schlaf
  - [ ] Idee 59: Wochen im Vergleich
  - [ ] Idee 60: Beste Schlafquelle
- [ ] **schlaf S2 Schuld, Regelmäßigkeit, HRV-Bereich, Werte-Chips, Klartext**. Blockiert von: Checkpoint A.
  - [ ] Idee 53: Schlafschuld über 7 Nächte
  - [ ] Idee 54: HRV im eigenen Bereich
  - [ ] Idee 55: Werte-Chips
  - [ ] Idee 57: Regelmäßigkeit
  - [ ] Idee 58: Erholung in einfacher Sprache

### Modul coach: Coach-Tab: zwei Motoren, Ton, Gedächtnis, Chips, Morgen-Check
Ideen 61 bis 70. Zweig `modul/coach`. Auftrag: `tasks/auftraege/coach.md`. Ordner: `LumenFit/Sources/Module/Coach/`, `LumenFit/Tests/Module/Coach/`, `LumenFit/Tests/Fixtures/Coach/`.

- [ ] **coach C1 Motor-Port, Regelmotor, Ton und Prüfung, Ehrlichkeit**. Blockiert von: Checkpoint A.
  - [ ] Idee 62: Rückfall ohne Apple Intelligence
  - [ ] Idee 63: Ton wie ein Freund
  - [ ] Idee 70: Ehrlich, was er nicht weiß
- [ ] **coach C2 Foundation Models, Kontext und Tools**. Blockiert von: Checkpoint A.
  - [ ] Idee 61: Coach auf dem Gerät
  - [ ] Idee 66: Coach kennt dein Training
- [ ] **coach C3 Gedächtnis, Chips, Schnellfragen, Morgen-Check, Daumen**. Blockiert von: Checkpoint A.
  - [ ] Idee 64: Coach merkt sich Ziele
  - [ ] Idee 65: Chips mit Handlung
  - [ ] Idee 67: Morgen-Check
  - [ ] Idee 68: Schnellfragen nach Tageszeit
  - [ ] Idee 69: Daumen und Merkliste

### Modul profil: Profil: Onboarding, Profil-Blatt, Aussehen, Ziele, Sicherung, Quellen, Datenschutz, Export
Ideen 71 bis 80. Zweig `modul/profil`. Auftrag: `tasks/auftraege/profil.md`. Ordner: `LumenFit/Sources/Module/Profil/`, `LumenFit/Tests/Module/Profil/`, `LumenFit/Tests/Fixtures/Profil/`.

- [ ] **profil P1 Onboarding, Profil-Blatt, Wechsel**. Blockiert von: Checkpoint A.
  - [ ] Idee 71: Einstieg in einer Minute
  - [ ] Idee 72: Profil-Blatt überall
- [ ] **profil P2 Aussehen, Health-Zugriff, Körperdaten, Ziele**. Blockiert von: Checkpoint A.
  - [ ] Idee 73: Aussehen-Seite
  - [ ] Idee 75: Health-Zugriff im Klartext
  - [ ] Idee 76: Körperdaten und Einheiten
  - [ ] Idee 77: Ziele-Seite
- [ ] **profil P3 Datensicherung, Quellen, Datenschutz, Export**. Blockiert von: Checkpoint A.
  - [ ] Idee 74: Datensicherung als Datei
  - [ ] Idee 78: Quellen und Lizenzen
  - [ ] Idee 79: Datenschutz in Klartext
  - [ ] Idee 80: Tabellenexport

### Modul verbinden: Verbinden: Lovea-Brücke, Partner-Karte, Mitteilungen, Band, Freundeskarten
Ideen 81 bis 90. Zweig `modul/verbinden`. Auftrag: `tasks/auftraege/verbinden.md`. Ordner: `LumenFit/Sources/Module/Verbinden/`, `LumenFit/Tests/Module/Verbinden/`, `LumenFit/Tests/Fixtures/Verbinden/`.

- [ ] **verbinden V1 Brücke, Freigaben, Partner-Karte, Mitteilungen**. Blockiert von: Checkpoint A.
  - [ ] Idee 81: Mit Lovea verbinden
  - [ ] Idee 82: Partner-Karte
  - [ ] Idee 83: Mitteilungen bei Partner-Ereignissen
  - [ ] Idee 84: Freigaben je Datenart
- [ ] **verbinden V2 Band: Verbindung, geteilt, Pause, Akku**. Blockiert von: Checkpoint A.
  - [ ] Idee 85: Band verbinden
  - [ ] Idee 86: Band geteilt
  - [ ] Idee 87: Pause am Handgelenk
  - [ ] Idee 88: Band-Akku im Blick
- [ ] **verbinden V3 Freundeskarte und Wochen-Rangliste**. Blockiert von: Checkpoint A.
  - [ ] Idee 89: Freundeskarte
  - [ ] Idee 90: Wochen-Rangliste mit Respekt

### Modul widgets: Widgets: Home- und Sperrbildschirm, Live Activity, Intents, Siri, Spotlight, Steuerelement
Ideen 91 bis 100. Zweig `modul/widgets`. Auftrag: `tasks/auftraege/widgets.md`. Ordner: `LumenFit/Sources/Module/Widgets/`, `LumenFit/Tests/Module/Widgets/`, `LumenFit/Tests/Fixtures/Widgets/`, `LumenFitWidgets/Sources/Widgets/`, `Gemeinsam/Widgets/`.

- [ ] **widgets W1 Snapshot, Widgets Bögen, Plan und Serie, Sperrbildschirm, Essen**. Blockiert von: Checkpoint A.
  - [ ] Idee 91: Widget Bögen
  - [ ] Idee 92: Widget Plan und Serie
  - [ ] Idee 93: Sperrbildschirm-Widgets
  - [ ] Idee 97: Widget Essen
- [ ] **widgets W2 Live Activity, Satz fertig, Gewohnheiten-Widget**. Blockiert von: Checkpoint A.
  - [ ] Idee 94: Live Activity Training
  - [ ] Idee 95: Satz fertig vom Sperrbildschirm
  - [ ] Idee 96: Gewohnheiten zum Abhaken
- [ ] **widgets W3 Siri, Spotlight, Steuerelement**. Blockiert von: Checkpoint A.
  - [ ] Idee 98: Siri und Kurzbefehle
  - [ ] Idee 99: Spotlight
  - [ ] Idee 100: Steuerelement im Kontrollzentrum

### Checkpoint B: je Modul
- [ ] Alle Ideen des Moduls eingebaut oder mit Grund als nicht umsetzbar gemeldet
- [ ] Nur Dateien der eigenen Ordner geändert (`git diff --name-only main...modul/<id>`)
- [ ] `swift-syntax-check` auf allen neuen Dateien OK; Tests geschrieben (Test zuerst); portierte Lovea-Tests liegen bei
- [ ] `bash scripts/check-schnell.sh` sauber (Namens-, Umfang- und Typnamen-Gate); Abschlussbericht mit ungeprüften Punkten liegt vor

## Phase 3: Integration und Auslieferung (Blockiert von: alle Module)

- [ ] **I1 Zusammenführen**. Reihenfolge profil, schlaf, essen, heute, gym, fortschritt, coach, verbinden, widgets auf `main`; vor dem Fenster nach jedem Merge `bash scripts/typnamen-doppelt.sh`, am Ende `bash scripts/check-schnell.sh --alle`; ein öffentliches CI-Fenster für alle (`scripts/ci-fenster.sh`); Kompilierfehler gehen an das Modul zurück.
- [ ] **I2 Qualitäts- und Barrierefreiheits-Durchgang**. `agent-skills:code-review-and-quality`, `code-simplification`, Checkliste aus `tasks/plan.md`; `grep "Kommt bald"` leer. Blockiert von: I1.
- [ ] **I3a PrivateDaten.json und Secret**. Nur wenn das Modul gym Vorgaben nutzt: Datei lokal aus Ahmeds privater Notiz bauen (nie ins Git), `signing/privat-secret.sh`; sonst Streichungen nach `konfiguration.md` 7.3. Blockiert von: G1.
- [ ] **I3 Signierung und Secrets**. `konfiguration.md` Abschnitt 6: Bundle IDs per Skript, Portal-Handarbeit (einmal Apple-Login durch Ahmed als Fernfunk-Aufgabe, danach klickt der Agent), Profile, Secrets, Icon, Tester. Blockiert von: G1 (parallel zu den Modulen möglich).
- [ ] **I4 TestFlight-Build**. `scripts/testflight-fenster.sh`, bei Rot zuerst `gh run view --log-failed`; Repo wieder privat. Blockiert von: I2, I3, I3a.
- [ ] **I5 Ship**. `agent-skills:ship`, Ideen abhaken, Vault-Eintrag, Fernfunk-Aufgabe "Lumen Fit testen" mit der Testliste, Lovea-Folgearbeit als eigener Auftrag vermerken, Hinweis "noch nicht auf dem Handy", bis Ahmed testet. Blockiert von: I4.

### Checkpoint C: Auslieferung
- [ ] CI grün, TestFlight-Build vorhanden, Repo privat
- [ ] Testliste (`tasks/plan.md`) an Ahmed (Fernfunk-Aufgabe)
- [ ] Offene Punkte (Lovea-Runde, Gerätetests) als Aufgaben angelegt
