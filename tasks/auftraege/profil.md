AUFTRAG: Modul „profil“ (Profil: Onboarding, Profil-Blatt, Aussehen, Ziele, Sicherung, Quellen, Datenschutz, Export) der iOS-App Lumen Fit.

KONTEXT
Lumen Fit: iOS-App (SwiftUI, Swift 6, iOS 26, iPhone) für Gesundheit und Fitness, client-only (kein Server, keine Konten), Standard-Design monochrom, Figur Lumi. Repo /home/tobi/projects/lumen-fit-ios, Zweig modul/profil im eigenen Worktree, Grundgerüst ist gemergt. Lies zuerst CLAUDE.md, CONSTRAINTS.md, CONTEXT.md, SPEC.md (Abschnitte 5.3, 5.8, 5.9, 6, 11) und docs/research/design.md. Kein Mac: lokal nur swift-syntax-check, Compiler und Tests laufen im Integrationsschritt in CI (starte kein CI). Test zuerst, kleinster korrekter Diff. Quelle für Fertiges ist /home/tobi/projects/lovea-app-ios/Lovea/Sources (nur lesen, Lovea nie ändern; Portierungsregeln SPEC 5.8). Vorlage für Konfiguration war Bahnherz.

ZIEL
Das Profil-Blatt (Avatar-Kapsel auf jedem Tab) und das Onboarding: Profil anlegen in einer Minute, Themes wählen, Ziele und Körperdaten, Health-Zugriff, Datensicherung als Datei, Quellen und Lizenzen, Datenschutz, Export. Hier darf nichts nach Anmeldung aussehen: es gibt nach dem Anlegen nie wieder einen Anmeldebildschirm.

DEINE ORDNER (nur hier schreiben; alles andere ist tabu)
- LumenFit/Sources/Module/Profil/
- LumenFit/Tests/Module/Profil/
- LumenFit/Tests/Fixtures/Profil/

DU NUTZT AUS DEM GRUNDGERÜST (Namen stehen in SPEC 5.9)
- `AppUmgebung.profil` (`ProfilStore`: `anlegen`, `wechsle`, `pruefe`, `benenne`, `aenderePasswort`, `loesche`, `profile`, `aktiv`), `Passwort`, `daten.einstellungen` (`EinstellungenStore.aendere`), `daten.ziele` (`ZieleStore`, `Koerperdaten`), `gesundheit.zugriff`, `daten.raum`, `schluesselbund`, `router`
- Design: `LumiView`, `MusterFlaeche`, `Palette`, `LumenFarben`, `ThemaID`, `Erscheinung`, `AvatarKapsel`, `ListenKarte`, `Pille`, `HaptikZentrale`
- Lovea-Typen im Grundgerüst: `ErnaehrungsZiele` (Rechnung der Ziele aus Körperdaten)
- Stubs, die du ersetzt: `ProfilModul`, `OnboardingView`, `ProfilBlattView`, `AussehenView`, `ZieleView`, `DatensicherungView`, `QuellenView`. Der Wurzel-Entscheid "Onboarding oder Tabs" liegt im Grundgerüst (`AppRootView` nach `profil.hatProfil`)

AUS LOVEA PORTIEREN (unter Lovea/Sources/Health/, wenn nicht anders angegeben; Modus K kopieren, A anpassen, N neu, - nicht)
- Koerper/ZieleBefragung.swift (Ziele erfragen) [A] Tests: ZieleBefragungTests
- Einstellungen/EinstellungenView.swift und Health/Einstellung/* (nur als Inhaltsvorbild für Gruppen und Hinweise) [N]
- NICHT übernehmen: Profile/* (Figur, Zimmer, Punkte), alles zu Chat und Lovea-Konto [-]

NEU ZU BAUEN
- Onboarding in vier Karten (Willkommen mit Lumi, Name und Passwort mit Hinweis "Du meldest dich nie wieder an", ein Ziel, Health erlauben ohne Zwang) und Willkommen-zurück-Karte nach Neuinstallation (Profil im Schlüsselbund, Daten fehlen): "Datensicherung einspielen?"
- Profil-Blatt: Name ändern, Passwort ändern (Passwort-Abfrage mit Schütteln und `.error`), Profil wechseln (Passwort des Zielprofils), Profil anlegen, Alles löschen (Passwort, vorher Liste, was gespeichert war)
- `AussehenView`: fünf Theme-Karten mit Mini-Vorschau (Farbe, Muster), Erscheinung System/Hell/Dunkel, wirkt sofort über `EinstellungenStore`; Graphit und Glut wählen beim Aktivieren einmalig Dunkel vor
- `ZieleView` und Körperdaten (Größe, Geburtsjahr, Geschlecht optional, kg/lb) mit Vorschlägen aus `ErnaehrungsZiele`; Health-Zugriff-Seite je `HealthTyp` mit Grund und Weg in die Einstellungen
- `Datensicherung`: eine JSON-Datei `lumenfit-sicherung-<datum>.json` mit Version, Ops-Zeilen, `einstellungen`, `ziele`, `freigaben` (ohne Passwort-Spur); Teilen über das Share-Sheet, Einspielen mit Prüfung (Version, doppelte Op-Ids); Roundtrip-Test; `QuellenView` mit Open Food Facts (ODbL), BLS (CC BY 4.0, Datenstand), Übungsbilder, Apple-Frameworks; Datenschutz-Seite; CSV-Export von Training und Essen

IDEEN, DIE DU EINBAUST (alle müssen am Ende drin sein)
71. **Einstieg in einer Minute** – Name, Passwort, ein Ziel, Health erlauben; Lumi führt durch vier Karten.
72. **Profil-Blatt überall** – die Avatar-Kapsel auf jedem Tab öffnet das Profil; Name und Passwort ändern.
73. **Aussehen-Seite** – fünf Karten mit Mini-Vorschau (Farbe, Muster), Erscheinung System, Hell, Dunkel; wirkt sofort.
74. **Datensicherung als Datei** – alles als eine Datei teilen und auf dem neuen Gerät einspielen; nach einer Neuinstallation fragt die App von selbst danach.
75. **Health-Zugriff im Klartext** – je Datentyp ein Haken, warum die App ihn braucht, und der Weg in die Einstellungen.
76. **Körperdaten und Einheiten** – Größe, Geburtsjahr, Geschlecht (nur für Formeln, optional), kg oder lb.
77. **Ziele-Seite** – Schritte, Kalorien, Protein, Schlaf, Gym-Tage und Gewichtsziel an einem Ort, mit Vorschlägen.
78. **Quellen und Lizenzen** – Open Food Facts, BLS, Übungsbilder und Apple-Dienste mit Namensnennung und Datenstand.
79. **Datenschutz in Klartext** – was gespeichert wird, was das iPhone nie verlässt; "Alles löschen" mit Passwort.
80. **Tabellenexport** – Training und Essen als CSV zum Teilen.

FIXTURES
Fixtures/Profil: eine `sicherung-beispiel.json` (erfundene Daten) und ein Roundtrip-Test.

AKZEPTANZ
- Onboarding legt ein Profil an und zeigt danach nie wieder Passwort-Eingaben beim Start; Test mit `SpeicherSchluesselbund` und Neustart der `AppUmgebung`
- Neuinstallation-Fall getestet: Schlüsselbund-Profil da, Profilordner fehlt, Willkommen-zurück-Karte erscheint
- Theme-Wechsel wirkt ohne Neustart in allen zehn Kombinationen (Vorschau-Test auf `Palette`); die Standardwahl ist Monochrom/System
- Die Sicherung enthält keine Passwort-Spur; Einspielen ist idempotent (doppelte Op-Ids werden übersprungen)
- Quellen-Seite nennt BLS (CC BY 4.0) und Open Food Facts (ODbL) im Wortlaut; Datenschutz-Seite sagt, was das Gerät nie verlässt
- Gemeinsam: alle Ideen oben eingebaut oder mit Grund als nicht umsetzbar gemeldet; nur die eigenen Ordner geändert (`git diff --name-only main...modul/profil`); `swift-syntax-check` OK auf allen neuen Dateien; Namens-Gate und Umfang-Gate (CONSTRAINTS) leer; alle Stub-Dateien des Moduls ersetzt ("Kommt bald" kommt nirgends mehr vor); keine Unterdrückungen; alle Texte Deutsch ohne Emojis; jede portierte Datei trägt oben `// Quelle: Lovea Health/<Pfad>`.

TESTS
- `SicherungTests` (Roundtrip, Version, Idempotenz), `OnboardingFlussTests`, `WillkommenZurueckTests`, `ThemaWahlTests`, `CsvExportTests`
- Portierte Lovea-Tests laut Tabelle

ABSCHLUSSBERICHT
Kurz: geänderte Dateien, welche Idee wie umgesetzt ist, was nur Compiler oder Gerät beweist (ungeprüft), Wünsche ans Grundgerüst (du änderst es nie), Annahmen für SPEC Abschnitt 15.
