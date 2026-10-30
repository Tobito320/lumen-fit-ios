// Quelle: Lovea Health/Heute/SchreibZeile.swift
import SwiftUI

/// "Schreib, was war": eine Zeile für einen Satz wie "23 Uhr ins Bett, 6 aufgestanden, 78,4 kg, 2 Gläser Wasser".
/// Erst feste Muster (`FreitextLogik`), sonst das Sprachmodell auf dem Gerät (`FreitextKI`, nur wenn Apple Intelligence da ist).
/// Das Erkannte steht als Chips da, zum Abwählen; "Sichern" speichert, danach geht "Rückgängig".
struct SchreibKarte: View {
    let modell: HeuteModell
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus
    @FocusState private var fokus: Bool
    @State private var text = ""
    @State private var chips: [FreitextChip] = []
    @State private var abgewaehlt: Set<Int> = []
    @State private var liest = false
    @State private var nichtsErkannt = false
    @State private var rueckgaengig: Rueckgang?
    @State private var gesichert = 0
    @State private var zurueck = 0
    @State private var gesendet = 0
    @State private var gewaehlt = 0

    /// Was vor dem Sichern war, damit "Rückgängig" es wiederherstellt.
    private struct Rueckgang {
        let tag: String
        let werte: FreitextChips.Werte
        let gewicht: Bool
        let schlaf: SchlafHandD?
        let schlafVorher: SchlafNacht?
        let zeilen: [String]
    }

    private var anim: Animation? { bewegungAus ? nil : Feder.schnell }
    private var kannSenden: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !liest }
    private var anzahlGewaehlt: Int { chips.filter { !abgewaehlt.contains($0.id) }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            zeile
            if !chips.isEmpty { erkannt }
            if nichtsErkannt { Text(FreitextChips.nichts).font(.footnote).foregroundStyle(palette.text2) }
            if let rueckgaengig { gespeichert(rueckgaengig) }
        }
        .animation(anim, value: chips)
        .animation(anim, value: rueckgaengig != nil)
        .animation(anim, value: nichtsErkannt)
        .haptik(.auswahl, bei: gesendet)
        .haptik(.erfolg, bei: gesichert)
        .haptik(.stopp, bei: zurueck)
        .haptik(.auswahl, bei: gewaehlt)
    }

    private var zeile: some View {
        HStack(spacing: Abstand.s) {
            Image(systemName: "square.and.pencil").font(.body.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
            TextField("Schreib, was war", text: $text, axis: .vertical)
                .lineLimit(1...3)
                .focused($fokus)
                .submitLabel(.send)
                .onSubmit { Task { await lesen() } }
                .accessibilityLabel("Schreib, was war")
                .accessibilityHint("Zum Beispiel Schlafzeit, Gewicht, Wasser oder Creatin")
            if liest {
                ProgressView().frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
            } else if kannSenden {
                Button { Task { await lesen() } } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundStyle(palette.akzent)
                        .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                }
                .buttonStyle(.federnd)
                .accessibilityLabel("Senden")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.leading, Abstand.l)
        .padding(.trailing, Abstand.xs)
        .frame(minHeight: 48)
        .lumenKartenFlaeche()
        .animation(anim, value: kannSenden)
    }

    private var erkannt: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Stimmt das?").font(.subheadline.weight(.semibold)).foregroundStyle(palette.text2)
            ForEach(chips) { chip in
                let an = !abgewaehlt.contains(chip.id)
                Button {
                    if an { abgewaehlt.insert(chip.id) } else { abgewaehlt.remove(chip.id) }
                    gewaehlt += 1
                } label: {
                    HStack(spacing: Abstand.s) {
                        Image(systemName: chip.symbol).frame(width: 24).accessibilityHidden(true)
                        Text(chip.text).font(.subheadline).multilineTextAlignment(.leading)
                        Spacer(minLength: Abstand.xs)
                        Image(systemName: an ? "checkmark.circle.fill" : "circle").accessibilityHidden(true)
                    }
                    .foregroundStyle(an ? palette.text : palette.text2)
                    .padding(.horizontal, Abstand.m)
                    .frame(minHeight: Abstand.tippflaeche)
                    .background(palette.haar, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
                }
                .buttonStyle(.federnd)
                .accessibilityLabel(chip.text)
                .accessibilityValue(an ? "ausgewählt" : "nicht ausgewählt")
                .accessibilityAddTraits(.isToggle)
            }
            HStack(spacing: Abstand.m) {
                Button("Sichern") { sichern() }
                    .buttonStyle(.borderedProminent).tint(palette.akzent).foregroundStyle(palette.aufAkzent)
                    .disabled(anzahlGewaehlt == 0).frame(minHeight: Abstand.tippflaeche)
                Button("Verwerfen") { verwerfen() }.buttonStyle(.bordered).tint(palette.text2).frame(minHeight: Abstand.tippflaeche)
            }
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenKartenFlaeche()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func gespeichert(_ r: Rueckgang) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Label("Gespeichert", systemImage: "checkmark.circle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
            ForEach(r.zeilen, id: \.self) { Text($0).font(.footnote).foregroundStyle(palette.text2) }
            Button("Rückgängig", systemImage: "arrow.uturn.backward") { zuruecknehmen(r) }.frame(minHeight: Abstand.tippflaeche)
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenKartenFlaeche()
        .accessibilityElement(children: .contain)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Handeln

    private func lesen() async {
        let eingabe = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !eingabe.isEmpty, !liest else { return }
        gesendet += 1
        fokus = false
        liest = true
        rueckgaengig = nil
        nichtsErkannt = false
        let tag = Datum.text(umgebung.uhr())
        var liste = FreitextLogik.lesen(eingabe, tag: tag)
        if liste.isEmpty { liste = await FreitextKI.lesen(eingabe, tag: tag) }
        liest = false
        abgewaehlt = []
        chips = FreitextChips.chips(liste)
        nichtsErkannt = liste.isEmpty
        if !liste.isEmpty { AccessibilityNotification.Announcement("\(liste.count) erkannt. Stimmt das?").post() }
    }

    private func verwerfen() {
        chips = []
        abgewaehlt = []
        zurueck += 1
    }

    private func sichern() {
        let liste = chips.filter { !abgewaehlt.contains($0.id) }
        guard !liste.isEmpty, let daten = umgebung.daten else { return }
        let tag = Datum.text(umgebung.uhr())
        let vorher = FreitextChips.Werte(gewicht: daten.habits.wert(Habit.gewicht.id, tag), wasser: daten.habits.wert(Habit.wasser.id, tag),
                                         creatin: daten.habits.wert(Habit.creatin.id, tag))
        let nachher = FreitextChips.nachher(liste.map(\.eintrag), vorher: vorher)
        let schlaf = liste.compactMap { chip -> SchlafHandD? in
            guard case .schlaf(let bett, let auf) = chip.eintrag else { return nil }
            let d = SchlafHandD(tag: tag, bett: bett, auf: auf)
            return SchlafHandLogik.nacht(d) == nil ? nil : d
        }.last
        let schlafVorher = SchlafDaten.eingetragen(umgebung)[tag]
        if nachher.gewicht != vorher.gewicht { Task { _ = await modell.speichereGewicht(zehntel: nachher.gewicht) } }
        if nachher.wasser != vorher.wasser { daten.habits.setze(Habit.wasser.id, datum: tag, wert: nachher.wasser) }
        if nachher.creatin != vorher.creatin { daten.habits.setze(Habit.creatin.id, datum: tag, wert: nachher.creatin) }
        if let schlaf {
            daten.raum.senden(SchlafHandLogik.art, schlaf)
            umgebung.ereignisse.senden(.healthAktualisiert)
        }
        modell.berechne()
        rueckgaengig = Rueckgang(tag: tag, werte: vorher, gewicht: nachher.gewicht != vorher.gewicht, schlaf: schlaf, schlafVorher: schlafVorher,
                                 zeilen: liste.map { $0.text })
        chips = []
        abgewaehlt = []
        text = ""
        gesichert += 1
    }

    private func zuruecknehmen(_ r: Rueckgang) {
        guard let daten = umgebung.daten else { return }
        daten.habits.setze(Habit.wasser.id, datum: r.tag, wert: r.werte.wasser)
        daten.habits.setze(Habit.creatin.id, datum: r.tag, wert: r.werte.creatin)
        if r.gewicht { daten.habits.setze(Habit.gewicht.id, datum: r.tag, wert: r.werte.gewicht) }
        if r.schlaf != nil {
            // Ein früherer Eintrag kommt zurück, sonst gilt wieder die automatische Erkennung.
            let d = r.schlafVorher.map { SchlafHandD(tag: r.tag, bett: $0.von, auf: $0.bis) }
                ?? SchlafHandD(tag: r.tag, bett: Datum.datum(r.tag), auf: Datum.datum(r.tag), geloescht: true)
            daten.raum.senden(SchlafHandLogik.art, d)
            umgebung.ereignisse.senden(.healthAktualisiert)
        }
        modell.berechne()
        rueckgaengig = nil
        zurueck += 1
        AccessibilityNotification.Announcement("Rückgängig gemacht").post()
    }
}
