import SwiftUI

// Trainingspartner (Auftrag 09.11.2026: "ein Freund auswählen ... dann sieht man die Tage, wann geplant ist für mich und für den"): ein Freund aus der Crew,
// unabhängig von Lovea, jede Seite wählt für sich. Sein Stand liegt im bisherigen Partner-Platz (`KontoDienst.partnerWaehlen`); hier die Woche zusammen,
// die Wahl und der Abschnitt auf der Crew-Seite.

/// Ein Tag in "Eure Woche".
enum CrewTagArt: Equatable, Sendable { case trainiert, geplant, frei }

struct CrewWochenTag: Identifiable, Equatable, Sendable {
    /// `yyyy-MM-dd`
    var tag: String
    /// "Mo" bis "So"
    var kurz: String
    var art: CrewTagArt
    var heute: Bool
    var id: String { tag }
}

/// Die Woche von Montag bis Sonntag für dich und eine Person: trainiert schlägt geplant. Rein und testbar.
enum CrewWocheLogik {
    nonisolated static let kurz = [String(localized: "Mo"), String(localized: "Di"), String(localized: "Mi"), String(localized: "Do"), String(localized: "Fr"), String(localized: "Sa"), String(localized: "So")]
    nonisolated static let lang = [String(localized: "Montag"), String(localized: "Dienstag"), String(localized: "Mittwoch"), String(localized: "Donnerstag"), String(localized: "Freitag"), String(localized: "Samstag"), String(localized: "Sonntag")]

    /// `geplant`: Wochentage 1 (Montag) bis 7; `trainiert`: Tage `yyyy-MM-dd`.
    static func woche(geplant: Set<Int>, trainiert: Set<String>, heute: String) -> [CrewWochenTag] {
        let montag = Datum.wochenstart(heute)
        return (0..<7).map { i in
            let tag = Datum.addTage(montag, i)
            let art: CrewTagArt = trainiert.contains(tag) ? .trainiert : geplant.contains(i + 1) ? .geplant : .frei
            return CrewWochenTag(tag: tag, kurz: kurz[i], art: art, heute: tag == heute)
        }
    }

    /// Meine geplanten Wochentage dieser Woche, mit verlegten Tagen und Testwoche (`TrainingLogik.tag`).
    static func geplant(plan: TrainingsPlan, heute: String) -> Set<Int> {
        let montag = Datum.wochenstart(heute)
        return Set((0..<7).compactMap { i in TrainingLogik.tag(plan, datum: Datum.addTage(montag, i)) == nil ? nil : i + 1 })
    }

    /// Meine Trainingstage dieser Woche bis heute.
    static func trainiert(sessions: [GymSession], heute: String) -> Set<String> {
        let montag = Datum.wochenstart(heute)
        return Set(sessions.map { Datum.text($0.start) }.filter { $0 >= montag && $0 <= heute })
    }

    /// Geplante Wochentage einer Person aus ihrem Plan; nil ohne Freigabe plan oder ohne Plan.
    static func geplant(_ datei: ZusammenfassungDatei) -> Set<Int>? {
        guard datei.freigaben.contains(.plan), let plan = datei.heute.plan else { return nil }
        return Set(plan.tage.flatMap(\.wochentage).filter { (1...7).contains($0) })
    }

    /// Trainingstage dieser Woche einer Person (eine Datei von letzter Woche zählt nicht); nil ohne Freigabe gym.
    static func trainiert(_ datei: ZusammenfassungDatei, heute: String) -> Set<String>? {
        guard datei.freigaben.contains(.gym) else { return nil }
        let montag = Datum.wochenstart(heute)
        return Set((datei.heute.gymTage ?? []).filter { $0 >= montag && $0 <= heute })
    }

    /// "Du: Montag trainiert, Mittwoch geplant." Freie Tage bleiben weg.
    static func vorlesen(_ name: String, _ woche: [CrewWochenTag]) -> String {
        let teile = woche.enumerated().compactMap { i, t -> String? in
            switch t.art {
            case .trainiert: String(localized: "\(lang[i]) trainiert")
            case .geplant: String(localized: "\(lang[i]) geplant")
            case .frei: nil
            }
        }
        return "\(name): " + (teile.isEmpty ? String(localized: "nichts geplant") : teile.joined(separator: ", "))
    }
}

/// "Eure Woche": je eine Reihe für dich und die Person, sieben Tage: voller Punkt trainiert, Ring geplant, kleiner Punkt frei; heute steht fett.
/// Teilt die Person Plan oder Gym nicht, steht das darunter statt einer leeren Reihe.
struct CrewWocheZusammen: View {
    let name: String
    let datei: ZusammenfassungDatei
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @ScaledMetric(relativeTo: .footnote) private var namensBreite: CGFloat = 76

    var body: some View {
        let heute = Datum.text(umgebung.uhr())
        let training = umgebung.daten?.training
        let ich = CrewWocheLogik.woche(geplant: training.map { CrewWocheLogik.geplant(plan: $0.plan, heute: heute) } ?? [],
                                       trainiert: CrewWocheLogik.trainiert(sessions: training?.sessions ?? [], heute: heute), heute: heute)
        let geplant = CrewWocheLogik.geplant(datei)
        let trainiert = CrewWocheLogik.trainiert(datei, heute: heute)
        VStack(alignment: .leading, spacing: Abstand.s) {
            HStack(spacing: 0) {
                Color.clear.frame(width: namensBreite, height: 1)
                ForEach(ich) { t in
                    Text(t.kurz).font(.caption2.weight(t.heute ? .bold : .regular)).foregroundStyle(t.heute ? palette.text : palette.text2)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            reihe(String(localized: "Du"), ich)
            if geplant != nil || trainiert != nil {
                reihe(name, CrewWocheLogik.woche(geplant: geplant ?? [], trainiert: trainiert ?? [], heute: heute))
            }
            if geplant == nil {
                Text("\(name) teilt den Plan noch nicht mit dir.").font(.footnote).foregroundStyle(palette.text2)
            }
            HStack(spacing: Abstand.m) {
                legende(.trainiert, String(localized: "trainiert"))
                legende(.geplant, String(localized: "geplant"))
            }
            .font(.caption)
            .foregroundStyle(palette.text2)
            .accessibilityHidden(true)
        }
    }

    private func reihe(_ wer: String, _ woche: [CrewWochenTag]) -> some View {
        HStack(spacing: 0) {
            Text(wer).font(.footnote.weight(.semibold)).foregroundStyle(palette.text).lineLimit(1).frame(width: namensBreite, alignment: .leading)
            ForEach(woche) { t in punkt(t.art).frame(maxWidth: .infinity, minHeight: 28) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CrewWocheLogik.vorlesen(wer, woche))
    }

    @ViewBuilder
    private func punkt(_ art: CrewTagArt) -> some View {
        switch art {
        case .trainiert: Circle().fill(palette.akzent).frame(width: 14, height: 14)
        case .geplant: Circle().strokeBorder(palette.text, lineWidth: 2).frame(width: 14, height: 14)
        case .frei: Circle().fill(palette.haar).frame(width: 6, height: 6)
        }
    }

    private func legende(_ art: CrewTagArt, _ text: String) -> some View {
        HStack(spacing: Abstand.xs) {
            punkt(art).frame(width: 14, height: 14)
            Text(text)
        }
    }
}

/// Der Trainingspartner oben auf der Crew-Seite: wer es ist (Tipp: seine Seite), eure Woche, teilen und ändern. Ohne Wahl ein Knopf zum Wählen.
struct CrewPartnerAbschnitt: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    /// Nur damit die Ansicht eine neue Wahl sofort zeigt; die Wahl selbst schreibt `KontoDienst.partnerWaehlen`.
    @AppStorage(VerbindungenLogik.partnerSchluessel) private var gewaehlt: String?
    @State private var wahlOffen = false
    @State private var teilt = false

    var body: some View {
        let personen = CrewLogik.crew(GymCrewQuelle.eintraege(umgebung))
        let partner = VerbindungenLogik.partner(personen, gewaehlt: gewaehlt)
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Trainingspartner").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityAddTraits(.isHeader)
            ListenKarte {
                if let partner {
                    let name = CrewLogik.name(partner)
                    NavigationLink { CrewFreundSeite(id: partner.id) } label: {
                        GymZeile(titel: name, untertitel: String(localized: "Jede Seite wählt für sich")) {
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    if let d = partner.daten {
                        Haarlinie()
                        CrewWocheZusammen(name: name, datei: d).padding(Abstand.l)
                    }
                    if !Set(partner.ich.zeigt).isSuperset(of: ["plan", "gym"]) {
                        Haarlinie()
                        Button { Task { await teilen(partner) } } label: {
                            GymZeile(titel: String(localized: "Plan und Training mit \(name) teilen"), untertitel: String(localized: "Dann sieht \(name) deine Trainingstage, deinen Plan und deine Sätze.")) {
                                if teilt { ProgressView() }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(teilt)
                    }
                    Haarlinie()
                    Button { wahlOffen = true } label: { GymZeile(titel: String(localized: "Anderen Trainingspartner wählen")) }
                        .buttonStyle(.plain)
                } else {
                    GymZeile(titel: String(localized: "Noch keiner gewählt"), untertitel: String(localized: "Wähle einen Freund: ihr seht eure Woche nebeneinander."))
                    if !personen.isEmpty {
                        Haarlinie()
                        Button { wahlOffen = true } label: { GymZeile(titel: String(localized: "Trainingspartner wählen")) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $wahlOffen) { CrewPartnerWahlBlatt() }
    }

    /// Meine Seite zeigt der Person zusätzlich Plan, Gym und Verlauf (Freigabe-Stufe Crew); was schon geteilt ist, bleibt.
    private func teilen(_ partner: VerbindungEintrag) async {
        teilt = true
        let zeigt = Set(partner.ich.zeigt).union(["plan", "gym", "verlauf"])
        _ = await umgebung.konto.verbindungAendern(partner.id, ["zeigt": zeigt.sorted()])
        teilt = false
    }
}

/// Wählen, wer Trainingspartner ist: die aktiven Personen der Crew oder keiner. Wirkt sofort.
struct CrewPartnerWahlBlatt: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @AppStorage(VerbindungenLogik.partnerSchluessel) private var gewaehlt: String?

    var body: some View {
        let personen = CrewLogik.crew(GymCrewQuelle.eintraege(umgebung))
        let aktuell = VerbindungenLogik.partner(personen, gewaehlt: gewaehlt)?.id
        NavigationStack {
            List {
                Section {
                    ForEach(personen) { e in
                        Button { waehle(e.id) } label: { zeile(CrewLogik.name(e), an: e.id == aktuell) }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(e.id == aktuell ? .isSelected : [])
                    }
                } footer: {
                    Text("Jede Seite wählt für sich. Wählt ihr euch gegenseitig, seht ihr beide eure Woche nebeneinander.")
                }
                Section {
                    Button { waehle(VerbindungenLogik.keinPartner) } label: { zeile(String(localized: "Keiner"), an: aktuell == nil) }
                        .buttonStyle(.plain)
                }
            }
            .navigationTitle("Trainingspartner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func zeile(_ titel: String, an: Bool) -> some View {
        HStack {
            Text(titel).foregroundStyle(palette.text)
            Spacer()
            if an { Image(systemName: "checkmark").foregroundStyle(palette.akzent).accessibilityHidden(true) }
        }
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(.rect)
    }

    private func waehle(_ id: String) {
        umgebung.konto.partnerWaehlen(id)
        dismiss()
    }
}
