// Quelle: Lovea Health/GymNeu/PlanView (neu im Lumen-Design)
import SwiftUI

/// Der Plan (Idee 27): die Woche mit Trainings- und Ruhetagen samt Hinweisen, die Tage mit ihren Übungen, die Split-Bibliothek,
/// ein eigener freier Split und der Übungskatalog. Jede Änderung geht als `gym.plan` raus (`TrainingStore.planSichern`).
struct PlanView: View {
    let sitzung: GymSitzung
    @Environment(\.palette) private var palette
    @State private var tagId: IdentifiableText?
    @State private var bibliothek = false
    @State private var frei = false
    @State private var neuerName = ""
    @State private var neuerTag = false

    struct IdentifiableText: Identifiable { var id: String }

    var body: some View {
        ScrollView {
            if let training = sitzung.training {
                inhalt(training)
                    .padding(.horizontal, Abstand.l)
                    .padding(.bottom, Abstand.xl)
            } else {
                LeerZustand(stimmung: .denkt, satz: "Der Plan lädt noch.")
            }
        }
        .sheet(item: $tagId) { PlanTagBlatt(sitzung: sitzung, tagId: $0.id) }
        .sheet(isPresented: $bibliothek) { SplitBibliothekView(sitzung: sitzung) }
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
            if plan.tage.isEmpty {
                LeerZustand(stimmung: .bereit, satz: "Du hast noch keinen Plan. Wähl einen Split aus der Bibliothek oder bau deinen eigenen.",
                            handlung: "Split wählen") { bibliothek = true }
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
            GymAbschnitt(titel: plan.splitName ?? "Dein Plan")
            ListenKarte {
                ForEach(1...7, id: \.self) { w in
                    wochenZeile(plan, w, training: training)
                    if w < 7 { Haarlinie() }
                }
            }
        }
    }

    private func wochenZeile(_ plan: TrainingsPlan, _ w: Int, training: TrainingStore) -> some View {
        let art = RuhetagLogik.art(plan, w)
        let text: String
        switch art {
        case .training(let t): text = t.name.isEmpty ? "Training" : t.name
        case .ruhe: text = "Ruhetag"
        case .offen: text = "Noch nicht geplant"
        }
        return GymZeile(titel: TrainingLogik.wochentagName[w - 1]) {
            Menu {
                ForEach(plan.tage) { t in
                    Button(t.name.isEmpty ? "Training" : t.name) { training.planSichern(RuhetagLogik.setzen(plan, w, tag: t.id)) }
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
            GymAbschnitt(titel: "Tage")
            ListenKarte {
                ForEach(plan.tage) { t in
                    Button { tagId = IdentifiableText(id: t.id) } label: {
                        GymZeile(titel: t.name.isEmpty ? "Training" : t.name,
                                 untertitel: "\(TrainingLogik.wochentageText(t.wochentage)) · \(ZeitSchaetzung.umfang(t))") {
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                        }
                    }
                    .buttonStyle(.plain)
                    if t.id != plan.tage.last?.id { Haarlinie() }
                }
                Haarlinie()
                Button { neuerTag = true } label: {
                    GymZeile(titel: "Tag hinzufügen") { Image(systemName: "plus").accessibilityHidden(true) }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Bibliothek, freier Split, Katalog

    private func quellen(_ plan: TrainingsPlan) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            GymAbschnitt(titel: "Mehr")
            ListenKarte {
                Button { bibliothek = true } label: {
                    GymZeile(titel: "Split-Bibliothek", untertitel: "Fertige Pläne für 2 bis 6 Tage, auch nur für eine Woche testen") {
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                Haarlinie()
                Button { frei = true } label: {
                    GymZeile(titel: "Eigenen Split anlegen", untertitel: "1 bis 6 Tage, du benennst sie und füllst sie selbst") {
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                Haarlinie()
                NavigationLink { UebungsSucheView() } label: {
                    GymZeile(titel: "Übungskatalog", untertitel: "\(UebungsKatalog.alle.count) Übungen mit Bild, Rekorden und Verlauf") {
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
