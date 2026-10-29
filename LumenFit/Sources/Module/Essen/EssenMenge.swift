import Foundation

/// Rechnen für den Portion-Schieber (Idee 46): Gramm, Stück (Portionsnamen wie "ganze, mittelgroß") oder Portion, ohne Oberfläche.
enum EssenMenge {
    /// Gramm oder Milliliter, die `zahl` in dieser Einheit bedeutet.
    static func gramm(_ zahl: Double, _ option: MengenOption) -> Double {
        switch option {
        case .portion(let p): zahl * p.gramm
        case .gramm, .milliliter: zahl
        }
    }

    /// Dieselbe Menge in einer anderen Einheit: 150 g werden bei "ganze, 50 g" zu 3 Stück. Portionen auf Viertel gerundet (mindestens ein Viertel),
    /// Gramm auf ganze Gramm (mindestens 1).
    static func umrechnen(_ zahl: Double, von: MengenOption, nach: MengenOption) -> Double {
        let g = gramm(zahl, von)
        switch nach {
        case .gramm, .milliliter:
            return max(1, g.rounded())
        case .portion(let p):
            guard p.gramm > 0 else { return 1 }
            return max(0.25, (g / p.gramm * 4).rounded() / 4)
        }
    }

    /// Schrittweite des Schiebers.
    static func schritt(_ option: MengenOption) -> Double {
        if case .portion = option { return 0.25 }
        return 5
    }

    /// Bereich des Schiebers; ein getippter Wert darf darüber liegen.
    static func bereich(_ option: MengenOption) -> ClosedRange<Double> {
        if case .portion = option { return 0...10 }
        return 0...1000
    }

    /// Menge, mit der das Detailblatt startet: letzte Menge, sonst die erste mittlere Portion, sonst 100 g oder ml.
    static func start(_ l: Lebensmittel, letzte: (menge: Double, einheit: Einheit)?) -> (option: MengenOption, zahl: Double) {
        if let letzte {
            return (MengenOption.auswahl(einheit: letzte.einheit, portionName: l.portionName, l: l), letzte.menge)
        }
        let portionen = ErnaehrungLogik.portionsAuswahl(l)
        if let teeloeffel = portionen.first(where: { $0.name == "Teelöffel, gestrichen" }) { return (.portion(teeloeffel), 1) }
        if let erste = portionen.first(where: { $0.name.contains("mittel") }) ?? portionen.first { return (.portion(erste), 1) }
        return (l.fluessig ? .milliliter : .gramm, 100)
    }
}
