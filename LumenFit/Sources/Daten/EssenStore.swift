// Quelle: Lovea Health/Ernaehrung/ErnaehrungModell.swift und Fasten.swift (Modell), ohne Person, Singleton, Netz, Live-Anzeige
import Foundation
import Observation

/// Tagebuch, eigene Lebensmittel, Rezepte, Favoriten, Körperwerte und Fasten des Profils.
/// Netz (Open Food Facts, Barcode-Kette) gehört dem Modul essen; Ernährungsziele liegen in `essen-ziele.json`.
@MainActor @Observable
final class EssenStore {
    @ObservationIgnored private let raum: LokalerRaum
    @ObservationIgnored private let ziele: ZieleStore
    @ObservationIgnored private let ereignisse: EreignisKanal?
    @ObservationIgnored private let uhr: Uhr
    @ObservationIgnored private let zieleDatei: JSONDatei<ErnaehrungsZiele>?
    private var faltung = ErnaehrungFaltung()
    private var fastenFaltung = FastenFaltung()
    private var gespeicherteZiele = ErnaehrungsZiele()

    /// Zehntel-kg je Tag aus dem Gewicht-Habit; `DatenSatz` verdrahtet es mit dem `HabitStore`.
    @ObservationIgnored var gewichtQuelle: @MainActor () -> [String: Int] = { [:] }
    /// Schreibt einen Habit-Wert (Protein-Habit abhaken); `DatenSatz` verdrahtet es mit dem `HabitStore`.
    @ObservationIgnored var habitSetzer: @MainActor (_ id: String, _ datum: String, _ wert: Int) -> Void = { _, _, _ in }
    /// Tageswerte (Zehntel) eines Habits, z. B. "mass.taille"; `DatenSatz` verdrahtet es mit dem `HabitStore`.
    @ObservationIgnored var massQuelle: @MainActor (_ id: String) -> [String: Int] = { _ in [:] }
    @ObservationIgnored var habitLeser: @MainActor (_ id: String, _ datum: String) -> Int = { _, _ in 0 }

    init(raum: LokalerRaum, ziele: ZieleStore, ordner: URL? = nil, ereignisse: EreignisKanal? = nil, uhr: @escaping Uhr = { Date() }) {
        self.raum = raum
        self.ziele = ziele
        self.ereignisse = ereignisse
        self.uhr = uhr
        zieleDatei = ordner.map { JSONDatei<ErnaehrungsZiele>($0.appendingPathComponent("essen-ziele.json")) }
        if let z = zieleDatei?.lade() { gespeicherteZiele = z }
        faltung = raum.falten(ErnaehrungFaltung.arten, ErnaehrungFaltung(), live: { [weak self] op in self?.faltung.anwenden(op) }) { $0.anwenden($1) }
        fastenFaltung = raum.falten(FastenFaltung.arten, FastenFaltung(), live: { [weak self] op in self?.fastenFaltung.anwenden(op) }) { $0.anwenden($1) }
    }

    var ich: ProfilID { raum.profil }

    // MARK: - Lesen

    func eintraege(_ tag: String) -> [EssenEintrag] { faltung.eintraege(ich, tag) }
    func eintraege(_ tag: String, _ m: Mahlzeit) -> [EssenEintrag] { eintraege(tag).filter { $0.mahlzeit == m } }
    func summe(_ tag: String) -> Naehrwerte { ErnaehrungLogik.summe(eintraege(tag)) }
    var tage: Set<String> { faltung.tage(ich) }
    var zuletzt: [Lebensmittel] { faltung.zuletzt(ich) }
    var haeufig: [Lebensmittel] { faltung.haeufig(ich) }
    func letzteMenge(_ l: Lebensmittel) -> (menge: Double, einheit: Einheit)? { faltung.letzteMenge(ich, l.id) }
    var eigene: [Lebensmittel] { faltung.eigeneLebensmittel }
    /// Rezept-Favoriten zeigen immer die aktuelle Fassung, gelöschte Rezepte fallen weg.
    var favoriten: [Lebensmittel] { faltung.favoritenListe(ich).compactMap { l in l.istRezept ? rezeptAktuell(l.id) : l } }
    func istFavorit(_ l: Lebensmittel) -> Bool { faltung.istFavorit(ich, l.id) }
    /// Wer das Lebensmittel oder Rezept zuerst angelegt hat; nil bei BLS und Open Food Facts.
    func ersteller(_ l: Lebensmittel) -> ProfilID? {
        l.istRezept ? faltung.ersteller(rezept: String(l.id.dropFirst("rezept-".count))) : faltung.ersteller(lebensmittel: l.id)
    }
    var rezepte: [Rezept] { faltung.rezepte }
    /// Für `rezept-…`-IDs die neueste Fassung als Lebensmittel, sonst nil.
    func rezeptAktuell(_ lebensmittelId: String) -> Lebensmittel? {
        guard lebensmittelId.hasPrefix("rezept-") else { return nil }
        let id = String(lebensmittelId.dropFirst("rezept-".count))
        return rezepte.first { $0.id == id }.map(ErnaehrungLogik.alsLebensmittel)
    }
    /// Rezept hinter einer `rezept-…`-ID, wenn es eine Mahlzeit ist.
    func mahlzeitVorlage(_ lebensmittelId: String) -> Rezept? {
        guard lebensmittelId.hasPrefix("rezept-") else { return nil }
        let id = String(lebensmittelId.dropFirst("rezept-".count))
        return rezepte.first { $0.id == id && $0.istMahlzeit }
    }
    var fasten: FastenD? { faltung.fasten(ich) }
    var anpassung: TagebuchAnpassung { faltung.anpassung(ich) }
    func mahlzeitName(_ m: Mahlzeit) -> String { anpassung.name(m) }
    /// Zehntel je Tag einer Messart: Habit-Werte und ältere Tagebuch-Werte (Op) zusammen, nichts doppelt. Gewicht ist die Gewicht-Reihe.
    func massReihe(_ art: MessArt) -> [String: Int] {
        guard let essenArt = art.essenArt else { return gewichtQuelle() }
        return Koerpermasse.reihe(habit: massQuelle(art.habitId), essen: faltung.koerperreihe(ich, essenArt))
    }

    func koerperwert(_ art: KoerperArt, bis tag: String) -> KoerperwertD? {
        massReihe(art.messArt).filter { $0.key <= tag }.max { $0.key < $1.key }
            .map { KoerperwertD(datum: $0.key, art: art, wert: Double($0.value) / 10, geloescht: nil) }
    }
    func offline(barcode: String) -> Lebensmittel? { faltung.lebensmittel(barcode: barcode, ich) }

    /// Gewicht (Zehntel-kg) an diesem Tag, sonst das letzte davor, mit Datum.
    func gewicht(bis tag: String) -> (zehntel: Int, datum: String)? {
        gewichtQuelle().filter { $0.value > 0 && $0.key <= tag }.max { $0.key < $1.key }.map { (zehntel: $0.value, datum: $0.key) }
    }

    /// Berechnetes Gewicht (`GewichtLogik`, wie die Health-Kachel), nil wenn nie eingetragen.
    var gewichtKg: Double? { GewichtLogik.berechnet(gewichtQuelle()).map { Double($0) / 10 } }

    /// Nie eingerichtet: aus dem Gewicht geschätzt (Standardwerte für den Rest), ohne Fragebogen.
    var ernaehrungsZiele: ErnaehrungsZiele {
        var z = gespeicherteZiele
        guard !z.eingerichtet else { return z }
        if ziele.koerper.geschlecht == .weiblich { z.geschlecht = 1 }
        return ErnaehrungLogik.berechnet(z, kg: gewichtKg ?? (z.geschlecht == 1 ? 62 : 78))
    }

    /// Ziele an einem bestimmten Tag (flexible Tage eingerechnet).
    func ernaehrungsZiele(tag: String) -> ErnaehrungsZiele { ernaehrungsZiele.fuer(tag: tag) }

    // MARK: - Schreiben

    /// `id` fest vorgeben, wenn ein anderer Teil der App den Eintrag später wiederfinden muss.
    func eintragen(_ l: Lebensmittel, menge: Double, einheit: Einheit, mahlzeit: Mahlzeit, datum: String, id: String = UUID().uuidString) {
        let e = EssenEintrag(id: id, datum: datum, mahlzeit: mahlzeit, menge: menge, einheit: einheit, lebensmittel: l, geloescht: nil)
        let vorher = summe(datum).protein
        raum.senden("essen.setzen", e)
        proteinPruefen(datum, protein: vorher + e.naehrwerte.protein)
        ereignisse?.senden(.mahlzeitGespeichert(tag: datum))
    }

    func aendern(_ e: EssenEintrag) {
        let ohne = eintraege(e.datum).filter { $0.id != e.id }
        raum.senden("essen.setzen", e)
        proteinPruefen(e.datum, protein: ErnaehrungLogik.summe(ohne).protein + e.naehrwerte.protein)
        ereignisse?.senden(.mahlzeitGespeichert(tag: e.datum))
    }

    func loeschen(_ e: EssenEintrag) {
        var weg = e
        weg.geloescht = true
        raum.senden("essen.setzen", weg)
        ereignisse?.senden(.mahlzeitGespeichert(tag: e.datum))
    }

    /// Alle Einträge einer Mahlzeit von einem anderen Tag noch einmal eintragen.
    func kopieren(von: String, nach: String, mahlzeit: Mahlzeit) {
        for e in eintraege(von, mahlzeit) {
            eintragen(e.lebensmittel, menge: e.menge, einheit: e.einheit, mahlzeit: mahlzeit, datum: nach)
        }
    }

    /// Gespeicherte Mahlzeit in einen Slot dieses Tags: ein Eintrag je Zutat, die Vorlage bleibt unverändert.
    func mahlzeitEintragen(_ r: Rezept, mahlzeit: Mahlzeit, datum: String) {
        for e in ErnaehrungLogik.eintraege(r, mahlzeit: mahlzeit, datum: datum) {
            eintragen(e.lebensmittel, menge: e.menge, einheit: e.einheit, mahlzeit: mahlzeit, datum: datum, id: e.id)
        }
    }

    func kopieren(_ r: Rezept) {
        var neu = r
        neu.id = UUID().uuidString
        rezeptSichern(neu)
    }

    func kopieren(_ l: Lebensmittel) {
        var neu = l
        neu.id = "eigen-\(UUID().uuidString)"
        eigenesSichern(neu)
    }

    func eigenesSichern(_ l: Lebensmittel) { raum.senden("lebensmittel.setzen", LebensmittelD(lebensmittel: l, geloescht: nil)) }
    func eigenesLoeschen(_ l: Lebensmittel) { raum.senden("lebensmittel.setzen", LebensmittelD(lebensmittel: l, geloescht: true)) }
    func favoritSetzen(_ l: Lebensmittel, an: Bool) { raum.senden("lebensmittel.favorit", FavoritD(lebensmittel: l, an: an)) }
    func rezeptSichern(_ r: Rezept) { raum.senden("rezept.setzen", r) }

    func rezeptLoeschen(_ r: Rezept) {
        var weg = r
        weg.geloescht = true
        raum.senden("rezept.setzen", weg)
    }

    func anpassungSichern(_ a: TagebuchAnpassung) { raum.senden("food.anpassung", a) }

    /// Schreibt in den Habit-Wert der Messart (derselbe Ort wie "Messung erfassen"); Werte außerhalb des Bereichs werden nicht gespeichert.
    func koerperwertSetzen(_ art: KoerperArt, _ wert: Double, datum: String) {
        let zehntel = Int((wert * 10).rounded())
        guard art.messArt.erlaubt.contains(zehntel) else { return }
        habitSetzer(art.messArt.habitId, datum, zehntel)
    }

    /// Das Gewicht liegt im Gewicht-Habit (Zehntel-kg), damit Heute und Fortschritt dieselbe Reihe lesen.
    func gewichtSetzen(zehntel: Int, datum: String) {
        habitSetzer(Habit.gewicht.id, datum, max(0, zehntel))
        ereignisse?.senden(.gewichtGespeichert(tag: datum))
    }

    func fastenStarten(_ start: Date? = nil) { raum.senden("fasten.setzen", FastenD(start: start ?? uhr(), ende: nil)) }
    func fastenBeenden() { raum.senden("fasten.setzen", FastenD(start: nil, ende: uhr())) }

    /// Speichert alle Ernährungsziele und markiert sie als eingerichtet.
    func zieleSichern(_ z: ErnaehrungsZiele) {
        var neu = z
        neu.eingerichtet = true
        gespeicherteZiele = neu
        zieleDatei?.speichere(neu)
    }

    // MARK: - Fasten (Port von FastenModell)

    var fastenEintraege: [FastenEintrag] { fastenFaltung.eintraege(ich) }
    var fastenLaufend: FastenEintrag? { fastenFaltung.laufend(ich) }
    var fastenPlan: FastenPlan { fastenFaltung.plan(ich) }

    func fastenPlanSetzen(_ plan: FastenPlan) { raum.senden("fasten.plan", FastenPlanD(plan: plan.rawValue)) }

    func fastenFensterStarten(_ start: Date? = nil) {
        raum.senden("fasten.eintrag", FastenEintrag(id: UUID().uuidString, start: start ?? uhr(), ende: nil, plan: fastenPlan.rawValue, geloescht: nil))
    }

    func fastenFensterBeenden(_ eintrag: FastenEintrag, ende: Date? = nil) {
        var neu = eintrag
        neu.ende = ende ?? uhr()
        raum.senden("fasten.eintrag", neu)
    }

    func fastenAendern(_ eintrag: FastenEintrag) { raum.senden("fasten.eintrag", eintrag) }

    func fastenLoeschen(_ eintrag: FastenEintrag) {
        var weg = eintrag
        weg.geloescht = true
        raum.senden("fasten.eintrag", weg)
    }

    /// Hakt das Protein-Habit ab, sobald das Protein-Ziel des Tages erreicht ist. Nie wieder ab.
    private func proteinPruefen(_ datum: String, protein: Double) {
        guard protein >= Double(ernaehrungsZiele(tag: datum).protein), habitLeser(Habit.protein.id, datum) == 0 else { return }
        habitSetzer(Habit.protein.id, datum, 1)
    }
}
