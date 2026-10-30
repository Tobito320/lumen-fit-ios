// Quelle: Lovea Health/Defekt/DefektKarte.swift
import SwiftUI

/// "Gerät defekt gemeldet am ...": Hinweis oben in der Übung. Knöpfe statt Textfeldern.
struct DefektKarte: View {
    let notiz: DefektNotiz
    let heute: String
    /// Die Ausweich-Übung, nil = kein Vorschlag (Cardio, eigene Übung, schon Sätze gemacht).
    var vorschlag: Uebung? = nil
    var wiederInOrdnung: () -> Void = {}
    var ausweichen: (Uebung) -> Void = { _ in }
    var nochDefekt: () -> Void = {}
    @Environment(\.palette) private var palette

    private var veraltet: Bool { DefektLogik.veraltet(notiz, heute: heute) }

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Label("Gerät defekt gemeldet", systemImage: "exclamationmark.triangle.fill")
                .font(.headline).foregroundStyle(palette.text)
            Text("\(Datum.anzeige(notiz.gemeldetAm)) (\(DefektLogik.alterText(notiz, heute: heute)))")
                .font(.subheadline.weight(.medium)).foregroundStyle(palette.text)
            if let text = notiz.text {
                Text(text).font(.footnote).foregroundStyle(palette.text2).fixedSize(horizontal: false, vertical: true)
            }
            if veraltet {
                Text("Die Meldung ist älter als \(DefektLogik.veraltetNachTagen) Tage. Noch defekt?")
                    .font(.footnote.weight(.semibold)).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Abstand.s) {
                    knopf("Noch defekt", systemImage: "wrench.fill", nochDefekt)
                    knopf("Wieder in Ordnung", systemImage: "checkmark.circle", wiederInOrdnung)
                }
            } else {
                knopf("Wieder in Ordnung", systemImage: "checkmark.circle", wiederInOrdnung)
            }
            if let vorschlag {
                Button { ausweichen(vorschlag) } label: {
                    HStack(spacing: Abstand.s) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ausweichen: \(vorschlag.name)").font(.subheadline.weight(.semibold)).foregroundStyle(palette.text).multilineTextAlignment(.leading)
                            Text(vorschlag.geraet).font(.caption).foregroundStyle(palette.text2)
                        }
                        Spacer(minLength: 0)
                        Text("Tauschen").font(.subheadline.weight(.medium)).foregroundStyle(palette.akzent)
                    }
                    .padding(Abstand.s)
                    .frame(minHeight: Abstand.tippflaeche)
                    .background(palette.grund, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
                    .contentShape(.rect)
                }
                .buttonStyle(.federnd)
                .accessibilityLabel("Ausweichen und tauschen gegen \(vorschlag.name), \(vorschlag.geraet)")
            }
        }
        .padding(Abstand.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func knopf(_ titel: String, systemImage: String, _ aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            Label(titel, systemImage: systemImage).font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
        }
        .buttonStyle(.bordered)
    }
}

/// "Ausgewichen: statt X" mit "Zurück zu Original", solange noch kein Haken gesetzt ist.
struct AusweichKarte: View {
    let original: Uebung
    let zurueck: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: Abstand.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Getauscht, statt \(original.name)").font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                Text(original.geraet).font(.caption).foregroundStyle(palette.text2)
            }
            Spacer(minLength: 0)
            Button("Zurück zu Original", action: zurueck)
                .buttonStyle(.bordered)
                .frame(minHeight: Abstand.tippflaeche)
        }
        .padding(Abstand.m)
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Zurück zu Original", zurueck)
    }
}

/// Der Knopf "Defekt melden", wenn noch nichts gemeldet ist.
struct DefektMeldenKnopf: View {
    var aktion: () -> Void = {}

    var body: some View {
        Button(action: aktion) {
            Label("Defekt melden", systemImage: "exclamationmark.triangle")
                .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Gerät kaputt oder wackelig, mit kurzer Notiz")
    }
}

/// Kurze Notiz zur Meldung; das Studio steht als Freitext in den Studio-Einstellungen.
struct DefektMeldenBlatt: View {
    let titel: String
    let studio: String
    let melden: (String) -> Void
    @State private var text = ""
    @Environment(\.dismiss) private var schliessen

    var body: some View {
        NavigationStack {
            Form {
                Section(studio.isEmpty ? "Dein Studio" : studio) {
                    TextField("Notiz, z. B. wackelt, Seil gerissen", text: $text, axis: .vertical)
                }
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) { Button("Melden") { melden(text); schliessen() } }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Die Einhänge-Stelle in `UebungsKarte`: die Karte, wenn für dieses Studio und diese Übung ein Defekt offen ist, sonst der Knopf.
/// Dazu die Ausweich-Karte mit "Zurück zu Original". Nicht bei Cardio und nicht bei ausgelassenen Übungen.
struct DefektAbschnitt: View {
    let sitzung: GymSitzung
    let index: Int
    @State private var blatt = false
    @State private var zaehler = 0

    var body: some View {
        if sitzung.liste.indices.contains(index), let store = sitzung.defekte {
            let u = sitzung.liste[index]
            let studio = sitzung.studio?.profil.name ?? ""
            let heute = Datum.text(sitzung.umgebung.uhr())
            let schluessel = DefektLogik.schluessel(studio: studio, uebung: u.id)
            if !u.planUebung.istCardio, !u.ausgelassen {
                VStack(spacing: 0) {
                    if let original = u.ersatzFuer.flatMap({ UebungsKatalog.nachId[$0] }), AusweichLogik.tauschbar(u, saetze: u.saetze) {
                        AusweichKarte(original: original) { sitzung.ausweichen(index, zu: original); zaehler += 1 }
                        Haarlinie()
                    }
                    if let n = store.offen(studio: studio, uebung: u.id) {
                        DefektKarte(notiz: n, heute: heute,
                                    vorschlag: AusweichLogik.tauschbar(u, saetze: u.saetze) ? DefektLogik.vorschlag(fuer: u) : nil,
                                    wiederInOrdnung: { store.erledigen(studio: studio, uebung: u.id, am: heute); zaehler += 1 },
                                    ausweichen: { sitzung.ausweichen(index, zu: $0); zaehler += 1 },
                                    nochDefekt: { store.bestaetigen(studio: studio, uebung: u.id, am: heute); zaehler += 1 })
                        Haarlinie()
                    } else {
                        DefektMeldenKnopf { blatt = true }
                            .padding(.horizontal, Abstand.m).padding(.vertical, Abstand.xs)
                        Haarlinie()
                    }
                }
                .id(schluessel)
                .sheet(isPresented: $blatt) {
                    DefektMeldenBlatt(titel: u.planUebung.anzeigeName, studio: studio) {
                        store.melden(text: $0, studio: studio, uebung: u.id, am: heute)
                        zaehler += 1
                    }
                }
                .haptik(.warnung, bei: zaehler)
                .animation(Feder.schnell, value: store.offen(studio: studio, uebung: u.id))
            }
        }
    }
}
