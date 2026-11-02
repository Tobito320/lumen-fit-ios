import SwiftUI

/// Gewicht in drei Sekunden (Idee 17), Teil 2: das Blatt mit dem Zahlenrad. Es startet bei der letzten Messung, ein Tipp auf "Speichern" genügt.
/// Auf Wunsch (Schalter, Einstellung `healthSchreiben`) geht der Wert zurück nach Health. Erreichbar über die Route `gewichtEintragen` und als Blatt im Heute-Tab.
struct GewichtEintragenView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var modell: HeuteModell?
    @State private var kilo = 75
    @State private var zehntel = 0
    @State private var gespeichert = 0
    @State private var geloescht = 0
    @State private var fehler = false
    @State private var tag = ""
    @State private var version = 0

    var body: some View {
        let _ = version
        let werte = alleWerte()
        ScrollView {
            VStack(spacing: Abstand.l) {
                tagWahl(werte)
                rad
                schrittReihe
                Button { speichern() } label: {
                    Text("Speichern").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.akzent)
                .foregroundStyle(palette.aufAkzent)
                if fehler {
                    Text("Das Gewicht muss zwischen 30 und 249,9 kg liegen.").font(.footnote.weight(.medium)).foregroundStyle(palette.text2)
                }
                if eigenerEintrag { loeschenKnopf }
                healthSchalter
                if let g = modell?.stand?.gewicht, g.punkte.count >= 2 {
                    VStack(alignment: .leading, spacing: Abstand.s) {
                        Text("Verlauf").font(.headline).foregroundStyle(palette.text)
                        HeuteGewichtDiagramm(punkte: g.punkte, ziel: g.zielKg).frame(height: 160)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                log(werte)
            }
            .padding(Abstand.l)
        }
        .navigationTitle("Gewicht")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .haptik(.erfolg, bei: gespeichert)
        .haptik(.stopp, bei: geloescht)
        .task {
            guard modell == nil else { return }
            let m = HeuteModell(umgebung: umgebung)
            m.berechne()
            modell = m
            tag = Datum.text(umgebung.uhr())
            setzeRad(m.stand?.gewicht.startZehntel ?? 750)
        }
    }

    // MARK: - Tag, Log, Löschen (wie Lovea GewichtBlatt)

    /// Gewicht je Tag in Zehntel-kg: Health, darüber das von Hand Eingetragene.
    private func alleWerte() -> [String: Int] {
        HeuteQuellen.gewichtWerte(health: umgebung.gesundheit.gewichte, manuell: umgebung.daten?.habits.werte(Habit.gewicht.id) ?? [:])
    }

    private var eigenerEintrag: Bool { (umgebung.daten?.habits.wert(Habit.gewicht.id, tag) ?? 0) > 0 }

    private func setzeRad(_ wert: Int) {
        let w = min(max(wert, HeuteQuellen.gewichtBereich.lowerBound), HeuteQuellen.gewichtBereich.upperBound)
        kilo = w / 10
        zehntel = w % 10
    }

    private func tagWahl(_ werte: [String: Int]) -> some View {
        DatePicker("Tag", selection: Binding(get: { Datum.datum(tag.isEmpty ? Datum.text(umgebung.uhr()) : tag) }, set: { tag = Datum.text($0) }),
                   in: ...umgebung.uhr(), displayedComponents: .date)
            .environment(\.locale, Locale(identifier: "de_DE"))
            .environment(\.timeZone, Datum.zone)
            .font(.subheadline)
            .foregroundStyle(palette.text)
            .frame(minHeight: Abstand.tippflaeche)
            .onChange(of: tag) { _, neu in
                if let z = GewichtText.zehntel(GewichtLogik.startFeld(werte, tag: neu)) { setzeRad(z) }
                fehler = false
            }
    }

    /// Plus und Minus in 0,1 kg; Halten zählt weiter (`buttonRepeatBehavior`, kein eigener Timer).
    private var schrittReihe: some View {
        HStack(spacing: Abstand.l) {
            schrittKnopf("minus", "Weniger", -1)
            Text(GewichtText.anzeige(kilo * 10 + zehntel)).font(.title2.weight(.semibold).monospacedDigit()).foregroundStyle(palette.text)
                .contentTransition(.numericText()).frame(minWidth: 110)
            schrittKnopf("plus", "Mehr", 1)
        }
    }

    private func schrittKnopf(_ symbol: String, _ name: String, _ delta: Int) -> some View {
        Button {
            let neu = kilo * 10 + zehntel + delta
            guard HeuteQuellen.gewichtBereich.contains(neu) else { return }
            withAnimation(Feder.schnell) { setzeRad(neu) }
        } label: {
            Image(systemName: symbol).font(.title3.weight(.semibold)).frame(width: 52, height: 52)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .tint(palette.text)
        .buttonRepeatBehavior(.enabled)
        .haptik(.auswahl, bei: kilo * 10 + zehntel)
        .accessibilityLabel("\(name), 0,1 Kilogramm")
    }

    private var loeschenKnopf: some View {
        Button("Eintrag vom \(Datum.anzeige(tag)) löschen", systemImage: "trash", role: .destructive) {
            modell?.loescheGewicht(tag: tag)
            geloescht += 1
            version += 1
        }
        .frame(minHeight: Abstand.tippflaeche)
        .accessibilityHint("Entfernt nur deinen eigenen Eintrag, nicht den aus Health")
    }

    /// Tageslog, neueste zuerst; Tippen lädt den Tag ins Rad.
    @ViewBuilder
    private func log(_ werte: [String: Int]) -> some View {
        let eintraege = Array(GewichtLogik.log(werte).prefix(30))
        if !eintraege.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Einträge").font(.headline).foregroundStyle(palette.text).padding(.bottom, Abstand.s)
                ForEach(eintraege) { p in
                    Button { withAnimation(Feder.schnell) { tag = p.tag } } label: {
                        HStack {
                            Text(Datum.anzeige(p.tag)).foregroundStyle(p.tag == tag ? palette.akzent : palette.text)
                            Spacer()
                            Text(GewichtText.anzeige(p.zehntel)).monospacedDigit().foregroundStyle(palette.text2)
                        }
                        .frame(minHeight: Abstand.tippflaeche)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(Datum.anzeige(p.tag)), \(GewichtText.anzeige(p.zehntel))")
                    .accessibilityHint("Zum Ändern antippen")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var rad: some View {
        HStack(spacing: 0) {
            Picker("Kilogramm", selection: $kilo) {
                ForEach(30...249, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 110)
            Text(",").font(.title.weight(.bold)).foregroundStyle(palette.text).accessibilityHidden(true)
            Picker("Zehntel", selection: $zehntel) {
                ForEach(0...9, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 70)
            Text("kg").font(.title3).foregroundStyle(palette.text2).padding(.leading, Abstand.s).accessibilityHidden(true)
        }
        .frame(height: 160)
        .accessibilityElement(children: .contain)
    }

    private var healthSchalter: some View {
        let daten = umgebung.daten
        return Toggle("Auch in Health speichern", isOn: Binding(
            get: { daten?.einstellungen.werte.healthSchreiben ?? false },
            set: { neu in daten?.einstellungen.aendere { $0.healthSchreiben = neu } }))
            .font(.subheadline)
            .foregroundStyle(palette.text)
            .frame(minHeight: Abstand.tippflaeche)
    }

    private func speichern() {
        guard let modell else { return }
        Task {
            if await modell.speichereGewicht(zehntel: kilo * 10 + zehntel, tag: tag.isEmpty ? nil : tag) {
                gespeichert += 1
                dismiss()
            } else {
                fehler = true
            }
        }
    }
}
