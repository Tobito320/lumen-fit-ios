import Foundation

/// Eine Übung auf dem FitPassport: der beste Satz als geschätztes 1RM.
struct PassportKraft: Equatable, Identifiable, Sendable {
    let name: String
    /// Geschätztes Einer-Maximum nach Epley in kg, auf ganze kg gerundet.
    let e1rmKg: Int
    var id: String { name }
}

/// Idee 40: die teilbare Langzeitkarte mit Kraft, Schlaf und Konstanz. Nur eigene Werte: kein Partner, kein Freund, keine Namen Dritter.
/// Der eigene Name steht nur drauf, wenn der Aufrufer ihn mitgibt.
struct FitPassportDaten: Equatable, Sendable {
    let name: String?
    /// Die drei meistgemachten Übungen mit Gewicht.
    let kraft: [PassportKraft]
    /// Schnitt der Nächte der letzten 60 Tage in Minuten; nil ohne Nacht.
    let schlafSchnitt: Int?
    let schlafNaechte: Int
    /// Wochen mit Training von den letzten 18.
    let aktiveWochen: Int
    let serieWochen: Int
    let gymTage: Int
    let medaillen: Int
    let stufe: Int

    /// Die Aussage als Titel: "FitPassport: Stufe 4, 38 Gym-Tage".
    var titel: String { "FitPassport: Stufe \(stufe), \(gymTage) \(gymTage == 1 ? "Gym-Tag" : "Gym-Tage")" }

    /// Alles in Sätzen für VoiceOver und als Textvorschau beim Teilen.
    var sprechtext: String {
        var teile = [titel]
        if !kraft.isEmpty { teile.append("Kraft: " + kraft.map { "\($0.name) \($0.e1rmKg) kg" }.joined(separator: ", ")) }
        if let s = schlafSchnitt { teile.append("Schlaf im Schnitt \(Rueckblick.dauer(s)) in \(schlafNaechte) Nächten") }
        teile.append("Konstanz: \(aktiveWochen) von \(KonstanzRaster.wochen) Wochen, Serie \(serieWochen) \(serieWochen == 1 ? "Woche" : "Wochen")")
        teile.append("\(medaillen) von \(MeilensteinKatalog.anzahl) Medaillen")
        return teile.joined(separator: ". ")
    }
}

enum FitPassport {
    static let schlafTage = 60

    static func bauen(name: String?, sessions: [GymSession], gym: [String: Int], schlafMinuten: [String: Int], medaillen: Int, heute: String,
                      katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> FitPassportDaten {
        let kraft = KraftKurve.uebungen(sessions, katalog: katalog).prefix(3).compactMap { u -> PassportKraft? in
            let bester = sessions.flatMap(\.laeufe).filter { $0.uebung == u.id }.flatMap { KraftKurve.arbeitssaetze($0) }
                .compactMap(VerlaufLogik.e1rm).max()
            return bester.map { PassportKraft(name: u.name, e1rmKg: Int($0.rounded())) }
        }
        let ab = Datum.addTage(heute, -(schlafTage - 1))
        let naechte = schlafMinuten.filter { $0.key >= ab && $0.key <= heute && $0.value > 0 }.map(\.value)
        let tage = MeilensteinPruefung.trainingsTage(sessions, gym: gym)
        let raster = KonstanzRaster.gitter(sessions, gym: gym, heute: heute)
        let reinerName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return FitPassportDaten(name: reinerName?.isEmpty == false ? reinerName : nil, kraft: Array(kraft),
                                schlafSchnitt: naechte.isEmpty ? nil : naechte.reduce(0, +) / naechte.count, schlafNaechte: naechte.count,
                                aktiveWochen: raster.aktiveWochen, serieWochen: MeilensteinPruefung.serieWochen(tage: tage, heute: heute),
                                gymTage: tage.count, medaillen: medaillen, stufe: LumiStufe.stufe(erreicht: medaillen))
    }
}
