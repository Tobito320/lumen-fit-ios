import SwiftUI

/// Der Trainingsplan des Partners (Gleichstand Lovea "Planansicht des Partners"): die Woche Mo bis So mit Trainings- und Ruhetagen, dann jeder Tag mit
/// seinen Übungen. Nur lesen. Er erscheint nur, wenn der Partner die Freigabe plan gegeben hat (sonst "Dein Partner hat das nicht freigegeben.").
struct PartnerPlanAnsicht: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        PartnerAnsichtRahmen(art: .plan, titel: "Trainingsplan") { datei in
            if let plan = datei.heute.plan { PartnerPlanInhalt(name: datei.profilName, plan: plan, heute: Datum.wochentag(Datum.text(umgebung.uhr()))) }
        }
    }
}

private struct PartnerPlanInhalt: View {
    let name: String
    let plan: PartnerPlan
    let heute: Int
    @Environment(\.palette) private var palette

    var body: some View {
        kopf.partnerErscheint(0)
        woche.partnerErscheint(1)
        if let tag = PartnerAnsichtLogik.heutigerTag(plan, wochentag: heute) { heutigeKarte(tag).partnerErscheint(2) }
        ForEach(Array(plan.tage.enumerated()), id: \.offset) { i, tag in
            tagKarte(tag).partnerErscheint(i + 3)
        }
    }

    private var kopf: some View {
        let tage = PartnerAnsichtLogik.trainingsTage(plan)
        return HeroKarte {
            VStack(alignment: .leading, spacing: Abstand.s) {
                Text("Plan von \(name)").font(.footnote.weight(.semibold))
                Text(plan.name ?? "Trainingsplan").font(.title2.weight(.bold)).fontDesign(.rounded)
                HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                    RollZahl(wert: Double(tage), format: .number.precision(.fractionLength(0))).font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                    Text(tage == 1 ? "Trainingstag pro Woche" : "Trainingstage pro Woche").font(.subheadline)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var woche: some View {
        let spalten = PartnerAnsichtLogik.spalten(plan, heute: heute)
        return VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Woche").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityAddTraits(.isHeader)
            HStack(spacing: 6) {
                ForEach(spalten) { spalte in spalteView(spalte) }
            }
            .padding(Abstand.m)
            .lumenKartenFlaeche()
        }
    }

    private func spalteView(_ s: PartnerAnsichtLogik.Spalte) -> some View {
        let form = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return VStack(spacing: 4) {
            Text(s.kuerzel).font(.caption.weight(s.istHeute ? .bold : .semibold)).foregroundStyle(s.istHeute ? palette.text : palette.text2)
            Text(s.titel)
                .font(.caption2.weight(.medium))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(form.fill(fuellung(s.art)))
                .overlay(form.strokeBorder(s.istHeute ? palette.text : Color.clear, lineWidth: 1.5))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(s.langerName): \(s.beschreibung)\(s.istHeute ? ", heute" : "")")
    }

    private func fuellung(_ art: PartnerAnsichtLogik.Spalte.Art) -> Color {
        switch art {
        case .training: palette.akzent.opacity(0.22)
        case .ruhe: palette.haar
        case .offen: Color.clear
        }
    }

    private func heutigeKarte(_ tag: PartnerPlanTag) -> some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: "dumbbell.fill").foregroundStyle(palette.text2).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Heute dran").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2)
                Text(tag.name.isEmpty ? "Training" : tag.name).font(.headline).foregroundStyle(palette.text)
            }
            Spacer(minLength: Abstand.m)
            Pille(text: tag.uebungen.count == 1 ? "1 Übung" : "\(tag.uebungen.count) Übungen")
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenKartenFlaeche()
        .accessibilityElement(children: .combine)
    }

    private func tagKarte(_ tag: PartnerPlanTag) -> some View {
        ListenKarte {
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name.isEmpty ? "Training" : tag.name).font(.headline).foregroundStyle(palette.text)
                Text(PartnerAnsichtLogik.wochentageText(tag)).font(.subheadline).foregroundStyle(palette.text2)
            }
            .padding(Abstand.l)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            if tag.uebungen.isEmpty {
                Haarlinie()
                Text("Noch keine Übungen.").font(.subheadline).foregroundStyle(palette.text2).padding(Abstand.l)
            }
            ForEach(Array(tag.uebungen.enumerated()), id: \.offset) { _, u in
                Haarlinie()
                HStack(spacing: Abstand.m) {
                    Text(u.name).foregroundStyle(palette.text)
                    Spacer(minLength: Abstand.m)
                    Text(PartnerAnsichtLogik.uebungText(u)).font(.subheadline).monospacedDigit().foregroundStyle(palette.text2)
                }
                .padding(.horizontal, Abstand.l)
                .frame(minHeight: Abstand.tippflaeche)
                .accessibilityElement(children: .combine)
            }
        }
    }
}
