import Foundation

/// Der Vorschlag fürs nächste Training (Idee 34): was heute dran ist, wie lange, und warum.
struct TrainingsVorschlag: Equatable, Sendable {
    let art: NaechstesTraining.Art
    let minuten: Int
    /// "Heute Beine, 45 Minuten".
    let titel: String
    /// Ein Satz mit den echten Zahlen: "Beine sind zu 100 Prozent erholt, Brust und Schulter erst zu 55 Prozent."
    let begruendung: String
    /// Richtwert Sätze, die in die Zeit passen (`ZeitSchaetzung.saetze(inMinuten:)`).
    let saetze: Int
}

/// Frischeste Muskeln plus verfügbare Zeit ergeben "Heute Beine, 45 Minuten". Der heutige Plantag gewinnt, solange seine Muskeln erholt genug sind.
enum NaechstesTraining {
    /// Vier Arten Training, jede aus den Muskelgruppen, die dabei arbeiten.
    enum Art: CaseIterable, Sendable {
        case beine, druecken, ziehen, rumpf

        var name: String {
            switch self {
            case .beine: "Beine"
            case .druecken: "Brust und Schulter"
            case .ziehen: "Rücken und Bizeps"
            case .rumpf: "Bauch"
            }
        }

        var gruppen: [MuskelGruppe] {
            switch self {
            case .beine: [.beine]
            case .druecken: [.brust, .schulter, .trizeps]
            case .ziehen: [.ruecken, .bizeps, .nacken]
            case .rumpf: [.bauch]
            }
        }

        /// Die Art, zu der eine Gruppe gehört; Unterarme laufen beim Ziehen mit.
        static func fuer(_ g: MuskelGruppe) -> Art {
            allCases.first { $0.gruppen.contains(g) } ?? .ziehen
        }
    }

    /// Ab so vielen Prozent gilt ein Plantag als erholt genug, um ihn dem frischesten Training vorzuziehen.
    static let planSchwelle = 60
    /// Mindestens und höchstens, was ein Vorschlag an Minuten nennt.
    static let minutenBereich = 15...120

    /// Mittlere Erholung einer Art in Prozent: ein Teil ohne Eintrag gilt als erholt (100), der Mittelwert über die Gruppen (`gruppenErholung` je Gruppe).
    static func erholung(_ art: Art, _ erholung: [MuskelTeil: Int]) -> Int {
        let werte = art.gruppen.map { KoerperLogik.gruppenErholung(erholung, $0) }
        return werte.reduce(0, +) / max(werte.count, 1)
    }

    /// Die Art des Plantags: die häufigste Art seiner Hauptmuskeln. Ohne Übungen nil.
    static func art(_ tag: TrainingsTag, katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> Art? {
        let arten = tag.uebungen.compactMap { katalog($0.uebung).flatMap(KoerperLogik.haupt)?.gruppe }.map(Art.fuer)
        guard !arten.isEmpty else { return nil }
        let zaehler = Dictionary(grouping: arten, by: { $0 }).mapValues(\.count)
        return Art.allCases.filter { zaehler[$0] != nil }.max { (zaehler[$0] ?? 0) < (zaehler[$1] ?? 0) }
    }

    /// Ohne erfasste Erholung und ohne Plantag gibt es keinen Vorschlag (die Ansicht zeigt dann den Leerzustand).
    static func vorschlag(erholung: [MuskelTeil: Int], plantag: TrainingsTag?, minuten: Int,
                          katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> TrainingsVorschlag? {
        let zeit = min(max(minuten, minutenBereich.lowerBound), minutenBereich.upperBound)
        let prozent = Dictionary(uniqueKeysWithValues: Art.allCases.map { ($0, Self.erholung($0, erholung)) })
        let geplant = plantag.flatMap { art($0, katalog: katalog) }
        let frischeste = Art.allCases.max { (prozent[$0] ?? 0) < (prozent[$1] ?? 0) }
        guard let frischeste else { return nil }
        if erholung.isEmpty && geplant == nil { return nil }

        let gewaehlt: Art
        var begruendung: String
        if let geplant, (prozent[geplant] ?? 0) >= planSchwelle || geplant == frischeste {
            gewaehlt = geplant
            begruendung = "Das steht heute im Plan, und \(geplant.name) \(verb(geplant)) zu \(prozent[geplant] ?? 0) Prozent erholt."
            let andere = Art.allCases.filter { $0 != geplant }.min { (prozent[$0] ?? 0) < (prozent[$1] ?? 0) }
            if let andere, (prozent[andere] ?? 100) < 90 {
                begruendung += " \(andere.name) \(verb(andere)) erst zu \(prozent[andere] ?? 0) Prozent erholt."
            }
        } else {
            gewaehlt = frischeste
            begruendung = "\(gewaehlt.name) \(verb(gewaehlt)) zu \(prozent[gewaehlt] ?? 0) Prozent erholt, am meisten von allen."
            if let geplant {
                begruendung += " Dein Plan sieht \(geplant.name) vor, aber \(geplant.name) \(verb(geplant)) erst zu \(prozent[geplant] ?? 0) Prozent erholt."
            }
        }
        return TrainingsVorschlag(art: gewaehlt, minuten: zeit, titel: "Heute \(gewaehlt.name), \(zeit) Minuten", begruendung: begruendung, saetze: ZeitSchaetzung.saetze(inMinuten: zeit))
    }

    /// "ist" für eine Gruppe, "sind" für mehrere ("Beine sind", "Bauch ist").
    private static func verb(_ art: Art) -> String { art == .rumpf ? "ist" : "sind" }
}
