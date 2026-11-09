# Lumen Fit wird reine Gym-App wie Hevy – Design (09.11.2026)

## Absicht
Ahmed (09.11.2026): "wir möchten es simpler halten. ... Somit isoliert man lumen fit nur für gym. Wir möchten es so krass nah an hevy app." Und: "Ein theme. Dark/white. Kein wählbarer Theme. ... Profil aufjedenfall ganz rechts. Startseite, training mit buttons usw so wie [Hevy]. Die bar unten gefällt mir der design von hevy. Bei kalender sollte man so sehen nach vorn und auch den partner."
Lumen Fit soll das tun, was Hevy gut macht (Training loggen, Pläne, Verlauf, Freunde), in Ahmeds Sprache und mit seinen Daten, ohne alles, was nicht Gym ist. Weniger Code heißt weniger Fehler, weniger Akku, schnellere Builds.

## Ziele
1. Drei Tabs wie Hevy: Startseite, Training, Profil (ganz rechts). Leiste unten als schwebende Pille.
2. Ein Theme: hell oder dunkel nach System, Akzent Blau. Keine Farbwelten, keine Muster.
3. Kalender im Profil: vergangene Trainings, geplante Tage nach vorn, dazu die Tage des Trainingspartners.
4. Code von rund 63.000 auf unter 30.000 Zeilen; Akku-Fresser raus oder gedrosselt (siehe Bestandsaufnahme im Entwurf).
5. Kein Fortschritt und keine Daten gehen verloren; alte Ops bleiben lesbar.

## Nicht-Ziele
- Essen, Schlaf, Tagesform, Energie, Ringe, Einsichten: nicht mehr in Lumen Fit (Essen zu Lovea, Schlaf zu Lumen Alarm, Rest entfällt).
- Kein Feed-Algorithmus, kein Abo, keine Werbung, kein Theme-Shop.
- Keine Pixelkopie von Hevy: Aufbau und Abläufe wie Hevy, Texte und Daten von Lumen Fit.

## Anti-Ziele (wäre ein Fehlschlag)
- Eine Funktion verschwindet ohne Ahmeds Wort (Soll-Liste `Lumen Fit – Wissen/Funktionen – was da ist.md` gilt).
- Essen oder Schlaf fehlen in Lumen Fit, bevor sie in Lovea bzw. Lumen Alarm bei Ahmed laufen.
- Ein Update löscht oder versteckt Trainingsdaten (Op-Log, Plan, laufendes Training).
- Die App fragt beim Start nach Rechten oder lädt wieder alles im Hintergrund.

## Rahmen
- Swift 6 strikt, iOS 26, keine Pakete, `CONSTRAINTS.md` gilt (0 Warnungen, Tests, Namens-Gate, Typnamen eindeutig). Kein Mac: `swift-kompilieren` vor jedem Push, CI-Fenster für Tests, ein TestFlight-Build am Tag.
- Datenkern bleibt: Op-Log je Profil, `gym.*`-Ops, `TrainingsPlan`; gespeicherte Typen nur mit optionalen Feldern erweitern; `AlteDateienLadenTests`.
- Server-Verträge bleiben (`/config`, `/partner`, `/verbindungen`, `/postfach`, `/coach/*`, `/lovea/*`); Essen-Wege verschwinden erst mit dem Essen.
- Freunde, Feed, Trainingspartner, Bestenliste baut die Sitzung fitfreunde (Zweig `fit-crew`); diese Spec nennt nur, wo sie erscheinen.
- Band, Schritte, Schlaf und alles an Health wandern zu Lumen Alarm (nur für den Besitzer). Lumen Fit fragt Schritte und Schlaf nur von dort ab und misst nichts über AirPods oder Gurt (Entscheidung 09.11.2026 23:47 im Entwurf-Kommentar). Bis Lumen Alarm das kann, bleibt das Band-Modul unverändert in Lumen Fit; Band-Nächte gehen bis dahin per Brücke an Lumen Alarm.

## Entschieden (Ahmed, 09.11.2026)
- Ein Theme hell/dunkel nach System, kein wählbares Theme.
- Tabs Startseite, Training, Profil; Profil ganz rechts; Leiste wie Hevy.
- Startseite und Training "mit Buttons so wie Hevy"; Kalender nach vorn und mit Partner.
- Lovea-Farbwelt als zweite Oberfläche weg ("Weg, eine Oberfläche").
- Übungsmenü ohne Notiz, Scheiben, Pause je Übung, Supersatz; Reihenfolge per Knopf; Pausen-Timer Standard aus (Build 17).
- Essen zu Lovea, Schlaf zu Lumen Alarm; erst ankommen lassen, dann entfernen.
- Rechte erst bei der Nutzung; offline zuerst; Skills für Agenten; Einladen in Sekunden.

## Meine Entscheidungen (als Vorschlag markiert, Ahmed kann sie kippen)
- Leiste: die iOS-26-Tab-Leiste (Glas, schwebend, drei Einträge) sieht aus wie Hevys Pille und braucht keinen eigenen Code. Erst wenn Ahmed sie am Gerät zu anders findet, eine eigene Leiste.
- Akzent: Systemblau (hell 0x0B5ED7 auf Weiß, dunkel 0x5B9DFF mit dunkler Schrift), damit der Kontrast-Test (4,5:1) hält.
- Startseite: Karte "Heute" (geplanter Tag, Training starten), Wochenleiste du und Partner, letzte Einheit, Gewohnheiten klein (Wasser, Creatin, Gym), Gewicht als Zeile; ab Build 19 darunter der Feed der Freunde.
- Profil: Kopf mit Name und Zahnrad, Zahlen Workouts und Freunde, Diagramm Dauer/Volumen/Wiederholungen je Woche, Dashboard mit Statistiken, Übungen, Messungen, Kalender, darunter die Liste der Workouts. Alle Einstellungen hinter dem Zahnrad (bisheriges Profil-Blatt, ohne Farbwelt).
- Übergang: Solange Essen und Schlaf noch da sind, erscheinen sie als Kacheln im Dashboard (Schlaf nur freigegeben), nicht als Tabs. So ist die Leiste schon richtig und nichts verschwindet.
- (gekippt am 09.11. 23:47) Band geht zu Lumen Alarm, siehe Rahmen.
- Widgets: Training-Live-Aktivität und ein Gym-Woche-Widget bleiben; die übrigen elf, Spotlight und Steuerelement gehen in Build 19.
- Medaillen bleiben klein, Lumi-Figur geht; Habits bleiben klein (Ahmeds meistgenutzte Funktion: 105 Tipps).

## Was weg geht (Bestandsaufnahme, Zeilen gerundet)
Essen 11.900 (zu Lovea) · Lovea-Farbwelt 4.200 · Partner-Ansichten über Lovea 3.100 (ersetzt durch Freunde) · Schlaf 2.900 (zu Lumen Alarm) · Körper-Silhouette und Erholung 2.400 (Messungen bleiben) · KI-Foto 2.200 (mit Essen) · Tagesform, Energie-Bank, Tages-Formen 2.000 · Studio, Geräte, Defekte 1.200 (toter Code) · Farbwelten und Muster 1.200 · Einsichten, Hinweise, Ringplatte, Schritte-Detail 1.000 · zehn Widgets, Essen-Live-Aktivität, Siri, Spotlight, Steuerelement ~2.000 (es bleiben: Training-Live-Aktivität mit „Satz fertig“, Gewohnheiten-Widgets, Gym-Woche-Widget; Entscheidung 09.11. 23:49) · Fasten 700 · Lumi-Figur 400 · TipKit 225.

## Was neu kommt
Fortschritt als stärkste Seite (Entscheidung 09.11. 23:52: „da gucke ich rein, wie es mir geht, wie ich meine Gewichte steigere, meine Sessions“): wie geht es dir (Woche gegen 4-Wochen-Schnitt), Gewichte je Übung mit Kurve und Änderung, Einheiten je Woche mit Verlauf wie Hevy, Körper, Medaillen; Konstanz-Raster, Rückblick, FitPassport bleiben bis zu seinem Wort · Karte „Letztes Training“ auf der Startseite (Entscheidung 09.11. 23:50) · Nutzungszähler zählt auch Umschalter und NavigationLinks (heute blind dafür, daher die falsche Angabe „Fortschritt nie geöffnet“) · Kalender mit Plan und Partner · Profil-Tab mit Statistik-Diagramm und Dashboard · Routinen-Karten im Training (Build 19) · Freunde: Freundesliste, Trainingspartner, Rangliste, geplante Tage, kein Feed (Zweig fit-crew) · Satz-Vorschlag (Build 17) · ein Theme.

## Builds
- 18: ein Theme, Lovea-Farbwelt raus, toter Code raus, drei Tabs, Profil-Tab mit Dashboard und Kalender, Startseite kompakt, Essen-Export und Schlaf-Brücke (Schalter). Plan: `docs/superpowers/plans/2026-11-09-lumen-fit-hevy-umbau1.md`.
- 19: Freunde (fit-crew), Training-Tab mit Routinen und Routine-Editor, Verlauf wie Hevy, Widgets kürzen (Live-Aktivität, Gewohnheiten, Gym-Woche bleiben).
- 20: Essen und Schlaf raus, Partner-Ansichten raus (nach Ahmeds Test der Lovea- und Lumen-Alarm-Builds).

## Offen für Ahmed
1. Startseite: Heute-Karte plus Woche plus Feed (Vorschlag) oder nur Feed wie Hevy?
2. Band: entschieden, zu Lumen Alarm (09.11. 23:47).
3. Gewohnheiten klein behalten oder ganz raus?
