// Quelle: Lovea Health/Heute/HeuteView.swift (Hinweise), Lovea Health/Heute/Hinweise*.swift (HinweisKarte)
import SwiftUI

/// "Das fällt mir auf": Einsichten aus dem Training als einklappbarer Abschnitt mit Zähler. Jede Einsicht klappt Tipp und Basis auf;
/// gesperrte (noch zu wenig Daten) zeigen einen Fortschrittsbalken. Offen oder zu merkt sich die App.
struct EinsichtenKarte: View {
    let einsichten: [HeuteHinweis]
    @AppStorage("heute.einsichten.offen") private var offen = true
    @State private var aufgeklappt: Set<String> = []
    @State private var umgeschaltet = 0
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus

    private var anim: Animation? { bewegungAus ? nil : Feder.schnell }
    private var freie: Int { einsichten.filter { $0.art != .gesperrt }.count }

    var body: some View {
        ListenKarte {
            VStack(spacing: 0) {
                Button {
                    withAnimation(anim) { offen.toggle() }
                    umgeschaltet += 1
                } label: {
                    HStack(spacing: Abstand.m) {
                        Image(systemName: "lightbulb.fill").foregroundStyle(palette.text2).frame(width: 24).accessibilityHidden(true)
                        Text("Das fällt mir auf").font(.headline).foregroundStyle(palette.text)
                        Text("\(freie)").font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(palette.aufAkzent)
                            .padding(.horizontal, Abstand.s).padding(.vertical, 2).background(palette.akzent, in: .capsule)
                            .contentTransition(.numericText())
                        Spacer(minLength: Abstand.s)
                        Image(systemName: "chevron.down").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2)
                            .rotationEffect(.degrees(offen ? 180 : 0)).accessibilityHidden(true)
                    }
                    .padding(Abstand.l)
                    .frame(minHeight: Abstand.tippflaeche)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Das fällt mir auf, \(freie) \(freie == 1 ? "Einsicht" : "Einsichten")")
                .accessibilityValue(offen ? "aufgeklappt" : "zugeklappt")
                .accessibilityAddTraits(.isButton)
                if offen {
                    ForEach(einsichten) { e in
                        Haarlinie()
                        if e.art == .gesperrt { gesperrt(e) } else { einsicht(e) }
                    }
                }
            }
            .clipped()
        }
        .haptik(.auswahl, bei: umgeschaltet)
    }

    private func einsicht(_ e: HeuteHinweis) -> some View {
        let auf = aufgeklappt.contains(e.id)
        return VStack(alignment: .leading, spacing: Abstand.s) {
            Button {
                withAnimation(anim) { if auf { aufgeklappt.remove(e.id) } else { aufgeklappt.insert(e.id) } }
                umgeschaltet += 1
            } label: {
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    HStack {
                        Text(e.titel).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                        Spacer(minLength: Abstand.s)
                        Text(e.zahl).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(palette.text2)
                        Image(systemName: "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(palette.text2)
                            .rotationEffect(.degrees(auf ? 180 : 0)).accessibilityHidden(true)
                    }
                    Text(e.text).font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(auf ? "Klappt Tipp und Basis zu" : "Klappt Tipp und Basis auf")
            if auf {
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    Label(e.tipp, systemImage: "arrow.right.circle").font(.footnote.weight(.medium)).foregroundStyle(palette.text)
                    Text("Basis: \(e.basis)").font(.caption).foregroundStyle(palette.text2)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func gesperrt(_ e: HeuteHinweis) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            HStack {
                Image(systemName: "lock.fill").foregroundStyle(palette.text2).accessibilityHidden(true)
                Text(e.titel).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                Spacer(minLength: Abstand.s)
                Text(e.zahl).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(palette.text2)
            }
            Text(e.text).font(.footnote).foregroundStyle(palette.text2)
            ProgressView(value: min(1, max(0, e.fortschritt ?? 0))).tint(palette.text2)
                .accessibilityLabel("Fortschritt").accessibilityValue(((e.fortschritt ?? 0) * 100).formatted(.number.precision(.fractionLength(0))) + " Prozent")
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
