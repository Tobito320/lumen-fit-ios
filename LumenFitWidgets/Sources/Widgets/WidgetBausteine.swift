import SwiftUI
import WidgetKit

// Gemeinsame Bausteine der Widgets. Das Widget-Ziel kompiliert nur `Gemeinsam` und `LumenFitWidgets`: nichts aus der App, und es liest nur `widget-stand.json`.
// Getönt (accented) und vibrant: Flächen, Muster, Datenfarben und Lumi entfallen, nur Text und Symbole bleiben (`widgetRenderingMode`).

/// Ein Eintrag aller Widgets: der Snapshot der Gruppe (nil = die Datei fehlt, dann zeigen die Widgets ihren ruhigen Leerzustand) und der Zeitpunkt.
struct SnapshotEintrag: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// Ein gemeinsamer Anbieter für alle Widgets: sie zeigen alle denselben Snapshot, nur anders angeordnet. Neu geladen wird spätestens nach der nächsten
/// Berliner Mitternacht, damit "heute" nicht auf dem alten Tag stehen bleibt; die App lädt bei jeder Änderung selbst neu.
struct SnapshotAnbieter: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEintrag {
        SnapshotEintrag(date: Date(), snapshot: WidgetSnapshot.beispiel())
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEintrag) -> Void) {
        completion(context.isPreview ? SnapshotEintrag(date: Date(), snapshot: WidgetSnapshot.beispiel()) : Self.aktuell())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEintrag>) -> Void) {
        let eintrag = Self.aktuell()
        // Zweiter Eintrag zur Mitternacht: das System zeichnet ihn selbst, "heute" und "morgen" stimmen auch, wenn das Neuladen sich verspätet.
        let mitternacht = WidgetAnzeige.naechsteMitternacht(eintrag.date)
        let danach = SnapshotEintrag(date: mitternacht, snapshot: eintrag.snapshot)
        completion(Timeline(entries: [eintrag, danach], policy: .after(mitternacht)))
    }

    private static func aktuell() -> SnapshotEintrag {
        SnapshotEintrag(date: Date(), snapshot: WidgetSnapshotDatei.lade())
    }
}

/// Die Farben eines Widgets aus Theme und Modus. Datenfarben nur in der Tief-Variante (Kontrast mindestens 4,5:1); getönt nimmt das System die Farbe.
struct WidgetFarben {
    let thema: ThemaID
    let dunkel: Bool
    let vollfarbe: Bool
    let grund: Color
    let text: Color
    let text2: Color
    let akzent: Color
    let bewegen: Color
    let trainieren: Color
    let erholen: Color

    static func bau(thema: ThemaID, erscheinung: Erscheinung?, systemDunkel: Bool, kontrastHoch: Bool, modus: WidgetRenderingMode) -> WidgetFarben {
        let dunkel = WidgetAnzeige.dunkel(erscheinung: erscheinung, system: systemDunkel)
        let p = LumenFarben.palette(thema: thema, dunkel: dunkel, kontrastHoch: kontrastHoch)
        let voll = modus == .fullColor
        func daten(_ b: Datenbereich) -> Color { voll ? LumenFarben.tief(b, dunkel: dunkel, kontrastHoch: kontrastHoch) : .primary }
        return WidgetFarben(thema: thema, dunkel: dunkel, vollfarbe: voll, grund: p.grund, text: voll ? p.text : .primary, text2: voll ? p.text2 : .secondary,
                            akzent: voll ? p.akzent : .primary, bewegen: daten(.bewegen), trainieren: daten(.trainieren), erholen: daten(.erholen))
    }

    func daten(_ bereich: Datenbereich) -> Color {
        switch bereich {
        case .bewegen: bewegen
        case .trainieren: trainieren
        case .erholen: erholen
        }
    }

    /// Schrift auf einer Fläche in Trainieren-Tief: dunkel bei dem hellen Grün im Dunkelmodus, sonst weiß.
    var aufTrainieren: Color { vollfarbe ? (dunkel ? .black : .white) : Color(white: 0) }
}

/// Der Hintergrund: einfarbig Token `grund` (ohne Muster).
struct WidgetHintergrund: View {
    let farben: WidgetFarben

    var body: some View { farben.grund }
}

/// Rahmen jedes Widgets: Farben aus Theme und Modus, Hintergrund über `containerBackground` (getönt ersetzt ihn das System), Link beim Tippen.
struct WidgetRahmen<Inhalt: View>: View {
    let snapshot: WidgetSnapshot?
    let link: URL?
    let inhalt: (WidgetFarben) -> Inhalt
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast
    @Environment(\.widgetRenderingMode) private var modus

    init(snapshot: WidgetSnapshot?, link: URL?, @ViewBuilder inhalt: @escaping (WidgetFarben) -> Inhalt) {
        self.snapshot = snapshot
        self.link = link
        self.inhalt = inhalt
    }

    var body: some View {
        let farben = WidgetFarben.bau(thema: snapshot?.thema ?? .monochrom, erscheinung: snapshot?.erscheinung, systemDunkel: schema == .dark,
                                      kontrastHoch: kontrast == .increased, modus: modus)
        inhalt(farben)
            .widgetURL(link)
            .containerBackground(for: .widget) { WidgetHintergrund(farben: farben) }
    }
}

/// Ruhiger Leerzustand: Lumi (nur in Vollfarbe), ein Satz, was zu tun ist.
struct WidgetLeerAnsicht: View {
    let farben: WidgetFarben
    var titel = String(localized: "Noch keine Werte")
    var text = String(localized: "Öffne Lumen Fit einmal, dann erscheinen sie hier.")

    var body: some View {
        VStack(spacing: 6) {
            if farben.vollfarbe {
                LumiView(stimmung: .bereit, groesse: 40)
            } else {
                Image(systemName: "figure.walk").font(.title).foregroundStyle(farben.text).widgetAccentable()
            }
            Text(titel).font(.footnote.weight(.semibold)).foregroundStyle(farben.text)
            Text(text).font(.caption).foregroundStyle(farben.text2).lineLimit(3)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(titel). \(text)")
    }
}

/// Drei offene 270-Grad-Bögen (Öffnung unten, runde Enden) mit Spur, innen nach außen: Bewegen, Trainieren, Erholen. Die Zahl steht daneben oder in der Mitte,
/// nie nur die Farbe (Symbol und Zahl tragen die Aussage). Eigene kleine Fassung, weil `LumenBogen` für die große Platte gebaut ist (feste Größe, weiße Schrift).
struct WidgetBoegen: View {
    let werte: [BogenWert]
    let farben: WidgetFarben
    var strich: CGFloat = 8
    var abstand: CGFloat = 3

    var body: some View {
        ZStack {
            ForEach(Array(werte.enumerated()), id: \.element.id) { index, wert in
                WidgetBogenSpur(anteil: wert.anteil, farbe: farben.daten(wert.id), strich: strich, spur: farben.vollfarbe ? farben.daten(wert.id).opacity(0.22) : .secondary.opacity(0.3))
                    .padding(CGFloat(index) * (strich + abstand) + strich / 2)
            }
        }
    }
}

/// Spur (voller Bogen, blass) und Wert (Anteil des Bogens, runde Enden). 270 Grad, Öffnung unten.
private struct WidgetBogenSpur: View {
    let anteil: Double
    let farbe: Color
    let strich: CGFloat
    let spur: Color

    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: 0.75).stroke(spur, style: StrokeStyle(lineWidth: strich, lineCap: .round))
            Circle().trim(from: 0, to: 0.75 * min(max(anteil, 0), 1)).stroke(farbe, style: StrokeStyle(lineWidth: strich, lineCap: .round))
                .widgetAccentable()
        }
        .rotationEffect(.degrees(135))
    }
}

/// Waagerechter Balken (Essen ist monochrom).
struct WidgetBalken: View {
    let anteil: Double
    let farbe: Color
    let spur: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(spur)
                Capsule().fill(farbe).frame(width: geo.size.width * min(max(anteil, 0), 1)).widgetAccentable()
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}
