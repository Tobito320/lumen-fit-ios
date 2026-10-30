// Quelle: Lovea Health/Verlauf/KonsistenzKarte.swift (neu im Lumen-Design: Palette statt fester Farben, Wortlegende, Diagrammbeschreibung)
import SwiftUI

/// Reine Hilfen der Konsistenz-Karte: deutsche Beschriftung und Monatssummen für die Diagrammbeschreibung.
enum KonsistenzKarteLogik {
    static let monatsKurz = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
    /// Nur Mo, Mi, Fr: jede zweite Zeile, damit die Namen bei 390 pt nicht aufeinander liegen.
    static let wochentage: [(zeile: Int, name: String)] = [(0, "Mo"), (2, "Mi"), (4, "Fr")]

    /// Deutscher Kurzname des Monats, den `KonsistenzLogik.Monat` englisch trägt.
    static func monatName(_ m: KonsistenzLogik.Monat) -> String {
        KonsistenzLogik.monatsnamen.firstIndex(of: m.name).map { monatsKurz[$0] } ?? m.name
    }

    /// Workouts je Monat eines Jahres (bis heute), für die Beschreibung des Rasters.
    static func monatsSummen(_ j: KonsistenzLogik.Jahr) -> [(monat: String, workouts: Int)] {
        var summen = [Int](repeating: 0, count: 12)
        for z in j.zellen.compactMap({ $0 }) where !z.zukunft {
            if let m = Int(z.tag.dropFirst(5).prefix(2)), (1...12).contains(m) { summen[m - 1] += z.anzahl }
        }
        let letzter = j.zellen.compactMap { $0 }.last { !$0.zukunft }.flatMap { Int($0.tag.dropFirst(5).prefix(2)) } ?? 0
        return (0..<min(12, letzter)).map { (monatsKurz[$0], summen[$0]) }
    }

    /// "Gesamt" oder das Jahr.
    static func zeitraumText(_ auswahl: Int?) -> String { auswahl.map { String($0) } ?? "Gesamt" }

    /// Aussage über der Karte: "27 Trainingstage in 2026" oder "112 Trainingstage insgesamt".
    static func aussage(_ jahre: [KonsistenzLogik.Jahr], auswahl: Int?) -> String {
        let tage = jahre.reduce(0) { $0 + $1.trainingstage }
        let wort = tage == 1 ? "Trainingstag" : "Trainingstage"
        return auswahl.map { "\(tage) \(wort) in \($0)" } ?? "\(tage) \(wort) insgesamt"
    }
}

/// Trainings-Konsistenz: je Jahr ein Raster (Spalten = Wochen, Zeilen = Mo bis So), neuestes Jahr oben. Eigene Kategorien mit Name und Farbe (Blatt
/// über das Palettensymbol), zwei Kategorien am Tag teilen die Zelle diagonal. Gezeichnet in einem Canvas je Jahr, kein Timer, keine Hintergrundarbeit.
struct KonsistenzKarte: View {
    let sessions: [GymSession]
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    /// nil = Gesamt, sonst ein einzelnes Jahr; Standard ist das laufende Jahr (gesetzt beim Erscheinen).
    @State private var auswahl: Int?
    @State private var auswahlGesetzt = false
    @State private var einstellung = KonsistenzEinstellung.standard
    @State private var kategorienOffen = false
    @State private var gewaehlt: String?
    @State private var tipp = 0
    /// Hilfszeile "Tipp auf einen Tag" nur bis zum ersten Tipp.
    @AppStorage("lumen.konsistenz.tippGesehen") private var tippGesehen = false

    private var ordner: URL? { umgebung.daten?.ordner }

    var body: some View {
        let heute = Datum.text(umgebung.uhr())
        let tage = KonsistenzLogik.tage(sessions)
        let verfuegbar = KonsistenzLogik.verfuegbar(tage: tage, heute: heute)
        let jahre = KonsistenzLogik.jahre(tage: tage, heute: heute, auswahl: auswahl)
        let fuellungen = KonsistenzKategorienLogik.fuellungen(sessions, einstellung: einstellung) { umgebung.daten?.training.tag(id: $0)?.name }
        let farben = Dictionary(einstellung.kategorien.map { ($0.id, farbe($0.farbe)) }, uniquingKeysWith: { erste, _ in erste })
        DiagrammKarte(aussage: KonsistenzKarteLogik.aussage(jahre, auswahl: auswahl),
                      kernzeile: sessions.isEmpty ? "Sobald du im Gym eincheckst, füllt sich das Raster." : "Tipp auf einen Tag zeigt das Training.") {
            VStack(alignment: .leading, spacing: Abstand.m) {
                kopf(verfuegbar: verfuegbar)
                legende
                detail
                ForEach(jahre) { j in
                    Haarlinie()
                    jahrBlock(j, fuellungen: fuellungen, farben: farben)
                }
            }
        }
        .sheet(isPresented: $kategorienOffen, onDismiss: { einstellung = KonsistenzKategorienDatei.lesen(ordner) }) {
            KonsistenzKategorienBlatt(ordner: ordner)
        }
        .haptik(.auswahl, bei: tipp)
        .task {
            guard !auswahlGesetzt else { return }
            auswahlGesetzt = true
            auswahl = Int(Datum.text(umgebung.uhr()).prefix(4))
            einstellung = KonsistenzKategorienDatei.lesen(ordner)
        }
    }

    private func farbe(_ hex: String) -> Color {
        KonsistenzFarbe.kanaele(hex: hex).map { Color(red: $0.r, green: $0.g, blue: $0.b) } ?? GymFarbe.gruen(schema: schema, kontrast: kontrast)
    }

    // MARK: Kopf, Legende, Tag

    private func kopf(verfuegbar: [Int]) -> some View {
        HStack(spacing: Abstand.s) {
            Text("Konsistenz").font(.headline).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            Spacer(minLength: Abstand.s)
            Button { kategorienOffen = true } label: {
                Image(systemName: "paintpalette")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.text)
                    .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                    .background(palette.grund, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
            }
            .buttonStyle(.federnd)
            .accessibilityLabel("Kategorien")
            .accessibilityHint("Eigene Kategorien mit Farbe festlegen")
            Menu {
                Picker("Zeitraum", selection: $auswahl) {
                    Text("Gesamt").tag(Int?.none)
                    ForEach(verfuegbar, id: \.self) { Text(String($0)).tag(Int?.some($0)) }
                }
            } label: {
                HStack(spacing: Abstand.xs) {
                    Text(KonsistenzKarteLogik.zeitraumText(auswahl))
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold)).accessibilityHidden(true)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.text)
                .padding(.horizontal, Abstand.m)
                .frame(minHeight: Abstand.tippflaeche)
                .background(palette.grund, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
            }
            .accessibilityLabel("Zeitraum, \(KonsistenzKarteLogik.zeitraumText(auswahl))")
        }
    }

    /// Umbrechendes Raster statt einer Zeile: mit eigenen Kategorien werden es mehr als drei Einträge. Jeder Eintrag steht mit Farbfeld und Wort.
    private var legende: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: Abstand.m, alignment: .leading)], alignment: .leading, spacing: Abstand.xs) {
            ForEach(einstellung.kategorien) { k in legendePunkt(farbe(k.farbe), k.name) }
            legendePunkt(GymFarbe.gruen(schema: schema, kontrast: kontrast), "Ohne Kategorie")
            legendePunkt(palette.haar, "Kein Training")
        }
        .accessibilityElement(children: .combine)
    }

    private func legendePunkt(_ farbe: Color, _ text: String) -> some View {
        HStack(spacing: Abstand.xs) {
            RoundedRectangle(cornerRadius: 3).fill(farbe).frame(width: 14, height: 14).accessibilityHidden(true)
            Text(text).font(.subheadline).foregroundStyle(palette.text2).lineLimit(1)
        }
    }

    /// Detailzeile nach einem Tipp; die Hilfszeile davor verschwindet für immer nach dem ersten Tipp.
    @ViewBuilder private var detail: some View {
        if let tag = gewaehlt {
            let einheiten = sessions.filter { Datum.text($0.start) == tag }.sorted { $0.start < $1.start }
            VStack(alignment: .leading, spacing: 2) {
                Text(Datum.anzeige(tag)).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                if einheiten.isEmpty {
                    Text("Kein Training").font(.footnote).foregroundStyle(palette.text2)
                } else {
                    ForEach(einheiten) { s in
                        Text(zeile(s)).font(.footnote).foregroundStyle(palette.text2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        } else if !tippGesehen {
            Text("Tipp auf einen Tag zeigt das Training.").font(.footnote).foregroundStyle(palette.text2)
        }
    }

    /// "Push · 18:30 · 45 min · Brust": mit dem Namen der Kategorie, damit die Farbe nicht allein trägt.
    private func zeile(_ s: GymSession) -> String {
        let name = umgebung.daten?.training.tag(id: s.tag)?.name
        var text = KonsistenzLogik.zeile(s, name: name)
        if let id = KonsistenzKategorienLogik.kategorie(tagId: s.tag, name: name, einstellung: einstellung),
           let k = einstellung.kategorien.first(where: { $0.id == id }) {
            text += " · \(k.name)"
        }
        return text
    }

    // MARK: Jahr

    private func jahrBlock(_ j: KonsistenzLogik.Jahr, fuellungen: [String: KonsistenzFuellung], farben: [String: Color]) -> some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            Text(String(j.jahr)).font(.title3.bold()).foregroundStyle(palette.text)
            raster(j, fuellungen: fuellungen, farben: farben)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Raster \(j.jahr): \(j.trainingstage) Trainingstage, \(j.workouts) Workouts")
        .accessibilityChartDescriptor(FortschrittDeskriptor(
            titel: "Konsistenz \(j.jahr)", zusammenfassung: "\(j.trainingstage) Trainingstage, \(j.workouts) Workouts", xTitel: "Monat", yTitel: "Workouts",
            einheit: "", stetig: false,
            punkte: KonsistenzKarteLogik.monatsSummen(j).map { .init(x: $0.monat, y: Double($0.workouts)) }))
        .accessibilityAction(named: "Letzten Trainingstag zeigen") { gewaehlt = j.letzterTag }
    }

    private func raster(_ j: KonsistenzLogik.Jahr, fuellungen: [String: KonsistenzFuellung], farben: [String: Color]) -> some View {
        let gewaehlterTag = gewaehlt
        let neutral = GymFarbe.gruen(schema: schema, kontrast: kontrast)
        let farbenSatz = RasterFarben(leer: palette.haar, neutral: neutral, schrift: palette.text2, auswahl: palette.text, kategorien: farben)
        return GeometryReader { geo in
            Canvas { ctx, size in
                Self.zeichnen(j, in: &ctx, size: size, gewaehlt: gewaehlterTag, fuellungen: fuellungen, farben: farbenSatz)
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { wert in tippen(j, wert.location, breite: geo.size.width) })
        }
        .aspectRatio(KonsistenzLogik.verhaeltnis, contentMode: .fit)
    }

    private func tippen(_ j: KonsistenzLogik.Jahr, _ ort: CGPoint, breite: Double) {
        guard let t = KonsistenzLogik.treffer(x: ort.x, y: ort.y, breite: breite),
              let zelle = j.zelle(spalte: t.spalte, zeile: t.zeile), !zelle.zukunft else { return }
        tipp += 1
        tippGesehen = true
        gewaehlt = gewaehlt == zelle.tag ? nil : zelle.tag
    }

    private struct RasterFarben: Sendable {
        let leer: Color
        let neutral: Color
        let schrift: Color
        let auswahl: Color
        let kategorien: [String: Color]
    }

    nonisolated private static func zeichnen(_ j: KonsistenzLogik.Jahr, in ctx: inout GraphicsContext, size: CGSize, gewaehlt: String?,
                                             fuellungen: [String: KonsistenzFuellung], farben: RasterFarben) {
        let einheit = size.width / (KonsistenzLogik.beschriftung + Double(KonsistenzLogik.spalten))
        let x0 = KonsistenzLogik.beschriftung * einheit
        let y0 = KonsistenzLogik.kopf * einheit
        let seite = einheit * 0.82

        for m in j.monate {
            let text = Text(KonsistenzKarteLogik.monatName(m)).font(.system(size: 10)).foregroundStyle(farben.schrift)
            ctx.draw(text, at: CGPoint(x: x0 + Double(m.spalte) * einheit, y: 0), anchor: .topLeading)
        }
        for (zeile, name) in KonsistenzKarteLogik.wochentage {
            let text = Text(name).font(.system(size: 10)).foregroundStyle(farben.schrift)
            ctx.draw(text, at: CGPoint(x: 0, y: y0 + (Double(zeile) + 0.5) * einheit), anchor: .leading)
        }
        for spalte in 0..<KonsistenzLogik.spalten {
            for zeile in 0..<7 {
                guard let z = j.zelle(spalte: spalte, zeile: zeile) else { continue }
                let rect = CGRect(x: x0 + Double(spalte) * einheit, y: y0 + Double(zeile) * einheit, width: seite, height: seite)
                let pfad = Path(roundedRect: rect, cornerRadius: seite * 0.22)
                let fuellung: KonsistenzFuellung? = (z.zukunft || z.anzahl == 0) ? nil : (fuellungen[z.tag] ?? .neutral)
                ctx.fill(pfad, with: .color(farbe(fuellung, farben, zweite: false)))
                if case .zwei? = fuellung {
                    // Geteilte Zelle: obere rechte Hälfte (Diagonale von links oben nach rechts unten) in der zweiten Farbe.
                    var haelfte = Path()
                    haelfte.move(to: CGPoint(x: rect.minX, y: rect.minY))
                    haelfte.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                    haelfte.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    haelfte.closeSubpath()
                    let zweite = farbe(fuellung, farben, zweite: true)
                    ctx.drawLayer { layer in
                        layer.clip(to: pfad)
                        layer.fill(haelfte, with: .color(zweite))
                    }
                }
                if z.tag == gewaehlt {
                    ctx.stroke(Path(roundedRect: rect.insetBy(dx: -1, dy: -1), cornerRadius: seite * 0.3), with: .color(farben.auswahl), lineWidth: 1.5)
                }
            }
        }
    }

    nonisolated private static func farbe(_ f: KonsistenzFuellung?, _ farben: RasterFarben, zweite: Bool) -> Color {
        switch f {
        case nil: farben.leer
        case .neutral: farben.neutral
        case .eine(let id): farben.kategorien[id] ?? farben.neutral
        case .zwei(let a, let b): farben.kategorien[zweite ? b : a] ?? farben.neutral
        }
    }
}
