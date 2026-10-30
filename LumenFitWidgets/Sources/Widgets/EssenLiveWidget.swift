// Quelle: Lovea Health/LoveaWidgets/Sources/EssenLiveWidget.swift
import ActivityKit
import SwiftUI
import WidgetKit

/// Die Essen-Live-Activity: Sperrbildschirm mit Kalorienbogen gegen das Ziel, Protein-Balken, den vier Mahlzeiten (Ring gegen ihren Richtwert) und der nächsten
/// offenen Mahlzeit; Dynamic Island kompakt mit Lumi und Bogen, erweitert mit Zahlen, Protein und Mahlzeiten. Die App aktualisiert nur bei Ereignissen
/// (`EssenLiveDienst`), nichts hier tickt. Ein Tipp öffnet das Essen-Tagebuch.
struct EssenLiveWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EssenLiveAktivitaet.self) { kontext in
            EssenLiveSperrbildschirm(stand: kontext.state.stand, veraltet: kontext.isStale)
                .widgetURL(RouteURL.url(fuer: .essen(.heute)))
        } dynamicIsland: { kontext in
            let stand = kontext.state.stand
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LumiView(stimmung: .bereit, groesse: 28)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(EssenLiveLogik.restText(stand))
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 96, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("\(EssenLiveLogik.zahl(stand.kcal)) kcal").font(.headline.monospacedDigit()).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    EssenLiveInselUnten(stand: stand)
                }
            } compactLeading: {
                LumiView(stimmung: .bereit, groesse: 22)
            } compactTrailing: {
                EssenLiveMiniBogen(stand: stand)
            } minimal: {
                EssenLiveMiniBogen(stand: stand)
            }
            .widgetURL(RouteURL.url(fuer: .essen(.heute)))
        }
    }
}

/// Die Farben aus dem Theme der App (Snapshot der Gruppe); die Dynamic Island ist immer schwarz und nimmt deshalb die dunklen Töne.
private func essenLiveFarben(systemDunkel: Bool, kontrastHoch: Bool) -> WidgetFarben {
    let snapshot = WidgetSnapshotDatei.lade()
    return WidgetFarben.bau(thema: snapshot?.thema ?? .monochrom, erscheinung: snapshot?.erscheinung, systemDunkel: systemDunkel,
                            kontrastHoch: kontrastHoch, modus: .fullColor)
}

/// Bogen oder Ring mit Spur und runden Enden. `luecke` = 270 Grad mit Öffnung unten (Kalorien), sonst voller Ring (Mahlzeit).
private struct EssenLiveBogen: View {
    let anteil: Double
    let farbe: Color
    let spur: Color
    let strich: CGFloat
    var luecke = true

    var body: some View {
        let umfang = luecke ? 0.75 : 1.0
        ZStack {
            Circle().trim(from: 0, to: umfang).stroke(spur, style: StrokeStyle(lineWidth: strich, lineCap: .round))
            Circle().trim(from: 0, to: umfang * min(max(anteil, 0), 1)).stroke(farbe, style: StrokeStyle(lineWidth: strich, lineCap: .round))
        }
        .rotationEffect(.degrees(luecke ? 135 : -90))
        .padding(strich / 2)
        .accessibilityHidden(true)
    }
}

/// Der kleine Bogen in der kompakten und minimalen Insel (immer dunkel).
private struct EssenLiveMiniBogen: View {
    let stand: EssenLiveStand

    var body: some View {
        let farben = essenLiveFarben(systemDunkel: true, kontrastHoch: false)
        EssenLiveBogen(anteil: EssenLiveLogik.anteil(stand.kcal, stand.kcalZiel), farbe: farben.akzent, spur: farben.text2.opacity(0.3), strich: 3)
            .frame(width: 22, height: 22)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Essen heute: \(EssenLiveLogik.kcalText(stand))")
    }
}

/// Eine Mahlzeit: Symbol im Ring gegen den Richtwert, Name, kcal. Die nächste offene Mahlzeit steht fett.
private struct EssenLiveMahlzeitZelle: View {
    let mahlzeit: Mahlzeit
    let stand: EssenLiveStand
    let farben: WidgetFarben

    var body: some View {
        let kcal = EssenLiveLogik.mahlzeitKcal(stand, mahlzeit)
        let naechste = EssenLiveLogik.naechsteMahlzeit(stand) == mahlzeit
        VStack(spacing: 3) {
            ZStack {
                EssenLiveBogen(anteil: EssenLiveLogik.mahlzeitAnteil(stand, mahlzeit), farbe: farben.akzent, spur: farben.text2.opacity(0.25), strich: 3, luecke: false)
                Image(systemName: mahlzeit.symbol).font(.system(size: 15)).foregroundStyle(farben.text)
            }
            .frame(width: 40, height: 40)
            Text(mahlzeit.name).font(.caption2.weight(naechste ? .bold : .regular)).foregroundStyle(naechste ? farben.text : farben.text2).lineLimit(1).minimumScaleFactor(0.8)
            Text("\(kcal) kcal").font(.caption2.monospacedDigit()).foregroundStyle(farben.text2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(mahlzeit.name), \(kcal) Kilokalorien" + (naechste ? ", als Nächstes" : ""))
    }
}

private struct EssenLiveMahlzeitenZeile: View {
    let stand: EssenLiveStand
    let farben: WidgetFarben

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Mahlzeit.allCases) { m in
                EssenLiveMahlzeitZelle(mahlzeit: m, stand: stand, farben: farben)
            }
        }
    }
}

/// Protein als Balken mit Zahl.
private struct EssenLiveProtein: View {
    let stand: EssenLiveStand
    let farben: WidgetFarben

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            WidgetBalken(anteil: EssenLiveLogik.anteil(stand.proteinG, stand.proteinZiel), farbe: farben.akzent, spur: farben.text2.opacity(0.25))
            Text(EssenLiveLogik.proteinText(stand)).font(.caption2).foregroundStyle(farben.text2).lineLimit(1)
        }
    }
}

/// Sperrbildschirm: Bogen mit Rest-Kalorien in der Mitte, daneben Kalorien, Rest und Protein; darunter die vier Mahlzeiten und die nächste offene.
private struct EssenLiveSperrbildschirm: View {
    let stand: EssenLiveStand
    let veraltet: Bool
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    var body: some View {
        let farben = essenLiveFarben(systemDunkel: schema == .dark, kontrastHoch: kontrast == .increased)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                EssenLiveBogen(anteil: EssenLiveLogik.anteil(stand.kcal, stand.kcalZiel), farbe: farben.akzent, spur: farben.text2.opacity(0.25), strich: 6)
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(EssenLiveLogik.kcalText(stand)).font(.headline.monospacedDigit()).foregroundStyle(farben.text).lineLimit(1).minimumScaleFactor(0.8)
                    Text(veraltet ? "Neuer Tag: öffne Lumen Fit" : EssenLiveLogik.restText(stand)).font(.caption).foregroundStyle(farben.text2).lineLimit(1)
                    EssenLiveProtein(stand: stand, farben: farben)
                }
            }
            EssenLiveMahlzeitenZeile(stand: stand, farben: farben)
            Text(EssenLiveLogik.naechsteText(stand)).font(.caption).foregroundStyle(farben.text2).lineLimit(1)
        }
        .padding(16)
        .activityBackgroundTint(farben.grund)
        .accessibilityElement(children: .contain)
    }
}

/// Dynamic Island erweitert, unten: Protein und die vier Mahlzeiten. Immer dunkel, weil die Insel schwarz ist.
private struct EssenLiveInselUnten: View {
    let stand: EssenLiveStand

    var body: some View {
        let farben = essenLiveFarben(systemDunkel: true, kontrastHoch: false)
        VStack(alignment: .leading, spacing: 8) {
            EssenLiveProtein(stand: stand, farben: farben)
            EssenLiveMahlzeitenZeile(stand: stand, farben: farben)
        }
    }
}
