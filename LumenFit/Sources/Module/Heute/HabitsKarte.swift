import SwiftUI

/// Gewohnheiten (Idee 16): ein Haken per Tipp, Zähl-Gewohnheiten wie Wasser mit Plus und Minus, dazu die sieben Quadrate der Woche und die Serie mit Flamme.
/// Ein Tipp auf den Namen öffnet die Seite der Gewohnheit (Zoom). Die Verwaltung (ausblenden, anlegen, löschen) steht in einer Zeile unten.
struct HabitsKarte: View {
    let habits: [HeuteHabitZeile]
    let tag: String
    let tippe: (HeuteHabitZeile) -> Void
    let weniger: (HeuteHabitZeile) -> Void
    let oeffne: (HeuteHabitZeile) -> Void
    let verwalte: () -> Void
    var zoom: Namespace.ID?
    @Environment(\.palette) private var palette

    @Environment(\.lumenAufbau) private var aufbau

    var body: some View {
        if aufbau == .lovea {
            // Lovea `HabitsSektion.swift:141`: jede Gewohnheit ist eine eigene Karte in ihrer Farbe.
            VStack(spacing: Abstand.m) {
                ForEach(habits) { zeile in
                    ListenKarte {
                        HeuteHabitReihe(zeile: zeile, tag: tag, tippe: { tippe(zeile) }, weniger: { weniger(zeile) }, oeffne: { oeffne(zeile) }, zoom: zoom)
                    }
                    .kartenTint(zeile.habit.tint)
                }
                ListenKarte { verwalten }
            }
        } else {
            standard
        }
    }

    private var verwalten: some View {
        Button(action: verwalte) {
            HStack {
                Text("Gewohnheiten verwalten").font(.subheadline).foregroundStyle(palette.text)
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.medium)).foregroundStyle(palette.text2).accessibilityHidden(true)
            }
            .padding(.horizontal, Abstand.l)
            .frame(minHeight: Abstand.tippflaeche)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var standard: some View {
        ListenKarte {
            HeuteKartenKopf(symbol: "checkmark.circle", titel: "Gewohnheiten").padding(Abstand.l)
            ForEach(habits) { zeile in
                Haarlinie()
                HeuteHabitReihe(zeile: zeile, tag: tag, tippe: { tippe(zeile) }, weniger: { weniger(zeile) }, oeffne: { oeffne(zeile) }, zoom: zoom)
            }
            Haarlinie()
            verwalten
        }
    }
}

private struct HeuteHabitReihe: View {
    let zeile: HeuteHabitZeile
    let tag: String
    let tippe: () -> Void
    let weniger: () -> Void
    let oeffne: () -> Void
    var zoom: Namespace.ID?
    @State private var mehr = 0
    @State private var minus = 0
    @State private var umgeschaltet = 0
    @State private var erreicht = 0
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus

    var body: some View {
        HStack(spacing: Abstand.m) {
            Button(action: oeffne) {
                HStack(spacing: Abstand.m) {
                    Image(systemName: zeile.habit.symbol).foregroundStyle(zeile.habit.tint).frame(width: 24).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(zeile.habit.name).font(.body).foregroundStyle(palette.text)
                        if let unter = unterzeile { Text(unter).font(.footnote.weight(.medium)).foregroundStyle(palette.text2) }
                        HStack(spacing: 3) {
                            woche
                            Spacer(minLength: 2)
                            flamme
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(zeile.habit.name), \(unterzeile ?? ""), heute \(zeile.erledigt ? "erledigt" : "offen")")
            .accessibilityHint("Öffnet die Details")
            .modifier(HabitZoomQuelle(id: zeile.habit.id, zoom: zoom))
            PartnerHabitKopf(habitID: zeile.habit.id)
            steuerung
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.xs)
        .frame(minHeight: 64)
        .haptik(.mehr, bei: mehr)
        .haptik(.weniger, bei: minus)
        .haptik(.auswahl, bei: umgeschaltet)
        .haptik(.erfolg, bei: erreicht)
        .accessibilityElement(children: .contain)
    }

    private var unterzeile: String? {
        let teile = [zeile.zaehlerText, zeile.serieText].compactMap { $0 }
        return teile.isEmpty ? nil : teile.joined(separator: " · ")
    }

    /// Sieben Quadrate Mo bis So; Zähl-Gewohnheiten füllen sich von unten.
    private var woche: some View {
        HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { i in
                HabitQuadrat(farbe: zeile.habit.tint, anteil: i < zeile.woche.count ? zeile.woche[i] : 0, istHeute: i == zeile.heuteIndex, groesse: 13)
            }
        }
        .accessibilityHidden(true)
    }

    private var flamme: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill").font(.caption.weight(.bold))
            Text("\(zeile.serie)")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(zeile.serie)))
                .animation(bewegungAus ? nil : Feder.weich, value: zeile.serie)
        }
        .foregroundStyle(zeile.serie > 0 ? zeile.habit.tint : palette.text2)
        .serieFeier(zeile.serie, schluessel: "serie.habit.\(zeile.habit.id)")
        .accessibilityHidden(true)
    }

    private func schritt(plus: Bool) {
        if plus {
            let ziel = HabitFeier.erreichtZiel(zeile.habit, wert: zeile.wert, ziel: zeile.ziel)
            withAnimation(bewegungAus ? nil : Feder.schnell) { tippe() }
            if ziel && HabitFeier.darfFeiern(habitId: zeile.habit.id, tag: tag) { erreicht += 1 } else if zeile.habit.zaehlen { mehr += 1 } else { umgeschaltet += 1 }
        } else {
            withAnimation(bewegungAus ? nil : Feder.schnell) { weniger() }
            minus += 1
        }
    }

    @ViewBuilder
    private var steuerung: some View {
        if zeile.habit.zaehlen {
            HStack(spacing: 0) {
                Button { schritt(plus: false) } label: { Image(systemName: "minus").frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche) }
                    .disabled(zeile.wert == 0)
                    .accessibilityLabel("\(zeile.habit.name) eins weniger")
                Button { schritt(plus: true) } label: {
                    Image(systemName: zeile.erledigt ? "checkmark.seal.fill" : "plus")
                        .symbolEffect(.bounce, value: bewegungAus ? 0 : mehr + erreicht)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                }
                .accessibilityLabel("\(zeile.habit.name) eins mehr")
            }
            .buttonStyle(.federnd)
            .foregroundStyle(zeile.erledigt ? zeile.habit.tint : palette.text)
            .accessibilityValue(zeile.zaehlerText ?? "")
        } else {
            Button { schritt(plus: true) } label: {
                ZStack {
                    Circle().strokeBorder(zeile.habit.tint.opacity(0.55), lineWidth: 2)
                    Circle().fill(zeile.habit.tint).scaleEffect(zeile.erledigt ? 1 : 0.3).opacity(zeile.erledigt ? 1 : 0)
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.aufHabitFarbe)
                        .scaleEffect(zeile.erledigt ? 1 : 0.4).opacity(zeile.erledigt ? 1 : 0)
                        .symbolEffect(.bounce, value: bewegungAus ? 0 : erreicht)
                }
                .frame(width: 30, height: 30)
                .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                .contentShape(Circle())
            }
            .buttonStyle(.federnd)
            .accessibilityLabel(zeile.habit.name)
            .accessibilityValue(zeile.erledigt ? "erledigt" : "offen")
            .accessibilityHint(zeile.erledigt ? "Nimmt den Haken weg" : "Hakt ab")
        }
    }
}

/// Quelle des Zoom-Übergangs zur Seite der Gewohnheit (nur mit Namensraum).
private struct HabitZoomQuelle: ViewModifier {
    let id: String
    let zoom: Namespace.ID?

    func body(content: Content) -> some View {
        if let zoom { content.matchedTransitionSource(id: id, in: zoom) } else { content }
    }
}
