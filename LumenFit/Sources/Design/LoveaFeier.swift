import SwiftUI

/// Freudenmomente des Themas Lovea (Quelle: Lovea `App/TagesMoment.swift`, `App/HerzenSpritzer.swift`): kleine Herzen platzen einmal,
/// höchstens einmal pro Tag und Anlass. Bewegung reduzieren: nur der Tick. Stromsparmodus: Siegel ohne Herzen. Andere Themen: nichts.
enum LoveaTagesMoment {
    /// true genau einmal pro Tag und Schlüssel (und merkt sich das auf dem Gerät).
    static func einmalHeute(_ schluessel: String, jetzt: Date = Date(), speicher: UserDefaults = .standard) -> Bool {
        let komponenten = Calendar.current.dateComponents([.year, .month, .day], from: jetzt)
        let heute = "\(komponenten.year ?? 0)-\(komponenten.month ?? 0)-\(komponenten.day ?? 0)"
        let key = "lumenfit.lovea.moment.\(schluessel)"
        guard speicher.string(forKey: key) != heute else { return false }
        speicher.set(heute, forKey: key)
        return true
    }
}

/// Kleine Herzen platzen einmal aus der Mitte und blenden aus (0,6 s). Kein Timer, keine Schleife.
struct LoveaHerzenSpritzer: View {
    var anzahl = 7
    var radius: CGFloat = 54
    var groesse: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var bewegungReduziert
    @Environment(\.stromsparmodus) private var spar
    @State private var los = false

    private var aus: Bool { bewegungReduziert || spar }

    var body: some View {
        ZStack {
            if !aus {
                ForEach(0..<anzahl, id: \.self) { i in herz(i) }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !aus else { return }
            withAnimation(.easeOut(duration: 0.6)) { los = true }
        }
    }

    private func herz(_ i: Int) -> some View {
        let winkel = Double(i) / Double(anzahl) * 2 * Double.pi
        let weite = radius * (i % 2 == 0 ? 1 : 0.7)
        return Image(systemName: "heart.fill")
            .font(.system(size: groesse))
            .foregroundStyle(i % 2 == 0 ? LumenFarben.loveaRose : Color.pink)
            .scaleEffect(los ? 1 : 0.3)
            .opacity(los ? 0 : 1)
            .offset(x: los ? CGFloat(cos(winkel)) * weite : 0, y: los ? CGFloat(sin(winkel)) * weite : 0)
    }
}

/// Ziel erreicht: ein Siegel federt kurz auf, Herzen platzen, ein Erfolgs-Tick. Einmal pro Tag und `schluessel`, höchstens 1,2 s.
/// Nur im Thema Lovea sichtbar (sonst leer).
struct LoveaZielFeier: View {
    let erreicht: Bool
    let schluessel: String
    @Environment(\.lumenThema) private var thema
    @Environment(\.accessibilityReduceMotion) private var bewegungReduziert
    @State private var zeigen = false
    @State private var huepf = 0
    @State private var tick = 0

    var body: some View {
        ZStack {
            if zeigen {
                LoveaHerzenSpritzer(anzahl: 8, radius: 60, groesse: 14)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(LumenFarben.loveaRose)
                    .symbolEffect(.bounce, options: .nonRepeating, value: huepf)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .haptik(.erfolg, bei: tick)
        .task(id: erreicht) {
            guard thema == .lovea, erreicht, LoveaTagesMoment.einmalHeute(schluessel) else { return }
            tick += 1
            guard !bewegungReduziert else { return }
            withAnimation(Feder.federnd) { zeigen = true }
            huepf += 1
            try? await Task.sleep(for: .seconds(1.1))
            withAnimation(Feder.weich) { zeigen = false }
        }
    }
}

/// Knopf dehnt sich beim Antippen wie Gelee (x 1,12, y 0,9) und federt zurück (Lovea `GeleeEffekte.swift`). Bewegung aus: nur abgedunkelt.
/// Nur im Thema Lovea gedehnt, sonst wie `.plain`.
struct GeleeKnopfStil: ButtonStyle {
    @Environment(\.bewegungAus) private var reduceMotion
    @Environment(\.stromsparmodus) private var spar
    @Environment(\.lumenThema) private var thema

    func makeBody(configuration: Configuration) -> some View {
        let gelee = thema == .lovea
        configuration.label
            .scaleEffect(x: gelee && configuration.isPressed && !reduceMotion ? 1.12 : 1, y: gelee && configuration.isPressed && !reduceMotion ? 0.9 : 1)
            .opacity(gelee && configuration.isPressed && reduceMotion ? 0.6 : 1)
            .animation(reduceMotion || spar || configuration.isPressed ? Feder.schnell : Feder.jelly, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GeleeKnopfStil {
    static var gelee: GeleeKnopfStil { GeleeKnopfStil() }
}

/// Karten blenden und skalieren dezent am Rand des Scrollbereichs (Lovea `KartenScroll.swift`). Nur im Thema Lovea; Bewegung aus: nur Überblenden.
private struct LoveaKartenScroll: ViewModifier {
    @Environment(\.lumenThema) private var thema
    @Environment(\.bewegungAus) private var ohneSkala

    func body(content: Content) -> some View {
        if thema == .lovea {
            content.scrollTransition(.interactive) { karte, phase in
                let rand = abs(phase.value)
                return karte.opacity(1 - 0.5 * rand).scaleEffect(ohneSkala ? 1 : 1 - 0.04 * rand)
            }
        } else {
            content
        }
    }
}

extension View {
    func karteScrollt() -> some View { modifier(LoveaKartenScroll()) }
}
