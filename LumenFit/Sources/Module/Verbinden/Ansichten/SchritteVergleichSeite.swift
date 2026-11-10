// Quelle: Lovea Health/SchritteAnsichten.swift (SchritteWocheKarte, SchritteVergleichView)
import Charts
import SwiftUI

/// "Name gegen dich": die Schritte der Woche von dir und deinem Partner nebeneinander, Differenz je Tag und gesamt (plus: du liegst vorn).
/// Ein Blatt, erreichbar aus der Partner-Karte. Zeigt nur, was der Partner freigegeben hat; Tage ohne Wert bleiben leer, nie 0.
/// Über das Diagramm ziehen wählt einen Tag (Haptik bei jedem Wechsel).
struct SchritteVergleichSeite: View {
    let partner: ZusammenfassungDatei
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bewegungAus) private var bewegungAus
    @State private var auswahl: String?

    private var heute: String { Datum.text(umgebung.uhr()) }

    private var meine: [String: Int] {
        var werte: [String: Int] = [:]
        for tag in HabitLogik.wochenTage(heute: heute) where tag <= heute {
            if let s = umgebung.gesundheit.tage[tag]?.schritte, s > 0 { werte[tag] = s }
        }
        return werte
    }

    var body: some View {
        let woche = PartnerVergleich.schritteWoche(heute: heute, mein: meine, datei: partner)
        return NavigationStack {
            ScrollView {
                if let woche {
                    VStack(alignment: .leading, spacing: Abstand.l) {
                        gesamt(woche)
                        diagramm(woche)
                        tage(woche)
                    }
                    .foregroundStyle(palette.text)
                    .padding(Abstand.l)
                } else {
                    Text("Dein Partner teilt keine Schritte.")
                        .font(.body)
                        .foregroundStyle(palette.text2)
                        .padding(Abstand.l)
                }
            }
            .navigationTitle("\(partner.profilName) gegen dich")
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .haptik(.auswahl, bei: auswahl)
    }

    // MARK: Gesamt

    private func gesamt(_ woche: PartnerVergleich.SchrittWoche) -> some View {
        let gewaehlt = PartnerVergleich.tag(zu: auswahl, in: woche.tage)
        let mein = gewaehlt?.mein ?? (gewaehlt == nil ? woche.meinGesamt : nil)
        let sein = gewaehlt?.sein ?? (gewaehlt == nil ? woche.seinGesamt : nil)
        let differenz = gewaehlt == nil ? woche.differenz : gewaehlt?.differenz
        return ListenKarte {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text(gewaehlt.map { Datum.anzeige($0.tag) } ?? String(localized: "Diese Woche")).font(.headline)
                HStack(alignment: .firstTextBaseline) {
                    Text(differenz.map(PartnerVergleich.differenzText) ?? "–")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Spacer()
                    VStack(alignment: .trailing, spacing: Abstand.xs) {
                        Text("Du \(zahl(mein))").foregroundStyle(palette.text)
                        Text("\(partner.profilName) \(zahl(sein))").foregroundStyle(palette.text2)
                    }
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                }
            }
            .padding(Abstand.l)
        }
        .animation(bewegungAus ? nil : Feder.schnell, value: auswahl)
        .accessibilityElement(children: .combine)
    }

    private func zahl(_ wert: Int?) -> String { wert.map { PartnerVergleich.zahl($0) } ?? "–" }

    // MARK: Diagramm

    private func diagramm(_ woche: PartnerVergleich.SchrittWoche) -> some View {
        let punkte = woche.tage.flatMap { t in
            [Reihe(tag: t, name: String(localized: "Du"), wert: t.mein), Reihe(tag: t, name: partner.profilName, wert: t.sein)]
        }
        return DiagrammKarte(aussage: String(localized: "Schritte der Woche"), kernzeile: woche.differenz == 0 ? String(localized: "Gleichauf") : (woche.differenz > 0 ? String(localized: "Du liegst vorn") : String(localized: "\(partner.profilName) liegt vorn"))) {
            Chart(punkte) { p in
                BarMark(x: .value("Tag", p.tag.kuerzel), y: .value("Schritte", p.wert ?? 0), width: .ratio(0.9))
                    .position(by: .value("Person", p.name))
                    .foregroundStyle(by: .value("Person", p.name))
                    .cornerRadius(4)
                    .opacity(auswahl == nil || auswahl == p.tag.kuerzel ? (p.wert == nil ? 0.25 : 1) : 0.35)
            }
            .chartForegroundStyleScale(domain: [String(localized: "Du"), partner.profilName], range: [palette.text, palette.text2])
            .chartXSelection(value: $auswahl)
            .chartYScale(domain: 0...Int(Double(woche.hoechster) * 1.2))
            .chartYAxis(.hidden)
            .environment(\.locale, Datum.anzeigeLocale)
            .frame(height: 180)
            .accessibilityChartDescriptor(HeuteDiagrammBeschreibung(
                titel: String(localized: "Schritte der Woche, du gegen \(partner.profilName)"),
                zusammenfassung: String(localized: "Du \(PartnerVergleich.zahl(woche.meinGesamt)), \(partner.profilName) \(PartnerVergleich.zahl(woche.seinGesamt)) Schritte"),
                xTitel: String(localized: "Tag"), yTitel: String(localized: "Schritte"), einheit: String(localized: "Schritte"),
                punkte: woche.tage.filter { !$0.zukunft }.map { HeuteDiagrammPunkt(name: $0.kuerzel, wert: Double($0.mein ?? 0)) }))
        }
    }

    private struct Reihe: Identifiable {
        var tag: PartnerVergleich.SchrittTag
        var name: String
        var wert: Int?
        var id: String { tag.tag + name }
    }

    // MARK: Tage

    private func tage(_ woche: PartnerVergleich.SchrittWoche) -> some View {
        ListenKarte {
            ForEach(Array(woche.tage.enumerated()), id: \.element.id) { index, tag in
                if index > 0 { Haarlinie() }
                zeile(tag, hoechster: woche.hoechster)
            }
        }
    }

    private func zeile(_ tag: PartnerVergleich.SchrittTag, hoechster: Int) -> some View {
        HStack(spacing: Abstand.m) {
            Text(tag.kuerzel)
                .font(.subheadline.weight(.semibold))
                .frame(width: 30, alignment: .leading)
            VStack(alignment: .leading, spacing: Abstand.xs) {
                balken(tag.sein, hoechster: hoechster, farbe: palette.text2)
                balken(tag.mein, hoechster: hoechster, farbe: palette.text)
            }
            Text(tag.differenz.map(PartnerVergleich.differenzText) ?? "–")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 64, alignment: .trailing)
        }
        .padding(.horizontal, Abstand.l)
        .frame(minHeight: Abstand.tippflaeche)
        .opacity(tag.zukunft ? 0.35 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Datum.anzeige(tag.tag)): du \(tag.mein.map { PartnerVergleich.zahl($0) } ?? String(localized: "keine Daten")), \(partner.profilName) \(tag.sein.map { PartnerVergleich.zahl($0) } ?? String(localized: "keine Daten"))")
    }

    private func balken(_ wert: Int?, hoechster: Int, farbe: Color) -> some View {
        GeometryReader { geo in
            Capsule().fill(farbe.opacity(0.15))
                .overlay(alignment: .leading) {
                    Capsule().fill(farbe).frame(width: geo.size.width * CGFloat(wert ?? 0) / CGFloat(hoechster))
                }
        }
        .frame(height: 10)
        .animation(bewegungAus ? nil : Feder.weich, value: wert)
    }
}
