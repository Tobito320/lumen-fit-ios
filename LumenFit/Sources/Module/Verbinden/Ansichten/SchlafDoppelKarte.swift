// Quelle: Lovea Health/SchlafCard.swift (Karte "Ihr beide")
import SwiftUI

/// "Ihr beide": der Schlaf von dir und deinem Partner, letzte Nacht in zwei Spalten und darunter die Woche als Doppelbalken (Mo bis So).
/// Eine eigene View für den Schlaf-Tab: ohne verbundenen Partner, ohne Freigabe schlaf oder ohne Schlafwert der Woche erscheint nichts.
struct SchlafDoppelKarte: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus
    @State private var gezeigt = false

    private var heute: String { Datum.text(umgebung.uhr()) }

    private var meine: [String: Int] {
        guard let daten = umgebung.daten else { return [:] }
        var werte: [String: Int] = [:]
        for tag in HabitLogik.wochenTage(heute: heute) where tag <= heute {
            if let n = TagesformQuellen.nacht(tag, daten: daten, gesundheit: umgebung.gesundheit) { werte[tag] = n.minuten }
        }
        return werte
    }

    var body: some View {
        if let datei = PartnerAnzeige.aktuell(umgebung), let woche = PartnerVergleich.schlafWoche(heute: heute, mein: meine, datei: datei) {
            karte(datei.profilName, woche)
        }
    }

    private func karte(_ name: String, _ woche: [PartnerVergleich.SchlafTag]) -> some View {
        let letzte = woche.first { $0.istHeute }
        let hoechster = PartnerVergleich.schlafHoechster(woche)
        return ListenKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                Label("Ihr beide", systemImage: "moon.zzz.fill")
                    .font(.headline)
                    .foregroundStyle(palette.text)
                    .accessibilityAddTraits(.isHeader)
                HStack(alignment: .top, spacing: Abstand.l) {
                    person("Du", letzte?.mein, palette.text)
                    person(name, letzte?.sein, palette.text2)
                }
                HStack(alignment: .bottom, spacing: Abstand.s) {
                    ForEach(woche) { tag in spalte(tag, hoechster: hoechster) }
                }
                .accessibilityHidden(true)
            }
            .padding(Abstand.l)
        }
        .accessibilityElement(children: .contain)
        .onAppear { gezeigt = true }
    }

    private func person(_ name: String, _ minuten: Int?, _ farbe: Color) -> some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            Text(name).font(.caption.weight(.semibold)).foregroundStyle(palette.text2)
            Text(minuten.map(PartnerAnzeige.schlafText) ?? "–")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(farbe)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(minuten.map { "\(name): \(PartnerAnzeige.schlafText($0))" } ?? "\(name): nichts eingetragen")
    }

    private func spalte(_ tag: PartnerVergleich.SchlafTag, hoechster: Int) -> some View {
        VStack(spacing: Abstand.xs) {
            HStack(alignment: .bottom, spacing: 3) {
                balken(tag.mein, hoechster: hoechster, farbe: palette.text)
                balken(tag.sein, hoechster: hoechster, farbe: palette.text2)
            }
            .frame(height: 56, alignment: .bottom)
            Text(tag.kuerzel)
                .font(.caption2)
                .foregroundStyle(tag.istHeute ? palette.text : palette.text2)
        }
        .frame(maxWidth: .infinity)
    }

    /// Wächst beim Erscheinen von unten (Reduce Motion: steht sofort). Ohne Wert ein flacher, blasser Strich.
    private func balken(_ minuten: Int?, hoechster: Int, farbe: Color) -> some View {
        let anteil = PartnerVergleich.schlafAnteil(minuten, hoechster: hoechster)
        let hoehe = anteil.map { max(3, CGFloat($0) * 56) } ?? 3
        return Capsule()
            .fill(minuten != nil ? farbe : farbe.opacity(0.15))
            .frame(width: 7, height: bewegungAus || gezeigt ? hoehe : 3)
            .animation(bewegungAus ? nil : Feder.weich, value: gezeigt)
    }
}
