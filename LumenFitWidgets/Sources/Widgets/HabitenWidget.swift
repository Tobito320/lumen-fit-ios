import AppIntents
import SwiftUI
import WidgetKit

/// Idee 96: interaktives Widget, Gewohnheiten direkt auf dem Home-Bildschirm abhaken. Der Tipp läuft im Widget-Prozess (`HabitAbhakenIntent`), schreibt nur
/// Dateien in die Gruppe und zeigt den Haken sofort; die App übernimmt ihn beim nächsten Öffnen oder sofort, wenn sie läuft.
struct HabitenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.onlyus.lumen-fit.habiten", provider: SnapshotAnbieter()) { eintrag in
            HabitenAnsicht(eintrag: eintrag)
        }
        .configurationDisplayName("Gewohnheiten")
        .description("Hake deine Gewohnheiten direkt auf dem Home-Bildschirm ab.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct HabitenAnsicht: View {
    let eintrag: SnapshotEintrag
    @Environment(\.widgetFamily) private var familie

    private var habits: [WidgetHabitKachel] { Array((eintrag.snapshot?.habits ?? []).prefix(familie == .systemMedium ? 4 : 2)) }

    var body: some View {
        WidgetRahmen(snapshot: eintrag.snapshot, link: RouteURL.url(fuer: .heute)) { farben in
            if habits.isEmpty {
                WidgetLeerAnsicht(farben: farben, titel: String(localized: "Noch keine Gewohnheiten"), text: String(localized: "Öffne Lumen Fit einmal, dann erscheinen sie hier."))
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Gewohnheiten", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(farben.text2)
                        .lineLimit(1)
                        .widgetAccentable()
                    if familie == .systemMedium {
                        HStack(alignment: .top, spacing: 12) {
                            spalte(Array(habits.prefix(2)), farben)
                            spalte(Array(habits.dropFirst(2)), farben)
                        }
                    } else {
                        spalte(habits, farben)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private func spalte(_ liste: [WidgetHabitKachel], _ farben: WidgetFarben) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(liste) { habit in zeile(habit, farben) }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// Eine Zeile mit dem Tipp-Knopf (mindestens 44 pt hoch). Ohne Profilkennung im Snapshot (alte Datei) ist die Zeile nur eine Anzeige.
    @ViewBuilder
    private func zeile(_ habit: WidgetHabitKachel, _ farben: WidgetFarben) -> some View {
        let wert = WidgetAnzeige.wertHeute(habit, snapshot: eintrag.snapshot, jetzt: eintrag.date)
        let fertig = WidgetAnzeige.erledigt(habit, wert: wert)
        let inhalt = HStack(spacing: 8) {
            ZStack {
                Circle().stroke(farben.text2.opacity(0.4), lineWidth: 2)
                if fertig {
                    Circle().fill(farben.akzent)
                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(farben.grund)
                } else {
                    Image(systemName: habit.symbol).font(.caption).foregroundStyle(farben.text)
                }
            }
            .frame(width: 28, height: 28)
            .widgetAccentable(fertig)
            VStack(alignment: .leading, spacing: 0) {
                Text(habit.name).font(.subheadline.weight(.semibold)).foregroundStyle(farben.text).lineLimit(1)
                Text(WidgetAnzeige.habitText(habit, wert: wert)).font(.caption).foregroundStyle(farben.text2).lineLimit(1)
            }
            Spacer(minLength: 0)
            if familie == .systemMedium, habit.serie >= 2 {
                Label("\(habit.serie)", systemImage: "flame.fill").font(.caption).foregroundStyle(farben.text2).lineLimit(1)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        if let profil = eintrag.snapshot?.profilKennung, !profil.isEmpty {
            let naechster = WidgetAnzeige.naechsterWert(zaehlen: habit.zaehlen, heute: wert, ziel: habit.ziel)
            Button(intent: HabitAbhakenIntent(habit: habit.id, wert: naechster, tag: Datum.text(eintrag.date), profil: profil)) { inhalt }
                .buttonStyle(.plain)
                .accessibilityLabel(sprechtext(habit, wert: wert))
                .accessibilityHint(habit.zaehlen && !fertig ? "Tippen zählt eins dazu" : (fertig ? "Tippen nimmt den Haken weg" : "Tippen hakt ab"))
        } else {
            inhalt
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(sprechtext(habit, wert: wert))
        }
    }

    private func sprechtext(_ habit: WidgetHabitKachel, wert: Int) -> String {
        "\(habit.name), \(WidgetAnzeige.habitText(habit, wert: wert))" + (habit.serie >= 2 ? String(localized: ", Serie \(habit.serie)") : "")
    }
}
