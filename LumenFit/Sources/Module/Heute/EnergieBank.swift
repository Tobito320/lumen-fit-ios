import Charts
import SwiftUI

/// Energie-Bank (Idee 15): ein Wert von 0 bis 100 für den Akku des Körpers aus Schlaf, Erholung und Belastung (die Rechnung `TagesformRechnung`),
/// mit dem Verlauf über den Tag. Ein Tipp öffnet die Gründe im Klartext.
struct EnergieBank: View {
    let energie: HeuteEnergie
    let oeffne: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: oeffne) {
            ListenKarte {
                VStack(alignment: .leading, spacing: Abstand.m) {
                    HeuteKartenKopf(symbol: "bolt.heart.fill", titel: "Energie-Bank", zusatz: energie.ergebnis.urteil)
                    zahl
                    balken
                    verlauf
                    Text(energie.ergebnis.satz.components(separatedBy: "\n").first ?? "")
                        .font(.subheadline).foregroundStyle(palette.text2).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Abstand.l)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Energie-Bank")
        .accessibilityValue(energie.ergebnis.akku.map { "\($0) von 100, \(energie.ergebnis.urteil). \(energie.ergebnis.satz.replacingOccurrences(of: "\n", with: ". "))" } ?? energie.ergebnis.urteil)
        .accessibilityHint("Zeigt die Gründe")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var zahl: some View {
        if let akku = energie.ergebnis.akku {
            HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                RollZahl(wert: Double(akku), format: HeuteFormat.ganz())
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.text)
                Text("von 100").font(.footnote).foregroundStyle(palette.text2)
            }
        } else {
            Text("–").font(.system(size: 44, weight: .bold, design: .rounded)).foregroundStyle(palette.text2)
        }
    }

    private var balken: some View {
        let anteil = Double(energie.ergebnis.akku ?? 0) / 100
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.haar)
                Capsule().fill(palette.text).frame(width: geo.size.width * min(max(anteil, 0), 1))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var verlauf: some View {
        if energie.verlauf.count >= 2 {
            Chart(energie.verlauf) { punkt in
                LineMark(x: .value("Uhrzeit", punkt.stunde), y: .value("Energie", punkt.akku)).interpolationMethod(.monotone)
                PointMark(x: .value("Uhrzeit", punkt.stunde), y: .value("Energie", punkt.akku)).symbolSize(24)
            }
            .foregroundStyle(palette.text)
            .chartYScale(domain: 0...100)
            .chartXScale(domain: 6...max(12, energie.verlauf.last?.stunde ?? 12))
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { wert in
                    AxisValueLabel { Text("\(wert.as(Int.self) ?? 0) Uhr").font(.caption2) }
                }
            }
            .frame(height: 64)
            .accessibilityChartDescriptor(HeuteDiagrammBeschreibung(
                titel: "Energie über den Tag", zusammenfassung: "Zuletzt \(energie.verlauf.last?.akku ?? 0) von 100", xTitel: "Uhrzeit", yTitel: "Energie", einheit: "von 100",
                punkte: energie.verlauf.map { HeuteDiagrammPunkt(name: "\($0.stunde) Uhr", wert: Double($0.akku)) }))
        }
    }
}

/// Die Gründe hinter der Zahl, die Empfehlung, alle Faktoren und das eigene Gefühl (Blatt).
struct EnergieDetail: View {
    let energie: HeuteEnergie
    let gefuehl: (Int) -> Void
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    kopf
                    if !energie.klartext.gruende.isEmpty { gruende }
                    if let empfehlung = energie.klartext.empfehlung {
                        VStack(alignment: .leading, spacing: Abstand.xs) {
                            Text("Heute").font(.headline)
                            Text(empfehlung).font(.body)
                        }
                    }
                    if let hinweis = energie.klartext.hinweis { Text(hinweis).font(.subheadline).foregroundStyle(palette.text2) }
                    gefuehlKarte
                    if !energie.ergebnis.faktoren.isEmpty { faktoren }
                    if !energie.ergebnis.fehlend.isEmpty { fehlend }
                }
                .foregroundStyle(palette.text)
                .padding(Abstand.l)
            }
            .navigationTitle("Energie-Bank")
            .navigationBarTitleDisplayMode(.inline)
            .lumenHintergrund()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
        }
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            Text(energie.ergebnis.akku.map { "\($0) von 100" } ?? "Noch keine Zahl")
                .font(.system(size: 40, weight: .bold, design: .rounded))
            Text(energie.ergebnis.urteil + " · Datenlage " + energie.ergebnis.datenlage).font(.subheadline).foregroundStyle(palette.text2)
        }
        .accessibilityElement(children: .combine)
    }

    private var gruende: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Warum").font(.headline)
            ForEach(Array(energie.klartext.gruende.enumerated()), id: \.offset) { _, zeile in
                HStack(alignment: .top, spacing: Abstand.s) {
                    Image(systemName: zeile.bremst ? "arrow.down" : "arrow.up").foregroundStyle(palette.text2).frame(width: 20).accessibilityHidden(true)
                    Text((zeile.bremst ? "Bremst: " : "Hilft: ") + zeile.text).font(.body)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var gefuehlKarte: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Wie fühlst du dich?").font(.headline)
            HStack(spacing: Abstand.s) {
                ForEach(1...5, id: \.self) { stufe in
                    let gewaehlt = energie.gefuehl == stufe
                    Button { gefuehl(stufe) } label: {
                        Text(TagesformGefuehl.name(stufe))
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                            .foregroundStyle(gewaehlt ? palette.aufAkzent : palette.text)
                            .background(gewaehlt ? palette.akzent : palette.flaeche, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(TagesformGefuehl.name(stufe))
                    .accessibilityAddTraits(gewaehlt ? .isSelected : [])
                }
            }
            if let v = energie.vergleich { Text(vergleichText(v)).font(.footnote).foregroundStyle(palette.text2) }
        }
    }

    private func vergleichText(_ v: TagesformVergleich) -> String {
        let n = Int(abs(v.schnitt).rounded())
        if abs(v.schnitt) <= TagesformGefuehl.passtBis { return "Die Rechnung passt zu deinem Gefühl (im Schnitt \(n) Punkte daneben, \(v.anzahl) Tage)." }
        return "Die Rechnung liegt im Schnitt \(n) Punkte \(v.schnitt > 0 ? "über" : "unter") deinem Gefühl (\(v.anzahl) Tage)."
    }

    private var faktoren: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Alle Faktoren").font(.headline)
            ListenKarte {
                ForEach(Array(energie.ergebnis.faktoren.enumerated()), id: \.element.id) { index, f in
                    if index > 0 { Haarlinie() }
                    HStack(alignment: .top, spacing: Abstand.m) {
                        Image(systemName: f.art.symbol).foregroundStyle(palette.text2).frame(width: 24).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: Abstand.xs) {
                            Text(f.kurz).font(.subheadline.weight(.semibold))
                            if let d = f.detail { Text(d).font(.footnote).foregroundStyle(palette.text2) }
                        }
                        Spacer(minLength: Abstand.s)
                        Text("\(Int(f.wert.rounded()))").font(.subheadline.monospacedDigit()).foregroundStyle(palette.text2)
                    }
                    .padding(Abstand.l)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var fehlend: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Ohne Daten").font(.headline)
            ForEach(energie.ergebnis.fehlend, id: \.self) { art in
                Text("\(art.titel): \(art.braucht)").font(.footnote).foregroundStyle(palette.text2)
            }
        }
    }
}
