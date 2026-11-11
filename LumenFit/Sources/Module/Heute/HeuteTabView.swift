import SwiftUI
import UIKit

/// Der Tab Heute (neues Design 10.11.2026, Bild `dark-home.png`/`light-home.png`): großer Gruß nach Tageszeit, die Ringplatte mit Lumi (Tipp auf Schritte öffnet
/// die Schritte-Seite) und Lumis Fortschritts-Satz, die Karte "Plan für heute" mit der Woche (heute in der Mitte, Tipp öffnet das Tag-Blatt), eine kompakte
/// Karte der mitgezählten Gewohnheiten und die Gewicht-Karte (Eintragen, Ziel, Alle Einträge). Ohne Health steht statt der Ringplatte "Health erlauben".
/// Umgeordnet (Lückenliste 2.1, nichts gestrichen): Tagwahl, vergangene Tage und Nachtragen im Tag-Blatt (`HeuteTagView`); Energie und Tagesform
/// (`HeuteEnergieSeite`) und das letzte Training (`LetzteEinheitKarte`) gehören nach Fortschritt; Schritte über die Ringplatte. Ist Gym aus, trägt der
/// alte Wochenstreifen die Woche (Tag-Blatt bleibt erreichbar).
struct HeuteTabView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var modell: HeuteModell?
    @State private var blatt: HeuteBlatt?
    @State private var start = 0
    @State private var habitSeite: String?
    @State private var einheit: String?
    @State private var alleEintraege = false
    @State private var sitzung: GymSitzung?
    @State private var toast: ToastInhalt?
    @State private var erledigt = 0
    @Namespace private var zoom
    @Environment(\.bewegungAus) private var bewegungAus

    var body: some View {
        ScrollView {
            if let modell, let stand = modell.stand {
                inhalt(stand, modell)
            }
        }
        .navigationTitle(modell?.stand.map { HeuteKartenLogik.gruss(stunde: $0.stunde) } ?? String(localized: "Heute"))
        .navigationBarTitleDisplayMode(.large)
        .lumenHintergrund()
        .sheet(item: $blatt, onDismiss: { modell?.berechne() }) { blatt in
            if let stand = modell?.stand {
                blattInhalt(blatt, stand)
            }
        }
        .navigationDestination(item: $habitSeite) { id in
            HabitDetailView(habitId: id).navigationTransition(.zoom(sourceID: id, in: zoom))
        }
        .navigationDestination(item: $einheit) { EinheitNachlesenView(sessionId: $0) }
        .navigationDestination(isPresented: $alleEintraege) { PartnerKoerperWeiche { MessungenView() } }
        .haptik(.start, bei: start)
        .haptik(.erfolg, bei: erledigt)
        .lumenToast($toast)
        .task(id: umgebung.profil.aktiv?.id) {
            let m = modell ?? HeuteModell(umgebung: umgebung)
            modell = m
            if sitzung == nil { sitzung = GymSitzung.von(umgebung) }
            m.berechne()
            await m.lade()
            await m.beobachte(rechnen: false)
        }
    }

    private func inhalt(_ s: HeuteStand, _ m: HeuteModell) -> some View {
        VStack(spacing: Abstand.l) {
            if s.hatGesundheit {
                Ringplatte(stand: s, stufe: umgebung.daten?.meilensteine.stufe ?? 1) { blatt = .schritte }
            } else if s.healthGeprueft {
                HeuteLeerKarte(modell: m)
            }
            if let v = s.verpasst, sitzung?.sessionId == nil {
                GymVerpasstKarte(verpasst: v, nachtragen: { blatt = .nachtragen(v) }, nachholen: { nachholen(v, auf: $0) },
                                 auslassen: { auslassen(v, m) })
                    .id(v.id)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
            if s.bereiche.gymAn {
                PlanKarte(plan: s.plan, woche: s.planWoche, serieWochen: s.serieWochen, laeuft: sitzung?.sessionId != nil, einheitHeute: s.einheitHeute,
                          starte: { starte(s.plan) }, weiter: { umgebung.router.oeffne(.gym(.training)) },
                          oeffneTag: { blatt = .tag($0) }, oeffneEinheit: { einheit = $0 })
            } else {
                WochenStreifen(woche: s.woche, bereiche: s.bereiche) { blatt = .tag($0) }
            }
            if !s.habits.isEmpty {
                HabitsKarte(habits: s.habits, tag: s.tag, tippe: { m.tippe($0) }, weniger: { m.weniger($0) }, oeffne: { habitSeite = $0.habit.id },
                            verwalte: { blatt = .habits }, zoom: zoom, kompakt: true)
            }
            if umgebung.daten?.einstellungen.werte.gewichtMitzaehlen ?? true {
                GewichtKarte(gewicht: s.gewicht, eintragen: { blatt = .gewicht }, ziel: { blatt = .gewichtZiel }, alleEintraege: { alleEintraege = true })
            }
        }
        .padding(.horizontal, Abstand.l)
        .padding(.bottom, Abstand.xl)
        .animation(bewegungAus ? nil : Feder.weich, value: s.verpasst?.id)
    }

    @ViewBuilder
    private func blattInhalt(_ blatt: HeuteBlatt, _ s: HeuteStand) -> some View {
        switch blatt {
        case .schritte: SchritteDetailView()
        case .gewicht:
            NavigationStack { GewichtEintragenView().toolbar { ToolbarItem(placement: .cancellationAction) { Button("Schließen") { self.blatt = nil } } } }
                .presentationDetents([.medium, .large])
        case .gewichtZiel: HeuteGewichtZielBlatt(gewicht: s.gewicht) { modell?.setzeGewichtsziel($0) }
        case .habits: HabitVerwaltungView()
        case .tag(let tag): HeuteTagView(tag: tag)
        case .nachtragen(let v):
            GymVerpasstNachtragBlatt(verpasst: v) { melde(String(localized: "\(v.name) vom \(v.wochentag) eingetragen"), erfolg: true) }
        }
    }

    /// "Ja, Freitag": der verpasste Plantag liegt nur diese Woche auf dem freien Tag (`WochenLogik.verlegen`), der Plan selbst bleibt.
    private func nachholen(_ v: GymVerpasst, auf datum: String) {
        guard umgebung.daten?.training.verlegen(von: v.gestern, auf: datum) == true else { return }
        modell?.berechne()
        melde(String(localized: "\(v.name) am \(GymVerpasstLogik.wochentag(datum)) eingeplant"), erfolg: true)
    }

    /// "Auslassen": die Karte für gestern ist beantwortet, sonst ändert sich nichts.
    private func auslassen(_ v: GymVerpasst, _ m: HeuteModell) {
        m.wischeHinweis(v.id)
        melde(String(localized: "Ok, \(v.name) fällt diese Woche aus"), erfolg: false)
    }

    private func melde(_ titel: String, erfolg: Bool) {
        toast = ToastInhalt(titel: titel, zeile: nil, stimmung: erfolg ? .ziel : .ruhetag)
        if erfolg { erledigt += 1 }
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
    case schritte, gewicht, gewichtZiel, habits
    case tag(String)
    case nachtragen(GymVerpasst)

    var id: String {
        switch self {
        case .schritte: "schritte"
        case .gewicht: "gewicht"
        case .gewichtZiel: "gewichtZiel"
        case .habits: "habits"
        case .tag(let tag): "tag-\(tag)"
        case .nachtragen(let v): "nachtragen-\(v.gestern)"
        }
    }
}

/// Energie und Tagesform als eigene Seite für den Tab Fortschritt (die Zeile auf Heute ist umgezogen, Lückenliste 2.1): rechnet mit einem eigenen
/// `HeuteModell` für heute und speichert das Gefühl dort. Aufruf: `.sheet { HeuteEnergieSeite() }` (`EnergieDetail` bringt seinen eigenen NavigationStack mit).
struct HeuteEnergieSeite: View {
    @Environment(AppUmgebung.self) private var umgebung
    @State private var modell: HeuteModell?

    var body: some View {
        Group {
            if let modell, let s = modell.stand {
                EnergieDetail(energie: s.energie) { modell.speichereGefuehl($0) }
            } else {
                ProgressView()
            }
        }
        .task {
            let m = modell ?? HeuteModell(umgebung: umgebung)
            modell = m
            m.berechne()
            await m.beobachte()
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
                ? String(localized: "Ich sehe noch nichts. Erlaube Lumen Fit in den Einstellungen unter Health den Zugriff auf Schritte und Schlaf.")
                : String(localized: "Ich sehe noch keine Health-Daten. Erlaube Health, dann füllen sich deine Bögen."),
            handlung: versucht ? String(localized: "Einstellungen öffnen") : String(localized: "Health erlauben")
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
