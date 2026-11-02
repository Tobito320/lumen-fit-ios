// Quelle: Lovea Health/Verlauf/VerlaufView.swift (VerlaufLeer :401, VerlaufGruppe :456, VerlaufUebung :545, VerlaufZeile :586, VerlaufAbschnitt :603)
import SwiftUI

/// Hilfen der Verlauf-Seite im Lovea-Aufbau (`LumenAufbau.lovea`): Farben, die Reihenfolge der Blöcke und die Zeichen der Erholung.
/// Alle Daten kommen aus den Lumen-Stores und `VerlaufLogik`/`VerlaufWoche`; hier steht nur die Darstellung.
enum VerlaufLovea {
    /// Lovea `Color.loveaRose` (Start-Knopf :65, Textlinks :279, Balken :154).
    static let rose = LumenFarben.loveaRose

    /// Lovea `KoerperFarbe.stufe` (KoerperView.swift:381-386): erholt grün, fast koralle, müde Rose.
    static func stufe(_ s: ErholungsStufe) -> Color {
        switch s {
        case .erholt: Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)
        case .fast: Color(red: 1, green: 0x7A / 255, blue: 0x59 / 255)
        case .muede: rose
        }
    }

    /// Lumen trägt die Stufe zusätzlich über die Form (voll, halb, leer); sie bleibt auch im Lovea-Aufbau, damit Farbe nie allein trägt.
    static func zeichen(_ s: ErholungsStufe) -> String {
        switch s {
        case .erholt: "circle.fill"
        case .fast: "circle.lefthalf.filled"
        case .muede: "circle"
        }
    }

    /// Die Blöcke der Seite "Verlauf" in der Reihenfolge von Lovea (`VerlaufView.swift:267-282`), danach die Karten, die nur Lumen hat.
    static func verlaufBloecke(highlights: Bool) -> [VerlaufLoveaBlock] {
        var liste: [VerlaufLoveaBlock] = [.konsistenz]
        if highlights { liste.append(.highlights) }
        liste.append(.alleTrainingstage)
        liste += [.gewicht, .stimmung, .rueckblick]
        return liste
    }
}

enum VerlaufLoveaBlock: Hashable, Sendable {
    case konsistenz, highlights, alleTrainingstage, gewicht, stimmung, rueckblick
}

/// Textlink in Rose mit Pfeil (Lovea "Alle Trainingstage" :279, "Plan ansehen und ändern" VerlaufWocheAnsichten.swift:245): nur das Etikett, der Knopf kommt vom Aufrufer.
struct VerlaufLoveaTextlink: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).accessibilityHidden(true)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(VerlaufLovea.rose)
        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
        .contentShape(.rect)
    }
}

/// Leerzustand der Woche (Lovea `VerlaufLeer` :401): Symbol, Satz, kein Kasten.
struct VerlaufLoveaLeer: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Noch keine Sätze eingetragen. Im Tab Gym hakst du Sätze ab, dann stehen sie hier.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 64)
    }
}

/// Zeile mit Haarlinie (Lovea `VerlaufZeile` :586). Mit `stufe` steht davor das Erholungszeichen (Lovea: Punkt 8 pt, hier mit Form) und die Stufe im VoiceOver-Text.
struct VerlaufLoveaZeile: View {
    let links: String
    let rechts: String
    var stufe: ErholungsStufe?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let stufe {
                    Image(systemName: VerlaufLovea.zeichen(stufe))
                        .font(.system(size: 8))
                        .foregroundStyle(VerlaufLovea.stufe(stufe))
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                }
                Text(links)
                Spacer(minLength: 12)
                Text(rechts).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
            }
            .font(.subheadline)
            .frame(minHeight: Abstand.tippflaeche)
            Divider()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stufe.map { "\(links), \(rechts), \(KoerperLogik.stufenWort($0))" } ?? "\(links), \(rechts)")
    }
}

/// Zwischenüberschrift (Lovea `VerlaufAbschnitt` :603).
struct VerlaufLoveaAbschnitt: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 22)
            .padding(.bottom, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Eine Muskelgruppe im Lovea-Aufbau (Lovea `VerlaufGruppe` :456): große Zahl, Einheiten, "Weitere Statistiken" einklappbar, Teile mit Erholung, Übungen.
struct VerlaufLoveaGruppe: View {
    let gruppe: MuskelGruppe
    let laeufe: [VerlaufLogik.Lauf]
    let heute: String
    var wochenSaetze: [MuskelTeil: Double] = [:]
    var erholung: [MuskelTeil: Int] = [:]
    var oeffnen: (String) -> Void = { _ in }
    /// Steht über der 0, wenn die Gruppe diese Woche keinen Satz hat (`VerlaufHinweis`).
    var ohneSaetze: [VerlaufLogik.TagOhneSaetze] = []
    var nachtragen: (() -> Void)?
    @State private var statistikOffen = false

    var body: some View {
        let z = VerlaufLogik.gruppen(laeufe, heute: heute)[gruppe] ?? VerlaufLogik.Zeitraeume()
        VStack(alignment: .leading, spacing: 0) {
            if z.woche.saetze == 0, !ohneSaetze.isEmpty {
                VerlaufHinweis(tage: ohneSaetze, nachtragen: nachtragen).padding(.bottom, 16)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(VerlaufLogik.zahl(z.woche.saetze)).font(.largeTitle.weight(.bold)).monospacedDigit()
                Text("Sätze diese Woche").font(.subheadline).foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .padding(.bottom, 8)
            VerlaufLoveaZeile(links: "Einheiten diese Woche", rechts: "\(z.woche.einheiten)×")
            VerlaufKlapp(titel: "Weitere Statistiken", offen: $statistikOffen) {
                VerlaufLoveaZeile(links: "Dieser Monat", rechts: VerlaufLogik.kurz(z.monat))
                VerlaufLoveaZeile(links: "Insgesamt", rechts: VerlaufLogik.kurz(z.gesamt))
            }
            VerlaufLoveaAbschnitt(text: "Teile diese Woche")
            teile
            VerlaufLoveaAbschnitt(text: "Übungen")
            uebungen
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var teile: some View {
        VStack(spacing: 0) {
            ForEach(MuskelTeil.allCases.filter { $0.gruppe == gruppe }, id: \.self) { t in
                let e = erholung[t] ?? 100
                VerlaufLoveaZeile(links: t.name, rechts: Self.teilText(wochenSaetze[t] ?? 0, e), stufe: MuskelLogik.stufe(e))
            }
        }
    }

    /// Lovea :512: ab 90 % Erholung nur die Sätze, sonst mit Prozent.
    nonisolated static func teilText(_ saetze: Double, _ e: Int) -> String {
        e >= 90 ? VerlaufLogik.saetzeText(saetze) : "\(VerlaufLogik.saetzeText(saetze)) · \(e) %"
    }

    @ViewBuilder
    private var uebungen: some View {
        let liste = VerlaufLogik.uebungen(gruppe, laeufe, heute: heute)
        if liste.isEmpty {
            Text("Noch keine Übung für \(gruppe.name) eingetragen. Sobald du eine trainierst, steht sie hier.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 10)
        } else {
            VStack(spacing: 0) {
                ForEach(liste) { u in
                    Button { oeffnen(u.id) } label: { zeile(u) }
                        .buttonStyle(.federnd)
                        .foregroundStyle(.primary)
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Öffnet die Übung")
                }
            }
        }
    }

    private func zeile(_ u: VerlaufLogik.UebungsVerlauf) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(u.uebung.name).font(.subheadline.weight(.semibold))
                    Text("\(u.monat)× diesen Monat · \(u.gesamt)× insgesamt").font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .frame(minHeight: Abstand.tippflaeche)
            .padding(.vertical, 6)
            Divider()
        }
        .contentShape(.rect)
    }
}

/// Eine Übung im Lovea-Aufbau (Lovea `VerlaufUebung` :545): bester e1RM groß, Monat und Gesamt, die Tage mit ihren Sätzen.
struct VerlaufLoveaUebung: View {
    let verlauf: VerlaufLogik.UebungsVerlauf

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let e = verlauf.e1rm {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(VerlaufLogik.zahl(e)) kg").font(.largeTitle.weight(.bold)).monospacedDigit()
                    Text("e1RM, geschätztes Maximum für eine Wiederholung").font(.subheadline).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .padding(.bottom, 8)
            }
            VerlaufLoveaZeile(links: "Diesen Monat", rechts: "\(verlauf.monat)×")
            VerlaufLoveaZeile(links: "Insgesamt", rechts: "\(verlauf.gesamt)×")
            VerlaufLoveaAbschnitt(text: "Tage")
            ForEach(verlauf.tage) { t in
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Datum.anzeige(t.tag)).font(.subheadline.weight(.semibold))
                        Text(t.text).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    Divider()
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
