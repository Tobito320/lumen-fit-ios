// Quelle: Lovea Health/GymNeu/PlanView (neu im Lumen-Design)
import SwiftUI

/// Eigener Plan (Entwurf `eigen`, Idee 27): die Woche mit Trainings- und Ruhetagen samt Hinweisen und "Zurück auf Plan", die Tage mit ihren Übungen,
/// dann Split-Bibliothek, ein eigener freier Split, Kalender und Übungskatalog. Jede Änderung geht als `gym.plan` raus (`TrainingStore.planSichern`).
struct PlanView: View {
    let sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var tagId: IdentifiableText?
    @State private var bibliothek = false
    @State private var frei = false
    @State private var neuerName = ""
    @State private var neuerTag = false

    struct IdentifiableText: Identifiable { var id: String }

    @ViewBuilder
    var body: some View {
        lumenBody
    }

    private var lumenBody: some View {
        ScrollView {
            if let training = sitzung.training {
                inhalt(training)
                    .padding(.horizontal, Abstand.l)
                    .padding(.bottom, Abstand.xl)
            } else {
                LeerZustand(stimmung: .denkt, satz: String(localized: "Der Plan lädt noch."))
            }
        }
        .sheet(item: $tagId) { PlanTagBlatt(sitzung: sitzung, tagId: $0.id) }
        .navigationDestination(isPresented: $bibliothek) { SplitBibliothekView(sitzung: sitzung) }
        .sheet(isPresented: $frei) { SplitFreiBlatt(sitzung: sitzung) }
        .alert("Neuer Tag", isPresented: $neuerTag) {
            TextField("Name, zum Beispiel Beine", text: $neuerName)
            Button("Anlegen") {
                if let t = sitzung.training { t.planSichern(PlanEditor.neuerTag(t.plan, name: neuerName)) }
                neuerName = ""
            }
            Button("Abbrechen", role: .cancel) { neuerName = "" }
        }
    }

    private func inhalt(_ training: TrainingStore) -> some View {
        let plan = training.plan
        return VStack(alignment: .leading, spacing: Abstand.l) {
            Text("Tage, Übungen und Sets selbst festlegen. Ein Split aus der Bibliothek ist die Vorlage.")
                .font(.subheadline).foregroundStyle(palette.text2)
            if plan.tage.isEmpty {
                LeerZustand(stimmung: .bereit, satz: String(localized: "Du hast noch keinen Plan. Wähl einen Split aus der Bibliothek oder bau deinen eigenen."),
                            handlung: String(localized: "Split wählen")) { bibliothek = true }
            } else {
                woche(plan, training: training)
                hinweise(plan, training: training)
                tage(plan)
            }
            quellen(plan)
        }
    }

    // MARK: Woche

    private func woche(_ plan: TrainingsPlan, training: TrainingStore) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            GymAbschnitt(titel: plan.splitName ?? String(localized: "Dein Plan"))
            ListenKarte {
                ForEach(1...7, id: \.self) { w in
                    wochenZeile(plan, w, training: training)
                    if w < 7 { Haarlinie() }
                }
                // Früher "Diese Woche" im Training-Tab; das Verlegen selbst steht auf der Seite des Tages.
                if WochenLogik.verlegt(plan, heute: Datum.text(umgebung.uhr())) {
                    Haarlinie()
                    GymZeile(titel: String(localized: "Zurück auf Plan"), untertitel: String(localized: "Verlegte Tage gelten wieder wie im Plan.")) {
                        Button("Zurücksetzen") { training.verlegungenLoeschen() }.buttonStyle(.bordered).controlSize(.large)
                    }
                }
            }
        }
    }

    private func wochenZeile(_ plan: TrainingsPlan, _ w: Int, training: TrainingStore) -> some View {
        let art = RuhetagLogik.art(plan, w)
        let text: String
        switch art {
        case .training(let t): text = t.name.isEmpty ? String(localized: "Training") : t.name
        case .ruhe: text = String(localized: "Ruhetag")
        case .offen: text = String(localized: "Noch nicht geplant")
        }
        return GymZeile(titel: TrainingLogik.wochentagName[w - 1]) {
            Menu {
                ForEach(plan.tage) { t in
                    Button(t.name.isEmpty ? String(localized: "Training") : t.name) { training.planSichern(RuhetagLogik.setzen(plan, w, tag: t.id)) }
                }
                Button("Ruhetag") { training.planSichern(RuhetagLogik.setzen(plan, w, tag: nil)) }
            } label: {
                Text(text).foregroundStyle(art == .offen ? palette.text2 : palette.text).frame(minHeight: Abstand.tippflaeche)
            }
            .accessibilityLabel("\(TrainingLogik.wochentagName[w - 1]): \(text)")
            .accessibilityHint("Training oder Ruhetag wählen")
        }
    }

    @ViewBuilder
    private func hinweise(_ plan: TrainingsPlan, training: TrainingStore) -> some View {
        let liste = RuhetagLogik.hinweise(plan)
        if !liste.isEmpty {
            ListenKarte {
                ForEach(liste) { h in
                    GymZeile(titel: h.text) {
                        if let tausch = h.tausch, tausch.count == 2 {
                            Button("Übernehmen") { training.planSichern(RuhetagLogik.tauschen(plan, tausch[0], tausch[1])) }
                                .buttonStyle(.bordered).controlSize(.large)
                        }
                    }
                    if h.id != liste.last?.id { Haarlinie() }
                }
            }
        }
    }

    // MARK: Tage

    private func tage(_ plan: TrainingsPlan) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            GymAbschnitt(titel: String(localized: "Tage"))
            ListenKarte {
                ForEach(plan.tage) { t in
                    Button { tagId = IdentifiableText(id: t.id) } label: {
                        GymZeile(titel: t.name.isEmpty ? String(localized: "Training") : t.name,
                                 untertitel: "\(TrainingLogik.wochentageText(t.wochentage)) · \(ZeitSchaetzung.umfang(t))") {
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    if t.id != plan.tage.last?.id { Haarlinie() }
                }
                Haarlinie()
                Button { neuerTag = true } label: {
                    GymZeile(titel: String(localized: "Tag hinzufügen"))
 { Image(systemName: "plus").accessibilityHidden(true) }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Bibliothek, freier Split, Katalog

    private func quellen(_ plan: TrainingsPlan) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            GymAbschnitt(titel: String(localized: "Mehr"))
            ListenKarte {
                Button { bibliothek = true } label: {
                    GymSymbolZeile(symbol: "square.grid.2x2.fill", farbe: Bereichsfarbe.splits, titel: String(localized: "Split-Bibliothek"),
                                   untertitel: String(localized: "Fertige Pläne für 2 bis 6 Tage, auch nur für eine Woche testen"))
                }
                .buttonStyle(.plain)
                Haarlinie()
                Button { frei = true } label: {
                    GymSymbolZeile(symbol: "square.and.pencil", farbe: Bereichsfarbe.splits, titel: String(localized: "Eigenen Split anlegen"),
                                   untertitel: String(localized: "1 bis 6 Tage, du benennst sie und füllst sie selbst"))
                }
                .buttonStyle(.plain)
                Haarlinie()
                NavigationLink { KalenderView() } label: {
                    GymSymbolZeile(symbol: "calendar", farbe: Bereichsfarbe.verlauf, titel: String(localized: "Kalender"),
                                   untertitel: String(localized: "Trainings, geplante Tage und Partner"))
                }
                .buttonStyle(.plain)
                Haarlinie()
                NavigationLink { UebungsSucheView(titel: String(localized: "Übungen")) } label: {
                    GymSymbolZeile(symbol: "dumbbell.fill", farbe: Bereichsfarbe.energie, titel: String(localized: "Übungskatalog"),
                                   untertitel: String(localized: "Alle Übungen mit Anleitung"))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
