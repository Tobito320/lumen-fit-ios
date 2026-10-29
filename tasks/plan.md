# Implementierungsplan: Lumen Fit

## Überblick

Lumen Fit ist Loveas Health-Hälfte als eigene, sehr gute App (SPEC.md). Der Bau läuft in drei Phasen: ein Grundgerüst (Datenkern aus Lovea, Konto, Design, Hülle, Stubs), danach neun Module parallel in eigenen Worktrees, danach Integration, Signierung und TestFlight. Es gibt keinen Mac und keinen lokalen Compiler: jeder Compilerfehler kostet einen CI-Lauf. Deshalb wird in kleinen Schritten gebaut, Syntax lokal geprüft und aus Lovea nur portiert, was dort schon Tests hat.

## Architekturentscheidungen

1. Client-only. Kein Konto-Server, kein Push (SPEC Annahmen 2, 8).
2. Datenkern = lokaler Op-Log je Profil mit den Lovea-Faltungen (SPEC 5.3, Annahme 4). Größter Gewinn an "Fertigem", Import aus Lovea später ohne Umbau.
3. Profil und Passwort-Spur im Schlüsselbund hinter einem Port; der Start fragt nie nach dem Passwort (SPEC 5.4).
4. Jede Fremdwelt hinter einem Port mit Fake: Health, Netz, Schlüsselbund, Mitteilungen, Band, Coach-Motor, Lovea-Dateien, Live Activity, Trainings-Steuerung.
5. Lovea-Verbindung als Dateivertrag in `group.com.onlyus.lovea`; Lovea bleibt unverändert (SPEC 5.5).
6. Band opt-in und Standard aus (SPEC 5.6, Annahme 9).
7. Coach mit zwei Motoren: Foundation Models und Regelrückfall (SPEC 5.7).
8. Design: Lumen-Bögen statt Aktivitätsringe, Muster per Canvas, Bewegung nur bei Ereignissen (SPEC 6).
9. Module hängen nur vom Grundgerüst ab; Querverweise laufen über feste Stub-Typnamen (SPEC 5.9).

## Abhängigkeitsgraph

```
G1 Repo-Gerüst
 |-- G2 Datenkern ---- G3 Stores ----------\
 |        \-- G5 Gesundheit ----------------\
 |-- G4 Konto -----------------------------> G7 Hülle, Stubs, Demo, grüne CI -> Checkpoint A
 \-- G6 Design -----------------------------/                                        |
                                                  heute | gym | fortschritt | essen | schlaf | coach | profil | verbinden | widgets
                                                  (neun Worktrees parallel, Zweige modul/<id>)             |
                                                                                                           v
                                                  I1 Zusammenführen -> I2 Durchgang -> I4 TestFlight -> I5 Ship
                                                  I3a/I3 Privatdatei, Signierung (parallel ab G1) ----------^
```

## Bauweise der Agenten

- Modell Opus 5.5 für das Grundgerüst und die neun Module; Denktiefe hoch (kein Compiler lokal). Zusätzlich beim Zusammenführen `code-review`.
- Jeder Agent: Skills `agent-skills:build` und `agent-skills:test-driven-development`, Matt Pocock `tdd`, vor Abschluss `agent-skills:code-review-and-quality` oder `doubt-driven-development`. Oberfläche mit `ui-pro-swiftui`, `agent-skills:frontend-ui-engineering` und `docs/research/design.md`; unsichere iOS-26-Namen vorher gegen die Apple-Doku prüfen (`agent-skills:source-driven-development`).
- Jedes Modul arbeitet in einem eigenen Git-Worktree auf `modul/<id>`; der Auftrag steht vollständig in `tasks/auftraege/<id>.md` (Dateien, Lovea-Portierung mit Tests, Typen, Ideen, Fixtures, Akzeptanz).
- CI gibt es für Modul-Zweige nicht; der Compiler läuft erst in I1. Darum: kleine Dateien, `swift-syntax-check` nach jeder Datei, keine Kunststücke.

## Phase 1: Grundgerüst

Auftrag `tasks/auftraege/grundgeruest.md`.

- **G1 Repo-Gerüst und leere App grün.** Vorlagen aus `docs/research/vorlagen`, GitHub-Repo privat, erste CI. Akzeptanz: `xcodegen generate` läuft, `ios-ci.yml` grün im öffentlichen Fenster (Job `patterns` und `test-iphone`), `pruefe-privat.sh` und Namens-Gate sauber. Blockiert von: keine.
- **G2 Datenkern.** `Datum`, `Op`, `JSONValue`, `JSONDatei`, `LokalerOpLog`, `LokalerRaum`, die portierten Lovea-Typen und -Tests (Tabelle SPEC 5.8). Akzeptanz: alle mitgenommenen Tests grün; kaputte letzte Log-Zeile wird gesichert; doppelte Op-Id wird übersprungen. Blockiert von: G1.
- **G3 Stores und DatenSatz.** Akzeptanz: Stores falten Ops aus Fixtures; Profilwechsel erzeugt einen neuen `DatenSatz`. Blockiert von: G2.
- **G4 Konto.** Akzeptanz: Profil anlegen, `AppUmgebung` neu aufbauen, Profil ist aktiv ohne Passwort; falsches Passwort wird abgelehnt; Neuinstallations-Fall; Fake-Rückfall. Blockiert von: G1.
- **G5 Gesundheit.** Akzeptanz: `FakeHealthLeser` liefert 60 Tage; `GesundheitsStand` holt beim ersten Mal 60 Tage, später nur das Neue; ohne Erlaubnis `HealthZugriff` statt Absturz. Blockiert von: G2.
- **G6 Design.** Akzeptanz: `FarbenKontrastTests` grün (alle Paare aus `kontrast.py`), `SymbolNamenTests` grün, `LumenBogen` und `LumiView` rendern in CI-Screenshots. Blockiert von: G1.
- **G7 Hülle, Stubs, Demo, Widget-Hülle.** Akzeptanz: jede Route führt zu einem Stub; `-lumenFitDemo` zeigt jeden Tab; Screenshot-Schritt der CI liefert alle Bilder; Test-Host startet keine Module. Blockiert von: G3, G4, G5, G6.

### Checkpoint A: Grundgerüst
- [ ] CI grün, Warnungen 0, Privat-Check und Namens-Gate sauber
- [ ] Jeder Stub aus SPEC 5.9 existiert und ist eingehängt; Tag `grundgeruest-fertig`
- [ ] Modulaufträge gegen den echten Code geprüft, Zweige und Worktrees angelegt

## Phase 2: Module (parallel)

Jedes Modul: Auftrag `tasks/auftraege/<id>.md`, Ordner und Ideen dort und in SPEC 12. Tickets mit Ideen-Nummern: `tasks/todo.md`.

| Modul | Tickets (Ideen) |
|---|---|
| heute | H1 Ringplatte, Score, Morgensatz, Energie (11, 12, 13, 15); H2 Plan, Hinweise, Wochenstreifen (14, 19, 20); H3 Habits, Gewicht, Schritte (16, 17, 18) |
| gym | Y1 Logging, Satztypen, RPE, Pause, Rekord (21 bis 24); Y2 Katalog, Splits, Supersets (26 bis 28); Y3 Rechner, Cardio und Studio, Health, Steuerung (25, 29, 30) |
| fortschritt | F1 Kraftkurve, Muskel-Sätze, Raster, Gewicht (31, 32, 35, 36); F2 Silhouette, Vorschlag (33, 34); F3 Meilensteine, Lumi, Rückblick, Passport (37 bis 40) |
| essen | E1 Suche, BLS, Tagebuch, Portion, Donut (42, 43, 45, 46); E2 Scan, OFF, Etikett (41, 48); E3 Ampel, Fasten, Ziele, Analyse (44, 47, 49, 50) |
| schlaf | S1 Nacht, Phasen, Woche, Vergleich, Quellen (51, 52, 56, 59, 60); S2 Schuld, Regelmäßigkeit, HRV, Chips, Klartext (53, 54, 55, 57, 58) |
| coach | C1 Port, Regelmotor, Ton, Ehrlichkeit (62, 63, 70); C2 Foundation Models, Kontext (61, 66); C3 Gedächtnis, Chips, Schnellfragen, Morgen-Check, Daumen (64, 65, 67, 68, 69) |
| profil | P1 Onboarding, Blatt, Wechsel (71, 72); P2 Aussehen, Health-Zugriff, Körperdaten, Ziele (73, 75, 76, 77); P3 Sicherung, Quellen, Datenschutz, Export (74, 78, 79, 80) |
| verbinden | V1 Brücke, Freigaben, Partner-Karte, Mitteilungen (81 bis 84); V2 Band (85 bis 88); V3 Freundeskarte, Rangliste (89, 90) |
| widgets | W1 Snapshot, Widgets (91, 92, 93, 97); W2 Live Activity, Satz fertig, Habit-Widget (94, 95, 96); W3 Siri, Spotlight, Steuerelement (98, 99, 100) |

### Checkpoint B: je Modul
- [ ] Alle Ideen des Moduls eingebaut oder mit Grund als nicht umsetzbar gemeldet
- [ ] Nur Dateien der eigenen Ordner geändert
- [ ] `swift-syntax-check` OK; Tests geschrieben (Test zuerst); portierte Lovea-Tests liegen bei
- [ ] Namens-Gate und Umfang-Gate leer; Abschlussbericht mit ungeprüften Punkten

Prüfung der Disjunktheit (vor dem Anlegen der Worktrees und bei I1):

```bash
for m in heute gym fortschritt essen schlaf coach profil verbinden widgets; do
  git diff --name-only main...modul/$m | while read -r f; do
    case "$f" in
      LumenFit/Sources/Module/*|LumenFit/Tests/Module/*|LumenFit/Tests/Fixtures/*|LumenFitWidgets/Sources/Widgets/*|Gemeinsam/Widgets/*|tasks/*) ;;
      *) echo "$m: $f (außerhalb der Modulordner)";;
    esac
  done
done
```

## Phase 3: Integration und Auslieferung

- **I1 Zusammenführen.** Reihenfolge profil, schlaf, essen, heute, gym, fortschritt, coach, verbinden, widgets auf `main`; ein öffentliches CI-Fenster für alle (`scripts/ci-fenster.sh` im Hintergrund, danach einmal `gh run watch`); Kompilierfehler gehen an das Modul zurück. Akzeptanz: CI grün, 0 Warnungen, alle Tests grün. Abhängig von: alle Module.
- **I2 Qualitäts- und Barrierefreiheits-Durchgang.** `agent-skills:code-review-and-quality`, `code-simplification`, `frontend-ui-engineering`; Checkliste: Labels an jedem Symbol, 44 pt, Dynamic Type bis Accessibility 3, Reduce Motion und Transparency, erhöhter Kontrast, Diagramm-Descriptor, keine Namen und Orte in Code und Logs, Umfang-Gate, `grep "Kommt bald"` leer, Lovea unverändert (SPEC 13 Nr. 14). Akzeptanz: Checkliste abgehakt, `/constraints guard` ohne Funde. Abhängig von: I1.
- **I3a PrivateDaten.json und Secret.** Nur wenn gym Studio-Vorgaben nutzt; sonst Streichungen nach `konfiguration.md` 7.3. Nie Werte in Logs oder Chat. Abhängig von: G1.
- **I3 Signierung und Secrets.** Nach `konfiguration.md` Abschnitt 6: Bundle IDs per Skript (`HEALTHKIT` und `APP_GROUPS`), Portal-Handarbeit (App Group, App-Eintrag; einmal Apple-Login durch Ahmed im Agenten-Chrome, Fernfunk-Aufgabe), Profile mit Pflichtliste (beide Gruppen, HealthKit), neun Secrets, Icon, Tester (Sichtbarkeit für eingeschränkte Nutzer, Gruppe, je Person `betaTesters`). Abhängig von: G1, parallel zu den Modulen.
- **I4 TestFlight-Build.** `scripts/testflight-fenster.sh`; bei Rot `gh run view --log-failed` (Upload-Fehler statt Build-Fehler ist der Normalfall der ersten Läufe). Akzeptanz: Build in TestFlight sichtbar, Repo wieder privat. Abhängig von: I2, I3, I3a.
- **I5 Ship.** `agent-skills:ship`, Ideen abhaken, Vault-Eintrag, Fernfunk-Aufgabe mit der Testliste, Lovea-Folgearbeit (SPEC 16) als eigener Auftrag, Hinweis "noch nicht auf dem Handy", bis Ahmed testet. Abhängig von: I4.

### Checkpoint C: Auslieferung
- [ ] CI grün, TestFlight-Build vorhanden, Repo privat
- [ ] Testliste an Ahmed (Fernfunk-Aufgabe)
- [ ] Offene Punkte als Aufgaben (Lovea-Runde, Gerätetests)

## Testliste für Ahmed (am Handy, in seinen Worten)

1. Profil anlegen, App ganz schließen und neu öffnen: kommt kein Passwort?
2. Neues TestFlight-Update einspielen: bist du noch drin?
3. App löschen und neu installieren: kennt sie dich und bietet sie die Sicherung an?
4. Alle fünf Themes in Hell und Dunkel: Muster sichtbar, nichts zu bunt, nichts schwer lesbar?
5. Heute: sehen die drei Bögen nach deinem Geschmack aus oder zu nah an den Apple-Ringen?
6. Ein Training: Plus und Minus statt Tippen, Pause startet von selbst, Rekord kommt einmal, auf dem Sperrbildschirm "Satz fertig" geht?
7. Essen: eine Packung scannen, Ampel und Quelle sichtbar?
8. Schlaf: letzte Nacht, HRV im eigenen Bereich, Werte-Chips stimmen mit Health überein?
9. Coach: drei Fragen, klingt er wie ein Freund? Auch auf einem Gerät ohne Apple Intelligence?
10. Ohne Lovea: ist wirklich nichts vom Partner zu sehen? Mit Lovea (erst nach der Lovea-Runde): Partner-Karte und Mitteilung?
11. Band einschalten: Pause vibriert; hält Lovea das Band noch fest (dann ausgelassen)?
12. Widgets, Steuerelement, Siri; Reduce Motion an; große Schrift; wie schnell ist der Akku nach einem Tag weg?

## Risiken und Gegenmittel

| Risiko | Gegenmittel |
|---|---|
| Nur der Compiler in CI findet Fehler; viele Dateien parallel | kleine Dateien, `swift-syntax-check`, Grundgerüst zuerst grün, I1 mit einem Fenster für alle |
| 76 von 207 Lovea-Health-Dateien hängen an Op-Log, Raum, Punkten, Figuren, Chat | feste Ersetzungstabelle im Grundgerüst (SPEC 5.8), Module bauen keine eigenen Ersatzteile |
| Namen und Studios stecken im Lovea-Code | Namens-Gate in `check-schnell.sh` und Job `patterns`, Studios nur aus `PrivateDaten.json` |
| FoundationModels-Namen ungeprüft | alles in einer Datei, vorher gegen Apple-Doku, Regelmotor als Rückfall |
| Schlüsselbund im unsignierten Simulator (-34018) | Port mit Speicher-Fake und Rückfall |
| Band nimmt eine Verbindung; Lovea hält sie | opt-in Standard aus, Warteschlange statt zweiter Verbindung, Gerätetest |
| `muskelkarte.json` ist AGPL | Silhouette neu gezeichnet, Datei nicht übernommen |
| Übungsbilder-Lizenz unklar | nur laden und cachen, Symbol-Rückfall, spätere zweite Quelle |
| Review beanstandet die Bögen | `LumenBalken` ist ein Austausch ohne Datenänderung |
| Faltung vieler Ops zu langsam | am Gerät messen; Kompaktierung wäre eine spätere Runde |
| Name "Lumen Fit" im Store vergeben | Zusatz, Anzeigename bleibt |
| Open Food Facts begrenzt oder fällt aus | Rate-Limit-Test, BLS offline, Eingabe von Hand |
| HealthKit-Hintergrundlieferung ohne eigenen Portal-Schalter im Profil | Pflichtliste prüft nur `healthkit`; Gerät entscheidet (`konfiguration.md` 9) |
| Neun Zweige kollidieren | disjunkte Ordner, Skriptprüfung, Stubs statt Änderungen an Gemeinsamem |

## Offene Fragen

Keine für Ahmed außer dem einmaligen Apple-Login (SPEC 16). Alle anderen Entscheidungen stehen als Annahmen in SPEC 15.
