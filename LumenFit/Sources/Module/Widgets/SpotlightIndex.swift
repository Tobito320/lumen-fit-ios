import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// Die zwei Bereiche des Spotlight-Index. `uebungen` gilt für alle Profile und wird nur bei neuem Katalog oder neuer Version neu geschrieben,
/// `profil` (Pläne, Favoriten) gehört dem aktiven Profil und wird bei jeder Änderung und jedem Profilwechsel ganz ersetzt.
enum SpotlightBereich: String, Sendable {
    case uebungen = "com.onlyus.lumen-fit.spotlight.uebungen"
    case profil = "com.onlyus.lumen-fit.spotlight.profil"
}

/// Ein Eintrag für Spotlight. Die `kennung` ist der `lumenfit://`-Link der Seite: `LumenFitApp` öffnet ihn über `RouteURL.route(ausSpotlightKennung:)` (SPEC 5.9 Vertrag 8).
struct SpotlightEintrag: Equatable, Sendable {
    var kennung: String
    var titel: String
    var beschreibung: String
    var stichworte: [String]
}

/// Ziel der Einträge. In der App Core Spotlight, im Test ein Fake.
@MainActor
protocol SpotlightSenke {
    func ersetze(_ bereich: SpotlightBereich, durch eintraege: [SpotlightEintrag])
}

/// Idee 99: Übungen, Plan-Tage und Favoriten in der iPhone-Suche, ein Tipp öffnet die Seite. Der Bau der Einträge ist rein.
enum SpotlightIndex {
    nonisolated static let hoechstensFavoriten = 200

    /// Der Link der Route; `zusatz` macht die Kennung eindeutig, wenn mehrere Einträge auf dieselbe Seite führen (`RouteURL` liest unbekannte Felder nicht).
    static func kennung(_ route: Route, zusatz: (name: String, wert: String)? = nil) -> String {
        guard let zusatz, var komponenten = URLComponents(url: RouteURL.url(fuer: route), resolvingAgainstBaseURL: false) else {
            return RouteURL.url(fuer: route).absoluteString
        }
        komponenten.queryItems = (komponenten.queryItems ?? []) + [URLQueryItem(name: zusatz.name, value: zusatz.wert)]
        return komponenten.url?.absoluteString ?? RouteURL.url(fuer: route).absoluteString
    }

    /// Jede Übung des Katalogs (deutscher und englischer Name suchbar), öffnet `.uebung(id:)`.
    static func uebungen(_ katalog: [Uebung]) -> [SpotlightEintrag] {
        var gesehen = Set<String>()
        return katalog.compactMap { u in
            let k = kennung(.uebung(id: u.id))
            guard gesehen.insert(k).inserted else { return nil }
            return SpotlightEintrag(kennung: k, titel: u.name, beschreibung: String(localized: "Übung · \(u.muskel) · \(u.geraet)"),
                                    stichworte: [u.name, u.en, u.koerper, u.geraet, "Übung", "Lumen Fit"])
        }
    }

    /// Jeder Trainingstag des Plans, öffnet die Pläne im Gym.
    static func plaene(_ plan: TrainingsPlan) -> [SpotlightEintrag] {
        plan.tage.map { tag in
            SpotlightEintrag(kennung: kennung(.gym(.plaene), zusatz: ("tag", tag.id)), titel: tag.name,
                             beschreibung: String(localized: "Trainingstag · \(TrainingLogik.wochentageText(tag.wochentage)) · \(tag.uebungen.count) Übungen"),
                             stichworte: [tag.name, "Plan", "Training", "Lumen Fit"])
        }
    }

    /// Favoriten aus dem Essen (Lebensmittel und Mahlzeiten), öffnet die Favoriten.
    static func favoriten(_ liste: [Lebensmittel]) -> [SpotlightEintrag] {
        var gesehen = Set<String>()
        return liste.prefix(hoechstensFavoriten).compactMap { l in
            guard gesehen.insert(l.id).inserted else { return nil }
            return SpotlightEintrag(kennung: kennung(.essen(.favoriten), zusatz: ("id", l.id)), titel: l.name,
                                    beschreibung: [String(localized: "Favorit"), l.marke].compactMap { $0 }.joined(separator: " · "),
                                    stichworte: [l.name, "Favorit", "Essen", "Lumen Fit"])
        }
    }

    /// Stempel des Übungs-Index: ändert sich Katalog oder App-Version, wird neu geschrieben, sonst nicht (rund 1.300 Einträge nicht bei jedem Start).
    static func uebungenStempel(anzahl: Int, version: String) -> String { "\(version)-\(anzahl)" }
}

/// Schreibt in den Core-Spotlight-Index der App. Aufträge laufen nacheinander, damit zwei schnelle Änderungen sich nicht überholen.
@MainActor
final class CoreSpotlightSenke: SpotlightSenke {
    private var laufend: Task<Void, Never>?

    func ersetze(_ bereich: SpotlightBereich, durch eintraege: [SpotlightEintrag]) {
        let vorher = laufend
        laufend = Task {
            await vorher?.value
            await Self.schreibe(bereich, eintraege)
        }
    }

    /// Alles in einer nichtisolierten Funktion: die Suchobjekte entstehen und verschwinden hier (kein Sendable-Übergang).
    nonisolated private static func schreibe(_ bereich: SpotlightBereich, _ eintraege: [SpotlightEintrag]) async {
        let index = CSSearchableIndex.default()
        try? await index.deleteSearchableItems(withDomainIdentifiers: [bereich.rawValue])
        guard !eintraege.isEmpty else { return }
        let objekte = eintraege.map { eintrag -> CSSearchableItem in
            let attribute = CSSearchableItemAttributeSet(contentType: .item)
            attribute.title = eintrag.titel
            attribute.contentDescription = eintrag.beschreibung
            attribute.keywords = eintrag.stichworte
            let objekt = CSSearchableItem(uniqueIdentifier: eintrag.kennung, domainIdentifier: bereich.rawValue, attributeSet: attribute)
            objekt.expirationDate = .distantFuture
            return objekt
        }
        try? await index.indexSearchableItems(objekte)
    }
}

/// Der Stempel der Übungen auf der Platte (`spotlight-stand.json` im Gruppenordner).
struct SpotlightStand: Codable, Equatable, Sendable {
    var uebungen: String?
}

/// Hält den Index aktuell: Übungen nur bei neuem Stempel, Pläne und Favoriten des aktiven Profils bei jeder Änderung (Vergleich vor dem Schreiben).
/// Ohne Profil wird der Profil-Bereich geleert.
@MainActor
final class SpotlightPflege {
    private let umgebung: AppUmgebung
    private let senke: any SpotlightSenke
    private let katalog: () -> [Uebung]
    private let version: String
    private var letzteProfilEintraege: [SpotlightEintrag]?

    init(umgebung: AppUmgebung, senke: any SpotlightSenke, katalog: @escaping () -> [Uebung] = { UebungsKatalog.alle },
         version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") {
        self.umgebung = umgebung
        self.senke = senke
        self.katalog = katalog
        self.version = version
    }

    func aktualisiere() {
        aktualisiereUebungen()
        let daten = umgebung.daten
        let eintraege = daten.map { SpotlightIndex.plaene($0.training.plan) + SpotlightIndex.favoriten($0.essen.favoriten) } ?? []
        guard eintraege != letzteProfilEintraege else { return }
        letzteProfilEintraege = eintraege
        senke.ersetze(.profil, durch: eintraege)
    }

    private func aktualisiereUebungen() {
        let liste = katalog()
        guard !liste.isEmpty else { return }
        let stempel = SpotlightIndex.uebungenStempel(anzahl: liste.count, version: version)
        let datei = JSONDatei<SpotlightStand>(umgebung.ordner.appendingPathComponent("spotlight-stand.json"))
        guard datei.lade()?.uebungen != stempel else { return }
        senke.ersetze(.uebungen, durch: SpotlightIndex.uebungen(liste))
        datei.speichere(SpotlightStand(uebungen: stempel))
    }
}
