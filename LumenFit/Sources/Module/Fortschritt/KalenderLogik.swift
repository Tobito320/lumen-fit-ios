import Foundation

/// Ein Tag im Monatsraster des Kalenders. `geplant` ist der Name des Plantags, nur für heute und kommende Tage.
struct KalenderTag: Equatable, Identifiable, Sendable {
    var datum: String
    var id: String { datum }
    var trainiert: Bool
    var geplant: String?
    var partnerTrainiert: Bool
    var partnerGeplant: Bool
    var heute: Bool
    var imMonat: Bool
}

/// Reine Logik des Kalenders im Training: Raster Mo bis So, Trainings rückwärts, Plan nur nach vorn, Partner-Marken.
enum KalenderLogik {
    static let monatsnamen = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]

    /// `monat` als `yyyy-MM`. Das Raster beginnt am Montag der Woche des 1. und endet am Sonntag der Woche des Letzten.
    static func tage(monat: String, sessions: [GymSession], plan: TrainingsPlan, partnerTage: [String], partnerPlan: PartnerPlan?, heute: String) -> [KalenderTag] {
        let erster = monat + "-01"
        let letzter = Datum.addTage(naechster(monat, schritt: 1) + "-01", -1)
        let anfang = Datum.montagDerWoche(erster)
        let ende = Datum.addTage(Datum.montagDerWoche(letzter), 6)
        let trainiert = Set(sessions.map { Datum.text($0.start) })
        let partnerGemacht = Set(partnerTage)
        return (0...max(0, Datum.tageZwischen(anfang, ende))).map { i in
            let datum = Datum.addTage(anfang, i)
            let kommend = datum >= heute
            let wochentag = Datum.wochentag(datum)
            return KalenderTag(
                datum: datum, trainiert: trainiert.contains(datum),
                geplant: kommend ? TrainingLogik.tag(plan, datum: datum)?.name : nil,
                partnerTrainiert: partnerGemacht.contains(datum),
                partnerGeplant: kommend && (partnerPlan?.tage.contains { $0.wochentage.contains(wochentag) } ?? false),
                heute: datum == heute, imMonat: datum.hasPrefix(monat))
        }
    }

    /// "November 2026"; ein kaputter Text kommt unverändert zurück.
    static func monatText(_ monat: String) -> String {
        guard let (jahr, nummer) = teile(monat) else { return monat }
        return "\(monatsnamen[nummer - 1]) \(jahr)"
    }

    /// Der Monat `schritt` Monate später (negativ: früher), wieder als `yyyy-MM`.
    static func naechster(_ monat: String, schritt: Int) -> String {
        guard let (jahr, nummer) = teile(monat) else { return monat }
        let index = jahr * 12 + (nummer - 1) + schritt
        return String(format: "%04d-%02d", index / 12, index % 12 + 1)
    }

    /// VoiceOver je Tag, etwa "9. November, heute, trainiert, Partner geplant".
    static func sprechtext(_ t: KalenderTag) -> String {
        let nummer = Int(t.datum.suffix(2)) ?? 0
        let monatsname = Int(t.datum.dropFirst(5).prefix(2)).flatMap { (1...12).contains($0) ? monatsnamen[$0 - 1] : nil } ?? ""
        var worte = ["\(nummer). \(monatsname)"]
        if t.heute { worte.append("heute") }
        if t.trainiert { worte.append("trainiert") }
        if let geplant = t.geplant { worte.append("geplant: \(geplant)") }
        if !t.trainiert && t.geplant == nil { worte.append("kein Training") }
        if t.partnerTrainiert { worte.append("Partner trainiert") }
        if t.partnerGeplant { worte.append("Partner geplant") }
        return worte.joined(separator: ", ")
    }

    private static func teile(_ monat: String) -> (Int, Int)? {
        let t = monat.split(separator: "-").compactMap { Int($0) }
        guard t.count == 2, (1...12).contains(t[1]), t[0] >= 0 else { return nil }
        return (t[0], t[1])
    }
}
