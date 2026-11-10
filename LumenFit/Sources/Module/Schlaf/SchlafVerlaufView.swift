import SwiftUI

/// Der Schlaf-Verlauf: die letzten 30 Nächte als Säulen, deine üblichen Zeiten, Regelmäßigkeit und alle Nächte mit Quelle. Jede Nacht öffnet ihr Detail.
struct SchlafVerlaufView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    @State private var band: [BandSchlafOp] = []
    @State private var umfang = Umfang.dreissig
    @State private var offen: String?
    @State private var korrigiere: SchlafGewaehlteNacht?
    @State private var version = 0
    @Environment(\.bewegungAus) private var bewegungAus

    private enum Umfang: String, CaseIterable, Identifiable {
        case sieben = "7 Nächte", dreissig = "30 Nächte", alle = "Alle"
        var id: String { rawValue }
        var anzahl: Int? { switch self { case .sieben: 7; case .dreissig: 30; case .alle: nil } }
        var titel: String {
            switch self {
            case .sieben: String(localized: "7 Nächte")
            case .dreissig: String(localized: "30 Nächte")
            case .alle: String(localized: "Alle")
            }
        }
    }

    private static let tageImDiagramm = 30

    var body: some View {
        let u = SchlafDaten.uebersicht(umgebung, band: band)
        let _ = version
        ScrollView {
            VStack(spacing: Abstand.l) {
                if u.hatDaten {
                    inhalt(u)
                } else {
                    LeerZustand(stimmung: u.lumi(jetzt: umgebung.uhr()), satz: String(localized: "Keine Schlafdaten. Trage dein Handy oder die Uhr nachts."),
                                handlung: String(localized: "In Health prüfen"), aktion: { SchlafHealthLink.oeffnen(openURL) })
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.s)
        }
        .navigationTitle("Schlafverlauf")
        .lumenHintergrund()
        .task(id: umgebung.profil.aktiv?.id) { band = SchlafDaten.bandOps(umgebung) }
        .sheet(item: $korrigiere) { n in
            SchlafEintragenView(tag: n.nacht.tag, nacht: n.nacht) { version += 1 }
        }
        .haptik(.auswahl, bei: offen)
        .haptik(.auswahl, bei: umfang)
    }

    @ViewBuilder
    private func inhalt(_ u: SchlafUebersicht) -> some View {
        diagramm(u)
        zeiten(u)
        SchlafRegelKarte(ergebnis: u.regelmaessigkeit)
        SchlafAbschnittKopf("Nächte")
        Picker("Zeitraum", selection: $umfang.animation(bewegungAus ? nil : Feder.schnell)) {
            ForEach(Umfang.allCases) { Text($0.titel).tag($0) }
        }
        .pickerStyle(.segmented)
        naechte(u)
    }

    private func diagramm(_ u: SchlafUebersicht) -> some View {
        let tage = u.tage(Self.tageImDiagramm)
        let mit = tage.compactMap(\.minuten)
        let schnitt = mit.isEmpty ? "" : SchlafFormat.dauer(mit.reduce(0, +) / mit.count)
        let aussage = mit.isEmpty ? String(localized: "Keine Nacht in den letzten \(Self.tageImDiagramm) Tagen")
            : String(localized: "Im Schnitt \(schnitt) in \(mit.count) Nächten")
        let kurz = mit.filter { $0 < WochenVergleich.kurzeNachtMinuten }.count
        let kernzeile = kurz == 0 ? String(localized: "Keine Nacht unter 6 Stunden") : (kurz == 1 ? String(localized: "1 Nacht unter 6 Stunden") : String(localized: "\(kurz) Nächte unter 6 Stunden"))
        return DiagrammKarte(aussage: aussage, kernzeile: kernzeile) {
            SchlafSaeulen(tage: tage, zielMinuten: u.zielMinuten, beschriftet: false).padding(.top, Abstand.s)
        }
    }

    /// Die üblichen Zeiten, getrennt nach Werktag und Wochenende; ohne genug Nächte steht da, was fehlt.
    private func zeiten(_ u: SchlafUebersicht) -> some View {
        ListenKarte {
            zeitenZeile("Werktags", u.werktag)
            Haarlinie()
            zeitenZeile("Am Wochenende", u.wochenende)
        }
    }

    private func zeitenZeile(_ titel: LocalizedStringKey, _ zeiten: SchlafZeiten?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.headline).foregroundStyle(palette.text)
                Text(zeiten == nil ? "Zu wenig Daten: ab 3 Nächten lerne ich deine übliche Zeit." : "Deine übliche Bett- und Aufstehzeit")
                    .font(.subheadline)
                    .foregroundStyle(palette.text2)
            }
            Spacer(minLength: Abstand.s)
            if let zeiten {
                Text(zeiten.text).font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
            }
        }
        .padding(Abstand.l)
        .accessibilityElement(children: .combine)
    }

    private func naechte(_ u: SchlafUebersicht) -> some View {
        let alle = Array(u.naechte.reversed())
        let liste = umfang.anzahl.map { Array(alle.prefix($0)) } ?? alle
        return ListenKarte {
            ForEach(Array(liste.enumerated()), id: \.element.nacht.tag) { index, nacht in
                if index > 0 { Haarlinie() }
                VStack(spacing: 0) {
                    Button {
                        withAnimation(bewegungAus ? nil : Feder.schnell) { offen = offen == nacht.nacht.tag ? nil : nacht.nacht.tag }
                    } label: {
                        zeile(nacht, offen: offen == nacht.nacht.tag)
                    }
                    .buttonStyle(.plain)
                    if offen == nacht.nacht.tag {
                        aktionen(u, nacht)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .clipped()
            }
        }
    }

    private func aktionen(_ u: SchlafUebersicht, _ n: SchlafGewaehlteNacht) -> some View {
        HStack(spacing: Abstand.m) {
            NavigationLink {
                SchlafNachtDetailView(nacht: n, vergleich: u.vergleichsnacht(fuer: n.nacht.tag), verlauf: u.vergleich)
            } label: {
                Label("Details", systemImage: "chart.bar.doc.horizontal").frame(minHeight: Abstand.tippflaeche)
            }
            Spacer(minLength: Abstand.s)
            Button("Korrigieren", systemImage: "pencil") { korrigiere = n }.frame(minHeight: Abstand.tippflaeche)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(palette.text)
        .padding(.horizontal, Abstand.l)
        .padding(.bottom, Abstand.s)
    }

    private func zeile(_ n: SchlafGewaehlteNacht, offen: Bool) -> some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: n.quelle.symbolName).frame(width: 24).foregroundStyle(palette.text2).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(Datum.anzeige(n.nacht.tag)).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                Text("\(Datum.uhrzeit(n.nacht.von)) bis \(Datum.uhrzeit(n.nacht.bis)) · \(n.quelle.name)").font(.caption).foregroundStyle(palette.text2).monospacedDigit()
            }
            Spacer(minLength: Abstand.s)
            Text(SchlafFormat.dauer(n.nacht.schlafMinuten)).font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
            Image(systemName: "chevron.down").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).rotationEffect(.degrees(offen ? 180 : 0)).accessibilityHidden(true)
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.s)
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Datum.anzeige(n.nacht.tag)): \(SchlafFormat.sprechDauer(n.nacht.schlafMinuten)), von \(Datum.uhrzeit(n.nacht.von)) bis \(Datum.uhrzeit(n.nacht.bis)), Quelle \(n.quelle.name)")
        .accessibilityHint(offen ? "Klappt die Nacht zu" : "Klappt Details und Korrigieren auf")
        .accessibilityAddTraits(.isButton)
    }
}
