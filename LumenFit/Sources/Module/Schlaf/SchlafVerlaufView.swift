import SwiftUI

/// Der Schlaf-Verlauf: die letzten 30 Nächte als Säulen, deine üblichen Zeiten, Regelmäßigkeit und alle Nächte mit Quelle. Jede Nacht öffnet ihr Detail.
struct SchlafVerlaufView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    @State private var band: [BandSchlafOp] = []

    private static let tageImDiagramm = 30

    var body: some View {
        let u = SchlafDaten.uebersicht(umgebung, band: band)
        ScrollView {
            VStack(spacing: Abstand.l) {
                if u.hatDaten {
                    inhalt(u)
                } else {
                    LeerZustand(stimmung: u.lumi(jetzt: umgebung.uhr()), satz: "Keine Schlafdaten. Trage dein Handy oder die Uhr nachts.",
                                handlung: "In Health prüfen", aktion: { SchlafHealthLink.oeffnen(openURL) })
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.s)
        }
        .navigationTitle("Schlafverlauf")
        .lumenHintergrund()
        .task(id: umgebung.profil.aktiv?.id) { band = SchlafDaten.bandOps(umgebung) }
    }

    @ViewBuilder
    private func inhalt(_ u: SchlafUebersicht) -> some View {
        diagramm(u)
        zeiten(u)
        SchlafRegelKarte(ergebnis: u.regelmaessigkeit)
        SchlafAbschnittKopf("Alle Nächte")
        naechte(u)
    }

    private func diagramm(_ u: SchlafUebersicht) -> some View {
        let tage = u.tage(Self.tageImDiagramm)
        let mit = tage.compactMap(\.minuten)
        let aussage = mit.isEmpty ? "Keine Nacht in den letzten \(Self.tageImDiagramm) Tagen"
            : "Im Schnitt \(SchlafFormat.dauer(mit.reduce(0, +) / mit.count)) in \(mit.count) Nächten"
        let kurz = mit.filter { $0 < WochenVergleich.kurzeNachtMinuten }.count
        let kernzeile = kurz == 0 ? "Keine Nacht unter 6 Stunden" : (kurz == 1 ? "1 Nacht unter 6 Stunden" : "\(kurz) Nächte unter 6 Stunden")
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

    private func zeitenZeile(_ titel: String, _ zeiten: SchlafZeiten?) -> some View {
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
        let liste = Array(u.naechte.reversed())
        return ListenKarte {
            ForEach(Array(liste.enumerated()), id: \.element.nacht.tag) { index, nacht in
                if index > 0 { Haarlinie() }
                NavigationLink {
                    SchlafNachtDetailView(nacht: nacht, vergleich: u.vergleichsnacht(fuer: nacht.nacht.tag), verlauf: u.vergleich)
                } label: {
                    zeile(nacht)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func zeile(_ n: SchlafGewaehlteNacht) -> some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: n.quelle.symbolName).frame(width: 24).foregroundStyle(palette.text2).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(Datum.anzeige(n.nacht.tag)).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                Text("\(Datum.uhrzeit(n.nacht.von)) bis \(Datum.uhrzeit(n.nacht.bis)) · \(n.quelle.name)").font(.caption).foregroundStyle(palette.text2).monospacedDigit()
            }
            Spacer(minLength: Abstand.s)
            Text(SchlafFormat.dauer(n.nacht.schlafMinuten)).font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.s)
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Datum.anzeige(n.nacht.tag)): \(SchlafFormat.sprechDauer(n.nacht.schlafMinuten)), von \(Datum.uhrzeit(n.nacht.von)) bis \(Datum.uhrzeit(n.nacht.bis)), Quelle \(n.quelle.name)")
        .accessibilityHint("Öffnet die Nacht")
    }
}
