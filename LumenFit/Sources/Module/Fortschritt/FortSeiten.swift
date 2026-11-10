import Charts
import SwiftUI

/// Seite "Gewichte" (Fortschritt > Gewichte > Alle): alle Plan-Übungen mit Linie und Änderung; darunter die Kraftkurve (früher unter "Mehr").
struct FortGewichteSeite: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var merker = FortMerker<FortTrainingEingabe, [GewichtZeile]>()

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        let zeilen = merker.wert(FortTrainingEingabe(sessions: q.sessions, plan: q.plan, heute: q.heute)) {
            FortschrittLogik.gewichte(q.sessions, plan: q.plan, heute: q.heute)
        }
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                Text("Schwerstes Set je Woche, letzte 8 Wochen. Tippen für Kurve und Rekorde.").font(.subheadline).foregroundStyle(palette.text2)
                    .padding(.horizontal, Abstand.xs)
                GewichteListe(zeilen: zeilen)
                ListenKarte {
                    FortListenZeile("Kraftkurve", wert: String(localized: "Gewicht, 1RM, Volumen"), symbol: "chart.line.uptrend.xyaxis", farbe: Bereichsfarbe.splits) {
                        KraftKurveSeite()
                    }
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .navigationTitle("Gewichte")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Seite "12-Wochen-Ausblick": Chips der Hauptübungen, Woche 1 -> Heute -> Woche 12, Kurve (gemessen durchgezogen, Plan gepunktet), Fußnote zur Regel.
struct FortAusblickSeite: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var gewaehlt: String?
    @State private var merker = FortMerker<FortTrainingEingabe, [FortAusblick]>()

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        let liste = merker.wert(FortTrainingEingabe(sessions: q.sessions, plan: q.plan, heute: q.heute)) {
            FortAusblickLogik.hauptuebungen(FortschrittLogik.gewichte(q.sessions, plan: q.plan, heute: q.heute))
        }
        let aktiv = liste.first { $0.id == gewaehlt } ?? liste.first
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                Text("So geht es weiter, wenn du dranbleibst. Ein Plan, kein Versprechen.").font(.subheadline).foregroundStyle(palette.text2)
                    .padding(.horizontal, Abstand.xs)
                if let aktiv {
                    chips(liste, aktiv: aktiv.id)
                    karte(aktiv)
                    (aktiv.schritt == 1 ? Text("Alle 2 Wochen ein kleiner Schritt: 1 kg mehr. Klappt ein Schritt nicht, bleibt das Gewicht, bis alle Sets sitzen.")
                        : Text("Alle 2 Wochen ein kleiner Schritt: 2,5 kg mehr. Klappt ein Schritt nicht, bleibt das Gewicht, bis alle Sets sitzen."))
                        .font(.footnote).foregroundStyle(palette.text2).padding(.horizontal, Abstand.xs)
                } else {
                    LeerZustand(stimmung: .bereit, satz: String(localized: "Noch kein Gewicht in den letzten 8 Wochen. Nach ein paar Trainings zeigt Lumi hier den Weg."),
                                handlung: String(localized: "Training starten")) { umgebung.router.oeffne(.gym(.training)) }
                        .lumenKartenFlaeche()
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .navigationTitle("12-Wochen-Ausblick")
        .navigationBarTitleDisplayMode(.inline)
        .haptik(.auswahl, bei: gewaehlt)
    }

    private func chips(_ liste: [FortAusblick], aktiv: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Abstand.s) {
                ForEach(liste) { a in
                    let an = a.id == aktiv
                    Button { gewaehlt = a.id } label: {
                        Text(a.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                            .foregroundStyle(an ? palette.grund : palette.text)
                            .padding(.horizontal, Abstand.l)
                            .frame(minHeight: Abstand.tippflaeche)
                            .background(an ? palette.text : palette.flaeche, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(an ? .isSelected : [])
                }
            }
        }
    }

    private struct Punkt: Identifiable {
        let woche: Int
        let kg: Double
        let teil: String
        var id: String { "\(teil)-\(woche)" }
    }

    private func karte(_ a: FortAusblick) -> some View {
        let gemessen = (0...a.heute).map { Punkt(woche: $0 + 1, kg: a.punkte[$0], teil: "gemessen") }
        let plan = (a.heute..<a.punkte.count).map { Punkt(woche: $0 + 1, kg: a.punkte[$0], teil: "plan") }
        let niedrig = a.punkte.min() ?? 0, hoch = a.punkte.max() ?? 1
        let rand = max((hoch - niedrig) * 0.12, 1)
        return VStack(alignment: .leading, spacing: Abstand.m) {
            HStack(alignment: .top) {
                wert("Woche 1", a.punkte.first ?? 0, farbe: palette.text)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(palette.text2).accessibilityHidden(true)
                wert("Heute", a.punkte[a.heute], farbe: palette.text)
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(palette.text2).accessibilityHidden(true)
                wert("Woche 12", a.punkte.last ?? 0, farbe: palette.akzent)
            }
            Chart {
                ForEach(gemessen + plan) { p in
                    LineMark(x: .value("Woche", p.woche), y: .value("kg", p.kg), series: .value("Teil", p.teil))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, dash: p.teil == "plan" ? [1, 7] : []))
                        .foregroundStyle(palette.akzent)
                }
                PointMark(x: .value("Woche", 1), y: .value("kg", a.punkte.first ?? 0)).symbolSize(50).foregroundStyle(palette.akzent)
                PointMark(x: .value("Woche", a.heute + 1), y: .value("kg", a.punkte[a.heute])).symbolSize(110).foregroundStyle(palette.akzent)
                PointMark(x: .value("Woche", a.punkte.count), y: .value("kg", a.punkte.last ?? 0))
                    .symbol { Circle().strokeBorder(palette.akzent, lineWidth: 2.5).background(Circle().fill(palette.flaeche)).frame(width: 11, height: 11) }
                RuleMark(x: .value("Heute", a.heute + 1)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3])).foregroundStyle(palette.text2.opacity(0.5))
            }
            .chartXScale(domain: 1...FortAusblickLogik.wochen)
            .chartYScale(domain: (niedrig - rand)...(hoch + rand))
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: [1, a.heute + 1, FortAusblickLogik.wochen]) { wert in
                    AxisValueLabel {
                        if let w = wert.as(Int.self) {
                            Text(w == a.heute + 1 ? "Heute" : "Woche \(w)").font(.caption2).foregroundStyle(palette.text2)
                        }
                    }
                }
            }
            .frame(height: 150)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(a.name): Woche 1 \(FortschrittLogik.zahl(a.punkte.first ?? 0)) kg, heute \(FortschrittLogik.zahl(a.punkte[a.heute])) kg, Woche 12 etwa \(FortschrittLogik.zahl(a.punkte.last ?? 0)) kg")
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lumenKartenFlaeche()
    }

    private func wert(_ titel: LocalizedStringKey, _ kg: Double, farbe: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.footnote).foregroundStyle(palette.text2)
            Text("\(FortschrittLogik.zahl(kg)) kg").font(.title3.weight(.bold)).monospacedDigit().foregroundStyle(farbe).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Seite "Energie und Tagesform": die Woche aus dem eigenen Gefühl (Säulen Mo bis So, Urteil), darunter die Energie-Bank wie bisher
/// (Tipp öffnet Gründe, Verlauf und das Gefühl zum Antippen) und der Stimmungsverlauf.
struct FortEnergieSeite: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var werte: [String: Int] = [:]
    @State private var modell: HeuteModell?
    @State private var detail = false

    /// Das Urteil der laufenden Woche (1 bis 5) für die Zeile im Tab; liest die kleine Datei der Energie-Bank.
    static func urteil(_ daten: DatenSatz?, heute: String) -> Int? {
        FortEnergie.urteil(FortEnergie.woche(werte(daten), heute: heute))
    }

    static func werte(_ daten: DatenSatz?) -> [String: Int] {
        guard let daten else { return [:] }
        let liste = TagesformGefuehl.laden(daten.ordner.appendingPathComponent(TagesformGefuehl.dateiname))
        return Dictionary(liste.map { ($0.tag, $0.gefuehl) }, uniquingKeysWith: { _, neu in neu })
    }

    var body: some View {
        let heute = Datum.text(umgebung.uhr())
        let woche = FortEnergie.woche(werte, heute: heute)
        let urteil = FortEnergie.urteil(woche)
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                VStack(alignment: .leading, spacing: Abstand.s) {
                    Text("Diese Woche").font(.footnote).foregroundStyle(palette.text2)
                    Text(urteil.map(TagesformGefuehl.name) ?? "–").font(.largeTitle.weight(.bold)).fontDesign(.rounded).foregroundStyle(palette.text)
                    Text(FortEnergie.satz(urteil)).font(.subheadline).foregroundStyle(palette.text2)
                    FortSaeulen(saeulen: woche.enumerated().map { i, w in
                        .init(id: "\(i)", beschriftung: String(localized: Self.tageText[i]), wert: Double(w ?? 0),
                              sprechtext: w.map { "\(String(localized: Self.tageText[i])): \(TagesformGefuehl.name($0))" } ?? "\(String(localized: Self.tageText[i])): \(String(localized: "kein Eintrag"))")
                    }, hervorgehoben: "\(Datum.wochentag(heute) - 1)", hoehe: 80)
                }
                .padding(Abstand.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lumenKartenFlaeche()
                Text("Dein Gefühl je Tag tippst du in der Energie-Bank an, von leer bis voll. Daraus wird diese Woche, ohne Messgeräte.")
                    .font(.footnote).foregroundStyle(palette.text2).padding(.horizontal, Abstand.xs)
                if let energie = modell?.stand?.energie {
                    EnergieBank(energie: energie) { detail = true }
                }
                StimmungVerlaufKarte()
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .navigationTitle("Energie und Tagesform")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            werte = Self.werte(umgebung.daten)
            let m = modell ?? HeuteModell(umgebung: umgebung)
            modell = m
            await m.beobachte()
        }
        .sheet(isPresented: $detail) {
            if let energie = modell?.stand?.energie {
                EnergieDetail(energie: energie) { stufe in
                    modell?.speichereGefuehl(stufe)
                    werte = Self.werte(umgebung.daten)
                }
            }
        }
    }

    private static let tageText: [String.LocalizationValue] = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
}
