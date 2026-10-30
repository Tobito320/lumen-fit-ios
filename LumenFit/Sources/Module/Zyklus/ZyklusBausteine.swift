// Quelle: Lovea Zyklus/ZyklusStil.swift, ZyklusSymptomeAuswahl.swift (neu im Lumen-Design: Palette, Muster statt nur Farbe, keine Deko)
import SwiftUI

// MARK: - Namen der Auswahlwerte

extension ZyklusBlutung {
    var eintragTitel: String {
        switch self {
        case .schmierblutung: "Schmier"
        case .leicht: "Leicht"
        case .mittel: "Mittel"
        case .stark: "Stark"
        }
    }
}

extension ZyklusSymptom {
    var eintragTitel: String {
        switch self {
        case .kopfschmerzen: "Kopf"
        case .kraempfe: "Krämpfe"
        case .rueckenschmerzen: "Rücken"
        case .brustspannen: "Brust"
        case .uebelkeit: "Übelkeit"
        case .blaehbauch: "Blähbauch"
        case .akne: "Akne"
        case .muedigkeit: "Müdigkeit"
        case .heisshunger: "Heißhunger"
        case .schwindel: "Schwindel"
        case .verstopfung: "Verstopfung"
        case .durchfall: "Durchfall"
        }
    }
}

extension ZyklusStimmung {
    var eintragTitel: String {
        switch self {
        case .froehlich: "Fröhlich"
        case .ruhig: "Ruhig"
        case .energiegeladen: "Voller Energie"
        case .empfindlich: "Empfindlich"
        case .gereizt: "Gereizt"
        case .traurig: "Traurig"
        case .aengstlich: "Ängstlich"
        case .gestresst: "Gestresst"
        }
    }
}

extension ZyklusAusfluss {
    var eintragTitel: String {
        switch self {
        case .keiner: "Keiner"
        case .klebrig: "Klebrig"
        case .cremig: "Cremig"
        case .waessrig: "Wässrig"
        case .eiweissartig: "Eiweißartig"
        }
    }
}

extension ZyklusTest {
    var eintragTitel: String { self == .positiv ? "Positiv" : "Negativ" }
}

extension ZyklusSex {
    var eintragTitel: String { self == .geschuetzt ? "Geschützt" : "Ungeschützt" }
}

// MARK: - Phasen: Name, Symbol, Farbe und Muster

/// Wie eine Phase aussieht. Die Farbe trägt nie allein die Aussage: dazu kommen Symbol, Name und ein eigenes Linienmuster im Ring und im Kalender.
enum ZyklusPhaseStil {
    static func name(_ phase: ZyklusPhase) -> String {
        switch phase {
        case .periode: "Periode"
        case .follikel: "Follikelphase"
        case .fruchtbar: "Fruchtbare Tage"
        case .eisprung: "Eisprung"
        case .luteal: "Lutealphase"
        }
    }

    static func symbol(_ phase: ZyklusPhase) -> String {
        switch phase {
        case .periode: "drop.fill"
        case .follikel: "leaf.fill"
        case .fruchtbar: "sparkle"
        case .eisprung: "sun.max.fill"
        case .luteal: "moon.fill"
        }
    }

    /// Eigene Farben für Linien und Flächen (Kontrast zur Karte mindestens 3:1), nie als Text.
    static func farbe(_ phase: ZyklusPhase, dunkel: Bool) -> Color {
        let hex: UInt32 = switch phase {
        case .periode: dunkel ? 0xFF6B8E : 0xB3123F
        case .follikel: dunkel ? 0xF2B34A : 0x9A5B00
        case .fruchtbar: dunkel ? 0xC3A2F5 : 0x6B3FA0
        case .eisprung: dunkel ? 0x4FDCD2 : 0x007A74
        case .luteal: dunkel ? 0xA7B3C2 : 0x5E6B7A
        }
        return LumenFarben.farbe(hex)
    }

    /// Linienmuster im Ring (Strich, Lücke): voll, lang gestrichelt, gepunktet, voll, kurz gestrichelt.
    nonisolated static func strichmuster(_ phase: ZyklusPhase) -> [CGFloat] {
        switch phase {
        case .periode, .eisprung: []
        case .follikel: [10, 5]
        case .fruchtbar: [1, 7]
        case .luteal: [4, 4]
        }
    }
}

// MARK: - Ring

/// Der Phasen-Ring: der ganze Zyklus als Kreis, jede Phase mit eigener Farbe und eigenem Linienmuster, ein Punkt zeigt den heutigen Tag.
/// Zahl und Beschriftung stehen in der Mitte. Der Punkt wandert beim Erscheinen einmal an seinen Platz (Reduce Motion: sofort).
struct ZyklusRingAnsicht: View {
    let abschnitte: [ZyklusRingLogik.Abschnitt]
    let fortschritt: Double
    let phase: ZyklusPhase?
    let titel: String
    let untertitel: String
    var beschreibung: String?

    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.bewegungAus) private var bewegungAus
    @ScaledMetric(relativeTo: .largeTitle) private var durchmesser: CGFloat = 232
    @ScaledMetric(relativeTo: .largeTitle) private var strich: CGFloat = 16
    @State private var angezeigt: Double?

    var body: some View {
        let dunkel = schema == .dark
        let anteil = min(max(angezeigt ?? (bewegungAus ? fortschritt : 0), 0), 1)
        ZStack {
            Circle().stroke(palette.haar, lineWidth: strich)
            ForEach(Array(abschnitte.enumerated()), id: \.offset) { _, a in
                Circle()
                    .trim(from: a.von + 0.004, to: max(a.von + 0.004, a.bis - 0.004))
                    .stroke(ZyklusPhaseStil.farbe(a.phase, dunkel: dunkel),
                            style: StrokeStyle(lineWidth: strich, lineCap: .butt, dash: ZyklusPhaseStil.strichmuster(a.phase)))
                    .rotationEffect(.degrees(-90))
            }
            if !abschnitte.isEmpty {
                Circle()
                    .fill(palette.text)
                    .overlay(Circle().stroke(palette.grund, lineWidth: 3))
                    .frame(width: strich + 8, height: strich + 8)
                    .offset(y: -(durchmesser / 2))
                    .rotationEffect(.degrees(360 * anteil))
            }
            VStack(spacing: Abstand.xs) {
                if let phase {
                    Image(systemName: ZyklusPhaseStil.symbol(phase))
                        .font(.title3)
                        .foregroundStyle(ZyklusPhaseStil.farbe(phase, dunkel: dunkel))
                        .accessibilityHidden(true)
                }
                Text(titel)
                    .font(.largeTitle.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(palette.text)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(untertitel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text2)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(strich + Abstand.xl)
        }
        .frame(width: durchmesser, height: durchmesser)
        .padding(strich)
        .frame(maxWidth: .infinity)
        .onAppear {
            guard angezeigt == nil else { return }
            if bewegungAus { angezeigt = fortschritt } else { withAnimation(.smooth(duration: 0.8)) { angezeigt = fortschritt } }
        }
        .onChange(of: fortschritt) { _, neu in
            if bewegungAus { angezeigt = neu } else { withAnimation(Feder.weich) { angezeigt = neu } }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titel), \(untertitel)")
        .accessibilityValue(beschreibung ?? "\(Int((min(max(fortschritt, 0), 1) * 100).rounded())) Prozent des Zyklus")
    }
}

// MARK: - Auswahl

struct ZyklusAuswahlOption<Wert: Hashable>: Identifiable {
    var wert: Wert
    var titel: String
    var id: Wert { wert }
}

/// Bricht Chips in Zeilen um.
struct ZyklusFluss: Layout {
    var abstand: CGFloat = Abstand.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        zeilen(breite: proposal.width ?? 320, subviews: subviews).groesse
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = zeilen(breite: bounds.width, subviews: subviews)
        for (i, p) in r.orte.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func zeilen(breite: CGFloat, subviews: Subviews) -> (groesse: CGSize, orte: [CGPoint]) {
        var orte: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var hoehe: CGFloat = 0
        var maxX: CGFloat = 0
        for s in subviews {
            let g = s.sizeThatFits(.unspecified)
            if x > 0, x + g.width > breite {
                x = 0
                y += hoehe + abstand
                hoehe = 0
            }
            orte.append(CGPoint(x: x, y: y))
            x += g.width + abstand
            hoehe = max(hoehe, g.height)
            maxX = max(maxX, x - abstand)
        }
        return (CGSize(width: maxX, height: y + hoehe), orte)
    }
}

/// Auswahl-Chip: gewählt ist gefüllt mit Häkchen (nicht nur andere Farbe), sonst Umriss. Mindestens 44 pt hoch.
struct ZyklusWahlChip: View {
    let titel: String
    var symbol: String?
    var gewaehlt = false
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: Abstand.xs) {
            if gewaehlt {
                Image(systemName: "checkmark").font(.footnote.weight(.bold)).accessibilityHidden(true)
            } else if let symbol {
                Image(systemName: symbol).font(.footnote.weight(.semibold)).accessibilityHidden(true)
            }
            Text(titel).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .foregroundStyle(gewaehlt ? palette.aufAkzent : palette.text)
        .padding(.horizontal, Abstand.m)
        .frame(minHeight: Abstand.tippflaeche)
        .background(gewaehlt ? palette.akzent : palette.grund, in: .capsule)
        .overlay(Capsule().stroke(gewaehlt ? Color.clear : palette.rand, lineWidth: 1))
        .contentShape(.capsule)
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }
}

struct ZyklusMehrfachAuswahl<Wert: Hashable>: View {
    var optionen: [ZyklusAuswahlOption<Wert>]
    @Binding var gewaehlt: Set<Wert>

    var body: some View {
        ZyklusFluss {
            ForEach(optionen) { option in
                let an = gewaehlt.contains(option.wert)
                Button {
                    if an { gewaehlt.remove(option.wert) } else { gewaehlt.insert(option.wert) }
                } label: {
                    ZyklusWahlChip(titel: option.titel, gewaehlt: an)
                }
                .buttonStyle(.federnd)
            }
        }
        .haptik(.auswahl, bei: gewaehlt)
    }
}

/// Einzelwahl; ein zweiter Tipp nimmt die Wahl zurück.
struct ZyklusEinzelAuswahl<Wert: Hashable>: View {
    var optionen: [ZyklusAuswahlOption<Wert>]
    @Binding var gewaehlt: Wert?

    var body: some View {
        ZyklusFluss {
            ForEach(optionen) { option in
                let an = gewaehlt == option.wert
                Button { gewaehlt = an ? nil : option.wert } label: {
                    ZyklusWahlChip(titel: option.titel, gewaehlt: an)
                }
                .buttonStyle(.federnd)
            }
        }
        .haptik(.auswahl, bei: gewaehlt)
    }
}

/// Karte mit Titelzeile und Inhalt, im Stil der Listenkarte.
struct ZyklusKarte<Inhalt: View>: View {
    var titel: String?
    var symbol: String?
    @ViewBuilder var inhalt: () -> Inhalt
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            if let titel {
                Label {
                    Text(titel).font(.headline)
                } icon: {
                    if let symbol { Image(systemName: symbol).accessibilityHidden(true) }
                }
                .foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            }
            inhalt()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
    }
}

/// Zweitrangiger Text in Karten.
struct ZyklusLeise: View {
    let text: String
    @Environment(\.palette) private var palette

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.subheadline).foregroundStyle(palette.text2).fixedSize(horizontal: false, vertical: true)
    }
}
