// Quelle: Lovea Health/EnergieKarte.swift (SchlafEintragenView)
import SwiftUI

/// Bett- und Aufstehzeit von Hand: eintragen, korrigieren, nachtragen (jede vergangene Nacht) und löschen. Ein Eintrag gilt vor jeder automatischen Quelle.
/// `tag` ist der Aufwachtag. Löschen nimmt nur den eigenen Eintrag weg; danach gilt wieder die automatische Erkennung.
struct SchlafEintragenView: View {
    let gespeichert: () -> Void
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var tag: String
    @State private var bett: Date
    @State private var auf: Date
    @State private var loeschenFragen = false
    @State private var fertig = 0
    @State private var geloescht = 0

    init(tag: String, nacht: SchlafNacht?, gespeichert: @escaping () -> Void) {
        self.gespeichert = gespeichert
        _tag = State(initialValue: tag)
        let start = SchlafHandLogik.start(tag: tag, vorhanden: nacht)
        _bett = State(initialValue: start.bett)
        _auf = State(initialValue: start.auf)
    }

    /// Die Nacht, die für `tag` gerade gilt (eigener Eintrag, Uhr, Handy oder Band).
    private func geltend(_ tag: String) -> SchlafGewaehlteNacht? {
        SchlafDaten.uebersicht(umgebung, band: SchlafDaten.bandOps(umgebung)).naechte.first { $0.nacht.tag == tag }
    }

    private var tagDatum: Binding<Date> {
        Binding(get: { Datum.datum(tag) }, set: { tag = Datum.text($0) })
    }

    private var eintrag: SchlafHandD? { SchlafHandLogik.eintrag(tag: tag, bett: bett, auf: auf) }
    private var minuten: Int { eintrag.flatMap(SchlafHandLogik.nacht)?.schlafMinuten ?? 0 }

    var body: some View {
        let aktuell = geltend(tag)
        let eigener = aktuell?.quelle == .eingetragen
        NavigationStack {
            Form {
                Section {
                    DatePicker("Aufgewacht am", selection: tagDatum, in: ...umgebung.uhr(), displayedComponents: .date)
                        .environment(\.locale, Datum.anzeigeLocale)
                        .environment(\.timeZone, Datum.zone)
                        .frame(minHeight: Abstand.tippflaeche)
                } footer: {
                    Text(fuss(aktuell))
                }
                Section {
                    DatePicker("Ins Bett", selection: $bett, displayedComponents: .hourAndMinute).frame(minHeight: Abstand.tippflaeche)
                    DatePicker("Aufgestanden", selection: $auf, displayedComponents: .hourAndMinute).frame(minHeight: Abstand.tippflaeche)
                    LabeledContent("Geschlafen") {
                        Text(minuten > 0 ? SchlafFormat.dauer(minuten) : "–").monospacedDigit().contentTransition(.numericText())
                    }
                } footer: {
                    Text("Was du hier einträgst, ersetzt die automatische Erkennung für diese Nacht. Erlaubt sind 1 bis 16 Stunden.")
                }
                if eigener {
                    Section {
                        Button("Eintrag löschen", systemImage: "trash", role: .destructive) { loeschenFragen = true }.frame(minHeight: Abstand.tippflaeche)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .lumenHintergrund()
            .navigationTitle(aktuell == nil ? "Schlaf eintragen" : "Nacht korrigieren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Sichern") { sichern() }.disabled(minuten == 0) }
            }
            .confirmationDialog("Eintrag für diese Nacht löschen?", isPresented: $loeschenFragen, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) { loeschen() }
            } message: {
                Text("Danach gilt wieder, was Uhr, Handy oder Band erkannt haben.")
            }
            .onChange(of: tag) { _, neu in
                let start = SchlafHandLogik.start(tag: neu, vorhanden: geltend(neu)?.nacht)
                bett = start.bett
                auf = start.auf
            }
            .haptik(.erfolg, bei: fertig)
            .haptik(.stopp, bei: geloescht)
        }
        .presentationDetents([.medium, .large])
    }

    private func fuss(_ aktuell: SchlafGewaehlteNacht?) -> String {
        guard let aktuell else { return String(localized: "Für diese Nacht ist noch nichts eingetragen.") }
        if aktuell.quelle == .eingetragen { return String(localized: "Für diese Nacht gibt es schon einen Eintrag. Sichern ersetzt ihn.") }
        return String(localized: "Für diese Nacht gibt es eine automatische Erkennung (\(aktuell.quelle.name)). Sichern ersetzt sie.")
    }

    private func sichern() {
        guard let eintrag, let raum = umgebung.daten?.raum else { return }
        raum.senden(SchlafHandLogik.art, eintrag)
        umgebung.ereignisse.senden(.healthAktualisiert)
        fertig += 1
        gespeichert()
        dismiss()
    }

    private func loeschen() {
        guard let raum = umgebung.daten?.raum else { return }
        raum.senden(SchlafHandLogik.art, SchlafHandD(tag: tag, bett: bett, auf: auf, geloescht: true))
        umgebung.ereignisse.senden(.healthAktualisiert)
        geloescht += 1
        gespeichert()
        dismiss()
    }
}

/// Schlafziel mit Extra-Tagen: an den gewählten Wochentagen gilt das Ziel plus (oder minus) die gewählten Minuten. Jede Änderung gilt sofort.
/// Das Grundziel steht unter Ziele und Körper.
struct SchlafZielView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var extra = SchlafZielExtra()
    @State private var geladen = false
    @State private var umgeschaltet = 0

    private var basis: Int { umgebung.daten?.ziele.ziele.schlafMinuten ?? 480 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                ListenKarte {
                    HStack {
                        Text("Grundziel").font(.body)
                        Spacer()
                        Text(SchlafFormat.dauer(basis)).font(.body.monospacedDigit()).foregroundStyle(palette.text2)
                    }
                    .padding(Abstand.l)
                    .accessibilityElement(children: .combine)
                    Haarlinie()
                    Stepper(value: Binding(get: { extra.extraMinuten }, set: { extra.extraMinuten = $0; sichere() }),
                            in: -SchlafZielLogik.extraGrenze...SchlafZielLogik.extraGrenze, step: 15) {
                        HStack {
                            Text("An diesen Tagen").font(.body)
                            Spacer()
                            Text(SchlafZielLogik.extraText(extra.extraMinuten)).font(.body.monospacedDigit()).foregroundStyle(palette.text2)
                        }
                    }
                    .padding(Abstand.l)
                    .frame(minHeight: Abstand.tippflaeche)
                    Haarlinie()
                    HStack(spacing: Abstand.xs) {
                        ForEach(1...7, id: \.self) { tag in
                            let an = SchlafLogik.istExtraTag(extra.extraTage, tag)
                            Button {
                                extra.extraTage = SchlafZielLogik.umgeschaltet(extra.extraTage, wochentag: tag)
                                umgeschaltet += 1
                                sichere()
                            } label: {
                                Text(HabitLogik.wochentagKuerzel[tag - 1]).font(.subheadline.weight(.semibold))
                                    .foregroundStyle(an ? palette.aufAkzent : palette.text)
                                    .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                                    .background(an ? palette.akzent : palette.haar, in: .rect(cornerRadius: Rundung.klein, style: .continuous))
                            }
                            .buttonStyle(.federnd)
                            .accessibilityLabel(HabitLogik.wochentagKuerzel[tag - 1])
                            .accessibilityValue(an ? "Extra-Tag" : "normaler Tag")
                            .accessibilityAddTraits(an ? .isSelected : [])
                        }
                    }
                    .padding(Abstand.l)
                }
                Text(erklaerung).font(.footnote).foregroundStyle(palette.text2)
            }
            .padding(Abstand.l)
        }
        .navigationTitle("Schlafziel")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .onAppear(perform: lade)
        .haptik(.auswahl, bei: umgeschaltet)
    }

    private var erklaerung: String {
        let ziel = SchlafFormat.dauer(max(0, basis + extra.extraMinuten))
        return extra.extraTage == 0 ? String(localized: "Wähle Wochentage, an denen du mehr (oder weniger) Schlaf brauchst, zum Beispiel vor Trainingstagen.")
            : String(localized: "An den gewählten Tagen gilt \(ziel). Der Schlaf-Tab und der Schlafbogen in Heute rechnen damit.")
    }

    private func lade() {
        guard !geladen, let raum = umgebung.daten?.raum else { return }
        extra = SchlafZielLogik.extra(ops: raum.ops(arten: [SchlafZielLogik.art]))
        geladen = true
    }

    private func sichere() {
        guard let raum = umgebung.daten?.raum else { return }
        raum.senden(SchlafZielLogik.art, SchlafZielLogik.geklemmt(extra))
        umgebung.ereignisse.senden(.einstellungenGeaendert)
    }
}
