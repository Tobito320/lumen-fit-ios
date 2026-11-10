// Quelle: Lovea Health/Verlauf/VerlaufWocheAnsichten.swift (neu im Lumen-Design)
import SwiftUI
import UIKit

// Bausteine der ruhigen Verlauf-Seite: Zahlenzeile, Start-Knopf, Gruppenliste mit Balken und Erholungspunkt, Highlights. Ohne Timer und Hintergrundarbeit,
// Ziele mindestens 44 pt, Bewegung nur bei Ereignissen und nie unter "Bewegung reduzieren".

/// Die zwei Ansichten oben (Umschalter).
enum VerlaufSeite: String, CaseIterable, Identifiable {
    case woche, verlauf
    var id: String { rawValue }

    var titel: String {
        switch self {
        case .woche: String(localized: "Woche")
        case .verlauf: String(localized: "Verlauf")
        }
    }
}

/// Wohin der Verlauf-Stapel gehen kann.
enum VerlaufZiel: Hashable {
    case gruppe(MuskelGruppe)
    case uebung(String)
    /// Die Trainingstage (Einheiten, Monatsraster, "Training nachtragen"): dorthin führt auch der Hinweis "Besuche ohne Sätze".
    case trainingstage
}

/// Besuche, Minuten, Sätze dieser Woche in einer Zeile; die Zahlen rollen beim Erscheinen hoch (`RollZahl`).
struct VerlaufZusammenfassung: View {
    let z: VerlaufWoche.Zusammenfassung
    @Environment(\.palette) private var palette

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Abstand.l) { spalten }
            VStack(alignment: .leading, spacing: Abstand.s) { spalten }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var spalten: some View {
        wert(z.besuche, z.besuche == 1 ? String(localized: "Besuch") : String(localized: "Besuche"))
        wert(z.minuten, String(localized: "Minuten"))
        wert(z.saetze, z.saetze == 1 ? String(localized: "Satz") : String(localized: "Sätze"))
    }

    private func wert(_ n: Int, _ name: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            RollZahl(wert: Double(n), format: .number.precision(.fractionLength(0)))
                .font(.title.bold()).fontDesign(.rounded)
                .foregroundStyle(n > 0 ? palette.text : palette.text2)
            Text(name).font(.footnote).foregroundStyle(palette.text2).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Der eine große Knopf der Seite: der Start von heute.
struct VerlaufStartKnopf: View {
    let text: String
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            Label(text, systemImage: "play.fill")
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche + 8)
        }
        .buttonStyle(.lumenHauptknopf)
    }
}

/// Auf- und Zuklappen: Titel mit Pfeil, Inhalt darunter gleitet ein (Feder, Haptik). `offen` bleibt beim Aufrufer.
struct VerlaufKlapp<Inhalt: View>: View {
    let titel: String
    @Binding var offen: Bool
    @ViewBuilder var inhalt: () -> Inhalt
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var ruhig
    @State private var tipp = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                tipp += 1
                withAnimation(ruhig ? nil : Feder.schnell) { offen.toggle() }
            } label: {
                HStack(spacing: Abstand.s) {
                    Text(titel).font(.subheadline.weight(.semibold))
                    Spacer(minLength: Abstand.s)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .rotationEffect(.degrees(offen ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(palette.text2)
                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.federnd)
            .accessibilityValue(offen ? "Ausgeklappt" : "Eingeklappt")
            if offen {
                // Der Inhalt blendet ein und gleitet von oben.
                inhalt().transition(ruhig ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .haptik(.auswahl, bei: tipp)
    }
}

/// Eine Gruppe: Erholungszeichen, Name, Balken gegen das Wochenziel, "6 / 12". Ohne Sätze nur Name und Pfeil, gedämpft.
/// Das Erholungszeichen trägt die Stufe über die Form (voll, halb, leer) und im VoiceOver-Text, nicht nur über Farbe.
struct VerlaufGruppenZeile: View {
    let zeile: VerlaufWoche.Zeile
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    private var leer: Bool { zeile.saetze <= 0 }
    private var text: Color { palette.text }
    private var text2: Color { palette.text2 }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Abstand.s) { zeichen; name; Spacer(minLength: Abstand.s); balken(breit: false); zahl; pfeil }
            VStack(alignment: .leading, spacing: Abstand.xs) {
                HStack(spacing: Abstand.s) { zeichen; name; Spacer(minLength: Abstand.s); zahl; pfeil }
                balken(breit: true)
            }
        }
        .frame(minHeight: Abstand.tippflaeche)
        .padding(.horizontal, Abstand.l)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sprechtext)
        .accessibilityHint("Öffnet die Muskelgruppe")
    }

    private var sprechtext: String {
        var teile = [zeile.gruppe.name]
        if leer {
            teile.append(String(localized: "keine Sätze diese Woche"))
        } else {
            teile.append(zeile.ziel.map { String(localized: "\(VerlaufLogik.zahl(zeile.saetze)) von \($0) Sätzen") } ?? VerlaufLogik.saetzeText(zeile.saetze))
        }
        if let e = zeile.erholung { teile.append(KoerperLogik.stufenWort(e)) }
        return teile.joined(separator: ", ")
    }

    /// Platz bleibt auch ohne Zeichen, damit die Namen untereinander stehen.
    @ViewBuilder private var zeichen: some View {
        let farbe = GymFarbe.gruen(schema: schema, kontrast: kontrast)
        Group {
            if let e = zeile.erholung {
                Image(systemName: Self.zeichen(e))
                    .foregroundStyle(e == .erholt ? farbe : palette.text2)
            } else {
                Color.clear
            }
        }
        .font(.caption)
        .frame(width: 14, height: 14)
        .accessibilityHidden(true)
    }

    /// Die Stufe über die Form (voll, halb, leer), damit Farbe nie allein trägt.
    private static func zeichen(_ s: ErholungsStufe) -> String {
        switch s {
        case .erholt: "circle.fill"
        case .fast: "circle.lefthalf.filled"
        case .muede: "circle"
        }
    }

    private var name: some View {
        Text(zeile.gruppe.name)
            .font(.subheadline.weight(leer ? .regular : .semibold))
            .foregroundStyle(leer ? text2 : text)
            .lineLimit(1)
    }

    @ViewBuilder private func balken(breit: Bool) -> some View {
        if !leer, let anteil = zeile.anteil {
            ProgressView(value: anteil)
                .tint(GymFarbe.gruen(schema: schema, kontrast: kontrast))
                .frame(width: breit ? nil : 96)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var zahl: some View {
        if !leer {
            Text(zeile.ziel.map { "\(VerlaufLogik.zahl(zeile.saetze)) / \($0)" } ?? VerlaufLogik.zahl(zeile.saetze))
                .font(.subheadline).monospacedDigit().foregroundStyle(text2).lineLimit(1)
        }
    }

    private var pfeil: some View {
        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
    }
}

/// Besuche dieser Woche ohne gezählten Satz, als schlanke Zeile statt Warnkasten: ein Besuch zählt auch ohne Sätze. Mit `nachtragen` ist sie antippbar
/// und führt zu den Trainingstagen, dort trägt man Sätze nach. Die Tage stehen für VoiceOver im Wert.
struct VerlaufHinweis: View {
    let tage: [VerlaufLogik.TagOhneSaetze]
    var nachtragen: (() -> Void)?
    @Environment(\.palette) private var palette

    var body: some View {
        if let nachtragen {
            Button(action: nachtragen) { zeile.contentShape(.rect) }
                .buttonStyle(.federnd)
                .accessibilityValue(tage.map { Datum.anzeige($0.tag) }.joined(separator: ", "))
                .accessibilityHint("Öffnet die Trainingstage. Tippe dort auf den Tag, um Sätze nachzutragen.")
        } else {
            zeile.accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder private var zeile: some View {
        lumenZeile
    }

    private var lumenZeile: some View {
        HStack(spacing: Abstand.s) {
            Image(systemName: "info.circle").accessibilityHidden(true)
            Text(VerlaufWoche.ohneSaetzeText(tage.count)).font(.subheadline)
            Spacer(minLength: Abstand.s)
            if nachtragen != nil {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).accessibilityHidden(true)
            }
        }
        .foregroundStyle(palette.text)
        .padding(.horizontal, Abstand.l)
        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
    }
}

/// Rekorde und Plateaus: höchstens drei offen, der Rest klappt unter "Mehr" animiert auf. Tipp auf eine Zeile öffnet den Verlauf der Übung.
struct VerlaufHighlightsListe: View {
    let eintraege: [VerlaufHighlights.Eintrag]
    let oeffnen: (String) -> Void
    @Environment(\.palette) private var palette
    @State private var mehrOffen = false

    var body: some View {
        let teile = VerlaufHighlights.kappen(eintraege)
        lumenListe(teile)
    }

    private func lumenListe(_ teile: (offen: [VerlaufHighlights.Eintrag], mehr: [VerlaufHighlights.Eintrag])) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            GymAbschnitt(titel: String(localized: "Rekorde und Plateaus"))
            ListenKarte {
                ForEach(teile.offen) { e in
                    zeile(e)
                    Haarlinie()
                }
                if !teile.mehr.isEmpty {
                    VerlaufKlapp(titel: String(localized: "Weitere Übungen (\(teile.mehr.count))"), offen: $mehrOffen) {
                        ForEach(teile.mehr) { e in
                            zeile(e)
                            Haarlinie()
                        }
                    }
                    .padding(.horizontal, Abstand.l)
                }
            }
        }
    }

    private func zeile(_ e: VerlaufHighlights.Eintrag) -> some View {
        Button { oeffnen(e.uebung.id) } label: {
            HStack(spacing: Abstand.m) {
                Image(systemName: e.art == .rekord ? "medal.fill" : "equal.circle.fill").frame(width: 28).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.uebung.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                    Text(untertitel(e)).font(.footnote).foregroundStyle(palette.text2).lineLimit(2)
                }
                Spacer(minLength: Abstand.s)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.s)
            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.federnd)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(e.uebung.name), \(untertitel(e))")
        .accessibilityHint("Öffnet die Übung")
    }

    private func untertitel(_ e: VerlaufHighlights.Eintrag) -> String {
        let kg = "e1RM \(VerlaufLogik.zahl(e.e1rm)) kg"
        return e.art == .rekord ? String(localized: "Neuer Rekord, \(kg)") : String(localized: "Plateau bei \(kg), seit drei Einheiten nicht gesteigert")
    }
}
