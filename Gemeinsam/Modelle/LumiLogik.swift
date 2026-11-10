import Foundation

/// Die Lage des Tages, aus der `LumiLogik` Lumis Zustand wählt. Nur Werte aus vorhandenen Daten (Heute rechnet sie aus).
/// Zustände, die an einem Ort feststehen (willkommen im Onboarding, anfeuern und pause im Training, denkt beim Coach), setzt der Ort selbst.
struct LumiLage: Equatable, Sendable {
    var heute: String
    /// Stunde in Berlin (0 bis 23).
    var stunde: Int
    /// Tage mit Training (Einheiten und Gym-Haken).
    var trainingsTage: Set<String> = []
    /// Heute ein neuer Bestwert (geschätztes 1RM) bei einer Übung.
    var rekordHeute = false
    var minutenHeute = 0
    /// Mittlere Anstrengung (RPE) der Sätze von heute; Ersatz für das Gefühl nach dem Training.
    var rpeSchnittHeute: Double? = nil
    /// Eigenes Gefühl zum Tag (Tagesform, 1 leer bis 5 voll).
    var gefuehlHeute: Int? = nil
    var serieWochen = 0
    var wochenzielErreicht = false
    /// Alle Bögen der Ringplatte sind voll.
    var boegenVoll = false
    var schlafMinuten: Int? = nil
    /// Morgen-Check von heute, 1 (schwer) bis 5 (top).
    var morgenCheck: Int? = nil
    var ruhetag = false
    /// Gilt, wenn keine Regel greift (die Stimmung des Morgensatzes: bereit, müde oder denkt).
    var basis: LumiZustand = .bereit
}

/// Welcher Lumi-Zustand heute gilt. Reine Regeln in fester Reihenfolge, die erste passende gewinnt.
enum LumiLogik {
    /// Unter so vielen Minuten Schlaf ist die Nacht kurz.
    static let kurzeNacht = 360
    /// So viele Tage ohne Training, dann vermisst Lumi dich.
    static let vermisstAb = 7
    /// So viele Tage Pause vor einem Training machen es zum Neustart (Muskelkater danach).
    static let neustartNach = 7

    static func zustand(_ l: LumiLage) -> LumiZustand {
        if l.stunde >= 23 || l.stunde < 5 { return .schlaeft }
        if l.trainingsTage.contains(l.heute) {
            if l.rekordHeute { return .stolz }
            let schwer: Bool = (l.rpeSchnittHeute ?? 0) >= 9 || l.minutenHeute > 90
            let leer: Bool = (l.gefuehlHeute ?? 3) <= 2 || (l.morgenCheck ?? 3) <= 2
            if schwer || leer { return .erschoepft }
            if l.wochenzielErreicht && l.serieWochen >= 2 { return .serie }
            return .ziel
        }
        if l.boegenVoll { return .ziel }
        if (l.schlafMinuten.map { $0 < kurzeNacht } ?? false) || (l.morgenCheck ?? 3) <= 2 { return .muede }
        if muskelkater(l) { return .muskelkater }
        if l.ruhetag { return .ruhetag }
        if vermisst(l) { return .vermisst }
        return l.basis
    }

    /// Der letzte Trainingstag war gestern oder vorgestern und ein Neustart: davor `neustartNach` Tage ohne Training (oder das erste Training überhaupt).
    static func muskelkater(_ l: LumiLage) -> Bool {
        for zurueck in [1, 2] {
            let tag = Datum.addTage(l.heute, -zurueck)
            guard l.trainingsTage.contains(tag) else { continue }
            return !(1...neustartNach).contains { l.trainingsTage.contains(Datum.addTage(tag, -$0)) }
        }
        return false
    }

    /// Es gab schon Training, aber heute und in den `vermisstAb - 1` Tagen davor keins.
    static func vermisst(_ l: LumiLage) -> Bool {
        guard !l.trainingsTage.isEmpty else { return false }
        return !(0..<vermisstAb).contains { l.trainingsTage.contains(Datum.addTage(l.heute, -$0)) }
    }
}
