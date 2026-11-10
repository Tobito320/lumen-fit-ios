import SwiftUI

/// Gewicht in drei Sekunden (Idee 17), Teil 2: das Blatt "Gewicht eintragen" (neues Design 10.11.2026). Oben die Datum-Pille (antippbar: anderer Tag),
/// der Streifen mit fünf Werten (−/+ 0,1 kg, Halten zählt weiter, Ziehen springt schneller), "Sichern" und der Hinweis, dass der Wert immer auch in Health landet
/// (Besitzer: "speichert immer automatisch", kein Schalter mehr). Darunter, beim Hochziehen des Blatts, Löschen, Verlauf und Einträge.
/// Erreichbar über die Route `gewichtEintragen` und als Blatt im Heute-Tab.
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
    /// Wert beim Beginn eines Zugs über den Streifen; nil = kein Zug.
    @State private var ziehStart: Int?

    var body: some View {
        let _ = version
        let werte = alleWerte()
        ScrollView {
            VStack(spacing: Abstand.l) {
                tagWahl(werte)
                streifen
                Button { speichern() } label: {
                    Text("Sichern").frame(maxWidth: .infinity)
                }
                .buttonStyle(.lumenHauptknopf)
                Text("Wird automatisch in Apple Health gespeichert.").font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.center)
                if fehler {
                    Text("Das Gewicht muss zwischen 30 und 249,9 kg liegen.").font(.footnote.weight(.medium)).foregroundStyle(palette.text2)
                }
                if eigenerEintrag { loeschenKnopf }
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
        .navigationTitle("Gewicht eintragen")
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
            .labelsHidden()
            .font(.subheadline)
            .foregroundStyle(palette.text)
            .frame(minHeight: Abstand.tippflaeche)
            .accessibilityLabel("Tag")
            .onChange(of: tag) { _, neu in
                if let z = GewichtText.zehntel(GewichtLogik.startFeld(werte, tag: neu)) { setzeRad(z) }
                fehler = false
            }
    }

    /// Minus, fünf Werte (der mittlere groß) und Plus, in 0,1 kg; Halten zählt weiter (`buttonRepeatBehavior`, kein eigener Timer).
    /// Waagerecht ziehen über die Werte springt schneller (12 pt je 0,1 kg, nach links mehr), VoiceOver stellt per Wischen hoch/runter.
    private var streifen: some View {
        let wert = kilo * 10 + zehntel
        return HStack(spacing: Abstand.s) {
            schrittKnopf("minus", String(localized: "Weniger"), -1)
            HStack(alignment: .firstTextBaseline, spacing: Abstand.m) {
                ForEach(-2...2, id: \.self) { d in
                    let w = wert + d
                    if d == 0 {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(Double(w) / 10, format: HeuteFormat.kilo()).heuteHeldenZahl(40).foregroundStyle(palette.text)
                                .contentTransition(.numericText(value: Double(w)))
                            Text("kg").font(.subheadline.weight(.semibold)).foregroundStyle(palette.text2)
                        }
                        .layoutPriority(1)
                    } else {
                        Text(HeuteQuellen.gewichtBereich.contains(w) ? (Double(w) / 10).formatted(HeuteFormat.kilo()) : " ")
                            .font(abs(d) == 1 ? .body : .footnote)
                            .monospacedDigit()
                            .foregroundStyle(palette.text2.opacity(abs(d) == 1 ? 1 : 0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 4)
                .onChanged { zug in
                    let start = ziehStart ?? wert
                    ziehStart = start
                    let neu = start + Int((-zug.translation.width / 12).rounded())
                    let grenzen = HeuteQuellen.gewichtBereich
                    setzeRad(min(max(neu, grenzen.lowerBound), grenzen.upperBound))
                }
                .onEnded { _ in ziehStart = nil })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Gewicht")
            .accessibilityValue(GewichtText.anzeige(wert))
            .accessibilityAdjustableAction { richtung in
                switch richtung {
                case .increment: schritt(1)
                case .decrement: schritt(-1)
                @unknown default: break
                }
            }
            schrittKnopf("plus", String(localized: "Mehr"), 1)
        }
    }

    private func schritt(_ delta: Int) {
        let neu = kilo * 10 + zehntel + delta
        guard HeuteQuellen.gewichtBereich.contains(neu) else { return }
        withAnimation(Feder.schnell) { setzeRad(neu) }
    }

    private func schrittKnopf(_ symbol: String, _ name: String, _ delta: Int) -> some View {
        Button { schritt(delta) } label: {
            Image(systemName: symbol).font(.title3.weight(.semibold)).frame(width: 48, height: 48)
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
