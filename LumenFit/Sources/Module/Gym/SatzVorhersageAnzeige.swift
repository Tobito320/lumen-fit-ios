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

/// Der Vorschlag am Satz, dezent wie Hevys "Previous"-Spalte: "Ziel 32,5 kg × 8" neben "Letztes Mal", ein Tipp trägt Gewicht und Wiederholungen ein.
/// Grund und Reserve hört VoiceOver. Steht nur am ersten offenen Satz einer Übung und nur, solange die Zeile noch anders steht; mit Schalter aus nichts.
/// `aufPlatte`: auf der schwarzen Karte "Als Nächstes" (weiße Schrift).
struct SatzVorschlagAnzeige: View {
    let sitzung: GymSitzung
    let uebung: Int
    let satz: Int
    var aufPlatte = false
    @AppStorage(SatzVorhersageQuelle.anSchluessel) private var an = true
    @AppStorage(SatzVorhersageQuelle.zielSchluessel) private var zielRoh = VorhersageZiel.schwer.rawValue
    @Environment(\.palette) private var palette
    @State private var uebernommen = 0

    var body: some View {
        if an, let v = SatzVorhersageQuelle.vorschlag(sitzung, uebung: uebung, satz: satz, ziel: VorhersageZiel(rawValue: zielRoh) ?? .schwer),
           !v.passt(sitzung.liste[uebung].saetze[satz]) {
            Button {
                sitzung.werteSetzen(uebung, satz, kg: v.kg, wdh: v.wdh)
                uebernommen += 1
            } label: {
                Text("Ziel \(v.text)")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(farbe)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(minHeight: Abstand.tippflaeche, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .haptik(.auswahl, bei: uebernommen)
            .accessibilityLabel(vorleseText(v))
            .accessibilityHint("Trägt Gewicht und Wiederholungen ein")
        }
    }

    private func vorleseText(_ v: SatzVorschlag) -> String {
        let wert = v.kg.map { "\(TrainingLogik.kgText($0)) Kilo, \(v.wdh) Wiederholungen" } ?? "\(v.wdh) Wiederholungen"
        let reserve = v.reserveText.map { ", \($0)" } ?? ""
        return "Vorschlag: \(wert)\(reserve). \(v.grund.text)"
    }

    private var farbe: Color { aufPlatte ? .white : palette.akzent }
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
