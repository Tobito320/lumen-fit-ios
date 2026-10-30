import SwiftUI

/// Fasten-Fenster (Idee 47): ein Tipp startet das Fenster, der Balken läuft von selbst (das System tickt), daneben die Restzeit und der Verlauf.
/// Nur `ProgressView(timerInterval:)` und `Text(timerInterval:)`, kein eigener Timer.
struct EssenFastenKarte: View {
    let essen: EssenStore
    @Environment(\.palette) private var palette

    var body: some View {
        let plan = essen.fastenPlan
        VStack(alignment: .leading, spacing: Abstand.m) {
            kopf(plan)
            if let laufend = essen.fastenLaufend {
                laufendesFenster(laufend)
            } else {
                Button { essen.fastenFensterStarten() } label: {
                    Label("Fasten starten", systemImage: "timer").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.lumenHauptknopf)
                .accessibilityHint("Startet das \(plan.name)-Fenster jetzt")
            }
            verlauf
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .lumenKartenFlaeche()
    }

    private func kopf(_ plan: FastenPlan) -> some View {
        HStack {
            Text("Fasten \(plan.name)").font(.headline).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.s)
            NavigationLink { EssenFastenView() } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text2)
                    .frame(minWidth: Abstand.tippflaeche, minHeight: Abstand.tippflaeche)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Fasten-Seite öffnen")
            if essen.fastenLaufend == nil {
                Menu {
                    ForEach(FastenPlan.allCases.filter { !$0.istTagesplan }) { p in
                        Button(p.name) { essen.fastenPlanSetzen(p) }
                    }
                } label: {
                    Label("Plan", systemImage: "chevron.up.chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: Abstand.tippflaeche)
                }
                .accessibilityLabel("Fastenplan wählen, jetzt \(plan.name)")
            }
        }
    }

    @ViewBuilder
    private func laufendesFenster(_ e: FastenEintrag) -> some View {
        let plan = FastenLogik.planVon(e)
        let ende = FastenLogik.geplantesEnde(start: e.start, plan: plan)
        // Das System zeichnet kurz nach `ende` neu und die Ansicht wechselt auf "Geschafft", ohne dass der Tab neu zeichnen muss.
        // Verglichen wird mit `Date.now`, nicht mit dem Zeitpunkt der Timeline: so kommt es auf deren erste Zeichnung nicht an.
        TimelineView(.explicit([ende.addingTimeInterval(1)])) { _ in
            let jetzt = Date.now
            if ende > jetzt {
                ProgressView(timerInterval: e.start...ende, countsDown: false) {
                    Text("Fenster läuft").font(.subheadline).foregroundStyle(palette.text2)
                } currentValueLabel: {
                    HStack(spacing: Abstand.xs) {
                        Text("noch").foregroundStyle(palette.text2)
                        Text(timerInterval: jetzt...ende, countsDown: true).monospacedDigit().foregroundStyle(palette.text)
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .tint(palette.akzent)
                .accessibilityLabel("Fasten läuft seit \(FastenLogik.zeitpunktText(e.start)), Plan \(plan.name)")
            } else {
                Label("Geschafft: \(plan.name) voll", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
            }
        }
        Button { essen.fastenFensterBeenden(e) } label: {
            Text("Fenster beenden").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
        }
        .buttonStyle(.bordered)
        Text("Gestartet \(FastenLogik.zeitpunktText(e.start))").font(.footnote).foregroundStyle(palette.text2)
    }

    @ViewBuilder
    private var verlauf: some View {
        let beendete = Array(FastenLogik.beendete(essen.fastenEintraege).prefix(5))
        if !beendete.isEmpty {
            Haarlinie()
            let serie = FastenLogik.serie(essen.fastenEintraege)
            Text(serie > 0 ? "Verlauf, \(serie) \(serie == 1 ? "Tag" : "Tage") in Folge geschafft" : "Verlauf")
                .font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
            ForEach(beendete) { e in
                let stunden = FastenLogik.dauerStunden(e) ?? 0
                let ziel = Double(FastenLogik.planVon(e).stunden)
                HStack(spacing: Abstand.m) {
                    Text(FastenLogik.zeitpunktText(e.start)).font(.footnote).monospacedDigit().foregroundStyle(palette.text2)
                        .frame(width: 96, alignment: .leading)
                    EssenBalken(anteil: stunden / max(ziel, 1))
                    Text("\(ErnaehrungLogik.zahl(stunden)) h").font(.footnote).monospacedDigit().foregroundStyle(palette.text)
                        .frame(width: 52, alignment: .trailing)
                    Image(systemName: FastenLogik.geschafft(e) ? "checkmark.circle.fill" : "minus.circle.fill")
                        .foregroundStyle(palette.text2).accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(FastenLogik.zeitpunktText(e.start)), \(ErnaehrungLogik.zahl(stunden)) Stunden von \(Int(ziel)), \(FastenLogik.geschafft(e) ? "geschafft" : "nicht ganz")")
            }
        }
    }
}
