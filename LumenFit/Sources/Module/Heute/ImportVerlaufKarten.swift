// Quelle: Lovea Home/WieGehtsDirCard.swift (drei Stufen, Symbole, Texte) und Kalender/KalenderModell.swift (stimmung.setzen)
import Charts
import SwiftUI

/// Drei Knöpfe für die Stimmung eines Tages. Schreibt dieselbe Teil-Op wie Lovea (`stimmung.setzen` mit `teil`), "Brauche" und Satz bleiben.
struct StimmungWahl: View {
    let tag: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus
    @State private var ausgeloest = 0

    var body: some View {
        let aktuell = umgebung.daten?.importVerlauf.stimmung(tag)?.stufe
        HStack(spacing: Abstand.s) {
            ForEach(StimmungStufe.allCases, id: \.self) { stufe in
                knopf(stufe, aktiv: stufe == aktuell)
            }
        }
        .haptik(.auswahl, bei: ausgeloest)
    }

    private func knopf(_ stufe: StimmungStufe, aktiv: Bool) -> some View {
        Button {
            withAnimation(bewegungAus ? nil : Feder.schnell) {
                umgebung.daten?.importVerlauf.setzeStimmung(stufe, tag: tag)
            }
            ausgeloest += 1
        } label: {
            VStack(spacing: Abstand.xs) {
                Image(systemName: stufe.symbolName).font(.title3).accessibilityHidden(true)
                Text(stufe.name).font(.caption.weight(.semibold))
            }
            .foregroundStyle(aktiv ? palette.aufAkzent : palette.text)
            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            .padding(.vertical, Abstand.s)
            .background(aktiv ? palette.akzent : palette.grund, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
            .scaleEffect(aktiv && !bewegungAus ? 1.04 : 1)
            .contentShape(.rect)
        }
        .buttonStyle(.federnd)
        .animation(bewegungAus ? nil : Feder.schnell, value: aktiv)
        .accessibilityLabel(stufe.name)
        .accessibilityHint("Stimmung für \(Datum.anzeige(tag)) festhalten")
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }
}

/// Stimmung eines Tages im Tag-Blatt der Woche (`HeuteTagView`). Für Tage in der Zukunft gibt es nichts einzutragen.
struct StimmungTagKarte: View {
    let tag: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        if tag <= Datum.text(umgebung.uhr()) {
            VStack(alignment: .leading, spacing: Abstand.m) {
                Text("Stimmung").font(.headline).foregroundStyle(palette.text)
                if let satz = umgebung.daten?.importVerlauf.stimmung(tag)?.satz, !satz.isEmpty {
                    Text(satz).font(.subheadline).foregroundStyle(palette.text2)
                }
                StimmungWahl(tag: tag)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Abstand.l)
            .lumenKartenFlaeche()
        }
    }
}

/// Stimmungsverlauf der letzten 14 Tage (Fortschritt, Verlauf) mit dem Eintragen für heute. Importierte Einträge aus Lovea erscheinen hier.
struct StimmungVerlaufKarte: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        let heute = Datum.text(umgebung.uhr())
        let reihe = ImportVerlaufLogik.stimmungReihe(umgebung.daten?.importVerlauf.stand ?? ImportVerlaufStand(), heute: heute)
        let aussage = ImportVerlaufLogik.stimmungAussage(reihe)
        VStack(alignment: .leading, spacing: Abstand.m) {
            Text("Stimmung").font(.headline).foregroundStyle(palette.text)
            Text(aussage).font(.subheadline).foregroundStyle(palette.text2)
            if !reihe.isEmpty { diagramm(reihe, aussage: aussage) }
            Text("Wie ist heute?").font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
            StimmungWahl(tag: heute)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .lumenKartenFlaeche()
    }

    private func diagramm(_ reihe: [ImportVerlaufLogik.StimmungPunkt], aussage: String) -> some View {
        Chart(reihe, id: \.tag) { p in
            PointMark(x: .value("Tag", Datum.datum(p.tag), unit: .day), y: .value("Stimmung", p.stufe.wert))
                .foregroundStyle(palette.akzent)
                .symbolSize(70)
        }
        .chartYScale(domain: 0.5...3.5)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(palette.haar)
                AxisValueLabel(format: .dateTime.day().month(.abbreviated)).foregroundStyle(palette.text2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [1, 2, 3]) { wert in
                AxisGridLine().foregroundStyle(palette.haar)
                AxisValueLabel {
                    if let w = wert.as(Int.self), let stufe = StimmungStufe.allCases.first(where: { $0.wert == w }) {
                        Image(systemName: stufe.symbolName).foregroundStyle(palette.text2)
                    }
                }
            }
        }
        .frame(height: 120)
        .accessibilityChartDescriptor(FortschrittDeskriptor(
            titel: "Stimmungsverlauf", zusammenfassung: aussage, xTitel: "Tag", yTitel: "Stimmung", einheit: "von 3",
            stetig: false, punkte: reihe.map { .init(x: KoerperLogik.tagMonat($0.tag), y: Double($0.stufe.wert)) }))
    }
}
