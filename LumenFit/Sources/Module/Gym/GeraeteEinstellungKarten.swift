// Quelle: Lovea Health/Einstellung/EinstellKarte.swift, EinstellAbschnitt.swift
import SwiftUI

/// "So geht's": Ablauf, Einstellen und typischer Fehler zu einer Übung. Zugeklappt, Tipp klappt auf (.snappy).
struct SoGehtsKarte: View {
    let hinweis: EinstellHinweis
    @State private var offen = false
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var ruhig

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Button { withAnimation(ruhig ? nil : .snappy) { offen.toggle() } } label: {
                HStack {
                    Label("So geht's", systemImage: "questionmark.circle.fill").font(.headline).foregroundStyle(palette.text)
                    Spacer(minLength: 0)
                    Image(systemName: offen ? "chevron.up" : "chevron.down").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2)
                }
                .frame(minHeight: Abstand.tippflaeche)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityValue(offen ? "aufgeklappt" : "zugeklappt")
            if offen {
                block("Ablauf", hinweis.anleitung)
                block("Einstellen", hinweis.einstellung)
                block("Typischer Fehler", hinweis.fehler)
                if hinweis.unsicher {
                    Label("Unsicher, selbst prüfen", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold)).foregroundStyle(palette.text2)
                }
            }
        }
        .padding(.horizontal, Abstand.m)
        .padding(.vertical, Abstand.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func block(_ titel: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.caption.weight(.semibold)).foregroundStyle(palette.text2)
            Text(text).font(.subheadline).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true)
        }
        .transition(.opacity)
    }
}

/// "Meine Einstellung": was beim letzten Mal an diesem Gerät eingestellt war. Tipp ändert.
struct MeineEinstellungKarte: View {
    let werte: GeraeteWerte?
    let studio: String
    var aendern: () -> Void = {}
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: aendern) {
            VStack(alignment: .leading, spacing: Abstand.xs) {
                HStack {
                    Label("Meine Einstellung", systemImage: "slider.horizontal.3").font(.headline).foregroundStyle(palette.text)
                    Spacer(minLength: 0)
                    Text(werte == nil ? "Eintragen" : "Ändern").font(.subheadline.weight(.medium)).foregroundStyle(palette.akzent)
                }
                if !studio.isEmpty { Text(studio).font(.caption).foregroundStyle(palette.text2) }
                if let w = werte, !w.istLeer {
                    HStack(spacing: Abstand.xs) {
                        chip("Bank", w.stufe)
                        chip("Sitz", w.sitz)
                        chip("Polster", w.polster)
                    }
                    if let n = w.notiz { Text(n).font(.subheadline).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true) }
                } else {
                    Text("Noch nichts gespeichert. Stell das Gerät ein und trag es hier ein, beim nächsten Mal steht es da.")
                        .font(.subheadline).foregroundStyle(palette.text2).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, Abstand.m)
            .padding(.vertical, Abstand.xs)
            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Öffnet die Eingabe")
    }

    @ViewBuilder private func chip(_ titel: String, _ wert: String?) -> some View {
        if let wert {
            HStack(spacing: 4) {
                Text(titel).font(.caption).foregroundStyle(palette.text2)
                Text(wert).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
            }
            .padding(.horizontal, Abstand.s).padding(.vertical, 5)
            .background(Capsule().fill(palette.grund))
            .overlay(Capsule().stroke(palette.rand, lineWidth: 1))
            .accessibilityElement(children: .combine)
        }
    }
}

/// Eingabe: Bankstufe, Sitzhöhe, Polster (kurze Texte, zum Beispiel "4") und eine freie Notiz.
struct GeraeteEinstellBlatt: View {
    let titel: String
    let studio: String
    let speichern: (GeraeteWerte) -> Void
    @State private var stufe: String
    @State private var sitz: String
    @State private var polster: String
    @State private var notiz: String
    @State private var gesichert = 0
    @Environment(\.dismiss) private var schliessen

    init(titel: String, studio: String, start: GeraeteWerte, speichern: @escaping (GeraeteWerte) -> Void) {
        self.titel = titel
        self.studio = studio
        self.speichern = speichern
        _stufe = State(initialValue: start.stufe ?? "")
        _sitz = State(initialValue: start.sitz ?? "")
        _polster = State(initialValue: start.polster ?? "")
        _notiz = State(initialValue: start.notiz ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(studio.isEmpty ? "Dieses Gerät" : studio) {
                    TextField("Bankstufe", text: $stufe)
                    TextField("Sitzhöhe", text: $sitz)
                    TextField("Polster", text: $polster)
                    TextField("Notiz", text: $notiz, axis: .vertical)
                }
            }
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        speichern(GeraeteWerte(stufe: stufe, sitz: sitz, polster: polster, notiz: notiz))
                        gesichert += 1
                        schliessen()
                    }
                }
            }
            .haptik(.erfolg, bei: gesichert)
        }
        .presentationDetents([.medium])
    }
}

/// Die Einhänge-Stelle in `UebungsKarte`: "So geht's" (wenn es einen Hinweis gibt) und "Meine Einstellung" mit Blatt zum Ändern.
struct GeraeteAbschnitt: View {
    let sitzung: GymSitzung
    let index: Int
    @State private var blatt = false

    var body: some View {
        if sitzung.liste.indices.contains(index), let store = sitzung.geraete, !sitzung.liste[index].planUebung.istCardio, !sitzung.liste[index].ausgelassen {
            let u = sitzung.liste[index].planUebung
            let studio = sitzung.studio?.profil.name ?? ""
            let schluessel = GeraeteEinstellungDatei.uebungsSchluessel(u)
            VStack(spacing: 0) {
                if let h = EinstellHinweise.finden(u) {
                    SoGehtsKarte(hinweis: h)
                    Haarlinie()
                }
                MeineEinstellungKarte(werte: store.werte(studio: studio, uebung: schluessel), studio: studio) { blatt = true }
                Haarlinie()
            }
            .sheet(isPresented: $blatt) {
                GeraeteEinstellBlatt(titel: u.anzeigeName, studio: studio, start: store.werte(studio: studio, uebung: schluessel) ?? GeraeteWerte()) {
                    store.setzen($0, studio: studio, uebung: schluessel)
                }
            }
        }
    }
}
