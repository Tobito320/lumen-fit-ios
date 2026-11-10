import SwiftUI

/// Abschnittstitel der älteren Seiten von Fortschritt: groß und fett, rechts optional eine Erklärung.
struct FortschrittAbschnitt: View {
    let titel: String
    var detail: String?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
            Text(titel).font(.title2.weight(.bold)).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            Spacer(minLength: Abstand.s)
            if let detail { Text(detail).font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.trailing) }
        }
    }
}

/// Was der Tab zeigt, einmal gerechnet (nicht bei jedem Aufbau): nur neu, wenn sich Einheiten, Plan, Gewicht, Ziele, Tag oder Zeitraum ändern.
struct FortTabStand {
    var uebersicht: FortUebersichtDaten
    var mehr: Bool
    var satz: String?
    var gewichte: [GewichtZeile]
    var letzte: EinheitDaten?
    var setsWoche: Int
    var ausblickWoche: Int?
    var gewichtKg: Double?
    var level: FortLevel
}

private struct FortTabEingabe: Equatable {
    var sessions: [GymSession]
    var plan: TrainingsPlan
    var gewicht: [String: Int]
    var heute: String
    var zeitraum: FortZeitraum
}

/// Merkt sich den letzten Stand; kein `@Observable`, die Ansicht beobachtet die Stores selbst.
@MainActor private final class FortTabSpeicher {
    var eingabe: FortTabEingabe?
    var stand: FortTabStand?

    func stand(_ e: FortTabEingabe, rechne: () -> FortTabStand) -> FortTabStand {
        if e == eingabe, let stand { return stand }
        let neu = rechne()
        eingabe = e
        stand = neu
        return neu
    }
}

/// Die Wurzel des Tabs Fortschritt im neuen Design (Entwurf, Besitzer 10.11.2026: "krass und gut, aber visuell schöner und kompakter"):
/// Übersicht (Monat | Woche), Gewichte (Top 3, "Alle"), Letztes Training, Kalender und Verlauf, dann die Liste der Unterseiten.
/// Ohne Training steht oben ein Leerzustand mit Knopf; die Liste bleibt. Der Tab setzt den `NavigationStack`.
struct FortschrittTabView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var zeitraum = FortZeitraum.monat
    @State private var speicher = FortTabSpeicher()
    @State private var energie: Int?

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        let zeitraum = zeitraum
        let s = speicher.stand(FortTabEingabe(sessions: q.sessions, plan: q.plan, gewicht: q.gewicht, heute: q.heute, zeitraum: zeitraum)) {
            Self.rechne(q, zeitraum: zeitraum)
        }
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.xl) {
                if q.hatTraining {
                    FortUebersichtKarte(daten: s.uebersicht, zeitraum: $zeitraum, mehr: s.mehr)
                    gewichte(s)
                    if let letzte = s.letzte { letztes(letzte) }
                } else {
                    leer
                }
                VStack(spacing: Abstand.l) {
                    ListenKarte {
                        FortListenZeile("Kalender und Verlauf", wert: String(localized: "\(s.uebersicht.insgesamt) Einheiten"), symbol: "calendar", farbe: Bereichsfarbe.verlauf) {
                            FortVerlaufSeite()
                        }
                    }
                    liste(s)
                }
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .navigationTitle("Fortschritt")
        .navigationBarTitleDisplayMode(.large)
        .fortschrittToast()
        .onAppear {
            FortschrittModul.waechter.pruefeAlles()
            energie = FortEnergieSeite.urteil(umgebung.daten, heute: Datum.text(umgebung.uhr()))
        }
    }

    static func rechne(_ q: FortschrittQuelle, zeitraum: FortZeitraum) -> FortTabStand {
        let heute = q.heute
        let vergleich = FortschrittLogik.vergleich(q.sessions, plan: q.plan, heute: heute, jetzt: q.jetzt)
        let gewichte = FortschrittLogik.gewichte(q.sessions, plan: q.plan, heute: heute)
        let gewicht = q.gewicht.filter { $0.key <= heute && $0.value > 0 }.max { $0.key < $1.key }
        return FortTabStand(
            uebersicht: FortUebersicht.daten(q.sessions, plan: q.plan, gewicht: q.gewicht, heute: heute, jetzt: q.jetzt, zeitraum: zeitraum),
            mehr: FortUebersicht.mehrAlsSonst(vergleich),
            satz: FortschrittLogik.satz(vergleich, geplantRest: FortschrittLogik.geplantRest(q.plan, sessions: q.sessions, heute: heute)),
            gewichte: gewichte, letzte: q.letztesTraining, setsWoche: vergleich.saetze,
            ausblickWoche: FortAusblickLogik.hauptuebungen(gewichte).first?.woche,
            gewichtKg: gewicht.map { Double($0.value) / 10 },
            level: FortErfolgeLogik.level(StatsPunkte.gesamt(q.sessions)))
    }

    private var leer: some View {
        LeerZustand(stimmung: .bereit, satz: String(localized: "Noch kein Training. Tipp auf Starten, Lumi zählt mit."), handlung: String(localized: "Training starten")) {
            umgebung.router.oeffne(.gym(.training))
        }
        .lumenKartenFlaeche()
    }

    private func gewichte(_ s: FortTabStand) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            FortKopf("Gewichte", linkTitel: s.gewichte.count > 0 ? "Alle" : nil) { FortGewichteSeite() }
            GewichteListe(zeilen: s.gewichte, anzahl: 3)
            if let satz = s.satz { Text(satz).font(.footnote).foregroundStyle(palette.text2).padding(.horizontal, Abstand.xs) }
        }
    }

    private func letztes(_ e: EinheitDaten) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            FortKopf("Letztes Training")
            NavigationLink { EinheitNachlesenView(sessionId: e.id) } label: {
                VStack(alignment: .leading, spacing: Abstand.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(e.titel).font(.headline).foregroundStyle(palette.text)
                        Spacer(minLength: Abstand.s)
                        Text(FortschrittLogik.kurzDatum(e.start)).font(.subheadline).foregroundStyle(palette.text2)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                    }
                    Text(Self.zeile(e)).font(.subheadline).foregroundStyle(palette.text2).monospacedDigit()
                }
                .padding(Abstand.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .lumenKartenFlaeche()
            .accessibilityElement(children: .combine)
            .accessibilityHint("Öffnet die Einheit")
        }
    }

    /// "1:15 h · 10 Sets · 2 Rekorde" (ohne kg, Besitzer).
    static func zeile(_ e: EinheitDaten) -> String {
        var teile: [String] = []
        if let dauer = e.dauer { teile.append(TrainingLogik.dauerText(dauer)) }
        teile.append(String(localized: "\(e.saetze) Sets"))
        if e.rekorde > 0 { teile.append(e.rekorde == 1 ? String(localized: "1 Rekord") : String(localized: "\(e.rekorde) Rekorde")) }
        return teile.joined(separator: " · ")
    }

    private func liste(_ s: FortTabStand) -> some View {
        ListenKarte {
            FortListenZeile("Sets je Muskel", wert: String(localized: "\(s.setsWoche) diese Woche"), symbol: "dumbbell.fill", farbe: Bereichsfarbe.splits) { FortSetsSeite() }
            Haarlinie()
            FortListenZeile("12-Wochen-Ausblick", wert: s.ausblickWoche.map { String(localized: "Woche \($0)") }, symbol: "chart.line.uptrend.xyaxis", farbe: Bereichsfarbe.creatin) {
                FortAusblickSeite()
            }
            Haarlinie()
            FortListenZeile("Körper und Gewicht", wert: s.gewichtKg.map { "\(FortschrittLogik.zahl($0)) kg" }, symbol: "scalemass.fill", farbe: Bereichsfarbe.gewicht) {
                PartnerKoerperWeiche { MessungenView() }
            }
            Haarlinie()
            FortListenZeile("Erfolge", wert: String(localized: "Level \(s.level.nummer) · \(s.level.name)"), symbol: "trophy.fill", farbe: Bereichsfarbe.erfolge) {
                MeilensteineView()
            }
            Haarlinie()
            FortListenZeile("Energie und Tagesform", wert: energie.map(TagesformGefuehl.name), symbol: "bolt.fill", farbe: Bereichsfarbe.energie) { FortEnergieSeite() }
            Haarlinie()
            FortListenZeile("Einsichten und Hinweise", symbol: "lightbulb.fill", farbe: .orange, route: .einsichten)
            Haarlinie()
            FortListenZeile("Rückblick", symbol: "calendar.badge.clock", farbe: Bereichsfarbe.verlauf) { RueckblickView() }
        }
    }
}
