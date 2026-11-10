import AppIntents

/// Die zwei Aktionen des Steuerelements im Kontrollzentrum (auch für die Aktionstaste): Training starten oder Essen scannen.
enum SchnellzugriffAktion: String, AppEnum, Sendable, CaseIterable {
    case training, scan

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Aktion" }

    static var caseDisplayRepresentations: [SchnellzugriffAktion: DisplayRepresentation] {
        [.training: DisplayRepresentation(title: "Training starten", image: .init(systemName: "figure.strengthtraining.traditional")),
         .scan: DisplayRepresentation(title: "Essen scannen", image: .init(systemName: "barcode.viewfinder"))]
    }

    var titel: String {
        switch self {
        case .training: String(localized: "Training starten")
        case .scan: String(localized: "Essen scannen")
        }
    }

    var symbolName: String {
        switch self {
        case .training: "figure.strengthtraining.traditional"
        case .scan: "barcode.viewfinder"
        }
    }
}

/// Der Knopf des Steuerelements: öffnet die App (`openAppWhenRun`) und führt die gewählte Aktion über die Haken aus (`KurzbefehlHaken`, gesetzt von `WidgetsModul.start`).
/// Liegt in `Gemeinsam`, damit App und Widget-Ziel ihn kompilieren; `perform()` läuft im Prozess der App.
struct SchnellzugriffIntent: AppIntent {
    static var title: LocalizedStringResource { "Schnellzugriff" }
    static var isDiscoverable: Bool { false }
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Aktion", default: .training) var aktion: SchnellzugriffAktion

    init() {}

    init(aktion: SchnellzugriffAktion) {
        self.aktion = aktion
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        switch aktion {
        case .training: KurzbefehlHaken.trainingStarten?()
        case .scan: KurzbefehlHaken.oeffne?(.essen(.scan))
        }
        return .result()
    }
}
