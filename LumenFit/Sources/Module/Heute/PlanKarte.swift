import SwiftUI

/// Karte "Plan für heute" (neues Design 10.11.2026): Kopf mit Serie "N Wochen in Folge", der Trainingstag groß, darunter "N Übungen · M min · Ziel",
/// die Woche mit heute in der Mitte (Haken für trainierte Tage, Buchstabe des Plantags, Strich für Ruhe; Tipp öffnet das Tag-Blatt) und der Hauptknopf.
/// Der Knopf startet das Training über den Port `trainingSteuerung` (Modul gym); ohne Plan führt er in den Plan-Bereich. Läuft ein Training, heißt er "Weiter";
/// nach dem Training öffnet "Einheit ansehen" die Einheit. "Heute locker" erscheint als Pille, wenn der Morgen-Check oder der Score es rät.
struct PlanKarte: View {
    let plan: HeutePlan
    var woche: [HeutePlanTag] = []
    var serieWochen = 0
    /// Ein Training läuft gerade: der Knopf heißt "Weiter".
    var laeuft = false
    /// Die heutige Einheit, wenn schon trainiert wurde.
    var einheitHeute: String?
    let starte: () -> Void
    var weiter: () -> Void = {}
    var oeffneTag: (String) -> Void = { _ in }
    var oeffneEinheit: (String) -> Void = { _ in }
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema

    var body: some View {
        ListenKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                kopf
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name).font(.title2.weight(.bold)).foregroundStyle(palette.text)
                    if let unter = unterzeile { Text(unter).font(.subheadline).foregroundStyle(palette.text2) }
                }
                .accessibilityElement(children: .combine)
                if plan.locker { Pille(text: "Heute locker", symbolName: "leaf.fill") }
                if zeigtTipp { Text(plan.tipp).font(.subheadline).foregroundStyle(palette.text2) }
                if woche.count == 7 { HeutePlanWoche(woche: woche, oeffne: oeffneTag) }
                knopf
            }
            .padding(Abstand.l)
        }
        .accessibilityElement(children: .contain)
    }

    private var kopf: some View {
        HStack(spacing: Abstand.s) {
            Image(systemName: "dumbbell.fill").foregroundStyle(palette.akzent).accessibilityHidden(true)
            Text("Plan für heute").font(.headline).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.s)
            if serieWochen > 0 {
                Label(serieWochen == 1 ? String(localized: "1 Woche in Folge") : String(localized: "\(serieWochen) Wochen in Folge"), systemImage: "flame.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(serieFarbe)
                    .labelStyle(HeuteEngesLabel())
            }
        }
    }

    /// Orange wie im Entwurf; hell dunkler, damit die Schrift 4,5:1 auf der Karte hält.
    private var serieFarbe: Color { schema == .dark ? Color.orange : LumenFarben.farbe(0xA84E00) }

    /// "5 Übungen · 65 min · Muskelaufbau" an einem Trainingstag; sonst nil.
    private var unterzeile: String? {
        guard plan.art == .training, plan.uebungen > 0 else { return nil }
        var teile = [plan.uebungen == 1 ? String(localized: "1 Übung") : String(localized: "\(plan.uebungen) Übungen")]
        if plan.minuten > 0 { teile.append(String(localized: "\(plan.minuten) min")) }
        if let ziel = plan.zielWort { teile.append(ziel) }
        return teile.joined(separator: " · ")
    }

    /// Der Tipp nur, wenn er mehr sagt als die Unterzeile: Ruhetag, kein Plan, erledigt, heute locker oder viele Tage am Stück.
    private var zeigtTipp: Bool { plan.art != .training || plan.locker || plan.uebungen == 0 }

    @ViewBuilder
    private var knopf: some View {
        if laeuft {
            Button(action: weiter) { Text("Weiter").frame(maxWidth: .infinity) }.buttonStyle(.lumenHauptknopf)
        } else if plan.art == .erledigt, let id = einheitHeute {
            Button { oeffneEinheit(id) } label: { Text("Einheit ansehen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
                .buttonStyle(.bordered)
                .tint(palette.akzent)
        } else if let text = plan.knopf {
            Button(action: starte) { Text(text).frame(maxWidth: .infinity) }.buttonStyle(.lumenHauptknopf)
        }
    }
}

/// Symbol und Text eng nebeneinander (Serie im Kartenkopf).
private struct HeuteEngesLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.accessibilityHidden(true)
            configuration.title
        }
    }
}

/// Die sieben Tage der Plan-Karte: heute in der Mitte als hervorgehobene Spalte "Heute". Vergangene Tage und heute öffnen das Tag-Blatt.
private struct HeutePlanWoche: View {
    let woche: [HeutePlanTag]
    let oeffne: (String) -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(woche) { tag in
                Button { oeffne(tag.tag) } label: {
                    VStack(spacing: Abstand.xs) {
                        Text(tag.istHeute ? "Heute" : LocalizedStringKey(tag.kuerzel))
                            .font(.caption.weight(tag.istHeute ? .bold : .medium))
                            .foregroundStyle(tag.istHeute ? palette.text : palette.text2)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        marke(tag)
                    }
                    .padding(.vertical, Abstand.s)
                    .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    .background(tag.istHeute ? palette.haar : Color.clear, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(tag.zukunft)
                .accessibilityLabel(beschreibung(tag))
                .accessibilityHint(tag.zukunft ? "" : "Öffnet den Tag")
            }
        }
    }

    @ViewBuilder
    private func marke(_ tag: HeutePlanTag) -> some View {
        switch tag.marke {
        case .erledigt:
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(palette.aufAkzentFlaeche)
                .frame(width: 26, height: 26)
                .background(palette.akzentFlaeche, in: .circle)
        case .training(let buchstabe, _):
            Text(buchstabe)
                .font(.caption.weight(.bold))
                .foregroundStyle(tag.istHeute ? palette.text : palette.text2)
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(tag.istHeute ? palette.akzent : palette.rand, lineWidth: tag.istHeute ? 2 : 1))
                .opacity(!tag.istHeute && !tag.zukunft ? 0.5 : 1)
        case .ruhe:
            Text("–").font(.callout).foregroundStyle(palette.text2).frame(width: 26, height: 26)
        }
    }

    private func beschreibung(_ tag: HeutePlanTag) -> String {
        let name = tag.istHeute ? String(localized: "Heute") : Datum.anzeige(tag.tag)
        switch tag.marke {
        case .erledigt: return String(localized: "\(name): trainiert")
        case .training(_, let plan): return tag.zukunft || tag.istHeute ? String(localized: "\(name): \(plan) geplant") : String(localized: "\(name): \(plan) geplant, nicht trainiert")
        case .ruhe: return String(localized: "\(name): Ruhetag")
        }
    }
}
