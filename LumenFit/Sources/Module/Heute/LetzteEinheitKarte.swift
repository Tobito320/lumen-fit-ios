import SwiftUI

/// Eine Übung der letzten Einheit: "3 × Latzug zur Brust" und der beste Satz ("62,5 kg × 8"); `rekord` = in dieser Einheit ein neuer Rekord.
struct LetzteEinheitZeile: Identifiable, Equatable, Sendable {
    var id: String
    var text: String
    var bester: String
    var rekord: Bool
}

/// Die Werte der Karte "Letztes Training", einmal gerechnet. Reine Werte, keine Logik in der Ansicht.
struct LetzteEinheit: Equatable, Sendable {
    var sessionId: String
    var titel: String
    /// "Mittwoch, 11. November, 18:05–19:20".
    var kopfzeile: String
    var dauer: String
    var volumenText: String
    var saetze: Int
    var rekorde: Int
    var zeilen: [LetzteEinheitZeile]
}

enum LetzteEinheitLogik {
    /// Die neueste beendete Einheit mit Daten; laufende und leere (kein Satz, keine Cardio-Übung) zählen nicht. nil, wenn es keine gibt.
    static func bauen(sessions: [GymSession], tag: (String?) -> TrainingsTag?) -> LetzteEinheit? {
        guard let s = sessions.filter({ $0.ende != nil && GymTageLogik.hatDaten($0) }).max(by: { $0.start < $1.start }), let ende = s.ende else { return nil }
        let plantag = tag(s.tag)
        let frueher = sessions.filter { $0.start < s.start }
        let liste = WorkoutLogik.uebungen(s, tag: plantag, frueher: frueher)
        let zeilen = liste.compactMap { zeile($0, frueher: frueher) }
        let titel = plantag.map { $0.name.isEmpty ? String(localized: "Training") : $0.name } ?? String(localized: "Freies Training")
        return LetzteEinheit(
            sessionId: s.id, titel: titel, kopfzeile: EinheitZeitenLogik.kopfZeit(s),
            dauer: TrainingLogik.dauerText(ende.timeIntervalSince(s.start)),
            volumenText: WorkoutLogik.volumen(liste).formatted(.number.precision(.fractionLength(0)).locale(Datum.anzeigeLocale)) + " kg",
            saetze: WorkoutLogik.saetzeZahl(liste), rekorde: zeilen.filter(\.rekord).count, zeilen: zeilen)
    }

    private static func zeile(_ u: WorkoutUebung, frueher: [GymSession]) -> LetzteEinheitZeile? {
        if u.planUebung.istCardio {
            return u.cardioFertig ? LetzteEinheitZeile(id: u.id, text: u.planUebung.anzeigeName, bester: "\(u.planUebung.minuten ?? 20) min", rekord: false) : nil
        }
        let gezaehlt = u.saetze.filter(\.zaehlt)
        // Schwerster Satz, bei gleichem Gewicht der mit mehr Wiederholungen; ohne Gewicht zählen die Wiederholungen.
        guard let bester = gezaehlt.max(by: { ($0.kg ?? 0, $0.wdh) < ($1.kg ?? 0, $1.wdh) }) else { return nil }
        let rekord = !RekordLogik.neue(gezaehlt, gegen: RekordLogik.tage(katalogId: u.planUebung.uebung, planId: u.id, in: frueher)).isEmpty
        return LetzteEinheitZeile(id: u.id, text: "\(gezaehlt.count) × \(u.planUebung.anzeigeName)", bester: WorkoutLogik.satzText(bester), rekord: rekord)
    }
}

/// Startseite: das letzte Training zum Nachlesen. Oben Name, Wochentag und Datum, dann Dauer, Volumen, Sätze und Rekorde als große Zahlen, darunter jede Übung
/// mit ihrem besten Satz. Ein Tipp öffnet die ganze Einheit (`EinheitNachlesenView`). Ohne beendete Einheit zeigt die Startseite die Karte nicht.
struct LetzteEinheitKarte: View {
    let einheit: LetzteEinheit
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.colorSchemeContrast) private var kontrast

    var body: some View {
        NavigationLink { EinheitNachlesenView(sessionId: einheit.sessionId) } label: {
            ListenKarte {
                VStack(alignment: .leading, spacing: Abstand.m) {
                    kopf
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), alignment: .leading)], alignment: .leading, spacing: Abstand.m) {
                        kennzahl(String(localized: "Dauer"), einheit.dauer)
                        kennzahl(String(localized: "Volumen"), einheit.volumenText)
                        kennzahl(String(localized: "Sätze"), "\(einheit.saetze)")
                        kennzahl(String(localized: "Rekorde"), "\(einheit.rekorde)", symbol: einheit.rekorde > 0 ? "trophy.fill" : nil)
                    }
                    if !einheit.zeilen.isEmpty {
                        Haarlinie()
                        VStack(alignment: .leading, spacing: Abstand.s) {
                            ForEach(einheit.zeilen) { zeile($0) }
                        }
                    }
                }
                .padding(Abstand.l)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Öffnet die Einheit zum Nachlesen")
    }

    private var kopf: some View {
        HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(einheit.titel).font(.title3.weight(.bold)).foregroundStyle(palette.text)
                Text(einheit.kopfzeile).font(.subheadline).foregroundStyle(palette.text2)
            }
            Spacer(minLength: Abstand.s)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
        }
    }

    private func kennzahl(_ titel: String, _ wert: String, symbol: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.footnote).foregroundStyle(palette.text2)
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol).foregroundStyle(rekordFarbe).accessibilityHidden(true) }
                Text(wert).font(.title3.weight(.bold)).fontDesign(.rounded).monospacedDigit().foregroundStyle(palette.text).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }

    private func zeile(_ z: LetzteEinheitZeile) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
            Text(z.text).font(.subheadline).foregroundStyle(palette.text).frame(maxWidth: .infinity, alignment: .leading)
            if z.rekord { Image(systemName: "trophy.fill").font(.footnote).foregroundStyle(rekordFarbe).accessibilityLabel("Rekord") }
            Text(z.bester).font(.subheadline).monospacedDigit().foregroundStyle(palette.text2)
        }
    }

    private var rekordFarbe: Color { LumenFarben.tief(.trainieren, dunkel: schema == .dark, kontrastHoch: kontrast == .increased) }
}
