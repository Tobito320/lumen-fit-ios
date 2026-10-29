AUFTRAG: Lovea-Runde nach Lumen Fit (eigene Runde in `~/projects/lovea-app-ios`, nicht Teil des Lumen-Fit-Baus).
Start erst, wenn Ahmed die Runde ausdrücklich verlangt. Bis dahin bleibt Lovea unverändert; die Partner-Karte in Lumen Fit läuft über Quelle A (Loveas vorhandene `widget-stand.json`).

ZIEL
Lovea und Lumen Fit tauschen die Dateien aus SPEC 5.5 (Vertrag B) im Ordner `<group.com.onlyus.lovea>/LumenFit/`, ohne dass beide Apps um das Band kämpfen.

SCHRITTE (in dieser Reihenfolge, jeder für sich mit Lovea-Test und CI)
1. `zusammenfassung.json` (version 1) lesen: Freigaben und `heute` zeigen, unbekannte oder kaputte Datei = nichts zeigen. Nur Zusammenfassungen, nie Rohdaten.
2. `partner.json` (version 1, gleiche Form wie `zusammenfassung.json`) schreiben; Quelle A bleibt als Rückfall, solange die Datei fehlt.
3. Band: Lovea liest `band-status.json`. Meldet Lumen Fit `verbunden: true`, vibriert Lovea nicht selbst, sondern schreibt einen Wunsch nach `band-wuensche.json` (`id`, `muster`, `zeit`, `von`). `band-erledigt.json` zeigt, welche Wünsche gelaufen sind. Wünsche, die älter als 15 Minuten sind, verfallen (Lumen Fit tut das auch).
4. Erst nach Gerätetest mit beiden Apps: Band-Code und die Health-Module aus Lovea entfernen (Lumen Fit hat sie).
5. Paar-Karte (Schritte-Duell) auf die Dateien umstellen.
6. Apple-Seite prüfen: die App-ID von Lumen Fit hat beide Gruppen; Loveas App-IDs bleiben unberührt.
7. Zum Schluss in Lumen Fit `VerbindenTexte.loveaTauschtDateien` auf `true` setzen (die Zusatzsätze "Lovea zeigt sie erst nach einem eigenen Update" verschwinden), Test `VerbindenTexteTests.testStandHeuteIstOhneLoveaRunde` anpassen, TestFlight-Build.

PRÜFUNG
- Ein Gerät mit beiden Apps: Freigabe "Schritte" einschalten, Lovea zeigt sie; ausschalten, Lovea zeigt nichts.
- Band: nur eine App hält es; ein Wunsch aus Lovea kommt am Band an, `band-erledigt.json` trägt seine Id.
- Ohne Lumen Fit auf dem Gerät läuft Lovea wie vorher.

GRENZEN
Keine Namen oder Adressen von Menschen im Git. Kein Kaufen, kein Senden an Menschen. Keine Wecker oder Erinnerungen in Lumen Fit.
