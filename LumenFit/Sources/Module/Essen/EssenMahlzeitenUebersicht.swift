// Quelle: Lovea Health/Ernaehrung/ErnaehrungView.swift (mahlzeitZeile mit Mini-Ring) und ErnaehrungMahlzeit.swift (MahlzeitenUebersicht)
import SwiftUI

/// Alle Mahlzeiten eines Tages: Mini-Ring (Anteil am Richtwert der Mahlzeit), kcal von Richtwert, die Namen der Lebensmittel
/// und ein Pfeil in die Mahlzeit-Seite; darunter die Einträge mit Wischen zum Löschen.
struct EssenMahlzeitenUebersicht: View {
    let tag: String

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus
    @State private var offen: EssenEintragZiel?
    @State private var geloescht = 0

    init(tag: String) { self.tag = tag }

    private var essen: EssenStore? { umgebung.daten?.essen }
    private var heute: String { Datum.text(umgebung.uhr()) }

    var body: some View {
        let ziel = essen?.ernaehrungsZiele(tag: tag).kcal ?? 0
        List {
            ForEach(Mahlzeit.allCases) { m in
                let liste = essen?.eintraege(tag, m) ?? []
                Section {
                    kopfZeile(m, liste, ziel: ziel)
                        .listRowBackground(palette.flaeche)
                    ForEach(liste) { e in
                        EssenMahlzeitZeile(eintrag: e) { offen = EssenEintragZiel(id: e.id) }
                            .listRowBackground(palette.flaeche)
                            .swipeActions(allowsFullSwipe: false) {
                                Button("Löschen", systemImage: "trash", role: .destructive) {
                                    essen?.loeschen(e)
                                    geloescht += 1
                                }
                            }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .fontDesign(.rounded)
        .lumenHintergrund()
        .navigationTitle(EssenMahlzeitenLogik.tagTitel(tag, heute: heute))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $offen) { ziel in eintragSeite(ziel.id) }
        .haptik(.stopp, bei: geloescht)
    }

    private func kopfZeile(_ m: Mahlzeit, _ liste: [EssenEintrag], ziel: Int) -> some View {
        let kcal = Int(ErnaehrungLogik.summe(liste).kcal.rounded())
        let richtwert = EssenMahlzeitenLogik.richtwert(m, zielKcal: ziel)
        let namen = EssenMahlzeitenLogik.namenZeile(liste)
        let name = essen?.mahlzeitName(m) ?? m.name
        return NavigationLink {
            EssenMahlzeitSeite(mahlzeit: m, tag: tag)
        } label: {
            HStack(spacing: Abstand.m) {
                miniRing(m, anteil: EssenMahlzeitenLogik.anteil(kcal: kcal, richtwert: richtwert))
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    Text(name).font(.headline.weight(.bold)).foregroundStyle(palette.text)
                    Text("\(EssenMahlzeitenLogik.zahl(kcal)) / \(EssenMahlzeitenLogik.zahl(richtwert)) kcal")
                        .font(.subheadline).monospacedDigit().foregroundStyle(palette.text)
                        .contentTransition(.numericText(value: Double(kcal)))
                        .animation(bewegungAus ? nil : Feder.weich, value: kcal)
                    if !namen.isEmpty {
                        Text(namen).font(.footnote).foregroundStyle(palette.text2).lineLimit(1)
                    }
                }
                Spacer(minLength: Abstand.xs)
            }
            .frame(minHeight: Abstand.tippflaeche)
            .contentShape(.rect)
        }
        .accessibilityLabel("\(name), \(kcal) von \(richtwert) Kilokalorien")
        .accessibilityHint("Zeigt, was du gegessen hast")
    }

    private func miniRing(_ m: Mahlzeit, anteil: Double) -> some View {
        ZStack {
            Circle().stroke(palette.haar, lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(anteil))
                .stroke(palette.text, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(bewegungAus ? nil : Feder.weich, value: anteil)
            Image(systemName: m.symbol).font(.body).foregroundStyle(palette.text2)
        }
        .frame(width: 46, height: 46)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func eintragSeite(_ id: String) -> some View {
        if let e = essen?.eintraege(tag).first(where: { $0.id == id }) {
            EssenDetailView(lebensmittel: e.lebensmittel, mahlzeit: e.mahlzeit, tag: e.datum, bearbeiten: e) { _ in offen = nil }
        } else {
            LeerZustand(stimmung: .bereit, satz: String(localized: "Dieser Eintrag ist gelöscht."))
        }
    }
}
