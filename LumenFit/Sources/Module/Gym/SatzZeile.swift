// Quelle: Lovea Health/WorkoutView.swift (Inhalt als Vorbild, neu im Lumen-Design)
import SwiftUI

/// Eine Satzzeile im laufenden Training als Tabellenzeile (Entwurf `live`, Idee 21 bis 23): Nummer mit Satztyp (aktiver Satz in Lime),
/// "Letztes Mal" (Tipp übernimmt) mit Ziel oder "Neuer Rekord", Felder kg und Reps (Tipp tippt ein, Halten oder VoiceOver: mehr/weniger),
/// der Haken (startet die Pause), darunter RPE und Zeiten. Ab Accessibility-Größe wird die Zeile zur Liste untereinander.
struct SatzZeile: View {
    let sitzung: GymSitzung
    let uebung: Int
    let satz: Int
    @Environment(\.dynamicTypeSize) private var schriftGroesse
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    @AppStorage(GymAnzeige.satzzeitSchluessel) private var satzzeit = false
    @AppStorage(GymAnzeige.rpeSpalteSchluessel) private var rpeSpalte = GymAnzeige.rpeSpalteStandard
    @State private var rpeBlatt = false
    /// Zahlenfeld zum Eintippen von Gewicht oder Wiederholungen (Tipp auf das Feld).
    @State private var eingabe: Eingabe?
    @State private var eingabeText = ""
    private enum Eingabe: String, Identifiable { case kg, wdh; var id: String { rawValue } }

    var body: some View {
        if sitzung.liste.indices.contains(uebung), sitzung.liste[uebung].saetze.indices.contains(satz) {
            zeile(sitzung.liste[uebung], sitzung.liste[uebung].saetze[satz])
                .alert(eingabe == .kg ? "Gewicht in kg" : "Reps", isPresented: Binding(get: { eingabe != nil }, set: { _ in })) {
                    TextField(eingabe == .kg ? "kg" : "Reps", text: $eingabeText)
                        .keyboardType(eingabe == .kg ? .decimalPad : .numberPad)
                    Button("Abbrechen", role: .cancel) { eingabe = nil }
                    Button("Sichern") { eingabeSichern() }
                }
        }
    }

    /// Getippten Wert übernehmen: derselbe Weg wie mehr/weniger (`werteSetzen`); ungültig ändert nichts.
    private func eingabeSichern() {
        let s = sitzung.liste[uebung].saetze[satz]
        switch eingabe {
        case .kg: if let kg = LetztesMal.kgAusText(eingabeText) { sitzung.werteSetzen(uebung, satz, kg: kg, wdh: s.wdh) }
        case .wdh: if let wdh = LetztesMal.wdhAusText(eingabeText) { sitzung.werteSetzen(uebung, satz, kg: s.kg, wdh: wdh) }
        case nil: break
        }
        eingabe = nil
    }

    private func zeile(_ u: WorkoutUebung, _ s: PlanSatz) -> some View {
        let gruen = GymFarbe.gruen(schema: schema, kontrast: kontrast)
        let istDran = sitzung.dran.map { $0.uebung == uebung && $0.satz == satz } ?? false
        let nummer = WorkoutLogik.nummer(u.saetze, satz)
        let zeiten = WorkoutLogik.zeitenText(sek: s.sek, pause: s.pause, satzzeit: satzzeit)
        return VStack(alignment: .leading, spacing: 0) {
            if schriftGroesse.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Abstand.s) {
                    typMenue(nummer, s, aktiv: istDran)
                    letztesSpalte(u, s)
                    kgFeld(s).frame(maxWidth: .infinity)
                    wdhFeld(s).frame(maxWidth: .infinity)
                    haken(s, gruen)
                }
            } else {
                HStack(spacing: LaufSpalten.abstand) {
                    typMenue(nummer, s, aktiv: istDran)
                    letztesSpalte(u, s).frame(maxWidth: .infinity, alignment: .leading)
                    kgFeld(s).frame(width: LaufSpalten.kg)
                    wdhFeld(s).frame(width: LaufSpalten.wdh)
                    haken(s, gruen)
                }
            }
            if (s.ok == true && rpeSpalte) || zeiten != nil {
                HStack(spacing: Abstand.s) {
                    Spacer(minLength: LaufSpalten.nummer)
                    if let zeiten { Text(zeiten).font(.footnote).foregroundStyle(palette.text2).monospacedDigit() }
                    if s.ok == true, rpeSpalte { rpeMenue(s) }
                }
            }
        }
        .padding(.horizontal, Abstand.m)
        .padding(.vertical, Abstand.xs)
        .background(s.ok == true ? gruen.opacity(0.14) : Color.clear)
        .modifier(SatzWischen(kopieren: { sitzung.satzKopieren(uebung, satz) }, loeschen: { sitzung.satzLoeschen(uebung, satz) }))
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Satz kopieren") { sitzung.satzKopieren(uebung, satz) }
        .accessibilityAction(named: "Satz löschen") { sitzung.satzLoeschen(uebung, satz) }
    }

    // MARK: Teile

    /// Das Kästchen mit der Satznummer ("1", "W", "D", "F"), Lime beim Satz, der dran ist; Tipp öffnet die Satztypen (Idee 22).
    private func typMenue(_ nummer: String, _ s: PlanSatz, aktiv: Bool) -> some View {
        Menu {
            Button("Normales Set") { sitzung.typ(uebung, satz, "") }
            Button("Aufwärm-Set (zählt nicht)") { sitzung.typ(uebung, satz, "w") }
            Button("Dropsatz") { sitzung.typ(uebung, satz, "d") }
            Button("Bis zum Versagen") { sitzung.typ(uebung, satz, "f") }
            Divider()
            Button("Set kopieren") { sitzung.satzKopieren(uebung, satz) }
            Button("Set löschen", role: .destructive) { sitzung.satzLoeschen(uebung, satz) }
        } label: {
            Text(nummer)
                .font(.subheadline.weight(.semibold)).fontDesign(.rounded).monospacedDigit()
                .foregroundStyle(aktiv ? palette.aufAkzentFlaeche : palette.text)
                .frame(width: 30, height: 30)
                .background(aktiv ? palette.akzentFlaeche : palette.grund, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
                .frame(width: LaufSpalten.nummer, height: Abstand.tippflaeche)
                .contentShape(.rect)
        }
        .accessibilityLabel("Set \(nummer)\(s.typ == "w" ? ", Aufwärmen" : s.typ == "d" ? ", Dropsatz" : s.failure ? ", bis zum Versagen" : "")\(aktiv ? ", ist dran" : "")")
        .accessibilityHint("Öffnet die Satztypen")
    }

    /// "60 kg × 8" vom letzten Mal (Tipp übernimmt), darunter "Neuer Rekord" nach dem Haken oder das Ziel des Satz-Vorschlags.
    private func letztesSpalte(_ u: WorkoutUebung, _ s: PlanSatz) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let letztes = LetztesMal.text(zeile: satz, in: u.saetze, vorher: u.vorher) {
                Button { sitzung.letztesMalUebernehmen(uebung, satz) } label: {
                    Text(letztes).font(.footnote).foregroundStyle(palette.text2).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Letztes Mal: \(letztes)")
                .accessibilityHint("Übernimmt Gewicht und Reps")
            } else {
                Text(verbatim: "–").font(.footnote).foregroundStyle(palette.text2).accessibilityLabel("Letztes Mal: nichts")
            }
            if let rekord = sitzung.rekordLabel["\(u.id)|\(satz)"], s.ok == true {
                Label("Neuer Rekord", systemImage: "trophy.fill").font(.caption.weight(.bold)).foregroundStyle(GymFarbe.gruen(schema: schema, kontrast: kontrast))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .accessibilityLabel("Rekord: \(rekord)")
            } else {
                SatzVorschlagAnzeige(sitzung: sitzung, uebung: uebung, satz: satz)
            }
        }
    }

    /// Feld wie im Entwurf (`.inp`): Tipp öffnet das Zahlenfeld, Halten bietet mehr/weniger, VoiceOver verstellt mit Wischen.
    private func feld(_ titel: String, wert: String?, tippen: @escaping () -> Void, plus: @escaping () -> Void, minus: @escaping () -> Void) -> some View {
        Button(action: tippen) {
            Text(wert ?? "–")
                .font(.body.weight(.semibold)).fontDesign(.rounded).monospacedDigit()
                .foregroundStyle(wert == nil ? palette.text2 : palette.text)
                .lineLimit(1).minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(palette.grund, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
                .frame(minHeight: Abstand.tippflaeche)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Mehr", systemImage: "plus", action: plus)
            Button("Weniger", systemImage: "minus", action: minus)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(titel)
        .accessibilityValue(wert ?? "leer")
        .accessibilityHint("Tippen zum Eintippen")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { tippen() }
        .accessibilityAdjustableAction { richtung in
            switch richtung {
            case .increment: plus()
            case .decrement: minus()
            @unknown default: break
            }
        }
    }

    private func kgFeld(_ s: PlanSatz) -> some View {
        feld("Gewicht", wert: s.kg.map { TrainingLogik.kgText($0) },
             tippen: { eingabeText = s.kg.map { TrainingLogik.kgText($0) } ?? ""; eingabe = .kg },
             plus: { sitzung.gewicht(uebung, satz, richtung: 1) }, minus: { sitzung.gewicht(uebung, satz, richtung: -1) })
    }

    private func wdhFeld(_ s: PlanSatz) -> some View {
        feld("Reps", wert: "\(s.wdh)",
             tippen: { eingabeText = "\(s.wdh)"; eingabe = .wdh },
             plus: { sitzung.wiederholungen(uebung, satz, richtung: 1) }, minus: { sitzung.wiederholungen(uebung, satz, richtung: -1) })
    }

    private func haken(_ s: PlanSatz, _ gruen: Color) -> some View {
        Button { sitzung.haken(uebung, satz) } label: {
            Image(systemName: "checkmark")
                .font(.body.weight(.bold))
                .foregroundStyle(s.ok == true ? Color.white : palette.text2)
                .frame(width: 32, height: 32)
                .background(s.ok == true ? gruen : palette.grund, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
                .frame(width: LaufSpalten.haken, height: Abstand.tippflaeche)
                .contentShape(.rect)
        }
        .buttonStyle(.federnd)
        .accessibilityLabel(s.ok == true ? "Set erledigt" : "Set abhaken")
        .accessibilityHint(s.ok == true ? "Nimmt den Haken zurück" : "Startet die Pause")
    }

    /// RPE aus der Skala nach RIR (Idee 22): Tipp öffnet das Blatt mit Farbpunkten und Erklärung.
    private func rpeMenue(_ s: PlanSatz) -> some View {
        Button { rpeBlatt = true } label: {
            HStack(spacing: Abstand.xs) {
                if let rpe = s.rpe { Circle().fill(AnstrengungFarbe.farbe(Anstrengung.stufe(rpe: rpe))).frame(width: 10, height: 10) }
                Text(s.rpe.map { "RPE \(TrainingLogik.kgText($0))" } ?? "RPE")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.text)
            }
            .padding(.horizontal, Abstand.m)
            .frame(minHeight: Abstand.tippflaeche)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Anstrengung")
        .accessibilityValue(s.rpe.map { Anstrengung.stufe(rpe: $0).titel } ?? "nicht gewählt")
        .sheet(isPresented: $rpeBlatt) {
            AnstrengungBlatt(aktuell: s.rpe) { sitzung.rpe(uebung, satz, $0) }
        }
    }
}

/// Wischen auf der Satzzeile: nach links löschen, nach rechts kopieren (die Zeilen liegen nicht in einer Liste, daher eigene Geste).
/// Nur deutlich waagerechte Züge zählen, damit das Scrollen nicht stört. Beides lässt sich über "Rückgängig" zurücknehmen.
struct SatzWischen: ViewModifier {
    let kopieren: () -> Void
    let loeschen: () -> Void

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 40).onEnded { wert in
                let dx = wert.translation.width, dy = wert.translation.height
                guard abs(dx) > 90, abs(dx) > 2.5 * abs(dy) else { return }
                if dx < 0 { loeschen() } else { kopieren() }
            }
        )
    }
}
