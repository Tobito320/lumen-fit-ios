import SwiftUI

/// Der eine Schalter für Bewegung (SPEC 6, `design.md` 3.7 und 9). "Bewegung reduzieren" schaltet alles ab. Der Stromsparmodus schaltet Einfahren,
/// Überschwinger, Zahlenrollen und das Zeichnen der Diagramme ab, Lumi hüpft dann nur einmal. Reine Regeln hier, getestet ohne Oberfläche.
enum BewegungsRegel {
    /// Ruhig: keine Animation (kein Einfahren, kein Überschwinger, kein Zeichnen).
    nonisolated static func ruhig(reduziert: Bool, stromsparmodus: Bool) -> Bool { reduziert || stromsparmodus }

    /// Wie oft Lumi bei einem Ereignis hüpft: zweimal, im Stromsparmodus einmal, bei "Bewegung reduzieren" gar nicht.
    nonisolated static func huepfer(reduziert: Bool, stromsparmodus: Bool) -> Int {
        if reduziert { return 0 }
        return stromsparmodus ? 1 : 2
    }

    /// Ab den Schriftstufen für Bedienungshilfen passen die drei Bögen mit ihren Zahlen nicht mehr nebeneinander: dann die Balken (`LumenBalken`).
    nonisolated static func nutztBalken(_ schrift: DynamicTypeSize) -> Bool { schrift.isAccessibilitySize }
}

extension EnvironmentValues {
    /// Der Stromsparmodus ist an (gesetzt von `bewegungsSchalter()` an der Wurzel).
    @Entry var stromsparmodus: Bool = false
    /// "Bewegung reduzieren" oder Stromsparmodus. Alle Stellen, die Bewegung einfahren oder zeichnen, lesen diesen Wert statt `accessibilityReduceMotion`.
    @Entry var bewegungAus: Bool = false
}

/// Der Stromsparmodus als beobachtbarer Wert (`NSProcessInfoPowerStateDidChange`). Eine Instanz für die App; kein Timer, kein Dauerpolling.
@MainActor @Observable
final class StromsparBeobachter {
    static let geteilt = StromsparBeobachter()

    private(set) var an = ProcessInfo.processInfo.isLowPowerModeEnabled
    @ObservationIgnored private var beobachter: NSObjectProtocol?

    private init() {
        beobachter = NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.an = ProcessInfo.processInfo.isLowPowerModeEnabled }
        }
    }
}

private struct BewegungsSchalter: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduziert

    func body(content: Content) -> some View {
        let spar = StromsparBeobachter.geteilt.an
        content
            .environment(\.stromsparmodus, spar)
            .environment(\.bewegungAus, BewegungsRegel.ruhig(reduziert: reduziert, stromsparmodus: spar))
    }
}

extension View {
    /// An die Wurzel der App (und jede Wurzel, die für sich steht): setzt `stromsparmodus` und `bewegungAus`.
    func bewegungsSchalter() -> some View { modifier(BewegungsSchalter()) }
}

/// Lumi hüpft einmal je Ereignis (Rekord, Meilenstein): `anzahl` kleine Sprünge, wenn die Ansicht erscheint. Dekoration, keine Dauerbewegung.
struct LumiHuepfer: ViewModifier {
    let anzahl: Int
    var hoehe: CGFloat = 7
    @State private var versatz: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: versatz)
            .task {
                for _ in 0..<anzahl {
                    withAnimation(.easeOut(duration: 0.16)) { versatz = -hoehe }
                    try? await Task.sleep(for: .milliseconds(160))
                    withAnimation(.easeIn(duration: 0.16)) { versatz = 0 }
                    try? await Task.sleep(for: .milliseconds(180))
                }
            }
    }
}
