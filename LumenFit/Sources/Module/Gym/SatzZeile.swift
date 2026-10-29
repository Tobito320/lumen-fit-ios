// Quelle: Lovea Health/WorkoutView.swift (Inhalt als Vorbild, neu im Lumen-Design)
import SwiftUI

/// Eine Satzzeile im laufenden Training (Idee 21 bis 23): Nummer mit Satztyp, Gewicht und Wiederholungen mit Plus und Minus,
/// der Haken (startet die Pause), darunter "Letztes Mal" und die RPE-Skala. Ab Accessibility-Größe wird die Zeile zur Liste untereinander.
struct SatzZeile: View {
    let sitzung: GymSitzung
    let uebung: Int
    let satz: Int
    @Environment(\.dynamicTypeSize) private var schriftGroesse
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    var body: some View {
        if sitzung.liste.indices.contains(uebung), sitzung.liste[uebung].saetze.indices.contains(satz) {
            zeile(sitzung.liste[uebung], sitzung.liste[uebung].saetze[satz])
        }
    }

    private func zeile(_ u: WorkoutUebung, _ s: PlanSatz) -> some View {
        let gruen = GymFarbe.gruen(schema: schema, kontrast: kontrast)
        let istDran = sitzung.dran.map { $0.uebung == uebung && $0.satz == satz } ?? false
        let nummer = WorkoutLogik.nummer(u.saetze, satz)
        let letztes = LetztesMal.text(zeile: satz, in: u.saetze, vorher: u.vorher)
        return VStack(alignment: .leading, spacing: Abstand.xs) {
            if schriftGroesse.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Abstand.s) {
                    typMenue(nummer, s)
                    kgSchalter(u, s)
                    wdhSchalter(s)
                    haken(s, gruen)
                }
            } else {
                HStack(spacing: Abstand.xs) {
                    typMenue(nummer, s)
                    Spacer(minLength: 0)
                    kgSchalter(u, s)
                    wdhSchalter(s)
                    haken(s, gruen)
                }
            }
            HStack(spacing: Abstand.s) {
                if let letztes {
                    Button { sitzung.letztesMalUebernehmen(uebung, satz) } label: {
                        Text("Letztes Mal: \(letztes)").font(.footnote).foregroundStyle(palette.text2)
                            .frame(minHeight: Abstand.tippflaeche, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Übernimmt Gewicht und Wiederholungen")
                }
                Spacer(minLength: 0)
                if s.ok == true { rpeMenue(s) }
                if let zeiten = WorkoutLogik.zeitenText(sek: s.sek, pause: s.pause, satzzeit: false) {
                    Text(zeiten).font(.footnote).foregroundStyle(palette.text2).monospacedDigit()
                }
            }
        }
        .padding(.horizontal, Abstand.m)
        .padding(.vertical, Abstand.xs)
        .background(istDran ? gruen.opacity(0.12) : Color.clear)
        .overlay(alignment: .leading) {
            Rectangle().fill(gruen).frame(width: istDran ? 3 : 0)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: Teile

    /// Das Kästchen mit der Satznummer ("1", "W", "D", "F"); Tipp öffnet die Satztypen (Idee 22).
    private func typMenue(_ nummer: String, _ s: PlanSatz) -> some View {
        Menu {
            Button("Normaler Satz") { sitzung.typ(uebung, satz, "") }
            Button("Aufwärmsatz (zählt nicht)") { sitzung.typ(uebung, satz, "w") }
            Button("Dropsatz") { sitzung.typ(uebung, satz, "d") }
            Button("Bis zum Versagen") { sitzung.typ(uebung, satz, "f") }
            Divider()
            Button("Satz kopieren") { sitzung.satzKopieren(uebung, satz) }
            Button("Satz löschen", role: .destructive) { sitzung.satzLoeschen(uebung, satz) }
        } label: {
            Text(nummer)
                .font(.headline.weight(.bold)).fontDesign(.rounded).monospacedDigit()
                .foregroundStyle(palette.text)
                .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                .background(palette.grund, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Rundung.klein, style: .continuous).stroke(palette.rand, lineWidth: 1))
        }
        .accessibilityLabel("Satz \(nummer)\(s.typ == "w" ? ", Aufwärmen" : s.typ == "d" ? ", Dropsatz" : s.failure ? ", bis zum Versagen" : "")")
        .accessibilityHint("Öffnet die Satztypen")
    }

    private func kgSchalter(_ u: WorkoutUebung, _ s: PlanSatz) -> some View {
        GymSchalter(titel: "Gewicht", wert: s.kg.map { "\(TrainingLogik.kgText($0)) kg" } ?? "– kg",
                    minus: { sitzung.gewicht(uebung, satz, richtung: -1) }, plus: { sitzung.gewicht(uebung, satz, richtung: 1) })
    }

    private func wdhSchalter(_ s: PlanSatz) -> some View {
        GymSchalter(titel: "Wiederholungen", wert: "\(s.wdh)",
                    minus: { sitzung.wiederholungen(uebung, satz, richtung: -1) }, plus: { sitzung.wiederholungen(uebung, satz, richtung: 1) })
    }

    private func haken(_ s: PlanSatz, _ gruen: Color) -> some View {
        Button { sitzung.haken(uebung, satz) } label: {
            Image(systemName: s.ok == true ? "checkmark.circle.fill" : "circle")
                .font(.title)
                .foregroundStyle(s.ok == true ? gruen : palette.text2)
                .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                .contentShape(.rect)
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(s.ok == true ? "Satz erledigt" : "Satz abhaken")
        .accessibilityHint(s.ok == true ? "Nimmt den Haken zurück" : "Startet die Pause")
    }

    /// RPE aus der Skala nach RIR (Idee 22): Tipp wählt, "Ohne" nimmt ihn weg.
    private func rpeMenue(_ s: PlanSatz) -> some View {
        Menu {
            ForEach(Anstrengung.allCases, id: \.self) { stufe in
                Button("RPE \(TrainingLogik.kgText(stufe.rpe)): \(stufe.titel)") { sitzung.rpe(uebung, satz, stufe) }
            }
            Button("Ohne RPE") { sitzung.rpe(uebung, satz, nil) }
        } label: {
            Text(s.rpe.map { "RPE \(TrainingLogik.kgText($0))" } ?? "RPE")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.text)
                .padding(.horizontal, Abstand.m)
                .frame(minHeight: Abstand.tippflaeche)
        }
        .accessibilityLabel("Anstrengung")
        .accessibilityValue(s.rpe.map { Anstrengung.stufe(rpe: $0).titel } ?? "nicht gewählt")
    }
}
