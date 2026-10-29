import Foundation

/// Schreibt `zusammenfassung.json` für Lovea (SPEC 5.5) und sendet danach die Darwin-Benachrichtigung. Der Inhalt kommt aus den Stores des aktiven
/// Profils und nur für die freigegebenen Datenarten (`ZusammenfassungBauer`, Standard keine). Ohne die Einstellung `loveaVerbunden` wird nichts geschrieben,
/// ohne Lovea-Gruppe (nil ohne Signierung) ebenso nicht. Liest nur Stores und Dateien, nie Health: der Abruf läuft auch bei gesperrtem Gerät.
@MainActor
final class LoveaBrueckeDienst {
    struct Quellen {
        var daten: @MainActor () -> DatenSatz?
        var gesundheit: GesundheitsStand
        var profilName: @MainActor () -> String?
    }

    /// Ohne Änderung wird die Datei trotzdem so oft erneuert, damit Lovea sie nie als veraltet (48 Stunden) sieht.
    nonisolated static let auffrischen: TimeInterval = 6 * 3600

    private let bruecke: any PartnerAustausch
    private let quellen: Quellen
    private let uhr: Uhr
    private let sende: (String) -> Void
    private var eigene: (profil: ProfilID, ereignisse: EigeneEreignisse)?
    private var letzte: ZusammenfassungDatei?

    init(bruecke: any PartnerAustausch, quellen: Quellen, uhr: @escaping Uhr = { Date() }, sende: @escaping (String) -> Void = DarwinKanal.sende) {
        self.bruecke = bruecke
        self.quellen = quellen
        self.uhr = uhr
        self.sende = sende
    }

    // MARK: Ereignisse des eigenen Profils

    /// Meldet ein eigenes Ereignis (Gym gestartet, beendet, Rekord): kommt in die nächste Datei, sofern die Art freigegeben ist.
    func ereignis(_ ereignis: Ereignis) {
        guard let daten = quellen.daten() else { return }
        let name = quellen.profilName() ?? "Profil"
        let jetzt = uhr()
        switch ereignis {
        case .trainingGestartet(let session):
            merke(PartnerEreignis(id: "gymStart-\(session)", art: .gymStart, zeit: jetzt, text: "\(name) ist im Gym"), daten)
        case .trainingBeendet(let session):
            merke(PartnerEreignis(id: "gymEnde-\(session)", art: .gymEnde, zeit: jetzt, text: "\(name) war im Gym"), daten)
        case .satzFertig(let session, let rekord) where rekord:
            merke(PartnerEreignis(id: "rekord-\(session)-\(Int(jetzt.timeIntervalSince1970))", art: .rekord, zeit: jetzt,
                                  text: "\(name) hat einen neuen Rekord"), daten)
        default:
            return
        }
    }

    private func merke(_ ereignis: PartnerEreignis, _ daten: DatenSatz) {
        eigeneEreignisse(daten).fuegeHinzu(ereignis, jetzt: uhr())
    }

    private func eigeneEreignisse(_ daten: DatenSatz) -> EigeneEreignisse {
        if let e = eigene, e.profil == daten.profil { return e.ereignisse }
        let neu = EigeneEreignisse(ordner: daten.ordner)
        eigene = (daten.profil, neu)
        letzte = nil
        return neu
    }

    // MARK: Datei

    /// Baut die Zusammenfassung und schreibt sie. `true`, wenn geschrieben wurde. Ohne Änderung nur nach `auffrischen`.
    @discardableResult
    func schreibe() -> Bool {
        guard let daten = quellen.daten(), daten.einstellungen.werte.loveaVerbunden else { return false }
        let jetzt = uhr()
        let heute = Datum.text(jetzt)
        let name = quellen.profilName() ?? "Profil"
        let tag = quellen.gesundheit.tage[heute]
        let nacht = quellen.gesundheit.naechte[heute]
        let ziele = daten.ziele.ziele
        let ereignisse = eigeneEreignisse(daten)
        if let s = tag?.schritte, s >= ziele.schritte, ziele.schritte > 0 {
            ereignisse.fuegeHinzu(PartnerEreignis(id: "ziel-\(heute)", art: .ziel, zeit: jetzt, text: "\(name) hat das Schrittziel erreicht"), jetzt: jetzt)
        }
        if let m = nacht?.schlafMinuten, m >= ziele.schlafMinuten, ziele.schlafMinuten > 0 {
            ereignisse.fuegeHinzu(PartnerEreignis(id: "schlafGut-\(heute)", art: .schlafGut, zeit: jetzt, text: "\(name) hat gut geschlafen"), jetzt: jetzt)
        }
        let eingabe = ZusammenfassungBauer.Eingabe(
            name: name, jetzt: jetzt, freigaben: daten.verbindung.freigaben, schritte: tag?.schritte,
            gymTageWoche: Self.gymTageDerWoche(daten.training.sessions, heute: heute), schlafMinuten: nacht?.schlafMinuten,
            kcal: Int(daten.essen.summe(heute).kcal.rounded()), ereignisse: ereignisse.liste)
        let datei = ZusammenfassungBauer.baue(eingabe)
        if let alt = letzte, Self.gleich(alt, datei), jetzt.timeIntervalSince(alt.geschrieben) < Self.auffrischen { return false }
        bruecke.schreibe(zusammenfassung: datei)
        letzte = datei
        sende(DarwinKanal.zusammenfassung)
        return true
    }

    /// Alles außer dem Zeitstempel gleich?
    nonisolated static func gleich(_ a: ZusammenfassungDatei, _ b: ZusammenfassungDatei) -> Bool {
        var x = a
        x.geschrieben = b.geschrieben
        return x == b
    }

    /// Tage dieser Woche (Montag bis heute) mit einer Einheit, in der etwas abgehakt ist.
    nonisolated static func gymTageDerWoche(_ sessions: [GymSession], heute: String) -> Int {
        let start = Datum.wochenstart(heute)
        return Set(sessions.filter { GymTageLogik.hatDaten($0) }.map { Datum.text($0.start) }.filter { $0 >= start && $0 <= heute }).count
    }
}
