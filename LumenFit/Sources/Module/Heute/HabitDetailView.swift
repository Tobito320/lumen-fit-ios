// Quelle: Lovea Health/HabitDetail.swift, HealthStil.swift (MonatsPager)
import SwiftUI

/// Die Seite einer Gewohnheit: Serie, beste Serie und Quote der letzten 30 Tage, dazu Woche, Monat (wischbar) und Jahr als Raster.
/// Ein Tipp auf einen vergangenen Tag im Monat hakt ihn ab oder nimmt den Haken zurück. Drei-Punkte-Menü: Bearbeiten und Löschen.
/// Wird per Zoom aus der Kachel geöffnet (`HeuteTabView`) oder aus der Verwaltung geschoben.
struct HabitDetailView: View {
    let habitId: String

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.bewegungAus) private var bewegungAus
    @State private var bearbeiten = false
    @State private var loeschenFragen = false
    @State private var gesetzt = 0
    @State private var zurueckgenommen = 0
    @State private var geloescht = 0

    var body: some View {
        Group {
            if let daten = umgebung.daten, let habit = daten.habits.habits[habitId] {
                inhalt(habit, daten)
            } else {
                LeerZustand(stimmung: .denkt, satz: "Diese Gewohnheit gibt es nicht mehr.")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .haptik(.erfolg, bei: gesetzt)
        .haptik(.stopp, bei: zurueckgenommen)
        .haptik(.warnung, bei: geloescht)
    }

    /// Wann heute getrunken wurde (aus den Zeitpunkten der Einträge).
    @ViewBuilder
    private func wasserProtokoll(_ daten: DatenSatz, heute: String) -> some View {
        let liste = WasserProtokoll.eintraege(ops: daten.raum.ops(arten: ["habit.setzen"]), profil: daten.habits.ich, tag: heute)
        HabitKartenRahmen {
            Text("Heute getrunken").font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            if liste.isEmpty {
                Text("Noch nichts eingetragen.").font(.subheadline).foregroundStyle(palette.text2)
            } else {
                ForEach(liste.reversed()) { e in
                    Label(WasserProtokoll.text(e), systemImage: "drop.fill").font(.subheadline.monospacedDigit()).foregroundStyle(palette.text)
                }
            }
        }
    }

    private func inhalt(_ habit: Habit, _ daten: DatenSatz) -> some View {
        let heute = Datum.text(umgebung.uhr())
        let werte = daten.habits.werte(habit.id)
        let ziel = daten.habits.habitZiel(habit.id)
        return ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                HabitDetailKopf(habit: habit, werte: werte, ziel: ziel, heute: heute)
                HabitKartenRahmen {
                    Text("Woche").font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
                    HabitWochenReihe(habit: habit, werte: werte, ziel: ziel, heute: heute)
                }
                if habit.id == Habit.wasser.id { wasserProtokoll(daten, heute: heute) }
                monat(habit, werte: werte, ziel: ziel, heute: heute, daten: daten)
                HabitKartenRahmen {
                    Text("Jahr").font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
                    HabitJahrRaster(habit: habit, werte: werte, ziel: ziel, heute: heute)
                }
            }
            .padding(Abstand.l)
            .padding(.bottom, Abstand.xl)
        }
        .navigationTitle(habit.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { bearbeiten = true } label: { Label("Bearbeiten", systemImage: "pencil") }
                    if !habit.istEingebaut {
                        Button(role: .destructive) { loeschenFragen = true } label: { Label("Löschen", systemImage: "trash") }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").frame(minWidth: Abstand.tippflaeche, minHeight: Abstand.tippflaeche)
                }
                .accessibilityLabel("Mehr")
            }
        }
        .sheet(isPresented: $bearbeiten) {
            if habit.istEingebaut {
                NavigationStack {
                    ZieleView().toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { bearbeiten = false } } }
                }
            } else {
                HabitFormularView(bestehend: habit)
            }
        }
        .confirmationDialog("Gewohnheit löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                daten.habits.loeschen(habit.id)
                geloescht += 1
                dismiss()
            }
        } message: {
            Text("\(habit.name) und der Verlauf gehen verloren.")
        }
    }

    private func monat(_ habit: Habit, werte: [String: Int], ziel: Int?, heute: String, daten: DatenSatz) -> some View {
        HabitKartenRahmen(innenRand: false) {
            Text("Monat").font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader).padding(.horizontal, Abstand.l)
            HabitMonatsPager { zurueck in
                HabitMonatGitter(habit: habit, werte: werte, ziel: ziel, heute: heute, monateZurueck: zurueck,
                                 tippen: habit.id == Habit.gewicht.id ? nil : { tagTippen($0, habit, daten, heute: heute) })
                    .padding(.horizontal, Abstand.l)
            }
        }
    }

    /// Ein vergangener Tag: erledigt wird offen, offen wird erledigt (Zähl-Gewohnheiten: das Tagesziel).
    private func tagTippen(_ tag: String, _ habit: Habit, _ daten: DatenSatz, heute: String) {
        guard tag <= heute else { return }
        let neu = HabitLogik.umgeschaltet(habit, wert: daten.habits.wert(habit.id, tag), ziel: daten.habits.habitZiel(habit.id))
        withAnimation(bewegungAus ? nil : Feder.schnell) { daten.habits.setze(habit.id, datum: tag, wert: neu) }
        if neu == 0 { zurueckgenommen += 1 } else { gesetzt += 1 }
    }
}

/// Flache Karte der Seite (`flaeche`, Kartenrundung). `innenRand: false`, wenn der Inhalt selbst bis an den Rand wischt.
private struct HabitKartenRahmen<Inhalt: View>: View {
    var innenRand = true
    @ViewBuilder let inhalt: Inhalt
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.m) { inhalt }
            .padding(.vertical, Abstand.l)
            .padding(.horizontal, innenRand ? Abstand.l : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lumenKartenFlaeche()
    }
}

/// Symbol, Häufigkeit und die drei Zahlen: Serie, beste Serie, Quote 30 Tage.
private struct HabitDetailKopf: View {
    let habit: Habit
    let werte: [String: Int]
    let ziel: Int?
    let heute: String
    @Environment(\.palette) private var palette

    var body: some View {
        let serie = HabitLogik.serie(habit, werte: werte, ziel: ziel, heute: heute)
        let beste = HabitLogik.besteSerie(habit, werte: werte, ziel: ziel, heute: heute)
        let quote = HabitLogik.quote30(habit, werte: werte, ziel: ziel, heute: heute)
        let wochen = Self.wochenweise(habit)
        return HabitKartenRahmen {
            HStack(spacing: Abstand.m) {
                Image(systemName: habit.symbol)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(habit.tint)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(habit.tint.opacity(0.18)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(HabitLogik.haeufigkeitText(habit, ziel: ziel)).font(.headline).foregroundStyle(palette.text)
                    Text(habit.zaehlen ? "Zählen, Ziel \(ziel ?? habit.tagesziel ?? 1) am Tag" : "Abhaken").font(.subheadline).foregroundStyle(palette.text2)
                }
            }
            HStack(alignment: .top, spacing: Abstand.s) {
                zahl("Serie", symbol: "flame.fill", wert: Double(serie), einheit: wochen ? (serie == 1 ? "Woche" : "Wochen") : (serie == 1 ? "Tag" : "Tage"),
                     satz: HabitRaster.serieText(habit, serie))
                zahl("Beste", symbol: "trophy.fill", wert: Double(beste), einheit: wochen ? (beste == 1 ? "Woche" : "Wochen") : (beste == 1 ? "Tag" : "Tage"),
                     satz: HabitRaster.serieText(habit, beste))
                zahl("30 Tage", symbol: "chart.bar.fill", wert: (quote * 100).rounded(), einheit: "%", satz: HabitRaster.prozent(quote))
            }
        }
    }

    private static func wochenweise(_ habit: Habit) -> Bool {
        if case .proWoche = habit.haeufigkeit { return true }
        return false
    }

    private func zahl(_ titel: String, symbol: String, wert: Double, einheit: String, satz: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(titel, systemImage: symbol).font(.caption.weight(.semibold)).foregroundStyle(habit.tint)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                RollZahl(wert: wert, format: HeuteFormat.ganz()).font(.system(.title2, design: .rounded).weight(.bold)).foregroundStyle(palette.text)
                Text(einheit).font(.caption).foregroundStyle(palette.text2)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titel): \(satz)")
    }
}

/// Mo bis So der Woche als größere Quadrate; Zähl-Gewohnheiten füllen sich von unten, erledigte tragen einen Haken.
private struct HabitWochenReihe: View {
    let habit: Habit
    let werte: [String: Int]
    let ziel: Int?
    let heute: String
    @Environment(\.palette) private var palette

    var body: some View {
        let tage = HabitLogik.wochenTage(heute: heute)
        let anteile = HabitRaster.wochenAnteile(habit, werte: werte, ziel: ziel, heute: heute)
        HStack(spacing: Abstand.s) {
            ForEach(Array(tage.enumerated()), id: \.offset) { i, tag in
                VStack(spacing: Abstand.xs) {
                    HabitQuadrat(farbe: habit.tint, anteil: anteile[i], istHeute: tag == heute, zukunft: tag > heute, haken: true)
                    Text(HabitLogik.wochentagKuerzel[i]).font(.caption2).foregroundStyle(tag == heute ? palette.text : palette.text2)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Diese Woche: \(HabitRaster.wochenErledigt(habit, werte: werte, ziel: ziel, heute: heute)) Tage erledigt")
    }
}

/// Ein Tag als Quadrat: Fläche in Habit-Farbe, gefüllt nach Anteil von unten. Gleiche Form auf der Kachel (klein) und in der Seite (groß).
struct HabitQuadrat: View {
    let farbe: Color
    let anteil: Double
    var istHeute = false
    var zukunft = false
    var haken = false
    /// nil = füllt die Breite als Quadrat.
    var groesse: CGFloat?
    @Environment(\.bewegungAus) private var bewegungAus

    var body: some View {
        let form = RoundedRectangle(cornerRadius: groesse == nil ? 8 : 3.5, style: .continuous)
        form.fill(farbe.opacity(zukunft ? 0.06 : 0.18))
            .overlay(alignment: .bottom) {
                GeometryReader { geo in
                    Rectangle().fill(farbe).frame(height: geo.size.height * anteil).frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .clipShape(form)
            .overlay { if istHeute { form.strokeBorder(farbe, lineWidth: 1) } }
            .overlay {
                if haken {
                    Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(Color.aufHabitFarbe)
                        .scaleEffect(anteil >= 1 ? 1 : 0.4).opacity(anteil >= 1 ? 1 : 0)
                }
            }
            .animation(bewegungAus ? nil : Feder.schnell, value: anteil)
            .frame(width: groesse, height: groesse)
            .aspectRatio(groesse == nil ? 1 : nil, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

/// Zwölf Monate zum Wischen, der aktuelle zuletzt und zuerst sichtbar. Jede Seite hat ihren Titel selbst. Haptik beim Seitenwechsel.
struct HabitMonatsPager<Inhalt: View>: View {
    // shortcut: zwölf Monate zurück; aus dem ersten Datentag ableiten, falls ältere Monate gebraucht werden.
    var anzahl = 12
    @ViewBuilder let inhalt: (_ monateZurueck: Int) -> Inhalt
    @State private var seite: Int?
    @State private var gewechselt = 0

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach((0..<anzahl).reversed(), id: \.self) { zurueck in
                    inhalt(zurueck).containerRelativeFrame(.horizontal).id(zurueck)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $seite)
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .defaultScrollAnchor(.trailing)
        .onChange(of: seite) { alt, neu in if alt != nil, neu != nil { gewechselt += 1 } }
        .haptik(.auswahl, bei: gewechselt)
    }
}

/// Der Monatskalender einer Gewohnheit, immer sechs Zeilen, damit die Höhe beim Wischen gleich bleibt.
struct HabitMonatGitter: View {
    let habit: Habit
    let werte: [String: Int]
    let ziel: Int?
    let heute: String
    let monateZurueck: Int
    /// Tipp auf einen vergangenen Tag; nil = nur Anzeige.
    var tippen: ((String) -> Void)?
    @Environment(\.palette) private var palette

    var body: some View {
        let zellen = HabitRaster.zellen(heute: heute, monateZurueck: monateZurueck)
        let erledigt = HabitRaster.monatErledigt(habit, werte: werte, ziel: ziel, heute: heute, monateZurueck: monateZurueck)
        VStack(alignment: .leading, spacing: Abstand.s) {
            HStack {
                Text(HabitRaster.monatsTitel(heute: heute, monateZurueck: monateZurueck)).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                Spacer()
                Text(erledigt == 1 ? "1 Tag" : "\(erledigt) Tage").font(.footnote).foregroundStyle(palette.text2)
            }
            HStack(spacing: 0) {
                ForEach(HabitLogik.wochentagKuerzel, id: \.self) { kuerzel in
                    Text(kuerzel).font(.caption2.weight(.semibold)).foregroundStyle(palette.text2).frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(zellen.enumerated()), id: \.offset) { _, tag in feld(tag) }
            }
        }
    }

    @ViewBuilder
    private func feld(_ tag: String?) -> some View {
        if let tag, tag <= heute {
            let anteil = HabitLogik.anteil(habit, wert: werte[tag] ?? 0, ziel: ziel)
            let fertig = HabitLogik.erledigt(habit, wert: werte[tag] ?? 0, ziel: ziel)
            let zelle = RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(habit.tint.opacity(anteil > 0 ? 0.3 + 0.7 * anteil : 0.1))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Text(HabitRaster.tagesnummer(tag)).font(.caption2).monospacedDigit()
                        .foregroundStyle(anteil >= 1 ? Color.aufHabitFarbe : palette.text)
                }
            if let tippen {
                Button { tippen(tag) } label: { zelle }
                    .buttonStyle(.federnd)
                    .frame(minHeight: 36)
                    .accessibilityLabel(Datum.anzeige(tag))
                    .accessibilityValue(fertig ? "erledigt" : "offen")
                    .accessibilityHint("Zum Markieren antippen")
            } else {
                zelle
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(Datum.anzeige(tag)): \(fertig ? "erledigt" : "offen")")
            }
        } else {
            Color.clear.aspectRatio(1, contentMode: .fit)
        }
    }
}

/// Zwölf Monate klein, vier Zeilen zu drei. Nur Anzeige; ein Satz je Monat für VoiceOver.
private struct HabitJahrRaster: View {
    let habit: Habit
    let werte: [String: Int]
    let ziel: Int?
    let heute: String
    @Environment(\.palette) private var palette

    var body: some View {
        let gesamt = HabitRaster.jahrMonate.reduce(0) { $0 + HabitRaster.monatErledigt(habit, werte: werte, ziel: ziel, heute: heute, monateZurueck: $1) }
        VStack(alignment: .leading, spacing: Abstand.m) {
            Text(gesamt == 1 ? "1 Tag in den letzten zwölf Monaten" : "\(gesamt) Tage in den letzten zwölf Monaten").font(.subheadline).foregroundStyle(palette.text2)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Abstand.m), count: 3), spacing: Abstand.m) {
                ForEach(HabitRaster.jahrMonate, id: \.self) { zurueck in mini(zurueck) }
            }
        }
    }

    private func mini(_ zurueck: Int) -> some View {
        let zellen = HabitRaster.zellen(heute: heute, monateZurueck: zurueck)
        let erledigt = HabitRaster.monatErledigt(habit, werte: werte, ziel: ziel, heute: heute, monateZurueck: zurueck)
        return VStack(alignment: .leading, spacing: 3) {
            Text(HabitRaster.monatsKurz(heute: heute, monateZurueck: zurueck)).font(.caption2.weight(.semibold)).foregroundStyle(palette.text2)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1.5), count: 7), spacing: 1.5) {
                ForEach(Array(zellen.enumerated()), id: \.offset) { _, tag in
                    if let tag, tag <= heute {
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(habit.tint.opacity(HabitLogik.anteil(habit, wert: werte[tag] ?? 0, ziel: ziel) > 0 ? 0.3 + 0.7 * HabitLogik.anteil(habit, wert: werte[tag] ?? 0, ziel: ziel) : 0.1))
                            .aspectRatio(1, contentMode: .fit)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(HabitRaster.monatsTitel(heute: heute, monateZurueck: zurueck)): \(erledigt == 1 ? "1 Tag" : "\(erledigt) Tage") erledigt")
    }
}
