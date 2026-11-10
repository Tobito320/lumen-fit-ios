import Foundation
import Observation

/// Der Ablauf der Einführung (Entwurf 10.11.2026): Willkommen, Name (ohne Passwort), "Hat dich jemand eingeladen?", dann acht Fragen mit du
/// (Erfahrung, Ziele, Orte, Tage, Minuten, Fokus-Muskeln, Mitzählen), die Nutzungsfrage, Health und am Ende "Dein Plan steht".
/// Alles Eingegebene bleibt hier im Speicher. Das Profil entsteht erst mit "Los geht's" auf der letzten Karte: `AppRootView` wechselt sofort zu den Tabs,
/// sobald es ein aktives Profil gibt, und würde die Karten sonst mitten im Ausfüllen wegnehmen.
/// `nochmal` (Präferenzen > "Einführung nochmal ansehen"): nur die Fragen und der Plan, kein neues Profil, der Plan nur nach Rückfrage.
@MainActor @Observable
final class ProfilOnboardingFluss {
    enum Karte: Int, CaseIterable, Sendable {
        case willkommen, profil, einladung, erfahrung, ziele, orte, tage, minuten, fokus, mitzaehlen, nutzung, health, plan

        /// Die acht Fragen des Entwurfs (mit "Überspringen"); der Plan ist die achte.
        var istFrage: Bool { (Karte.erfahrung.rawValue...Karte.mitzaehlen.rawValue).contains(rawValue) }
    }

    let nochmal: Bool
    let karten: [Karte]
    private(set) var karte: Karte
    var name = ""
    /// Code oder Link eines Freundes (freiwillig); eingelöst wird nach dem Anlegen (das Konto braucht ein Profil).
    var einladung = ""
    var gymTage = ProfilPraeferenzLogik.standardTage
    /// Alle Antworten samt Bereichen; `setzeBereich` lässt den letzten Bereich nie ausschalten.
    var wahl = Einstellungen()
    private(set) var healthAngefragt = false
    /// Die Antwort auf die Frage nach der Nutzungsmeldung; ohne Antwort geht es auf dieser Karte nicht weiter, vorgewählt ist nichts. Health hängt nie daran.
    private(set) var nutzung: NutzungAntwort = .offen
    private(set) var fehler: String?
    /// Der Plan aus den Antworten, gerechnet beim Betreten der letzten Karte (nicht beim Zeichnen).
    private(set) var plan: SplitVorlage?

    init(nochmal: Bool = false, start: Einstellungen = Einstellungen(), gymTage: Int = ProfilPraeferenzLogik.standardTage) {
        self.nochmal = nochmal
        let liste = nochmal ? Karte.allCases.filter { $0.istFrage || $0 == .plan } : Karte.allCases
        karten = liste
        karte = liste[0]
        wahl = start
        self.gymTage = gymTage
    }

    var anzahl: Int { karten.count }
    var index: Int { karten.firstIndex(of: karte) ?? 0 }
    /// "Schritt 2 von 13" für VoiceOver.
    var stand: String { String(localized: "Schritt \(index + 1) von \(anzahl)") }
    /// Anteil für den Balken oben (ohne die Willkommen-Karte).
    var anteil: Double { Double(index + 1) / Double(anzahl) }
    var istLetzte: Bool { karte == karten.last }

    var nameGueltig: Bool { if case .success = NamenRegel.pruefe(name) { true } else { false } }
    /// Leer ist erlaubt (niemand hat eingeladen); sonst muss es ein Code oder Link von Lumen Fit sein.
    var einladungGueltig: Bool { einladungLeer || VerbindungenLogik.einladung(aus: einladung) != nil }
    var einladungLeer: Bool { einladung.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var kannWeiter: Bool {
        switch karte {
        case .profil: nameGueltig
        case .einladung: einladungGueltig
        case .erfahrung: wahl.trainingsErfahrung != nil
        case .nutzung: nutzung != .offen
        default: true
        }
    }

    /// Zielart für Kalorien und Protein aus den gewählten Zielen.
    var art: Zielart { ProfilPraeferenzLogik.zielart(wahl.trainingsZiele) }

    /// Hält die Antwort fest und geht zur nächsten Karte.
    func antworteNutzung(_ antwort: NutzungAntwort) {
        nutzung = antwort
        weiter()
    }

    /// Einfachauswahl (Erfahrung): ein Tipp wählt und geht weiter.
    func waehleErfahrung(_ e: TrainingsErfahrung) {
        wahl.trainingsErfahrung = e
        weiter()
    }

    /// "Weiß ich nicht, nimm den Vorschlag": setzt die Empfehlung der Frage und geht weiter.
    func nimmVorschlag() {
        switch karte {
        case .ziele: wahl.trainingsZiele = [.muskeln]
        case .orte: wahl.trainingsOrte = [.studio]
        case .tage: gymTage = ProfilPraeferenzLogik.standardTage
        case .minuten: wahl.trainingsMinuten = ProfilPraeferenzLogik.standardMinuten
        default: break
        }
        weiter()
    }

    var hatVorschlag: Bool { [.ziele, .orte, .tage, .minuten].contains(karte) }

    /// Schaltet einen Bereich der Auswahl; false, wenn es der letzte eingeschaltete wäre.
    @discardableResult
    func setzeBereich(_ bereich: AppBereich, an: Bool) -> Bool { wahl.setze(bereich, an: an) }

    /// Wohin die App nach dem Einrichten geht, wenn kein Plan übernommen wird: mit Gym zu den Plänen, sonst bleibt es bei Heute.
    var startRoute: Route? { wahl.gymAn ? .gym(.plaene) : nil }

    func weiter() {
        guard kannWeiter, index + 1 < karten.count else { return }
        gehe(zu: karten[index + 1])
    }

    /// "Überspringen" auf einer Frage: die übrigen Fragen behalten ihre Standardwerte.
    func ueberspringe() {
        guard karte.istFrage, let naechste = karten.first(where: { $0.rawValue > Karte.mitzaehlen.rawValue }) else { return }
        gehe(zu: naechste)
    }

    func zurueck() {
        guard index > 0 else { return }
        gehe(zu: karten[index - 1])
    }

    private func gehe(zu neu: Karte) {
        fehler = nil
        karte = neu
        if neu == .plan { rechnePlan() }
    }

    private func rechnePlan() {
        plan = ProfilPraeferenzLogik.plan(wahl, tage: gymTage, geschlecht: nil)
    }

    /// Fragt Health nur für die gewählten Bereiche (das System zeigt sein Blatt nur beim ersten Mal). Ohne Zwang: "Später" legt das Profil ohne diese Frage an.
    func healthFragen(leser: any HealthLeser) async {
        _ = await leser.zugriff(fuer: wahl.healthTypen)
        healthAngefragt = true
    }

    /// Hinweis zum Namensfeld (nil, solange nichts getippt ist oder alles passt); gleiche Regel wie beim Ändern.
    var nameHinweis: String? { Self.nameHinweis(name) }

    static func nameHinweis(_ name: String) -> String? {
        guard !name.isEmpty, case .failure(let f) = NamenRegel.pruefe(name) else { return nil }
        return NamenRegel.text(f)
    }

    /// Legt das Profil an und schreibt Ziele, Einstellungen und (mit `planUebernehmen`) den Plan in einem Schritt. false mit `fehler`, wenn es nicht ging.
    @discardableResult
    func abschliessen(in umgebung: AppUmgebung, planUebernehmen: Bool = false) -> Bool {
        beende(Result { try umgebung.profil.anlegen(name: name, passwort: "") }, in: umgebung, planUebernehmen: planUebernehmen)
    }

    /// Wie `abschliessen`, aber abseits des Hauptthreads (die Oberfläche hängt nicht). Die Oberfläche nutzt diese.
    @discardableResult
    func abschliessenImHintergrund(in umgebung: AppUmgebung, planUebernehmen: Bool) async -> Bool {
        let ergebnis: Result<Profil, Error>
        do { ergebnis = .success(try await umgebung.profil.anlegenImHintergrund(name: name, passwort: "")) } catch { ergebnis = .failure(error) }
        return beende(ergebnis, in: umgebung, planUebernehmen: planUebernehmen)
    }

    private func beende(_ ergebnis: Result<Profil, Error>, in umgebung: AppUmgebung, planUebernehmen: Bool) -> Bool {
        if case .failure(let grund) = ergebnis {
            switch grund as? ProfilFehler {
            case .nameLeer:
                fehler = String(localized: "Wie soll Lumi dich nennen?")
                karte = .profil
            case .nameUngueltig(let f):
                fehler = NamenRegel.text(f)
                karte = .profil
            case .nichtErlaubt:
                fehler = String(localized: "Weitere Profile sind auf diesem iPhone nicht möglich.")
            default:
                fehler = String(localized: "Das Profil konnte nicht gespeichert werden. Versuch es nochmal.")
            }
            return false
        }
        guard let daten = umgebung.daten else { return false }
        let jetzt = umgebung.uhr()
        let ziele = ProfilZielVorschlag.vorschlag(koerper: Koerperdaten(), art: art, gymTage: gymTage, kg: nil, jahr: ProfilZielSpeicher.jahr(jetzt))
        ProfilZielSpeicher.sichere(ziele: ziele, koerper: Koerperdaten(), in: daten, jahr: ProfilZielSpeicher.jahr(jetzt))
        let angefragt = healthAngefragt
        let gewaehlt = wahl
        let antwort = nutzung
        let tag = Datum.text(jetzt)
        daten.einstellungen.aendere {
            $0.antworteNutzung(antwort, tag: tag)
            $0.healthGefragt = angefragt
            $0.gymAn = gewaehlt.gymAn
            $0.essenAn = gewaehlt.essenAn
            $0.schlafAn = gewaehlt.schlafAn
            Self.uebernimmAntworten(gewaehlt, in: &$0)
        }
        if planUebernehmen, let plan { daten.training.planSichern(SplitLogik.alsPlan(plan)) }
        return true
    }

    /// "Einführung nochmal ansehen": schreibt nur die Antworten und die Tage, legt kein Profil an. Den Plan ersetzt die Oberfläche erst nach Rückfrage.
    func sichereNochmal(in umgebung: AppUmgebung) {
        guard let daten = umgebung.daten else { return }
        let gewaehlt = wahl
        daten.einstellungen.aendere { Self.uebernimmAntworten(gewaehlt, in: &$0) }
        // Bereiche über den gewohnten Weg (Health nachfragen); erst einschalten, dann aus, damit nie keiner an ist.
        let bisher = daten.einstellungen.werte
        for an in [true, false] {
            for b in AppBereich.allCases where gewaehlt.zeigt(b) == an && bisher.zeigt(b) != an { ProfilBereiche.schalte(b, an: an, in: umgebung) }
        }
        var ziele = daten.ziele.ziele
        if ziele.gymTageProWoche != gymTage {
            ziele.gymTageProWoche = gymTage
            daten.ziele.setze(ziele)
        }
    }

    /// Die Antworten der Fragen (ohne Bereiche, Nutzung, Health).
    private static func uebernimmAntworten(_ von: Einstellungen, in e: inout Einstellungen) {
        e.trainingsErfahrung = von.trainingsErfahrung
        e.trainingsZiele = von.trainingsZiele
        e.trainingsOrte = von.trainingsOrte
        e.trainingsMinuten = von.trainingsMinuten ?? ProfilPraeferenzLogik.standardMinuten
        e.fokusMuskeln = von.fokusMuskeln
        e.gewichtMitzaehlen = von.gewichtMitzaehlen
        e.schritteMitzaehlen = von.schritteMitzaehlen
        e.creatinMitzaehlen = von.creatinMitzaehlen
    }

    /// Nach dem Anlegen: der Code eines Freundes, bereit für das Blatt "Verbinden" (`VerbindungScanBlatt`). nil ohne gültigen Code.
    var einladungZumEinloesen: String? { VerbindungenLogik.einladung(aus: einladung) }
}

/// Für `fullScreenCover(item:)` in den Präferenzen.
extension ProfilOnboardingFluss: Identifiable {}
