/// Langes Drücken auf eine Coach-Antwort (W-003, ruhigere Antworten): Kopieren, Teilen, Merken und bei der letzten Antwort "Neu fragen".
/// Unter der Antwort stehen nur noch die Daumen.
enum CoachAntwortMenue {
    enum Punkt: Hashable, Sendable { case kopieren, teilen, merken(gemerkt: Bool), nochmal }

    static func punkte(letzte: Bool, gemerkt: Bool, denkt: Bool, pausiert: Bool) -> [Punkt] {
        var p: [Punkt] = [.kopieren, .teilen, .merken(gemerkt: gemerkt)]
        if letzte, !denkt, !pausiert { p.append(.nochmal) }
        return p
    }
}
