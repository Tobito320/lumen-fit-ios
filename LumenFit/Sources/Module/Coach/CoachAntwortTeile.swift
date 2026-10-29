import SwiftUI

// Bausteine des Coach-Chats im Lumen-Design (Apple monochrom, Lumi als Figur): Antworttext ohne Blase, Blase der Person, Tippanzeige, Chips,
// Daumen und Merken, Karte des Morgen-Checks. Jede Tippfläche hat mindestens 44 pt, jedes Symbol ein Label, Reduce Motion wird beachtet.

enum CoachAnzeige {
    nonisolated static let deutsch = Locale(identifier: "de_DE")

    /// "Mittwoch, 23. September".
    static func tag(_ datum: Date) -> String {
        datum.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: deutsch, timeZone: Datum.zone))
    }

    /// "09:41".
    static func uhrzeit(_ datum: Date) -> String {
        datum.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: deutsch, timeZone: Datum.zone))
    }

    /// Das Symbol eines Chips nach seiner Handlung.
    static func symbol(_ aktion: CoachAktion) -> String? {
        switch aktion {
        case .antworten: "text.bubble"
        case .gewohnheitAnlegen: "plus.circle"
        case .planMorgenLeicht: "figure.strengthtraining.traditional"
        case .oeffne: "arrow.up.right"
        case .nichts: nil
        }
    }

    /// Fett für Zahlen mit Einheit ("8.200 Schritte", "120 g"); mit Markdown im Text gilt dessen eigene Auszeichnung.
    static func markiert(_ roh: String) -> AttributedString {
        if roh.contains("*") || roh.contains("`") { return CoachText.inline(roh) }
        var text = AttributedString(roh)
        for bereich in CoachText.zahlBereiche(roh) {
            let von = text.index(text.startIndex, offsetByCharacters: bereich.lowerBound)
            let bis = text.index(text.startIndex, offsetByCharacters: bereich.upperBound)
            text[von..<bis].inlinePresentationIntent = .stronglyEmphasized
        }
        return text
    }
}

// MARK: - Antworttext

/// Die Antwort des Coachs: Absätze, Überschriften, Listen, Nummern und Tabellen ohne Blase. Marker fallen weg.
struct CoachAntwortText: View {
    let text: String
    @Environment(\.palette) private var palette

    var body: some View {
        let zeilen = CoachText.zeilen(CoachMarker.zerlegen(text).text)
        VStack(alignment: .leading, spacing: Abstand.s) {
            ForEach(Array(zeilen.enumerated()), id: \.offset) { _, zeile in
                ansicht(zeile)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func ansicht(_ zeile: CoachText.Zeile) -> some View {
        switch zeile.art {
        case .absatz:
            Text(CoachAnzeige.markiert(zeile.text)).font(.body).foregroundStyle(palette.text)
        case .ueberschrift:
            Text(CoachText.inline(zeile.text)).font(.headline).foregroundStyle(palette.text)
        case .punkt:
            HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
                Text("•").foregroundStyle(palette.text2).accessibilityHidden(true)
                Text(CoachAnzeige.markiert(zeile.text)).font(.body).foregroundStyle(palette.text)
            }
        case .nummer(let nummer):
            HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
                Text("\(nummer).").monospacedDigit().foregroundStyle(palette.text2)
                Text(CoachAnzeige.markiert(zeile.text)).font(.body).foregroundStyle(palette.text)
            }
        case .aufgabe:
            HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
                Image(systemName: "circle").foregroundStyle(palette.text2).accessibilityHidden(true)
                Text(CoachAnzeige.markiert(zeile.text)).font(.body).foregroundStyle(palette.text)
            }
        case .tabelle(let kopf, let daten):
            Grid(alignment: .leading, horizontalSpacing: Abstand.m, verticalSpacing: Abstand.xs) {
                GridRow {
                    ForEach(Array(kopf.enumerated()), id: \.offset) { _, zelle in
                        Text(zelle).font(.footnote.weight(.semibold)).foregroundStyle(palette.text)
                    }
                }
                ForEach(Array(daten.enumerated()), id: \.offset) { _, reihe in
                    GridRow {
                        ForEach(Array(reihe.enumerated()), id: \.offset) { _, zelle in
                            Text(zelle).font(.footnote).foregroundStyle(palette.text2)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Blase der Person

struct CoachNutzerBlase: View {
    let text: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(palette.aufAkzent)
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
            .background(palette.akzent, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.leading, Abstand.xxl)
            .textSelection(.enabled)
            .accessibilityLabel("Du: \(text)")
    }
}

// MARK: - Tippanzeige

/// "Coach denkt nach" mit Lumi. Steht höchstens 15 Sekunden (`CoachModell.frist`); nach 8 Sekunden ein Hinweis. Der Takt läuft nur, solange sie sichtbar ist.
struct CoachDenkAnzeige: View {
    let seit: Date
    @Environment(\.palette) private var palette

    var body: some View {
        TimelineView(.periodic(from: seit, by: 1)) { zeit in
            HStack(alignment: .center, spacing: Abstand.m) {
                LumiView(stimmung: .denkt, groesse: 34)
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    Text("Coach denkt nach").font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                    if let hinweis = CoachLokal.denkHinweis(sekunden: zeit.date.timeIntervalSince(seit)) {
                        Text(hinweis).font(.footnote).foregroundStyle(palette.text2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Fehlerzeile mit Lumi

/// Die ruhige Zeile, wenn der Coach gerade nicht antworten konnte: Lumi und der Text, nie ein rohes Fehlerwort.
struct CoachFehlerZeile: View {
    let text: String
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .center, spacing: Abstand.m) {
            LumiView(stimmung: .muede, groesse: 40)
            Text(text).font(.body).foregroundStyle(palette.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chips unter der Antwort

/// Die Chips einer Antwort. Ein benutzter Chip steht mit Haken und ist nicht mehr tippbar (die Handlung lief schon).
struct CoachChipLeiste: View {
    let nachricht: CoachNachricht
    let modell: CoachModell

    var body: some View {
        if !nachricht.chips.isEmpty {
            CoachChipFluss(zentriert: false) {
                ForEach(nachricht.chips) { chip in
                    let benutzt = modell.istBenutzt(chip, in: nachricht)
                    CoachVorschlagChip(frage: chip.text, symbol: benutzt ? "checkmark" : CoachAnzeige.symbol(chip.aktion)) {
                        modell.tippe(chip, in: nachricht)
                    }
                    .disabled(benutzt)
                    .opacity(benutzt ? 0.6 : 1)
                    .accessibilityHint(benutzt ? "Schon erledigt" : hinweis(chip.aktion))
                }
            }
        }
    }

    private func hinweis(_ aktion: CoachAktion) -> String {
        switch aktion {
        case .antworten: "Stellt diese Frage"
        case .gewohnheitAnlegen: "Legt eine Gewohnheit an"
        case .planMorgenLeicht: "Macht das Training von morgen leichter"
        case .oeffne: "Öffnet die Seite"
        case .nichts: ""
        }
    }
}

// MARK: - Daumen und Merken

struct CoachAktionsZeile: View {
    let nachricht: CoachNachricht
    let modell: CoachModell

    var body: some View {
        HStack(spacing: Abstand.xs) {
            knopf(symbol: nachricht.daumen == true ? "hand.thumbsup.fill" : "hand.thumbsup", label: "Antwort gefällt mir",
                  an: nachricht.daumen == true) { modell.setzeDaumen(true, an: nachricht) }
            knopf(symbol: nachricht.daumen == false ? "hand.thumbsdown.fill" : "hand.thumbsdown", label: "Antwort gefällt mir nicht",
                  an: nachricht.daumen == false) { modell.setzeDaumen(false, an: nachricht) }
            knopf(symbol: modell.istGemerkt(nachricht) ? "bookmark.fill" : "bookmark", label: "Antwort merken",
                  an: modell.istGemerkt(nachricht)) { modell.schalteMerkliste(nachricht) }
        }
    }

    private func knopf(symbol: String, label: String, an: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.body)
                .frame(minWidth: Abstand.tippflaeche, minHeight: Abstand.tippflaeche)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(an ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }
}

// MARK: - Morgen-Check

/// Die eine mutige Karte des Tabs: eine Frage, fünf Antworten, ein "Heute nicht". Erscheint nur beim Öffnen am Morgen.
struct CoachMorgenCheckKarte: View {
    let modell: CoachModell
    @Environment(\.palette) private var palette

    var body: some View {
        HeroKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                HStack(spacing: Abstand.m) {
                    LumiView(stimmung: .bereit, groesse: 40)
                    Text(CoachMorgenCheck.frage).font(.headline)
                }
                HStack(spacing: Abstand.s) {
                    ForEach(CoachMorgenCheck.stufen, id: \.wert) { stufe in
                        Button { modell.morgenCheckBeantworten(stufe.wert) } label: {
                            VStack(spacing: Abstand.xs) {
                                Image(systemName: stufe.symbol).font(.title3)
                                Text(stufe.name).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(palette.aufAkzent.opacity(0.16), in: .rect(cornerRadius: Rundung.klein, style: .continuous))
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(stufe.name), \(stufe.wert) von 5")
                    }
                }
                Button("Heute nicht") { modell.morgenCheckUeberspringen() }
                    .font(.subheadline)
                    .frame(minHeight: Abstand.tippflaeche)
                    .buttonStyle(.plain)
                    .underline()
            }
        }
        .accessibilityElement(children: .contain)
    }
}
