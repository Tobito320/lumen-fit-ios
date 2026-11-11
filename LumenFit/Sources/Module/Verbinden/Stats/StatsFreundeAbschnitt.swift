import SwiftUI

/// Stats > Freunde: Platz unter den Freunden, die "Freunde sehen mich" anhaben (ich zähle nur, wenn ich will: Zeigen oder Ausblenden, sofort),
/// Rekorde gegen die Freunde, "Mit Freunden" (Trainingspartner, Herausforderungen, Rekorde der Freunde, Freunde verwalten) und Einladen.
struct StatsFreundeAbschnitt: View {
    let mass: StatsMass
    let einladen: () -> Void
    let codeEingeben: () -> Void
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    private var stats: StatsDienst { StatsDienst.von(umgebung) }
    private var sichtbar: Bool { umgebung.daten?.einstellungen.werte.statsFreunde == true }

    var body: some View {
        let freunde = stats.antwort?.freunde ?? []
        let namen = Dictionary(GymCrewQuelle.eintraege(umgebung).map { ($0.id, $0.anzeigeName) }, uniquingKeysWith: { a, _ in a })
        let mein = mass.wert(stats.eigene)
        let zeilen = StatsLogik.zeilen(ichName: String(localized: "Du"), ichWert: mein,
                                       andere: freunde.compactMap { f in mass.wert(f).map { (id: f.id, name: namen[f.id] ?? f.name, wert: $0) } })
        let platz = StatsLogik.platz(zeilen)
        VStack(alignment: .leading, spacing: Abstand.l) {
            StatsPlatzKarte(
                gruppe: String(localized: "Deine Freunde"), rang: platz.rang, von: platz.von,
                wert: mein.map { mass.wertText($0, jetzt: umgebung.uhr()) } ?? StatsTexte.schritteNichtDabei,
                satz: mein == nil ? StatsTexte.schritteWie : StatsLogik.satzFreunde(zeilen, mass: mass), stimmung: platz.rang == 1 && zeilen.count > 1 ? .ziel : .anfeuern,
                sichtSymbol: sichtbar ? "person.2.fill" : "lock.fill",
                sichtText: sichtbar ? String(localized: "Deine Freunde sehen deinen Platz.") : String(localized: "Privat: Freunde sehen dich nicht."),
                knopf: sichtbar ? String(localized: "Ausblenden") : String(localized: "Zeigen"),
                aktion: { umgebung.daten?.einstellungen.aendere { $0.statsFreunde.toggle() } })
            liste(zeilen)
            rekorde(freunde)
            mitFreunden
            einladenKnoepfe
        }
    }

    private func liste(_ zeilen: [CrewRang]) -> some View {
        ListenKarte {
            ForEach(Array(zeilen.enumerated()), id: \.element.id) { i, z in
                if i > 0 { Haarlinie() }
                if z.ich {
                    StatsZeileView(zeile: z, untertitel: sichtbar ? String(localized: "Freunde sehen dich") : String(localized: "Privat, nur du siehst dich"))
                } else {
                    NavigationLink { CrewFreundSeite(id: z.id) } label: { StatsZeileView(zeile: z) }.buttonStyle(.plain)
                }
            }
            if zeilen.count < 2 {
                Text("Hier stehen deine Freunde, sobald sie in Stats „Zeigen“ antippen.")
                    .font(.footnote).foregroundStyle(palette.text2).padding(Abstand.l)
            }
        }
    }

    @ViewBuilder
    private func rekorde(_ freunde: [StatsFreund]) -> some View {
        let top = Array(stats.eigene.hauptuebungen.prefix(3))
        if !top.isEmpty {
            StatsKopf(titel: String(localized: "Rekorde"), zusatz: String(localized: "gegen deine Freunde"))
            ListenKarte {
                ForEach(Array(top.enumerated()), id: \.element.id) { i, u in
                    if i > 0 { Haarlinie() }
                    let p = StatsLogik.platzFreunde(kg: u.kg, uebung: u.id, freunde: freunde)
                    NavigationLink { UebungDetailView(id: u.id) } label: {
                        GymZeile(titel: UebungsKatalog.nachId[u.id]?.name ?? String(localized: "Übung"),
                                 untertitel: p.von > 1 ? String(localized: "Platz \(p.rang) von \(p.von)") : String(localized: "Noch kein Freund mit dieser Übung")) {
                            Text(RekordLogik.text(u.kg)).font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var mitFreunden: some View {
        let crew = CrewDienst.von(umgebung)
        let laufen = (crew.antwort?.herausforderungen ?? []).filter(\.dabei).count
        let anzahl = GymCrewQuelle.eintraege(umgebung).count
        return VStack(alignment: .leading, spacing: Abstand.s) {
            StatsKopf(titel: String(localized: "Mit Freunden"))
            ListenKarte {
                NavigationLink { StatsTrainingspartnerSeite() } label: {
                    StatsMenueZeile(symbol: "figure.strengthtraining.traditional", farbe: .purple, titel: String(localized: "Trainingspartner"))
                }
                .buttonStyle(.plain)
                Haarlinie()
                NavigationLink { StatsHerausforderungenSeite() } label: {
                    StatsMenueZeile(symbol: "flame.fill", farbe: Bereichsfarbe.splits, titel: String(localized: "Herausforderungen"),
                                    wert: laufen > 0 ? String(localized: "\(laufen) laufen") : nil)
                }
                .buttonStyle(.plain)
                Haarlinie()
                NavigationLink { StatsRekordeFreundeSeite() } label: {
                    StatsMenueZeile(symbol: "trophy.fill", farbe: Bereichsfarbe.erfolge, titel: String(localized: "Rekorde der Freunde"))
                }
                .buttonStyle(.plain)
                Haarlinie()
                NavigationLink { StatsFreundeSeite() } label: {
                    StatsMenueZeile(symbol: "person.2.fill", farbe: Bereichsfarbe.freunde, titel: String(localized: "Freunde verwalten"),
                                    wert: anzahl > 0 ? "\(anzahl)" : nil)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var einladenKnoepfe: some View {
        VStack(spacing: Abstand.xs) {
            Button(action: einladen) {
                Label("Freunde einladen", systemImage: "qrcode").font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.text)
            .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
            Button("Code eingeben", action: codeEingeben)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.akzent)
                .frame(minHeight: Abstand.tippflaeche)
        }
        .padding(.top, Abstand.s)
    }
}
