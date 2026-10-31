import Foundation

/// Der Zählerstand des Bands über die Zeit (Tagessumme der Schritte), wie Loveas `WeckerAblauf.SchrittVerlauf`: jede neue Probe sagt, wie viele Schritte seit der
/// ersten Probe im Fenster dazukamen. Fällt der Zähler zurück (neuer Tag, neues Band), fängt der Verlauf neu an: aus einem Rücksetzen werden nie Schritte.
/// Die erste Probe ist nur der Ausgangspunkt.
struct BandSchrittVerlauf: Equatable, Sendable {
    struct Probe: Equatable, Sendable {
        let zeit: Date
        let summe: Int
    }

    /// Wie weit zurück (Sekunden) Proben zählen.
    let fenster: TimeInterval
    private(set) var proben: [Probe] = []

    init(fenster: TimeInterval) { self.fenster = fenster }

    mutating func aufnehmen(summe: Int, zeit: Date) -> Int {
        if let letzte = proben.last, summe < letzte.summe { proben = [] }
        proben.append(Probe(zeit: zeit, summe: summe))
        proben.removeAll { zeit.timeIntervalSince($0.zeit) > fenster }
        return summe - (proben.first?.summe ?? summe)
    }
}

/// Zählt im Weckfenster von Lumen Alarm die Schritte am Band und meldet "aufgestanden" (Vertrag mit Lumen Alarm, Abschnitt 3). Das Fenster gilt ab der Weckzeit,
/// solange Wünsche dieser Weckzeit offen sind (oder `bisAufgewacht` gesetzt ist, höchstens 90 Minuten) und `schritteNoetig` über 0 liegt. Alle 30 Sekunden
/// kommt eine Probe; die erste ist der Ausgangspunkt. Jede Probe schreibt `band-schritte.json`. Bei genug Schritten steht dort `aufgestanden`, die Wünsche der
/// Weckzeit gelten als erledigt und der Darwin-Name `band-aufgestanden` geht raus. Außerhalb des Fensters läuft nichts (kein Timer, keine Bluetooth-Frage).
@MainActor
final class AufstehWaechter {
    nonisolated static let probeAbstand: TimeInterval = 30
    /// So lange wartet die Probe nach der Frage ans Band auf die Antwort.
    nonisolated static let wartezeit: TimeInterval = 4
    /// Längstes Fenster nach der Weckzeit (Ende des Plans mit "bis aufgewacht").
    nonisolated static let fensterMaximal: TimeInterval = 90 * 60

    private let uhr: Uhr
    private let fenster: @MainActor () -> [WeckFenster]
    private let offen: @MainActor (String) -> Bool
    private let lesen: @MainActor () -> Bool
    private let stand: @MainActor () -> (summe: Int, zeit: Date)?
    private let bisher: @MainActor () -> BandSchritteDatei?
    private let schreibe: @MainActor (BandSchritteDatei) -> Void
    private let aufgestanden: @MainActor (WeckFenster) -> Void
    private let warte: @Sendable (TimeInterval) async -> Void

    private var aufgabe: Task<Void, Never>?
    private var laeuftFuer: Date?
    private var nummer = 0
    private var verlauf = BandSchrittVerlauf(fenster: fensterMaximal)
    private var schritte = 0
    private var erreicht: Set<Date> = []

    /// `lesen`: fragt das Band (false: nicht bereit). `stand`: Tagessumme und Zeit der letzten Antwort. `offen`: gibt es noch offene Wünsche mit dieser Id-Vorsilbe?
    init(uhr: @escaping Uhr, fenster: @escaping @MainActor () -> [WeckFenster], offen: @escaping @MainActor (String) -> Bool,
         lesen: @escaping @MainActor () -> Bool, stand: @escaping @MainActor () -> (summe: Int, zeit: Date)?,
         bisher: @escaping @MainActor () -> BandSchritteDatei?, schreibe: @escaping @MainActor (BandSchritteDatei) -> Void,
         aufgestanden: @escaping @MainActor (WeckFenster) -> Void,
         warte: @escaping @Sendable (TimeInterval) async -> Void = { _ = try? await Task.sleep(for: .seconds($0)) }) {
        self.uhr = uhr
        self.fenster = fenster
        self.offen = offen
        self.lesen = lesen
        self.stand = stand
        self.bisher = bisher
        self.schreibe = schreibe
        self.aufgestanden = aufgestanden
        self.warte = warte
    }

    /// Das Fenster, das jetzt zählt (die früheste Weckzeit zuerst), sonst nil. Rein, damit es ohne Band testbar ist.
    static func aktives(_ liste: [WeckFenster], jetzt: Date, offen: @MainActor (String) -> Bool) -> WeckFenster? {
        liste.sorted { $0.weckzeit < $1.weckzeit }.first { f in
            guard f.schritteNoetig > 0, jetzt >= f.weckzeit, jetzt.timeIntervalSince(f.weckzeit) < fensterMaximal else { return false }
            return f.bisAufgewacht || offen(f.idPraefix)
        }
    }

    /// Aufruf nach jedem Verarbeiten der Wünsche (Start, Vordergrund, Darwin, Takt): startet oder beendet das Zählen.
    func anstossen() {
        guard let f = Self.aktives(fenster(), jetzt: uhr(), offen: offen), !erreicht.contains(f.weckzeit) else { stoppe(); return }
        if let datei = bisher(), datei.weckzeit == f.weckzeit, datei.aufstanden {
            erreicht.insert(f.weckzeit)
            stoppe()
            return
        }
        if aufgabe != nil, laeuftFuer == f.weckzeit { return }
        stoppe()
        laeuftFuer = f.weckzeit
        verlauf = BandSchrittVerlauf(fenster: Self.fensterMaximal)
        schritte = 0
        nummer += 1
        let meine = nummer
        aufgabe = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let ich = self else { return }
                if await ich.probe(f) { break }
                let pause = ich.warte
                await pause(Self.probeAbstand)
                guard !Task.isCancelled, let weiter = self, weiter.nummer == meine,
                      Self.aktives(weiter.fenster(), jetzt: weiter.uhr(), offen: weiter.offen)?.weckzeit == f.weckzeit else { break }
            }
            if let ich = self, ich.nummer == meine {
                ich.aufgabe = nil
                ich.laeuftFuer = nil
            }
        }
    }

    func stoppe() {
        aufgabe?.cancel()
        aufgabe = nil
        laeuftFuer = nil
    }

    /// Eine Probe: Band fragen, kurz warten, die frische Tagessumme in den Verlauf. true, wenn genug Schritte da sind.
    func probe(_ f: WeckFenster) async -> Bool {
        let frage = uhr()
        if lesen() {
            let pause = warte
            await pause(Self.wartezeit)
        }
        if let s = stand(), s.zeit >= frage { schritte = verlauf.aufnehmen(summe: s.summe, zeit: s.zeit) }
        // Ohne eine einzige Antwort des Bands gibt es nichts zu melden.
        guard !verlauf.proben.isEmpty else { return false }
        let genug = schritte >= f.schritteNoetig
        schreibe(BandSchritteDatei(version: LoveaVertrag.version, geschrieben: uhr(), weckzeit: f.weckzeit, schritte: schritte, aufgestanden: genug))
        if genug {
            erreicht.insert(f.weckzeit)
            aufgestanden(f)
        }
        return genug
    }
}
