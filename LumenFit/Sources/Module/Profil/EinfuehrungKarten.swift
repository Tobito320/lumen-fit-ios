import SwiftUI

/// Der Inhalt einer Karte der Einführung (ohne Kopf und Knöpfe unten, die macht `OnboardingView`).
struct EinfuehrungKarte: View {
    @Bindable var fluss: ProfilOnboardingFluss
    var fokus: FocusState<Bool>.Binding
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        switch fluss.karte {
        case .willkommen: willkommen
        case .profil: profil
        case .einladung: einladung
        case .erfahrung: erfahrung
        case .ziele: ziele
        case .orte: orte
        case .tage:
            titel("Wie oft bist du pro Woche im Gym?", "Tipp auf Minus oder Plus.")
            EinfuehrungZaehler(wert: $fluss.gymTage, bereich: ProfilPraeferenzLogik.tageBereich, schritt: 1,
                               einheit: "mal pro Woche", hinweis: "3 mal ist für den Anfang ideal.")
        case .minuten:
            titel("Wie lange trainierst du meistens?", "Mit Aufwärmen, so ungefähr.")
            EinfuehrungZaehler(wert: Binding(get: { fluss.wahl.trainingsMinuten ?? ProfilPraeferenzLogik.standardMinuten },
                                             set: { fluss.wahl.trainingsMinuten = $0 }),
                               bereich: ProfilPraeferenzLogik.minutenBereich, schritt: ProfilPraeferenzLogik.minutenSchritt,
                               einheit: "Minuten", hinweis: "60 Minuten reichen für den Anfang.")
        case .fokus:
            titel("Gibt es Muskeln, die dir besonders wichtig sind?", "Tipp höchstens 2 an. Alles andere trainierst du trotzdem mit.")
            EinfuehrungFokusWahl(fokus: $fluss.wahl.fokusMuskeln)
        case .mitzaehlen: mitzaehlen
        case .nutzung: NutzungFrageText()
        case .health: health
        case .plan: EinfuehrungPlanAnsicht(vorlage: fluss.plan, fokus: fluss.wahl.fokusMuskeln)
        }
    }

    // MARK: - Karten

    private var willkommen: some View {
        VStack(spacing: Abstand.l) {
            LumiView(stimmung: .willkommen, groesse: 160).padding(.top, Abstand.l)
            Text("Hallo, ich bin Lumi.").font(.largeTitle.bold()).foregroundStyle(palette.text).multilineTextAlignment(.center)
            Text("Ich zähle mit, wenn du dich bewegst, trainierst und dich erholst. Das Einrichten dauert eine Minute.")
                .font(.body).foregroundStyle(palette.text2).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var profil: some View {
        titel("Wie soll ich dich nennen?", "Deine Daten bleiben auf deinem iPhone. Nur dein Name geht an den Lumen-Server, damit Einstellungen ohne Update änderbar sind.")
        VStack(alignment: .leading, spacing: Abstand.m) {
            TextField("Dein Name", text: $fluss.name)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused(fokus)
                .onSubmit { fokus.wrappedValue = false }
                .modifier(EinfuehrungFeld())
            if let hinweis = fluss.nameHinweis {
                Text(hinweis).font(.footnote).foregroundStyle(palette.text2)
            }
        }
        Label {
            Text("Du brauchst kein Passwort. Wenn du eines willst, legst du es später unter Konto fest.")
                .font(.subheadline).foregroundStyle(palette.text2)
        } icon: {
            Image(systemName: "lock.open.fill").foregroundStyle(palette.text)
        }
    }

    @ViewBuilder private var einladung: some View {
        titel("Hat dich jemand eingeladen?", "Dann tipp den Code deines Freundes ein. Nach dem Einrichten seid ihr verbunden.")
        VStack(alignment: .leading, spacing: Abstand.m) {
            HStack(spacing: Abstand.s) {
                TextField("K7Q2-9FX", text: $fluss.einladung)
                    .font(.title3.monospaced())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused(fokus)
                    .onSubmit { fokus.wrappedValue = false }
                    .accessibilityLabel("Code deines Freundes")
                    .modifier(EinfuehrungFeld())
                // iOS fragt nach der Zwischenablage erst, wenn man selbst auf Einfügen tippt.
                PasteButton(payloadType: String.self) { [fluss] texte in
                    let text = texte.first ?? ""
                    Task { @MainActor in fluss.einladung = text }
                }
                .labelStyle(.iconOnly)
                .buttonBorderShape(.capsule)
                .tint(palette.akzent)
            }
            if !fluss.einladungGueltig {
                Text("Das ist kein Code von Lumen Fit. Ein Code hat 8 Zeichen, zum Beispiel K7Q2-9FX.")
                    .font(.footnote).foregroundStyle(palette.text2)
            }
        }
    }

    @ViewBuilder private var erfahrung: some View {
        titel("Wie lange trainierst du schon?", "Damit Gewichte und Tempo zu dir passen.")
        VStack(spacing: Abstand.s) {
            ForEach(TrainingsErfahrung.allCases, id: \.self) { e in
                EinfuehrungOption(titel: ProfilPraeferenzLogik.titel(e), an: fluss.wahl.trainingsErfahrung == e) { fluss.waehleErfahrung(e) }
            }
        }
    }

    @ViewBuilder private var ziele: some View {
        titel("Was ist dir wichtig?", "Du kannst mehrere wählen.")
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Abstand.s), GridItem(.flexible(), spacing: Abstand.s)], spacing: Abstand.s) {
            ForEach(TrainingsZiel.allCases, id: \.self) { z in
                EinfuehrungKachel(titel: ProfilPraeferenzLogik.titel(z), hinweis: ProfilPraeferenzLogik.hinweis(z), symbol: ProfilPraeferenzLogik.symbol(z),
                                  empfehlung: z == .muskeln, an: fluss.wahl.trainingsZiele.contains(z)) {
                    fluss.wahl.trainingsZiele = ProfilPraeferenzLogik.umschalten(fluss.wahl.trainingsZiele, z)
                }
            }
        }
    }

    @ViewBuilder private var orte: some View {
        titel("Wo trainierst du?", "Du kannst mehrere wählen. Du bekommst nur Übungen, die dort gehen.")
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Abstand.s), GridItem(.flexible(), spacing: Abstand.s)], spacing: Abstand.s) {
            ForEach(TrainingsOrt.allCases, id: \.self) { o in
                EinfuehrungKachel(titel: ProfilPraeferenzLogik.titel(o), hinweis: ProfilPraeferenzLogik.hinweis(o), symbol: ProfilPraeferenzLogik.symbol(o),
                                  empfehlung: o == .studio, an: fluss.wahl.trainingsOrte.contains(o)) {
                    fluss.wahl.trainingsOrte = ProfilPraeferenzLogik.umschalten(fluss.wahl.trainingsOrte, o)
                }
            }
        }
    }

    @ViewBuilder private var mitzaehlen: some View {
        titel("Was willst du nebenbei im Blick behalten?", "Nur was du einschaltest, siehst du auf der Startseite.")
        EinfuehrungMitzaehlen(wahl: $fluss.wahl, schlafSichtbar: umgebung.konto.schlafSichtbar)
        Button("Nichts davon") {
            fluss.wahl.gewichtMitzaehlen = false
            fluss.wahl.schritteMitzaehlen = false
            fluss.wahl.creatinMitzaehlen = false
            fluss.setzeBereich(.schlaf, an: false)
            fluss.setzeBereich(.essen, an: false)
        }
        .font(.body.weight(.medium))
        .foregroundStyle(palette.akzent)
        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
        Text("Du kannst das jederzeit ändern: Profil, Präferenzen.")
            .font(.footnote).foregroundStyle(palette.text2).frame(maxWidth: .infinity)
    }

    @ViewBuilder private var health: some View {
        titel("Health dazunehmen?", "Lumen Fit liest nur, was du gewählt hast, aus Health. So ist dein erster Tag schon voll. Alles bleibt auf deinem iPhone.")
        ListenKarte {
            ProfilZeile(symbol: "figure.walk", titel: String(localized: "Schritte und Bewegung"), zeile: String(localized: "Für deinen Tagesbogen"), pfeil: false)
            if fluss.wahl.schlafAn, umgebung.konto.schlafSichtbar {
                Haarlinie()
                ProfilZeile(symbol: "bed.double.fill", titel: String(localized: "Schlaf und Erholung"), zeile: String(localized: "Für deine Nächte und die Bereitschaft"), pfeil: false)
            }
            if fluss.wahl.gymAn {
                Haarlinie()
                ProfilZeile(symbol: "dumbbell.fill", titel: String(localized: "Training"), zeile: String(localized: "Damit Training von der Uhr zählt"), pfeil: false)
            }
            Haarlinie()
            ProfilZeile(symbol: "scalemass.fill", titel: String(localized: "Gewicht"), zeile: String(localized: "Für Verlauf und Ziel"), pfeil: false)
        }
        Text("Du kannst das auch später ändern: Einstellungen, Health, Datenzugriff und Geräte, Lumen Fit.")
            .font(.footnote).foregroundStyle(palette.text2)
    }

    private func titel(_ titel: LocalizedStringKey, _ text: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text(titel).font(.largeTitle.bold()).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            Text(text).font(.body).foregroundStyle(palette.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Bausteine

/// Eingabefeld auf der Fläche des Themes.
private struct EinfuehrungFeld: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content
            .padding(Abstand.m)
            .frame(minHeight: Abstand.tippflaeche)
            .background(palette.flaeche, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
    }
}

/// Haken rechts oben oder am Ende: gefüllt in Lime, wenn gewählt.
private struct EinfuehrungHaken: View {
    let an: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        Image(systemName: an ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(an ? palette.akzent : palette.text2)
            .accessibilityHidden(true)
    }
}

/// Eine Antwort als Zeile (Einfachauswahl).
struct EinfuehrungOption: View {
    let titel: String
    var hinweis: String?
    var empfehlung = false
    let an: Bool
    let tippen: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: tippen) {
            HStack(spacing: Abstand.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel).font(.body.weight(.semibold)).foregroundStyle(palette.text)
                    if let hinweis { Text(hinweis).font(.footnote).foregroundStyle(palette.text2) }
                }
                Spacer(minLength: Abstand.s)
                if empfehlung { Text("Empfehlung").font(.footnote).foregroundStyle(palette.text2) }
                EinfuehrungHaken(an: an)
            }
            .padding(Abstand.l)
            .frame(minHeight: 56)
            .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous).strokeBorder(an ? palette.akzent : .clear, lineWidth: 2))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(an ? .isSelected : [])
        .haptik(.auswahl, bei: an)
    }
}

/// Eine Antwort als Kachel mit Symbol (Mehrfachauswahl, zwei nebeneinander).
private struct EinfuehrungKachel: View {
    let titel: String
    let hinweis: String
    let symbol: String
    let empfehlung: Bool
    let an: Bool
    let tippen: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: tippen) {
            VStack(alignment: .leading, spacing: Abstand.s) {
                HStack(alignment: .top) {
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundStyle(palette.akzent)
                        .frame(width: 48, height: 48)
                        .background(palette.grund, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
                        .accessibilityHidden(true)
                    Spacer(minLength: 0)
                    EinfuehrungHaken(an: an)
                }
                Text(titel).font(.headline).foregroundStyle(palette.text).fixedSize(horizontal: false, vertical: true)
                Text(hinweis).font(.footnote).foregroundStyle(palette.text2).fixedSize(horizontal: false, vertical: true)
                if empfehlung { Text("Empfehlung").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2) }
                Spacer(minLength: 0)
            }
            .padding(Abstand.l)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous).strokeBorder(an ? palette.akzent : .clear, lineWidth: 2))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(an ? .isSelected : [])
        .haptik(.auswahl, bei: an)
    }
}

/// Zähler mit Minus und Plus, die große Zahl in der Mitte.
struct EinfuehrungZaehler: View {
    @Binding var wert: Int
    let bereich: ClosedRange<Int>
    let schritt: Int
    let einheit: LocalizedStringKey
    var hinweis: LocalizedStringKey?
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: Abstand.s) {
            HStack {
                knopf("minus", -schritt).disabled(wert <= bereich.lowerBound)
                Spacer(minLength: Abstand.s)
                VStack(spacing: 0) {
                    Text(wert, format: .number).font(.system(size: 56, weight: .bold).monospacedDigit()).foregroundStyle(palette.text)
                        .contentTransition(.numericText())
                    Text(einheit).font(.subheadline).foregroundStyle(palette.text2)
                }
                Spacer(minLength: Abstand.s)
                knopf("plus", schritt).disabled(wert >= bereich.upperBound)
            }
            .padding(Abstand.l)
            .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(einheit))
            .accessibilityValue(Text(wert, format: .number))
            .accessibilityAdjustableAction { richtung in
                switch richtung {
                case .increment: setze(wert + schritt)
                case .decrement: setze(wert - schritt)
                @unknown default: break
                }
            }
            if let hinweis { Text(hinweis).font(.footnote).foregroundStyle(palette.text2) }
        }
        .haptik(.auswahl, bei: wert)
    }

    private func knopf(_ symbol: String, _ schritt: Int) -> some View {
        Button { setze(wert + schritt) } label: {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(palette.text)
                .frame(width: 56, height: 56)
                .background(palette.grund, in: .circle)
        }
        .buttonStyle(.plain)
    }

    private func setze(_ neu: Int) { wert = min(max(neu, bereich.lowerBound), bereich.upperBound) }
}

/// Fokus-Muskeln als Chips (höchstens zwei) und "Nein, alles ausgewogen".
struct EinfuehrungFokusWahl: View {
    @Binding var fokus: [String]
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: Abstand.m) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Abstand.s)], spacing: Abstand.s) {
                ForEach(ProfilPraeferenzLogik.fokusWahl, id: \.self) { g in
                    let an = fokus.contains(g.rawValue)
                    Button { fokus = ProfilPraeferenzLogik.fokusUmschalten(fokus, g) } label: {
                        Text(g.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(an ? palette.aufAkzentFlaeche : palette.text)
                            .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                            .background(an ? palette.akzentFlaeche : palette.flaeche, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(an ? .isSelected : [])
                }
            }
            EinfuehrungOption(titel: String(localized: "Nein, alles ausgewogen"), hinweis: String(localized: "Jeder Muskel bekommt gleich viel"),
                              empfehlung: true, an: fokus.isEmpty) { fokus = [] }
        }
        .haptik(.auswahl, bei: fokus)
    }
}

/// Die Schalter "Mitzählen": Körpergewicht, Schritte, Schlaf (nur mit Freigabe des Servers), Creatin, Essen (bis zum Umzug zu Lovea).
/// Schlaf und Essen sind die Bereiche (`AppBereich`); der letzte Bereich bleibt an.
struct EinfuehrungMitzaehlen: View {
    @Binding var wahl: Einstellungen
    let schlafSichtbar: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        ListenKarte {
            schalter(String(localized: "Körpergewicht"), String(localized: "Einmal pro Woche wiegen reicht"), "scalemass.fill", Bereichsfarbe.gewicht, $wahl.gewichtMitzaehlen)
            Haarlinie()
            schalter(String(localized: "Schritte"), String(localized: "Aus Apple Health"), "figure.walk", .orange, $wahl.schritteMitzaehlen)
            if schlafSichtbar {
                Haarlinie()
                schalter(String(localized: "Schlaf"), String(localized: "Aus Apple Health"), "bed.double.fill", .indigo, bereich(.schlaf))
            }
            Haarlinie()
            schalter(String(localized: "Creatin"), String(localized: "3,5 g pro Tipp. Lohnt sich, sobald du regelmäßig trainierst"), "pills.fill", Bereichsfarbe.creatin, $wahl.creatinMitzaehlen)
            Haarlinie()
            schalter(String(localized: "Essen"), String(localized: "Kalorien und Protein"), "fork.knife", .pink, bereich(.essen))
        }
    }

    private func bereich(_ b: AppBereich) -> Binding<Bool> {
        Binding(get: { wahl.zeigt(b) }, set: { wahl.setze(b, an: $0) })
    }

    private func schalter(_ titel: String, _ zeile: String, _ symbol: String, _ farbe: Color, _ an: Binding<Bool>) -> some View {
        Toggle(isOn: an) {
            HStack(spacing: Abstand.m) {
                SymbolQuadrat(symbol: symbol, farbe: farbe)
                VStack(alignment: .leading, spacing: 2) {
                    Text(titel).font(.body).foregroundStyle(palette.text)
                    Text(zeile).font(.footnote).foregroundStyle(palette.text2)
                }
            }
        }
        .tint(palette.akzentFlaeche)
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.m)
        .frame(minHeight: 64)
    }
}

/// "Dein Plan steht": Lumi, der Split mit Woche und Tag 1 mit seinen Übungen. Rechnet nichts selbst: die Vorlage kommt fertig aus dem Fluss.
struct EinfuehrungPlanAnsicht: View {
    let vorlage: SplitVorlage?
    let fokus: [String]
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.l) {
            Text("Dein Plan steht").font(.largeTitle.bold()).foregroundStyle(palette.text).accessibilityAddTraits(.isHeader)
            HStack(spacing: Abstand.m) {
                LumiView(stimmung: .willkommen, groesse: 48)
                Text(vorlage == nil ? "Für deine Antworten habe ich noch keinen fertigen Plan. Du suchst dir gleich selbst einen aus."
                                    : "Ich hab dir einen Plan gebaut. Wir fangen klein an.")
                    .font(.subheadline.weight(.medium)).foregroundStyle(palette.text)
            }
            if let vorlage { plan(vorlage) }
        }
    }

    @ViewBuilder private func plan(_ v: SplitVorlage) -> some View {
        let tag1 = SplitLogik.alsPlan(v).tage.first
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Passt zu deinen Antworten").font(.footnote).foregroundStyle(palette.text2)
            Text(v.name).font(.title2.bold()).foregroundStyle(palette.text)
            Text(tag1.map { "\(SplitLogik.unterzeile(v)) · \(String(localized: "ca. \(ZeitSchaetzung.minuten($0)) min je Training"))" } ?? SplitLogik.unterzeile(v))
                .font(.subheadline).foregroundStyle(palette.text2)
            HStack(spacing: 0) {
                ForEach(Array(SplitLogik.wochenbild(v).enumerated()), id: \.offset) { i, an in
                    VStack(spacing: Abstand.xs) {
                        Text(HabitLogik.wochentagKuerzel[i]).font(.caption.weight(.semibold)).foregroundStyle(palette.text2)
                        Circle()
                            .fill(an ? palette.akzentFlaeche : palette.haar)
                            .frame(width: an ? 28 : 6, height: an ? 28 : 6)
                            .frame(height: 28)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(TrainingLogik.wochentagName[i]): \(an ? String(localized: "Training") : String(localized: "frei"))")
                }
            }
            .padding(.top, Abstand.s)
        }
        .padding(Abstand.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        if let e = v.einheiten.first {
            HStack {
                Text("Tag 1: \(e.name)").font(.title3.bold()).foregroundStyle(palette.text)
                Spacer()
                Text("\(e.uebungen.count) Übungen").font(.footnote).foregroundStyle(palette.text2)
            }
            ListenKarte {
                ForEach(Array(e.uebungen.enumerated()), id: \.offset) { i, z in
                    if i > 0 { Haarlinie() }
                    let u = UebungsKatalog.nachId[z.uebung]
                    HStack(spacing: Abstand.m) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(u?.name ?? String(localized: "Übung")).font(.body).foregroundStyle(palette.text)
                            Text("\(u?.koerper ?? "") · \(SplitLogik.wdhText(z))").font(.footnote).foregroundStyle(palette.text2)
                        }
                        Spacer(minLength: Abstand.s)
                        if let u, fokus.contains(where: { MuskelGruppe(rawValue: $0)?.name == u.koerper }) { Pille(text: String(localized: "Fokus")) }
                    }
                    .padding(.horizontal, Abstand.l)
                    .padding(.vertical, Abstand.m)
                    .accessibilityElement(children: .combine)
                }
            }
            Text("Klappen alle Sets, schlägt Lumen Fit beim nächsten Mal etwas mehr Gewicht vor.")
                .font(.footnote).foregroundStyle(palette.text2)
        }
    }
}
