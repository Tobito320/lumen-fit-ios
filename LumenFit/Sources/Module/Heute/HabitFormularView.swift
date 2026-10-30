// Quelle: Lovea Health/HabitFormular.swift
import SwiftUI

/// Gewohnheit anlegen oder bearbeiten: Name, 40 Symbole, 8 Farben, Häufigkeit (jeden Tag, pro Woche, feste Tage), Abhaken oder Zählen mit Tagesziel.
/// Mit `bestehend` ändert es dieselbe Gewohnheit (`habit.aendern`, gleiche id). "Für beide" gibt es nicht: Partnerdaten kommen mit dem Austausch (Paket Verbinden).
struct HabitFormularView: View {
    var bestehend: Habit?

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var symbol: String
    @State private var farbe: HabitFarbe
    @State private var art: HaeufigkeitArt
    @State private var proWoche: Int
    @State private var tage: Set<Int>
    @State private var zaehlen: Bool
    @State private var tagesziel: Int
    @State private var gesichert = 0

    init(bestehend: Habit? = nil) {
        self.bestehend = bestehend
        let h = bestehend
        _name = State(initialValue: h?.name ?? "")
        _symbol = State(initialValue: h?.symbol ?? HabitSymbole.alle[0])
        _farbe = State(initialValue: h.map { HabitFarbe.von($0.farbe) } ?? .amber)
        _zaehlen = State(initialValue: h?.zaehlen ?? false)
        _tagesziel = State(initialValue: h?.tagesziel ?? 3)
        switch h?.haeufigkeit ?? .taeglich {
        case .taeglich:
            _art = State(initialValue: .taeglich); _proWoche = State(initialValue: 3); _tage = State(initialValue: [1, 3, 5])
        case .proWoche(let n):
            _art = State(initialValue: .proWoche); _proWoche = State(initialValue: n); _tage = State(initialValue: [1, 3, 5])
        case .tage(let t):
            _art = State(initialValue: .tage); _proWoche = State(initialValue: 3); _tage = State(initialValue: Set(t))
        }
    }

    private var gueltig: Bool { HabitRaster.formularGueltig(name: name, festeTageArt: art == .tage, tage: tage) }

    private var entwurf: Habit {
        let haeufigkeit: Haeufigkeit = switch art {
        case .taeglich: .taeglich
        case .proWoche: .proWoche(proWoche)
        case .tage: .tage(HabitRaster.festeTage(tage))
        }
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return Habit(id: bestehend?.id ?? "h-\(UUID().uuidString.lowercased())", name: sauber.isEmpty ? "Neue Gewohnheit" : sauber, symbol: symbol,
                     farbe: farbe.rawValue, zaehlen: zaehlen, tagesziel: zaehlen ? tagesziel : nil, haeufigkeit: haeufigkeit, fuer: bestehend?.fuer ?? "ich")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section { vorschau }
                Section("Name") { TextField("Zum Beispiel Dehnen", text: $name).textInputAutocapitalization(.sentences).frame(minHeight: Abstand.tippflaeche) }
                Section("Symbol") { symbolGitter }
                Section("Farbe") { farbReihe }
                haeufigkeitSektion
                artSektion
            }
            .scrollContentBackground(.hidden)
            .lumenHintergrund()
            .navigationTitle(bestehend == nil ? "Neue Gewohnheit" : "Gewohnheit bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(bestehend == nil ? "Anlegen" : "Sichern") { sichern() }.disabled(!gueltig) }
            }
            .haptik(.auswahl, bei: symbol)
            .haptik(.auswahl, bei: farbe)
            .haptik(.auswahl, bei: art)
            .haptik(.auswahl, bei: tage)
            .haptik(.erfolg, bei: gesichert)
            .animation(Feder.schnell, value: art)
            .animation(Feder.schnell, value: zaehlen)
        }
    }

    /// Die Kachel, wie sie später aussieht: Symbol, Name, Häufigkeit und die sieben Wochenquadrate. An festen Tagen tragen die fälligen Tage einen Rand.
    private var vorschau: some View {
        let h = entwurf
        let faellig: Set<Int> = {
            if case .tage(let t) = h.haeufigkeit { return Set(t) }
            return Set(1...7)
        }()
        return VStack(alignment: .leading, spacing: Abstand.s) {
            Image(systemName: h.symbol).font(.title2.weight(.semibold)).foregroundStyle(h.tint).frame(height: 32)
            Text(h.name).font(.headline).foregroundStyle(palette.text).lineLimit(2)
            Text(HabitLogik.haeufigkeitText(h, ziel: nil)).font(.subheadline).foregroundStyle(palette.text2).lineLimit(1)
            HStack(spacing: 3) {
                ForEach(1...7, id: \.self) { tag in
                    HabitQuadrat(farbe: h.tint, anteil: 0, istHeute: faellig.contains(tag), groesse: 13)
                }
            }
        }
        .padding(Abstand.m)
        .frame(width: 180, alignment: .leading)
        .background(h.tint.opacity(0.14), in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vorschau: \(h.name), \(HabitLogik.haeufigkeitText(h, ziel: nil))")
    }

    private var symbolGitter: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: Abstand.tippflaeche), spacing: 4)], spacing: 4) {
            ForEach(HabitSymbole.alle, id: \.self) { s in
                let gewaehlt = s == symbol
                Button { withAnimation(Feder.schnell) { symbol = s } } label: {
                    Image(systemName: s).font(.body.weight(.semibold))
                        .foregroundStyle(gewaehlt ? Color.aufHabitFarbe : palette.text)
                        .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                        .background(Circle().fill(gewaehlt ? farbe.farbe : Color.clear))
                }
                .buttonStyle(.federnd)
                .accessibilityLabel(s)
                .accessibilityAddTraits(gewaehlt ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    private var farbReihe: some View {
        HStack(spacing: 0) {
            ForEach(HabitFarbe.allCases, id: \.self) { f in
                Button { withAnimation(Feder.schnell) { farbe = f } } label: {
                    Circle().fill(f.farbe).frame(width: 30, height: 30)
                        .overlay { if f == farbe { Circle().strokeBorder(palette.text, lineWidth: 2.5).padding(-5) } }
                        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.federnd)
                .accessibilityLabel(f.anzeigename)
                .accessibilityAddTraits(f == farbe ? .isSelected : [])
            }
        }
    }

    private var haeufigkeitSektion: some View {
        Section("Häufigkeit") {
            Picker("Häufigkeit", selection: $art) {
                Text("Jeden Tag").tag(HaeufigkeitArt.taeglich)
                Text("Pro Woche").tag(HaeufigkeitArt.proWoche)
                Text("Feste Tage").tag(HaeufigkeitArt.tage)
            }
            .pickerStyle(.segmented)
            if art == .proWoche {
                Stepper("\(proWoche) Tage pro Woche", value: $proWoche, in: 1...7)
            } else if art == .tage {
                wochentage
            }
        }
    }

    private var wochentage: some View {
        HStack(spacing: 4) {
            ForEach(1...7, id: \.self) { tag in
                let an = tage.contains(tag)
                Button { if an { tage.remove(tag) } else { tage.insert(tag) } } label: {
                    Text(HabitLogik.wochentagKuerzel[tag - 1]).font(.subheadline.weight(.semibold))
                        .foregroundStyle(an ? Color.aufHabitFarbe : palette.text)
                        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                        .background(RoundedRectangle(cornerRadius: Rundung.klein, style: .continuous).fill(an ? farbe.farbe : palette.haar))
                }
                .buttonStyle(.federnd)
                .accessibilityLabel(HabitLogik.wochentagKuerzel[tag - 1])
                .accessibilityAddTraits(an ? .isSelected : [])
            }
        }
        .padding(.vertical, 2)
    }

    private var artSektion: some View {
        Section("Art") {
            Picker("Art", selection: $zaehlen) {
                Text("Abhaken").tag(false)
                Text("Zählen").tag(true)
            }
            .pickerStyle(.segmented)
            if zaehlen { Stepper("Tagesziel: \(tagesziel)", value: $tagesziel, in: 1...50) }
        }
    }

    private func sichern() {
        guard let daten = umgebung.daten, gueltig else { return }
        if bestehend == nil { daten.habits.anlegen(entwurf) } else { daten.habits.aendern(entwurf) }
        gesichert += 1
        dismiss()
    }
}

private enum HaeufigkeitArt: Hashable { case taeglich, proWoche, tage }
