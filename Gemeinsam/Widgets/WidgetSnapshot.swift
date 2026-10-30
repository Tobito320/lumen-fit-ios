import Foundation

/// Stand für die Widgets, geschrieben von der App als `widget-stand.json` im Gruppenordner (`WidgetsModul`), gelesen von den Widgets und der Live Activity.
/// Alle Felder sind optional und werden einzeln und nachsichtig gelesen: eine ältere oder neuere Datei bleibt lesbar, ein unbekannter Wert wird zu "fehlt".
/// Es gehört immer dem aktiven Profil; `tag` ist der Tag, für den die "heute"-Werte gelten (nach Mitternacht zeigen die Widgets sie nicht mehr als heutig).
struct WidgetSnapshot: Codable, Equatable, Sendable {
    var geschrieben: Date?
    var profilName: String?
    /// `ProfilID.rawValue`: damit das Widget beim Abhaken sagt, für wen die Op gilt.
    var profilKennung: String?
    var tag: String?
    var thema: ThemaID?
    var erscheinung: Erscheinung?
    /// Lumis Stimmung heute (Op `fit.lumi.stimmung`), sonst `bereit`.
    var lumi: LumiStimmung?
    var lumiStufe: Int?
    var boegen: WidgetBoegenWerte?
    /// Der nächste Trainingstag laut Plan.
    var plan: WidgetPlanTag?
    /// Wochen in Folge mit mindestens einem Training.
    var serieWochen: Int?
    var essen: WidgetEssenStand?
    var habits: [WidgetHabitKachel]?
    /// Die sieben Tage (Montag bis Sonntag) der Woche von `tag` mit Gym (Einheit oder Haken).
    var gymWoche: [WidgetGymTag]?
    /// Was der verbundene Partner freigibt (Gym-Duell, Schritte-Duell); nil ohne Verbindung.
    var partner: WidgetPartnerStand?

    init(geschrieben: Date? = nil, profilName: String? = nil, profilKennung: String? = nil, tag: String? = nil, thema: ThemaID? = nil,
         erscheinung: Erscheinung? = nil, lumi: LumiStimmung? = nil, lumiStufe: Int? = nil, boegen: WidgetBoegenWerte? = nil,
         plan: WidgetPlanTag? = nil, serieWochen: Int? = nil, essen: WidgetEssenStand? = nil, habits: [WidgetHabitKachel]? = nil,
         gymWoche: [WidgetGymTag]? = nil, partner: WidgetPartnerStand? = nil) {
        self.geschrieben = geschrieben; self.profilName = profilName; self.profilKennung = profilKennung; self.tag = tag
        self.thema = thema; self.erscheinung = erscheinung; self.lumi = lumi; self.lumiStufe = lumiStufe; self.boegen = boegen
        self.plan = plan; self.serieWochen = serieWochen; self.essen = essen; self.habits = habits
        self.gymWoche = gymWoche; self.partner = partner
    }

    private enum CodingKeys: String, CodingKey {
        case geschrieben, profilName, profilKennung, tag, thema, erscheinung, lumi, lumiStufe, boegen, plan, serieWochen, essen, habits, gymWoche, partner
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        geschrieben = try? c.decodeIfPresent(Date.self, forKey: .geschrieben)
        profilName = try? c.decodeIfPresent(String.self, forKey: .profilName)
        profilKennung = try? c.decodeIfPresent(String.self, forKey: .profilKennung)
        tag = try? c.decodeIfPresent(String.self, forKey: .tag)
        thema = try? c.decodeIfPresent(ThemaID.self, forKey: .thema)
        erscheinung = try? c.decodeIfPresent(Erscheinung.self, forKey: .erscheinung)
        lumi = try? c.decodeIfPresent(LumiStimmung.self, forKey: .lumi)
        lumiStufe = try? c.decodeIfPresent(Int.self, forKey: .lumiStufe)
        boegen = try? c.decodeIfPresent(WidgetBoegenWerte.self, forKey: .boegen)
        plan = try? c.decodeIfPresent(WidgetPlanTag.self, forKey: .plan)
        serieWochen = try? c.decodeIfPresent(Int.self, forKey: .serieWochen)
        essen = try? c.decodeIfPresent(WidgetEssenStand.self, forKey: .essen)
        habits = try? c.decodeIfPresent([WidgetHabitKachel].self, forKey: .habits)
        gymWoche = try? c.decodeIfPresent([WidgetGymTag].self, forKey: .gymWoche)
        partner = try? c.decodeIfPresent(WidgetPartnerStand.self, forKey: .partner)
    }
}

/// Die Werte hinter den drei Bögen (Bewegen, Trainieren, Erholen) von heute. Rohwerte statt fertiger Texte: das Widget formatiert selbst.
struct WidgetBoegenWerte: Codable, Equatable, Sendable {
    var schritte: Int?
    var schritteZiel: Int?
    /// Verschiedene Tage mit Training in dieser Woche (Montag bis Sonntag).
    var trainingTage: Int?
    var trainingZiel: Int?
    /// Schlaf der letzten Nacht in Minuten.
    var schlafMinuten: Int?
    var schlafZiel: Int?
    /// Letzte HRV in Millisekunden (Erholung auf dem Sperrbildschirm).
    var hrv: Int?
}

/// Der nächste Trainingstag: Name aus dem Plan und sein Datum (`yyyy-MM-dd`). "Heute" oder "morgen" rechnet das Widget selbst, damit es über Mitternacht stimmt.
struct WidgetPlanTag: Codable, Equatable, Sendable {
    var name: String
    var tag: String
}

/// Kalorien und Protein von heute gegen die Ziele.
struct WidgetEssenStand: Codable, Equatable, Sendable {
    var kcal: Int
    var kcalZiel: Int
    var protein: Int
    var proteinZiel: Int
}

/// Eine Gewohnheit zum Abhaken. `heute` ist der Wert für `WidgetSnapshot.tag`; `ziel` ist das Tagesziel zählender Gewohnheiten (sonst 1).
struct WidgetHabitKachel: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var symbol: String
    var zaehlen: Bool
    var ziel: Int
    var heute: Int
    var serie: Int
}

/// Ein Tag der Gym-Woche (`tag` = `yyyy-MM-dd`).
struct WidgetGymTag: Codable, Equatable, Sendable {
    var tag: String
    var erledigt: Bool
}

/// Was der Partner freigegeben hat, fürs Widget. Jedes Feld steht nur mit der Freigabe seiner Art (`aus`); `tag` ist der Tag der Partner-Datei,
/// Schritte und Schlaf gelten nur, wenn er der heutige ist.
struct WidgetPartnerStand: Codable, Equatable, Sendable {
    var name: String
    var tag: String
    var schritte: Int?
    var schritteZiel: Int?
    /// Tage der laufenden Woche mit Gym; leer heißt "freigegeben, aber keiner", nil heißt "nicht geteilt".
    var gymTage: [String]?
    var gymZiel: Int?
    var schlafMinuten: Int?
    var schlafZiel: Int?

    static func aus(_ d: ZusammenfassungDatei) -> WidgetPartnerStand {
        let frei = Set(d.freigaben)
        let h = d.heute
        return WidgetPartnerStand(
            name: d.profilName, tag: h.tag,
            schritte: frei.contains(.schritte) ? h.schritte : nil, schritteZiel: frei.contains(.schritte) ? h.schritteZiel : nil,
            gymTage: frei.contains(.gym) ? (h.gymTage ?? (h.gymTageWoche == 0 ? [] : nil)) : nil, gymZiel: frei.contains(.gym) ? h.gymZiel : nil,
            schlafMinuten: frei.contains(.schlaf) ? h.schlafMinuten : nil, schlafZiel: frei.contains(.schlaf) ? h.schlafZiel : nil)
    }
}

/// Lesen und Schreiben der Datei. Ohne Gruppenordner (Tests, unsignierter Simulator) gilt der Ordner, den der Aufrufer nennt: nie ein Absturz.
enum WidgetSnapshotDatei {
    nonisolated static let name = "widget-stand.json"

    static func datei(ordner: URL) -> JSONDatei<WidgetSnapshot> { JSONDatei(ordner.appendingPathComponent(name)) }

    /// nil, wenn die Datei fehlt oder kaputt ist (die Widgets zeigen dann ihren ruhigen Leerzustand).
    static func lade(ordner: URL = AppGruppe.ordner()) -> WidgetSnapshot? { datei(ordner: ordner).lade() }

    @discardableResult
    static func schreibe(_ snapshot: WidgetSnapshot, ordner: URL) -> Bool { datei(ordner: ordner).speichere(snapshot) }
}
