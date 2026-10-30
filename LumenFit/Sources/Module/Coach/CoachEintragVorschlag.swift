import Foundation

// Eintrags-Marker des Coachs als Vorschlag: `[[wasser: 250]]`, `[[supplement: Kreatin]]`, `[[gefuehl: schlaf | gut]]`, `[[gewicht: 81,3]]`,
// `[[essen: ...]]` und `[[mahlzeit: ...]]`, die Gedächtnis-Marker `merke`, `aendere`, `vergiss` und die Training-Marker (`CoachTrainingMarker`).
// Anders als in Lovea trägt der Coach hier nie von selbst ein: der Chat zeigt "Eintragen?" mit Bestätigen und Verwerfen, erst danach
// laufen die Stores. Danach steht eine Karte "Eingetragen" mit Rückgängig. Die Rechnung ist rein, geschrieben wird in `speichern`.

extension CoachTracking {
    enum Eintrag: Equatable, Sendable {
        /// Gläser zu 250 ml, wie das Wasser-Habit sie zählt.
        case wasser(glaeser: Int)
        /// Ein Klick = 3,5 g (`Habit.creatinGramm`).
        case kreatin(klicks: Int)
        case schlafGefuehl(CoachMarker.Gefuehl)
        /// Setzt den Tageswert (kein Addieren): zwei Gewichte einer Antwort, das letzte gilt.
        case gewicht(kg: Double)
        case mahlzeit(CoachMarker.MahlzeitDaten)
        case merke(String)
        case aendere(id: String, text: String)
        case vergiss(id: String)
        /// Ein Training-Marker; was er bewirkt, plant `CoachTrainingMarker` erst beim Speichern gegen den Stand der Einheit.
        case training(CoachMarker.Art)
    }

    /// Eine Zeile der Karte. Mit `route` ein Knopf in die Seite dazu, bei Gedächtnis-Zeilen öffnet ein Tipp die Liste.
    struct Zeile: Equatable, Sendable {
        let text: String
        let symbol: String
        let route: Route?
        let oeffnetGedaechtnis: Bool

        init(text: String, symbol: String, route: Route? = nil, oeffnetGedaechtnis: Bool = false) {
            self.text = text
            self.symbol = symbol
            self.route = route
            self.oeffnetGedaechtnis = oeffnetGedaechtnis
        }
    }

    /// Milliliter eines Glases im Wasser-Habit.
    nonisolated static let glasMl = 250

    /// Habit-Id des Schlafgefühls (wie in Lovea); nur der Coach liest sie.
    nonisolated static let schlafGefuehlId = "schlafgefuehl"

    nonisolated static func glaeser(ml: Int) -> Int { max(1, Int((Double(ml) / Double(glasMl)).rounded())) }

    /// Gramm auf Klicks, mindestens einer.
    nonisolated static func klicks(gramm: Double) -> Int { max(1, Int((gramm / Habit.creatinGramm).rounded())) }

    /// Gewicht in Zehntel-Kilo, wie das Gewicht-Habit es speichert (81,3 kg = 813).
    nonisolated static func zehntel(kg: Double) -> Int { Int((kg * 10).rounded()) }

    /// Die Mahlzeit, die zu einer Uhrzeit passt, wenn der Coach keine nennt.
    nonisolated static func mahlzeit(stunde: Int) -> Mahlzeit {
        switch stunde {
        case 5..<11: .fruehstueck
        case 11..<16: .mittag
        case 16..<22: .abend
        default: .snack
        }
    }

    /// Die kurze Form `essen` als volle Mahlzeit; fehlende Nährwerte sind 0.
    nonisolated static func mahlzeit(aus e: CoachMarker.Essen, stunde: Int) -> CoachMarker.MahlzeitDaten {
        CoachMarker.MahlzeitDaten(mahlzeit: e.art ?? mahlzeit(stunde: stunde), name: e.name, kcal: e.kcal, eiweiss: e.protein ?? 0,
                                  kohlenhydrate: e.kohlenhydrate ?? 0, fett: e.fett ?? 0, zucker: nil)
    }

    /// Gleiche Marker einer Antwort werden zusammengezählt (zwei Gläser = ein Eintrag), Gefühl und Gewicht zählen einmal (das letzte gilt).
    nonisolated static func eintraege(_ marker: [CoachMarker.Art], stunde: Int) -> [Eintrag] {
        var ml = 0
        var gramm = 0.0
        var gefuehl: CoachMarker.Gefuehl?
        var kilo: Double?
        var mahlzeiten: [CoachMarker.MahlzeitDaten] = []
        var gedaechtnis: [Eintrag] = []
        for art in marker {
            switch art {
            case .wasser(let m): ml += m
            case .kreatin(let g): gramm += g
            case .schlafGefuehl(let g): gefuehl = g
            case .gewicht(let kg): kilo = kg
            case .mahlzeit(let d): mahlzeiten.append(d)
            case .essen(let e): mahlzeiten.append(mahlzeit(aus: e, stunde: stunde))
            case .merke(let t): gedaechtnis.append(.merke(t))
            case .aendere(let id, let text): gedaechtnis.append(.aendere(id: id, text: text))
            case .vergiss(let id): gedaechtnis.append(.vergiss(id: id))
            default: break
            }
        }
        var liste: [Eintrag] = []
        if ml > 0 { liste.append(.wasser(glaeser: glaeser(ml: ml))) }
        if gramm > 0 { liste.append(.kreatin(klicks: klicks(gramm: gramm))) }
        if let kilo { liste.append(.gewicht(kg: kilo)) }
        if let gefuehl { liste.append(.schlafGefuehl(gefuehl)) }
        liste.append(contentsOf: mahlzeiten.map { Eintrag.mahlzeit($0) })
        liste.append(contentsOf: gedaechtnis)
        liste.append(contentsOf: CoachTrainingMarker.geordnet(marker).map { Eintrag.training($0) })
        return liste
    }

    /// Die Zeile eines Eintrags, vor dem Speichern (Vorschlag) und danach (Karte). Training: `stand` nennt die Übung beim Namen.
    nonisolated static func zeile(_ e: Eintrag, stand: CoachTrainingMarker.Stand? = nil) -> Zeile {
        switch e {
        case .wasser(let n):
            return Zeile(text: "Wasser +\(n) \(n == 1 ? "Glas" : "Gläser") (\(n * glasMl) ml)", symbol: "drop.fill", route: .heute)
        case .kreatin(let n):
            let gramm = String(format: "%.1f", Double(n) * Habit.creatinGramm).replacingOccurrences(of: ".", with: ",")
            return Zeile(text: "Creatin +\(n) \(n == 1 ? "Klick" : "Klicks") (\(gramm) g)", symbol: "pills.fill", route: .heute)
        case .schlafGefuehl(let g):
            return Zeile(text: "Schlafgefühl \(g.rawValue)", symbol: "bed.double.fill", route: .schlaf(.letzteNacht))
        case .gewicht(let kg):
            return Zeile(text: "Gewicht \(String(format: "%.1f", kg).replacingOccurrences(of: ".", with: ",")) kg", symbol: Habit.gewicht.symbol, route: .gewichtEintragen)
        case .mahlzeit(let d):
            // "ca.": die Werte sind eine Schätzung des Coachs, der Chat-Text nennt sie auch so.
            return Zeile(text: "\(d.mahlzeit.name): \(kurz(d.name)), ca. \(d.kcal) kcal", symbol: "fork.knife", route: .essen(.heute))
        case .merke(let t):
            return Zeile(text: "Merken: \(kurz(t))", symbol: "brain.head.profile", oeffnetGedaechtnis: true)
        case .aendere(_, let t):
            return Zeile(text: "Gedächtnis ändern: \(kurz(t))", symbol: "brain.head.profile", oeffnetGedaechtnis: true)
        case .vergiss(let id):
            return Zeile(text: "Vergessen: \(kurz(id))", symbol: "brain.head.profile", oeffnetGedaechtnis: true)
        case .training(let art):
            return Zeile(text: CoachTrainingMarker.vorschlagText(art, stand: stand), symbol: "figure.strengthtraining.traditional", route: .gym(.training))
        }
    }

    /// Eine Zeile der Karte bleibt kurz: ab 60 Zeichen mit Auslassung.
    nonisolated static func kurz(_ text: String) -> String { text.count > 60 ? String(text.prefix(59)) + "…" : text }

    /// Das Ergebnis von `speichern`: die Zeilen der Karte und der Weg zurück (in umgekehrter Reihenfolge ausführen).
    struct Gespeichert {
        var zeilen: [Zeile] = []
        var zurueck: [@MainActor () -> Void] = []
        /// Eine Mahlzeit oder Wasser war dabei (für Hinweise, die sonst doppelt zählen würden).
        var wasserDabei = false
        var essenDabei = false
    }

    /// Schreibt über die Stores des Profils (Wasser in Gläsern, Creatin in Klicks, Gewicht in Zehntel-Kilo, Mahlzeit ins Tagebuch,
    /// Gedächtnis, Training). Der Tag ist der von `jetzt`. Was nicht greift (Training ohne Einheit, unbekannter Eintrag), erzeugt keine Zeile.
    @MainActor
    static func speichern(_ liste: [Eintrag], daten: DatenSatz, gedaechtnis: CoachGedaechtnis, jetzt: Date) -> Gespeichert {
        let heute = Datum.text(jetzt)
        var erg = Gespeichert()
        for e in liste {
            switch e {
            case .wasser(let n):
                let vorher = daten.habits.wert(Habit.wasser.id, heute)
                daten.habits.setzeWasser(datum: heute, anzahl: vorher + n)
                erg.zurueck.append { daten.habits.setzeWasser(datum: heute, anzahl: vorher) }
                erg.wasserDabei = true
            case .kreatin(let klicks):
                let vorher = daten.habits.wert(Habit.creatin.id, heute)
                daten.habits.setze(Habit.creatin.id, datum: heute, wert: vorher + klicks)
                erg.zurueck.append { daten.habits.setze(Habit.creatin.id, datum: heute, wert: vorher) }
            case .schlafGefuehl(let g):
                // Wert 1 bis 3, 0 = keins.
                let vorher = daten.habits.wert(schlafGefuehlId, heute)
                daten.habits.setze(schlafGefuehlId, datum: heute, wert: g.wert)
                erg.zurueck.append { daten.habits.setze(schlafGefuehlId, datum: heute, wert: vorher) }
            case .gewicht(let kg):
                // Tageswert in Zehntel-Kilo, dieselbe Op wie der Gewicht-Bildschirm; 0 beim Zurücknehmen = kein Wert.
                let vorher = daten.habits.wert(Habit.gewicht.id, heute)
                daten.essen.gewichtSetzen(zehntel: zehntel(kg: kg), datum: heute)
                erg.zurueck.append { daten.essen.gewichtSetzen(zehntel: vorher, datum: heute) }
            case .mahlzeit(let d):
                // Feste Id, damit Rückgängig genau diesen Eintrag findet.
                let neu = essenEintrag(d, datum: heute)
                daten.essen.eintragen(neu.lebensmittel, menge: neu.menge, einheit: neu.einheit, mahlzeit: neu.mahlzeit, datum: neu.datum, id: neu.id)
                erg.zurueck.append { daten.essen.loeschen(neu) }
                erg.essenDabei = true
            case .merke(let text):
                guard let sauber = gedaechtnis.hinzufuegen(text) else { continue }
                erg.zurueck.append { gedaechtnis.loeschen(sauber) }
            case .aendere(let id, let text):
                guard let alt = CoachGedaechtnisRegeln.finde(id, in: gedaechtnis.eintraege), gedaechtnis.aendern(alt, zu: text),
                      let neu = CoachGedaechtnisRegeln.einzeilig(text) else { continue }
                erg.zurueck.append { gedaechtnis.aendern(neu, zu: alt) }
            case .vergiss(let id):
                guard let alt = CoachGedaechtnisRegeln.finde(id, in: gedaechtnis.eintraege) else { continue }
                gedaechtnis.loeschen(alt)
                erg.zurueck.append { gedaechtnis.wiederherstellen(alt) }
                erg.zeilen.append(Zeile(text: "Vergessen: \(kurz(alt))", symbol: "brain.head.profile", oeffnetGedaechtnis: true))
                continue
            case .training(let art):
                // Passt der Marker nicht (keine Einheit, unbekannte Id, gegen die Regeln der App), geschieht nichts und es gibt keine Zeile.
                guard let ergebnis = CoachTrainingMarker.ausfuehren(art, daten: daten, jetzt: jetzt) else { continue }
                erg.zurueck.append(ergebnis.zurueck)
                erg.zeilen.append(Zeile(text: ergebnis.text, symbol: ergebnis.symbol, route: .gym(.training)))
                continue
            }
            erg.zeilen.append(zeile(e))
        }
        return erg
    }

    /// Der Tagebuch-Eintrag (eine Portion) in der Mahlzeit, die der Coach gewählt hat. Die Werte gelten für eine Portion.
    nonisolated static func essenEintrag(_ d: CoachMarker.MahlzeitDaten, datum: String, id: String = UUID().uuidString) -> EssenEintrag {
        let l = Lebensmittel(id: "schnell-\(UUID().uuidString)", name: d.name,
                             pro100: Naehrwerte(kcal: Double(d.kcal), protein: d.eiweiss, kohlenhydrate: d.kohlenhydrate, fett: d.fett, zucker: d.zucker),
                             portionMenge: 100, portionName: "Eintrag")
        return EssenEintrag(id: id, datum: datum, mahlzeit: d.mahlzeit, menge: 1, einheit: .portion, lebensmittel: l, geloescht: nil)
    }
}
