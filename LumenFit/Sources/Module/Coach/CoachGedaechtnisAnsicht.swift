import SwiftUI

/// Das Gedächtnis des Coachs (Idee 64): Ziele, Verletzungen und Vorlieben, lokal, sichtbar, änderbar und löschbar.
struct CoachGedaechtnisAnsicht: View {
    let modell: CoachModell
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var reduceMotion
    @State private var neu = ""
    @State private var zuAendern: String?
    @State private var aenderungsText = ""
    @State private var geloescht: String?
    @FocusState private var fokus: Bool

    var body: some View {
        let eintraege = modell.gedaechtnis?.eintraege ?? []
        List {
            Section {
                Text("Dein Coach merkt sich nur, was hier steht: Ziele, Verletzungen, Vorlieben. Es bleibt auf deinem iPhone, und du kannst jeden Eintrag ändern oder löschen. Nach links wischen löscht.")
                    .font(.subheadline).foregroundStyle(palette.text2)
                eingabe(eintraege)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            Section {
                if eintraege.isEmpty {
                    LeerZustand(stimmung: .bereit, satz: "Noch nichts gemerkt. Schreib oben, was dein Coach wissen soll, oder sag im Chat: Merk dir, dass ...")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(eintraege, id: \.self) { eintrag in
                        zeile(eintrag)
                            .listRowBackground(palette.flaeche)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("Löschen", systemImage: "trash", role: .destructive) { loesche(eintrag) }
                                Button("Ändern", systemImage: "pencil") { aenderungsText = eintrag; zuAendern = eintrag }.tint(palette.text2)
                            }
                    }
                }
            } footer: {
                Text("\(eintraege.count) von \(CoachGedaechtnis.maxEintraege) Einträgen")
                    .font(.footnote).foregroundStyle(palette.text2)
                    .accessibilityLabel("\(eintraege.count) von \(CoachGedaechtnis.maxEintraege) Einträgen gemerkt")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Gedächtnis")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .alert("Eintrag ändern", isPresented: Binding(get: { zuAendern != nil }, set: { if !$0 { zuAendern = nil } })) {
            TextField("Text", text: $aenderungsText)
            Button("Sichern") {
                if let alt = zuAendern { modell.gedaechtnis?.aendern(alt, zu: aenderungsText) }
                zuAendern = nil
            }
            Button("Abbrechen", role: .cancel) { zuAendern = nil }
        }
        .safeAreaInset(edge: .bottom) {
            if let text = geloescht {
                rueckgaengigLeiste(text)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : Feder.weich, value: geloescht)
        .haptik(.warnung, bei: geloescht)
    }

    private func eingabe(_ eintraege: [String]) -> some View {
        let gueltig = CoachGedaechtnisRegeln.hinzufuegen(neu, bestehend: eintraege) != nil
        return HStack(spacing: Abstand.s) {
            TextField("Neu merken, zum Beispiel: Linkes Knie vorsichtig belasten", text: $neu, axis: .vertical)
                .lineLimit(1...3)
                .focused($fokus)
                .submitLabel(.done)
                .onSubmit { hinzufuegen() }
                .padding(.horizontal, Abstand.l)
                .padding(.vertical, Abstand.m)
                .frame(minHeight: Abstand.tippflaeche)
                .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous).stroke(palette.haar, lineWidth: 1))
            Button { hinzufuegen() } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(palette.aufAkzent)
                    .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                    .background(palette.akzent, in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(!gueltig)
            .opacity(gueltig ? 1 : 0.35)
            .accessibilityLabel("Merken")
        }
    }

    private func zeile(_ eintrag: String) -> some View {
        HStack(spacing: Abstand.m) {
            Text(eintrag).font(.body).foregroundStyle(palette.text).frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                Button("Ändern", systemImage: "pencil") { aenderungsText = eintrag; zuAendern = eintrag }
                Button("Löschen", systemImage: "trash", role: .destructive) { loesche(eintrag) }
            } label: {
                Image(systemName: "ellipsis").frame(minWidth: Abstand.tippflaeche, minHeight: Abstand.tippflaeche)
            }
            .accessibilityLabel("Eintrag bearbeiten: \(eintrag)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Löschen") { loesche(eintrag) }
    }

    private func rueckgaengigLeiste(_ text: String) -> some View {
        HStack(spacing: Abstand.m) {
            Text("Gelöscht: \(text)").font(.subheadline).lineLimit(1).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.s)
            Button("Rückgängig") {
                modell.gedaechtnis?.wiederherstellen(text)
                geloescht = nil
            }
            .font(.subheadline.weight(.semibold))
            .frame(minHeight: Abstand.tippflaeche)
        }
        .padding(.horizontal, Abstand.l)
        .glassEffect(.regular, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        .padding(.horizontal, Abstand.l)
    }

    private func hinzufuegen() {
        guard modell.gedaechtnis?.hinzufuegen(neu) != nil else { return }
        neu = ""
    }

    private func loesche(_ eintrag: String) {
        modell.gedaechtnis?.loeschen(eintrag)
        geloescht = eintrag
    }
}
