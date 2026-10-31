// Quelle: Lovea Health/Verlauf/VerlaufWocheAnsichten.swift (neu im Lumen-Design)
import SwiftUI
import UIKit

// Bausteine der ruhigen Verlauf-Seite: Zahlenzeile, Start-Knopf, Gruppenliste mit Balken und Erholungspunkt, Highlights, Plan. Ohne Timer und Hintergrundarbeit,
// Ziele mindestens 44 pt, Bewegung nur bei Ereignissen und nie unter "Bewegung reduzieren".

/// Die drei Ansichten oben (Umschalter).
enum VerlaufSeite: String, CaseIterable, Identifiable {
    case woche, verlauf, plan
    var id: String { rawValue }

    var titel: String {
        switch self {
        case .woche: "Woche"
        case .verlauf: "Verlauf"
        case .plan: "Plan"
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
    @Environment(\.lumenAufbau) private var aufbau

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Abstand.l) { spalten }
            VStack(alignment: .leading, spacing: Abstand.s) { spalten }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var spalten: some View {
        wert(z.besuche, z.besuche == 1 ? "Besuch" : "Besuche")
        wert(z.minuten, "Minuten")
        wert(z.saetze, z.saetze == 1 ? "Satz" : "Sätze")
    }

    private func wert(_ n: Int, _ name: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if aufbau == .lovea {
                // Lovea VerlaufWocheAnsichten.swift:38-45: feste Zahl, Systemschrift, kein Hochrollen.
                Text("\(n)").font(.title.bold()).monospacedDigit().foregroundStyle(n > 0 ? Color.primary : Color.secondary)
            } else {
                RollZahl(wert: Double(n), format: .number.precision(.fractionLength(0)))
                    .font(.title.bold()).fontDesign(.rounded)
                    .foregroundStyle(n > 0 ? palette.text : palette.text2)
            }
            Text(name).font(.footnote).foregroundStyle(aufbau == .lovea ? Color.secondary : palette.text2).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Der eine große Knopf der Seite: der Start von heute.
struct VerlaufStartKnopf: View {
    let text: String
    let aktion: () -> Void
    @Environment(\.lumenAufbau) private var aufbau

    var body: some View {
        if aufbau == .lovea {
            // Lovea VerlaufWocheAnsichten.swift:56-68: weiße Schrift auf Rose, 52 pt hoch, Radius 14, federnder Knopf.
            Button(action: aktion) {
                Label(text, systemImage: "play.fill")
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .padding(.horizontal, 16)
                    .background(VerlaufLovea.rose, in: .rect(cornerRadius: 14, style: .continuous))
                    .contentShape(.rect)
            }
            .buttonStyle(.federnd)
        } else {
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
}

/// Auf- und Zuklappen: Titel mit Pfeil, Inhalt darunter gleitet ein (Feder, Haptik). `offen` bleibt beim Aufrufer.
struct VerlaufKlapp<Inhalt: View>: View {
    let titel: String
    @Binding var offen: Bool
    @ViewBuilder var inhalt: () -> Inhalt
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau
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
                .foregroundStyle(aufbau == .lovea ? Color.secondary : palette.text2)
                .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.federnd)
            .accessibilityValue(offen ? "Ausgeklappt" : "Eingeklappt")
            if offen {
                // Lovea (:98) blendet nur ein; Lumen lässt den Inhalt zusätzlich von oben gleiten.
                inhalt().transition(ruhig || aufbau == .lovea ? .opacity : .opacity.combined(with: .move(edge: .top)))
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
    @Environment(\.lumenAufbau) private var aufbau
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    private var leer: Bool { zeile.saetze <= 0 }
    private var lovea: Bool { aufbau == .lovea }
    private var text: Color { lovea ? Color.primary : palette.text }
    private var text2: Color { lovea ? Color.secondary : palette.text2 }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Abstand.s) { zeichen; name; Spacer(minLength: Abstand.s); balken(breit: false); zahl; pfeil }
            VStack(alignment: .leading, spacing: Abstand.xs) {
                HStack(spacing: Abstand.s) { zeichen; name; Spacer(minLength: Abstand.s); zahl; pfeil }
                balken(breit: true)
            }
        }
        .frame(minHeight: Abstand.tippflaeche)
        .padding(.horizontal, lovea ? 0 : Abstand.l) // Lovea: die Liste liegt ohne Kasten auf der Seite
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sprechtext)
        .accessibilityHint("Öffnet die Muskelgruppe")
    }

    private var sprechtext: String {
        var teile = [zeile.gruppe.name]
        if leer {
            teile.append("keine Sätze diese Woche")
        } else {
            teile.append(zeile.ziel.map { "\(VerlaufLogik.zahl(zeile.saetze)) von \($0) Sätzen" } ?? VerlaufLogik.saetzeText(zeile.saetze))
        }
        if let e = zeile.erholung { teile.append(KoerperLogik.stufenWort(e)) }
        return teile.joined(separator: ", ")
    }

    /// Platz bleibt auch ohne Zeichen, damit die Namen untereinander stehen.
    @ViewBuilder private var zeichen: some View {
        let farbe = GymFarbe.gruen(schema: schema, kontrast: kontrast)
        Group {
            if let e = zeile.erholung {
                // Lovea (:137-141): Punkt in der Stufenfarbe; die Form (voll, halb, leer) bleibt zusätzlich.
                Image(systemName: VerlaufLovea.zeichen(e))
                    .foregroundStyle(lovea ? VerlaufLovea.stufe(e) : (e == .erholt ? farbe : palette.text2))
            } else {
                Color.clear
            }
        }
        .font(lovea ? .system(size: 8) : .caption)
        .frame(width: lovea ? 8 : 14, height: lovea ? 8 : 14)
        .accessibilityHidden(true)
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
                .tint(lovea ? VerlaufLovea.rose : GymFarbe.gruen(schema: schema, kontrast: kontrast))
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
        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(lovea ? Color(uiColor: .tertiaryLabel) : palette.text2).accessibilityHidden(true)
    }
}

/// Besuche dieser Woche ohne gezählten Satz, als schlanke Zeile statt Warnkasten: ein Besuch zählt auch ohne Sätze. Mit `nachtragen` ist sie antippbar
/// und führt zu den Trainingstagen, dort trägt man Sätze nach. Die Tage stehen für VoiceOver im Wert.
struct VerlaufHinweis: View {
    let tage: [VerlaufLogik.TagOhneSaetze]
    var nachtragen: (() -> Void)?
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau

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
        if aufbau == .lovea { loveaZeile } else { lumenZeile }
    }

    /// Lovea VerlaufView.swift:439-447: ohne Symbol, graue Schrift, Systemfläche mit Radius 12.
    private var loveaZeile: some View {
        HStack(spacing: 8) {
            Text(VerlaufWoche.ohneSaetzeText(tage.count)).font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            if nachtragen != nil {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 12, style: .continuous))
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
    @Environment(\.lumenAufbau) private var aufbau
    @State private var mehrOffen = false

    var body: some View {
        let teile = VerlaufHighlights.kappen(eintraege)
        if aufbau == .lovea { loveaListe(teile) } else { lumenListe(teile) }
    }

    /// Lovea VerlaufWocheAnsichten.swift:182-195: Titel "Highlights", Zeilen mit Trennlinie, ohne Kasten und ohne Symbol.
    private func loveaListe(_ teile: (offen: [VerlaufHighlights.Eintrag], mehr: [VerlaufHighlights.Eintrag])) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Highlights")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(teile.offen) { loveaZeile($0) }
            if !teile.mehr.isEmpty {
                VerlaufKlapp(titel: "Mehr (\(teile.mehr.count))", offen: $mehrOffen) {
                    ForEach(teile.mehr) { loveaZeile($0) }
                }
            }
        }
    }

    /// Lovea :197-219.
    private func loveaZeile(_ e: VerlaufHighlights.Eintrag) -> some View {
        Button { oeffnen(e.uebung.id) } label: {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.uebung.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(loveaUntertitel(e)).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
                }
                .frame(minHeight: Abstand.tippflaeche)
                .padding(.vertical, 4)
                Divider()
            }
            .contentShape(.rect)
        }
        .buttonStyle(.federnd)
        .foregroundStyle(.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(e.uebung.name), \(loveaUntertitel(e))")
        .accessibilityHint("Öffnet die Übung")
    }

    private func loveaUntertitel(_ e: VerlaufHighlights.Eintrag) -> String {
        let kg = "e1RM \(VerlaufLogik.zahl(e.e1rm)) kg"
        return e.art == .rekord ? "Neuer Rekord, \(kg)" : "Plateau, \(kg)"
    }

    private func lumenListe(_ teile: (offen: [VerlaufHighlights.Eintrag], mehr: [VerlaufHighlights.Eintrag])) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            GymAbschnitt(titel: "Rekorde und Plateaus")
            ListenKarte {
                ForEach(teile.offen) { e in
                    zeile(e)
                    Haarlinie()
                }
                if !teile.mehr.isEmpty {
                    VerlaufKlapp(titel: "Mehr (\(teile.mehr.count))", offen: $mehrOffen) {
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
        return e.art == .rekord ? "Neuer Rekord, \(kg)" : "Plateau bei \(kg), seit drei Einheiten nicht gesteigert"
    }
}

/// Der Plan in einer Liste: Split, Tage mit Wochentagen. Tipp öffnet die Gym-Seite zum Ändern.
struct VerlaufPlan: View {
    let plan: TrainingsPlan
    let oeffnen: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau

    var body: some View {
        if aufbau == .lovea { loveaPlan } else { lumenPlan }
    }

    /// Lovea VerlaufWocheAnsichten.swift:232-257: flache Liste mit Trennlinien, Split als graue Zeile, Textlink in Rose.
    private var loveaPlan: some View {
        VStack(alignment: .leading, spacing: 0) {
            if plan.tage.isEmpty {
                Text("Noch kein Plan. Such dir in der Gym-Seite einen Split aus.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            } else {
                if let split = plan.splitName {
                    Text(split).font(.footnote.weight(.semibold)).foregroundStyle(.secondary).padding(.bottom, 4)
                }
                ForEach(plan.tage) { t in
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            Text(t.name.isEmpty ? "Training" : t.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                            Spacer(minLength: 8)
                            Text(Self.untertitel(t)).font(.subheadline).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(minHeight: Abstand.tippflaeche)
                        Divider()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Button(action: oeffnen) { VerlaufLoveaTextlink(text: plan.tage.isEmpty ? "Gym öffnen" : "Plan ansehen und ändern") }
                .buttonStyle(.federnd)
        }
    }

    private var lumenPlan: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            if plan.tage.isEmpty {
                Text("Noch kein Plan. Such dir in der Gym-Seite einen Split aus.").font(.subheadline).foregroundStyle(palette.text2)
            } else {
                if let split = plan.splitName { GymAbschnitt(titel: split) }
                ListenKarte {
                    ForEach(plan.tage) { t in
                        zeile(t)
                        if t.id != plan.tage.last?.id { Haarlinie() }
                    }
                }
            }
            Button(action: oeffnen) {
                Label(plan.tage.isEmpty ? "Gym öffnen" : "Plan ansehen und ändern", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
                    .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.bordered)
        }
    }

    /// "Mo, Do · 6 Übungen".
    static func untertitel(_ t: TrainingsTag) -> String {
        let tage = t.wochentage.sorted().compactMap { w -> String? in HabitLogik.wochentagKuerzel.indices.contains(w - 1) ? HabitLogik.wochentagKuerzel[w - 1] : nil }
        let n = t.uebungen.count
        let umfang = n == 1 ? "1 Übung" : "\(n) Übungen"
        return tage.isEmpty ? umfang : tage.joined(separator: ", ") + " · " + umfang
    }

    private func zeile(_ t: TrainingsTag) -> some View {
        GymZeile(titel: t.name.isEmpty ? "Training" : t.name, untertitel: Self.untertitel(t))
            .accessibilityElement(children: .combine)
    }
}
