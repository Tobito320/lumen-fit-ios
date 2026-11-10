// Quelle: Lovea Health/GymNeu/GymStartView.swift (neu im Lumen-Design, Aufbau nach dem Entwurf vom 10.11.2026)
import SwiftUI

/// Der Training-Tab (Entwurf `training`): Woche Mo bis So (Tipp wählt den Tag), Lumi-Zeile, großer Start in Lime, Pillen "Kurz · 30 min" und "Ohne Plan",
/// der gewählte Tag als Zeile (öffnet die Seite des Tages), die Zeilen Anderen Plan wählen, Splits, Übungen und Cardio, "Hilfe?" und "Eigenen Plan bauen".
/// Darunter bleibt, was der Entwurf nicht zeigt: Letzte Einheiten, Alle Trainingstage, Kalender, Nachtragen (bis Fortschritt sie trägt).
/// Auschecken vergessen steht nur, wenn nötig, ganz oben; die Testwoche unter dem Tag; das Zahnrad oben rechts.
struct GymStartView: View {
    let sitzung: GymSitzung
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var gewaehlt: String?
    /// "Kurz · 30 min" an: der Start nimmt nur die ersten Übungen, der Rest wird ausgelassen (nicht gelöscht).
    @State private var kurz = false
    @State private var cardioGeraet: CardioWahl?
    @State private var einstellungen = false
    /// Die vergessene Einheit, deren Endzeit gerade eingetragen wird.
    @State private var endzeitFuer: GymSession?
    @State private var nachtragen = false
    @State private var planWahl = false
    @State private var hilfe = false

    var body: some View {
        ScrollView {
            if let training = sitzung.training {
                inhalt(training)
                    .padding(.horizontal, Abstand.l)
                    .padding(.bottom, Abstand.xl)
            } else {
                LeerZustand(stimmung: .denkt, satz: String(localized: "Das Training lädt noch."))
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { einstellungen = true } label: { Label("Einstellungen fürs Training", systemImage: "gearshape") }
            }
        }
        .sheet(item: $cardioGeraet) { CardioEingabeView(sitzung: sitzung, geraet: $0.rawValue) }
        .sheet(isPresented: $einstellungen) { GymEinstellungenBlatt(sitzung: sitzung) }
        .sheet(item: $endzeitFuer) { EinheitEndzeitBlatt(session: $0, jetzt: umgebung.uhr()) }
        .sheet(isPresented: $nachtragen) { EinheitNachtragenBlatt(jetzt: umgebung.uhr()) }
        .sheet(isPresented: $planWahl) { GymPlanWahlBlatt(sitzung: sitzung) }
        .sheet(isPresented: $hilfe) { GymHilfeBlatt() }
        .task { sitzung.ladeWennNoetig() }
    }

    private func inhalt(_ training: TrainingStore) -> some View {
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)
        let datum = gewaehlt ?? heute
        // Der Stand gilt für heute (Knopf, Lumi, Testwoche); der gewählte Tag zeigt nur seine Zeile.
        let stand = GymStartStand.bauen(sessions: training.sessions, plan: training.plan, gewaehlt: heute, jetzt: jetzt)
        let heuteGemacht = stand.woche.first { $0.heute }?.gemacht ?? false
        let lumi = GymTabLogik.lumi(laeuft: stand.knopf == .weiter, heuteGemacht: heuteGemacht, tagName: stand.tag.map(Self.name))
        let kurzMoeglich = stand.knopf == .starten && !heuteGemacht && stand.tag.map { GymTabLogik.kurzLohnt($0) } == true
        return VStack(alignment: .leading, spacing: Abstand.l) {
            if stand.vergessen, let s = training.vergessene(jetzt: jetzt) { vergessenKarte(s, training: training) }
            wochenleiste(stand, datum: datum)
            lumiZeile(lumi)
            if let knopf = stand.knopf {
                startKnopf(knopf, heuteGemacht: heuteGemacht, tag: kurzMoeglich && kurz ? stand.tag : nil, training: training)
            }
            if stand.knopf == .starten { pillen(stand, kurzMoeglich: kurzMoeglich) }
            tagZeile(datum: datum, heute: heute, stand: stand, training: training, kurz: kurzMoeglich && kurz)
            if let hinweis = stand.testHinweis { testwoche(hinweis, training: training) }
            unterseiten(training, heute: heute)
            hilfeUndEigen
            verlauf(training, jetzt: jetzt)
        }
    }

    private static func name(_ t: TrainingsTag) -> String { t.name.isEmpty ? String(localized: "Training") : t.name }

    // MARK: Woche

    private func wochenleiste(_ stand: GymStartStand, datum: String) -> some View {
        HStack(spacing: Abstand.xs) {
            ForEach(stand.woche) { t in
                let gewaehlt = t.datum == datum
                Button {
                    self.gewaehlt = t.datum == stand.heute ? nil : t.datum
                } label: {
                    VStack(spacing: 4) {
                        Text(t.heute ? String(localized: "Heute") : t.kuerzel)
                            .font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                        Image(systemName: t.gemacht ? "checkmark.circle.fill" : t.geplant != nil ? "circle" : "minus")
                            .font(.title3)
                            .foregroundStyle(t.gemacht ? palette.akzent : palette.text2)
                            .accessibilityHidden(true)
                        // Punkt, wenn der Partner an diesem Tag trainiert hat (nur mit Verbindung).
                        WochenPersonenPunkte(tag: t.datum, ichGym: false)
                    }
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche + 12)
                    .background(gewaehlt ? palette.akzent.opacity(0.12) : Color.clear, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Rundung.klein, style: .continuous).stroke(gewaehlt ? palette.akzent : Color.clear, lineWidth: 1.5))
                }
                .buttonStyle(.federnd)
                .accessibilityLabel(t.sprechtext)
                .accessibilityAddTraits(gewaehlt ? .isSelected : [])
            }
        }
        .padding(.top, Abstand.s)
    }

    private func lumiZeile(_ z: GymTabLogik.LumiZeile) -> some View {
        HStack(spacing: Abstand.m) {
            LumiView(stimmung: z.stimmung, groesse: 40).accessibilityHidden(true)
            Text(z.satz).font(.subheadline).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Start

    private func startKnopf(_ knopf: GymStartKnopf, heuteGemacht: Bool, tag kurzTag: TrainingsTag?, training: TrainingStore) -> some View {
        Button {
            switch knopf {
            case .weiter: sitzung.ladeWennNoetig()
            case .fortsetzen: sitzung.fortsetzen()
            case .starten: starten(kurzTag, training: training)
            }
        } label: {
            Label(knopfTitel(knopf, heuteGemacht: heuteGemacht), systemImage: knopf.symbolName)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.lumenHauptknopf)
    }

    private func knopfTitel(_ knopf: GymStartKnopf, heuteGemacht: Bool) -> String {
        switch knopf {
        case .weiter: String(localized: "Weiter")
        case .fortsetzen: String(localized: "Fortsetzen")
        case .starten: heuteGemacht ? String(localized: "Noch ein Training") : String(localized: "Training starten")
        }
    }

    /// Start von heute. Mit Kurzversion werden die Übungen nach der Grenze gleich ausgelassen: sie bleiben im Plan und lassen sich im Training wieder aufnehmen.
    private func starten(_ kurzTag: TrainingsTag?, training: TrainingStore) {
        guard let kurzTag else {
            sitzung.starte(planTag: training.heutigerTag()?.id)
            return
        }
        let weg = GymTabLogik.kurzWeg(kurzTag)
        sitzung.starte(planTag: kurzTag.id)
        for i in sitzung.liste.indices.reversed() where weg.contains(sitzung.liste[i].planUebung.id) { sitzung.auslassen(i) }
        kurz = false
    }

    private func pillen(_ stand: GymStartStand, kurzMoeglich: Bool) -> some View {
        HStack(spacing: Abstand.s) {
            Spacer(minLength: 0)
            if kurzMoeglich, let tag = stand.tag {
                let minuten = GymTabLogik.rund(ZeitSchaetzung.minuten(GymTabLogik.kurzversion(tag)))
                GymPillenKnopf(text: String(localized: "Kurz · \(minuten) min"), symbol: "clock", an: kurz) { kurz.toggle() }
                    .accessibilityHint("Startet nur die ersten Übungen des Tages")
            }
            GymPillenKnopf(text: String(localized: "Ohne Plan"), symbol: "play.fill") { sitzung.starteFrei() }
                .accessibilityHint("Freies Training, die Übungen wählst du unterwegs")
            Spacer(minLength: 0)
        }
    }

    // MARK: Tag

    @ViewBuilder
    private func tagZeile(datum: String, heute: String, stand: GymStartStand, training: TrainingStore, kurz: Bool) -> some View {
        let tag = TrainingLogik.tag(training.plan, datum: datum)
        let wochentag = TrainingLogik.wochentagName[Datum.wochentag(datum) - 1]
        if let tag {
            let wann = datum == heute ? String(localized: "Heute") : wochentag
            let umfang = kurz ? String(localized: "Kurzversion · \(ZeitSchaetzung.umfang(GymTabLogik.kurzversion(tag)))") : ZeitSchaetzung.umfang(tag)
            let erledigt = datum == heute && stand.status != "noch nicht" ? stand.status : nil
            NavigationLink {
                GymTagSeite(sitzung: sitzung, datum: datum)
            } label: {
                HStack(spacing: Abstand.m) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.name(tag)).font(.title.weight(.bold)).fontDesign(.rounded).foregroundStyle(palette.text)
                        Text("\(wann) · \(erledigt ?? umfang)").font(.body).foregroundStyle(palette.text)
                    }
                    Spacer(minLength: Abstand.s)
                    Image(systemName: "chevron.right").font(.body.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                }
                .frame(minHeight: Abstand.tippflaeche)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Zeigt die Übungen des Tages")
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ruhetag").font(.title.weight(.bold)).fontDesign(.rounded).foregroundStyle(palette.text)
                Text("\(datum == heute ? String(localized: "Heute") : wochentag) · \(String(localized: "Muskeln wachsen in der Pause"))")
                    .font(.body).foregroundStyle(palette.text2)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func testwoche(_ hinweis: String, training: TrainingStore) -> some View {
        ListenKarte {
            GymZeile(titel: hinweis) {
                Button("Beenden") { training.testwocheAbbrechen() }.buttonStyle(.bordered).controlSize(.large)
            }
        }
    }

    // MARK: Zeilen

    private func unterseiten(_ training: TrainingStore, heute: String) -> some View {
        let woche = GymTabLogik.planWoche(training.plan, sessions: training.sessions, heute: heute)
        let plan = training.plan.splitName ?? (training.plan.tage.isEmpty ? String(localized: "Noch kein Plan") : String(localized: "Eigener Plan"))
        return ListenKarte {
            Button { planWahl = true } label: {
                GymSymbolZeile(symbol: "arrow.triangle.2.circlepath", farbe: Bereichsfarbe.freunde, titel: String(localized: "Anderen Plan wählen"),
                               untertitel: woche.map { String(localized: "\(plan) · Woche \($0)") } ?? plan)
            }
            .buttonStyle(.plain)
            Haarlinie()
            NavigationLink { SplitBibliothekView(sitzung: sitzung) } label: {
                GymSymbolZeile(symbol: "square.grid.2x2.fill", farbe: Bereichsfarbe.splits, titel: String(localized: "Splits"),
                               untertitel: String(localized: "Fertige Pläne zum Ausprobieren"))
            }
            .buttonStyle(.plain)
            Haarlinie()
            NavigationLink { UebungsSucheView(titel: String(localized: "Übungen")) } label: {
                GymSymbolZeile(symbol: "dumbbell.fill", farbe: Bereichsfarbe.energie, titel: String(localized: "Übungen"),
                               untertitel: String(localized: "Alle Übungen mit Anleitung"))
            }
            .buttonStyle(.plain)
            Haarlinie()
            // Cardio ohne Training (Laufband, Stairmaster): der Entwurf hat keinen Platz dafür, darum eine Zeile hier.
            Menu {
                Button("Laufband", systemImage: "figure.walk.treadmill") { cardioGeraet = .laufband }
                Button("Stairmaster", systemImage: "figure.stair.stepper") { cardioGeraet = .stairmaster }
            } label: {
                GymSymbolZeile(symbol: "heart.fill", farbe: Bereichsfarbe.verlauf, titel: String(localized: "Cardio eintragen"),
                               untertitel: String(localized: "Laufband oder Stairmaster ohne Training"))
            }
            .buttonStyle(.plain)
        }
    }

    private var hilfeUndEigen: some View {
        VStack(spacing: Abstand.s) {
            GymPillenKnopf(text: String(localized: "Hilfe?"), symbol: "info.circle") { hilfe = true }
                .accessibilityHint("Was mache ich für welchen Muskel?")
            NavigationLink(value: Route.gym(.plaene)) {
                Text("Eigenen Plan bauen · für Fortgeschrittene")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.akzent)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Auschecken vergessen

    private func vergessenKarte(_ s: GymSession, training: TrainingStore) -> some View {
        ListenKarte {
            GymZeile(titel: String(localized: "Auschecken vergessen?"),
                     untertitel: String(localized: "Die Einheit von \(GymFormat.tag(s.start)) läuft noch. Trag ein, wann du fertig warst, oder setz das Ende auf 1,5 Stunden nach dem Start."))
            HStack(spacing: Abstand.s) {
                Button("Endzeit eintragen") { endzeitFuer = s }
                    .buttonStyle(.bordered).controlSize(.large)
                Button("Nach 1,5 Stunden") { training.auschecken(s.id, ende: EinheitZeitenLogik.endeVorschlag(start: s.start, jetzt: umgebung.uhr())) }
                    .buttonStyle(.bordered).controlSize(.large)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.bottom, Abstand.m)
        }
    }

    // MARK: Verlauf (bis Fortschritt ihn trägt)

    @ViewBuilder
    private func verlauf(_ training: TrainingStore, jetzt: Date) -> some View {
        let liste = training.sessions.sorted { $0.start > $1.start }.prefix(5)
        VStack(alignment: .leading, spacing: Abstand.s) {
            GymAbschnitt(titel: String(localized: "Letzte Einheiten"))
            ListenKarte {
                ForEach(Array(liste)) { s in
                    let tag = Datum.text(s.start)
                    NavigationLink {
                        EinheitNachlesenView(sessionId: s.id)
                    } label: {
                        GymZeile(titel: training.tag(id: s.tag).map(Self.name) ?? String(localized: "Freies Training"),
                                 untertitel: GymFormat.tag(s.start) + (s.notiz.map { " · \($0.prefix(60))" } ?? "")) {
                            HStack(spacing: Abstand.xs) {
                                Text(GymStartLogik.status([s], datum: tag, heute: Datum.text(jetzt), geplant: nil, jetzt: jetzt))
                                    .font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.trailing)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Öffnet die Einheit zum Nachlesen")
                    .accessibilityElement(children: .combine)
                    Haarlinie()
                }
                NavigationLink { TrainingVerlaufView() } label: {
                    GymSymbolZeile(symbol: "list.bullet", farbe: Bereichsfarbe.verlauf, titel: String(localized: "Alle Trainingstage"),
                                   untertitel: String(localized: "Monatsraster, Serie und alle Einheiten"))
                }
                .buttonStyle(.plain)
                Haarlinie()
                NavigationLink { KalenderView() } label: {
                    GymSymbolZeile(symbol: "calendar", farbe: Bereichsfarbe.verlauf, titel: String(localized: "Kalender"),
                                   untertitel: String(localized: "Trainings, geplante Tage und Partner"))
                }
                .buttonStyle(.plain)
                Haarlinie()
                Button { nachtragen = true } label: {
                    GymSymbolZeile(symbol: "plus", farbe: Bereichsfarbe.einstellungen, titel: String(localized: "Training nachtragen"), pfeil: false)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Die zwei Schnellknöpfe für Cardio ohne Training.
enum CardioWahl: String, Identifiable { case laufband, stairmaster; var id: String { rawValue } }
