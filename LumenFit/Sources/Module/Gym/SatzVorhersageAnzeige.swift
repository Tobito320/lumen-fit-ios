import SwiftUI

/// Liest für die Ansichten, was der Satz-Vorschlag braucht: die Zeilen der Übung, die früheren Einheiten (ohne das laufende Training), Art und Schritt
/// des Geräts und die zwei Einstellungen. Schreibt nichts; übernommen wird über `GymSitzung.werteSetzen` (derselbe Weg wie Tippen und Plus/Minus).
@MainActor
enum SatzVorhersageQuelle {
    nonisolated static let anSchluessel = "fit.vorhersage.an"
    nonisolated static let zielSchluessel = "fit.vorhersage.ziel"

    static var an: Bool { UserDefaults.standard.object(forKey: anSchluessel) as? Bool ?? true }
    static var ziel: VorhersageZiel { VorhersageZiel(rawValue: UserDefaults.standard.string(forKey: zielSchluessel) ?? "") ?? .schwer }

    /// Frühere Einheiten je Übung, einmal je Training gerechnet: `TrainingStore.sessions` faltet bei jedem Lesen alle Ops neu, und jede Satzzeile fragt.
    /// shortcut: ändert jemand mitten im Training eine alte Einheit, gilt der neue Stand erst im nächsten Training; bei Bedarf am Op-Zähler festmachen.
    private static var historien: [String: [UebungTag]] = [:]
    private static var historienTraining: String?

    private static func historie(_ sitzung: GymSitzung, _ w: WorkoutUebung) -> [UebungTag] {
        let training = sitzung.sessionId ?? ""
        if historienTraining != training {
            historien = [:]
            historienTraining = training
        }
        let schluessel = "\(w.planUebung.uebung)|\(w.id)"
        if let da = historien[schluessel] { return da }
        let frueher = (sitzung.training?.sessions ?? []).filter { $0.id != sitzung.sessionId }
        let neu = RekordLogik.tage(katalogId: w.planUebung.uebung, planId: w.id, in: frueher)
        historien[schluessel] = neu
        return neu
    }

    /// Der Vorschlag für Satz `satz` der Übung `uebung`, aber nur, wenn das der erste offene Satz der Übung ist (einer auf einmal, nach jedem Haken neu).
    static func vorschlag(_ sitzung: GymSitzung, uebung u: Int, satz i: Int, ziel: VorhersageZiel) -> SatzVorschlag? {
        guard sitzung.liste.indices.contains(u), sitzung.liste[u].saetze.firstIndex(where: { $0.ok != true }) == i else { return nil }
        return rechne(sitzung, uebung: u, satz: i, ziel: ziel)
    }

    /// Das vorgeschlagene Arbeitsgewicht der Übung (erster offener Satz, der kein Aufwärmsatz ist), etwa als Start des Scheibenrechners; nil ohne.
    static func arbeitsgewicht(_ sitzung: GymSitzung, uebung u: Int) -> Double? {
        guard an, sitzung.liste.indices.contains(u),
              let i = sitzung.liste[u].saetze.firstIndex(where: { $0.ok != true && $0.typ != "w" && $0.typ != "d" }) else { return nil }
        return rechne(sitzung, uebung: u, satz: i, ziel: ziel)?.kg
    }

    private static func rechne(_ sitzung: GymSitzung, uebung u: Int, satz i: Int, ziel: VorhersageZiel) -> SatzVorschlag? {
        let w = sitzung.liste[u]
        guard !w.planUebung.istCardio, !w.ausgelassen else { return nil }
        let katalog = sitzung.katalog(w.planUebung)
        guard let art = SatzVorhersageLogik.art(katalog, name: w.planUebung.anzeigeName) else { return nil }
        return SatzVorhersageLogik.vorschlag(zeile: i, saetze: w.saetze, historie: historie(sitzung, w), art: art,
                                             schritt: LetztesMal.kgSchritt(geraet: katalog?.geraet), ziel: ziel,
                                             pause: w.planUebung.pause ?? PauseLogik.standard, heute: Datum.text(sitzung.umgebung.uhr()))
    }
}

/// Der Vorschlag am Satz: "Vorschlag: 62,5 kg × 8 · 1 Wdh Reserve", darunter der Grund (bei der Langhantel mit Scheiben pro Seite). Ein Tipp trägt
/// Gewicht und Wiederholungen in die Zeile ein. Steht nur am ersten offenen Satz einer Übung; ohne Vorschlag oder mit Schalter aus nichts.
/// `aufPlatte`: auf der schwarzen Karte "Als Nächstes" (Schrift kommt von der Karte).
struct SatzVorschlagAnzeige: View {
    let sitzung: GymSitzung
    let uebung: Int
    let satz: Int
    var aufPlatte = false
    @AppStorage(SatzVorhersageQuelle.anSchluessel) private var an = true
    @AppStorage(SatzVorhersageQuelle.zielSchluessel) private var zielRoh = VorhersageZiel.schwer.rawValue
    @Environment(\.palette) private var palette
    @Environment(\.lumenAufbau) private var aufbau
    @State private var uebernommen = 0

    var body: some View {
        if an, let v = SatzVorhersageQuelle.vorschlag(sitzung, uebung: uebung, satz: satz, ziel: VorhersageZiel(rawValue: zielRoh) ?? .schwer) {
            let passt = v.passt(sitzung.liste[uebung].saetze[satz])
            Button {
                sitzung.werteSetzen(uebung, satz, kg: v.kg, wdh: v.wdh)
                uebernommen += 1
            } label: {
                inhalt(v, passt: passt)
            }
            .buttonStyle(.plain)
            .disabled(passt)
            .haptik(.auswahl, bei: uebernommen)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(vorleseText(v, passt: passt))
            .accessibilityHint(passt ? "" : "Trägt Gewicht und Wiederholungen ein")
        }
    }

    private func inhalt(_ v: SatzVorschlag, passt: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
            Image(systemName: passt ? "checkmark.circle.fill" : "arrow.up.forward.circle.fill")
                .foregroundStyle(akzent)
            VStack(alignment: .leading, spacing: 1) {
                Text(titel(v, passt: passt)).font(.footnote.weight(.semibold)).monospacedDigit()
                Text(unterzeile(v)).font(.caption).foregroundStyle(nebenFarbe)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(hauptFarbe)
        .frame(minHeight: Abstand.tippflaeche, alignment: .leading)
        .contentShape(.rect)
    }

    private func titel(_ v: SatzVorschlag, passt: Bool) -> String {
        let kopf = passt ? "Vorschlag eingetragen" : "Vorschlag"
        return [("\(kopf): \(v.text)"), v.reserveText].compactMap { $0 }.joined(separator: " · ")
    }

    private func unterzeile(_ v: SatzVorschlag) -> String {
        let geraet = sitzung.liste.indices.contains(uebung) ? sitzung.katalog(sitzung.liste[uebung].planUebung)?.geraet : nil
        let scheiben = v.kg.flatMap { SatzVorhersageLogik.scheiben(kg: $0, geraet: geraet) }
        return [v.grund.text, scheiben.map { "pro Seite \($0)" }].compactMap { $0 }.joined(separator: " · ")
    }

    private func vorleseText(_ v: SatzVorschlag, passt: Bool) -> String {
        let wert = v.kg.map { "\(TrainingLogik.kgText($0)) Kilo, \(v.wdh) Wiederholungen" } ?? "\(v.wdh) Wiederholungen"
        let reserve = v.reserveText.map { ", \($0)" } ?? ""
        return "\(passt ? "Vorschlag eingetragen" : "Vorschlag"): \(wert)\(reserve). \(v.grund.text)"
    }

    private var akzent: Color { aufPlatte ? .white : aufbau == .lovea ? .blue : palette.akzent }
    private var hauptFarbe: Color { aufPlatte ? .white : aufbau == .lovea ? .primary : palette.text }
    private var nebenFarbe: Color { aufPlatte ? .white.opacity(0.8) : aufbau == .lovea ? .secondary : palette.text2 }
}

/// Die Einstellungen des Satz-Vorschlags im Blatt "Einstellungen fürs Training": an oder aus und das Ziel (schwer oder klassisch).
struct SatzVorhersageAbschnitt: View {
    @AppStorage(SatzVorhersageQuelle.anSchluessel) private var an = true
    @AppStorage(SatzVorhersageQuelle.zielSchluessel) private var zielRoh = VorhersageZiel.schwer.rawValue

    var body: some View {
        let ziel = VorhersageZiel(rawValue: zielRoh) ?? .schwer
        Section {
            Toggle("Vorschlag für jeden Satz", isOn: $an)
            if an {
                Picker("Ziel", selection: $zielRoh) {
                    ForEach(VorhersageZiel.allCases) { Text($0.titel).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }
        } header: {
            Text("Satz-Vorschlag")
        } footer: {
            Text("Aus deinen letzten Sätzen schätzt Lumen Fit deine Stärke und schlägt Gewicht und Wiederholungen für den nächsten Satz vor. \(ziel.bereicheText) Schaffst du oben im Bereich alle Sätze, kommt mehr Gewicht. Nach drei Einheiten ohne Fortschritt kommt eine leichtere Einheit. Ein Tipp auf den Vorschlag trägt ihn ein.")
        }
    }
}
