import Foundation

/// Essen zurück zu Lovea (09.11.2026): die Essen-Ops dieses Profils gehen über den Lumen-Server (`POST /lovea/ops`) in Loveas Raum, bei jedem Abgleich
/// nur die neuen (der Log hängt nur an: gemerkt ist, wie viele schon gesendet sind), dazu die Ernährungsziele als `einstellung.setzen ziel.ernaehrung.*`.
/// Läuft nur, wenn der Server den Export anschaltet (`essenExportAn`, erst wenn Lovea Essen wieder zeigt) und das Konto freigegeben ist.
/// Nach dem ersten vollen Lauf meldet die App "erledigt", damit die Lovea-Seite weiß, dass die Daten da sind.
enum LoveaEssenExport {
    nonisolated static let arten: Set<String> = ["essen.setzen", "lebensmittel.setzen", "lebensmittel.favorit", "rezept.setzen", "fasten.setzen", "fasten.eintrag",
                                                "fasten.plan", "food.anpassung", "koerper.setzen"]
    /// 50 Ops je Anfrage: der Server nimmt höchstens 256 KB und je Op 4 KB, 50 mal 4 KB passen sicher hinein.
    nonisolated static let paket = 50

    /// Die Ziele als Lovea-Einstellungen. Feste Kennung je Feld und Wert: ein zweiter Lauf schickt nichts doppelt (Lovea überspringt bekannte Ids),
    /// ein geänderter Wert kommt als neue Op an. Nie eingerichtete Ziele (nur geschätzt) gehen nicht raus.
    static func zielOps(_ z: ErnaehrungsZiele, von: ProfilID, zeit: Date) -> [Op] {
        guard z.eingerichtet else { return [] }
        return ErnaehrungsZiele.felder.map { feld in
            let wert = z.wert(feld)
            let d = (try? JSONEncoder().encode(["schluessel": JSONValue.string("ziel.ernaehrung.\(feld)"), "wert": JSONValue.number(Double(wert))])) ?? Data("{}".utf8)
            return Op(id: "lumenfit-ziel-\(feld)-\(wert)", art: "einstellung.setzen", von: von, zeit: zeit, d: d)
        }
    }

    /// Kurzform des Zielstands, um Wiederholungen zu erkennen.
    static func zieleStand(_ z: ErnaehrungsZiele) -> String? {
        z.eingerichtet ? ErnaehrungsZiele.felder.map { "\($0)=\(z.wert($0))" }.joined(separator: ",") : nil
    }

    /// Schickt die noch nicht gesendeten Essen-Ops (in Paketen) und geänderte Ziele. Rückgabe: Zahl der gesendeten Ops; nil, wenn nichts zu tun war
    /// oder der Weg fehlte (Netz, Server ohne Export). Bricht ein Paket ab, bleibt der Rest für den nächsten Abgleich.
    @MainActor @discardableResult
    static func starteWennOffen(konto: KontoDienst, daten: DatenSatz?, jetzt: Date) async -> Int? {
        guard konto.essenExportAn, let daten else { return nil }
        let alle = daten.raum.ops(arten: arten)
        var gesendet = konto.essenExportAnzahl
        var zaehler = 0
        while gesendet < alle.count {
            let teil = Array(alle[gesendet..<min(gesendet + paket, alle.count)])
            guard await konto.loveaOpsSenden(teil) == 200 else { return zaehler == 0 ? nil : zaehler }
            gesendet += teil.count
            zaehler += teil.count
            konto.essenExportMerken(anzahl: gesendet, ziele: konto.essenExportZiele)
        }
        let ziele = daten.essen.ernaehrungsZiele
        if let stand = zieleStand(ziele), stand != konto.essenExportZiele {
            guard await konto.loveaOpsSenden(zielOps(ziele, von: daten.profil, zeit: jetzt)) == 200 else { return zaehler == 0 ? nil : zaehler }
            konto.essenExportMerken(anzahl: gesendet, ziele: stand)
        }
        if !konto.essenExportErledigt { await konto.essenExportAbgeschlossen() }
        return zaehler
    }
}
