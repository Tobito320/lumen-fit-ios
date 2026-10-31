// Quelle: Lovea Health/GymSession.swift (GymVerlaufView, GymMonat, GymVerlaufZeile; neu im Lumen-Design, ohne Partner)
import SwiftUI

/// Der Training-Verlauf: Diese Woche, Serie, Gesamt, ein Monatsraster zum Wischen (ältere Monate nach links) und alle Einheiten, neueste zuerst.
/// Tipp auf einen Tag oder eine Einheit öffnet sie zum Nachlesen; ein Tag nur mit Gym-Häkchen öffnet "Training nachtragen" für genau diesen Tag.
struct TrainingVerlaufView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau
    @State private var offen: String?
    @State private var nachtragen: NachtragZiel?
    @State private var tipp = 0

    /// Das Blatt "Training nachtragen": mit Tag (Häkchen ohne Einheit) oder frei.
    private struct NachtragZiel: Identifiable {
        let datum: String?
        var id: String { datum ?? "frei" }
    }

    var body: some View {
        if aufbau == .lovea {
            TageLoveaVerlauf()
        } else {
            lumenInhalt
        }
    }

    @ViewBuilder
    private var lumenInhalt: some View {
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)
        let sessions = umgebung.daten?.training.sessions ?? []
        let gym = umgebung.daten?.habits.werte(Habit.gym.id) ?? [:]
        let nurHaken = GymTageLogik.nurAbgehakt(sessions: sessions, gym: gym)
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                if sessions.isEmpty && nurHaken.isEmpty {
                    LeerZustand(stimmung: .bereit, satz: "Noch keine Einheit. Starte ein Training, dann steht es hier.", handlung: "Training starten") {
                        umgebung.router.oeffne(.gym(.training))
                    }
                    .lumenKartenFlaeche()
                } else {
                    kennzahlen(sessions, heute: heute)
                    monate(sessions, nurHaken: nurHaken, heute: heute)
                }
                liste(sessions)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .navigationTitle("Trainingstage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { nachtragen = NachtragZiel(datum: nil) } label: {
                    Image(systemName: "plus").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                }
                .accessibilityLabel("Training nachtragen")
            }
        }
        .navigationDestination(item: $offen) { EinheitNachlesenView(sessionId: $0) }
        .sheet(item: $nachtragen) { EinheitNachtragenBlatt(datum: $0.datum, jetzt: umgebung.uhr()) }
        .haptik(.auswahl, bei: tipp)
    }

    // MARK: Kennzahlen

    private func kennzahlen(_ sessions: [GymSession], heute: String) -> some View {
        let woche = TrainingLogik.dieseWoche(sessions, heute: heute)
        let serie = TrainingLogik.serieWochen(sessions, heute: heute)
        return ListenKarte {
            HStack(alignment: .top, spacing: Abstand.l) {
                zahl("Diese Woche", wert: Double(woche), einheit: nil)
                zahl("Serie", wert: Double(serie), einheit: serie == 1 ? "Woche" : "Wochen")
                zahl("Gesamt", wert: Double(sessions.count), einheit: nil)
            }
            .padding(Abstand.l)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Diese Woche \(woche), Serie \(serie) \(serie == 1 ? "Woche" : "Wochen"), insgesamt \(sessions.count)")
    }

    private func zahl(_ titel: String, wert: Double, einheit: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.caption).foregroundStyle(palette.text2)
            HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                RollZahl(wert: wert, format: .number.precision(.fractionLength(0)))
                    .font(.title2.weight(.bold)).fontDesign(.rounded).foregroundStyle(palette.text)
                if let einheit { Text(einheit).font(.footnote).foregroundStyle(palette.text2) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Monate

    private func monate(_ sessions: [GymSession], nurHaken: Set<String>, heute: String) -> some View {
        let tage = Set(sessions.map { Datum.text($0.start) })
        let aeltester = (tage.union(nurHaken)).min()
        let anzahl = EinheitZeitenLogik.monateAnzahl(aeltesterTag: aeltester, heute: heute)
        return DiagrammKarte(aussage: "\(tage.count) \(tage.count == 1 ? "Trainingstag" : "Trainingstage") insgesamt",
                             kernzeile: "Wische nach rechts für frühere Monate. Gefüllt ist Training, ein Ring ist nur das Gym-Häkchen.") {
            EinheitMonatsPager(anzahl: anzahl) { zurueck in
                EinheitMonat(tage: tage, nurHaken: nurHaken, heute: heute, monateZurueck: zurueck) { tag in
                    tipp += 1
                    tagTippen(tag, sessions)
                }
                .padding(.horizontal, Abstand.xs)
            }
        }
    }

    /// Tipp auf einen Tag im Monat: die Einheit öffnen, sonst (nur Häkchen) das Nachtragen für genau diesen Tag.
    private func tagTippen(_ tag: String, _ sessions: [GymSession]) {
        if let s = GymTageLogik.einheit(am: tag, in: sessions) {
            offen = s.id
        } else {
            nachtragen = NachtragZiel(datum: tag)
        }
    }

    // MARK: Liste

    @ViewBuilder
    private func liste(_ sessions: [GymSession]) -> some View {
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: Abstand.s) {
                GymAbschnitt(titel: "Alle Einheiten")
                ListenKarte {
                    ForEach(sessions) { s in
                        Button { offen = s.id } label: { zeile(s) }
                            .buttonStyle(.plain)
                        if s.id != sessions.last?.id { Haarlinie() }
                    }
                }
            }
        }
    }

    private func zeile(_ s: GymSession) -> some View {
        let tag = umgebung.daten?.training.tag(id: s.tag)
        return HStack(spacing: Abstand.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Datum.anzeige(Datum.text(s.start))).font(.body.weight(.semibold)).foregroundStyle(palette.text)
                Text(EinheitZeitenLogik.zeitText(s)).font(.subheadline).foregroundStyle(s.ende == nil ? palette.text : palette.text2)
                Text(EinheitZeitenLogik.untertitel(s, tag: tag)).font(.footnote).foregroundStyle(palette.text2)
            }
            Spacer(minLength: Abstand.s)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.m)
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Öffnet die Einheit")
    }
}

/// Monate nebeneinander, Wischen blättert; die letzte Seite ist der laufende Monat (nie die Zukunft).
struct EinheitMonatsPager<Inhalt: View>: View {
    let anzahl: Int
    @ViewBuilder let inhalt: (_ monateZurueck: Int) -> Inhalt

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach((0..<anzahl).reversed(), id: \.self) { zurueck in
                    inhalt(zurueck).containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.trailing)
    }
}

/// Ein Monat als Gitter (immer sechs Zeilen): Trainingstage gefüllt, Tage nur mit Gym-Häkchen als Ring. Mit `tippen` sind diese Tage antippbar.
struct EinheitMonat: View {
    let tage: Set<String>
    let nurHaken: Set<String>
    let heute: String
    let monateZurueck: Int
    var tippen: ((String) -> Void)?
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    private static let spalten = Array(repeating: GridItem(.flexible(), spacing: Abstand.xs), count: 7)

    var body: some View {
        let gitter = EinheitZeitenLogik.gitter42(heute: heute, monateZurueck: monateZurueck)
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text(EinheitZeitenLogik.monatTitel(gitter)).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 0) {
                ForEach(HabitLogik.wochentagKuerzel, id: \.self) { k in
                    Text(k).font(.caption2.weight(.semibold)).foregroundStyle(palette.text2).frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            LazyVGrid(columns: Self.spalten, spacing: Abstand.xs) {
                ForEach(gitter.indices, id: \.self) { i in zelle(gitter[i]) }
            }
        }
    }

    @ViewBuilder
    private func zelle(_ tag: String?) -> some View {
        if let tag {
            let an = tage.contains(tag)
            let ring = !an && nurHaken.contains(tag)
            let text = EinheitZeitenLogik.tagSprechtext(tag, training: an, nurHaken: ring)
            if let tippen, an || ring {
                Button { tippen(tag) } label: { nummer(tag, an: an, ring: ring) }
                    .buttonStyle(.federnd)
                    .accessibilityLabel(text)
                    .accessibilityHint(an ? "Öffnet die Einheit" : "Training für diesen Tag nachtragen")
            } else {
                nummer(tag, an: an, ring: ring).accessibilityLabel(text)
            }
        } else {
            Color.clear.frame(minHeight: Abstand.tippflaeche)
        }
    }

    private func nummer(_ tag: String, an: Bool, ring: Bool) -> some View {
        let gruen = GymFarbe.gruen(schema: schema, kontrast: kontrast)
        return Text(HabitRaster.tagesnummer(tag))
            .font(.footnote.weight(an ? .bold : .regular).monospacedDigit())
            .foregroundStyle(an ? palette.grund : tag == heute ? palette.text : palette.text2)
            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            .background(an ? gruen : Color.clear, in: .circle)
            .overlay { if ring { Circle().strokeBorder(gruen, lineWidth: 2) } }
            .contentShape(.circle)
    }
}
