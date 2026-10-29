import SwiftUI
import UIKit

/// Der Heute-Tab: ruhiger Einstieg. Oben die Ringplatte als einzige mutige Karte, darunter Bereit-Score, Hinweise, Plan, Energie-Bank, Gewohnheiten,
/// Gewicht, Schritte und der Wochenstreifen. Die Partner-Karte erscheint nur mit Verbindung. Ohne Health zeigt er statt der Health-Karten einen Leerzustand
/// mit "Health erlauben"; Plan, Gewohnheiten und Gewicht gehen auch ohne.
struct HeuteTabView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var modell: HeuteModell?
    @State private var blatt: HeuteBlatt?
    @State private var start = 0

    var body: some View {
        ScrollView {
            if let modell, let stand = modell.stand {
                inhalt(stand, modell)
            }
        }
        .navigationTitle("Heute")
        .lumenHintergrund()
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AvatarKapsel() } }
        .sheet(item: $blatt) { blatt in
            if let stand = modell?.stand {
                blattInhalt(blatt, stand)
            }
        }
        .haptik(.start, bei: start)
        .task(id: umgebung.profil.aktiv?.id) {
            let m = modell ?? HeuteModell(umgebung: umgebung)
            modell = m
            m.berechne()
            await m.lade()
            await m.beobachte()
        }
    }

    @ViewBuilder
    private func inhalt(_ s: HeuteStand, _ m: HeuteModell) -> some View {
        VStack(spacing: Abstand.l) {
            if s.hatGesundheit {
                Ringplatte(stand: s, stufe: umgebung.daten?.meilensteine.stufe ?? 1)
                ScoreKarte(score: s.score) { blatt = .score }
            } else if s.healthGeprueft {
                HeuteLeerKarte(modell: m)
            }
            if !s.hinweise.isEmpty { HinweiseKarte(hinweise: s.hinweise) { m.wischeHinweis($0) } }
            PlanKarte(plan: s.plan) { starte(s.plan) }
            if s.hatGesundheit { EnergieBank(energie: s.energie) { blatt = .energie } }
            HabitsKarte(habits: s.habits, tippe: { m.tippe($0) }, weniger: { m.weniger($0) }, verwalte: { blatt = .habits })
            GewichtKarte(gewicht: s.gewicht) { blatt = .gewicht }
            if s.hatGesundheit { SchritteKarte(schritte: s.schritte) { blatt = .schritte } }
            WochenStreifen(woche: s.woche) { blatt = .tag($0) }
            PartnerKarte(bereich: .heute)
        }
        .padding(.horizontal, Abstand.l)
        .padding(.bottom, Abstand.xl)
    }

    @ViewBuilder
    private func blattInhalt(_ blatt: HeuteBlatt, _ s: HeuteStand) -> some View {
        switch blatt {
        case .score: BereitScoreDetail(score: s.score)
        case .energie: EnergieDetail(energie: s.energie) { modell?.speichereGefuehl($0) }
        case .schritte: SchritteDetailView()
        case .gewicht: NavigationStack { GewichtEintragenView().toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { self.blatt = nil } } } }
        case .habits: HabitVerwaltungView()
        case .tag(let tag): HeuteTagView(tag: tag)
        }
    }

    /// Der Knopf der Plan-Karte: Training starten (Modul gym), ohne Plan in den Plan-Bereich.
    private func starte(_ plan: HeutePlan) {
        if plan.art == .keinPlan {
            umgebung.router.oeffne(.gym(.plaene))
        } else {
            umgebung.trainingSteuerung.starte(planTag: plan.tagID)
            start += 1
        }
    }
}

/// Welches Blatt über dem Heute-Tab liegt.
private enum HeuteBlatt: Identifiable {
    case score, energie, schritte, gewicht, habits
    case tag(String)

    var id: String {
        switch self {
        case .score: "score"
        case .energie: "energie"
        case .schritte: "schritte"
        case .gewicht: "gewicht"
        case .habits: "habits"
        case .tag(let tag): "tag-\(tag)"
        }
    }
}

/// Leerzustand ohne Health: Lumi, ein Satz, eine Handlung. Zeigt Health nach dem Versuch immer noch nichts, führt der Knopf in die Einstellungen.
struct HeuteLeerKarte: View {
    let modell: HeuteModell
    @State private var versucht = false
    @Environment(\.openURL) private var oeffneURL

    var body: some View {
        LeerZustand(
            stimmung: .denkt,
            satz: versucht
                ? "Ich sehe noch nichts. Erlaube Lumen Fit in den Einstellungen unter Health den Zugriff auf Schritte und Schlaf."
                : "Ich sehe noch keine Health-Daten. Erlaube Health, dann füllen sich deine Bögen.",
            handlung: versucht ? "Einstellungen öffnen" : "Health erlauben"
        ) {
            if versucht {
                if let url = URL(string: UIApplication.openSettingsURLString) { oeffneURL(url) }
            } else {
                Task {
                    _ = await modell.healthErlauben()
                    versucht = true
                }
            }
        }
    }
}
