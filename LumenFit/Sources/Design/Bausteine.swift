import SwiftUI

/// Kleine Kapsel mit Text und optional Symbol (Filter, Status). Status steht immer mit Symbol und Text, nie nur in Farbe.
struct Pille: View {
    let text: String
    let symbolName: String?
    @Environment(\.palette) private var palette

    init(text: String, symbolName: String? = nil) {
        self.text = text
        self.symbolName = symbolName
    }

    var body: some View {
        HStack(spacing: Abstand.xs) {
            if let symbolName { Image(systemName: symbolName).accessibilityHidden(true) }
            Text(text)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(palette.text)
        .padding(.horizontal, Abstand.m)
        .padding(.vertical, Abstand.s)
        .background(palette.flaeche, in: .capsule)
        .overlay(Capsule().stroke(palette.haar, lineWidth: 1))
    }
}

/// Leerzustand: Lumi, ein Satz, eine Handlung.
struct LeerZustand: View {
    let stimmung: LumiStimmung
    let satz: String
    let handlung: String?
    let aktion: (@MainActor () -> Void)?
    @Environment(\.palette) private var palette

    init(stimmung: LumiStimmung, satz: String, handlung: String? = nil, aktion: (@MainActor () -> Void)? = nil) {
        self.stimmung = stimmung
        self.satz = satz
        self.handlung = handlung
        self.aktion = aktion
    }

    var body: some View {
        VStack(spacing: Abstand.l) {
            LumiView(stimmung: stimmung, groesse: 120)
            Text(satz)
                .font(.body)
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.center)
            if let handlung, let aktion {
                Button(handlung) { aktion() }
                    .buttonStyle(.lumenHauptknopf)
                    .frame(minHeight: Abstand.tippflaeche)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Abstand.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stimmung.beschreibung). \(satz)")
    }
}

/// Fehler, die helfen: was schiefging und was jetzt hilft. Symbol und Text, Warnfarbe nur hier.
struct FehlerKarte: View {
    let titel: String
    let hilfe: String
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema

    var body: some View {
        HStack(alignment: .top, spacing: Abstand.m) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(LumenFarben.farbe(schema == .dark ? 0xFFB340 : 0x8F4B00))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Abstand.xs) {
                Text(titel).font(.headline).foregroundStyle(palette.text)
                Text(hilfe).font(.subheadline).foregroundStyle(palette.text2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Diagramm mit Aussage als Titel und der Kernzeile darunter. Den `accessibilityChartDescriptor` setzt der Aufrufer am Chart.
/// Kein Muster hinter dem Diagramm: die Marks müssen lesbar bleiben.
struct DiagrammKarte<Inhalt: View>: View {
    let aussage: String
    let kernzeile: String
    let inhalt: Inhalt
    @Environment(\.palette) private var palette

    init(aussage: String, kernzeile: String, @ViewBuilder inhalt: () -> Inhalt) {
        self.aussage = aussage
        self.kernzeile = kernzeile
        self.inhalt = inhalt()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text(aussage).font(.headline).foregroundStyle(palette.text)
            Text(kernzeile).font(.subheadline).foregroundStyle(palette.text2)
            inhalt
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
    }
}

/// Zahl, die beim ersten Anzeigen von 0 hochrollt (0,8 s) und danach bei Änderung in 0,38 s nachzieht. Reduce Motion: sofort.
struct RollZahl: View {
    let wert: Double
    let format: FloatingPointFormatStyle<Double>
    @State private var angezeigt: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let aktuell = angezeigt ?? 0
        Text(aktuell, format: format)
            .monospacedDigit()
            .contentTransition(.numericText(value: aktuell))
            .onAppear {
                guard angezeigt == nil else { return }
                if reduceMotion { angezeigt = wert } else { withAnimation(.smooth(duration: 0.8)) { angezeigt = wert } }
            }
            .onChange(of: wert) { _, neu in
                if reduceMotion { angezeigt = neu } else { withAnimation(Feder.weich) { angezeigt = neu } }
            }
            .accessibilityLabel(Text(wert, format: format))
    }
}

struct ToastInhalt: Equatable, Sendable {
    var titel: String
    var zeile: String?
    var stimmung: LumiStimmung
}

private struct ToastModifier: ViewModifier {
    @Binding var inhalt: ToastInhalt?
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = inhalt {
                    HStack(spacing: Abstand.m) {
                        LumiView(stimmung: toast.stimmung, groesse: 36)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(toast.titel).font(.headline)
                            if let zeile = toast.zeile { Text(zeile).font(.subheadline).foregroundStyle(palette.text2) }
                        }
                    }
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, Abstand.l)
                    .padding(.vertical, Abstand.m)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.top, Abstand.s)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .accessibilityElement(children: .combine)
                }
            }
            .animation(reduceMotion ? nil : Feder.federnd, value: inhalt)
            .haptik(.erfolg, bei: inhalt)
            .task(id: inhalt) {
                guard inhalt != nil else { return }
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { inhalt = nil }
            }
    }
}

extension View {
    /// Toast mit Lumi, steht 3 s, gleitet ein, Haptik `.erfolg`.
    func lumenToast(_ inhalt: Binding<ToastInhalt?>) -> some View {
        modifier(ToastModifier(inhalt: inhalt))
    }
}
