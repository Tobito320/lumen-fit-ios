# Lumen Fit Umbau 1 (Build 18): ein Theme, drei Tabs, Profil mit Kalender – Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lumen Fit bekommt Hevys Aufbau (Startseite, Training, Profil ganz rechts), ein Theme hell/dunkel, einen Kalender mit geplanten Tagen und Partner, und verliert die Lovea-Farbwelt, toten Code und die Nicht-Gym-Karten der Startseite, ohne dass eine Funktion vor ihrer Ankunft woanders verschwindet.

**Architecture:** Datenkern, Stores und Server bleiben unverändert; nur Ansichten, Tabs, Theme und Logik-Dateien ändern sich. Jede Aufgabe läuft in einem eigenen Worktree auf einem Zweig von `build-18`, wird mit `swift-kompilieren` geprüft und von der Sitzung lumenfit gemergt; Tests laufen im CI-Fenster. Löschen heißt: Datei, Tests, Einträge in `project.yml` (falls Pfad genannt) und Soll-Liste in einem Commit.

**Tech Stack:** Swift 6 strikt, SwiftUI, iOS 26, XCTest, XcodeGen (`project.yml`), Skripte `scripts/check-schnell.sh`, `swift-kompilieren`.

**Spec:** `docs/superpowers/specs/2026-11-09-lumen-fit-hevy-design.md`

## Global Constraints

- `CONSTRAINTS.md` gilt: 0 Warnungen, keine `try!`, kein `fatalError`, keine Personennamen oder Orte in Code, Tests, Commits (`bash scripts/namen-gate.sh`), Typnamen eindeutig (`bash scripts/typnamen-doppelt.sh`), keine Swift-Pakete.
- Gespeicherte Typen (`Einstellungen`, `ThemaID`, `Op`-Rümpfe) bleiben lesbar: Enum-Fälle nie entfernen, nur Verhalten ändern; jede Änderung an einem gespeicherten Typ bekommt einen Fall in `AlteDateienLadenTests`.
- Nichts entfernen, was die Spec nicht als "weg" nennt. Essen und Schlaf bleiben erreichbar (Dashboard-Kacheln), bis Build 20.
- Oberflächentexte Deutsch mit Umlauten, Bezeichner ASCII, keine Emojis. Tippflächen 44 pt, jedes Symbol ohne Text hat ein Label.
- Vor jedem Commit `swift-syntax-check <Dateien>` und `bash scripts/check-schnell.sh`; vor jedem Push `swift-kompilieren` (Exit 0). Kein Merge in `main`, kein TestFlight durch Arbeiter.
- Commits kurz auf Deutsch mit den vom System vorgegebenen Co-Authored-By- und Claude-Session-Zeilen.

## Review Focus

1. Alte Profile mit gespeicherter Farbwelt (`thema: "wald"`, `"lovea"`) starten mit dem einen Theme ohne Absturz und ohne Rücksetzen anderer Einstellungen (Test in Aufgabe 1).
2. Ein Deep Link oder Widget öffnet `.essen`, `.schlaf`, `.gym(.plaene)` oder `.profil(...)`: landet auf dem richtigen Tab und der richtigen Seite, nie im Leeren (Test in Aufgabe 4).
3. Kalender an Monatsgrenzen, am heutigen Tag (trainiert und geplant zugleich) und ohne Partner (Test in Aufgabe 6).
4. Ein laufendes Training beim Tab-Umbau: Training-Tab zeigt es weiter, Live-Aktivität und Intents funktionieren (RauchTests, Aufgabe 4).
5. Startseite ohne Health-Rechte, ohne Plan und ohne Partner zeigt Leerzustände mit genau einem Knopf, keine leere Fläche (Test in Aufgabe 7).

---

### Task 1: Ein Theme hell/dunkel

**Files:**
- Modify: `Gemeinsam/Design/Farben.swift` (`LumenFarben.tokens`), `Gemeinsam/Design/Theme.swift`, `LumenFit/Sources/Module/Profil/AussehenView.swift`, `LumenFit/Sources/Module/Profil/ProfilThemaWahl.swift`
- Delete: `Gemeinsam/Design/Muster.swift` und die drei Aufrufer von `MusterFlaeche`/`lumenMuster` (grep `MusterFlaeche\|lumenMuster` in `LumenFit/Sources`, `Gemeinsam`): Hintergrund wird einfarbig `palette.grund`
- Test: `LumenFit/Tests/Grundgeruest/FarbenKontrastTests.swift`, `LumenFit/Tests/Grundgeruest/AlteDateienLadenTests.swift`

**Interfaces:**
- Produces: `LumenFarben.tokens(thema: ThemaID, dunkel: Bool) -> Tokens` liefert für JEDES `thema` dieselbe Zeile: hell `(0xFFFFFF, 0xF2F2F7, 0x000000, 0x5E5E62, 0x8A8A8E, 0xE5E5EA, 0x0B5ED7, 0xFFFFFF)`, dunkel `(0x000000, 0x1C1C1E, 0xFFFFFF, 0x98989F, 0x8E8E93, 0x2C2C2E, 0x5B9DFF, 0x0B0C0E)`. `ThemaID` behält alle Fälle (gespeicherte Werte), `ProfilThemaWahl.wirksam` gibt immer `.schlicht` zurück.

- [ ] **Step 1: Failing Tests** in `FarbenKontrastTests`: `testAlleThemenHabenDieselbePalette()` (für alle `ThemaID.allCases`: `tokens(thema:dunkel:)` gleich den beiden Zeilen oben) und bestehende Kontrastprüfung (Text 4,5:1, Bedienelemente 3,0:1) über die zwei Zeilen; in `AlteDateienLadenTests`: `testAlteFarbweltLaedtMitEinemTheme()` (Datei `einstellungen.json` mit `"thema":"wald","erscheinung":"dunkel"` lädt, `ProfilThemaWahl.wirksam(.wald, loveaErlaubt: true) == .schlicht`, `erscheinung == .dunkel` bleibt).
- [ ] **Step 2:** `swift-syntax-check` der Tests, dann Umsetzung: `tokens` auf die zwei Zeilen reduzieren (Kommentar mit Ahmeds Satz "Ein theme. Dark/white. Kein wählbarer Theme."), `Muster.swift` löschen, Aufrufer auf `palette.grund`, `AussehenView` behält nur den Picker "Erscheinung" (System, Hell, Dunkel), `ProfilThemaWahl.waehle` entfällt (Aufrufer prüfen), `wirksam` → `.schlicht`; `python3 -I docs/research/kontrast.py` auf die zwei Zeilen.
- [ ] **Step 3:** `swift-syntax-check` aller geänderten Dateien, `bash scripts/check-schnell.sh`, Commit `Ein Theme hell/dunkel nach System, Farbwelten und Muster raus (Ahmed 09.11.)`.

### Task 2: Lovea-Farbwelt als zweite Oberfläche raus

**Files:**
- Delete: `LumenFit/Sources/Design/LumenAufbau.swift`, `LumenFit/Sources/Module/Gym/{TrainingLoveaAufbau,TageLoveaAufbau,PlanLoveaAufbau,PlanLoveaEditor,PlanLoveaSplits,TrainingLoveaBeenden,UebungLoveaGif,RechnerBlatt,Rechner,BeendenAblauf}.swift`, `LumenFit/Sources/Module/Fortschritt/{KoerperLoveaAufbau,VerlaufLoveaAufbau}.swift`, `LumenFit/Sources/Module/Heute/HeuteLoveaAufbau.swift`; Tests `LumenFit/Tests/Module/Gym/{PlanLoveaTests,TageLoveaLogikTests,BeendenAblaufTests,AufwaermRechnerTests,ScheibenRechnerTests,SupersatzTests,TrainingNotizTests}.swift`, `LumenFit/Tests/Module/Fortschritt/{KoerperLoveaLogikTests,VerlaufLoveaAufbauTests}.swift`
- Modify: alle 41 Dateien mit `lumenAufbau` oder `LumenAufbau` (grep): Zweig `aufbau == .lovea` entfernen, Lumen-Zweig bleibt; `LumenFit/Sources/Module/Gym/GymSeite.swift` (`wahl(bereich:laeuft:)` ohne `aufbau`, Fall `loveaLauf` weg), `GymTabView.swift`, `GymStartView.swift` (Lovea-Menü, `werZeile`, `verlegenKarte`, `uebungenUndSplit`, `cardioKnoepfe`, `einstellungenKnopf` nur, wo Lumen sie nicht nutzt), `GymSitzung.swift` (`aufwaermen`, `supersatz`, `pauseZiel`, `notiz`, `satzStarten`/`satzLauf` NUR wenn kein Aufrufer außer Lovea bleibt; `naechsterSatzStarten` bleibt für die Live-Aktivität), `AppRootView.swift:32` (Environment-Zeile weg), `SatzVorhersageAnzeige.swift` (Farbe ohne `aufbau`)
- Test: `LumenFit/Tests/Module/Gym/GymSeiteTests.swift`, `GymSitzungTests.swift` (Tests zu Supersatz/Notiz/Pause je Übung entfernen, Rest unverändert grün)

**Interfaces:**
- Produces: `GymSeite.wahl(bereich: GymBereich, laeuft: Bool) -> GymSeite` mit Fällen `start, lauf, plan, fortschritt`.

- [ ] **Step 1:** `GymSeiteTests` auf die neue Signatur umschreiben (zwei Fälle: `laeuft` → `.lauf`, sonst `.start`); `swift-syntax-check`.
- [ ] **Step 2:** Dateien löschen, dann `grep -rn "lumenAufbau\|LumenAufbau\|aufbau == \.lovea\|loveaLauf" LumenFit Gemeinsam` muss leer sein; Zweige entfernen, nicht Funktionen umbenennen. `SupersatzLogik` und `PauseLogik.nach` bleiben (alte Pläne tragen `supersatz`), nur die Setter in `GymSitzung` gehen.
- [ ] **Step 3:** `swift-syntax-check` aller Dateien, `bash scripts/check-schnell.sh --alle`, `cd <worktree> && swift-kompilieren` (Exit 0, sonst Fehler beheben), Commit `Lovea-Farbwelt als zweite Oberfläche raus, eine Oberfläche (Ahmed 09.11.)`.
- [ ] **Step 4:** Soll-Liste im Vault: Zeilen "Nur Farbwelt Lovea" und "Farbwelt Lovea" unter "Bewusst gestrichen 09.11." mit Zitat "Weg, eine Oberfläche".

### Task 3: Toter Code und TipKit raus

**Files:**
- Delete: `LumenFit/Sources/Module/Gym/{StudioKarte,StudioProfil,StudioOeffnung,StudioSuche,StudioSucheApple,DefektKarte,DefektLogik,GeraeteEinstellung,GeraeteEinstellungKarten,GymTipps}.swift`; Tests `LumenFit/Tests/Module/Gym/{StudioTests,StudioSucheTests,DefektTests,GeraeteEinstellungTests,GymTippTests}.swift`
- Modify: `GymSitzung.swift` (`studios`, `geraeteStores`, `defektStores`, `speicherNeuLaden`, `studio`, `geraete`, `defekte` weg; `cardioPuls` bleibt), `AppRootView.swift:128` (`speicherNeuLaden` Aufruf weg), die 4 Dateien mit `.gymTipp(` (Modifier entfernen), `LumenFit/Sources/Module/Gym/EinstellHinweise.swift` bleibt (liest "So geht's" in `UebungDetailView`), `project.yml` nur falls eine gelöschte Datei dort steht; `NSLocationWhenInUseUsageDescription` in `project.yml` bleibt bis Build 19 (Review entscheidet).
- Test: `RauchTests` grün; `GymSitzungTests` grün.

- [ ] **Step 1:** Löschen, `grep -rn "StudioStore\|GeraeteStore\|DefektStore\|gymTipp\|GymTipps" LumenFit` leer; `swift-syntax-check`, `check-schnell`.
- [ ] **Step 2:** `swift-kompilieren` Exit 0, Commit `Toter Code raus: Studio, Geräte-Einstellung, Defekte, TipKit (Ahmed 04.11. und 09.11.)`.

### Task 4: Drei Tabs wie Hevy

**Files:**
- Modify: `LumenFit/Sources/App/LumenFitTab.swift`, `LumenFit/Sources/App/Router.swift`, `LumenFit/Sources/App/RouteAnsicht.swift`, `LumenFit/Sources/App/AppRootView.swift` (`TabsAnsicht`), `LumenFit/Sources/Design/AvatarKapsel.swift` (nur noch im Profil-Kopf; die 5 Toolbar-Aufrufe in Heute, Training, Plan, Essen, Schlaf entfernen)
- Test: `LumenFit/Tests/Grundgeruest/BereicheTests.swift`, `RouteURLTests.swift`, `RauchTests.swift`

**Interfaces:**
- Produces: `enum LumenFitTab: String, CaseIterable { case start, training, profil }` mit `titel` ("Startseite", "Training", "Profil") und `symbolName` ("house.fill", "dumbbell.fill", "person.fill"); `static func fuer(_ route: Route) -> LumenFitTab`: `.heute, .gewichtEintragen, .verlauf → .start`; `.gym(_), .uebung → .training`; `.essen, .schlaf, .profil, .freund → .profil`. `Router.zeigt(_ tab:)` gibt für die drei Tabs immer `true`; `Router.zeigt(_ route:)` prüft Essen und Schlaf weiter über `einstellungen.wirksam(schlafSichtbar:)`. `RouteAnsicht.wurzel(.profil)` ist `ProfilTabView()` (Aufgabe 5).

- [ ] **Step 1: Failing Tests:** `BereicheTests.testDreiTabsImmerSichtbar()` (für jede Einstellung `router.zeigt(tab) == true` für alle drei), `RouteURLTests.testRoutenLandenAufDemRichtigenTab()` (`LumenFitTab.fuer(.essen(.heute)) == .profil`, `.gym(.plaene) == .training`, `.profil(.ziele) == .profil`, `.heute == .start`), `RauchTests` (App mit laufendem Training startet, Tab Training zeigt `TrainingLaufView`).
- [ ] **Step 2:** Umsetzen. `Router.oeffne(_ route:)`: `.essen(.heute)` → `wechsle(.profil, [route])`, `.schlaf(.letzteNacht)` → `wechsle(.profil, [route])`, `.gym(.plaene)/.gym(.fortschritt)` → `wechsle(.training, [route])`, `.profil(_)` → `wechsle(.profil, [])` bzw. Unterseite als Pfad. `TabView` bleibt die System-Leiste (iOS 26, `.tabBarMinimizeBehavior(.onScrollDown)`), Tint ist der Akzent aus Aufgabe 1.
- [ ] **Step 3:** `swift-syntax-check`, `check-schnell`, `swift-kompilieren` Exit 0, Commit `Drei Tabs wie Hevy: Startseite, Training, Profil (Ahmed 09.11.)`.

### Task 5: Profil-Tab mit Zahlen, Diagramm, Dashboard und Workouts

**Files:**
- Create: `LumenFit/Sources/Module/Profil/ProfilTabView.swift`, `LumenFit/Sources/Module/Profil/ProfilStatistikLogik.swift`, `LumenFit/Sources/Module/Profil/ProfilStatistikKarte.swift`, `LumenFit/Sources/Module/Profil/ProfilDashboard.swift`
- Modify: `LumenFit/Sources/Module/Profil/ProfilBlattView.swift` (wird das Blatt hinter dem Zahnrad, ohne Zeile "Aussehen"-Farbwelt; "Aussehen" bleibt mit Erscheinung), `LumenFit/Sources/Module/Gym/TrainingVerlaufView.swift` (als Liste unter "Workouts" einbettbar: `init(eingebettet: Bool = false)` ohne eigenen Titel)
- Test: `LumenFit/Tests/Module/Profil/ProfilStatistikLogikTests.swift`

**Interfaces:**
- Produces: `enum StatistikArt: CaseIterable { case dauer, volumen, wiederholungen }` mit `titel` ("Dauer", "Volumen", "Wiederholungen"); `struct WochenWert: Equatable { var montag: String; var wert: Double }`; `enum ProfilStatistikLogik { static func wochen(_ sessions: [GymSession], heute: String, art: StatistikArt, anzahl: Int = 8) -> [WochenWert] }` (älteste Woche zuerst, Dauer in Minuten aus `ende - start`, Volumen = Summe `kg × wdh` über Sätze mit `zaehlt`, Wiederholungen = Summe `wdh` über Sätze mit `zaehlt`; Wochen ohne Training mit `wert 0`). Dashboard-Kacheln: `ProfilDashboard` zeigt `NavigationLink`s: Statistiken → `VerlaufView()`, Übungen → `UebungsSucheView(titel: "Übungen")`, Messungen → `MessungenView()`, Kalender → `KalenderView()` (Aufgabe 6); zusätzlich, solange vorhanden: Essen → `EssenTabView()` (nur `bereicheWirksam.essenAn`), Schlaf → `SchlafTabView()` (nur `konto.schlafSichtbar`), Freunde → `VerbindungenView()`.

- [ ] **Step 1: Failing Tests** `testWochenLiefernAchtWochenAeltesteZuerstMitNullen()`, `testVolumenUndWiederholungenZaehlenNurAbgehakteSaetzeOhneAufwaermen()`, `testDauerInMinutenAusStartUndEnde()` mit `GymSession`-Fixtures (erfundene runde Werte).
- [ ] **Step 2:** Logik und Ansichten bauen: Kopf (Name groß, rechts Zahnrad öffnet `ProfilBlattView` als Sheet mit "Fertig"), Zeile mit Zahlen "Workouts" (`training.sessions.count`) und "Freunde" (`konto.verbindungen` aktive Zahl), `ProfilStatistikKarte` (Swift Charts `Chart` mit `BarMark`, Picker segmentiert über `StatistikArt`), `ProfilDashboard` (2 Spalten, Kacheln 44 pt+ mit Symbol und Titel), Abschnitt "Workouts" mit `TrainingVerlaufView(eingebettet: true)`, Zeile "Schritte heute" (nur mit Health-Daten, Wert aus `gesundheit.tage`). Bausteine `ListenKarte`, `HeroKarte`, `Pille` nutzen.
- [ ] **Step 3:** `swift-syntax-check`, `check-schnell`, `swift-kompilieren` Exit 0, Commit `Profil-Tab wie Hevy: Zahlen, Diagramm, Dashboard, Workouts`.

### Task 6: Kalender mit geplanten Tagen und Partner

**Files:**
- Create: `LumenFit/Sources/Module/Fortschritt/KalenderLogik.swift`, `LumenFit/Sources/Module/Fortschritt/KalenderView.swift`
- Test: `LumenFit/Tests/Module/Fortschritt/KalenderLogikTests.swift`

**Interfaces:**
- Produces: `struct KalenderTag: Equatable, Identifiable { var datum: String; var id: String { datum }; var trainiert: Bool; var geplant: String?; var partnerTrainiert: Bool; var partnerGeplant: Bool; var heute: Bool; var imMonat: Bool }`; `enum KalenderLogik { static func tage(monat: String, sessions: [GymSession], plan: TrainingsPlan, partnerTage: [String], partnerPlan: PartnerPlan?, heute: String) -> [KalenderTag] }` (`monat` als `yyyy-MM`; Raster beginnt am Montag der Woche des 1., endet am Sonntag der Woche des Letzten, `imMonat` markiert Fremdtage; `trainiert` = eine Einheit mit `Datum.text(start) == datum`; `geplant` nur für `datum >= heute`: `TrainingLogik.tag(plan, datum:)?.name`; `partnerTrainiert` = `partnerTage.contains(datum)`; `partnerGeplant` nur für `datum >= heute`: ein Tag in `partnerPlan.tage` enthält `Datum.wochentag(datum)`); `static func monatText(_ monat: String) -> String` ("November 2026"), `static func naechster(_ monat: String, schritt: Int) -> String`. Partnerquelle: `umgebung.daten?.verbindung.partner`: bei `.verbunden(let d)` oder `.veraltet(let d)` ist `partnerTage = d.heute.gymTage ?? []`, `partnerPlan = d.heute.plan`; sonst leer.

- [ ] **Step 1: Failing Tests** `testVergangeneTageZeigenTrainiertNieGeplant()`, `testKommendeTageZeigenDenPlantagNachWochentag()`, `testHeuteKannTrainiertUndGeplantSein()`, `testPartnerTageUndPartnerPlanWerdenMarkiert()`, `testRasterBeginntMontagUndEndetSonntagMitFremdtagen()` (Monat 2026-11: erster Rastertag 2026-10-26, letzter 2026-12-06), `testOhnePartnerKeineMarken()`.
- [ ] **Step 2:** Logik, dann Ansicht: Kopf mit Pfeilen und `monatText`, Wochentagszeile Mo–So, `LazyVGrid` mit 7 Spalten, Tag als Kreis: gefüllt (trainiert), Umriss (geplant), kleiner zweiter Punkt unten in zweiter Farbe (Partner trainiert gefüllt, geplant Umriss), heute mit Ring; Legende "Du · Partner"; Tipp auf einen Tag zeigt unter dem Raster die Einheit (`EinheitNachlesenView` für die Session dieses Tages) oder "Geplant: <Name>" oder "Ruhetag". VoiceOver je Tag: "9. November, trainiert, Partner geplant".
- [ ] **Step 3:** `swift-syntax-check`, `check-schnell`, `swift-kompilieren` Exit 0, Commit `Kalender im Profil: Trainings, geplante Tage nach vorn und Partner (Ahmed 09.11.)`.

### Task 7: Startseite kompakt

**Files:**
- Modify: `LumenFit/Sources/Module/Heute/HeuteTabView.swift` (Titel "Startseite"; Inhalt in dieser Reihenfolge: `PlanKarte`, `WochenStreifen`, neue `LetzteEinheitKarte`, `HabitsKarte`, `GewichtKarte`, `PartnerKarte(.heute)` bis Build 19; Tagleiste und Tagwahl bleiben), `LumenFit/Sources/Module/Heute/HeuteModell.swift` (Tagesform, Energie, Einsichten, Hinweise, Schritte-Detail nicht mehr rechnen)
- Create: `LumenFit/Sources/Module/Heute/LetzteEinheitKarte.swift` (letzte beendete Einheit: Name, Datum, Dauer, Sätze, Tipp öffnet `EinheitNachlesenView`)
- Delete: `LumenFit/Sources/Module/Heute/{TagesformRechnung,TagesformKlartext,TagesformQuellen,TagesFormen,EnergieBank,EinsichtenKarte,HinweiseKarte,HeuteHinweise,SchritteKarte,SchritteDetailView,Ringplatte*}.swift` samt Tests (Namen per grep), `HeuteLeerKarte` nur, wenn kein Aufrufer bleibt
- Test: `LumenFit/Tests/Module/Heute/HeuteModellTests.swift` (anpassen), neuer `LetzteEinheitKarteTests` nur für die Logik "letzte beendete Einheit" (`static func letzte(_ sessions: [GymSession]) -> GymSession?`)

**Interfaces:**
- Consumes: `GesundheitsStand.tage` bleibt (Schritte-Zeile im Profil, Widgets), `WochenStreifen(woche:bereiche:)` bleibt.
- Produces: `HeuteStand` ohne `energie`, `einsichten`, `hinweise`; `Route.verlauf` und `Route.gewichtEintragen` bleiben.

- [ ] **Step 1: Failing Test** `LetzteEinheitKarteTests.testLetzteBeendeteEinheitNeuesteZuerstOhneLaufende()`.
- [ ] **Step 2:** Umsetzen und löschen; `grep -rn "Tagesform\|EnergieBank\|EinsichtenKarte\|HinweiseKarte\|SchritteKarte" LumenFit` leer (außer Widgets-Snapshot, der nur Schritte-Zahlen liest). Leerzustände: ohne Plan `LeerZustand(... "Split wählen")`, ohne Einheit "Noch kein Training".
- [ ] **Step 3:** `swift-syntax-check`, `check-schnell`, `swift-kompilieren` Exit 0, Commit `Startseite kompakt: Heute-Karte, Woche, letzte Einheit, Gewohnheiten, Gewicht (Ahmed 09.11.)`.

### Task 8: Soll-Liste, Spec und Testliste

**Files:**
- Modify: Vault `19 Bastelprojekte/Lumen Fit – Wissen/Funktionen – was da ist.md` (Abschnitte App insgesamt, Heute → Startseite, Profil; "Bewusst gestrichen 09.11." mit Zitaten), `SPEC.md` Abschnitt 3 (Tabs) und 6 (Design: ein Theme), `CLAUDE.md` (Tabs, Theme), `~/.claude/buero-stand/lumenfit-testliste-10-11.md` (höchstens 7 Punkte in Ahmeds Worten)

- [ ] **Step 1:** Soll-Liste gegen den Code abgleichen (jede Zeile der betroffenen Abschnitte prüfen, nichts fehlt, was nicht gestrichen ist).
- [ ] **Step 2:** Commit der Doku im Repo, Vault-Commit.

## Reihenfolge und Merge
Aufgaben 1, 2, 3 nacheinander (jede ändert viele Dateien), dann 4 → 5 → 6 → 7 (bauen aufeinander auf), 8 zuletzt. Die Sitzung lumenfit mergt jeden Zweig nach `build-18`, kompiliert einmal gesamt, dann CI-Fenster und ein TestFlight-Build.
