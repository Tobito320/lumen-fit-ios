import SwiftUI

/// Eine Herausforderung: Stand mit Balken je Person (gemeinsam: ein Balken zum Ziel), Tage übrig, Annehmen und Ablehnen oder Verlassen.
/// Jede App meldet nur ihre eigene Zahl; was hier steht, ist der letzte Stand des Servers.
struct CrewHerausforderungSeite: View {
    let id: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var verlassenFragen = false
    @State private var fehler: String?

    private var dienst: CrewDienst { CrewDienst.von(umgebung) }

    var body: some View {
        Group {
            if let h = dienst.herausforderung(id) {
                inhalt(h)
            } else {
                LeerZustand(stimmung: .denkt, satz: String(localized: "Diese Herausforderung gibt es nicht mehr."))
            }
        }
        .lumenHintergrund()
        .navigationTitle(dienst.herausforderung(id).map(CrewLogik.titel) ?? String(localized: "Herausforderung"))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await dienst.laden(erzwingen: true) }
        .modifier(CrewFehlerAnzeige(extra: $fehler))
    }

    private func inhalt(_ h: CrewHerausforderung) -> some View {
        let jetzt = umgebung.uhr()
        let stand = CrewLogik.stand(h, jetzt: jetzt)
        return ScrollView {
            VStack(alignment: .leading, spacing: Abstand.xl) {
                ListenKarte {
                    VStack(alignment: .leading, spacing: Abstand.s) {
                        HStack {
                            Pille(text: CrewLogik.text(stand), symbolName: h.mass.symbol)
                            Spacer()
                            Text(CrewLogik.restText(h, jetzt: jetzt)).font(.footnote).foregroundStyle(palette.text2)
                        }
                        Text("\(Datum.anzeige(Datum.text(h.start))) bis \(Datum.anzeige(Datum.text(h.ende)))").font(.footnote).foregroundStyle(palette.text2)
                        if h.mass == .uebung {
                            Text("Steigerung des geschätzten 1RM gegen den eigenen Stand vor dem Start, in Promille (10 ‰ = 1 %).")
                                .font(.footnote).foregroundStyle(palette.text2)
                        }
                    }
                    .padding(Abstand.l)
                    .accessibilityElement(children: .combine)
                }
                if h.modus == .gemeinsam { gemeinsam(h) }
                personen(h)
                knoepfe(h, vorbei: CrewLogik.vorbei(h, jetzt: jetzt))
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.xl)
        }
        .confirmationDialog("Herausforderung verlassen?", isPresented: $verlassenFragen, titleVisibility: .visible) {
            Button("Verlassen", role: .destructive) {
                Task {
                    fehler = await dienst.verlassen(h.id)
                    if fehler == nil { dismiss() }
                }
            }
        } message: {
            Text(h.ersteller ? "Du hast sie gestartet: damit endet sie für alle." : "Dein Wert zählt dann nicht mehr.")
        }
    }

    private func gemeinsam(_ h: CrewHerausforderung) -> some View {
        let summe = h.teilnehmer.filter(\.dabei).reduce(0) { $0 + $1.wert }
        let ziel = max(1, h.ziel ?? 1)
        return ListenKarte {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text("\(CrewLogik.wertText(summe, h.mass)) von \(CrewLogik.wertText(ziel, h.mass))")
                    .font(.headline).monospacedDigit().foregroundStyle(palette.text)
                ProgressView(value: Double(min(summe, ziel)), total: Double(ziel)).tint(palette.akzent)
            }
            .padding(Abstand.l)
            .accessibilityElement(children: .combine)
        }
    }

    private func personen(_ h: CrewHerausforderung) -> some View {
        let sortiert = h.teilnehmer.sorted { ($0.dabei ? 0 : 1, -$0.wert, $0.name) < ($1.dabei ? 0 : 1, -$1.wert, $1.name) }
        let groesster = max(1, sortiert.filter(\.dabei).map(\.wert).max() ?? 1)
        return ListenKarte {
            ForEach(Array(sortiert.enumerated()), id: \.element.id) { i, t in
                if i > 0 { Haarlinie() }
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    HStack {
                        Text(t.ich ? String(localized: "Du") : t.name).font(.body.weight(t.ich ? .bold : .regular)).foregroundStyle(palette.text).lineLimit(1)
                        Spacer(minLength: Abstand.s)
                        Text(t.dabei ? CrewLogik.wertText(t.wert, h.mass) : String(localized: "eingeladen"))
                            .font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(t.dabei ? palette.text : palette.text2)
                    }
                    if t.dabei {
                        ProgressView(value: Double(t.wert), total: Double(groesster)).tint(t.ich ? palette.akzent : palette.text2)
                    }
                }
                .padding(.horizontal, Abstand.l)
                .padding(.vertical, Abstand.m)
                .frame(minHeight: Abstand.tippflaeche)
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder
    private func knoepfe(_ h: CrewHerausforderung, vorbei: Bool) -> some View {
        if h.eingeladen, !vorbei, !h.abgebrochen {
            VStack(spacing: Abstand.s) {
                Button {
                    Task { fehler = await dienst.annehmen(h.id) }
                } label: { Text("Annehmen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                .buttonStyle(.lumenHauptknopf)
                Button {
                    Task {
                        fehler = await dienst.ablehnen(h.id)
                        if fehler == nil { dismiss() }
                    }
                } label: { Text("Ablehnen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                .buttonStyle(.bordered)
                Text(CrewTexte.sichtbar).font(.footnote).foregroundStyle(palette.text2)
            }
        } else if h.dabei, !vorbei, !h.abgebrochen {
            Button(role: .destructive) { verlassenFragen = true } label: {
                Text("Verlassen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.bordered)
        }
    }
}
