import Foundation

/// Namen, Einheiten und Symbole der Vitalwerte im Schlaf-Tab.
enum SchlafVitalInfo {
    static func name(_ art: VitalArt) -> String {
        switch art {
        case .ruhepuls: "Ruhepuls"
        case .hrv: "HRV"
        case .sauerstoff: "SpO2"
        case .atemfrequenz: "Atmung"
        case .temperatur: "Temperatur"
        case .vo2max: "VO2max"
        }
    }

    static func einheit(_ art: VitalArt) -> String {
        switch art {
        case .ruhepuls, .atemfrequenz: "/min"
        case .hrv: "ms"
        case .sauerstoff: "%"
        case .temperatur: "°C"
        case .vo2max: "ml/kg/min"
        }
    }

    /// Für VoiceOver ausgeschrieben.
    static func sprechEinheit(_ art: VitalArt) -> String {
        switch art {
        case .ruhepuls: "Schläge pro Minute"
        case .atemfrequenz: "Atemzüge pro Minute"
        case .hrv: "Millisekunden"
        case .sauerstoff: "Prozent"
        case .temperatur: "Grad Celsius"
        case .vo2max: "Milliliter pro Kilogramm und Minute"
        }
    }

    static func stellen(_ art: VitalArt) -> Int {
        switch art {
        case .ruhepuls, .hrv, .sauerstoff: 0
        case .atemfrequenz, .temperatur, .vo2max: 1
        }
    }

    static func symbolName(_ art: VitalArt) -> String {
        switch art {
        case .ruhepuls: "heart.fill"
        case .hrv: "bolt.heart.fill"
        case .sauerstoff: "lungs.fill"
        case .atemfrequenz: "wind"
        case .temperatur: "thermometer.medium"
        case .vo2max: "figure.run"
        }
    }

    /// "54 /min", "36,4 °C".
    static func text(_ art: VitalArt, _ wert: Double) -> String {
        let zahl = SchlafFormat.zahl(wert, stellen: stellen(art))
        return art == .sauerstoff ? "\(zahl) %" : "\(zahl) \(einheit(art))"
    }

    static func sprechText(_ art: VitalArt, _ wert: Double) -> String {
        "\(SchlafFormat.zahl(wert, stellen: stellen(art))) \(sprechEinheit(art))"
    }
}

/// Idee 54, HRV im eigenen Bereich: der Bereich ist dein Mittelwert der letzten 60 Tage plus minus eine Streuung, nicht eine fremde Norm.
/// Der aktuelle Wert (der neueste der 60 Tage) zählt nicht zum Bereich, sonst misst er sich an sich selbst; sein Alter steht im Text, wenn er nicht von heute oder gestern ist.
/// Unter 14 Werten gibt es keinen Bereich ("zu wenig Daten"); es wird nichts erfunden.
struct PersoenlicherBereich: Equatable, Sendable {
    static let tage = 60
    static let mindestWerte = 14
    /// Ein Wert von heute oder gestern gilt als frisch (nur auf frische Werte stützt sich der Erholungs-Satz).
    static let frischTage = 1

    enum Lage: Equatable, Sendable {
        case niedrig, normal, hoch

        var name: String {
            switch self {
            case .niedrig: "unter deinem Bereich"
            case .normal: "in deinem Bereich"
            case .hoch: "über deinem Bereich"
            }
        }
    }

    enum Trend: Equatable, Sendable {
        case hoeher, gleich, tiefer

        var symbolName: String {
            switch self {
            case .hoeher: "arrow.up"
            case .gleich: "arrow.right"
            case .tiefer: "arrow.down"
            }
        }
    }

    let art: VitalArt
    /// Mittelwert der Werte der letzten 60 Tage ohne den aktuellen.
    let mittel: Double
    /// Standardabweichung (Stichprobe) derselben Werte.
    let streuung: Double
    /// Anzahl der Werte hinter Mittel und Streuung.
    let anzahl: Int
    let aktuell: Double
    let aktuellTag: String

    /// Der neueste Wert der Art im 60-Tage-Fenster (heute eingeschlossen). Viele Nutzer haben VO2max oder SpO2 nur alle paar Tage.
    static func aktuellerWert(_ werte: [VitalMesswert], art: VitalArt, heute: String) -> VitalMesswert? {
        let ab = Datum.addTage(heute, -(tage - 1))
        return werte.filter { $0.art == art && $0.wert.isFinite && $0.tag >= ab && $0.tag <= heute }.max { $0.tag < $1.tag }
    }

    /// Werte der Art je Tag im 60-Tage-Fenster, je Tag zählt der zuletzt genannte.
    static func werteImFenster(_ werte: [VitalMesswert], art: VitalArt, heute: String) -> [String: Double] {
        let ab = Datum.addTage(heute, -(tage - 1))
        var jeTag: [String: Double] = [:]
        for w in werte where w.art == art && w.wert.isFinite && w.tag >= ab && w.tag <= heute { jeTag[w.tag] = w.wert }
        return jeTag
    }

    /// Von heute oder gestern.
    func istFrisch(heute: String) -> Bool { aktuellTag >= Datum.addTage(heute, -Self.frischTage) }

    /// `nil` ohne aktuellen Wert oder unter 14 Werten im Bereich.
    static func berechne(werte: [VitalMesswert], art: VitalArt, heute: String) -> PersoenlicherBereich? {
        guard let jetzt = aktuellerWert(werte, art: art, heute: heute) else { return nil }
        let basis = Array(werteImFenster(werte, art: art, heute: heute).filter { $0.key != jetzt.tag }.values)
        guard basis.count >= mindestWerte else { return nil }
        let mittel: Double = basis.reduce(0, +) / Double(basis.count)
        let quadrate: Double = basis.reduce(0) { (summe: Double, wert: Double) in summe + (wert - mittel) * (wert - mittel) }
        let varianz: Double = quadrate / Double(basis.count - 1)
        return PersoenlicherBereich(art: art, mittel: mittel, streuung: varianz.squareRoot(), anzahl: basis.count, aktuell: jetzt.wert, aktuellTag: jetzt.tag)
    }

    /// Abstand zum Mittel in Streuungen. Ohne Streuung (alle Werte gleich) gilt jede Abweichung als deutlich (3), keine als 0: nie durch 0 teilen.
    var abstandInStreuungen: Double {
        let unterschied = aktuell - mittel
        if abs(unterschied) < 1e-9 { return 0 }
        guard streuung > 1e-9 else { return unterschied > 0 ? 3 : -3 }
        return unterschied / streuung
    }

    var lage: Lage {
        let z = abstandInStreuungen
        if z < -1 { return .niedrig }
        if z > 1 { return .hoch }
        return .normal
    }

    /// Pfeil gegen deinen Schnitt: ab einer halben Streuung Abstand hoch oder runter.
    var trend: Trend {
        let z = abstandInStreuungen
        if z < -0.5 { return .tiefer }
        if z > 0.5 { return .hoeher }
        return .gleich
    }

    /// Abweichung vom Schnitt in Prozent, gerundet (positiv = darüber).
    var abweichungProzent: Int {
        guard abs(mittel) > 1e-9 else { return 0 }
        return Int(((aktuell - mittel) / abs(mittel) * 100).rounded())
    }

    /// Lage des Punkts im Bereich von 0 bis 1: Mitte ist dein Schnitt, die Ränder sind zwei Streuungen entfernt.
    var position: Double { min(1, max(0, 0.5 + abstandInStreuungen / 4)) }

    var untereGrenze: Double { max(0, mittel - streuung) }
    var obereGrenze: Double { mittel + streuung }

    /// "52 bis 74 ms".
    var bereichText: String {
        let stellen = SchlafVitalInfo.stellen(art)
        return "\(SchlafFormat.zahl(untereGrenze, stellen: stellen)) bis \(SchlafFormat.zahl(obereGrenze, stellen: stellen)) \(SchlafVitalInfo.einheit(art))"
    }

    /// "Mit 68 ms liegst du in deinem Bereich (52 bis 74 ms)."
    var lageSatz: String {
        "Mit \(SchlafVitalInfo.text(art, aktuell)) liegst du \(lage.name) (\(bereichText))."
    }

    /// Satz für den Chip: "4 % über deinem Schnitt".
    var schnittText: String {
        let p = abweichungProzent
        if p == 0 { return "wie dein Schnitt" }
        return "\(abs(p)) % \(p > 0 ? "über" : "unter") deinem Schnitt"
    }
}

/// Ein Werte-Chip (Idee 55): der aktuelle Wert einer Art und, wenn es genug Werte gibt, sein Bereich.
struct SchlafVitalStand: Equatable, Sendable, Identifiable {
    let art: VitalArt
    let aktuell: VitalMesswert?
    let bereich: PersoenlicherBereich?
    /// Werte der Art im 60-Tage-Fenster (ohne den aktuellen).
    let vorhanden: Int
    let heute: String

    var id: VitalArt { art }

    /// Chips in der Reihenfolge des Auftrags (die HRV hat ihren eigenen Bereich).
    static let chipArten: [VitalArt] = [.ruhepuls, .sauerstoff, .atemfrequenz, .temperatur, .vo2max]

    static func bauen(art: VitalArt, werte: [VitalMesswert], heute: String) -> SchlafVitalStand {
        let jetzt = PersoenlicherBereich.aktuellerWert(werte, art: art, heute: heute)
        let basis = PersoenlicherBereich.werteImFenster(werte, art: art, heute: heute).filter { $0.key != jetzt?.tag }.count
        return SchlafVitalStand(art: art, aktuell: jetzt, bereich: PersoenlicherBereich.berechne(werte: werte, art: art, heute: heute), vorhanden: basis, heute: heute)
    }

    /// "vom 18.09.", wenn der aktuelle Wert nicht von heute oder gestern ist; sonst `nil`.
    var datumHinweis: String? {
        guard let aktuell, aktuell.tag < Datum.addTage(heute, -PersoenlicherBereich.frischTage) else { return nil }
        return "vom \(SchlafFormat.kurzesDatum(aktuell.tag))"
    }

    /// Der Bereich, wenn er auf einem Wert von heute oder gestern steht (für den Erholungs-Satz).
    var frischerBereich: PersoenlicherBereich? { bereich.flatMap { $0.istFrisch(heute: heute) ? $0 : nil } }

    /// Text unter dem Wert: der Trend gegen den Schnitt, oder was fehlt.
    var untertitel: String {
        guard aktuell != nil else { return "Keine Daten" }
        let hinweis = datumHinweis.map { " · \($0)" } ?? ""
        if let bereich { return bereich.schnittText + hinweis }
        return "Zu wenig Daten für deinen Schnitt (\(vorhanden) von \(PersoenlicherBereich.mindestWerte))" + hinweis
    }

    /// Ein Satz für VoiceOver mit Name, Wert und Trend.
    var sprechSatz: String {
        guard let aktuell else { return "\(SchlafVitalInfo.name(art)): keine Daten. In Health prüfen." }
        return "\(SchlafVitalInfo.name(art)) \(SchlafVitalInfo.sprechText(art, aktuell.wert)), \(untertitel)"
    }
}
