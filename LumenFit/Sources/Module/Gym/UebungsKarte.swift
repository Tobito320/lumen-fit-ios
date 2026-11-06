// Quelle: Lovea Health/WorkoutView.swift (Inhalt als Vorbild, neu im Lumen-Design)
import SwiftUI

/// Eine Übung im laufenden Training: Kopf mit Bild und Menü, die Satzzeilen, darunter "Satz dazu". Cardio zeigt statt der Sätze die Dauer.
struct UebungsKarte: View {
    let sitzung: GymSitzung
    let index: Int
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    @State private var blatt: Blatt?

    private enum Blatt: String, Identifiable {
        case notiz, pause, rechner, tausch, cardio, reihenfolge
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
            kopf(u, gruen).uebungZiehen(u.id) { von, auf in sitzung.verschieben(von, auf: auf) }
            Haarlinie()
            if u.planUebung.istCardio {
                cardioZeile(u, gruen)
            } else if u.ausgelassen {
                GymZeile(titel: "Ausgelassen", untertitel: "Zählt nicht für Volumen und Rekorde") {
                    Button("Wieder dazu") { sitzung.wiederAufnehmen(index) }.buttonStyle(.bordered).controlSize(.large)
                }
            } else {
                GymTippZeile(art: .satzWischen, kontext: tippKontext(u))
                ForEach(u.saetze.indices, id: \.self) { i in
                    SatzZeile(sitzung: sitzung, uebung: index, satz: i)
                    if i < u.saetze.count - 1 { Haarlinie() }
                }
                Haarlinie()
                // Der Rechner steht im Menü ⋯ ("Scheiben und Aufwärmen"), W-003: ein Knopf je Karte weniger.
                HStack {
                    Button { sitzung.satzDazu(index) } label: { Label("Satz dazu", systemImage: "plus").frame(minHeight: Abstand.tippflaeche) }
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, Abstand.l)
                .frame(minHeight: Abstand.tippflaeche)
            }
        }
        .sheet(item: $blatt) { b in
            switch b {
            case .notiz: NotizBlatt(sitzung: sitzung, index: index)
            case .pause: PauseWahlBlatt(sitzung: sitzung, index: index)
            case .rechner: RechnerBlatt(sitzung: sitzung, index: index)
            case .tausch: AusweichBlatt(sitzung: sitzung, index: index)
            case .cardio: CardioAbschlussBlatt(sitzung: sitzung, index: index)
            case .reihenfolge: ReihenfolgeBlatt(sitzung: sitzung)
            }
        }
    }

    private func kopf(_ u: WorkoutUebung, _ gruen: Color) -> some View {
        HStack(spacing: Abstand.m) {
            UebungsBild(id: u.planUebung.uebung, koerper: sitzung.katalog(u.planUebung)?.koerper)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(u.planUebung.anzeigeName)
                    .font(.headline).foregroundStyle(palette.text).lineLimit(3)
                Text(untertitel(u)).font(.footnote).foregroundStyle(palette.text2)
                if let notiz = u.planUebung.notiz {
                    Label(notiz, systemImage: "note.text").font(.footnote).foregroundStyle(palette.text2)
                }
            }
            Spacer(minLength: Abstand.s)
            Menu {
                // Oben nur das Nötigste; Notiz, Scheiben, Reihenfolge, Pause, Supersatz, Rekorde und Entfernen eine Ebene tiefer.
                if !u.planUebung.istCardio {
                    if AusweichLogik.tauschbar(u, saetze: u.saetze) {
                        Button { blatt = .tausch } label: { Label("Gerät besetzt: tauschen", systemImage: "arrow.left.arrow.right") }
                    }
                    Button { sitzung.auslassen(index) } label: { Label("Auslassen", systemImage: "forward.fill") }
                }
                Menu {
                    Button { blatt = .notiz } label: { Label("Notiz", systemImage: "note.text") }
                    if !u.planUebung.istCardio {
                        Button { blatt = .rechner } label: { Label("Scheiben und Aufwärmen", systemImage: "scalemass") }
                    }
                    Button { blatt = .reihenfolge } label: { Label("Reihenfolge ändern", systemImage: "arrow.up.arrow.down") }
                    Button { blatt = .pause } label: { Label("Pause dieser Übung", systemImage: "timer") }
                    if !u.planUebung.istCardio {
                        Button { sitzung.supersatz(index, an: u.planUebung.supersatz != true) } label: {
                            Label(u.planUebung.supersatz == true ? "Supersatz lösen" : "Supersatz mit der nächsten", systemImage: "link")
                        }
                    }
                    NavigationLink(value: Route.uebung(id: u.planUebung.uebung)) { Label("Rekorde und Verlauf", systemImage: "medal.fill") }
                    if u.extra {
                        Button(role: .destructive) { sitzung.uebungWeg(index) } label: { Label("Entfernen", systemImage: "trash") }
                    }
                } label: { Label("Mehr", systemImage: "ellipsis") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundStyle(palette.text)
                    .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
            }
            .accessibilityLabel("Mehr zu \(u.planUebung.anzeigeName)")
            .gymTipp(.uebungMehr, tippKontext(u))
        }
        .padding(Abstand.m)
        .accessibilityElement(children: .contain)
    }

    private func tippKontext(_ u: WorkoutUebung) -> GymTippKontext {
        GymTippKontext(trainingLaeuft: true, kartenIndex: index, saetze: u.saetze.count)
    }

    private func untertitel(_ u: WorkoutUebung) -> String {
        var teile = ["\(u.fertigZahl) von \(u.gesamt)"]
        if GymEigeneLogik.istEigene(u.planUebung.uebung) { teile.append("Eigene") }
        if u.planUebung.supersatz == true { teile.append("Supersatz") }
        if let p = u.planUebung.pause { teile.append("Pause \(WorkoutLogik.pauseText(p))") }
        if let original = u.ersatzFuer, let name = UebungsKatalog.nachId[original]?.name { teile.append("statt \(name)") }
        return teile.joined(separator: " · ")
    }

    private func cardioZeile(_ u: WorkoutUebung, _ gruen: Color) -> some View {
        GymZeile(titel: u.cardioFertig ? "Cardio erledigt" : "Cardio: \(u.planUebung.minuten ?? 20) min geplant", untertitel: "Dauer, Distanz und Puls eintragen") {
            if u.cardioFertig {
                Button("Zurück") { sitzung.cardioZurueck(index) }.buttonStyle(.bordered).controlSize(.large)
            } else {
                Button("Eintragen") { blatt = .cardio }.buttonStyle(.lumenHauptknopf).controlSize(.large)
            }
        }
    }
}

/// Notiz je Übung (Idee 28): bleibt an der Übung und steht beim nächsten Training wieder da.
struct NotizBlatt: View {
    let sitzung: GymSitzung
    let index: Int
    @State private var text = ""
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Form {
                Section("Notiz zur Übung") {
                    TextField("Zum Beispiel: Sitz auf Stufe 4", text: $text, axis: .vertical).lineLimit(2...6)
                }
                Section { Text("Die Notiz bleibt an dieser Übung und steht beim nächsten Training wieder da.").font(.footnote) }
            }
            .navigationTitle("Notiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { sitzung.notiz(index, text); schliessen() } }
            }
            .onAppear { text = sitzung.liste.indices.contains(index) ? sitzung.liste[index].planUebung.notiz ?? "" : "" }
        }
        .presentationDetents([.medium])
    }
}

/// Eigene Pause je Übung (Idee 23): Standard, aus oder eine der festen Zeiten.
struct PauseWahlBlatt: View {
    let sitzung: GymSitzung
    let index: Int
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            List {
                Button("Standard (\(WorkoutLogik.pauseText(PauseLogik.standard)))") { sitzung.pauseZiel(index, nil); schliessen() }
                ForEach(WorkoutLogik.pausen, id: \.self) { sekunden in
                    Button(WorkoutLogik.pauseText(sekunden)) { sitzung.pauseZiel(index, sekunden); schliessen() }
                }
            }
            .navigationTitle("Pause dieser Übung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } } }
        }
        .presentationDetents([.medium])
    }
}

/// "Gerät besetzt": eine oder zwei Alternativen für denselben Muskel (Idee 26, `AusweichLogik`).
struct AusweichBlatt: View {
    let sitzung: GymSitzung
    let index: Int
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            List {
                if sitzung.liste.indices.contains(index), let original = sitzung.liste[index].planUebung.katalog {
                    let alternativen = AusweichLogik.alternativen(fuer: original)
                    if alternativen.isEmpty {
                        Text("Keine passende Alternative gefunden.")
                    }
                    ForEach(alternativen) { alt in
                        Button {
                            sitzung.ausweichen(index, zu: alt)
                            schliessen()
                        } label: {
                            HStack(spacing: Abstand.m) {
                                UebungsBild(id: alt.id, koerper: alt.koerper).frame(width: 48, height: 48)
                                VStack(alignment: .leading) {
                                    Text(alt.name).font(.body.weight(.medium))
                                    Text("\(alt.muskel) · \(alt.geraet)").font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                            .frame(minHeight: Abstand.tippflaeche)
                        }
                    }
                }
            }
            .navigationTitle("Gerät besetzt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } } }
        }
    }
}

/// Reihenfolge der Übungen im Training ändern: kompakte Liste, nur Namen, Griffe immer sichtbar. "Fertig" speichert (`GymSitzung.umordnen`).
struct ReihenfolgeBlatt: View {
    let sitzung: GymSitzung
    private struct Eintrag: Identifiable { let id: String; let name: String }
    @State private var eintraege: [Eintrag] = []
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            List {
                ForEach(eintraege) { Text($0.name) }
                    .onMove { eintraege.move(fromOffsets: $0, toOffset: $1) }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reihenfolge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { sitzung.umordnen(eintraege.map(\.id)); schliessen() } }
            }
            .onAppear { eintraege = sitzung.liste.map { Eintrag(id: $0.id, name: $0.planUebung.anzeigeName) } }
        }
    }
}
