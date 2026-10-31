import SwiftUI

extension PartnerAnsichtLogik {
    /// Der Stand des Partners für die Ansichten (in der Demo aus der Fixture, sonst aus dem Verbindungs-Store).
    @MainActor
    static func aktuellerStand(_ umgebung: AppUmgebung) -> PartnerStand {
        VerbindenDemo.partner ?? umgebung.daten?.verbindung.partner ?? .nichtVerbunden
    }
}

private struct PartnerStandKey: EnvironmentKey { static let defaultValue: PartnerStand? = nil }

extension EnvironmentValues {
    /// Eine bestimmte Person statt des Lovea-Partners: die Ansichten (Plan, Verlauf, Tagebuch, Körperwerte) lesen dann ihren Stand. Gesetzt über `PartnerEinstiegZeilen(stand:)`.
    var partnerStandUeberschreibung: PartnerStand? {
        get { self[PartnerStandKey.self] }
        set { self[PartnerStandKey.self] = newValue }
    }
}

/// Der gemeinsame Rahmen der vier Partner-Ansichten: holt den Stand, zeigt bei fehlender Freigabe oder ohne Daten einen Leerzustand mit Lumi
/// ("Dein Partner hat das nicht freigegeben."), bei älteren Daten einen Hinweis über dem Inhalt und sonst den Inhalt der Ansicht.
struct PartnerAnsichtRahmen<Inhalt: View>: View {
    let art: FreigabeArt
    let titel: String
    let inhalt: (ZusammenfassungDatei) -> Inhalt
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.partnerStandUeberschreibung) private var person

    init(art: FreigabeArt, titel: String, @ViewBuilder inhalt: @escaping (ZusammenfassungDatei) -> Inhalt) {
        self.art = art
        self.titel = titel
        self.inhalt = inhalt
    }

    var body: some View {
        let lage = PartnerAnsichtLogik.lage(person ?? PartnerAnsichtLogik.aktuellerStand(umgebung), art: art)
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                if case .bereit(let datei, let veraltet) = lage {
                    if let hinweis = PartnerAnsichtLogik.veraltetHinweis(datei, veraltet: veraltet) { veraltetKarte(hinweis) }
                    inhalt(datei)
                } else {
                    LeerZustand(stimmung: .bereit, satz: PartnerAnsichtLogik.leerSatz(lage, art: art))
                        .lumenKartenFlaeche()
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .navigationTitle(titel)
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
    }

    private func veraltetKarte(_ hinweis: String) -> some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: "clock.arrow.circlepath").foregroundStyle(palette.text2).accessibilityHidden(true)
            Text(hinweis).font(.subheadline).foregroundStyle(palette.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .lumenKartenFlaeche()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hinweis: \(hinweis)")
    }
}

/// Karten fahren beim Erscheinen mit einer Feder ein, eine nach der anderen. Unter "Bewegung reduzieren" und im Stromsparmodus stehen sie sofort da.
private struct PartnerErscheinen: ViewModifier {
    let reihenfolge: Int
    @Environment(\.bewegungAus) private var ruhig
    @State private var da = false

    func body(content: Content) -> some View {
        content
            .opacity(ruhig || da ? 1 : 0)
            .offset(y: ruhig || da ? 0 : 16)
            .onAppear {
                guard !ruhig, !da else { return }
                withAnimation(Feder.federnd.delay(Double(min(reihenfolge, 6)) * 0.06)) { da = true }
            }
    }
}

/// Ein Diagramm zeichnet sich beim Erscheinen von links ein (nicht unter "Bewegung reduzieren" und im Stromsparmodus).
private struct PartnerZeichnen: ViewModifier {
    @Environment(\.bewegungAus) private var ruhig
    @State private var sichtbar = false

    func body(content: Content) -> some View {
        content
            .mask(alignment: .leading) {
                GeometryReader { geo in Rectangle().frame(width: ruhig || sichtbar ? geo.size.width : 0) }
            }
            .onAppear {
                guard !ruhig, !sichtbar else { return }
                withAnimation(.easeOut(duration: 0.7)) { sichtbar = true }
            }
    }
}

extension View {
    /// `reihenfolge` 0, 1, 2 ... : die Karten kommen nacheinander.
    func partnerErscheint(_ reihenfolge: Int) -> some View { modifier(PartnerErscheinen(reihenfolge: reihenfolge)) }

    func partnerZeichnet() -> some View { modifier(PartnerZeichnen()) }
}

/// Ein Balken, der sich beim Erscheinen auf seinen Anteil (0 bis 1) füllt. Der Anteil steht auch im Text daneben, der Balken ist für VoiceOver stumm.
struct PartnerBalken: View {
    let anteil: Double
    var hoehe: CGFloat = 8
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var ruhig
    @State private var gefuellt = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.haar)
                Capsule().fill(palette.text).frame(width: geo.size.width * (ruhig || gefuellt ? anteil : 0))
            }
        }
        .frame(height: hoehe)
        .accessibilityHidden(true)
        .onAppear {
            guard !ruhig, !gefuellt else { return }
            withAnimation(Feder.weich.delay(0.1)) { gefuellt = true }
        }
        .animation(ruhig ? nil : Feder.weich, value: anteil)
    }
}
