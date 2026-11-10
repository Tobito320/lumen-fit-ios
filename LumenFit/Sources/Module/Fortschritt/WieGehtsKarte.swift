import SwiftUI

/// "Wie geht's dir": diese Woche gegen den Schnitt der vier Wochen davor (Einheiten, Volumen, Sätze), ein Satz zu den Hauptübungen
/// und das letzte Training als Tipp-Zeile, damit es sofort zu finden ist. Pfeile sind neutral gefärbt: eine laufende Woche liegt oft noch unter dem Schnitt.
struct WieGehtsKarte: View {
    let vergleich: TrainingsWochenVergleich
    let satz: String?
    let letzte: EinheitDaten?
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Diese Woche").font(.headline).foregroundStyle(palette.text)
                Text("gegen Schnitt der 4 Wochen davor").font(.footnote).foregroundStyle(palette.text2)
            }
            HStack(spacing: Abstand.s) {
                kachel("Einheiten", wert: FortschrittLogik.zahl(Double(vergleich.einheiten)), ist: Double(vergleich.einheiten),
                       schnitt: vergleich.einheitenSchnitt, schnittText: FortschrittLogik.zahl(vergleich.einheitenSchnitt))
                kachel("Volumen", wert: FortschrittLogik.volumenText(vergleich.volumen), ist: vergleich.volumen,
                       schnitt: vergleich.volumenSchnitt, schnittText: FortschrittLogik.volumenText(vergleich.volumenSchnitt))
                kachel("Sets", wert: FortschrittLogik.zahl(Double(vergleich.saetze)), ist: Double(vergleich.saetze),
                       schnitt: vergleich.saetzeSchnitt, schnittText: FortschrittLogik.zahl(vergleich.saetzeSchnitt))
            }
            if let satz {
                HStack(alignment: .top, spacing: Abstand.m) {
                    Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(palette.akzent).frame(width: 24).accessibilityHidden(true)
                    Text(satz).font(.subheadline).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let letzte { letztes(letzte) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .lumenKartenFlaeche()
    }

    private func kachel(_ titel: String, wert: String, ist: Double, schnitt: Double, schnittText: String) -> some View {
        let richtung = Self.richtung(ist: ist, schnitt: schnitt)
        return VStack(alignment: .leading, spacing: Abstand.xs) {
            Text(titel).font(.footnote).foregroundStyle(palette.text2)
            HStack(spacing: Abstand.xs) {
                Text(wert).font(.title2.weight(.bold)).fontDesign(.rounded).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                if let richtung { Image(systemName: richtung.symbol).font(.footnote.weight(.bold)).foregroundStyle(palette.text2).accessibilityHidden(true) }
            }
            Text("Ø \(schnittText)").font(.footnote).foregroundStyle(palette.text2).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(Abstand.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.haar, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titel) \(wert)\(richtung.map { ", " + $0.text } ?? ""), Schnitt \(schnittText)")
    }

    /// Pfeil und Wort gegen den Schnitt; nil ohne Schnitt (noch keine Woche davor).
    static func richtung(ist: Double, schnitt: Double) -> (symbol: String, text: String)? {
        guard schnitt > 0 else { return nil }
        if ist > schnitt { return ("arrow.up", "über dem Schnitt") }
        if ist < schnitt { return ("arrow.down", "unter dem Schnitt") }
        return ("minus", "wie der Schnitt")
    }

    private func letztes(_ e: EinheitDaten) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Haarlinie()
            NavigationLink {
                EinheitNachlesenView(sessionId: e.id)
            } label: {
                HStack(spacing: Abstand.m) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Letztes Training").font(.footnote).foregroundStyle(palette.text2)
                        Text("\(e.titel), \(FortschrittLogik.kurzDatum(e.start))").font(.headline).foregroundStyle(palette.text)
                    }
                    Spacer(minLength: Abstand.s)
                    if let dauer = e.dauer { Text(TrainingLogik.dauerText(dauer)).font(.subheadline).foregroundStyle(palette.text2).monospacedDigit() }
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                }
                .frame(minHeight: Abstand.tippflaeche)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Öffnet die Einheit")
        }
    }
}
