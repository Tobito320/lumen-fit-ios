import Foundation
import Observation

/// Ein Studio aus der Ortssuche: nur Name und Abstand. Koordinaten verlassen den Port nie und werden nie gespeichert.
struct StudioTreffer: Equatable, Sendable, Identifiable {
    var name: String
    /// Meter von der aktuellen Position; nil ohne Standort.
    var entfernungM: Double?
    var id: String { name }
}

/// Die Ortssuche hinter dem Studio-Feld. Echt: MapKit (`AppleStudioSuche`), in Tests ein Fake. Ohne Erlaubnis oder Netz liefert sie eine leere Liste oder Treffer ohne Abstand, nie einen Fehler.
@MainActor
protocol StudioSuchPort {
    func suche(text: String) async -> [StudioTreffer]
}

/// Ordnen und Filtern der Treffer, rein und ohne MapKit.
enum StudioSucheLogik {
    static let maxTreffer = 8
    /// Weiter weg ist es nicht "in der Nähe"; Treffer ohne Abstand bleiben.
    static let maxEntfernungM = 50_000.0

    /// Leere Namen raus, gleiche Namen nur einmal (der nähere), zu weit weg raus, nach Abstand sortiert (ohne Abstand ans Ende, sonst in Quellreihenfolge), höchstens `maxTreffer`.
    static func ordne(_ roh: [StudioTreffer]) -> [StudioTreffer] {
        var bester: [String: StudioTreffer] = [:]
        var reihenfolge: [String] = []
        for t in roh {
            let name = t.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, (t.entfernungM ?? 0) <= maxEntfernungM else { continue }
            let schluessel = name.lowercased()
            let neu = StudioTreffer(name: name, entfernungM: t.entfernungM)
            if let alt = bester[schluessel] {
                if (neu.entfernungM ?? .infinity) < (alt.entfernungM ?? .infinity) { bester[schluessel] = neu }
            } else {
                bester[schluessel] = neu
                reihenfolge.append(schluessel)
            }
        }
        let sortiert = reihenfolge.compactMap { bester[$0] }.enumerated().sorted { a, b in
            switch (a.element.entfernungM, b.element.entfernungM) {
            case let (x?, y?): return x != y ? x < y : a.offset < b.offset
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.offset < b.offset
            }
        }
        return sortiert.prefix(maxTreffer).map(\.element)
    }

    /// "350 m", "1,2 km", "12 km".
    static func entfernungText(_ meter: Double) -> String {
        if meter < 1000 { return "\(Int((meter / 10).rounded()) * 10) m" }
        if meter < 10_000 {
            let zehntel = Int((meter / 100).rounded())
            return "\(zehntel / 10),\(zehntel % 10) km"
        }
        return "\(Int((meter / 1000).rounded())) km"
    }
}

/// Hält die Treffer für das Studio-Feld. `aktualisiere` wird aus `.task(id:)` gerufen; ein abgebrochener Aufruf (neuer Buchstabe) schreibt nichts mehr.
@MainActor @Observable
final class StudioSucheModell {
    private(set) var treffer: [StudioTreffer] = []
    @ObservationIgnored private let port: StudioSuchPort
    /// Der Name, den die Person gerade aus der Liste gewählt hat: dafür keine neue Suche.
    @ObservationIgnored private var uebernommen: String?

    init(port: StudioSuchPort) {
        self.port = port
    }

    func aktualisiere(text: String) async {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t == uebernommen {
            treffer = []
            return
        }
        let roh = await port.suche(text: t)
        guard !Task.isCancelled else { return }
        treffer = StudioSucheLogik.ordne(roh)
    }

    func leeren() { treffer = [] }

    /// Der Name des gewählten Treffers; die Liste verschwindet.
    func uebernehme(_ t: StudioTreffer) -> String {
        uebernommen = t.name
        treffer = []
        return t.name
    }
}
