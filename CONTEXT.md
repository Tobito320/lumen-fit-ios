# Lumen Fit

Eine iOS-App für Gesundheit und Fitness: Gym, Essen, Schlaf, Schritte, Coach und Fortschritt, mit der Figur Lumi und fünf Themes. Sie läuft komplett auf dem Gerät. Wer Lovea hat, kann beide Apps verbinden. Diese Datei legt die Wörter fest, die in Spec, Code, Tests und App-Texten gelten. Sie enthält bewusst keine Technik und keine Namen von Personen.

## Menschen und Profile

**Profil**:
Die Daten und Einstellungen einer Person auf diesem Gerät: Name, Passwort-Spur, Ziele, Trainings, Essen, Gewohnheiten, Themes. Es gibt beliebig viele; genau eines ist aktiv.
_Avoid_: Konto, Account, Login, User

**Aktives Profil**:
Das Profil, dessen Daten gerade angezeigt werden. Beim Start ist es das zuletzt aktive; die App fragt dabei nie nach dem Passwort.

**Passwort-Spur**:
Salz, Hash und Rundenzahl des Passworts im Schlüsselbund. Das Passwort selbst wird nie gespeichert.
_Avoid_: Passwort speichern, Token

**Datensatz**:
Alle Stores eines Profils zusammen, aufgebaut aus seinem Ereignis-Log. Wechselt das Profil, entsteht ein neuer Datensatz.

**Partner**:
Die Person, mit der ein Profil über Lovea verbunden ist. Sie erscheint nur als Zusammenfassung, nie mit Rohdaten.
_Avoid_: Freund (anderes Wort, siehe unten), Gegenüber

**Freund**:
Eine Person, deren Freundeskarte man importiert hat. Nur ein Schnappschuss, keine Live-Daten.

## Daten

**Op**:
Ein Ereignis im Log, zum Beispiel ein Satz im Training oder eine Mahlzeit. Hat eine Art, eine Zeit und einen JSON-Rumpf. Kommt aus Lovea.
_Avoid_: Eintrag (für Ops), Event

**Faltung**:
Die reine Rechnung, die aus allen Ops einer Art den aktuellen Stand macht.

**Raum**:
Der lokale Log eines Profils samt Beobachtern: schreibt Ops an und meldet sie den Stores. Hat in Lumen Fit keinen Server.

**Store**:
Ein `@Observable`-Objekt, das einen Teil des Standes hält und Änderungen als Ops in den Raum schreibt.

**Port**:
Eine Schnittstelle zur Außenwelt (Health, Netz, Schlüsselbund, Bluetooth, Mitteilungen, Coach, Lovea-Dateien) mit einer echten und einer Fake-Umsetzung für Tests.

## Gym

**Training**:
Eine Einheit vom Einchecken bis zum Auschecken (Lovea: Session). Besteht aus Übungsläufen mit Sätzen.

**Plan** und **Trainingstag**:
Der Wochenplan mit seinen Tagen und Übungen. Ein **Split** ist eine Vorlage dafür (Push/Pull/Legs, Ganzkörper, Upper/Lower).

**Satz**:
Gewicht und Wiederholungen einer Übung. **Satztyp**: Aufwärmen, normal, Drop, bis Versagen. Aufwärmsätze zählen nicht für Volumen und Rekorde.

**Rekord**:
Bestes Gewicht, beste Wiederholungszahl, bestes geschätztes 1RM oder bestes Volumen einer Übung, erkannt direkt nach dem Satz.

**Pause**:
Die Zeit nach einem abgehakten Satz; der Timer startet von selbst.

**Studio-Besuch**:
Ein Einchecken und Auschecken im Studio. Zählt ins Konstanz-Raster.

**Erholung (Muskel)**:
Wie ausgeruht eine Muskelgruppe ist, in Prozent, aus Sätzen und Zeit seit dem Training.

## Essen

**Lebensmittel**:
Ein Eintrag mit Nährwerten pro 100 Gramm aus BLS, Open Food Facts oder eigener Eingabe.

**BLS**:
Der Bundeslebensmittelschlüssel, gebündelt und offline benutzbar. Namensnennung nötig.

**Mahlzeit**:
Frühstück, Mittag, Abend oder Snack. Ein **Essen-Eintrag** ist ein Lebensmittel mit Menge in einer Mahlzeit an einem Tag.

**Ampel**:
Halal- und Zucker-Hinweis als Pille mit Symbol und Text. Sagt "unklar", wenn Zutaten fehlen.
_Avoid_: Farbampel ohne Text

**Fasten-Fenster**:
Die Zeit ohne Essen, zum Beispiel 16:8.

## Schlaf und Erholung

**Nacht**:
Der Schlaf eines Tages mit Phasen (Wach, REM, Kern, Tief) aus Health, Band oder eigener Eingabe.

**Schlafschuld**:
Die fehlenden Minuten der letzten sieben Nächte gegen das Schlafziel.

**Eigener Bereich**:
Der persönliche 60-Tage-Bereich eines Wertes (zum Beispiel HRV), gegen den "im Bereich" gemessen wird, nicht eine fremde Norm.

**Bereit-Score** und **Energie-Bank**:
Zwei eigene, offen erklärte Werte aus Schlaf, Erholung und Belastung. Sie sind keine Messung und keine medizinische Aussage.

## Gewohnheiten und Fortschritt

**Gewohnheit**:
Etwas, das man regelmäßig tut, mit Haken oder Zähler und einer **Serie**.

**Meilenstein** und **Medaille**:
Ein erreichtes Ziel (zum Beispiel 50 Gym-Tage) und sein Abzeichen. Gesperrte Medaillen zeigen Text statt Farbe.

**Konstanz-Raster**:
18 Wochen mal 7 Tage in vier Stufen.

**Rückblick**:
Die Wochen- oder Monatskarte mit den wichtigsten Zahlen, als Bild teilbar. Der **FitPassport** ist die Langzeitversion.

## Lumi und Design

**Lumi**:
Die Figur der App: rund, bunt, süß. Fünf **Stimmungen** (bereit, müde, stolz, schläft, denkt) und **Stufen** 1 bis 9, die mit den Meilensteinen wachsen.
_Avoid_: Maskottchen-Name mit Herz, Avatar

**Datenbereich**:
Eine der drei Farben: Bewegen (Rot), Trainieren (Grün), Erholen (Blau). Jede Farbe heißt genau einen Lebensbereich.

**Lumen-Bogen**:
Der offene 270-Grad-Bogen für einen Datenbereich mit Spur, Beschriftung und Zahl. **Ringplatte**: die schwarze Fläche, auf der drei Bögen stehen.
_Avoid_: Aktivitätsring (Apple-Begriff, anderer Zweck)

**Theme**:
Eines von fünf Aussehen (Monochrom, Graphit, Stahl, Glut, Wald) mit Farben und Muster. **Erscheinung**: System, Hell oder Dunkel.

**Muster**:
Das Linienbild eines Themes (Punkte, Diagonalen, Raster, Wellen, Höhenlinien).

## Coach

**Coach**:
Der Chat, der die Zahlen der Person kennt und in kurzen Sätzen antwortet. Er stellt keine Diagnosen.

**Coach-Motor**:
Die Maschine hinter dem Coach: das Sprachmodell auf dem Gerät oder der regelbasierte Rückfall.

**Chip**:
Eine Antwortmöglichkeit mit Handlung ("Mach ich" legt eine Gewohnheit an).

**Merkzettel**:
Das, was der Coach sich über die Person merkt (Ziele, Verletzungen, Vorlieben). Sichtbar und löschbar.

## Verbindung

**Verbunden**:
Eine frische Partner-Datei liegt in der gemeinsamen Gruppe und die Einstellung ist an. Sonst ist nichts vom Partner zu sehen.

**Freigabe**:
Die Erlaubnis, eine Datenart (Schritte, Gym, Schlaf, Essen) als Zusammenfassung zu teilen. Standard: keine.

**Band**:
Das Fitness-Band mit Bluetooth. **Band-Wunsch**: eine Bitte von Lovea, das Band vibrieren zu lassen.

**Freundeskarte**:
Die Wochenzusammenfassung als Bild, Link oder QR.

## Bau

**Modul**:
Ein Stück der App mit eigenen Ordnern, das parallel gebaut wird. Neun gibt es: heute, gym, fortschritt, essen, schlaf, coach, profil, verbinden, widgets.

**Grundgerüst**:
Alles Gemeinsame, das vor den Modulen steht: Datenkern, Design, Konto, Ports, Stubs.

**Stub**:
Eine Datei, die das Grundgerüst anlegt und die ein Modul später mit Inhalt füllt.
