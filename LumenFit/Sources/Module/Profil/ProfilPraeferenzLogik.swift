import Foundation

/// Die Antworten der Einführung und der Präferenzen (Erfahrung, Ziele, Orte, Tage, Minuten, Fokus): Texte, Symbole und der fertige Plan daraus.
/// Rein, ohne Zustand. Gespeichert wird in `Einstellungen` (Tage in `Ziele.gymTageProWoche`).
enum ProfilPraeferenzLogik {
    static let tageBereich = 1...7
    static let minutenBereich = 30...120
    static let minutenSchritt = 15
    static let standardTage = 3
    static let standardMinuten = 60
    static let fokusHoechstens = 2
    /// Bis hierhin zählt ein Training als kurz: dann kommen zuerst die 45-Minuten-Pläne.
    static let kurzBisMinuten = 45
    /// Wählbare Fokus-Muskeln (ohne Nacken und Unterarme). Gesäß steckt in Beine (`MuskelGruppe` kennt es nicht einzeln).
    static let fokusWahl: [MuskelGruppe] = [.brust, .schulter, .bizeps, .trizeps, .ruecken, .bauch, .beine]

    // MARK: - Texte und Symbole

    static func titel(_ e: TrainingsErfahrung) -> String {
        switch e {
        case .geradeAngefangen: String(localized: "Ich fange gerade an")
        case .unterSechsMonate: String(localized: "Unter 6 Monaten")
        case .bisZweiJahre: String(localized: "6 Monate bis 2 Jahre")
        case .laenger: String(localized: "Länger als 2 Jahre")
        }
    }

    static func titel(_ z: TrainingsZiel) -> String {
        switch z {
        case .muskeln: String(localized: "Muskeln aufbauen")
        case .staerker: String(localized: "Stärker werden")
        case .abnehmen: String(localized: "Abnehmen")
        case .fitter: String(localized: "Fitter und gesünder")
        }
    }

    static func hinweis(_ z: TrainingsZiel) -> String {
        switch z {
        case .muskeln: String(localized: "Sichtbar mehr Muskeln")
        case .staerker: String(localized: "Mehr Gewicht schaffen")
        case .abnehmen: String(localized: "Ohne Kalorien zählen")
        case .fitter: String(localized: "Mehr Energie im Alltag")
        }
    }

    static func symbol(_ z: TrainingsZiel) -> String {
        switch z {
        case .muskeln: "figure.strengthtraining.traditional"
        case .staerker: "dumbbell.fill"
        case .abnehmen: "scalemass.fill"
        case .fitter: "heart.text.square.fill"
        }
    }

    static func titel(_ o: TrainingsOrt) -> String {
        switch o {
        case .studio: String(localized: "Fitnessstudio")
        case .zuhause: String(localized: "Zuhause")
        case .calisthenics: String(localized: "Calisthenics")
        }
    }

    static func hinweis(_ o: TrainingsOrt) -> String {
        switch o {
        case .studio: String(localized: "Geräte, Hanteln, Kabelzug")
        case .zuhause: String(localized: "Kurzhanteln, vielleicht eine Bank")
        case .calisthenics: String(localized: "Stange und Barren, im Studio oder im Park")
        }
    }

    static func symbol(_ o: TrainingsOrt) -> String {
        switch o {
        case .studio: "building.2.fill"
        case .zuhause: "house.fill"
        case .calisthenics: "figure.climbing"
        }
    }

    /// "Muskeln aufbauen, Abnehmen" oder "Nicht gewählt".
    static func zieleText(_ ziele: [TrainingsZiel]) -> String {
        ziele.isEmpty ? String(localized: "Nicht gewählt") : ziele.map(titel).formatted(.list(type: .and, width: .narrow))
    }

    static func orteText(_ orte: [TrainingsOrt]) -> String {
        orte.isEmpty ? String(localized: "Nicht gewählt") : orte.map(titel).formatted(.list(type: .and, width: .narrow))
    }

    static func erfahrungText(_ e: TrainingsErfahrung?) -> String { e.map(titel) ?? String(localized: "Nicht gewählt") }

    static func fokusText(_ fokus: [String]) -> String {
        let namen = fokus.compactMap { MuskelGruppe(rawValue: $0)?.name }
        return namen.isEmpty ? String(localized: "Ausgewogen") : namen.formatted(.list(type: .and, width: .narrow))
    }

    static func tageText(_ tage: Int) -> String { String(localized: "\(tage) mal pro Woche") }
    static func minutenText(_ minuten: Int) -> String { String(localized: "\(minuten) Minuten") }

    // MARK: - Auswahl

    /// Mehrfachwahl: drin wird raus, raus wird hinten angehängt.
    static func umschalten<T: Equatable>(_ liste: [T], _ wert: T) -> [T] {
        liste.contains(wert) ? liste.filter { $0 != wert } : liste + [wert]
    }

    /// Fokus: höchstens zwei. Ist schon zwei gewählt, fällt der zuerst gewählte heraus.
    static func fokusUmschalten(_ liste: [String], _ gruppe: MuskelGruppe) -> [String] {
        if liste.contains(gruppe.rawValue) { return liste.filter { $0 != gruppe.rawValue } }
        return Array((liste + [gruppe.rawValue]).suffix(fokusHoechstens))
    }

    static func minutenGerundet(_ wert: Int) -> Int {
        let gerundet = Int((Double(wert) / Double(minutenSchritt)).rounded()) * minutenSchritt
        return min(max(gerundet, minutenBereich.lowerBound), minutenBereich.upperBound)
    }

    // MARK: - Abbildung auf vorhandene Logik

    /// Zielart für Kalorien und Protein (`ProfilZielVorschlag`): Abnehmen gewinnt, dann Aufbauen (Muskeln oder stärker), sonst halten.
    static func zielart(_ ziele: [TrainingsZiel]) -> Zielart {
        if ziele.contains(.abnehmen) { return .abnehmen }
        if ziele.contains(.muskeln) || ziele.contains(.staerker) { return .aufbauen }
        return .halten
    }

    /// Ziel eines Splits (`SplitVorlage.ziel`): das erste Gewählte in fester Reihenfolge; ohne Wahl "muskeln" (Empfehlung der Einführung).
    static func splitZiel(_ ziele: [TrainingsZiel]) -> String {
        let reihenfolge: [(TrainingsZiel, String)] = [(.muskeln, "muskeln"), (.staerker, "kraft"), (.abnehmen, "definieren"), (.fitter, "fit")]
        return reihenfolge.first { ziele.contains($0.0) }?.1 ?? "muskeln"
    }

    /// Ausstattung eines Splits (`SplitVorlage.geraet`): Studio vor Zuhause (Kurzhanteln) vor Calisthenics (ohne Geräte); ohne Wahl Studio.
    static func splitGeraet(_ orte: [TrainingsOrt]) -> String {
        if orte.isEmpty || orte.contains(.studio) { return "studio" }
        return orte.contains(.zuhause) ? "kurzhantel" : "zuhause"
    }

    /// Der fertige Plan aus den Antworten über `SplitLogik.vorschlag`. Bis 45 Minuten zuerst die 45-Minuten-Pläne, sonst die normalen;
    /// gibt es dort keinen passenden, alle. Erfahrung und Fokus ändern den Split nicht (die Vorlagen kennen sie nicht).
    static func plan(_ e: Einstellungen, tage: Int, geschlecht: Geschlecht?, in liste: [SplitVorlage] = SplitKatalog.alle) -> SplitVorlage? {
        let kurz = (e.trainingsMinuten ?? standardMinuten) <= kurzBisMinuten
        let ziel = splitZiel(e.trainingsZiele), geraet = splitGeraet(e.trainingsOrte)
        let passend = liste.filter { SplitLogik.istKurzplan($0) == kurz }
        return SplitLogik.vorschlag(geschlecht, tage: tage, ziel: ziel, geraet: geraet, in: passend)
            ?? SplitLogik.vorschlag(geschlecht, tage: tage, ziel: ziel, geraet: geraet, in: liste)
    }
}
