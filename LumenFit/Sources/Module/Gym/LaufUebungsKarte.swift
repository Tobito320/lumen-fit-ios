// Quelle: UebungsKarte.swift (gleiche Funktionen, neuer Look nach Entwurf `live`, `exCard`)
import SwiftUI

/// Eine Übung im laufenden Training (Entwurf `exCard`): Bild, Name in Lime, "2 von 3" oder "Skipped", Menü (Gerät besetzt? Ersetzen, Skip,
/// Rekorde und Verlauf, Entfernen bei dazugekommenen), Formtipp, die Tabelle Set / Letztes Mal / kg / Reps / Haken und "Set dazu".
/// Cardio zeigt statt der Tabelle die Dauer. Im Reihenfolge-Modus (`kompakt`) bleibt nur der Kopf mit Rahmen, zum Ziehen und Ablegen.
struct LaufUebungsKarte: View {
    let sitzung: GymSitzung
    let index: Int
    var kompakt = false
    /// Formtipp unter der Übung, die dran ist (nur in den ersten Wochen, `LaufHilfe.formtipp`).
    var formtipp: String? = nil
    /// Erste Wochen: unter dem zuletzt abgehakten Set fragt "Wie war das Set?" (`LaufHilfe.gefuehlFrage`).
    var gefuehl = false
    var abgelegt: () -> Void = {}
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    @Environment(\.dynamicTypeSize) private var schrift
    @State private var blatt: Blatt?

    private enum Blatt: String, Identifiable {
        case tausch, cardio
        var id: String { rawValue }
    }

    var body: some View {
        if sitzung.liste.indices.contains(index) {
            karte(sitzung.liste[index])
        }
    }

    private func karte(_ u: WorkoutUebung) -> some View {
        let gruen = GymFarbe.gruen(schema: schema, kontrast: kontrast)
        return ListenKarte {
            if kompakt {
                kopf(u, gruen)
                    .uebungZiehen(u.id) { von, auf in
                        sitzung.verschieben(von, auf: auf)
                        abgelegt()
                    }
            } else {
                kopf(u, gruen)
                if let formtipp, !u.ausgelassen { tipp(formtipp) }
                if u.planUebung.istCardio {
                    Haarlinie()
                    cardioZeile(u)
                } else if u.ausgelassen {
                    Haarlinie()
                    GymZeile(titel: String(localized: "Skipped"), untertitel: String(localized: "Zählt nicht für Volumen und Rekorde")) {
                        Button("Wieder aufnehmen") { sitzung.wiederAufnehmen(index) }.buttonStyle(.bordered).controlSize(.large)
                    }
                } else {
                    if !schrift.isAccessibilitySize { tabellenKopf }
                    ForEach(u.saetze.indices, id: \.self) { i in
                        SatzZeile(sitzung: sitzung, uebung: index, satz: i)
                        if gefuehl, !sitzung.gefuehlGegeben.contains("\(u.id)|\(i)"), LaufHilfe.gefuehlFrage(u.saetze, satz: i) {
                            gefuehlZeile(i)
                        }
                    }
                    Button { sitzung.satzDazu(index) } label: {
                        Label("Set dazu", systemImage: "plus").font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                            .background(palette.grund, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.text)
                    .padding(Abstand.m)
                }
            }
        }
        .overlay {
            if kompakt {
                RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous).stroke(palette.akzent, lineWidth: 2)
            }
        }
        .sheet(item: $blatt) { b in
            switch b {
            case .tausch: AusweichBlatt(sitzung: sitzung, index: index)
            case .cardio: CardioAbschlussBlatt(sitzung: sitzung, index: index)
            }
        }
    }

    private func kopf(_ u: WorkoutUebung, _ gruen: Color) -> some View {
        HStack(spacing: Abstand.m) {
            UebungsBild(id: u.planUebung.uebung, koerper: sitzung.katalog(u.planUebung)?.koerper)
                .frame(width: 48, height: 48)
                .opacity(u.ausgelassen ? 0.5 : 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(u.planUebung.anzeigeName)
                    .font(.headline).foregroundStyle(palette.akzent).lineLimit(3)
                Text(untertitel(u)).font(.footnote).foregroundStyle(u.fertig ? gruen : palette.text2)
                if !kompakt { CrewBestwertZeile(uebung: u.planUebung.anzeigeName) }
            }
            Spacer(minLength: Abstand.s)
            if kompakt {
                Image(systemName: "line.3.horizontal")
                    .font(.title2).foregroundStyle(palette.text2)
                    .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                    .accessibilityLabel("Ziehen, um \(u.planUebung.anzeigeName) zu verschieben")
            } else {
                menue(u)
            }
        }
        .padding(Abstand.m)
        .accessibilityElement(children: .contain)
    }

    /// Das Menü ⋯: Ersetzen (Gerät besetzt, nur im laufenden Training), Skip oder Wieder aufnehmen, Rekorde und Verlauf, bei dazugekommenen Übungen Entfernen.
    private func menue(_ u: WorkoutUebung) -> some View {
        Menu {
            if !u.planUebung.istCardio {
                if AusweichLogik.tauschbar(u, saetze: u.saetze) {
                    Button { blatt = .tausch } label: { Label("Gerät besetzt? Ersetzen", systemImage: "arrow.left.arrow.right") }
                }
                if u.ausgelassen {
                    Button { sitzung.wiederAufnehmen(index) } label: { Label("Wieder aufnehmen", systemImage: "arrow.uturn.backward") }
                } else {
                    Button { sitzung.auslassen(index) } label: { Label("Skip", systemImage: "forward.fill") }
                }
            }
            NavigationLink(value: Route.uebung(id: u.planUebung.uebung)) { Label("Rekorde und Verlauf", systemImage: "trophy.fill") }
            if u.extra {
                Button(role: .destructive) { sitzung.uebungWeg(index) } label: { Label("Entfernen", systemImage: "trash") }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.text2)
                .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                .contentShape(.rect)
        }
        .accessibilityLabel("Mehr zu \(u.planUebung.anzeigeName)")
    }

    private func untertitel(_ u: WorkoutUebung) -> String {
        if u.ausgelassen { return String(localized: "Skipped") }
        var teile = [String(localized: "\(u.fertigZahl) von \(u.gesamt)")]
        if u.planUebung.supersatz == true { teile.append(String(localized: "Supersatz")) }
        if GymEigeneLogik.istEigene(u.planUebung.uebung) { teile.append(String(localized: "Eigene")) }
        if let original = u.ersatzFuer, let name = UebungsKatalog.nachId[original]?.name { teile.append(String(localized: "statt \(name)")) }
        return teile.joined(separator: " · ")
    }

    /// Kopf der Satz-Tabelle in denselben Spalten wie `SatzZeile`.
    private var tabellenKopf: some View {
        HStack(spacing: LaufSpalten.abstand) {
            Text("Set").frame(width: LaufSpalten.nummer)
            Text("Letztes Mal").frame(maxWidth: .infinity, alignment: .leading)
            Text("kg").frame(width: LaufSpalten.kg)
            Text("Reps").frame(width: LaufSpalten.wdh)
            Image(systemName: "checkmark").frame(width: LaufSpalten.haken)
        }
        .font(.caption.weight(.semibold)).textCase(.uppercase)
        .foregroundStyle(palette.text2)
        .lineLimit(1)
        .padding(.horizontal, Abstand.m)
        .accessibilityHidden(true)
    }

    /// Formtipp (Entwurf `.tip1`): der häufigste Fehler der Übung, warm hinterlegt.
    private func tipp(_ text: String) -> some View {
        Label { Text(text).font(.subheadline).foregroundStyle(palette.text) } icon: { Image(systemName: "info.circle.fill").foregroundStyle(.orange) }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Abstand.m)
            .background(Color.orange.opacity(0.16), in: .rect(cornerRadius: Rundung.klein, style: .continuous))
            .padding(.horizontal, Abstand.m)
            .padding(.bottom, Abstand.s)
            .accessibilityLabel("Formtipp: \(text)")
    }

    /// "Wie war das Set? Leicht / Passt / Schwer" (Entwurf `fbRow`): stellt das nächste Set eine Stufe um.
    private func gefuehlZeile(_ i: Int) -> some View {
        HStack(spacing: Abstand.s) {
            Text("Wie war das Set?").font(.footnote).foregroundStyle(palette.text2)
            Spacer(minLength: 0)
            Button("Leicht") { sitzung.satzGefuehl(index, i, .leicht) }
            Button("Passt") { sitzung.satzGefuehl(index, i, .passt) }
            Button("Schwer") { sitzung.satzGefuehl(index, i, .schwer) }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .tint(palette.text)
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, Abstand.m)
        .padding(.bottom, Abstand.s)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Wie war das Set?")
    }

    private func cardioZeile(_ u: WorkoutUebung) -> some View {
        GymZeile(titel: u.cardioFertig ? String(localized: "Cardio erledigt") : String(localized: "Cardio: \(u.planUebung.minuten ?? 20) min geplant"),
                 untertitel: String(localized: "Dauer, Distanz und Puls eintragen")) {
            if u.cardioFertig {
                Button("Zurück") { sitzung.cardioZurueck(index) }.buttonStyle(.bordered).controlSize(.large)
            } else {
                Button("Eintragen") { blatt = .cardio }.buttonStyle(.lumenHauptknopf).controlSize(.large)
            }
        }
    }
}
