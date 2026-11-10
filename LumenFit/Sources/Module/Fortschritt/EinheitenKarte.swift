import SwiftUI

/// "Einheiten je Woche": Balken der letzten 8 Kalenderwochen, umschaltbar zwischen Dauer, Volumen und Reps. Ein Tipp auf einen Balken wählt die Woche,
/// ihr Wert steht groß darüber (Standard: die laufende Woche). Pillen und Balken sind Knöpfe (44 pt, gewählt mit Merkmal).
struct EinheitenKarte: View {
    let sessions: [GymSession]
    let heute: String
    var jetzt: Date?
    @State private var art = StatistikArt.dauer
    @State private var woche: String?
    @Environment(\.palette) private var palette

    var body: some View {
        let werte = FortschrittLogik.wochen(sessions, heute: heute, jetzt: jetzt, art: art)
        let montag = Datum.montagDerWoche(heute)
        let gewaehlt = werte.first { $0.montag == woche } ?? werte.last
        let text = Self.text(gewaehlt?.wert ?? 0, art: art)
        VStack(alignment: .leading, spacing: Abstand.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.wochenTitel(gewaehlt?.montag ?? montag, heute: heute)).font(.footnote).foregroundStyle(palette.text2)
                Text(text).font(.largeTitle.weight(.bold)).fontDesign(.rounded).monospacedDigit().foregroundStyle(palette.text)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .accessibilityElement(children: .combine)
            FortSaeulen(saeulen: werte.map { w in
                .init(id: w.montag, beschriftung: "\(FortschrittLogik.kalenderwoche(w.montag))", wert: w.wert,
                      sprechtext: "\(Self.wochenTitel(w.montag, heute: heute)), \(Self.text(w.wert, art: art))")
            }, hervorgehoben: gewaehlt?.montag, hoehe: 112) { woche = $0 }
            HStack(spacing: Abstand.s) {
                ForEach(StatistikArt.allCases, id: \.self) { pille($0) }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .lumenKartenFlaeche()
        .haptik(.auswahl, bei: art)
        .haptik(.auswahl, bei: woche)
    }

    /// "Diese Woche", "Letzte Woche", sonst "KW 44".
    static func wochenTitel(_ montag: String, heute: String) -> String {
        let jetzt = Datum.montagDerWoche(heute)
        if montag == jetzt { return String(localized: "Diese Woche") }
        if montag == Datum.addTage(jetzt, -7) { return String(localized: "Letzte Woche") }
        return String(localized: "KW \(FortschrittLogik.kalenderwoche(montag))")
    }

    /// Dauer als "2:17 h" (Minuten), Volumen als "12,9 t" oder "9.690 kg", Reps als Zahl.
    static func text(_ wert: Double, art: StatistikArt) -> String {
        switch art {
        case .dauer: TrainingLogik.dauerText(wert * 60)
        case .volumen: FortschrittLogik.volumenText(wert)
        case .wiederholungen: String(localized: "\(Int(wert.rounded())) Reps")
        }
    }

    private func pille(_ a: StatistikArt) -> some View {
        let gewaehlt = a == art
        return Button { art = a } label: {
            Text(a.titel)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(gewaehlt ? palette.aufAkzentFlaeche : palette.text)
                .padding(.horizontal, Abstand.l)
                .frame(minHeight: Abstand.tippflaeche)
                .background(gewaehlt ? palette.akzentFlaeche : palette.haar, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(gewaehlt ? .isSelected : [])
    }
}
