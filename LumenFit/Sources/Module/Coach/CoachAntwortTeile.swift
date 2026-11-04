import SwiftUI
import UIKit

// Bausteine des Coach-Chats im Lumen-Design (Apple monochrom, Lumi als Figur): Antworttext ohne Blase, Blase der Person, Tippanzeige, Chips,
// Daumen, Menü beim langen Drücken (Merken, Kopieren, Neu fragen), Karte des Morgen-Checks. Jede Tippfläche hat mindestens 44 pt, jedes Symbol ein Label, Reduce Motion wird beachtet.

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

    /// "Heute, 14:05" oder "Mittwoch, 23. September, 14:05": für die Uhrzeit unter einer Nachricht und für VoiceOver.
    static func zeitText(_ datum: Date) -> String {
        let kalender = Datum.kalender
        let tagText = kalender.isDateInToday(datum) ? "Heute" : kalender.isDateInYesterday(datum) ? "Gestern" : tag(datum)
        return "\(tagText), \(uhrzeit(datum))"
    }

    /// Zahl ohne unnötige Nachkommastellen, deutsch: 8200 -> "8.200", 82,4 -> "82,4".
    static func zahl(_ wert: Double) -> String {
        let begrenzt = min(max(wert, 0), 1_000_000_000)
        return begrenzt.formatted(.number.precision(.fractionLength(0...1)).locale(deutsch))
    }

    /// Der Text ohne Markdown-Zeichen, für VoiceOver.
    static func klartext(_ text: String) -> String {
        String(CoachText.inline(text).characters)
    }

    /// Antwort ohne Marker und ohne Fett-Sterne, zum Kopieren und Teilen.
    static func kopierText(_ roh: String) -> String {
        CoachMarker.zerlegen(roh).text.replacingOccurrences(of: "**", with: "")
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

/// Die Antwort des Coachs: Absätze, Überschriften, Listen, Nummern und Tabellen ohne Blase. Marker fallen weg. Mit `aufgaben` sind
/// Aufgabenzeilen zum Abhaken (Haken pro Antwort); `woerter` blendet nur die ersten Wörter ein (Wort für Wort).
struct CoachAntwortText: View {
    let text: String
    var aufgaben: CoachAufgabenAnbindung?
    var woerter: Int?
    @Environment(\.palette) private var palette

    var body: some View {
        let alle = CoachText.zeilen(CoachMarker.zerlegen(text).text)
        VStack(alignment: .leading, spacing: Abstand.s) {
            ForEach(Array(zeigen(alle).enumerated()), id: \.offset) { _, zeile in
                ansicht(zeile)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    private func zeigen(_ zeilen: [CoachText.Zeile]) -> [CoachText.Zeile] {
        guard let woerter else { return zeilen }
        return CoachText.eingeblendet(zeilen, woerter: woerter)
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
            if let aufgaben {
                CoachAufgabeZeile(text: zeile.text, erledigt: aufgaben.modell.istAbgehakt(aufgaben.nachricht, zeile.text)) {
                    aufgaben.modell.schalteHaken(aufgaben.nachricht, zeile.text)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
                    Image(systemName: "circle").foregroundStyle(palette.text2).accessibilityHidden(true)
                    Text(CoachAnzeige.markiert(zeile.text)).font(.body).foregroundStyle(palette.text)
                }
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tabelle. " + daten.map { reihe in zip(kopf, reihe).map { "\($0): \($1)" }.joined(separator: ", ") }.joined(separator: ". "))
        }
    }
}

/// Womit eine Antwort ihre Aufgaben abhakt: das Modell und die Nachricht, an die der Haken gebunden ist.
struct CoachAufgabenAnbindung {
    let modell: CoachModell
    let nachricht: CoachNachricht
}

// MARK: - Blase der Person

extension CoachMarker.Ziel {
    /// Die Seite zu einem Ring-Label ("Schritte", "Schlaf", ...); `nil`, wenn es dazu keine gibt.
    static func fuer(label: String) -> CoachMarker.Ziel? {
        let klein = label.lowercased()
        if klein.contains("schritt") { return .schritte }
        if klein.contains("schlaf") { return .schlaf }
        if klein.contains("gewicht") { return .gewicht }
        if klein.contains("training") || klein.contains("satz") || klein.contains("sätze") { return .training }
        if klein.contains("kcal") || klein.contains("kalorien") || klein.contains("protein") || klein.contains("essen") { return .essen }
        return nil
    }
}

/// Blase der Person. Tippen zeigt die Uhrzeit; langes Drücken: Kopieren, Teilen, Anheften, In die Eingabe übernehmen.
struct CoachNutzerBlase: View {
    let modell: CoachModell
    let nachricht: CoachNachricht
    var hervor = false
    @Environment(\.palette) private var palette
    @State private var zeitSichtbar = false

    var body: some View {
        VStack(alignment: .trailing, spacing: Abstand.xs) {
            Text(nachricht.text)
                .font(.body)
                .foregroundStyle(palette.aufAkzent)
                .padding(.horizontal, Abstand.l)
                .padding(.vertical, Abstand.m)
                .background(palette.akzent, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
                .overlay {
                    if hervor {
                        RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous).stroke(palette.text, lineWidth: 2)
                    }
                }
                .padding(.leading, Abstand.xxl)
                .contentShape(.rect)
                .onTapGesture { withAnimation(Feder.schnell) { zeitSichtbar.toggle() } }
                .contextMenu {
                    Button("Kopieren", systemImage: "doc.on.doc") { UIPasteboard.general.string = nachricht.text }
                    ShareLink(item: nachricht.text) { Label("Teilen", systemImage: "square.and.arrow.up") }
                    Button(modell.istGemerkt(nachricht) ? "Nicht mehr anheften" : "Anheften",
                           systemImage: modell.istGemerkt(nachricht) ? "pin.slash" : "pin") { modell.schalteMerkliste(nachricht) }
                    Button("In Eingabe übernehmen", systemImage: "arrow.up.doc") {
                        modell.entwurf = String(nachricht.text.prefix(CoachModell.maxZeichen))
                    }
                }
            if zeitSichtbar {
                Text(CoachAnzeige.zeitText(nachricht.zeit)).font(.caption).foregroundStyle(palette.text2)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Du: \(nachricht.text). \(CoachAnzeige.zeitText(nachricht.zeit))")
    }
}

// MARK: - Antwort des Coachs

/// Eine Antwort mit allem darunter: Text (Wort für Wort, solange sie frisch ist), Diagramm, Ring, Nacht, Ziel, Chips, Aktionen.
/// Der volle Text steht unsichtbar im Layout, damit die Zeile beim Einblenden nicht wächst und springt.
struct CoachAntwortZeile: View {
    let modell: CoachModell
    let nachricht: CoachNachricht
    let letzte: Bool
    var hervor = false

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var reduceMotion
    @State private var zeitSichtbar = false
    @State private var fertig: Bool
    /// Zählt Tipps im Menü des langen Drückens, damit jeder Punkt eine Rückmeldung gibt.
    @State private var menueTipps = 0
    private let start: Date?
    private let gesamt: Int

    init(modell: CoachModell, nachricht: CoachNachricht, letzte: Bool, hervor: Bool = false) {
        self.modell = modell
        self.nachricht = nachricht
        self.letzte = letzte
        self.hervor = hervor
        let n = CoachText.gesamtWoerter(CoachText.zeilen(CoachMarker.zerlegen(nachricht.text).text))
        gesamt = n
        var beginn: Date?
        if letzte, !CoachPersona.istFehler(nachricht.text), CoachText.einblendenLohnt(gesamt: n),
           let seit = modell.frischSeit(nachricht.id), modell.jetzt.timeIntervalSince(seit) < CoachText.einblendDauer(gesamt: n) {
            beginn = seit
        }
        start = beginn
        _fertig = State(initialValue: beginn == nil)
    }

    var body: some View {
        let zerlegt = CoachMarker.zerlegen(nachricht.text)
        let fehler = CoachPersona.istFehler(nachricht.text)
        VStack(alignment: .leading, spacing: Abstand.s) {
            if fehler {
                CoachFehlerZeile(text: nachricht.text)
            } else {
                textBlock
                    .contentShape(.rect)
                    .onTapGesture { withAnimation(Feder.schnell) { zeitSichtbar.toggle() } }
                    .contextMenu { menue }
                if zeitSichtbar {
                    Text(CoachAnzeige.zeitText(nachricht.zeit)).font(.caption).foregroundStyle(palette.text2).transition(.opacity)
                }
            }
            if fertig || reduceMotion {
                extras(zerlegt)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                // Ältere Antworten bleiben nur Text; Chips und Daumen stehen unter der letzten (W-003).
                if letzte {
                    CoachChipLeiste(nachricht: nachricht, modell: modell)
                    if !fehler { CoachAktionsZeile(nachricht: nachricht, modell: modell) }
                }
            }
        }
        .haptik(.auswahl, bei: menueTipps)
        .padding(hervor ? Abstand.s : 0)
        .background(hervor ? palette.akzent.opacity(0.12) : .clear, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        .task {
            guard let start, !fertig else { return }
            let rest = start.addingTimeInterval(CoachText.einblendDauer(gesamt: gesamt)).timeIntervalSince(modell.jetzt)
            try? await Task.sleep(for: .seconds(max(0, rest)))
            withAnimation(reduceMotion ? nil : Feder.weich) { fertig = true }
        }
    }

    @ViewBuilder
    private var menue: some View {
        let text = CoachAnzeige.kopierText(nachricht.text)
        ForEach(CoachAntwortMenue.punkte(letzte: letzte, gemerkt: modell.istGemerkt(nachricht), denkt: modell.denkt, pausiert: modell.pausiert),
                id: \.self) { punkt in
            switch punkt {
            case .kopieren:
                Button("Kopieren", systemImage: "doc.on.doc") { UIPasteboard.general.string = text; menueTipps += 1 }
            case .teilen:
                ShareLink(item: text) { Label("Teilen", systemImage: "square.and.arrow.up") }
            case .merken(let gemerkt):
                Button(gemerkt ? "Nicht mehr merken" : "Merken", systemImage: gemerkt ? "bookmark.slash" : "bookmark") {
                    modell.schalteMerkliste(nachricht); menueTipps += 1
                }
            case .nochmal:
                Button("Neu fragen", systemImage: "arrow.clockwise") { modell.nochmal(); menueTipps += 1 }
            }
        }
    }

    @ViewBuilder
    private var textBlock: some View {
        let anbindung = CoachAufgabenAnbindung(modell: modell, nachricht: nachricht)
        if let start, !fertig, !reduceMotion {
            TimelineView(.explicit(CoachText.einblendTermine(start: start, gesamt: gesamt))) { zeit in
                let n = CoachText.sichtbareWoerter(vergangen: zeit.date.timeIntervalSince(start), gesamt: gesamt)
                ZStack(alignment: .topLeading) {
                    CoachAntwortText(text: nachricht.text).hidden()
                    CoachAntwortText(text: nachricht.text, woerter: n)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(CoachAnzeige.klartext(CoachAnzeige.kopierText(nachricht.text)))
        } else {
            CoachAntwortText(text: nachricht.text, aufgaben: anbindung)
        }
    }

    @ViewBuilder
    private func extras(_ zerlegt: CoachMarker.Zerlegt) -> some View {
        if let d = zerlegt.diagramm { CoachDiagramm(titel: d.titel, punkte: d.punkte) }
        if let l = zerlegt.linie { CoachDiagramm(titel: l.titel, punkte: l.punkte, linie: true) }
        if let f = zerlegt.fortschritt {
            CoachFortschritt(label: f.label, aktuell: f.aktuell, ziel: f.ziel, weg: CoachMarker.Ziel.fuer(label: f.label)?.route)
        }
        if let nacht = zerlegt.schlafNacht, umgebung.router.einstellungen.schlafAn { CoachSchlafKarte(tag: nacht) }
        if let ziel = zerlegt.vorgeschlagenesZiel { CoachZielKnopf(text: ziel, modell: modell) }
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
    @Environment(AppUmgebung.self) private var umgebung

    /// "Zeig mir" auf einen ausgeschalteten Bereich (Essen, Schlaf, Gym) ergibt keinen Chip; die Daten bleiben.
    private var chips: [CoachChip] {
        nachricht.chips.filter { chip in
            if case .oeffne(let route) = chip.aktion { return umgebung.router.einstellungen.zeigt(route) }
            return true
        }
    }

    var body: some View {
        if !chips.isEmpty {
            CoachChipFluss(zentriert: false) {
                ForEach(chips) { chip in
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

// MARK: - Daumen

/// Unter der letzten Antwort nur die Daumen; Merken, Kopieren und "Neu fragen" liegen im langen Drücken (`CoachAntwortMenue`).
struct CoachAktionsZeile: View {
    let nachricht: CoachNachricht
    let modell: CoachModell

    var body: some View {
        HStack(spacing: Abstand.xs) {
            knopf(symbol: nachricht.daumen == true ? "hand.thumbsup.fill" : "hand.thumbsup", label: "Antwort gefällt mir",
                  an: nachricht.daumen == true) { modell.setzeDaumen(true, an: nachricht) }
            knopf(symbol: nachricht.daumen == false ? "hand.thumbsdown.fill" : "hand.thumbsdown", label: "Antwort gefällt mir nicht",
                  an: nachricht.daumen == false) { modell.setzeDaumen(false, an: nachricht) }
        }
    }

    private func knopf(symbol: String, label: String, an: Bool, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Image(systemName: symbol)
                .font(.body)
                .contentTransition(.symbolEffect(.replace))
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
