import SwiftUI
import WidgetKit

/// Idee 93: Sperrbildschirm. Rund: Schritte als Bogen. Rechteckig: Schlaf und Erholung. Zeile: die Gym-Serie. Das System färbt Sperrbildschirm-Widgets selbst:
/// keine eigenen Datenfarben, nur Text und Symbole (`widgetAccentable` für das Hervorgehobene).
struct SperrbildschirmWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.onlyus.lumen-fit.sperrbildschirm", provider: SnapshotAnbieter()) { eintrag in
            SperrbildschirmAnsicht(eintrag: eintrag)
        }
        .configurationDisplayName("Sperrbildschirm")
        .description("Schritte, Schlaf und Gym-Serie auf dem Sperrbildschirm.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct SperrbildschirmAnsicht: View {
    let eintrag: SnapshotEintrag
    @Environment(\.widgetFamily) private var familie

    private var boegen: WidgetBoegenWerte? { WidgetAnzeige.istVonHeute(eintrag.snapshot, jetzt: eintrag.date) ? eintrag.snapshot?.boegen : nil }

    var body: some View {
        Group {
            switch familie {
            case .accessoryInline:
                zeile
            case .accessoryRectangular:
                rechteck
            default:
                rund
            }
        }
        .widgetURL(RouteURL.url(fuer: familie == .accessoryInline ? .gym(.training) : .heute))
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }

    // MARK: Rund: Schritte

    private var rund: some View {
        let schritte = boegen?.schritte
        return Gauge(value: WidgetAnzeige.anteil(schritte, boegen?.schritteZiel)) {
            Image(systemName: "figure.walk")
        } currentValueLabel: {
            Text(schritte.map(LockscreenLogik.kurzZahl) ?? "–")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .accessibilityLabel("Schritte")
        .accessibilityValue(schritte.map { String(localized: "\(WidgetAnzeige.zahlText($0)) von \(WidgetAnzeige.zahlText(boegen?.schritteZiel ?? 0))") } ?? String(localized: "keine Werte von heute"))
    }

    // MARK: Rechteckig: Schlaf und Erholung

    private var rechteck: some View {
        let z = WidgetAnzeige.schlafZeile(eintrag.snapshot, jetzt: eintrag.date)
        return VStack(alignment: .leading, spacing: 2) {
            Label("Schlaf", systemImage: "moon.zzz.fill")
                .font(.caption.weight(.semibold))
                .widgetAccentable()
            Text(z.schlaf ?? String(localized: "Keine Daten")).font(.headline).lineLimit(1)
            Gauge(value: z.anteil) { EmptyView() }
                .gaugeStyle(.accessoryLinearCapacity)
            if let erholung = z.erholung {
                Text("Erholung: \(erholung)").font(.caption).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([String(localized: "Schlaf"), z.schlaf, z.erholung.map { String(localized: "Erholung \($0)") }].compactMap { $0 }.joined(separator: ", "))
    }

    // MARK: Zeile: Gym-Serie

    private var zeile: some View {
        Label(WidgetAnzeige.serieText(eintrag.snapshot?.serieWochen), systemImage: "flame.fill")
    }
}
