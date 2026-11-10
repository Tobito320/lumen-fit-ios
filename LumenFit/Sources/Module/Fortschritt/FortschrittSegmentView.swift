import SwiftUI

/// Der Abschnitt "Mehr" unten auf der Seite Fortschritt (`FortschrittTabView`): alles, was das frühere Segment Fortschritt im Tab Gym erreichbar machte und
/// nicht nach oben gewandert ist. Verlauf (Konstanz und Gewicht), Kraftkurve, Muskelkarte (Wochenleiste, Sätze je Körperteil, Erholung), nächstes Training,
/// Rückblick (mit FitPassport) und Lumi. Messungen und Medaillen stehen jetzt in ihren eigenen Abschnitten, die Wochenziele hinter "Ziele" in der Leiste.
/// Nur der Inhalt, ohne ScrollView, Hintergrund oder Leiste: die Seite darum bringt sie mit.
struct FortschrittSegmentView: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        ListenKarte {
            FortschrittLinkZeile(titel: "Verlauf", detail: "Konstanz und Gewicht", symbol: "chart.xyaxis.line") { VerlaufView() }
            Haarlinie()
            FortschrittLinkZeile(titel: "Kraftkurve", detail: "Bestes Gewicht, 1RM und Volumen je Übung", symbol: "chart.line.uptrend.xyaxis") { KraftKurveSeite() }
            Haarlinie()
            FortschrittLinkZeile(titel: "Muskelkarte", detail: "Sätze und Erholung je Körperteil", symbol: "figure.arms.open") { MuskelkartenSeite() }
            Haarlinie()
            FortschrittLinkZeile(titel: "Nächstes Training", detail: "Was heute passt", symbol: "figure.strengthtraining.traditional") { NaechstesTrainingSeite() }
            Haarlinie()
            FortschrittLinkZeile(titel: "Rückblick", detail: "Woche und Monat teilen, FitPassport", symbol: "calendar") { RueckblickView() }
            Haarlinie()
            FortschrittLinkZeile(titel: "Lumi", detail: "Stufe \(q.stufe) von \(LumiStufe.schwellen.count)", symbol: "sparkles") { LumiSeiteView() }
        }
    }
}

/// Eine Zeile mit Symbol, Titel, Erklärung und Pfeil, die eine Seite öffnet. Mindestens 56 pt hoch.
struct FortschrittLinkZeile<Ziel: View>: View {
    let titel: String
    let detail: String
    let symbol: String
    let ziel: Ziel
    @Environment(\.palette) private var palette

    init(titel: String, detail: String, symbol: String, @ViewBuilder ziel: () -> Ziel) {
        self.titel = titel
        self.detail = detail
        self.symbol = symbol
        self.ziel = ziel()
    }

    var body: some View {
        NavigationLink {
            ziel
        } label: {
            HStack(spacing: Abstand.m) {
                Image(systemName: symbol).frame(width: 28).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel).font(.headline)
                    Text(detail).font(.footnote).foregroundStyle(palette.text2)
                }
                Spacer(minLength: Abstand.s)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, Abstand.l)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
