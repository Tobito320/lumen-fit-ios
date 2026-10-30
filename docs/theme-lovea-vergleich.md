# Theme Lovea: Vergleich Lovea gegen Lumen Fit

Stand 30.10.2026. Quelle der Lovea-Werte: `~/code/lovea-app-ios`, Zweig `runde-3`, nur gelesen; Pfade unten sind relativ zu `Lovea/Sources/`.
Gelesen und verglichen: `App/Farben.swift`, `App/Feder.swift`, `App/Abstand.swift`, `App/GeleeEffekte.swift`, `App/KartenScroll.swift`, `App/HerzenSpritzer.swift`,
`App/AppRootView.swift`, `Health/HealthStil.swift`, `Health/Heute/HeuteView.swift`, `Health/Heute/TagesFormen.swift` (Maße und Farben), `Health/SchritteRinge.swift`,
`Home/HomeView.swift`, `Assets.xcassets/AccentColor.colorset`. Nur überflogen: `Chat/Backdrop.swift`.
Nicht gelesen: die übrigen rund 4.500 Dateien (Chat, Zimmer, Zyklus, Snaps, Gym-Ansichten im Einzelnen). Was dort anders aussieht, steht hier nicht.

## Zuerst: Lovea fällt bei Kontrast durch, Entscheidung offen

Das Theme gibt die Lovea-Farben 1:1 wieder, auch dort, wo Lovea selbst unter WCAG AA (4,5:1) liegt. Betroffen (hell): Akzent `#FF3B5C` auf Weiß 3,48:1, Nebentext
(`secondaryLabel`) 3,44:1, weiße Schrift auf dem Akzent 3,48:1; dunkel: weiße Schrift auf dem Akzent 3,48:1. Zahlen unten. `FarbenKontrastTests` und `docs/research/kontrast.py`
kennen genau diese Paare und verlangen für sie 3:1; alle anderen Themes und Paare bleiben bei 4,5:1. Soll abgedunkelt werden: die Tokens in `Gemeinsam/Design/Farben.swift`
ändern (Vorschlag Akzent hell `#D42347`: 5,08:1 auf Weiß, 4,56:1 auf `#F2F2F7`; Nebentext hell `#6C6C70`: 5,23:1 / 4,69:1; Schrift auf dem Akzent dunkel schwarz: 6,03:1)
und die Liste `loveaBekannt` in `FarbenKontrastTests` leeren.

## Wer das Theme sieht

Nur Konten, die der Server freigibt (`KontoDienst.loveaErlaubt`, der Server setzt es nur für die zwei Lovea-Personen). Maßstab ist die Freigabe, nicht der Name.
Ohne Freigabe fehlt die Karte in "Aussehen", und ein gespeichertes `lovea` gilt als Monochrom (`ProfilThemaWahl.wirksam`), ohne dass etwas umgeschrieben wird. Das gilt für
die App-Wurzel, die Widgets und die Anzeige im Profil. Die Freigabe wird in `konto-stand.json` gesichert und bleibt nach dem Import und ohne Netz (Test `ThemaLoveaTests`).

## Wie Lovea aussieht (aus dem gelesenen Code)

Lovea ist in Health und Home ein System-Look: Grund `systemBackground`, Karten `secondarySystemBackground`, Text `.primary` und `.secondary`, ein einziger Akzent `#FF3B5C`.
In den gelesenen Health- und Home-Dateien gibt es kein Muster, keinen Verlauf auf Flächen und keinen Schatten außer am Schalterknopf. Das Herzmuster, das das Theme bisher hatte,
steht in den Health- und Home-Flächen nirgends; es ist dort entfernt. Herzen gibt es in Lovea an genau drei Stellen: als Deko im Bereich Zyklus (`Zyklus/ZyklusDeko.swift:5,67`,
Hintergrund `Zyklus/ZyklusStil.swift:82`, Herz im Phasen-Ring `Zyklus/ZyklusStil.swift:119`), als einmaliger Spritzer (`App/HerzenSpritzer.swift:5`, genutzt bei Ziel erreicht `Health/SchritteRinge.swift:131`,
Serie `Health/HabitsSektion.swift:177`, Chat, Notizen) und im Chat-Hintergrund. Zyklus und beide Spritzer sind jetzt im Theme Lovea nachgebaut (Tabelle unten); das Muster bleibt weg.
Nicht ausgeschlossen: Chat-Hintergründe und der Lovea-Verlauf des Profilkopfs (`Chat/Backdrop.swift`, `Profile/ProfilHintergrund.swift:46`) sind Verläufe und Bilder; die hat Lumen Fit nicht.
Die bisherigen Hex-Werte des Themes (Rosé-Flächen `#FFEDF0`, `#211418`, Text `#1C1C1E`) stammten nicht aus Lovea.

## Tabelle

Spalten: Eigenschaft, Lovea-Wert (Datei:Zeile), Lumen-Fit-Stelle, übernommen.

| Eigenschaft | Lovea-Wert | Lumen Fit | Übernommen |
|---|---|---|---|
| Akzent | `#FF3B5C`, hell und dunkel gleich (`App/Farben.swift:5`, `AccentColor.colorset`) | `Gemeinsam/Design/Farben.swift`, `tokens(.lovea)` | ja, hell wie dunkel (fällt hell unter 4,5:1, siehe oben) |
| Tint der App und Tab-Leiste | `.tint(Color.loveaRose)` (`App/AppRootView.swift:207`) | `lumenTheme` setzt `.tint(palette.akzent)` (`Gemeinsam/Design/Theme.swift`) | ja |
| Grund | `systemBackground`: Weiß / Schwarz (Home: `Home/HomeView.swift:16`, `ScrollView` ohne eigenen Grund) | `grund` = `#FFFFFF` / `#000000` | ja (Hex aus der UIKit-Tabelle, nicht aus dem Lovea-Code) |
| Karte (Heute) | `secondarySystemBackground`, ohne Rand (`Health/Heute/HeuteView.swift:126`) | `flaeche` = `#F2F2F7` / `#1C1C1E`, `ListenKarte` | ja |
| Karte (Health-Karte) | gleiche Fläche plus 14 % Tönung der Kartenfarbe (Standard Grau) und bei erhöhtem Kontrast Rand 0,7 (`Health/HealthStil.swift:42-54`) | `ListenKarte` kennt keine Tönung | nein: Lumen Fit hat eine Kartenart. Gewählt ist die flache Heute-Karte, weil Lumen Fit dem Heute-Tab folgt. Lovea-Seiten mit der getönten Karte sehen etwas dunkler aus |
| Kartenform | Radius 16, `.continuous` (`App/Abstand.swift:15,20`) | `Rundung.karte` = 16 (`Gemeinsam/Design/Abstand.swift`) | ja |
| Abstände | 4, 8, 12, 16, 24 (`App/Abstand.swift:6-10`); Home: 16 / 16 (`Home/HomeView.swift:17,33`) | `Abstand.xs...xl` gleich | ja, schon gleich |
| Haupttext | `.primary` = Schwarz / Weiß | `text` = `#000000` / `#FFFFFF` | ja |
| Nebentext | `.secondary`, rund `#8A8A8E` hell, `#8D8D93` dunkel (Apple-Werte; `Health/Heute/HeuteView.swift:143`) | `text2` = `#8A8A8E` / `#8D8D93` | ja (hell fällt unter 4,5:1) |
| Trennlinie | Separator, `#C6C6C8` hell, `#38383A` dunkel (UIKit `opaqueSeparator`) | `haar` | ja (Hex aus der UIKit-Tabelle) |
| Muster / Hintergrund | keins in Health und Home | `MusterZeichner.hatMuster(.lovea)` = nein; `MusterFlaeche` zeichnet nichts, auch keine Streifen auf der Hauptkarte | ja (Herzmuster entfernt) |
| Verläufe auf Flächen | keine in den gelesenen Dateien (`Health/HealthStil.swift:40-41`: "flat") | keine | ja |
| Schatten | nur am Schalterknopf, `black 0.2, radius 1.5, y 1` (`App/GeleeEffekte.swift:100`) | `LoveaSchalterZeile` in `LumenFit/Sources/Design/Schalter.swift` | ja |
| Schalter | Spur Lovea-Rosa / `secondary` 30 %, weißer Knopf 27 pt, beim Drücken 35 pt breit, 51 x 31 pt, Zeile mindestens 44 pt, Haptik `auswahl`, Feder `jelly` (`App/GeleeEffekte.swift:64-106`) | `LumenSchalterStil` wechselt im Theme Lovea auf `LoveaSchalterZeile` | ja |
| Press-Zustand der Knöpfe | Skala 0,94, Rückfeder `jelly`; Reduce Motion: Deckkraft 0,6 (`App/Feder.swift:48-50`) | `FederKnopfStil` (`LumenFit/Sources/Design/Feder.swift`) | ja, schon gleich |
| Federn | `schnell` snappy 0,28; `weich` smooth 0,38; `federnd` bouncy 0,42 + 0,12; `jelly` spring 0,32 / 0,55 (`App/Feder.swift:7-18`) | `Feder.*` gleiche Werte | ja, schon gleich |
| Hauptknopf | System `.borderedProminent` mit Rosé-Tint (68 Stellen, z. B. `Health/SchlafCard.swift:210`) | `LumenHauptknopfStil`: Kapsel in `akzent`, Schrift `aufAkzent` (weiß), 44 pt hoch | Form und Farben ja. Das System-Aussehen (iOS-26-Politur, Druck-Animation) ist ungeprüft |
| Schrift | System; `.rounded` für Zahlen in Ringen (`Health/SchritteRinge.swift:23,29`) | `SchritteBogen`, `LumenBogen` nutzen `.rounded` für Zahlen; Rest System | ja, schon gleich |
| Zahlen-Übergang | `.contentTransition(.numericText)` (`Health/SchritteRinge.swift:27`, `Health/Heute/HeuteView.swift:190`) | `RollZahl`, `TagesformRing` | ja, schon gleich |
| Tagesform-Ring | Spur `Color.secondary.opacity(0.2)`, Strich 8, Rundkappe, Stufenfarbe grün / orange / rot, Zahl `0,38 x Durchmesser` fett (`Health/Heute/HeuteView.swift:180-190`) | `TagesformRing` (`LumenFit/Sources/Module/Heute/TagesformRing.swift`) | ja; die Spur war `haar`, jetzt wie Lovea |
| Formkacheln "Dein Tag" | Radius 20, Rand 10 / 6, Einheit `.tertiary`, Farben und Pfade der Formen (`Health/Heute/TagesFormen.swift:10-27,394-406`) | `TagesFormKachel` (`LumenFit/Sources/Module/Heute/TagesFormen.swift`) | Formfarben und Pfade waren schon gleich; Radius 20, Rand 10 / 6 und `.tertiary` übernommen |
| Zusatzzeile der Formkacheln | immer genau eine Zeile `caption2`, `.tertiary`, leer als Leerzeichen (`TagesFormen.swift:398`); Schritte "Ziel N" (`Health/Heute/HeuteView.swift:784`), Creatin "n/ziel Klicks" (`:843`), Gewicht "zuletzt x,x" (`:950`), Food (`:934`) | `TagesFormKachel.zusatz`, gesetzt in `TagesFormenReihe` für Schritte, Creatin, Gewicht | ja. Wasser, Koffein, Protein haben in Lovea keine Zusatzzeile. Food und Lovea-Wasser-Text "/N Gl." gibt es in Lumen Fit nicht als Kachel: nein |
| Karten-Tönung 14 % | `healthKarte(farbe)`: `secondarySystemBackground` + `farbe.opacity(0.14)`, Rand `farbe.opacity(0.7)` nur bei erhöhtem Kontrast (`Health/HealthStil.swift:42-54`). Farbe je Bereich: Schlaf Indigo (`Health/SchlafCard.swift:23`), Essen Türkis `ErnaehrungStil.akzent` (`Health/Ernaehrung/ErnaehrungView.swift:41`, `TagesNaehrwerte.swift:46`), Gym Mint (`Health/GymSession.swift:48`), Energie Amber (`Health/EnergieKarte.swift:63`), Coach Himmel / Mint / Indigo je Antwortkarte (`Health/Coach/CoachAntwortTeile.swift:93,198,242,277`), Habit nach `habit.tint` (`Health/HabitsSektion.swift:141`); Heute-Karten flach | Umgebungswert `kartenTint` (`Design/LoveaKarte.swift`), gesetzt je Tab in `App/RouteAnsicht.swift`; `ListenKarte` und die Kartenfläche `lumenKartenFlaeche()` (ersetzt in rund 50 Dateien das gleiche `.background(palette.flaeche, ...)`) tönen nur im Theme Lovea | teilweise. Eine Farbe je Bereich statt je Karte (Coach: Himmel statt Wechsel, Gym: Mint); Energie und Habit-Karten nicht eigens getönt; Heute bleibt flach wie in Lovea. Andere Themen unverändert |
| Gelee-Knopf (1,12 / 0,9) | nur am Senden-Knopf des Coach-Chats (`Health/Coach/CoachChatView.swift:714`) | `GeleeKnopfStil` (`Design/LoveaFeier.swift`) am Senden-Knopf in `CoachChatView`; nur im Theme Lovea gedehnt | ja, am gleichen Anlass. Die Hauptknöpfe sind in Lovea `borderedProminent`, nicht Gelee; dort gibt es also kein Gegenstück |
| Karten-Scroll (Skala 0,96, Deckkraft 0,5 am Rand) | Home- und Wir-Karten (`Home/PartnerTagCard.swift:33`, `Home/SchritteDuellCard.swift:28`, `Wir/FrageDesTagesCard.swift:33`, `Dates/UI/DatesKarte.swift:29` u. a.), nicht in Health | `karteScrollt()` (`Design/LoveaFeier.swift`) an `PartnerKarte`, dem Gegenstück der Partner-Karte; nur Theme Lovea; Bewegung aus: nur Überblenden | ja, an der einen Karte, die Lovea-Home-Karten entspricht |
| Ziel erreicht (Siegel, Herzen, Tick) | `ZielFeier` einmal pro Tag (`App/TagesMoment.swift:55-85`), genutzt an den Schritten (`Health/SchritteRinge.swift:131`); Bewegung reduzieren: nur Tick; Stromsparmodus: Siegel ohne Herzen | `LoveaZielFeier` + `LoveaHerzenSpritzer` (`Design/LoveaFeier.swift`) an `SchritteKarte` (Heute), Marke einmal pro Tag auf dem Gerät | ja, nur Theme Lovea. Die gleiche Feier für Trainingsende gibt es in Lovea nicht (nur Schritte und Serien) |
| Serie +1 (Hüpfer, Herzen) | `serieFeier` (`App/TagesMoment.swift:21`, `Health/HabitsSektion.swift:177`) | nein | nein, nicht nachgebaut: ob Lumen Fit eine Serienzahl in der Gewohnheitszeile zeigt, ist nicht geprüft |
| Zyklus (Palette, Hintergrund, Karte, Ring) | eigene Palette Zuckerrosa / Himbeere / Perlmutt, dunkel tiefes Beerenrot (`Zyklus/ZyklusStil.swift:6-27`), Verlauf mit Deko (`:82`, `ZyklusDeko.swift:67`), Perlmutt-Karte Radius 26, Rand 1,5, Schatten (`ZyklusStil.swift:119` ff.), Phasenfarben `ZyklusPhasenTon`, Herz im Ring | `Module/Zyklus/ZyklusLoveaStil.swift`: Palette, Hintergrund mit Deko, Karte, Phasenfarben und Herz im Ring; `lumenZyklusHintergrund()` auf allen Zyklus-Seiten | ja im Theme Lovea. Nicht übernommen: Schweben der Deko (kein Takt in Lumen Fit), Himbeere-Knopf `ZyklusKnopf` und `ZyklusChip` (Lumen-Fit-Zyklus nutzt `LumenHauptknopfStil` mit der Himbeere als `akzent` und `ZyklusWahlChip`, Form nicht verglichen), Ring als Fortschrittsring (Lumen Fit: Phasen-Ring mit Linienmustern, damit Farbe nie allein trägt) |
| Tab-Leiste | `.sidebarAdaptable`, schrumpft beim Abwärtsscrollen, Tint Rosé (`App/AppRootView.swift:205-207`) | `lumenTabLeiste()` in `LumenFit/Sources/Design/Leiste.swift`, nur im Theme Lovea | ja im Code; ob die Leiste im Lumen-Fit-Aufbau wirklich schrumpft, ist ungeprüft |
| Haptik | leicht / mittel / erfolg / auswahl / warnung, Schalter `Haptik.an` (`App/Feder.swift:57-68`) | `HaptikZentrale` mit gleicher Bedeutung, Schalter `haptikAn` | ja in der Bedeutung; der Lovea-Schalter gibt `auswahl` wie in Lovea |
| Gewohnheitsfarben | acht Töne hell / dunkel (`Health/HealthStil.swift:10-19`) | `HabitFarbeAnsicht.swift:9-16` | ja, die acht Paare sind gleich (verglichen) |
| Symbole und Gewicht | System-Symbole im Standardgewicht, `.semibold` nur an Einzelstellen (z. B. `Health/Heute/HeuteView.swift:276`) | `HeuteKartenKopf` u. a. | ungeprüft: nicht Stück für Stück verglichen |
| Schritte-Ring | geschlossen, Strich `0,11 x Seite`, Spur 16 %, Verlauf `0,7 -> 1`, zweite Runde halb so dick mit Schein, Personenfarbe (`Health/SchritteRinge.swift:40-62`) | `SchritteBogen`: offener 270-Grad-Bogen auf schwarzer Platte, Strich 20, Spur 22 % | nein. Anderes Bauteil, nicht nur ein Wert (Vorgabe "kein Aktivitätsring", `design.md` Abschnitt 2); eigener Auftrag, falls gewünscht |
| Drei Bögen der Ringplatte | gibt es in Lovea nicht | `LumenBogen` | nicht vergleichbar |
| Personenfarben | Rosé `#E0284A`, Blau `#2F6FE4`, hell wie dunkel (`App/Farben.swift:16,19`) | in Lumen Fit gibt es keine Personenfarbe | nein, kein Gegenstück |
| Schütteln bei Fehleingabe | `schuettelt(bei:)` (`App/GeleeEffekte.swift:7-42`), in Lovea nur am Ort-Link der Dates (`Dates/UI/DateIdeeOrtLink.swift:120`) | kein Gegenstück: Lumen Fit hat keine Dates | nein |
| Herzen-Spritzer | Reaktion im Chat, Banner, Notizen, Ziel und Serie | nur bei Ziel erreicht (siehe oben) | Chat, Banner, Notizen hat Lumen Fit nicht |
| Material / Glas | `.glass`-Knopf an 2 Stellen; sonst flache Karten, `loveaPille` ist absichtlich kein Material (`App/Farben.swift:7-9`) | `glassEffect` bei Avatar-Kapsel und Toast | ungeprüft; nicht je Theme unterschieden |
| Erscheinung (Hell/Dunkel) | folgt dem System | Auswahl System / Hell / Dunkel | bleibt Lumen-Fit-Funktion |
| Bewegung bei Stromsparmodus | `federnd` und `jelly` verlieren nur den Überschwinger; Herzen aus (`HerzenSpritzer.swift:13`, `TagesMoment.swift:54`) | im Theme Lovea: `bewegungAus` nur bei "Bewegung reduzieren" (`Design/Bewegung.swift`); Knopf, Lovea-Schalter und Toast nehmen unter Stromsparmodus `schnell` / `weich` statt der federnden Kurve; Herzen aus | ja im Theme Lovea. Andere Themen behalten die strengere Regel (alles aus) |

## Kontrast (WCAG AA, berechnet; `docs/research/kontrast.py`, `FarbenKontrastTests`)

| Paar | Lovea | Verhältnis | Im Theme |
|---|---|---|---|
| Akzent `#FF3B5C` auf Weiß / auf `#F2F2F7` (Text, Symbol) | durchgefallen | 3,48:1 / 3,12:1 (Lovea sagt es selbst, `App/Farben.swift:15`) | 1:1, Untergrenze 3:1 im Test |
| Weiße Schrift auf `#FF3B5C` (Knopf, hell und dunkel) | durchgefallen | 3,48:1 | 1:1 |
| `secondaryLabel` hell auf Weiß / `#F2F2F7` | durchgefallen | 3,44:1 / 3,08:1 | 1:1 |
| `secondaryLabel` dunkel auf Schwarz / `#1C1C1E` | hält | 6,36:1 / 5,16:1 | 1:1 |
| Akzent dunkel `#FF3B5C` auf Schwarz / `#1C1C1E` | hält | 6,03:1 / 4,89:1 | 1:1 |
| Lovea-eigene Abhilfe `#E0284A` (Personenfarbe, weiße Schrift) | hält auf Weiß | 4,59:1; auf `#F2F2F7` nur 4,12:1 | nicht benutzt |
| Schalterspur `#FF3B5C` auf Weiß / Schwarz | Bedienelement, 3:1 | 3,48:1 / 6,03:1 | 1:1, hält |
| Schalter aus (`secondary` 30 %) auf Weiß | durchgefallen | rund 1,7:1 (der Zustand steht auch an der Lage des Knopfs) | 1:1 |
| Stufenfarben im Tagesform-Ring (System-Grün / -Orange auf `#F2F2F7`) | durchgefallen als Grafik | 1,99:1 / 1,97:1; Zahl und Urteil stehen daneben | 1:1 |
| Einheit `.tertiary` in den Formkacheln | durchgefallen (grob 2:1, nicht genau gerechnet, Alpha-Farbe) | – | 1:1 |
| System-Orange als Text auf Karte, hell (`Health/Heute/HeuteView.swift:205`) | durchgefallen | 2,2:1 | ungeprüft, ob Lumen Fit solche Texte hat |

Die Lovea-Durchfaller sind Lovea-Befunde; in Lovea ist nichts geändert.

## Abweichungen, kurz

1. Karten-Tönung: eine Farbe je Bereich statt je Karte; Energie, Habit und Datenbereiche (Diagramm- und Balkenfarben in Schlaf, Essen, Gym) nicht auf Lovea-Farben gezogen, weil jede der vielen Stellen einen Themenwert bräuchte.
2. Schritte-Ring, Ringplatte, Bögen: anderes Bauteil, nicht umgebaut (Ahmeds Vorgabe: Schritte-Ring bleibt).
3. Trennlinie, Rand, Flächen-Hex: Apples UIKit-Tabelle statt Lovea-Code, weil Lovea System-Farben nur beim Namen nennt.
4. Das Herzmuster ist in Health und Home entfernt (dort gibt es keins); Zyklus hat die Herzen-Deko wie Lovea, ohne Schweben.
5. Kein Gegenstück: Schütteln (nur Dates), Serie-Feier, Chat- und Snap-Herzen, Gelee an Hauptknöpfen (Lovea nimmt dort `borderedProminent`).
6. Zyklus: `ZyklusKnopf` und `ZyklusChip` nicht nachgebaut.
7. Gym, Schlaf, Essen, Coach: Karten, Tönung, Radien und Farben der Bereiche verglichen und angepasst, soweit sie über die gemeinsame Kartenfläche laufen. Diagramme (Balken, Linien), Symbolgewichte und Bewegungen je Ansicht sind nicht Stück für Stück verglichen.

## Ungeprüft

Neu in dieser Runde, alles ohne Build und ohne Bild: die rund 50 ersetzten Kartenflächen (andere Themen sollten pixelgleich bleiben, ist nicht gesehen), Kontrast der Zyklus-Palette in Lumen Fit (Werte aus Lovea, dort als mindestens 7:1 und 4,5:1 genannt, hier nicht gerechnet), Ring-Phasenfarben auf Perlmutt (nicht gemessen; `follikel` `#E0703A` liegt rechnerisch nahe an 3:1), Sicht von `karteScrollt` auf `PartnerKarte`.

Swift kompiliert hier nicht. Gelaufen ist nur `swift-syntax-check`; es gab keinen Build, keinen Test und kein Bild. Nicht gesehen: 390 pt und 440 pt (an Maßen ändern sich die Schalterzeile, mindestens 44 pt hoch, die Formkacheln mit Zusatzzeile, Rand 10 / 6, Radius 20, und die Zyklus-Karten mit Radius 26), Tab-Leiste beim Scrollen, Schalter beim Drücken. Die CI nimmt jetzt auch das Theme `lovea`
auf (nur ein iPhone, keine zweite Breite). Der Server nimmt bei einer 200-Antwort ohne `erlaubt` (`{}`) die Freigabe zurück (`KontoDienst.swift:235`, nur gelesen), das passt nicht zum Test
`testAblehnungOderNetzfehlerNimmtDieFreigabeNichtZurueck` ("erst ein klares erlaubt:false nimmt sie zurück"). Dann verschwindet auch das Theme. Nur gemeldet, nicht geändert.
