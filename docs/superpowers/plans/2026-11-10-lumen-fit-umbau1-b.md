# Lumen Fit Umbau 1, Teil 2 (Build 18): Aufteilung B, Fortschritt stark, Sicherungen – Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lumen Fit bekommt die vom Besitzer gewählte Aufteilung B (Startseite, Training, Fortschritt, Freunde, Profil ganz rechts) im Design von Entwurf 3, eine starke Fortschritt-Seite, einen Kalender mit Partner, und schließt die Lücken aus dem Ship-Review von Build 17.

**Ersetzt** die Aufgaben 4 bis 8 in `docs/superpowers/plans/2026-11-09-lumen-fit-hevy-umbau1.md` (die gingen von drei Tabs aus). Aufgaben 1 bis 3 dort sind erledigt und in `build-18` (d41924c).

**Architecture:** Datenkern, gespeicherte Typen und Stores bleiben; neu sind Ansichten, reine Logik-`enum`s und das Tab-Gerüst. Jede Aufgabe läuft in einem eigenen Worktree auf einem Zweig von `build-18`, wird mit `swift-kompilieren` geprüft und von der Sitzung lumenfit gemergt; Tests laufen im CI-Fenster.

**Tech Stack:** Swift 6 strikt, SwiftUI, iOS 26, Swift Charts, XCTest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-09-lumen-fit-hevy-design.md`. **Bildvorlage:** Vault `19 Bastelprojekte/Lumen Fit/hevy-entwurf-v3.html` (Aufteilung B, Hell und Dunkel), Bilder `~/.claude/buero-stand/entwurf-v3/*.png` (die `a-…`-Bilder sind Aufteilung A und gelten nicht).

## Global Constraints

- Alles aus dem Kopf von `2026-11-09-lumen-fit-hevy-umbau1.md` gilt weiter (CONSTRAINTS.md, Namens-Gate, keine Personennamen in Code/Tests/Commits, Typnamen eindeutig, gespeicherte Typen lesbar, 44 pt, Labels, `swift-kompilieren` vor jedem Push, kein Merge in `main`).
- Entscheidungen des Besitzers (09./10.11.2026): Aufteilung B; Essen und Schlaf bis zum Umzug als zwei Zeilen oben im Profil; auf der Startseite keine Freunde und keine Partner-Punkte; Fortschritt ist die stärkste Seite; Verlauf wie Hevy; Live-Aktivität mit "Satz fertig" bleibt; nichts entfernen ohne sein Wort.
- Doppelt anbieten ist verboten: jede Funktion hat genau einen Ort (Medaillen nur im Fortschritt, Statistik nur im Fortschritt, Einstellungen nur im Profil).
- Seiten, die der Besitzer nicht ausdrücklich gestrichen hat, bleiben erreichbar: Rückblick, Konstanz, FitPassport, Lumi, Muskelkarte (Silhouette), Erholung, Nächstes Training wandern im Fortschritt nach unten unter "Mehr".

## Review Focus

1. Altes `-lumenFitTab plan|essen|schlaf` oder ein Deep Link `.gym(.plaene)`, `.essen(...)`, `.schlaf(...)`, `.gym(.fortschritt)` landet auf dem richtigen neuen Tab mit der richtigen Seite, nie im Leeren (Aufgabe 4).
2. Ein laufendes Training beim Tab-Umbau: Training-Tab zeigt es, Mini-Leiste "Training läuft" auf anderen Tabs, Live-Aktivität und Intents gehen (RauchTests, Aufgabe 4).
3. Konto ohne Essen/Schlaf-Freigabe sieht im Profil keine leeren Zeilen; Konto mit beiden sieht beide (Aufgabe 4).
4. Fortschritt ohne Training, mit genau einer Einheit und über Monats- und Jahresgrenzen (KW 52/1) zeigt Leerzustände bzw. richtige Wochen (Aufgabe 5).
5. Wert getippt, sofort Tab gewechselt und Handy gesperrt: der Wert ist nach Neustart da (Aufgabe 8).

---

### Task 4: Tab-Gerüst B, Profil als Tab, Essen/Schlaf-Zeilen, Freunde-Tab

**Files:**
- Modify: `LumenFit/Sources/App/LumenFitTab.swift`, `Router.swift`, `RouteAnsicht.swift`, `AppRootView.swift` (`TabsAnsicht`), `StartArgumente.swift`, `LumenFit/Sources/Design/AvatarKapsel.swift` (Toolbar-Aufrufe in Heute, Gym, Essen, Schlaf entfernen, das Profil ist jetzt ein Tab), `LumenFit/Sources/Module/Profil/ProfilBlattView.swift` (wird Wurzel des Profil-Tabs, kein Sheet mehr, kein "Fertig"), `LumenFit/Sources/Module/Gym/GymTabView.swift` (Umschalter Pläne | Fortschritt weg: Training zeigt `GymStartView`, Plan ist eine Unterseite)
- Create: `LumenFit/Sources/Module/Profil/ProfilUmzugZeilen.swift` (zwei Zeilen Essen und Schlaf)
- Test: `LumenFit/Tests/Grundgeruest/BereicheTests.swift`, `RouteURLTests.swift`, `RauchTests.swift`, `StartArgumenteTests.swift` (falls vorhanden, sonst in `RouteURLTests`)

**Interfaces:**
- Produces: `enum LumenFitTab: String, CaseIterable { case heute, training, fortschritt, freunde, profil }` (Rohwert `heute` bleibt, Titel "Startseite"); `titel` "Startseite", "Training", "Fortschritt", "Freunde", "Profil"; `symbolName` "house.fill", "dumbbell.fill", "chart.xyaxis.line", "person.2.fill", "person.crop.circle.fill". Alle fünf Tabs immer sichtbar.
- `static func fuer(_ route: Route) -> LumenFitTab`: `.heute, .gewichtEintragen → .heute`; `.gym(.training), .gym(.plaene), .uebung → .training`; `.gym(.fortschritt), .verlauf → .fortschritt`; `.freund, .verbindungen → .freunde`; `.essen, .schlaf, .profil → .profil`.
- `StartArgumente`: `-lumenFitTab` akzeptiert die neuen Werte; alte Werte: `plan → training`, `gym → training`, `essen|schlaf → profil` (Test).
- `ProfilUmzugZeilen`: Zeile "Essen" (nur `umgebung.bereicheWirksam.essenAn`), Untertitel "Zieht bald zu Lovea um" nur wenn `umgebung.konto.loveaErlaubt`, sonst Untertitel leer; Zeile "Schlaf" (nur `umgebung.konto.schlafSichtbar`), Untertitel "Zieht bald zu Lumen Alarm um". Tipp pusht `EssenTabView()` bzw. `SchlafTabView()` im Profil-Stapel. Beide Zeilen oben im Profil, über Konto.
- Freunde-Tab Wurzel: `FreundeTabView()` (neu, im Ordner `LumenFit/Sources/Module/Verbinden/`): zeigt die heutigen Bausteine untereinander: `PartnerKarte(bereich: .gym)`, `GymCrewAbschnitt()`, `GymRekordPinnwandView()`, Zeile "Verbindungen" → `VerbindungenView()`. Diese Bausteine verschwinden dafür aus `GymStartView` (sonst doppelt). Ersetzt fitfreunde ihn mit fit-crew, tauscht die Sitzung lumenfit nur diese eine Wurzel.
- Mini-Leiste "Training läuft · 23:14 · Weiter" über der Tab-Leiste auf allen Tabs außer Training, solange `GymSitzung.von(umgebung)?.sessionId != nil` (vorhandene Anzeige wiederverwenden, falls es eine gibt; sonst neu in `AppRootView`).

- [ ] **Step 1: Failing Tests:** `testFuenfTabsImmerSichtbar()`, `testRoutenLandenAufDemRichtigenTab()` (je Zeile oben eine Assertion), `testAlteStartArgumenteLandenImNeuenTab()` (`plan → .training`, `essen → .profil`), `testEssenZeileNurMitEssenUndSchlafZeileNurMitFreigabe()`, RauchTest "laufendes Training: Tab Training zeigt `TrainingLaufView`".
- [ ] **Step 2:** Umsetzen. `TabView` mit System-Leiste (iOS 26), Tint = Akzent.
- [ ] **Step 3:** `swift-syntax-check`, `check-schnell`, `swift-kompilieren` Exit 0, Commit `Tabs Startseite, Training, Fortschritt, Freunde, Profil (Wunsch vom 09.11.2026)`.

### Task 5: Fortschritt als stärkste Seite

**Files:**
- Create: `LumenFit/Sources/Module/Fortschritt/FortschrittLogik.swift`, `FortschrittTabView.swift`, `WieGehtsKarte.swift`, `GewichteListe.swift`, `EinheitenKarte.swift`, `VerlaufNachWochen.swift`
- Modify: `LumenFit/Sources/Module/Fortschritt/FortschrittSegmentView.swift` (wird zum Abschnitt "Mehr" unten in `FortschrittTabView`: Konstanz, Rückblick, Muskelkarte, Lumi, FitPassport, Nächstes Training bleiben als Zeilen; die Medaillen-Zeile wandert nach oben)
- Test: `LumenFit/Tests/Module/Fortschritt/FortschrittLogikTests.swift`

**Interfaces:**
- Produces: `struct WochenVergleich: Equatable { var einheiten: Int; var einheitenSchnitt: Double; var volumen: Double; var volumenSchnitt: Double; var saetze: Int; var saetzeSchnitt: Double; var gestiegen: Int; var hauptuebungen: Int }`; `enum FortschrittLogik { static func vergleich(_ sessions: [GymSession], plan: TrainingsPlan, heute: String) -> WochenVergleich` (diese Woche Mo bis heute gegen den Schnitt der 4 Wochen davor; Volumen = Σ kg × wdh abgehakter Arbeitssätze ohne Aufwärmen; `hauptuebungen` = Übungen im Plan mit mindestens einer Einheit in den letzten 8 Wochen; `gestiegen` = davon die, deren schwerster Satz der letzten 4 Wochen über dem der 4 Wochen davor liegt); `static func gewichte(_ sessions: [GymSession], plan: TrainingsPlan, heute: String) -> [GewichtZeile]` mit `struct GewichtZeile: Equatable, Identifiable { var uebungId: String; var name: String; var muskel: String; var wochen: [Double?] /* 8 Werte, älteste zuerst, schwerster Satz je Woche */; var aktuell: Double; var aenderung4Wochen: Double; var id: String { uebungId } }`, Reihenfolge wie im Plan; `static func wochen(_ sessions: [GymSession], heute: String, art: StatistikArt, anzahl: Int = 8) -> [WochenWert]` mit `enum StatistikArt: CaseIterable { case dauer, volumen, wiederholungen }` und `struct WochenWert: Equatable { var montag: String; var wert: Double }` (Wochen ohne Training mit 0); `static func nachWochen(_ sessions: [GymSession], heute: String) -> [(titel: String, sessions: [GymSession])]` mit Titeln "Diese Woche", "Letzte Woche", sonst "KW 44" (ISO-Woche), neueste zuerst, nur beendete Einheiten.
- Satz unter "Wie geht's dir": `"\(gestiegen) von \(hauptuebungen) Hauptübungen sind gestiegen."`, ohne Hauptübungen kein Satz; läuft die Woche noch und es sind Trainings geplant: Zusatz "Die Woche läuft noch, \(n) Trainings sind geplant."
- Seite in dieser Reihenfolge (Bild `fortschritt-*.png`): Wie geht's dir · Gewichte (Tipp → vorhandene Übungsdetailseite über `.uebung`) · Sätze je Muskel (`SaetzeProMuskelKarte` unverändert) · Einheiten (Swift Charts `BarMark`, Umschalter Dauer/Volumen/Wiederholungen als Pillen, darunter `VerlaufNachWochen`, Tipp → `EinheitNachlesenView`) · Körper (`GewichtVerlaufKarte`, Zeile Messungen) · Medaillen (eine Zeile, Tipp → `MeilensteineView`) · Mehr (Zeilen aus `FortschrittSegmentView`).

- [ ] **Step 1: Failing Tests:** `testVergleichDieseWocheGegenVierWochenSchnitt()`, `testGestiegenZaehltNurPlanuebungenMitHoeheremSchwerstemSatz()`, `testAufwaermsaetzeZaehlenNichtInsVolumen()`, `testWochenLiefernAchtWochenAeltesteZuerstMitNullen()`, `testNachWochenTitelUndJahreswechselKW52NachKW1()`, `testOhneTrainingLeereListenUndKeinSatz()`. Erfundene runde Werte, `TestUhr`.
- [ ] **Step 2:** Logik, dann Ansichten mit `HeroKarte`, `ListenKarte`, `Pille`, `LeerZustand`, `DiagrammKarte`. Linie je Gewichtszeile als kleines `Chart` mit `LineMark` (64 × 28 pt, ohne Achsen, `accessibilityLabel` "Brustpresse, 32,5 Kilo, plus 5 seit 4 Wochen").
- [ ] **Step 3:** Prüfungen, Commit `Fortschritt: wie geht's dir, Gewichte, Einheiten, Verlauf nach Wochen (Wunsch vom 09.11.2026)`.

### Task 6: Kalender mit geplanten Tagen und Partner

Unverändert wie Task 6 in `2026-11-09-lumen-fit-hevy-umbau1.md` (Dateien, `KalenderLogik`, Tests), mit einer Änderung: der Kalender ist eine Unterseite des Training-Tabs (Zeile "Kalender" in Task 7), nicht des Profils. Commit `Kalender im Training: Trainings, geplante Tage nach vorn und Partner (Wunsch vom 09.11.2026)`.

### Task 7: Training-Tab und Startseite

**Files:**
- Modify: `LumenFit/Sources/Module/Gym/GymStartView.swift` (Reihenfolge wie Bild `training-*.png`: großer Knopf "Training starten", Zeile "Ohne Plan starten", Woche mit Partner-Punkten, "Heute: <Tag>" mit Übungsliste, dann Zeilen "Plan" → `PlanView`, "Kalender" → `KalenderView`, "Übungen" → `UebungsSucheView(titel: "Übungen")`; "Mehr" mit Verlegen, Cardio, Nachtragen, Einstellungen bleibt), `LumenFit/Sources/Module/Heute/HeuteTabView.swift` (Titel "Startseite"; Reihenfolge wie Bild `home-*.png`: Heute-Karte mit Start, Woche ohne Partner, Gewohnheiten, Gewicht, `LetzteEinheitKarte`; `PartnerKarte(.heute)` weg, Tagesform, Energie, Einsichten, Hinweise, Schritte-Detail nicht mehr auf der Startseite)
- Create: `LumenFit/Sources/Module/Heute/LetzteEinheitKarte.swift` (Name, Wochentag und Datum, Dauer, Volumen, Sätze, Rekorde, darunter je Übung "3 × Name" und bester Satz; Tipp → `EinheitNachlesenView`)
- Löschen erst nach Wort des Besitzers: Dateien von Tagesform, Energie-Bank, Einsichten, Hinweise bleiben im Code und werden nur nicht mehr angezeigt; die Liste kommt in den Abschlussbericht.
- Test: `LetzteEinheitKarteTests.testLetzteBeendeteEinheitNeuesteZuerstOhneLaufende()`, `testZeilenJeUebungMitBestemSatz()`.

- [ ] Steps wie oben (Test, Umsetzen, Prüfungen), Commit `Training-Tab mit Plan, Kalender, Übungen; Startseite kompakt mit letztem Training (Wunsch vom 09.11.2026)`.

### Task 8: Sicherungen aus dem Ship-Review von Build 17

**Files:**
- Modify: `LumenFit/Sources/Module/Gym/GymSitzung.swift`, `LumenFit/Sources/App/AppUmgebung.swift` (`fuehreAbrufAus`), `server/index.js` (`loveaOpsSenden`), `server/postfach.js` (`planPruefen`)
- Test: `LumenFit/Tests/Module/Gym/GymSitzungTests.swift`, `LumenFit/Tests/App/HealthLieferungTests.swift` (Pfad per grep), `LumenFit/Tests/Fixtures/Gym/gym-lauf-stand.jsonl` + `AlteDateienLadenGymLaufTests.swift`, `server/index.test.js`, `server/postfach.test.js` (falls vorhanden)

**Interfaces und Regeln:**
- `GymSitzung` schreibt offene Entwürfe selbst, unabhängig von der sichtbaren Ansicht: Beobachter auf `UIApplication.willResignActiveNotification` und `didEnterBackgroundNotification` ruft `entwurfSenden()` (Beobachter einmal je Instanz, `nonisolated` Rückruf hüpft per `MainActor.assumeIsolated` oder `Task { @MainActor in }`); `entwurfVerzug` bleibt 1,5 s, neu `nonisolated static let entwurfHoechstens: TimeInterval = 5` (spätestens 5 s nach dem ersten offenen Tipp wird geschrieben, auch bei Dauertippen); `zuruecksetzen()` und der Wechsel-Zweig von `ladeWennNoetig()` rufen erst `entwurfSenden()`, dann leeren. Der Aufruf in `TrainingLaufView` bleibt (doppelt schreiben ist harmlos, `sende` entfernt die id).
- `fuehreAbrufAus`: läuft schon ein Abruf, merkt eine zweite Lieferung `nochmal = true` und quittiert erst, wenn der Nachlauf fertig ist (Muster wie `GesundheitsStand`).
- Server `loveaOpsSenden`: Body höchstens 256 KB; je Op `id` höchstens 80 Zeichen, `JSON.stringify(d)` höchstens 4 KB, `Date.parse(zeit)` endlich und höchstens jetzt + 1 Tag; bei `art === "einstellung.setzen"` nur `d.schluessel` mit Präfix `ziel.` und Zahl als `wert`; sonst 400 mit Grund.
- `planPruefen`: doppelte Übungs-`id` innerhalb eines Tages → 400.

- [ ] **Step 1: Failing Tests:** `testHintergrundSchreibtEntwurfOhneAnsicht()` (Notification posten, ohne `entwurfAufgabe` abzuwarten Op auf Platte), `testDauerTippenSchreibtSpaetestensNachFuenfSekunden()` (Verzug injizierbar oder `TestUhr`), `testBeendenMitStehenderUhrBehaeltEntwurfUndEnde()` (keine `uhr.vor`, Werte und `ende` nach Neuladen da), `testEntwurfUeberlebtZuruecksetzen()`, `testAbgerissenerLetzterEintragUeberlebtDasUpdate()` (Fixture-Kopie mit abgerissener letzter Zeile ohne Zeilenende: laufende Einheit und Haken da, neuer Haken hängt sauber an), `testZweiteLieferungWaehrendAbrufWirdNachgeholt()`; Server: `Essen-Export: zu großes d, Zukunftszeit, fremder Schlüssel -> 400`, `Plan mit doppelter Übungs-id -> 400`.
- [ ] **Step 2:** Umsetzen.
- [ ] **Step 3:** `cd server && npm test` grün, Swift-Prüfungen, Commit `Sicherungen: Entwurf auch ohne Ansicht und spätestens nach 5 s, Health-Nachlauf, Server prüft Export und Plan-ids`.

### Task 9: Soll-Liste, Spec, Testliste

- Modify: Vault `19 Bastelprojekte/Lumen Fit – Wissen/Funktionen – was da ist.md` (Tabs, Profil, Fortschritt, Startseite; nichts fehlt, was nicht gestrichen ist), `SPEC.md` Abschnitt 3 (Tabs) und 6 (ein Theme), `CLAUDE.md` (Tabs, Theme, Bausteine ohne `MusterFlaeche`), `~/.claude/buero-stand/lumenfit-testliste-<tt-mm>.md` (höchstens 7 Punkte in den Worten des Besitzers).

## Reihenfolge und Merge
Parallel in eigenen Worktrees: Task 4 (Gerüst), Task 5 (Fortschritt, nur neue Dateien plus `FortschrittSegmentView`), Task 6 (Kalender, nur neue Dateien), Task 8 (Sicherungen). Danach Task 7 auf dem Stand mit 4 und 6. Die Sitzung lumenfit mergt nach `build-18` in der Reihenfolge 8, 4, 6, 5, 7, hängt `FortschrittTabView` und `KalenderView` ein, kompiliert gesamt, dann Task 9, CI-Fenster und ein TestFlight-Build.
