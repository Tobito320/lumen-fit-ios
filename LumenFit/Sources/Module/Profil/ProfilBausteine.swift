import SwiftUI

/// Kleine Bausteine, die nur die Profil-Seiten brauchen (Gruppenkopf, Zeilen, Passwort-Abfrage). Alles im Lumen-Design: deckende Karten, Haarlinien.

/// Kopf einer Gruppe auf einer Seite.
struct ProfilGruppenKopf: View {
    let text: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(palette.text2)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Abstand.xs)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Eine Zeile mit Symbol, Titel, optionaler Zeile darunter und optionalem Wert rechts. Als Navigationsziel mit Pfeil (`pfeil`).
struct ProfilZeile: View {
    let symbol: String
    let titel: String
    var zeile: String?
    var wert: String?
    var pfeil = true
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.text)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(titel).font(.body).foregroundStyle(palette.text)
                if let zeile { Text(zeile).font(.footnote).foregroundStyle(palette.text2) }
            }
            Spacer(minLength: Abstand.s)
            if let wert { Text(wert).font(.body).foregroundStyle(palette.text2) }
            if pfeil {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.m)
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Auswahlzeile mit Haken (Mehrfach- oder Einzelwahl). Der Haken steht immer mit Text, VoiceOver sagt "ausgewählt".
struct ProfilAuswahlZeile: View {
    let titel: String
    let hinweis: String?
    let an: Bool
    let tippen: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            tippen()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel).font(.body.weight(.semibold)).foregroundStyle(palette.text)
                    if let hinweis { Text(hinweis).font(.footnote).foregroundStyle(palette.text2) }
                }
                Spacer()
                Image(systemName: "checkmark").fontWeight(.bold).foregroundStyle(palette.text).opacity(an ? 1 : 0).accessibilityHidden(true)
            }
            .padding(Abstand.l)
            .frame(minHeight: Abstand.tippflaeche)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(an ? .isSelected : [])
        .haptik(.auswahl, bei: an)
    }
}

/// Seitliches Wackeln bei falschem Passwort.
struct ProfilSchuettel: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}

/// Fragt ein Passwort ab und führt bei richtigem Passwort die Handlung `pruefen` aus (true, wenn alles geklappt hat). Mit `neuTitel` kommt ein zweites Feld
/// dazu (neues Passwort). Falsch: Wackeln, Haptik `.fehler`, "Passwort stimmt nicht. Versuch es nochmal." Es gibt keine Anmeldung: das Blatt erscheint
/// nur bei Handlungen, die es verlangen.
struct ProfilPasswortBlatt: View {
    let titel: String
    let erklaerung: String
    let knopf: String
    var zerstoererisch = false
    var neuTitel: String?
    let pruefen: @MainActor (_ passwort: String, _ neu: String) -> Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var passwort = ""
    @State private var neu = ""
    @State private var versuche: CGFloat = 0
    @State private var falsch = false
    @FocusState private var fokus: Bool

    private var bereit: Bool { !passwort.isEmpty && (neuTitel == nil || neu.count >= Passwort.mindestLaenge) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Abstand.l) {
                Text(erklaerung).font(.body).foregroundStyle(palette.text2)
                VStack(spacing: Abstand.m) {
                    feld("Passwort", text: $passwort).focused($fokus)
                    if let neuTitel {
                        feld(neuTitel, text: $neu)
                        if !neu.isEmpty, neu.count < Passwort.mindestLaenge {
                            Text("Mindestens \(Passwort.mindestLaenge) Zeichen.").font(.footnote).foregroundStyle(palette.text2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .modifier(ProfilSchuettel(animatableData: versuche))
                if falsch {
                    Label("Passwort stimmt nicht. Versuch es nochmal.", systemImage: "exclamationmark.circle")
                        .font(.subheadline).foregroundStyle(palette.text)
                }
                Button(role: zerstoererisch ? .destructive : nil, action: absenden) {
                    Text(knopf).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(zerstoererisch ? Color.white : palette.aufAkzent)
                .disabled(!bereit)
                Spacer()
            }
            .padding(Abstand.l)
            .lumenHintergrund()
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } } }
            .onAppear { fokus = true }
            .haptik(.fehler, bei: versuche)
        }
        .presentationDetents([.medium])
    }

    private func feld(_ titel: String, text: Binding<String>) -> some View {
        SecureField(titel, text: text)
            .textContentType(.password)
            .submitLabel(.done)
            .onSubmit(absenden)
            .padding(Abstand.m)
            .frame(minHeight: Abstand.tippflaeche)
            .background(palette.flaeche, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
            .accessibilityLabel(titel)
    }

    private func absenden() {
        guard bereit else { return }
        if pruefen(passwort, neu) {
            dismiss()
        } else {
            falsch = true
            passwort = ""
            if reduceMotion { versuche += 1 } else { withAnimation(.linear(duration: 0.4)) { versuche += 1 } }
        }
    }
}
