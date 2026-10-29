import SwiftUI

/// Texte der Freunde-Seite, rein und ohne Oberfläche.
enum FreundeText {
    /// "26. Oktober" für den Montag einer Woche.
    static func woche(_ tag: String) -> String {
        let stil = Date.FormatStyle(locale: Locale(identifier: "de_DE"), calendar: Datum.kalender, timeZone: Datum.kalender.timeZone)
        return Datum.datum(tag).formatted(stil.day().month(.wide))
    }

    /// "61.400 Schritte, 4 Gym-Tage, Schlaf 7 h 20 min": für VoiceOver und Teilen.
    static func zusammenfassung(_ karte: FreundKarte) -> String {
        var teile = ["\(karte.schritte.formatted()) Schritte", karte.gymTage == 1 ? "1 Gym-Tag" : "\(karte.gymTage) Gym-Tage"]
        if let schlaf = karte.schlafSchnittMinuten { teile.append("Schlaf im Schnitt \(PartnerAnzeige.schlafText(schlaf))") }
        return teile.joined(separator: ", ")
    }

    /// Was beim Lesen einer Karte schiefging und was jetzt hilft.
    static func fehler(_ fehler: FreundeKarteCodec.Fehler) -> (titel: String, hilfe: String) {
        switch fehler {
        case .leer: ("Nichts zu lesen", "Kopiere den ganzen Link der Karte und versuche es noch einmal.")
        case .format: ("Das ist keine Lumen-Fit-Karte", "Bitte deinen Freund, die Karte noch einmal zu schicken.")
        case .pruefsumme: ("Die Karte ist beschädigt", "Der Link ist abgeschnitten oder verändert. Bitte deinen Freund, ihn noch einmal zu schicken.")
        case .version: ("Die Karte ist von einer neueren Version", "Aktualisiere Lumen Fit und öffne die Karte noch einmal.")
        case .werte: ("Die Werte auf der Karte sind nicht möglich", "Bitte deinen Freund, die Karte neu zu erstellen.")
        }
    }
}

/// Die eigene Wochenkarte als Bild (Idee 89): Name, Woche, Schritte, Gym-Tage, Schlaf und der QR-Code. Das Bild entsteht mit `ImageRenderer`,
/// darum bekommt es Palette und Größe ausdrücklich (der Renderer erbt keine Umgebung) und eine feste Schriftgröße.
struct FreundeKartenBild: View {
    let karte: FreundKarte
    let qr: UIImage?
    let palette: Palette

    static let breite: CGFloat = 360

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.l) {
            Text("Lumen Fit").font(.footnote.weight(.semibold))
            VStack(alignment: .leading, spacing: Abstand.xs) {
                Text(karte.name).font(.largeTitle.bold())
                Text("Woche ab \(FreundeText.woche(karte.woche))").font(.subheadline)
            }
            HStack(alignment: .top, spacing: Abstand.xl) {
                wert(karte.schritte.formatted(), "Schritte")
                wert("\(karte.gymTage)", "Gym-Tage")
                if let schlaf = karte.schlafSchnittMinuten { wert(PartnerAnzeige.schlafText(schlaf), "Schlaf Ø") }
            }
            if let qr {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .padding(Abstand.m)
                    .background(.white, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
                    .frame(maxWidth: .infinity)
            }
            Text("Scanne den QR-Code mit der Kamera, dann öffnet sich Lumen Fit.").font(.footnote)
        }
        .foregroundStyle(palette.aufAkzent)
        .padding(Abstand.xl)
        .frame(width: Self.breite, alignment: .leading)
        .background(palette.akzent)
        .environment(\.dynamicTypeSize, .large)
    }

    private func wert(_ zahl: String, _ name: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(zahl).font(.title2.weight(.semibold)).monospacedDigit()
            Text(name).font(.caption)
        }
    }
}
