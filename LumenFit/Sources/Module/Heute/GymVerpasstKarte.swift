import SwiftUI

/// Karte "Gestern verpasst" zwischen Ringplatte und "Plan für heute" (Entwurf `verpasstKarte`, Besitzer 11.11.2026, "Zwei Wege"):
/// erst die Frage "Eintragen vergessen oder warst du nicht da?", nach "War nicht da" der Vorschlag, den Plantag diese Woche auf einem
/// freien Tag nachzuholen (Hauptknopf, weitere freie Tage als Pillen, "Auslassen").
struct GymVerpasstKarte: View {
    let verpasst: GymVerpasst
    let nachtragen: () -> Void
    let nachholen: (String) -> Void
    let auslassen: () -> Void
    @State private var nichtDa = false
    @State private var getippt = 0
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @Environment(\.bewegungAus) private var bewegungAus

    var body: some View {
        ListenKarte {
            VStack(alignment: .leading, spacing: Abstand.m) {
                HStack(spacing: Abstand.s) {
                    Image(systemName: "calendar").foregroundStyle(symbolFarbe).accessibilityHidden(true)
                    Text(titel).font(.headline).foregroundStyle(palette.text).contentTransition(.opacity)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(palette.text2)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                if nichtDa { nachholenKnoepfe.transition(.opacity) } else { frageKnoepfe.transition(.opacity) }
            }
            .padding(Abstand.l)
        }
        .accessibilityElement(children: .contain)
        .haptik(.auswahl, bei: getippt)
    }

    /// Orange wie im Entwurf (wie die Serie der Plan-Karte); hell dunkler für genug Kontrast auf der Karte.
    private var symbolFarbe: Color { schema == .dark ? Color.orange : LumenFarben.farbe(0xA84E00) }

    private var titel: String {
        nichtDa ? String(localized: "\(verpasst.name) nachholen?") : String(localized: "Gestern: \(verpasst.name)")
    }

    private var text: String {
        guard nichtDa else { return String(localized: "Am \(verpasst.wochentag) war \(verpasst.name) geplant. Eintragen vergessen oder warst du nicht da?") }
        return verpasst.freiText ?? String(localized: "Diese Woche ist kein Tag mehr frei.")
    }

    private var frageKnoepfe: some View {
        HStack(spacing: Abstand.s) {
            Button(action: nachtragen) { Text("Nachtragen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
            Button {
                getippt += 1
                withAnimation(bewegungAus ? nil : Feder.weich) { nichtDa = true }
            } label: { Text("War nicht da").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
        }
        .buttonStyle(.bordered)
        .tint(palette.akzent)
    }

    private var nachholenKnoepfe: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            if let erster = verpasst.freie.first {
                Button { nachholen(erster) } label: {
                    Text("Ja, \(GymVerpasstLogik.wochentag(erster))").frame(maxWidth: .infinity)
                }
                .buttonStyle(.lumenHauptknopf)
            }
            HStack(spacing: Abstand.s) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Abstand.s) {
                        ForEach(verpasst.freie.dropFirst(), id: \.self) { datum in
                            Button { nachholen(datum) } label: {
                                Pille(text: GymVerpasstLogik.wochentag(datum)).frame(minHeight: Abstand.tippflaeche).contentShape(.rect)
                            }
                            .buttonStyle(.federnd)
                            .accessibilityLabel(String(localized: "Am \(GymVerpasstLogik.wochentag(datum)) nachholen"))
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                Button("Auslassen", action: auslassen)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.akzent)
                    .frame(minWidth: Abstand.tippflaeche, minHeight: Abstand.tippflaeche)
                    .accessibilityHint(String(localized: "\(verpasst.name) fällt diese Woche aus"))
            }
        }
    }
}

/// Blatt "<Tag> nachtragen" (Entwurf `S.sheet=='nach'`): die Übungen des Plantags von gestern mit den Werten vom letzten Mal, alle abgehakt.
/// Tipp auf eine Übung ändert ihre Sätze wie in einer beendeten Einheit (`EinheitSaetzeBlatt`). "Speichern" legt eine normale Einheit mit
/// Datum gestern an (18 Uhr, so lange wie geschätzt); Health bekommt sie nur, wenn Trainings sonst auch dorthin gehen.
struct GymVerpasstNachtragBlatt: View {
    let verpasst: GymVerpasst
    let gespeichert: () -> Void
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var schliessen
    @Environment(\.palette) private var palette
    @State private var liste: [WorkoutUebung]?
    @State private var bearbeiten: WorkoutUebung?

    private var minuten: Int { HeuteKartenLogik.minuten(verpasst.tag) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Abstand.m) {
                    Text(minuten > 0 ? String(localized: "\(Datum.anzeige(verpasst.gestern)) · ca. \(minuten) min") : Datum.anzeige(verpasst.gestern))
                        .font(.subheadline)
                        .foregroundStyle(palette.text2)
                    if let liste, !liste.isEmpty {
                        ListenKarte {
                            ForEach(liste) { u in
                                zeile(u)
                                if u.id != liste.last?.id { Haarlinie() }
                            }
                        }
                        Text("Gewichte vom letzten Mal. Tipp eine Übung, um sie zu ändern.")
                            .font(.footnote)
                            .foregroundStyle(palette.text2)
                            .multilineTextAlignment(.center)
                    }
                    Button(action: speichern) { Text("Speichern").frame(maxWidth: .infinity) }
                        .buttonStyle(.lumenHauptknopf)
                        .disabled(liste == nil)
                }
                .padding(Abstand.l)
            }
            .lumenHintergrund()
            .navigationTitle(String(localized: "\(verpasst.name) nachtragen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } } }
            .sheet(item: $bearbeiten) { u in
                EinheitSaetzeBlatt(sessionId: "", uebung: u) { neu in
                    if let i = liste?.firstIndex(where: { $0.id == u.id }) { liste?[i].saetze = neu }
                }
            }
        }
        .onAppear {
            guard liste == nil else { return }
            liste = GymVerpasstLogik.vorbelegt(verpasst.tag, frueher: umgebung.daten?.training.sessions ?? [])
        }
    }

    @ViewBuilder
    private func zeile(_ u: WorkoutUebung) -> some View {
        if u.planUebung.istCardio {
            GymZeile(titel: u.planUebung.anzeigeName, untertitel: String(localized: "\(u.planUebung.minuten ?? 20) min")) { EmptyView() }
        } else {
            Button { bearbeiten = u } label: {
                GymZeile(titel: u.planUebung.anzeigeName, untertitel: detail(u)) {
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Sätze ändern")
        }
    }

    /// "3 Sätze · 25 kg × 12" (der letzte abgehakte Satz); ohne Haken "nicht gemacht".
    private func detail(_ u: WorkoutUebung) -> String {
        guard let letzter = u.saetze.last(where: { $0.ok == true }) else { return String(localized: "nicht gemacht") }
        let zahl = u.fertigZahl == 1 ? String(localized: "1 Satz") : String(localized: "\(u.fertigZahl) Sätze")
        return "\(zahl) · \(WorkoutLogik.satzText(letzter))"
    }

    private func speichern() {
        guard let d = umgebung.daten, let liste else { return }
        let start = Datum.datum(verpasst.gestern).addingTimeInterval(18 * 3600)
        let ende = start.addingTimeInterval(Double(minuten > 0 ? minuten : 60) * 60)
        d.training.nachtragen(tag: verpasst.tag.id, start: start, ende: ende)
        // `nachtragen` gibt die id nicht zurück; die Einheit von gestern ist über Start und Tag eindeutig (die Karte gibt es nur ohne Einheit gestern).
        if let s = d.training.sessions.first(where: { $0.start == start && $0.tag == verpasst.tag.id }) {
            for u in liste {
                if u.planUebung.istCardio {
                    if u.cardioFertig { d.training.fertig(s.id, u.planUebung, saetze: []) }
                } else {
                    d.training.saetzeSenden(s.id, u.planUebung, u.saetze)
                }
            }
            if d.einstellungen.werte.healthSchreiben, let fertig = d.training.sessions.first(where: { $0.id == s.id }) {
                let schreiber = umgebung.healthSchreiber
                Task { _ = await schreiber.speichere(training: fertig) }
            }
        }
        gespeichert()
        schliessen()
    }
}
