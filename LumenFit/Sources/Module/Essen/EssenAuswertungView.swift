// Quelle: Lovea Health/Ernaehrung/ErnaehrungAnalyse.swift:140-484 (ErnaehrungAnalyseView)
import SwiftUI

/// Auswertung wie in einer großen Ernährungs-App: Zeitraum von einer Woche bis zu zwei Jahren (bei langen Zeiträumen je Woche oder Monat gemittelt),
/// dann Kalorien, Makros, Nährstoffe (Mikros in Prozent der EU-Referenz), Gewicht, Körperwerte, Serie und die kalorienreichsten Lebensmittel.
/// Gezeichnet wird nur ohne `bewegungAus`; jedes Diagramm hat eine VoiceOver-Beschreibung.
struct EssenAuswertungView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus
    @State private var zeitraum: AnalyseZeitraum = .woche
    @State private var gezeichnet = false

    init() {}

    var body: some View {
        ScrollView {
            if let essen = umgebung.daten?.essen {
                inhalt(essen)
                    .padding(Abstand.l)
            }
        }
        .navigationTitle("Auswertung")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .haptik(.auswahl, bei: zeitraum)
        .onAppear {
            if bewegungAus { gezeichnet = true } else { withAnimation(Feder.weich) { gezeichnet = true } }
        }
    }

    // MARK: - Aufbau

    private func inhalt(_ essen: EssenStore) -> some View {
        let heute = Datum.text(umgebung.uhr())
        let tage = AnalyseLogik.tage(bis: heute, anzahl: zeitraum.rawValue)
        let buckets = AnalyseLogik.buckets(tage, gruppierung: zeitraum.gruppierung)
        // Alle Einträge einmal geholt statt in jeder Teilauswertung neu.
        let eintraege = tage.flatMap { essen.eintraege($0) }
        let summen = EssenAuswertungLogik.tagesSummen(eintraege)
        let ziele = essen.ernaehrungsZiele
        let wachstum = gezeichnet || bewegungAus ? 1.0 : 0.0
        return VStack(alignment: .leading, spacing: Abstand.l) {
            zeitraumWahl
            if eintraege.isEmpty && !hatMesswerte(essen, tage) {
                LeerZustand(stimmung: .bereit, satz: "In diesem Zeitraum ist noch nichts eingetragen. Sobald du isst oder dich wiegst, rechne ich es dir vor.")
            }
            if !eintraege.isEmpty {
                kalorienKarte(buckets: buckets, summen: summen, ziele: ziele, wachstum: wachstum)
                makroKarte(summen: summen, ziele: ziele)
                naehrstoffeKarte(summen: summen)
            }
            gewichtKarte(essen, tage: tage, wachstum: wachstum)
            koerperKarten(essen, tage: tage, wachstum: wachstum)
            serieUndTopKarte(essen, eintraege: eintraege, heute: heute)
        }
    }

    private func hatMesswerte(_ essen: EssenStore, _ tage: [String]) -> Bool {
        guard let von = tage.first, let bis = tage.last else { return false }
        return !EssenAuswertungLogik.gewichtReihe(essen.gewichtQuelle(), von: von, bis: bis).isEmpty
    }

    private func karte<Inhalt: View>(@ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: Abstand.m) { inhalt() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Abstand.l)
            .lumenKartenFlaeche()
    }

    // MARK: - Zeitraum

    private var zeitraumWahl: some View {
        karte {
            Menu {
                Picker("Zeitraum", selection: $zeitraum) {
                    ForEach(AnalyseZeitraum.allCases) { z in Text(z.name).tag(z) }
                }
            } label: {
                HStack {
                    Text("Zeitraum").font(.headline).foregroundStyle(palette.text)
                    Spacer(minLength: Abstand.s)
                    Label(zeitraum.name, systemImage: "chevron.up.chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.text2)
                }
                .contentShape(.rect)
                .frame(minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zeitraum wählen, jetzt \(zeitraum.name)")
        }
    }

    // MARK: - Kalorien

    private func kalorienKarte(buckets: [AnalyseBucket], summen: [String: Naehrwerte], ziele: ErnaehrungsZiele, wachstum: Double) -> some View {
        let werte = summen.mapValues(\.kcal)
        let schnitt = AnalyseLogik.schnitt(werte)
        let imZiel = AnalyseLogik.tageImZiel(Array(werte.values), ziel: Double(ziele.kcal))
        let gruppierung = zeitraum.gruppierung
        let beschreibung = EssenReiheBeschreibung(
            titel: "Kalorien im Zeitraum \(zeitraum.name)",
            zusammenfassung: "Durchschnitt \(Int(schnitt.rounded())) Kilokalorien, Ziel \(ziele.kcal)",
            xTitel: "Zeit", yTitel: "Kilokalorien", einheit: "kcal",
            kategorien: buckets.map { AnalyseLogik.label($0, gruppierung) },
            werte: buckets.map { AnalyseLogik.bucketSchnitt($0, werte) },
            ziel: Double(ziele.kcal))
        return DiagrammKarte(aussage: "Kalorien", kernzeile: EssenAuswertungLogik.kalorienKernzeile(schnitt: schnitt, imZiel: imZiel, tageMitEintraegen: werte.count)) {
            EssenKalorienDiagramm(buckets: buckets, gruppierung: gruppierung, werte: werte, ziel: ziele.kcal, wachstum: wachstum, beschreibung: beschreibung)
            HStack {
                EssenKennzahlSpalte(wert: "\(Int(schnitt.rounded())) kcal", titel: "Schnitt")
                Spacer()
                EssenKennzahlSpalte(wert: "\(imZiel) von \(werte.count)", titel: "Tage im Ziel")
            }
        }
    }

    // MARK: - Makros

    private func makroKarte(summen: [String: Naehrwerte], ziele: ErnaehrungsZiele) -> some View {
        let schnitte = EssenAuswertungLogik.makroSchnitte(summen, ziele: ziele)
        let hatEnergie = schnitte.contains { $0.energie > 0 }
        let beschreibung = EssenReiheBeschreibung(
            titel: "Makros im Schnitt",
            zusammenfassung: schnitte.map { "\($0.name) \(Int((EssenAuswertungLogik.energieAnteil($0, in: schnitte) * 100).rounded())) Prozent der Energie" }.joined(separator: ", "),
            xTitel: "Makro", yTitel: "Anteil an der Energie", einheit: "Prozent",
            kategorien: schnitte.map(\.name),
            werte: schnitte.map { EssenAuswertungLogik.energieAnteil($0, in: schnitte) * 100 })
        return DiagrammKarte(aussage: "Makros im Schnitt", kernzeile: "Anteil an der Energie und Gramm je Tag gegen dein Ziel") {
            HStack(alignment: .center, spacing: Abstand.l) {
                if hatEnergie { EssenMakroSektor(schnitte: schnitte, sichtbar: gezeichnet || bewegungAus, beschreibung: beschreibung) }
                VStack(alignment: .leading, spacing: Abstand.m) {
                    ForEach(schnitte) { m in makroZeile(m, anteil: EssenAuswertungLogik.energieAnteil(m, in: schnitte)) }
                }
            }
        }
    }

    private func makroZeile(_ m: EssenMakroSchnitt, anteil: Double) -> some View {
        HStack {
            Circle().fill(palette.text.opacity(m.deckkraft)).frame(width: 10, height: 10).accessibilityHidden(true)
            Text(m.name).font(.subheadline).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.s)
            Text("\(Int(m.gramm.rounded())) / \(m.ziel) g").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
            Text("\(Int((anteil * 100).rounded())) %").font(.footnote).monospacedDigit().foregroundStyle(palette.text2)
                .frame(width: 42, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(m.name): \(Int(m.gramm.rounded())) von \(m.ziel) Gramm, \(Int((anteil * 100).rounded())) Prozent der Energie")
    }

    // MARK: - Nährstoffe

    private func naehrstoffeKarte(summen: [String: Naehrwerte]) -> some View {
        let grund = EssenAuswertungLogik.grundZeilen(summen)
        let vitamine = EssenAuswertungLogik.mikroZeilen(summen, gruppe: .vitamine)
        let mineralstoffe = EssenAuswertungLogik.mikroZeilen(summen, gruppe: .mineralstoffe)
        return karte {
            Text("Nährstoffe im Schnitt").font(.headline).foregroundStyle(palette.text)
            if grund.isEmpty && vitamine.isEmpty && mineralstoffe.isEmpty {
                Text("Noch keine Nährwertangaben in diesem Zeitraum.").font(.subheadline).foregroundStyle(palette.text2)
            } else {
                VStack(alignment: .leading, spacing: Abstand.s) { ForEach(grund) { naehrstoffZeile($0) } }
                if !vitamine.isEmpty { abschnitt("Vitamine", vitamine) }
                if !mineralstoffe.isEmpty { abschnitt("Mineralstoffe", mineralstoffe) }
                Text("Nur Lebensmittel mit Angaben dazu zählen in den Schnitt.").font(.footnote).foregroundStyle(palette.text2)
            }
        }
    }

    private func abschnitt(_ titel: String, _ zeilen: [NaehrstoffZeile]) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text(titel).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text).padding(.top, Abstand.xs)
            ForEach(zeilen) { naehrstoffZeile($0) }
        }
    }

    private func naehrstoffZeile(_ zeile: NaehrstoffZeile) -> some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            HStack {
                Text(zeile.name).font(.subheadline).foregroundStyle(palette.text)
                Spacer(minLength: Abstand.s)
                Text(zeile.menge).font(.subheadline).monospacedDigit().foregroundStyle(palette.text2)
                if let prozent = zeile.prozent {
                    Text("\(Int(prozent.rounded())) %").font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(palette.text)
                        .frame(width: 52, alignment: .trailing)
                }
            }
            if let prozent = zeile.prozent { EssenBalken(anteil: prozent / 100, hoehe: 4) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(zeile.prozent.map { "\(zeile.name): \(zeile.menge), \(Int($0.rounded())) Prozent der Referenz" } ?? "\(zeile.name): \(zeile.menge)")
    }

    // MARK: - Gewicht und Körperwerte

    @ViewBuilder
    private func gewichtKarte(_ essen: EssenStore, tage: [String], wachstum: Double) -> some View {
        if let von = tage.first, let bis = tage.last {
            let reihe = EssenAuswertungLogik.gewichtReihe(essen.gewichtQuelle(), von: von, bis: bis)
            if let erstes = reihe.first, let letztes = reihe.last {
                let diff = EssenAuswertungLogik.gewichtVeraenderungZehntel(reihe)
                let beschreibung = EssenReiheBeschreibung(
                    titel: "Gewicht", zusammenfassung: EssenAuswertungLogik.gewichtKernzeile(reihe),
                    xTitel: "Tag", yTitel: "Kilogramm", einheit: "kg",
                    kategorien: reihe.map { Self.tagKurz($0.tag) }, werte: reihe.map { $0.wert },
                    von: max(0, (reihe.map(\.wert).min() ?? 0).rounded(.down) - 1))
                DiagrammKarte(aussage: "Gewicht", kernzeile: EssenAuswertungLogik.gewichtKernzeile(reihe)) {
                    EssenMessLinie(reihe: reihe, einheit: "kg", hoehe: 140, achsenWerte: 5, wachstum: wachstum, beschreibung: beschreibung)
                    HStack {
                        EssenKennzahlSpalte(wert: "\(ErnaehrungLogik.zahl(erstes.wert)) kg", titel: "Start")
                        Spacer()
                        EssenKennzahlSpalte(wert: "\(ErnaehrungLogik.zahl(letztes.wert)) kg", titel: "Aktuell")
                        Spacer()
                        EssenKennzahlSpalte(wert: "\(diff > 0 ? "+" : "")\(ErnaehrungLogik.zahl(Double(diff) / 10)) kg", titel: "Veränderung")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func koerperKarten(_ essen: EssenStore, tage: [String], wachstum: Double) -> some View {
        ForEach(KoerperArt.allCases) { art in
            let reihe = EssenAuswertungLogik.koerperReihe(tage: tage) { essen.koerperwert(art, bis: $0) }
            if let letztes = reihe.last {
                let kern = "Zuletzt \(ErnaehrungLogik.zahl(letztes.wert)) \(art.einheit)"
                let beschreibung = EssenReiheBeschreibung(
                    titel: art.name, zusammenfassung: kern, xTitel: "Tag", yTitel: art.einheit == "%" ? "Prozent" : "Zentimeter",
                    einheit: art.einheit, kategorien: reihe.map { Self.tagKurz($0.tag) }, werte: reihe.map { $0.wert },
                    von: max(0, (reihe.map(\.wert).min() ?? 0).rounded(.down) - 1))
                DiagrammKarte(aussage: art.name, kernzeile: kern) {
                    EssenMessLinie(reihe: reihe, einheit: art.einheit, hoehe: 100, achsenWerte: 4, wachstum: wachstum, beschreibung: beschreibung)
                }
            }
        }
    }

    /// "23.09." für Beschreibungen.
    private static func tagKurz(_ tag: String) -> String {
        let teile = tag.split(separator: "-")
        return teile.count == 3 ? "\(teile[2]).\(teile[1])." : tag
    }

    // MARK: - Serie und Top-Lebensmittel

    private func serieUndTopKarte(_ essen: EssenStore, eintraege: [EssenEintrag], heute: String) -> some View {
        let top = EssenAuswertungLogik.top(eintraege)
        let serie = AnalyseLogik.serie(essen.tage, heute: heute)
        let hoechste = top.first?.kcal ?? 1
        return karte {
            HStack {
                Text("Meiste Kalorien").font(.headline).foregroundStyle(palette.text)
                Spacer(minLength: Abstand.s)
                Label("\(serie) \(serie == 1 ? "Tag" : "Tage") in Folge", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .contentTransition(.numericText(value: Double(serie)))
            }
            if top.isEmpty {
                Text("Noch nichts eingetragen").font(.subheadline).foregroundStyle(palette.text2)
            } else {
                VStack(spacing: Abstand.s) {
                    ForEach(top) { zeile in
                        VStack(alignment: .leading, spacing: Abstand.xs) {
                            HStack {
                                Text(zeile.name).font(.subheadline).foregroundStyle(palette.text).lineLimit(2)
                                Spacer(minLength: Abstand.s)
                                Text("\(Int(zeile.kcal.rounded())) kcal").font(.subheadline).monospacedDigit().foregroundStyle(palette.text2)
                            }
                            EssenBalken(anteil: zeile.kcal / max(hoechste, 1), hoehe: 4)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(zeile.name), \(Int(zeile.kcal.rounded())) Kilokalorien")
                    }
                }
            }
        }
    }
}
