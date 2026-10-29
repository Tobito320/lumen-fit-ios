# Lumen Fit: 100 Ideen

Format nach `agent-skills:idea-refine` (Ein-Seiter), Stand 29.10.2026. Der Auftrag verlangt eine sehr gute Health-App, die auch Kollegen nutzen können, und "so viel Fertiges wie möglich aus Lovea". Diese Datei hält die 100 Ideen fest, die alle eingebaut werden. Die Bestätigungsfrage der Methode entfällt (Auftrag ohne Rückfragen, `SPEC.md` Abschnitt 15). Jede Idee gehört zu genau einem Modul oder zum Grundgerüst; der Bau steht in `tasks/todo.md`, die Aufträge in `tasks/auftraege/`.

## Problem Statement

Wie bekommen Ahmed, seine Partnerin und Kollegen eine einzige ruhige, schöne Health-App, die Gym, Essen, Schlaf, Schritte und einen menschlichen Coach auf dem iPhone hält, ohne Konto-Server, ohne erneute Anmeldung und ohne dass Lovea dafür schwerer bleibt?

## Recommended Direction

Eine client-only App mit fünf Tabs (Heute, Gym, Essen, Schlaf, Coach). Der Kern ist Fertiges aus Lovea (Gym-Logik, Essen mit Scan, Schlaf, Habits, Coach-Regeln, Widgets), das auf lokale Stores umgebaut wird. Darüber liegen drei Dinge aus der Recherche: Hevy/Strong-Qualität beim Satz-Logging, Fitbod-Erholung je Muskel und ein Whoop/Bevel-Score aus Health-Werten. Die Figur Lumi und die Meilensteine geben die Wärme, Themes und Muster das Aussehen. Die Lovea-Verbindung läuft über einen Dateivertrag in der gemeinsamen App Group; ohne Verbindung läuft alles normal.

## Key Assumptions to Validate

- Zwei Apps können sich eine App Group teilen (`group.com.onlyus.lovea`), ohne dass Lovea geändert wird (erst am Gerät belegt).
- Das Band nimmt nur eine Verbindung; deshalb ist Band in Lumen Fit Standard aus (Idee 85).
- Apple Intelligence ist nicht auf jedem Gerät da; der Regel-Coach muss gut genug sein (Idee 62).
- Das Schlüsselbund-Profil überlebt eine Neuinstallation meistens, die Daten nicht (Idee 74 fängt das ab).
- Die Bögen der Ringplatte (Idee 6) sind kein Review-Problem (nicht geprüft).
- Loveas `widget-stand.json` in der gemeinsamen Gruppe enthält Schritte, Gym-Woche und Schlaf beider Personen und bleibt lesbar (Quelle A, SPEC 5.5); ändert Lovea das Format, wird die Verbindung still "nicht verbunden".

## MVP Scope

Alle 100 Ideen werden eingebaut. Reihenfolge: Grundgerüst (1 bis 10), danach neun Module parallel (je 10 Ideen), danach Integration. Geht eine Idee technisch nicht (zum Beispiel ein Control-Widget in CI), ersetzt sie die Rückfall-Lösung aus ihrem Auftrag und wird in `tasks/todo.md` vermerkt.

## Not Doing (and Why)

- Wecker, Erinnerungen, Töne, Wiege-Erinnerung: Auftrag sagt, sie sind eine andere App.
- Konto-Server, Live-Freunde-Feed, Push von Gerät zu Gerät: braucht ein Backend.
- Apple Watch, iPad, Android, Fitness+-Videos, ECG, biologisches Alter: nicht im Umfang oder medizinisch heikel.
- Kaufen, Abos, Werbung, Tracking Dritter.

## Die 100 Ideen

Zeile: Nummer, Titel, Nutzen, Modul in eckigen Klammern. Die Nummern 1 bis 100 stehen je einmal da.

1. **Profil für immer** – Name und Passwort einmal anlegen, danach nie wieder ein Anmeldebildschirm: Profil und Passwort-Spur liegen im Schlüsselbund und überleben Updates und meist auch eine Neuinstallation. [grundgeruest]
2. **Mehrere Profile pro Gerät** – Kollegen oder Familie teilen ein Gerät; jedes Profil hat eigene Daten, der Wechsel braucht das Passwort. [grundgeruest]
3. **Fünf Themes in Hell und Dunkel** – Monochrom (Standard), Graphit, Stahl, Glut, Wald; Wechsel sofort, ohne Neustart und ohne neue Anmeldung. [grundgeruest]
4. **Muster in jedem Theme** – Punkte, Diagonalen, Raster, Wellen oder Höhenlinien in Kopf, Karten und Hauptkarte; ein Canvas, einmal gezeichnet, kein Dauerlauf. [grundgeruest]
5. **Lumi, die süße Figur** – rundes, buntes Licht mit großen Augen und fünf Stimmungen; das einzig Bunte neben den drei Datenfarben. [grundgeruest]
6. **Lumen-Bögen** – drei offene Bögen für Bewegen, Trainieren, Erholen mit Zahl daneben und ein Balken-Ersatz; ruhige Apple-Farben statt Regenbogen. [grundgeruest]
7. **Haptik und Federn aus einem Guss** – ein Satz Federn und eine Haptik-Zentrale mit Schalter; Reduce Motion und Stromsparmodus gelten überall. [grundgeruest]
8. **Erster Tag schon voll** – beim Erlauben von Health liest die App 60 Tage Verlauf (Schritte, Schlaf, HRV), damit Diagramme sofort gefüllt sind statt leer. [grundgeruest]
9. **Jede Seite hat einen Link** – lumenfit://-Links führen zu jeder Seite; Widgets, Live Activity, Coach-Chips und Siri nutzen dieselben Wege. [grundgeruest]
10. **Fehler, die helfen** – jeder Fehler sagt, was schiefging und was jetzt hilft, mit Lumi dabei; eine kaputte Datei wird gesichert statt gelöscht. [grundgeruest]
11. **Ringplatte mit Lumen-Bögen** – Schritte, Gym und Schlaf auf einer schwarzen Platte mit Streifen; die Bögen füllen sich beim Öffnen, Lumi sitzt in der Mitte. [heute]
12. **Bereit-Score** – Erholung, Belastung und Schlaf als drei kleine Bögen mit einem Satz dazu; eigene, offen erklärte Formel aus Health-Werten. [heute]
13. **Lumis Morgensatz** – ein Satz aus echten Zahlen ("Gut erholt. Heute Beine?"), Lumis Stimmung folgt dem Score. [heute]
14. **Plan-Karte mit einem Tipp** – der heutige Trainingstag aus dem Split, ein Knopf startet das Training. [heute]
15. **Energie-Bank** – ein Wert von 0 bis 100 für den Akku des Körpers aus Schlaf, Erholung und Belastung, mit Verlauf über den Tag. [heute]
16. **Gewohnheiten mit Serie** – Haken per Tipp, Zähl-Gewohnheiten wie Wasser, Serie in Tagen oder Wochen, Verwaltung in einer Zeile. [heute]
17. **Gewicht in drei Sekunden** – Blatt mit Zahlenrad, Verlauf mit Ziellinie, auf Wunsch zurück nach Health geschrieben. [heute]
18. **Schritte im Detail** – Tag, Woche, Monat, Distanz, Etagen, beste Tage und die Zielmarke. [heute]
19. **Hinweise des Tages** – höchstens drei kleine, wegwischbare Karten aus Regeln ("Zweimal unter 6 Stunden: heute locker"). [heute]
20. **Wochenstreifen** – Montag bis Sonntag mit kleinen Bögen je Tag; ein Tipp öffnet den Tag. [heute]
21. **Letztes Mal in der Zeile** – je Satz steht der Wert vom letzten Training, Gewicht und Wiederholungen mit Plus und Minus statt Tippen. [gym]
22. **Satztypen und RPE** – Aufwärmen, normal, Drop, bis Versagen; RPE-Skala zum Antippen. [gym]
23. **Pausen-Timer, der von selbst startet** – startet beim Haken, plus und minus 15 Sekunden, eigene Pause je Übung, am Ende Haptik und Band. [gym]
24. **Rekord sofort** – direkt nach dem Satz ein Toast bei neuem Gewichts-, Wiederholungs- oder 1RM-Rekord; Lumi hüpft einmal. [gym]
25. **Scheiben- und Aufwärmrechner** – welche Scheiben pro Seite, Aufwärmsätze in Prozent vom Arbeitsgewicht. [gym]
26. **1.333 Übungen auf Deutsch** – Suche mit Synonymen, Muskel und Gerät; Bilder aus dem Netz im Cache, ohne Bild ein Symbol. [gym]
27. **Splits und Wochenplan** – Push/Pull/Legs, Ganzkörper, Upper/Lower aus Vorlagen oder frei; "heute Beine statt Push" erkennt die Abweichung. [gym]
28. **Supersets und Notizen** – Übungen koppeln, Notiz je Übung und je Training. [gym]
29. **Cardio und Studio-Besuch** – Cardio mit Dauer, Distanz und Puls; Einchecken und Auschecken zählt Besuche und warnt außerhalb der Öffnungszeiten. [gym]
30. **Training nach Health schreiben** – beim Beenden entsteht ein Workout in Health (Dauer, Energie, Puls); ein Schalter, Standard aus. [gym]
31. **Kraftkurve je Übung** – Linie mit Fläche und Endpunkt für bestes Gewicht, geschätztes 1RM und Volumen; der Titel nennt die Aussage ("Bankdrücken: 70 kg, plus 10"). [fortschritt]
32. **Sätze je Muskel gegen Ziel** – Wochenbalken je Muskelgruppe mit Zielzahl und Wert rechts. [fortschritt]
33. **Erholungs-Silhouette** – selbst gezeichnete Körperkarte zeigt je Muskel die Erholung in Prozent, die Liste daneben sagt es in Worten. [fortschritt]
34. **Vorschlag fürs nächste Training** – frischeste Muskeln plus verfügbare Zeit ergeben "Heute Beine, 45 Minuten" samt Begründung. [fortschritt]
35. **Konstanz-Raster** – 18 Wochen mal 7 Tage in vier Stufen, auch ohne Farbe lesbar. [fortschritt]
36. **Gewichtsverlauf mit Trend** – gleitender Mittelwert, Ziellinie und Prognose "in 9 Wochen am Ziel". [fortschritt]
37. **Meilensteine und Medaillen** – 25 Medaillen (erste Woche, 10/50/100 Gym-Tage, Volumen, Schlafserie), schwarz mit Rand; gesperrte stehen grau mit Text. [fortschritt]
38. **Lumi-Stufen 1 bis 9** – Lumi wächst mit den Meilensteinen; Pfad, Wochenserie und nächstes Ziel mit Balken. [fortschritt]
39. **Wochen- und Monatsrückblick** – Sonntagskarte mit Gym-Tagen, Volumen, Schlafschnitt und dem besten Moment; als Bild teilbar. [fortschritt]
40. **FitPassport** – eine teilbare Karte mit Langzeitwerten (Kraft, Schlaf, Konstanz), ohne Namen Dritter. [fortschritt]
41. **Barcode-Scan** – Kamera erkennt den Code, Treffer aus Speicher, BLS, dann Open Food Facts; unbekannt führt zur Eingabe von Hand. [essen]
42. **7.140 Lebensmittel ohne Netz** – BLS 4.0 gebündelt; Haferflocken, Ei und Reis gibt es auch im Flugmodus. [essen]
43. **Makro-Donut ohne Farbe** – Protein, Kohlenhydrate, Fett als Grautöne mit Muster und Beschriftung; die Farben bleiben für Gym und Schlaf frei. [essen]
44. **Halal- und Zucker-Ampel** – Pille mit Symbol und Text, prüft Zutaten (Gelatine, Alkohol, E-Nummern) und sagt "unklar", wenn Zutaten fehlen. [essen]
45. **Favoriten und Zuletzt** – häufige Lebensmittel oben, eigene Gerichte als Favorit speichern. [essen]
46. **Portion-Schieber** – Gramm, Stück oder Portion; die Nährwerte rollen mit. [essen]
47. **Fasten-Fenster 16:8** – Balken mit Restzeit und Verlauf, ein Tipp startet das Fenster. [essen]
48. **Etikett-Foto** – Nährwerttabelle fotografieren, Vision liest die Zahlen, du prüfst und speicherst. [essen]
49. **Ziele aus deinen Körperdaten** – Kalorien und Protein aus Größe, Gewicht und Ziel (aufbauen, halten, abnehmen), alles überschreibbar. [essen]
50. **Wochenanalyse Essen** – Protein je Tag gegen Ziellinie, Zucker, Ballaststoffe und Mikronährstoff-Lücken in Klartext. [essen]
51. **Letzte Nacht groß** – Schlafzeit als Heldenzahl mit von bis und Ziel; Lumi schläft nachts. [schlaf]
52. **Phasen-Balken** – Tief, Kern, REM und Wach mit Muster und Beschriftung, nie nur Farbe. [schlaf]
53. **Schlafschuld über 7 Nächte** – gegen dein Ziel gerechnet, mit Vorschlag "heute 45 Minuten früher". [schlaf]
54. **HRV im eigenen Bereich** – 60-Tage-Bereich statt fremder Norm; Punkt nach Lage und ein Satz dazu. [schlaf]
55. **Werte-Chips** – Ruhepuls, SpO2, Atmung, Temperatur und VO2max mit Trendpfeil gegen deinen Schnitt. [schlaf]
56. **Wochenübersicht Schlaf** – sieben Balken, Schnitt und Nächte unter 6 Stunden. [schlaf]
57. **Regelmäßigkeit** – wie stark die Einschlafzeit streut, als ruhiger Score statt Vorwurf. [schlaf]
58. **Erholung in einfacher Sprache** – "Deine HRV liegt 12 Prozent über deinem Schnitt, du bist bereit", aus Regeln, auf Wunsch vom Coach erklärt. [schlaf]
59. **Wochen im Vergleich** – diese gegen letzte Woche, Wochenende gegen Werktag. [schlaf]
60. **Beste Schlafquelle** – Uhr, Handy oder Band; doppelte Nächte werden zusammengeführt, die genaueste Quelle gewinnt. [schlaf]
61. **Coach auf dem Gerät** – Apples Sprachmodell antwortet auf Deutsch ohne Server; Gesundheitsdaten verlassen das iPhone nicht. [coach]
62. **Rückfall ohne Apple Intelligence** – gleiche Tipps aus Textbausteinen und Regeln, damit jedes Gerät einen brauchbaren Coach hat. [coach]
63. **Ton wie ein Freund** – kurze Sätze, eine Frage, echte Zahlen; an schweren Tagen verständnisvoll, nie belehrend; die Tonregeln sind Tests. [coach]
64. **Coach merkt sich Ziele** – Ziele, Verletzungen und Vorlieben liegen lokal, sichtbar und löschbar. [coach]
65. **Chips mit Handlung** – "Mach ich" legt eine Gewohnheit an, "Morgen leicht" ändert den Plan, "Zeig mir" springt zur Seite. [coach]
66. **Coach kennt dein Training** – bekommt letztes Training, Rekorde, Schlaf und Essen als Kontext, ohne dass du etwas kopierst. [coach]
67. **Morgen-Check** – eine Frage beim ersten Öffnen am Morgen (1 bis 5), die Antwort färbt Lumis Stimmung und den Plan-Vorschlag. [coach]
68. **Schnellfragen nach Tageszeit** – morgens "Wie fühle ich mich?", abends "Was esse ich noch?"; ein Tipp statt Tippen. [coach]
69. **Daumen und Merkliste** – Antworten bewerten und merken; der Coach lernt Länge und Ton. [coach]
70. **Ehrlich, was er nicht weiß** – fehlen Daten, fragt er nach; keine Diagnosen, bei Beschwerden der Hinweis auf Ärztin oder Arzt. [coach]
71. **Einstieg in einer Minute** – Name, Passwort, ein Ziel, Health erlauben; Lumi führt durch vier Karten. [profil]
72. **Profil-Blatt überall** – die Avatar-Kapsel auf jedem Tab öffnet das Profil; Name und Passwort ändern. [profil]
73. **Aussehen-Seite** – fünf Karten mit Mini-Vorschau (Farbe, Muster), Erscheinung System, Hell, Dunkel; wirkt sofort. [profil]
74. **Datensicherung als Datei** – alles als eine Datei teilen und auf dem neuen Gerät einspielen; nach einer Neuinstallation fragt die App von selbst danach. [profil]
75. **Health-Zugriff im Klartext** – je Datentyp ein Haken, warum die App ihn braucht, und der Weg in die Einstellungen. [profil]
76. **Körperdaten und Einheiten** – Größe, Geburtsjahr, Geschlecht (nur für Formeln, optional), kg oder lb. [profil]
77. **Ziele-Seite** – Schritte, Kalorien, Protein, Schlaf, Gym-Tage und Gewichtsziel an einem Ort, mit Vorschlägen. [profil]
78. **Quellen und Lizenzen** – Open Food Facts, BLS, Übungsbilder und Apple-Dienste mit Namensnennung und Datenstand. [profil]
79. **Datenschutz in Klartext** – was gespeichert wird, was das iPhone nie verlässt; "Alles löschen" mit Passwort. [profil]
80. **Tabellenexport** – Training und Essen als CSV zum Teilen. [profil]
81. **Mit Lovea verbinden** – ein Schalter; verbunden heißt, die gemeinsame Gruppe hat eine frische Partner-Datei; ohne Verbindung läuft alles wie gewohnt. [verbinden]
82. **Partner-Karte** – Heute und Schlaf zeigen, was die verbundene Person freigibt, sonst gar nichts, nicht einmal einen Platzhalter. [verbinden]
83. **Mitteilungen bei Partner-Ereignissen** – "Partner ist im Gym" oder "Ziel erreicht" als lokale Mitteilung, je Art abschaltbar. [verbinden]
84. **Freigaben je Datenart** – Schritte, Gym, Schlaf und Essen einzeln teilen, Standard aus, mit Vorschau, was der andere sieht. [verbinden]
85. **Band verbinden** – CoreBluetooth mit Schritten, Puls und Akku; Standard aus, solange Lovea das Band noch selbst hält. [verbinden]
86. **Band geteilt** – Vibrationswünsche von Lovea landen in einer Warteschlange der gemeinsamen Gruppe, Lumen Fit führt sie am Band aus. [verbinden]
87. **Pause am Handgelenk** – das Pausen-Ende vibriert am Band, Muster einstellbar. [verbinden]
88. **Band-Akku im Blick** – Prozent, Verbindung, Warnung unter 15 Prozent und Verlauf der letzten Tage. [verbinden]
89. **Freundeskarte** – Wochenzusammenfassung als Bild, Link oder QR teilen; der Empfänger sieht sie als Karte, ganz ohne Server. [verbinden]
90. **Wochen-Rangliste mit Respekt** – aus importierten Freundeskarten, Schritte und Gym-Tage; "Respekt" statt Like. [verbinden]
91. **Widget Bögen** – klein: drei Bögen mit den Schritten in der Mitte, im Theme deiner App. [widgets]
92. **Widget Plan und Serie** – mittel: heutiger Plan, Serie und Bögen. [widgets]
93. **Sperrbildschirm-Widgets** – rund (Schritte), rechteckig (Schlaf und Erholung), Zeile (Gym-Serie). [widgets]
94. **Live Activity Training** – Dynamic Island und Sperrbildschirm mit Übung, Satz 3 von 4, Pausen-Countdown und Fortschrittsbalken. [widgets]
95. **Satz fertig vom Sperrbildschirm** – ein Knopf in der Live Activity setzt den Haken, ohne die App zu öffnen. [widgets]
96. **Gewohnheiten zum Abhaken** – interaktives Widget, Haken direkt auf dem Home-Bildschirm. [widgets]
97. **Widget Essen** – Rest-Kalorien und Protein heute, ein Tipp öffnet den Scan. [widgets]
98. **Siri und Kurzbefehle** – "Training starten", "Gewicht eintragen" und "Essen scannen" als App-Kurzbefehle ohne Einrichtung. [widgets]
99. **Spotlight** – Übungen, Pläne und Favoriten tauchen in der iPhone-Suche auf und öffnen die Seite. [widgets]
100. **Steuerelement im Kontrollzentrum** – Knopf für Training starten oder Scan, auch für die Aktionstaste. [widgets]
