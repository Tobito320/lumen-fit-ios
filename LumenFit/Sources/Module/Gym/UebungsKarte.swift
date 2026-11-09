// Quelle: Lovea Health/WorkoutView.swift (Inhalt als Vorbild, neu im Lumen-Design)
import SwiftUI

/// Eine Übung im laufenden Training: Kopf mit Bild und Menü, die Satzzeilen, darunter "Satz dazu". Cardio zeigt statt der Sätze die Dauer.
/// Im Reihenfolge-Modus (`kompakt`, Knopf oben im Training) bleibt nur der Kopf mit Rahmen, zum Ziehen und Ablegen.
struct UebungsKarte: View {
    let sitzung: GymSitzung
    let index: Int
    /// Reihenfolge-Modus: die Sätze klappen zu, die Karte bekommt einen Rahmen und lässt sich ziehen; `abgelegt` meldet das Ablegen.
    var kompakt = false
    var abgelegt: () -> Void = {}
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
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
                    HStack {
                        Button { sitzung.satzDazu(index) } label: { Label("Satz dazu", systemImage: "plus").frame(minHeight: Abstand.tippflaeche) }
                        Spacer()
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, Abstand.l)
                    .frame(minHeight: Abstand.tippflaeche)
                }
            }
        }
        .overlay {
            if kompakt {
                RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous).stroke(gruen, lineWidth: 2)
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
            VStack(alignment: .leading, spacing: 2) {
                Text(u.planUebung.anzeigeName)
                    .font(.headline).foregroundStyle(palette.text).lineLimit(3)
                Text(untertitel(u)).font(.footnote).foregroundStyle(palette.text2)
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

    /// Das Menü ⋯: nur Tauschen, Auslassen, Rekorde und Verlauf, bei dazugekommenen Übungen Entfernen (09.11.2026: Notiz, Scheiben und
    /// Aufwärmen, Pause je Übung und Supersatz sind gestrichen; die Reihenfolge ändert der Knopf oben im Training).
    private func menue(_ u: WorkoutUebung) -> some View {
        Menu {
            if !u.planUebung.istCardio {
                if AusweichLogik.tauschbar(u, saetze: u.saetze) {
                    Button { blatt = .tausch } label: { Label("Gerät besetzt: tauschen", systemImage: "arrow.left.arrow.right") }
                }
                Button { sitzung.auslassen(index) } label: { Label("Auslassen", systemImage: "forward.fill") }
            }
            NavigationLink(value: Route.uebung(id: u.planUebung.uebung)) { Label("Rekorde und Verlauf", systemImage: "medal.fill") }
            if u.extra {
                Button(role: .destructive) { sitzung.uebungWeg(index) } label: { Label("Entfernen", systemImage: "trash") }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
                .foregroundStyle(palette.text)
                .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
        }
        .accessibilityLabel("Mehr zu \(u.planUebung.anzeigeName)")
        .gymTipp(.uebungMehr, tippKontext(u))
    }

    private func tippKontext(_ u: WorkoutUebung) -> GymTippKontext {
        GymTippKontext(trainingLaeuft: true, kartenIndex: index, saetze: u.saetze.count)
    }

    private func untertitel(_ u: WorkoutUebung) -> String {
        var teile = ["\(u.fertigZahl) von \(u.gesamt)"]
        if GymEigeneLogik.istEigene(u.planUebung.uebung) { teile.append("Eigene") }
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
