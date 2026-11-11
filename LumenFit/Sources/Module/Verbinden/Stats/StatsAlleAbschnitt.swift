import SwiftUI

/// Stats > Alle: echte Bestenliste der Öffentlichen (die ersten fünf, "···", die Nachbarn um mich). Privat stehe ich nur für mich darin
/// ("Du · Privat, nur du siehst dich"), Platz und Prozent rechnet das Gerät. Mitmachen nur über das Blatt mit den Regeln.
/// Melden und Blockieren: lange auf einen Namen drücken (Apple verlangt beides für Inhalte anderer).
struct StatsAlleAbschnitt: View {
    let mass: StatsMass
    let mitmachen: () -> Void
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var markieren: (eintrag: StatsEintrag, blockieren: Bool)?
    @State private var fehler: String?
    @State private var einstellungOffen = false

    private var stats: StatsDienst { StatsDienst.von(umgebung) }

    var body: some View {
        let e = umgebung.daten?.einstellungen.werte ?? Einstellungen()
        let oeffentlich = e.statsOeffentlich && e.statsSpitzname != nil
        let eigene = stats.eigene
        // Rekorde nach Trainingsjahr; Schritte immer gegen alle.
        let kohorte = StatsLogik.vergleich(stats.antwort?.alle ?? [], jahr: eigene.jahr)
        let vergleich = mass.istSchritte ? StatsLogik.vergleich(stats.antwort?.alle ?? [], jahr: nil) : kohorte
        let mein = mass.wert(eigene)
        let andere = vergleich.andere.compactMap { a in mass.wert(a).map { (id: a.id, name: a.name, wert: $0) } }
        let zeilen = StatsLogik.zeilen(ichName: oeffentlich ? (e.statsSpitzname ?? String(localized: "Du")) : String(localized: "Du"), ichWert: mein, andere: andere)
        let platz = StatsLogik.platz(zeilen)
        let prozent = mein.flatMap { m in StatsLogik.prozent(mein: Double(m), andere: andere.map { Double($0.wert) }) }
        VStack(alignment: .leading, spacing: Abstand.l) {
            StatsPlatzKarte(
                gruppe: vergleich.jahr.map { String(localized: "Alle \(StatsLogik.jahrText($0))") } ?? String(localized: "Alle"),
                rang: platz.rang, von: platz.von, wert: mein.map { mass.wertText($0, jetzt: umgebung.uhr()) } ?? StatsTexte.schritteNichtDabei,
                satz: mein == nil ? StatsTexte.schritteWie : prozent.map { StatsLogik.satzAlle(prozent: $0, mass: mass, jahr: vergleich.jahr) }, stimmung: .bereit,
                sichtSymbol: oeffentlich ? "globe" : "lock.fill",
                sichtText: oeffentlich ? String(localized: "Öffentlich als „\(e.statsSpitzname ?? "")“") : String(localized: "Privat: nur du siehst dich in der Liste."),
                knopf: oeffentlich ? String(localized: "Ändern") : String(localized: "Mitmachen"),
                aktion: { if oeffentlich { einstellungOffen = true } else { mitmachen() } })
            if oeffentlich, stats.antwort?.ich.ausgeblendet == true {
                Label("Dein Eintrag ist für andere ausgeblendet, bis wir ihn geprüft haben.", systemImage: "eye.slash")
                    .font(.footnote).foregroundStyle(palette.text2)
            }
            liste(zeilen, oeffentlich: oeffentlich, eintraege: vergleich.andere)
            rekorde(jahr: kohorte.jahr)
            Text("Alle sehen nur Spitznamen, Punkte und Schritte, nie Gewicht, Körper oder andere Gesundheitsdaten. Melden oder Blockieren: lange auf einen Namen drücken.")
                .font(.footnote).foregroundStyle(palette.text2).fixedSize(horizontal: false, vertical: true)
        }
        .confirmationDialog(markierenTitel, isPresented: Binding(get: { markieren != nil }, set: { if !$0 { markieren = nil } }), titleVisibility: .visible,
                            presenting: markieren) { m in
            Button(m.blockieren ? String(localized: "Blockieren") : String(localized: "Melden"), role: .destructive) {
                Task {
                    if m.blockieren { fehler = await stats.blockieren(m.eintrag.id) } else { fehler = await stats.melden(m.eintrag.id) }
                }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: { m in
            Text(m.blockieren ? String(localized: "Ihr seht euch in Alle nicht mehr.") : String(localized: "Du siehst den Eintrag nicht mehr. Wir prüfen ihn."))
        }
        .alert("Das hat nicht geklappt", isPresented: Binding(get: { fehler != nil }, set: { if !$0 { fehler = nil } })) {
            Button("Verstanden", role: .cancel) {}
        } message: { Text(fehler ?? "") }
        .sheet(isPresented: $einstellungOffen) { StatsEinstellungBlatt() }
    }

    private var markierenTitel: String {
        guard let m = markieren else { return "" }
        return m.blockieren ? String(localized: "\(m.eintrag.name) blockieren?") : String(localized: "\(m.eintrag.name) melden?")
    }

    private func liste(_ zeilen: [CrewRang], oeffentlich: Bool, eintraege: [StatsEintrag]) -> some View {
        let nachId = Dictionary(eintraege.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let teile = StatsLogik.ausschnitt(anzahl: zeilen.count, ich: zeilen.firstIndex(where: \.ich))
        return ListenKarte {
            ForEach(Array(teile.enumerated()), id: \.offset) { n, teil in
                if n > 0 { Haarlinie() }
                if let i = teil {
                    let z = zeilen[i]
                    if z.ich {
                        StatsZeileView(zeile: z, untertitel: oeffentlich ? String(localized: "Öffentlich") : String(localized: "Privat, nur du siehst dich"))
                    } else {
                        StatsZeileView(zeile: z)
                            .contextMenu {
                                if let eintrag = nachId[z.id] {
                                    Button { markieren = (eintrag, false) } label: { Label("Melden", systemImage: "exclamationmark.bubble") }
                                    Button(role: .destructive) { markieren = (eintrag, true) } label: { Label("Blockieren", systemImage: "hand.raised") }
                                }
                            }
                    }
                } else {
                    Text("···").font(.headline).foregroundStyle(palette.text2).frame(maxWidth: .infinity, minHeight: 32).accessibilityHidden(true)
                }
            }
            if zeilen.count < 2 {
                Text("Noch macht hier niemand öffentlich mit.").font(.footnote).foregroundStyle(palette.text2).padding(Abstand.l)
            }
        }
    }

    @ViewBuilder
    private func rekorde(jahr: Int?) -> some View {
        let top = Array(stats.eigene.hauptuebungen.prefix(3))
        if !top.isEmpty {
            StatsKopf(titel: String(localized: "Rekorde"), zusatz: jahr.map { String(localized: "gegen alle \(StatsLogik.jahrText($0))") } ?? String(localized: "gegen alle"))
            ListenKarte {
                ForEach(Array(top.enumerated()), id: \.element.id) { i, u in
                    if i > 0 { Haarlinie() }
                    let p = StatsLogik.prozentAlle(kg: u.kg, uebung: u.id, rekorde: stats.antwort?.rekorde ?? [:], jahr: jahr)
                    NavigationLink { UebungDetailView(id: u.id) } label: {
                        GymZeile(titel: UebungsKatalog.nachId[u.id]?.name ?? String(localized: "Übung"),
                                 untertitel: p.map { String(localized: "Stärker als \($0.prozent) %") } ?? String(localized: "Noch zu wenige zum Vergleich")) {
                            Text(RekordLogik.text(u.kg)).font(.body.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
