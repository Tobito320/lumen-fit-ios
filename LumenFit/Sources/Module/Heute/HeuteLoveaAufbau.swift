// Quelle: Lovea Health/Heute/HeuteView.swift (body :467-501, Kopf :575, Tag wählen :600, Körper :665, Verlauf :681)
import SwiftUI

/// Der Heute-Tab im Lovea-Aufbau (Theme Lovea mit Freigabe): Reihenfolge, Abschnitte und Wege des Health-Tabs der Lovea-App.
/// Oben der Kopf "Health" mit Datum, dann die Plantag-Zeile, die Karte Tagesform mit Monat, Wochenstreifen und Gefühl, der Zyklus-Hinweis,
/// "Dein Tag" mit dem Raster und "Schreib, was war", "Das fällt mir auf", "Körper" und die Zeile "Verlauf". Seiten (Gym, Schlaf, Essen, Coach, Verlauf)
/// öffnen im Stapel des Heute-Tabs, wie in Lovea. Was Lumen Fit mehr hat als Lovea, steht danach unter "Mehr aus Lumen Fit". Alle Karten sind die
/// fachlichen Bausteine von Lumen Fit; hier entscheidet nur die Anordnung. Punkte und Challenges bleiben in Lovea.
struct HeuteLoveaInhalt: View {
    let stand: HeuteStand
    let modell: HeuteModell
    let blaettere: (Int) -> Void
    let springe: (String) -> Void
    let kalender: () -> Void
    let oeffneBlatt: (HeuteBlatt) -> Void
    let oeffneHabit: (String) -> Void
    let starte: (HeutePlan) -> Void
    let zoom: Namespace.ID
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var schritteSeite = false
    @State private var habitsSeite = false
    @State private var koerperAuswahl: KoerperAuswahl?
    @State private var befragung = false

    private var heute: String { Datum.text(umgebung.uhr()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            kopf
            if stand.istHeute { plantag }
            tagesform
            if stand.istHeute { ZyklusHinweisAnsicht() }
            abschnitt(stand.istHeute ? "Dein Tag" : Datum.anzeige(stand.tag)) {
                raster
                if stand.istHeute { SchreibKarte(modell: modell) }
            }
            if stand.istHeute, !stand.einsichten.isEmpty { EinsichtenKarte(einsichten: stand.einsichten) }
            if stand.istHeute { CoachSicherheitZeile { umgebung.router.schiebe(.coach(frage: nil)) } }
            if stand.istHeute { abschnitt("Körper") { koerper } }
            verlaufZeile
            mehr
        }
        .navigationDestination(isPresented: $schritteSeite) { SchritteDetailView(eingebettet: true) }
        .navigationDestination(isPresented: $habitsSeite) { habitsSeiteInhalt }
        .sheet(item: $koerperAuswahl) { KoerperBlattView(gruppe: $0.gruppe, teil: $0.teil) }
        .sheet(isPresented: $befragung) { ZieleBefragungView().presentationDetents([.large]) }
    }

    // MARK: Kopf und Plantag

    /// Lovea: Datum klein, darunter "Health"; ein Tipp springt zurück zu heute (`HeuteView.swift:575`).
    private var kopf: some View {
        Button { springe(heute) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(stand.istHeute ? Datum.anzeige(stand.tag).uppercased() : "ZURÜCK ZU HEUTE")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(stand.istHeute ? palette.text2 : palette.akzent)
                Text("Health").font(.largeTitle.bold()).foregroundStyle(palette.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
    }

    /// Lovea `PlantagKarte` (`SplitFreiAnsichten.swift:29`): "Tag 3 diese Woche: Upper", ein Tipp öffnet das Gym. Ohne Plan fehlt die Zeile.
    /// Der Start-Knopf und die Pille "Heute locker" der Plan-Karte stehen im Gym (Startseite), dort wie bisher.
    @ViewBuilder
    private var plantag: some View {
        if let plan = umgebung.daten?.training.plan, let tag = SplitFrei.plantag(plan, datum: stand.tag) {
            Button { gym() } label: {
                HStack(spacing: 12) {
                    Image(systemName: tag.heute ? "figure.strengthtraining.traditional" : "moon.zzz")
                        .font(.title3)
                        .foregroundStyle(tag.heute ? palette.akzent : palette.text2)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tag.titel).font(.headline).foregroundStyle(palette.text).lineLimit(2)
                        Text(tag.unter).font(.footnote).foregroundStyle(palette.text2).lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .lumenKartenFlaeche()
                .contentShape(.rect)
            }
            .buttonStyle(.federnd)
            .accessibilityHint("Öffnet das Gym")
        }
    }

    // MARK: Tagesform (Lovea: Monat, Pfeile, Streifen, Karte, Gefühl)

    private var tagesform: some View {
        VStack(spacing: 0) {
            tagesWahl
                .padding(.horizontal, 16)
                .padding(.top, 8)
                // Lovea: ein langer, klar waagerechter Zug auf der Woche blättert um eine Woche (`HeuteView.swift:627`).
                .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { zug in
                    guard abs(zug.translation.width) > abs(zug.translation.height) else { return }
                    blaettere(zug.translation.width < 0 ? 7 : -7)
                })
            if stand.istHeute || stand.hatGesundheit { TagesformLoveaKarte(energie: stand.energie, bearbeitbar: stand.istHeute,
                                                                          detail: { oeffneBlatt(.energie) }, gefuehl: { modell.speichereGefuehl($0) }) }
        }
        .lumenKartenFlaeche()
    }

    /// Monat mit Pfeilen (eine Woche vor und zurück), darunter Mo bis So mit Plan und Bilanz. Monat antippen öffnet den Kalender (`HeuteView.swift:600`).
    private var tagesWahl: some View {
        let training = umgebung.daten?.training
        let woche = KoerperWoche.bauen(sessions: training?.sessions ?? [], plan: training?.plan ?? .leer, heute: heute,
                                       katalog: { UebungsKatalog.nachId[$0] }, montagVon: stand.tag)
        return VStack(spacing: 0) {
            HStack {
                pfeil("chevron.left", -7, "Woche davor", aktiv: HeuteTagWahl.kannZurueck(stand.tag, heute: heute))
                Spacer()
                Button(action: kalender) {
                    HStack(spacing: 4) {
                        Text(Datum.datum(stand.tag).formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "de_DE"))))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.text)
                        Image(systemName: "calendar").font(.footnote).foregroundStyle(palette.text2).accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Öffnet den Monat")
                Spacer()
                pfeil("chevron.right", 7, "Woche danach", aktiv: HeuteTagWahl.kannVor(stand.tag, heute: heute))
            }
            KoerperWochenLeiste(woche: woche, gewaehlt: stand.tag, waehlen: { tag in
                guard tag <= heute else { return }
                springe(tag)
            }, eingebettet: true)
        }
    }

    private func pfeil(_ symbol: String, _ tage: Int, _ beschriftung: String, aktiv: Bool) -> some View {
        Button { blaettere(tage) } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(aktiv ? palette.text : palette.text2.opacity(0.4))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.federnd)
        .disabled(!aktiv)
        .accessibilityLabel(beschriftung)
    }

    // MARK: Dein Tag

    private var raster: some View {
        let tag = stand.tag
        let essen = umgebung.daten?.essen
        let kost = TagesFormEssen(kcal: Int((essen?.summe(tag).kcal ?? 0).rounded()), ziel: essen?.ernaehrungsZiele(tag: tag).kcal ?? 0)
        return TagesFormenReihe(stand: stand, essen: kost, tippe: { modell.tippe($0) }, oeffne: { oeffne($0) }) {
            CoachKachelView(alsKachel: true, oeffne: { umgebung.router.schiebe(.coach(frage: nil)) })
        }
    }

    /// Wohin eine Kachel führt (`HeuteView.swift:775-960`): Schritte, Schlaf, Habits, Food und Gym als Seite im Stapel, Gewicht als Blatt.
    private func oeffne(_ form: TagesForm) {
        switch form {
        case .schritte: schritteSeite = true
        case .schlaf: umgebung.router.schiebe(.schlaf(.letzteNacht))
        case .habits: habitsSeite = true
        case .protein: umgebung.router.schiebe(.essen(.heute))
        case .gewicht: oeffneBlatt(.gewicht)
        case .training: gym()
        case .wasser, .koffein, .creatin, .stimmung: break
        }
    }

    private func gym() { umgebung.router.schiebe(.gym(.training)) }

    private var habitsSeiteInhalt: some View {
        ScrollView {
            HabitsKarte(habits: stand.habits, tag: stand.tag, tippe: { modell.tippe($0) }, weniger: { modell.weniger($0) },
                        oeffne: { oeffneHabit($0.habit.id) }, verwalte: { oeffneBlatt(.habits) }, zoom: zoom)
                .padding(16)
        }
        .lumenHintergrund()
        .navigationTitle("Gewohnheiten")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Körper und Verlauf

    /// Lovea `KoerperInhalt` ohne Streifen, Figur und nächstes Training (`HeuteView.swift:668`): Bilanz, Ziele-Karte solange keine Ziele da sind, "Sätze diese Woche".
    @ViewBuilder
    private var koerper: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        let daten = q.koerper
        VStack(alignment: .leading, spacing: Abstand.m) {
            Text(daten.streifen.bilanz).font(.footnote).foregroundStyle(palette.text2).frame(maxWidth: .infinity)
            if !q.zieleGesetzt { ZielFestlegenKarte { befragung = true } }
            SaetzeFelderKarte(daten: daten) { koerperAuswahl = KoerperAuswahl(gruppe: $0, teil: nil) }
        }
    }

    /// Lovea `kasten("Verlauf", …)` (`HeuteView.swift:718`): Symbol in getönter Fläche, Titel, Zeile, Pfeil.
    private var verlaufZeile: some View {
        Button { umgebung.router.schiebe(.verlauf) } label: {
            HStack(spacing: 14) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(TagesForm.schlaf.farbe)
                    .frame(width: 44, height: 44)
                    .background(TagesForm.schlaf.farbe.opacity(0.18), in: .rect(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verlauf").font(.headline).foregroundStyle(palette.text)
                    Text("Übungen und Muskelgruppen").font(.subheadline).foregroundStyle(palette.text2).lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lumenKartenFlaeche()
            .contentShape(.rect(cornerRadius: Rundung.karte, style: .continuous))
        }
        .buttonStyle(.federnd)
    }

    // MARK: Mehr aus Lumen Fit

    /// Was Lovea nicht hat und Lumen Fit schon: Bereit-Score, Hinweise des Tages, Energie über den Tag, Plan-Karte mit Start, Schritte, Gewicht mit Verlauf und die Woche in Bögen.
    @ViewBuilder
    private var mehr: some View {
        let unten = stand.istHeute || stand.hatTagesdaten
        if unten {
            abschnitt("Mehr aus Lumen Fit") {
                if stand.hatGesundheit { ScoreKarte(score: stand.score) { oeffneBlatt(.score) } }
                if stand.istHeute, !stand.hinweise.isEmpty { HinweiseKarte(hinweise: stand.hinweise) { modell.wischeHinweis($0) } }
                if stand.istHeute {
                    ListenKarte { EnergieVerlaufDiagramm(energie: stand.energie).padding(Abstand.l) }
                    PlanKarte(plan: stand.plan) { starte(stand.plan) }
                }
                if stand.hatGesundheit { SchritteKarte(schritte: stand.schritte) { schritteSeite = true } }
                GewichtKarte(gewicht: stand.gewicht, wiege: { oeffneBlatt(.gewicht) }, eintragbar: stand.istHeute)
                if stand.istHeute, stand.hatGesundheit { WochenStreifen(woche: stand.woche) { oeffneBlatt(.tag($0)) } }
                if stand.istHeute { PartnerKarte(bereich: .heute) }
            }
        }
    }

    /// Lovea `abschnitt`: Überschrift `title2.bold`, darunter der Inhalt (`HeuteView.swift:690`).
    private func abschnitt<Inhalt: View>(_ titel: String, @ViewBuilder _ inhalt: () -> Inhalt) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titel).font(.title2.bold()).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            inhalt()
        }
    }
}

/// Lovea `TagesformKarte` + `TagesformGefuehlLeiste` (`HeuteView.swift:130`, `Tagesform/TagesformBlock.swift:67`): Ring mit Urteil, zwei bis drei Gründe, "Für heute",
/// darunter fünf Batterien fürs eigene Gefühl. Ein Tipp auf die Karte öffnet die Gründe (Blatt Energie).
struct TagesformLoveaKarte: View {
    let energie: HeuteEnergie
    let bearbeitbar: Bool
    let detail: () -> Void
    let gefuehl: (Int) -> Void
    @Environment(\.palette) private var palette
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        VStack(spacing: 0) {
            Button(action: detail) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tagesform").font(.headline).foregroundStyle(palette.text)
                    TagesformRing(akku: energie.ergebnis.akku, urteil: energie.ergebnis.urteil)
                    if energie.ergebnis.akku == nil { Text(energie.ergebnis.satz).font(.subheadline).foregroundStyle(palette.text2) }
                    if let datei = PartnerAnzeige.zusammenfassung(VerbindenDemo.partner ?? umgebung.daten?.verbindung.partner ?? .nichtVerbunden),
                       PartnerAnzeige.energie(datei) != nil {
                        // Lovea `EnergieKarte.swift` partnerZeile: der Rat der Person steht in der Tagesform-Karte.
                        PartnerEnergieZeile(datei: datei).padding(.horizontal, -Abstand.l)
                    }
                    if let kappe = energie.ergebnis.kappe {
                        Label("Obergrenze: \(kappe.text)", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(LoveaDaten.ueber)
                    }
                    if !energie.klartext.gruende.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(energie.klartext.gruende.enumerated()), id: \.offset) { _, zeile in grund(zeile) }
                        }
                    }
                    if let hinweis = energie.klartext.hinweis { Text(hinweis).font(.footnote).foregroundStyle(palette.text2) }
                    if let empfehlung = energie.klartext.empfehlung {
                        VStack(alignment: .leading, spacing: 4) {
                            Divider()
                            Text("Für heute").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2)
                            Text(empfehlung).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Zeigt, woraus die Tagesform entsteht")
            if bearbeitbar || energie.gefuehl != nil {
                GefuehlLeiste(gewaehlt: energie.gefuehl, bearbeitbar: bearbeitbar, waehlen: gefuehl)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    /// Das Symbol zeigt, was gemeint ist, die Farbe die Richtung (orange bremst, grün hilft); für VoiceOver steht es als Wort davor.
    private func grund(_ zeile: TagesformKlartext.Zeile) -> some View {
        let farbe: Color = zeile.bremst ? .orange : .green
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: zeile.art.symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(farbe)
                .frame(minWidth: 22)
                .accessibilityHidden(true)
            Text(zeile.text).font(.subheadline).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((zeile.bremst ? "Bremst: " : "Hilft: ") + zeile.text)
    }
}

/// Fünf Batterien, ein Antippen speichert; die gewählte ist hinterlegt (Lovea `TagesformGefuehlLeiste`).
private struct GefuehlLeiste: View {
    let gewaehlt: Int?
    let bearbeitbar: Bool
    let waehlen: (Int) -> Void
    @State private var tipp = 0
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(gewaehlt.map { "Du fühlst dich: \(TagesformGefuehl.name($0))" } ?? "Wie fühlst du dich heute?")
                .font(.footnote.weight(.semibold)).foregroundStyle(palette.text2)
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { stufe in knopf(stufe) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .haptik(.auswahl, bei: tipp)
    }

    private func knopf(_ stufe: Int) -> some View {
        let aktiv = gewaehlt == stufe
        return Button {
            tipp += 1
            waehlen(stufe)
        } label: {
            Image(systemName: GefuehlBatterie.symbol(stufe))
                .font(.title3)
                .foregroundStyle(aktiv ? palette.akzent : palette.text2)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(aktiv ? palette.akzent.opacity(0.18) : Color.clear, in: .rect(cornerRadius: 10, style: .continuous))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!bearbeitbar)
        .accessibilityLabel("Gefühl \(stufe) von 5, \(TagesformGefuehl.name(stufe))")
        .accessibilityAddTraits(aktiv ? .isSelected : [])
    }
}

/// Lovea `CoachKachel` (`Coach/CoachChatView.swift:73`): unter dem Raster steht nur der Sicherheits-Hinweis (zu wenig Essen im Log), ungekürzt; sonst nichts.
/// Alles andere zeigt die Coach-Kachel im Raster.
struct CoachSicherheitZeile: View {
    let oeffne: () -> Void
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var schrift

    var body: some View {
        if let daten = umgebung.daten, !CoachEinstellungen(ordner: daten.ordner).stand.pause,
           let karte = CoachRegeln.karten(CoachDaten.eingabe(umgebung, daten)).first, karte.art == .sicherheit {
            Button(action: oeffne) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles").font(.title3).foregroundStyle(HabitFarbe.mint.farbe).frame(width: 28).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Coach").font(.headline).foregroundStyle(palette.text)
                        Text(karte.titel).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                        Text(karte.text).font(.footnote).foregroundStyle(palette.text2).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .lumenKartenFlaeche()
                .contentShape(.rect(cornerRadius: Rundung.karte, style: .continuous))
            }
            .buttonStyle(.federnd)
            .accessibilityHint("Öffnet den Coach-Chat")
        }
    }
}
