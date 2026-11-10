import SwiftUI

/// Abschnittsüberschrift im Schlaf-Tab (für VoiceOver eine Überschrift).
struct SchlafAbschnittKopf: View {
    let text: LocalizedStringKey
    @Environment(\.palette) private var palette

    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text)
            .font(.title2.weight(.bold))
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Abstand.s)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Der Tab Schlaf: letzte Nacht als Heldenzahl, Phasen, Woche, Erholung mit HRV im eigenen Bereich; Werte-Chips, Schuld, Regelmäßigkeit, Quelle unter "Details".
/// `.verlauf` zeigt den Verlauf, `.werte` öffnet den Tab bei den Werten. Ohne Daten steht ein Leerzustand mit einer Handlung da.
struct SchlafTabView: View {
    var bereich: SchlafBereich = .letzteNacht

    var body: some View {
        if bereich == .verlauf {
            SchlafVerlaufView()
        } else {
            SchlafTabInhalt(zuWerten: bereich == .werte)
        }
    }
}

private struct SchlafTabInhalt: View {
    let zuWerten: Bool
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    @State private var band: [BandSchlafOp] = []
    @State private var position: String?
    @State private var version = 0
    @State private var eintragen = false
    @State private var detailsOffen = false

    private static let wertenAnker = "schlaf-werte"

    var body: some View {
        let uebersicht = SchlafDaten.uebersicht(umgebung, band: band)
        let _ = version
        ScrollView {
            VStack(spacing: Abstand.l) {
                if let letzte = uebersicht.letzte {
                    inhalt(uebersicht, letzte)
                } else {
                    leer(uebersicht)
                }
                SchlafDoppelKarte()
                PartnerKarte(bereich: .schlaf)
            }
            .scrollTargetLayout()
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.s)
        }
        .scrollPosition(id: $position, anchor: .top)
        .task {
            guard zuWerten else { return }
            detailsOffen = true
            try? await Task.sleep(for: .milliseconds(200))
            position = Self.wertenAnker
        }
        .navigationTitle("Schlaf")
        .lumenHintergrund()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Schlaf eintragen", systemImage: "plus") { eintragen = true }
            }
        }
        .sheet(isPresented: $eintragen) {
            SchlafEintragenView(tag: Datum.text(umgebung.uhr()), nacht: SchlafDaten.uebersicht(umgebung, band: band).letzte?.nacht) { version += 1 }
        }
        .task(id: umgebung.profil.aktiv?.id) { band = SchlafDaten.bandOps(umgebung) }
        .task { await beobachte() }
    }

    /// Neue Health- oder Band-Daten (Rückkehr in den Vordergrund, Health-Lieferung): die Band-Nächte neu lesen.
    private func beobachte() async {
        for await ereignis in umgebung.ereignisse.strom() {
            switch ereignis {
            case .healthAktualisiert, .vordergrund: band = SchlafDaten.bandOps(umgebung)
            default: break
            }
        }
    }

    // MARK: - Mit Daten

    @ViewBuilder
    private func inhalt(_ u: SchlafUebersicht, _ letzte: SchlafGewaehlteNacht) -> some View {
        SchlafCard(nacht: letzte, titel: u.titelLetzte, zielMinuten: u.ziel(fuer: letzte.nacht.tag), lumi: u.lumi(jetzt: umgebung.uhr()))
        phasen(u, letzte)
        wochenAbschnitt(u)
        erholungKarte(u)
        // Lumen: Werte, Schuld und Rhythmus, Leistung, Quelle, Ziel und Verlauf unter "Details".
        MehrKlappe(String(localized: "Details"), untertitel: String(localized: "Werte, Schuld, Rhythmus, Quelle, Verlauf"), offen: $detailsOffen) {
            werteAbschnitt(u)
            ruheAbschnitt(u)
            leistungsAbschnitt(u)
            weiter(u, letzte)
        }
    }

    @ViewBuilder
    private func wochenAbschnitt(_ u: SchlafUebersicht) -> some View {
        SchlafAbschnittKopf("Woche")
        SchlafWochenKarte(woche: u.woche, zielMinuten: u.zielMinuten)
    }

    @ViewBuilder
    private func erholungKarte(_ u: SchlafUebersicht) -> some View {
        SchlafAbschnittKopf("Erholung").id(Self.wertenAnker)
        SchlafBereichKarte(hrv: u.hrv, erholung: u.erholung)
    }

    @ViewBuilder
    private func werteAbschnitt(_ u: SchlafUebersicht) -> some View {
        SchlafAbschnittKopf("Werte")
        SchlafWerteChips(staende: u.chips)
    }

    @ViewBuilder
    private func ruheAbschnitt(_ u: SchlafUebersicht) -> some View {
        SchlafAbschnittKopf("Schuld und Rhythmus")
        SchlafSchuldKarte(schuld: u.schuld)
        SchlafRegelKarte(ergebnis: u.regelmaessigkeit)
    }

    @ViewBuilder
    private func leistungsAbschnitt(_ u: SchlafUebersicht) -> some View {
        let minuten = Dictionary(u.naechte.map { ($0.nacht.tag, $0.nacht.schlafMinuten) }, uniquingKeysWith: { $1 })
        let punkte = SchlafLeistung.punkte(umgebung.daten?.training.sessions ?? [], schlafMinuten: minuten)
        if punkte.count >= 3 {
            SchlafAbschnittKopf("Schlaf und Leistung")
            SchlafLeistungKarte(punkte: punkte)
        }
    }

    private func phasen(_ u: SchlafUebersicht, _ letzte: SchlafGewaehlteNacht) -> some View {
        let balken = PhasenBalken(nacht: letzte.nacht)
        let aussage = u.ohnePhasen ? String(localized: "Nur die Schlafzeit") : String(localized: "So hast du geschlafen")
        let kernzeile = u.ohnePhasen ? String(localized: "Geschlafen \(SchlafFormat.dauer(letzte.nacht.schlafMinuten))") : balken.kernzeile
        return DiagrammKarte(aussage: aussage, kernzeile: kernzeile) { balken }
    }

    /// Quelle der Nacht (Detail) und Verlauf.
    private func weiter(_ u: SchlafUebersicht, _ letzte: SchlafGewaehlteNacht) -> some View {
        ListenKarte {
            quelleZeile(u, letzte)
            Haarlinie()
            zielZeile
            Haarlinie()
            verlaufZeile
        }
        .buttonStyle(.plain)
    }

    private func quelleZeile(_ u: SchlafUebersicht, _ letzte: SchlafGewaehlteNacht) -> some View {
        NavigationLink {
            SchlafNachtDetailView(nacht: letzte, vergleich: u.vergleichLetzte, verlauf: u.vergleich)
        } label: {
            zeile(symbol: letzte.quelle.symbolName, titel: "Quelle: \(letzte.quelle.name)", text: "Details zur Nacht")
        }
    }

    private var zielZeile: some View {
        NavigationLink {
            SchlafZielView()
        } label: {
            zeile(symbol: "target", titel: "Schlafziel", text: "Extra-Tage, zum Beispiel vor dem Training")
        }
    }

    private var verlaufZeile: some View {
        NavigationLink(value: Route.schlaf(.verlauf)) {
            zeile(symbol: "chart.bar.fill", titel: "Verlauf", text: "Alle Nächte, übliche Zeiten")
        }
    }

    private func zeile(symbol: String, titel: LocalizedStringKey, text: LocalizedStringKey) -> some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: symbol).frame(width: 28).foregroundStyle(palette.text2).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.headline).foregroundStyle(palette.text)
                Text(text).font(.subheadline).foregroundStyle(palette.text2)
            }
            Spacer(minLength: Abstand.s)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
        }
        .padding(Abstand.l)
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Ohne Daten

    @ViewBuilder
    private func leer(_ u: SchlafUebersicht) -> some View {
        if umgebung.gesundheit.letzteAktualisierung == nil, umgebung.gesundheit.zugriff != .nichtVerfuegbar {
            ProgressView("Schlaf wird geholt")
                .frame(maxWidth: .infinity)
                .padding(Abstand.xxl)
        } else {
            LeerZustand(stimmung: u.lumi(jetzt: umgebung.uhr()), satz: String(localized: "Keine Schlafdaten. Trage dein Handy oder die Uhr nachts."),
                        handlung: String(localized: "In Health prüfen"), aktion: { SchlafHealthLink.oeffnen(openURL) })
        }
    }
}
