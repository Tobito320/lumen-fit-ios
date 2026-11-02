import SwiftUI

/// Die Tage davor: je Tag eine Zeile mit der ersten Frage, Suche über den ganzen Verlauf und Export als Text.
struct CoachVerlaufView: View {
    let modell: CoachModell
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var suche = ""

    var body: some View {
        let tage = modell.vergangeneTage
        let treffer = CoachLokal.suche(modell.sichtbarerVerlauf, begriff: suche)
        ScrollView {
            if !suche.trimmingCharacters(in: .whitespaces).isEmpty {
                suchergebnis(treffer, tage: tage)
            } else if tage.isEmpty {
                LeerZustand(stimmung: .schlaeft, satz: "Noch kein Verlauf. Frag deinen Coach etwas, dann steht es hier.")
                    .padding(.top, Abstand.xxl)
            } else {
                ListenKarte {
                    ForEach(Array(tage.enumerated()), id: \.element.id) { index, tag in
                        if index > 0 { Haarlinie() }
                        NavigationLink {
                            CoachTagLeser(tag: tag, modell: modell)
                        } label: {
                            zeile(tag)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Abstand.l)
            }
        }
        .navigationTitle("Verlauf")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $suche, prompt: "Im Verlauf suchen")
        .lumenHintergrund()
        .toolbar {
            if !modell.sichtbarerVerlauf.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: exportText) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Verlauf als Text teilen")
                }
            }
        }
    }

    private var exportText: String {
        CoachLokal.export(modell.sichtbarerVerlauf, ich: umgebung.profil.aktiv?.name ?? "Ich", coach: modell.einstellungen?.anzeigeName ?? CoachLokal.standardName) {
            "\(CoachAnzeige.tag($0)), \(CoachAnzeige.uhrzeit($0))"
        }
    }

    private func zeile(_ tag: CoachTage.Tag) -> some View {
        HStack(spacing: Abstand.m) {
            VStack(alignment: .leading, spacing: Abstand.xs) {
                Text(CoachAnzeige.tag(tag.beginn)).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                Text(tag.vorschau).font(.footnote).foregroundStyle(palette.text2).lineLimit(2)
            }
            Spacer(minLength: Abstand.s)
            Text("\(tag.anzahl)").font(.footnote.monospacedDigit()).foregroundStyle(palette.text2)
            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(palette.text2).accessibilityHidden(true)
        }
        .padding(Abstand.l)
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(CoachAnzeige.tag(tag.beginn)), \(tag.anzahl) Nachrichten. \(tag.vorschau)")
    }

    @ViewBuilder
    private func suchergebnis(_ treffer: [CoachNachricht], tage: [CoachTage.Tag]) -> some View {
        if treffer.isEmpty {
            LeerZustand(stimmung: .denkt, satz: "Dazu finde ich nichts im Verlauf.").padding(.top, Abstand.xxl)
        } else {
            ListenKarte {
                ForEach(Array(treffer.enumerated()), id: \.element.id) { index, nachricht in
                    if index > 0 { Haarlinie() }
                    if let tag = CoachTage.tag(mit: nachricht.id, in: tage) {
                        NavigationLink { CoachTagLeser(tag: tag, modell: modell) } label: { trefferZeile(nachricht) }
                            .buttonStyle(.plain)
                            .accessibilityHint("Öffnet den Tag")
                    } else {
                        trefferZeile(nachricht)
                    }
                }
            }
            .padding(Abstand.l)
        }
    }
}

extension CoachVerlaufView {
    fileprivate func trefferZeile(_ nachricht: CoachNachricht) -> some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            Text("\(CoachAnzeige.tag(nachricht.zeit)), \(CoachAnzeige.uhrzeit(nachricht.zeit))").font(.caption).foregroundStyle(palette.text2)
            Text(CoachText.vorschau(nachricht.text)).font(.body).foregroundStyle(palette.text)
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Ein vergangener Tag zum Nachlesen (nur lesen, ohne Chips).
struct CoachTagLeser: View {
    let tag: CoachTage.Tag
    let modell: CoachModell
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Abstand.l) {
                ForEach(tag.nachrichten) { nachricht in
                    switch nachricht.rolle {
                    case .nutzer: CoachNutzerBlase(modell: modell, nachricht: nachricht)
                    case .coach: CoachAntwortText(text: nachricht.text)
                    }
                }
            }
            .padding(Abstand.l)
        }
        .navigationTitle(CoachAnzeige.tag(tag.beginn))
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
    }
}
