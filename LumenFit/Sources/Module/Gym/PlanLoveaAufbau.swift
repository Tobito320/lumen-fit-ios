// Quelle: Lovea Health/GymNeu/SplitAnsichten.swift (SplitBibliothekView :163, SplitBibliothekInhalt :66, GymChip :8, SplitWochenbild :25, GymPfeilZeile :40),
// Health/TrainingsPlanView.swift (WochenLeiste :177, PlanHinweisZeile :263, TagZeile :288)
import SwiftUI
import UIKit

/// Reine Logik des Plans im Lovea-Aufbau (`LumenAufbau.lovea`): Filter der Bibliothek, gewählter Tag im Editor, Texte der Zeilen.
/// Alles Lesen und Schreiben des Plans bleibt bei `TrainingStore` und `PlanEditor`.
enum PlanLoveaLogik {
    /// Lovea blendet "Für dich" aus, wenn es keine eigenen Splits gibt (`SplitAnsichten.swift:112`).
    static func hatEigene(_ splits: [SplitVorlage]) -> Bool { splits.contains(where: SplitLogik.istEigen) }

    static func artWahl(_ splits: [SplitVorlage]) -> [(id: String, text: String)] {
        SplitLogik.artWahl.filter { $0.id != "fuerdich" || hatEigene(splits) }
    }

    /// Wer eigene Splits hat, sieht zuerst nur die (Lovea `SplitAnsichten.swift:177`).
    static func startArt(_ splits: [SplitVorlage]) -> String? { hatEigene(splits) ? "fuerdich" : nil }

    /// Ein gemerktes "Für dich" ohne eigene Splits gilt als "Alle", sonst bliebe die Liste leer.
    static func wirksameArt(_ art: String?, _ splits: [SplitVorlage]) -> String? {
        art == "fuerdich" && !hatEigene(splits) ? nil : art
    }

    /// Der Tag, den der Editor zeigt: der zuletzt gewählte, sonst der Starttag, sonst der erste. Unbekannte Ids (gelöschter Tag) fallen weg.
    static func gewaehlterTag(_ plan: TrainingsPlan, gewaehlt: String?, start: String?) -> String? {
        for id in [gewaehlt, start] {
            if let id, plan.tage.contains(where: { $0.id == id }) { return id }
        }
        return plan.tage.first?.id
    }

    /// Lovea zeigt das Plus im Editor nur bis zur Obergrenze (`SplitEditorView.swift:51`, 1 bis 6 Tage).
    static func darfNeuerTag(_ plan: TrainingsPlan) -> Bool { plan.tage.count < SplitFrei.tageBereich.upperBound }

    static func tagName(_ t: TrainingsTag) -> String { t.name.isEmpty ? "Ohne Namen" : t.name }

    static func wochentageText(_ t: TrainingsTag) -> String {
        t.wochentage.isEmpty ? "flexibel" : TrainingLogik.wochentageText(t.wochentage)
    }

    static func uebungenText(_ t: TrainingsTag) -> String {
        t.uebungen.isEmpty ? "Noch keine Übungen" : t.uebungen.map(\.anzeigeName).joined(separator: " · ")
    }

    /// Kurztitel eines Wochentags in der Leiste: Name des Tages, "Ruhe" oder "?" (Lovea `TrainingsPlanView.swift:244`).
    static func titel(_ art: TagArt) -> String {
        switch art {
        case .training(let t): t.name.isEmpty ? "Training" : t.name
        case .ruhe: "Ruhe"
        case .offen: "?"
        }
    }

    static func beschreibung(_ art: TagArt) -> String {
        switch art {
        case .training(let t): t.name.isEmpty ? "Training" : t.name
        case .ruhe: "Ruhetag"
        case .offen: "noch nicht geplant"
        }
    }

    /// Gewicht über alle Sätze einer Übung: ein Wert, "gemischt" oder "ohne" (Lovea `SplitEditorView.swift:134`).
    static func kgText(_ u: PlanUebung) -> String {
        let kg = Set(u.saetze.map(\.kg))
        guard kg.count == 1, let eins = kg.first else { return kg.count > 1 ? "gemischt" : "ohne" }
        return eins.map { "\(TrainingLogik.kgText($0)) kg" } ?? "ohne"
    }

    static func wdhText(_ u: PlanUebung) -> String {
        Set(u.saetze.map(\.wdh)).count > 1 ? "gemischt" : "\(u.saetze.first?.wdh ?? 10)"
    }

    /// Farbe eines Plantags wie in Lovea (`TrainingsPlanView.swift:285`); flexible Tage lila.
    static func tagFarbe(_ index: Int) -> Color {
        [Color.blue, .orange, .pink, .teal, .yellow, .purple][min(max(index, 0), TagFarbe.anzahl)]
    }
}

// MARK: - Bausteine

/// Kapsel für Filter, Tage und Wochentage: gewählt = gefüllt (Lovea `GymChip`).
struct PlanLoveaChip: View {
    let text: String
    var an = false

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .foregroundStyle(an ? Color(uiColor: .systemBackground) : Color.secondary)
            .background(an ? Color.primary : Color(uiColor: .tertiarySystemFill), in: Capsule())
            .frame(minHeight: 44)
            .contentShape(.rect)
    }
}

/// Sieben kurze Striche Mo bis So: an = Trainingstag (Lovea `SplitWochenbild`).
struct PlanLoveaWochenbild: View {
    let tage: [Bool]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(tage.enumerated()), id: \.offset) { _, an in
                Capsule().fill(an ? Color.primary : Color(uiColor: .tertiarySystemFill)).frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Zeile mit Titel, Unterzeile und Pfeil (Lovea `GymPfeilZeile`).
struct PlanLoveaPfeilZeile<Zusatz: View>: View {
    let titel: String
    let unter: String
    @ViewBuilder var zusatz: Zusatz

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.body.weight(.semibold)).foregroundStyle(Color.primary)
                Text(unter).font(.footnote).foregroundStyle(.secondary)
                zusatz
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
        }
        .frame(minHeight: 52)
        .padding(.vertical, 4)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

extension PlanLoveaPfeilZeile where Zusatz == EmptyView {
    init(titel: String, unter: String) {
        self.init(titel: titel, unter: unter) { EmptyView() }
    }
}

// MARK: - Bibliothek (Lovea "Splits")

/// Reiner Inhalt der Bibliothek (Lovea `SplitBibliothekInhalt`). Zwei Zeilen mehr als in Lovea, damit nichts von Lumen Fit verloren geht:
/// "Woche und Ruhetage" (Ruhetage, Vorschläge, alle Tage) und "Übungskatalog".
struct PlanLoveaBibliothekInhalt: View {
    let fuer: String
    let splits: [SplitVorlage]
    let planLeer: Bool
    var filter: Int? = nil
    var art: String? = nil
    var suche = ""
    var filtern: (Int?) -> Void = { _ in }
    var artWaehlen: (String?) -> Void = { _ in }
    var gefuehrt: () -> Void = {}
    var selbst: () -> Void = {}
    var frisch: () -> Void = {}
    var woche: () -> Void = {}
    var katalog: () -> Void = {}
    var waehlen: (SplitVorlage) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: gefuehrt) { PlanLoveaPfeilZeile(titel: "Geführt erstellen", unter: "Drei Fragen, dann ein Vorschlag") }.buttonStyle(.plain)
            Divider()
            Button(action: frisch) { PlanLoveaPfeilZeile(titel: "Eigenen Split anlegen", unter: "1 bis 6 Tage, jeder mit eigenem Namen") }.buttonStyle(.plain)
            if !planLeer {
                Divider()
                Button(action: selbst) { PlanLoveaPfeilZeile(titel: "Meinen Plan anpassen", unter: "Tage und Übungen selbst anlegen") }.buttonStyle(.plain)
                Divider()
                Button(action: woche) { PlanLoveaPfeilZeile(titel: "Woche und Ruhetage", unter: "Ruhetage, Vorschläge und alle Trainingstage") }.buttonStyle(.plain)
            }
            Divider()
            Button(action: katalog) {
                PlanLoveaPfeilZeile(titel: "Übungskatalog", unter: "\(UebungsKatalog.alle.count) Übungen mit Bild, Rekorden und Verlauf")
            }
            .buttonStyle(.plain)
            Text("FERTIGE SPLITS FÜR \(fuer.uppercased())")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 22)
                .accessibilityAddTraits(.isHeader)
            chips
            liste
        }
    }

    private var chips: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button { artWaehlen(nil) } label: { PlanLoveaChip(text: "Alle", an: art == nil) }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(art == nil ? .isSelected : [])
                    ForEach(Array(PlanLoveaLogik.artWahl(splits).enumerated()), id: \.offset) { _, a in
                        chip(a)
                    }
                }
            }
            tageChips
        }
    }

    @ViewBuilder
    private func chip(_ a: (id: String, text: String)) -> some View {
        let knopf = Button { artWaehlen(art == a.id ? nil : a.id) } label: { PlanLoveaChip(text: a.text, an: art == a.id) }
            .buttonStyle(.plain)
            .accessibilityAddTraits(art == a.id ? .isSelected : [])
        if a.id == "fuerdich" {
            knopf.loveaTipp(.loveaSplitFuerDich)
        } else {
            knopf
        }
    }

    private var tageChips: some View {
        HStack(spacing: 6) {
            Button { filtern(nil) } label: { PlanLoveaChip(text: "Alle", an: filter == nil) }
                .buttonStyle(.plain)
                .accessibilityLabel("Alle Tage")
                .accessibilityAddTraits(filter == nil ? .isSelected : [])
            ForEach(SplitLogik.tageWahl, id: \.self) { n in
                Button { filtern(n) } label: { PlanLoveaChip(text: "\(n)", an: filter == n) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(n) Tage")
                    .accessibilityAddTraits(filter == n ? .isSelected : [])
            }
            Text("Tage").font(.footnote).foregroundStyle(.secondary).padding(.leading, 4)
        }
    }

    @ViewBuilder
    private var liste: some View {
        let treffer = SplitLogik.treffer(splits, art: art, tage: filter, suche: suche)
        if treffer.isEmpty {
            Text(suche.isEmpty ? "Kein Split passt zu den Filtern." : "Nichts gefunden. Stell die Filter auf Alle.")
                .font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 14)
        }
        ForEach(Array(treffer.enumerated()), id: \.element.id) { i, v in
            if i > 0 { Divider() }
            Button { waehlen(v) } label: {
                PlanLoveaPfeilZeile(titel: v.name, unter: SplitLogik.unterzeile(v)) {
                    PlanLoveaWochenbild(tage: SplitLogik.wochenbild(v)).frame(width: 150).padding(.top, 6)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

/// Wohin die Bibliothek schiebt. Alles liegt im Stapel des Gym-Tabs; `Router` und `Route` bleiben unberührt.
enum PlanLoveaZiel: Hashable {
    case gefuehrt, frisch, woche, katalog
    case editor(String?)
    case vorschau(String)
}

/// Der Plan im Lovea-Aufbau: die Seite "Splits" von Lovea (`SplitBibliothekView`). Unter dem Segment "Plan" des Gym-Tabs
/// ersetzt sie `PlanView`, die Daten sind dieselben (`TrainingStore.planSichern`, `gym.plan`).
struct PlanLoveaView: View {
    let sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @State private var filter: Int?
    @State private var art: String? = "fuerdich"
    @State private var suche = ""
    @State private var ziel: PlanLoveaZiel?
    @State private var auswahl = 0

    var body: some View {
        let splits = SplitLogik.fuer(umgebung.daten?.ziele.koerper.geschlecht)
        ScrollView {
            if let training = sitzung.training {
                PlanLoveaBibliothekInhalt(
                    fuer: "dich", splits: splits, planLeer: training.plan.tage.isEmpty, filter: filter,
                    art: PlanLoveaLogik.wirksameArt(art, splits), suche: suche,
                    filtern: { n in
                        auswahl += 1
                        withAnimation(Feder.schnell) { filter = n }
                    },
                    artWaehlen: { a in
                        auswahl += 1
                        withAnimation(Feder.schnell) { art = a }
                    },
                    gefuehrt: { ziel = .gefuehrt }, selbst: { ziel = .editor(nil) }, frisch: { ziel = .frisch },
                    woche: { ziel = .woche }, katalog: { ziel = .katalog }, waehlen: { ziel = .vorschau($0.id) }
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            } else {
                LeerZustand(stimmung: .denkt, satz: "Der Plan lädt noch.")
            }
        }
        .searchable(text: $suche, prompt: "Split, Übung oder Muskel")
        .navigationDestination(item: $ziel) { seite($0) }
        .haptik(.auswahl, bei: auswahl)
    }

    @ViewBuilder
    private func seite(_ z: PlanLoveaZiel) -> some View {
        switch z {
        case .gefuehrt: PlanLoveaGefuehrtView(sitzung: sitzung, fertig: { ziel = nil })
        case .editor(let start): PlanLoveaEditorView(sitzung: sitzung, start: start)
        case .frisch: PlanLoveaFreiView(sitzung: sitzung) { ziel = .editor(nil) }
        case .woche: PlanLoveaWochenSeite(sitzung: sitzung)
        case .katalog: UebungsSucheView()
        case .vorschau(let id):
            if let v = SplitKatalog.alle.first(where: { $0.id == id }) { PlanLoveaVorschauView(sitzung: sitzung, vorlage: v, fertig: { ziel = nil }) }
        }
    }
}

// MARK: - Woche und Ruhetage (Lovea TrainingsPlanView)

/// Mo bis So: Name des Trainingstags, "Ruhe" oder ein oranges "?"; Tipp öffnet das Menü Training oder Ruhetag (Lovea `WochenLeiste`).
struct PlanLoveaWochenLeiste: View {
    let plan: TrainingsPlan
    var heute = 1
    var setzen: (Int, String?) -> Void = { _, _ in }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { w in
                Menu {
                    ForEach(plan.tage) { t in
                        Button(t.name.isEmpty ? "Ohne Namen" : t.name, systemImage: "dumbbell") { setzen(w, t.id) }
                    }
                    Button("Ruhetag", systemImage: "bed.double") { setzen(w, nil) }
                } label: {
                    spalte(w)
                }
                .accessibilityHint("Training oder Ruhetag festlegen")
            }
        }
        .padding(.vertical, 4)
    }

    private func spalte(_ w: Int) -> some View {
        let art = RuhetagLogik.art(plan, w)
        let form = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return VStack(spacing: 4) {
            Text(HabitLogik.wochentagKuerzel[w - 1])
                .font(.caption.weight(w == heute ? .bold : .semibold))
                .foregroundStyle(w == heute ? Color.primary : Color.secondary)
            Text(PlanLoveaLogik.titel(art))
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(form.fill(farbe(art)))
                .overlay {
                    if art == .offen { form.strokeBorder(Color.orange, style: StrokeStyle(lineWidth: 1, dash: [3, 2])) }
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(TrainingLogik.wochentagName[w - 1]): \(PlanLoveaLogik.beschreibung(art))")
    }

    private func farbe(_ art: TagArt) -> Color {
        switch art {
        case .training: HabitFarbe.mint.farbe.opacity(0.25)
        case .ruhe: Color(uiColor: .tertiarySystemFill)
        case .offen: Color.orange.opacity(0.15)
        }
    }
}

/// Ein Hinweis zur Woche mit Glühbirne; "Übernehmen", wenn er einen Tausch trägt (Lovea `PlanHinweisZeile`).
struct PlanLoveaHinweisZeile: View {
    let hinweis: PlanHinweis
    var uebernehmen: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(hinweis.text).font(.subheadline)
            } icon: {
                Image(systemName: "lightbulb.fill").foregroundStyle(Color.yellow)
            }
            if hinweis.tausch != nil {
                Button("Übernehmen", action: uebernehmen)
                    .buttonStyle(.lumenHauptknopf)
            }
        }
        .padding(.vertical, 4)
    }
}

/// "Push · Mo, Do" und die Übungen in einer Zeile (Lovea `TagZeile`).
struct PlanLoveaTagZeile: View {
    let tag: TrainingsTag
    var farbe: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle().fill(farbe).frame(width: 12, height: 12).accessibilityHidden(true)
                Text(PlanLoveaLogik.tagName(tag)).font(.headline).foregroundStyle(Color.primary)
                Spacer()
                Text(PlanLoveaLogik.wochentageText(tag)).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(PlanLoveaLogik.uebungenText(tag))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// Die Wochenseite aus Lovea (`TrainingsPlanView`, eigene Person): Woche, Vorschlag, Trainingstage. Hier liegt, was Lumen Fit im Plan
/// zusätzlich kann (Ruhetage, Hinweise mit Tausch, Tage ohne Wochentag, Tage löschen), im Aufbau der Lovea-Liste.
struct PlanLoveaWochenSeite: View {
    let sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @State private var editor: PlanLoveaEditorZiel?
    @State private var aenderung = 0

    private var training: TrainingStore? { sitzung.training }

    var body: some View {
        let plan = training?.plan ?? .leer
        List {
            Section {
                PlanLoveaWochenLeiste(plan: plan, heute: Datum.wochentag(Datum.text(umgebung.uhr()))) { w, tag in
                    training?.planSichern(RuhetagLogik.setzen(plan, w, tag: tag))
                    aenderung += 1
                }
            } header: {
                Text("Woche")
            } footer: {
                Text("Tipp auf einen Tag: Training oder Ruhetag.")
            }
            hinweise(plan)
            Section("Trainingstage") {
                if plan.tage.isEmpty {
                    Text("Noch kein Tag. Leg zum Beispiel \"Push\" oder \"Beine\" an.").foregroundStyle(.secondary)
                    Button("Ersten Trainingstag anlegen", systemImage: "plus.circle.fill") { neuerTag() }
                        .frame(minHeight: 44)
                }
                ForEach(plan.tage) { tag in
                    Button { editor = PlanLoveaEditorZiel(start: tag.id) } label: {
                        PlanLoveaTagZeile(tag: tag, farbe: PlanLoveaLogik.tagFarbe(TagFarbe.index(tag, in: plan)))
                    }
                    .buttonStyle(.federnd)
                }
                .onDelete { stellen in
                    var neu = plan
                    neu.tage.remove(atOffsets: stellen)
                    training?.planSichern(neu)
                    aenderung += 1
                }
                if !plan.tage.isEmpty {
                    Button("Tag hinzufügen", systemImage: "plus") { neuerTag() }.frame(minHeight: 44)
                }
            }
        }
        .navigationTitle("Mein Trainingsplan")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Neuer Tag", systemImage: "plus") { neuerTag() }
            }
        }
        .navigationDestination(item: $editor) { PlanLoveaEditorView(sitzung: sitzung, start: $0.start) }
        .haptik(.auswahl, bei: aenderung)
    }

    @ViewBuilder
    private func hinweise(_ plan: TrainingsPlan) -> some View {
        let liste = RuhetagLogik.hinweise(plan)
        if !liste.isEmpty {
            Section("Vorschlag") {
                ForEach(liste) { h in
                    PlanLoveaHinweisZeile(hinweis: h) {
                        guard let t = h.tausch, t.count == 2 else { return }
                        training?.planSichern(RuhetagLogik.tauschen(plan, t[0], t[1]))
                        aenderung += 1
                    }
                }
            }
        }
    }

    /// Wie `PlanView`: ein Tag ohne Wochentag, leerer Name wird "Tag N"; danach gleich in den Editor.
    private func neuerTag() {
        guard let training else { return }
        let neu = PlanEditor.neuerTag(training.plan, name: "")
        training.planSichern(neu)
        editor = PlanLoveaEditorZiel(start: neu.tage.last?.id)
        aenderung += 1
    }
}

/// Ziel "Editor an diesem Tag" als Hashable-Wert für `navigationDestination(item:)`.
struct PlanLoveaEditorZiel: Hashable, Identifiable {
    var start: String?
    var id: String { start ?? "" }
}
