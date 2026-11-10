// Quelle: Lovea Health/LoveaWidgets/HabitWidget.swift
import AppIntents
import SwiftUI
import WidgetKit

/// Eine Gewohnheit zur Wahl für das Einzel-Widget. Die Liste kommt aus dem Snapshot in der Gruppe (nur die sichtbaren Gewohnheiten der App).
struct HabitAuswahl: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Gewohnheit" }
    static let defaultQuery = HabitAuswahlAbfrage()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct HabitAuswahlAbfrage: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [HabitAuswahl] {
        alle().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HabitAuswahl] { alle() }

    func defaultResult() async -> HabitAuswahl? { alle().first }

    private func alle() -> [HabitAuswahl] {
        (WidgetSnapshotDatei.lade()?.habits ?? []).map { HabitAuswahl(id: $0.id, name: $0.name) }
    }
}

/// Die Einstellung des Einzel-Widgets: welche Gewohnheit es zeigt.
struct HabitWahlIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Gewohnheit wählen" }
    static var description: IntentDescription { IntentDescription("Wähle die Gewohnheit, die das Widget zeigt.") }

    @Parameter(title: "Gewohnheit") var habit: HabitAuswahl?

    init() {}
}

struct HabitEinzelEintrag: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let auswahl: String?
}

struct HabitEinzelAnbieter: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HabitEinzelEintrag {
        HabitEinzelEintrag(date: Date(), snapshot: WidgetSnapshot.beispiel(), auswahl: "wasser")
    }

    func snapshot(for configuration: HabitWahlIntent, in context: Context) async -> HabitEinzelEintrag {
        context.isPreview ? placeholder(in: context) : aktuell(configuration)
    }

    func timeline(for configuration: HabitWahlIntent, in context: Context) async -> Timeline<HabitEinzelEintrag> {
        let eintrag = aktuell(configuration)
        let mitternacht = WidgetAnzeige.naechsteMitternacht(eintrag.date)
        let danach = HabitEinzelEintrag(date: mitternacht, snapshot: eintrag.snapshot, auswahl: eintrag.auswahl)
        return Timeline(entries: [eintrag, danach], policy: .after(mitternacht))
    }

    private func aktuell(_ konfiguration: HabitWahlIntent) -> HabitEinzelEintrag {
        HabitEinzelEintrag(date: Date(), snapshot: WidgetSnapshotDatei.lade(), auswahl: konfiguration.habit?.id)
    }
}

/// Eine einzelne Gewohnheit groß auf dem Home-Bildschirm (klein): ein Tipp hakt ab oder zählt eins dazu, wie im Gewohnheiten-Widget.
struct HabitEinzelWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "com.onlyus.lumen-fit.habit-einzel", intent: HabitWahlIntent.self, provider: HabitEinzelAnbieter()) { eintrag in
            HabitEinzelAnsicht(eintrag: eintrag)
        }
        .configurationDisplayName("Gewohnheit")
        .description("Eine Gewohnheit deiner Wahl, direkt abhakbar.")
        .supportedFamilies([.systemSmall])
    }
}

struct HabitEinzelAnsicht: View {
    let eintrag: HabitEinzelEintrag

    private var habit: WidgetHabitKachel? { WidgetAnzeige.habit(id: eintrag.auswahl, snapshot: eintrag.snapshot) }

    var body: some View {
        WidgetRahmen(snapshot: eintrag.snapshot, link: RouteURL.url(fuer: .heute)) { farben in
            if let habit {
                kachel(habit, farben)
            } else {
                WidgetLeerAnsicht(farben: farben, titel: String(localized: "Noch keine Gewohnheiten"), text: String(localized: "Öffne Lumen Fit einmal, dann kannst du eine wählen."))
            }
        }
    }

    @ViewBuilder
    private func kachel(_ habit: WidgetHabitKachel, _ farben: WidgetFarben) -> some View {
        let wert = WidgetAnzeige.wertHeute(habit, snapshot: eintrag.snapshot, jetzt: eintrag.date)
        let fertig = WidgetAnzeige.erledigt(habit, wert: wert)
        let anteil = habit.zaehlen ? WidgetAnzeige.anteil(wert, habit.ziel) : (fertig ? 1 : 0)
        let inhalt = VStack(alignment: .leading, spacing: 4) {
            ZStack {
                Circle().stroke(farben.text2.opacity(0.25), lineWidth: 5)
                Circle().trim(from: 0, to: anteil)
                    .stroke(farben.trainieren, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .widgetAccentable()
                Image(systemName: fertig ? "checkmark" : habit.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(farben.text)
            }
            .frame(width: 64, height: 64)
            Spacer(minLength: 0)
            Text(habit.name).font(.subheadline.weight(.semibold)).foregroundStyle(farben.text).lineLimit(1)
            HStack(spacing: 6) {
                Text(WidgetAnzeige.habitText(habit, wert: wert)).font(.caption).foregroundStyle(farben.text2).lineLimit(1)
                if habit.serie >= 2 {
                    Label("\(habit.serie)", systemImage: "flame.fill").font(.caption).foregroundStyle(farben.text2).lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        let sprech = "\(habit.name), \(WidgetAnzeige.habitText(habit, wert: wert))" + (habit.serie >= 2 ? String(localized: ", Serie \(habit.serie)") : "")
        if let profil = eintrag.snapshot?.profilKennung, !profil.isEmpty {
            let naechster = WidgetAnzeige.naechsterWert(zaehlen: habit.zaehlen, heute: wert, ziel: habit.ziel)
            Button(intent: HabitAbhakenIntent(habit: habit.id, wert: naechster, tag: Datum.text(eintrag.date), profil: profil)) { inhalt }
                .buttonStyle(.plain)
                .accessibilityLabel(sprech)
                .accessibilityHint(habit.zaehlen && !fertig ? "Tippen zählt eins dazu" : (fertig ? "Tippen nimmt den Haken weg" : "Tippen hakt ab"))
        } else {
            inhalt
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(sprech)
        }
    }
}
