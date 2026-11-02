import SwiftUI
import UIKit

/// Der Heute-Tab: ruhiger Einstieg. Oben die Ringplatte als einzige mutige Karte, darunter Hinweise, Plan, Energie-Bank, Gewohnheiten,
/// Gewicht, Schritte und der Wochenstreifen. Die Partner-Karte erscheint nur mit Verbindung. Ohne Health zeigt er statt der Health-Karten einen Leerzustand
/// mit "Health erlauben"; Plan, Gewohnheiten und Gewicht gehen auch ohne.
struct HeuteTabView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var modell: HeuteModell?
    @State private var blatt: HeuteBlatt?
    @State private var start = 0
    @State private var habitSeite: String?
    @State private var tagGewechselt = 0
    /// Verschiebung und Deckkraft des Inhalts beim Tagwechsel: er gleitet in Wischrichtung hinaus und von der Gegenseite herein.
    @State private var versatz: CGFloat = 0
    @State private var deckkraft = 1.0
    @Namespace private var zoom
    @Environment(\.bewegungAus) private var bewegungAus
    @Environment(\.lumenAufbau) private var aufbau

    var body: some View {
        ScrollView {
            if let modell, let stand = modell.stand {
                // Die eine Wahl dieses Tabs: Lovea-Aufbau (Theme Lovea mit Freigabe) oder der heutige Aufbau.
                if aufbau == .lovea { loveaInhalt(stand, modell) } else { inhalt(stand, modell) }
            }
        }
        .navigationTitle(aufbau == .lovea ? "" : "Heute")
        .navigationBarTitleDisplayMode(aufbau == .lovea ? .inline : .automatic)
        .lumenHintergrund()
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AvatarKapsel() } }
        .sheet(item: $blatt) { blatt in
            if let stand = modell?.stand {
                blattInhalt(blatt, stand)
            }
        }
        .navigationDestination(item: $habitSeite) { id in
            HabitDetailView(habitId: id).navigationTransition(.zoom(sourceID: id, in: zoom))
        }
        .haptik(.start, bei: start)
        .haptik(.auswahl, bei: tagGewechselt)
        .task(id: umgebung.profil.aktiv?.id) {
            let m = modell ?? HeuteModell(umgebung: umgebung)
            modell = m
            m.berechne()
            await m.lade()
            await m.beobachte()
        }
    }

    private func inhalt(_ s: HeuteStand, _ m: HeuteModell) -> some View {
        // Karten zum Wegwischen (Hinweise) wischen selbst waagerecht: dann gilt die Tagwahl-Geste nur auf der Leiste, sonst auf der ganzen Seite.
        let ueberall = !s.istHeute || s.hinweise.isEmpty
        return VStack(spacing: Abstand.l) {
            HeuteTagLeiste(tag: s.tag, heute: Datum.text(umgebung.uhr()), blaettere: { blaettere($0) }, kalender: { blatt = .kalender },
                           zuHeute: { springe(zu: Datum.text(umgebung.uhr())) })
                .simultaneousGesture(tagWischen, including: ueberall ? .subviews : .all)
            VStack(spacing: Abstand.l) {
                if s.istHeute { heuteInhalt(s, m) } else { vergangenerTag(s, m) }
            }
            .id(s.tag)
            .offset(x: versatz)
            .opacity(deckkraft)
            .transition(.opacity)
        }
        .padding(.horizontal, Abstand.l)
        .padding(.bottom, Abstand.xl)
        .simultaneousGesture(tagWischen, including: ueberall ? .all : .subviews)
    }

    /// Der Aufbau von Lovea (`HeuteLoveaAufbau.swift`). Die Tagwahl wischt dort nur auf der Woche (eine Woche je Zug), der Inhalt gleitet beim Tagwechsel wie bisher.
    private func loveaInhalt(_ s: HeuteStand, _ m: HeuteModell) -> some View {
        HeuteLoveaInhalt(stand: s, modell: m, blaettere: { blaettere($0) }, springe: { springe(zu: $0) }, kalender: { blatt = .kalender },
                         oeffneBlatt: { blatt = $0 }, oeffneHabit: { habitSeite = $0 }, starte: { starte($0) }, zoom: zoom)
            .id(s.tag)
            .offset(x: versatz)
            .opacity(deckkraft)
            .transition(.opacity)
            .padding(.horizontal, 16)
            .padding(.bottom, Abstand.xl)
    }

    /// Waagerecht wischen: nach links der nächste Tag, nach rechts der Tag davor (nur ein langer, klar waagerechter Zug).
    private var tagWischen: some Gesture {
        DragGesture(minimumDistance: 30).onEnded { geste in
            guard let schritt = HeuteTagWahl.wischSchritt(breite: geste.translation.width, hoehe: geste.translation.height) else { return }
            blaettere(schritt)
        }
    }

    @ViewBuilder
    private func heuteInhalt(_ s: HeuteStand, _ m: HeuteModell) -> some View {
        if s.hatGesundheit {
            Ringplatte(stand: s, stufe: umgebung.daten?.meilensteine.stufe ?? 1)
        } else if s.healthGeprueft {
            HeuteLeerKarte(modell: m)
        }
        if !s.hinweise.isEmpty { HinweiseKarte(hinweise: s.hinweise) { m.wischeHinweis($0) } }
        if !s.einsichten.isEmpty { EinsichtenKarte(einsichten: s.einsichten) }
        PlanKarte(plan: s.plan) { starte(s.plan) }
        if s.hatGesundheit { EnergieBank(energie: s.energie) { blatt = .energie } }
        SchreibKarte(modell: m)
        if umgebung.router.coachSichtbar { CoachKachelView() }
        habitsKarte(s, m)
        GewichtKarte(gewicht: s.gewicht) { blatt = .gewicht }
        if s.hatGesundheit { SchritteKarte(schritte: s.schritte) { blatt = .schritte } }
        WochenStreifen(woche: s.woche) { blatt = .tag($0) }
        PartnerKarte(bereich: .heute)
    }

    /// Ein vergangener Tag: nur die Karten, die ihre Werte für genau diesen Tag haben. Plan, Hinweise, Energie von jetzt, Coach und Partner fehlen
    /// mit Absicht (sie gelten für heute). Gewohnheiten lassen sich nachtragen, weil der Speicher einen Tag entgegennimmt.
    @ViewBuilder
    private func vergangenerTag(_ s: HeuteStand, _ m: HeuteModell) -> some View {
        if s.hatTagesdaten {
            if s.hatGesundheit {
                Ringplatte(stand: s, stufe: umgebung.daten?.meilensteine.stufe ?? 1)
            }
            if let daten = umgebung.daten { HeuteTagZeilen(tag: s.tag, daten: daten) }
        } else {
            LeerZustand(stimmung: .schlaeft, satz: "Keine Daten für diesen Tag.")
        }
        habitsKarte(s, m)
        if s.hatTagesdaten { GewichtKarte(gewicht: s.gewicht, wiege: {}, eintragbar: false) }
    }

    private func habitsKarte(_ s: HeuteStand, _ m: HeuteModell) -> some View {
        HabitsKarte(habits: s.habits, tag: s.tag, tippe: { m.tippe($0) }, weniger: { m.weniger($0) }, oeffne: { habitSeite = $0.habit.id },
                    verwalte: { blatt = .habits }, zoom: zoom)
    }

    // MARK: - Tag wählen

    private func blaettere(_ tage: Int) {
        guard let s = modell?.stand else { return }
        springe(zu: HeuteTagWahl.schritt(s.tag, tage: tage, heute: Datum.text(umgebung.uhr())))
    }

    /// Wechselt den Tag mit Übergang: der Inhalt gleitet in Wischrichtung hinaus und von der Gegenseite herein (Feder). Reduce Motion und Stromsparmodus: Überblendung.
    private func springe(zu tag: String) {
        guard let m = modell, let s = m.stand else { return }
        let richtung = HeuteTagWahl.richtung(von: s.tag, nach: HeuteTagWahl.begrenze(tag, heute: Datum.text(umgebung.uhr())))
        guard richtung != 0 else { return }
        tagGewechselt += 1
        if bewegungAus {
            withAnimation(.easeInOut(duration: 0.2)) { m.waehleTag(tag) }
            return
        }
        withAnimation(.easeIn(duration: 0.12)) {
            versatz = CGFloat(-richtung) * 40
            deckkraft = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(130))
            versatz = CGFloat(richtung) * 40
            m.waehleTag(tag)
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(Feder.weich) {
                versatz = 0
                deckkraft = 1
            }
        }
    }

    @ViewBuilder
    private func blattInhalt(_ blatt: HeuteBlatt, _ s: HeuteStand) -> some View {
        switch blatt {
        case .energie: EnergieDetail(energie: s.energie) { modell?.speichereGefuehl($0) }
        case .schritte: SchritteDetailView()
        case .gewicht: NavigationStack { GewichtEintragenView().toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { self.blatt = nil } } } }
        case .habits: HabitVerwaltungView()
        case .tag(let tag): HeuteTagView(tag: tag)
        case .kalender:
            HeuteKalenderBlatt(tag: s.tag, heute: Datum.text(umgebung.uhr())) { springe(zu: $0) }
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
enum HeuteBlatt: Identifiable {
    case energie, schritte, gewicht, habits, kalender
    case tag(String)

    var id: String {
        switch self {
        case .energie: "energie"
        case .schritte: "schritte"
        case .gewicht: "gewicht"
        case .habits: "habits"
        case .kalender: "kalender"
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
