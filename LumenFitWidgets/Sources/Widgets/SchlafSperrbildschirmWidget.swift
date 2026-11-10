// Quelle: Lovea Health/LoveaWidgets/LockscreenWidgets.swift
import SwiftUI
import WidgetKit

/// Schlaf auf dem Sperrbildschirm: rund als Ring gegen das Schlafziel mit der Dauer in der Mitte, in einer Zeile "Schlaf 7:12 h". Das System färbt selbst:
/// nur Text und Symbole, kein eigener Datenfarbton. Ohne Wert von heute steht ein Strich.
struct SchlafSperrbildschirmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.onlyus.lumen-fit.schlaf-sperrbildschirm", provider: SnapshotAnbieter()) { eintrag in
            SchlafSperrbildschirmAnsicht(eintrag: eintrag)
        }
        .configurationDisplayName("Schlaf")
        .description("Die letzte Nacht als Ring oder Zeile auf dem Sperrbildschirm.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

struct SchlafSperrbildschirmAnsicht: View {
    let eintrag: SnapshotEintrag
    @Environment(\.widgetFamily) private var familie

    private var werte: (schlaf: String?, erholung: String?, anteil: Double) { WidgetAnzeige.schlafZeile(eintrag.snapshot, jetzt: eintrag.date) }

    var body: some View {
        Group {
            switch familie {
            case .accessoryInline:
                Label(WidgetAnzeige.schlafInline(eintrag.snapshot, jetzt: eintrag.date), systemImage: "moon.zzz.fill")
            default:
                rund
            }
        }
        .widgetURL(RouteURL.url(fuer: .heute))
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    private var rund: some View {
        let w = werte
        return Gauge(value: w.anteil) {
            Image(systemName: "moon.zzz.fill")
        } currentValueLabel: {
            Text(w.schlaf.map { String($0.dropLast(2)) } ?? "–")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .accessibilityLabel("Schlaf")
        .accessibilityValue(w.schlaf.map { String(localized: "\($0), \(Int(w.anteil * 100)) Prozent des Ziels") } ?? String(localized: "keine Werte von heute"))
    }
}
