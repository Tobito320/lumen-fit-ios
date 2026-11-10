// Quelle: Lovea Health/Ernaehrung/TagesNaehrwerte.swift
import Charts
import SwiftUI

/// Alle Nährwerte eines Tages: Kalorien, Makros, Ballaststoffe/Zucker/Salz/gesättigte Fettsäuren, dann Vitamine, Mineralstoffe und Weitere
/// mit Menge und % der EU-Referenz, dazu die Kalorien je Mahlzeit. Reine Summe aller Einträge des Tages, kein Ziel-Vergleich.
struct EssenTagesNaehrwerteView: View {
    let tag: String

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus

    init(tag: String) { self.tag = tag }

    private var eintraege: [EssenEintrag] { umgebung.daten?.essen.eintraege(tag) ?? [] }

    var body: some View {
        let summe = ErnaehrungLogik.summe(eintraege)
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                kalorienUndMakros(summe)
                grundKarte(summe)
                mikroKarte(String(localized: "Vitamine"), .vitamine, summe)
                mikroKarte(String(localized: "Mineralstoffe"), .mineralstoffe, summe)
                mikroKarte(String(localized: "Weitere"), .weitere, summe)
                mahlzeitKarte
            }
            .padding(Abstand.l)
        }
        .fontDesign(.rounded)
        .lumenHintergrund()
        .navigationTitle(Datum.anzeige(tag))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func karte<Inhalt: View>(@ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) { inhalt() }
            .padding(Abstand.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lumenKartenFlaeche()
    }

    // MARK: Kalorien und Makros

    private func kalorienUndMakros(_ summe: Naehrwerte) -> some View {
        karte {
            Text("Kalorien").font(.headline).foregroundStyle(palette.text)
            HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                RollZahl(wert: summe.kcal, format: .number.precision(.fractionLength(0)))
                    .font(.title.weight(.heavy)).foregroundStyle(palette.text)
                Text("kcal").font(.subheadline).foregroundStyle(palette.text2)
            }
            Haarlinie()
            makroZeile(String(localized: "Kohlenhydrate"), summe.kohlenhydrate)
            makroZeile(String(localized: "Eiweiß"), summe.protein)
            makroZeile(String(localized: "Fett"), summe.fett)
        }
    }

    private func makroZeile(_ name: String, _ gramm: Double) -> some View {
        HStack {
            Text(name).font(.subheadline).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.s)
            Text("\(Int(gramm.rounded())) g").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
        }
        .frame(minHeight: 28)
        .accessibilityElement(children: .combine)
    }

    // MARK: Grundnährstoffe und Mikros

    private func grundKarte(_ summe: Naehrwerte) -> some View {
        let zeilen = EssenMahlzeitenLogik.grundZeilen(summe)
        return karte {
            Text("Weitere Nährwerte").font(.headline).foregroundStyle(palette.text)
            if zeilen.isEmpty {
                Text("Keine Angaben für diesen Tag.").font(.subheadline).foregroundStyle(palette.text2)
            } else {
                ForEach(zeilen) { naehrstoffZeile($0) }
            }
        }
    }

    @ViewBuilder
    private func mikroKarte(_ titel: String, _ gruppe: Mikro.Gruppe, _ summe: Naehrwerte) -> some View {
        let zeilen = EssenMahlzeitenLogik.mikroZeilen(summe, gruppe)
        if !zeilen.isEmpty {
            karte {
                Text(titel).font(.headline).foregroundStyle(palette.text)
                ForEach(zeilen) { naehrstoffZeile($0) }
                let ohne = EssenMahlzeitenLogik.ohneVitamine(eintraege)
                if gruppe == .vitamine, ohne > 0 {
                    Text(ohne == 1 ? "1 Eintrag ohne Angaben zu Vitaminen." : "\(ohne) Einträge ohne Angaben zu Vitaminen.")
                        .font(.footnote).foregroundStyle(palette.text2)
                }
            }
        }
    }

    private func naehrstoffZeile(_ zeile: NaehrstoffZeile) -> some View {
        HStack {
            Text(zeile.name).font(.subheadline).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.s)
            Text(zeile.menge).font(.subheadline).monospacedDigit().foregroundStyle(palette.text2)
            if let prozent = zeile.prozent {
                Text("\(Int(prozent.rounded())) %").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
                    .frame(width: 46, alignment: .trailing)
            }
        }
        .frame(minHeight: 28)
        .accessibilityElement(children: .combine)
    }

    // MARK: Mahlzeiten

    private var mahlzeitKarte: some View {
        let werte = Mahlzeit.allCases.map { m in (name: m.name, kcal: ErnaehrungLogik.summe(eintraege.filter { $0.mahlzeit == m }).kcal) }
        let beschreibung = werte.map { String(localized: "\($0.name) \(String(Int($0.kcal.rounded()))) Kilokalorien") }.joined(separator: ", ")
        return karte {
            Text("Kalorien je Mahlzeit").font(.headline).foregroundStyle(palette.text)
            Chart {
                ForEach(werte, id: \.name) { w in
                    BarMark(x: .value("kcal", w.kcal), y: .value("Mahlzeit", w.name))
                        .foregroundStyle(palette.text.opacity(0.75))
                        .cornerRadius(4)
                }
            }
            .chartXAxis { AxisMarks(position: .bottom) }
            .animation(bewegungAus ? nil : Feder.weich, value: werte.map(\.kcal))
            .frame(height: 140)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Kalorien je Mahlzeit")
            .accessibilityValue(beschreibung)
        }
    }
}
