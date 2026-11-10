import SwiftUI
import UIKit

/// Die Startseite (Aufteilung B, Bild `home-*.png`): oben Plan für heute mit Start, dann die Woche (ohne Freunde und Partner), Gewohnheiten, Gewicht,
/// das letzte Training zum Nachlesen und unten die Ringplatte mit Lumi. Tagesform, Energie-Bank, Einsichten, Hinweise und die Schritte-Karte zeigt sie nicht mehr
/// (Code und Detailseiten bleiben, Schritte stehen im Profil). Ohne Health zeigt sie statt der Ringplatte einen Leerzustand mit "Health erlauben".
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

    var body: some View {
        ScrollView {
            if let modell, let stand = modell.stand {
                inhalt(stand, modell)
            }
        }
        .navigationTitle("Startseite")
        .navigationBarTitleDisplayMode(.automatic)
        .lumenHintergrund()
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
        // Die Hinweise-Karte (die einzige, die waagerecht wischte) steht nicht mehr auf der Startseite: die Tagwahl-Geste gilt auf der ganzen Seite.
        VStack(spacing: Abstand.l) {
            HeuteTagLeiste(tag: s.tag, heute: Datum.text(umgebung.uhr()), blaettere: { blaettere($0) }, kalender: { blatt = .kalender },
                           zuHeute: { springe(zu: Datum.text(umgebung.uhr())) })
                .simultaneousGesture(tagWischen, including: .subviews)
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
        .simultaneousGesture(tagWischen, including: .all)
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
        if s.bereiche.gymAn { PlanKarte(plan: s.plan) { starte(s.plan) } }
        WochenStreifen(woche: s.woche, bereiche: s.bereiche) { blatt = .tag($0) }
        habitsKarte(s, m)
        GewichtKarte(gewicht: s.gewicht) { blatt = .gewicht }
        if s.bereiche.gymAn, let letzte = letzteEinheit { LetzteEinheitKarte(einheit: letzte) }
        if s.hatGesundheit {
            Ringplatte(stand: s, stufe: umgebung.daten?.meilensteine.stufe ?? 1)
            // Energie und Tagesform bleiben erreichbar (nichts verschwindet ohne Wort des Besitzers), als eine Zeile statt der großen Karte.
            ListenKarte {
                Button { blatt = .energie } label: { ProfilListenZeile("Energie und Tagesform", symbol: "bolt.heart.fill") }
                    .buttonStyle(.plain)
            }
        } else if s.healthGeprueft {
            HeuteLeerKarte(modell: m)
        }
    }

    /// Das letzte beendete Training mit Daten; nil ohne.
    private var letzteEinheit: LetzteEinheit? {
        guard let training = umgebung.daten?.training else { return nil }
        return LetzteEinheitLogik.bauen(sessions: training.sessions) { training.tag(id: $0) }
    }

    /// Ein vergangener Tag: nur die Karten, die ihre Werte für genau diesen Tag haben. Plan, Hinweise, Energie von jetzt und Partner fehlen
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
