// Quelle: Lovea Zyklus/ZyklusRootView.swift (Reiter, Sperre, Einstellungen)
import SwiftUI

/// Der Zyklus als eigene Seite (Profil, Zyklus): Sperre, Reiter je Modus, Einstellungen.
/// Sperrt sich, sobald die App in den Hintergrund geht.
struct ZyklusEinstieg: View {
    let store: ZyklusStore
    @State private var sperre: ZyklusSperre
    @State private var reiter = ZyklusReiter.heute
    @State private var einstellungen = false
    @Environment(\.scenePhase) private var phase
    @Environment(\.palette) private var palette
    @Environment(AppUmgebung.self) private var umgebung

    init(store: ZyklusStore) {
        self.store = store
        _sperre = State(initialValue: ZyklusSperre(store: store))
    }

    var body: some View {
        Group {
            if sperre.gesperrt {
                ZyklusSperreAnsicht(sperre: sperre)
            } else {
                inhalt
            }
        }
        .navigationTitle("Zyklus")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: phase) { _, neu in if neu == .background { sperre.sperren() } }
    }

    private var inhalt: some View {
        let modus = store.einstellung.modus
        let aktuell = ZyklusRootLogik.gueltig(reiter, modus: modus)
        return VStack(spacing: 0) {
            Picker("Bereich", selection: Binding(get: { aktuell }, set: { reiter = $0 })) {
                ForEach(ZyklusRootLogik.reiter(modus)) { Text(ZyklusRootLogik.titel($0, modus: modus)).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.s)
            .haptik(.auswahl, bei: aktuell)
            seite(aktuell, modus: modus)
        }
        .lumenHintergrund()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { einstellungen = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Zyklus-Einstellungen")
            }
        }
        .sheet(isPresented: $einstellungen) { ZyklusEinstellungenBlatt(store: store, sperre: sperre) }
        .task {
            if store.werte.healthLesen { await ZyklusHealthImport.importieren(zyklus: store, leser: umgebung.healthLeser) }
        }
    }

    @ViewBuilder
    private func seite(_ r: ZyklusReiter, modus: ZyklusModus) -> some View {
        switch r {
        case .heute: ZyklusHeuteView(store: store)
        case .kalender: ZyklusKalenderView(store: store)
        case .insights: ZyklusInsightsView(store: store)
        case .modus:
            switch modus {
            case .schwanger: ZyklusSchwangerView(store: store)
            case .kinderwunsch: ZyklusKinderwunschView(store: store)
            case .pille: ZyklusPilleView(store: store)
            case .zyklus: ZyklusHeuteView(store: store)
            }
        }
    }
}

/// Ziel des Links `lumenfit://profil?bereich=zyklus`: die Zyklus-Seite, oder ein kurzer Satz, solange der Zyklus aus ist.
struct ZyklusRouteSeite: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        if let zyklus = umgebung.daten?.zyklus, zyklus.aktiv {
            ZyklusEinstieg(store: zyklus)
        } else {
            Text("Der Zyklus ist aus. Du schaltest ihn im Profil ein.")
                .font(.body)
                .foregroundStyle(palette.text2)
                .multilineTextAlignment(.center)
                .padding(Abstand.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .lumenHintergrund()
        }
    }
}

/// Kleine Karte für die Heute-Seite: Training und Alltag passend zur Phase. Zeigt nichts, solange der Zyklus aus ist.
struct ZyklusHinweisAnsicht: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        if let hinweis = umgebung.daten?.zyklus.hinweisHeute() {
            ListenKarte {
                VStack(alignment: .leading, spacing: Abstand.s) {
                    Label("Zyklus: \(ZyklusPhaseStil.name(hinweis.phase))", systemImage: ZyklusPhaseStil.symbol(hinweis.phase))
                        .font(.headline)
                        .foregroundStyle(palette.text)
                    Text(hinweis.training).font(.subheadline).foregroundStyle(palette.text)
                    Text(hinweis.energie).font(.footnote).foregroundStyle(palette.text2)
                }
                .padding(Abstand.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Zeile in der Partner-Karte: was der andere von seinem Zyklus teilt (Phase, Tag, ein Satz).
struct ZyklusPartnerZeile: View {
    let zusammenfassung: ZyklusZusammenfassung
    @Environment(\.palette) private var palette

    var body: some View {
        if let phase = ZyklusPhase(rawValue: zusammenfassung.phase) {
            VStack(alignment: .leading, spacing: Abstand.xs) {
                Label(zusammenfassung.tag.map { "Zyklus: \(ZyklusPhaseStil.name(phase)), Tag \($0)" } ?? "Zyklus: \(ZyklusPhaseStil.name(phase))",
                      systemImage: ZyklusPhaseStil.symbol(phase))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text)
                Text(zusammenfassung.satz).font(.footnote).foregroundStyle(palette.text2)
                ForEach(zusammenfassung.tipps, id: \.self) { Text($0).font(.footnote).foregroundStyle(palette.text2) }
            }
            .padding(Abstand.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}
