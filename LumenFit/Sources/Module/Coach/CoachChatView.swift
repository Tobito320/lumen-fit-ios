import SwiftUI

/// Der Chat von heute. Die Tage davor stehen im Verlauf (`CoachVerlaufView`), das Gedächtnis und die Einstellungen im Menü.
struct CoachChatView: View {
    @Bindable var modell: CoachModell
    var frage: String?

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var reduceMotion
    @State private var blatt: CoachBlatt?
    @State private var hervorgehoben: String?
    @State private var amEnde = true
    @State private var neueAntwort = false
    @State private var stoppSignal = 0
    @State private var sendeZaehler = 0
    @State private var ausblendenFrage = false
    @State private var zielFrage = false
    @State private var zielText = ""
    @FocusState private var fokus: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Abstand.l) {
                    if modell.morgenCheckSichtbar { CoachMorgenCheckKarte(modell: modell).transition(.opacity) }
                    if modell.heute.isEmpty, !modell.denkt { willkommen.transition(.opacity) }
                    ForEach(Array(modell.heute.enumerated()), id: \.element.id) { index, nachricht in
                        if CoachText.trennerNoetig(vorher: index > 0 ? modell.heute[index - 1].zeit : nil, jetzt: nachricht.zeit, kalender: Datum.kalender) {
                            trenner(nachricht.zeit)
                        }
                        zeile(nachricht, letzte: index == modell.heute.count - 1)
                            .id(nachricht.id)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                    }
                    if modell.denkt, let seit = modell.denkBeginn { CoachDenkAnzeige(seit: seit).id("denkt").transition(.opacity) }
                    Color.clear.frame(height: 1).id("ende")
                }
                .padding(.horizontal, Abstand.l)
                .padding(.top, Abstand.m)
                .padding(.bottom, Abstand.l)
                .animation(reduceMotion ? nil : Feder.weich, value: modell.heute.isEmpty)
                .animation(reduceMotion ? nil : Feder.weich, value: modell.heute.count)
                .animation(reduceMotion ? nil : Feder.weich, value: modell.morgenCheckSichtbar)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onScrollGeometryChange(for: Bool.self) { geometrie in
                geometrie.contentOffset.y + geometrie.containerSize.height >= geometrie.contentSize.height - 80
            } action: { _, unten in
                amEnde = unten
                if unten { neueAntwort = false }
            }
            .onChange(of: modell.heute.count) { antwortAnzeigen(proxy) }
            .onChange(of: modell.denkt) { scrolle(proxy) }
            .overlay(alignment: .bottomTrailing) {
                if !amEnde, !modell.heute.isEmpty { nachUnten(proxy) }
            }
            .animation(reduceMotion ? nil : Feder.schnell, value: amEnde)
            .sheet(item: $blatt) { art in
                CoachBlattAnsicht(blatt: art, modell: modell) { id in springe(id, proxy) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { eingabe }
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: Abstand.s) {
                    LumiView(stimmung: modell.denkt ? .denkt : .bereit, groesse: 24)
                    Text(modell.einstellungen?.anzeigeName ?? CoachLokal.standardName).font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
            }
            ToolbarItem(placement: .topBarLeading) { menue }
            ToolbarItem(placement: .topBarTrailing) { AvatarKapsel() }
        }
        .task(id: frage) {
            modell.pruefeMorgenCheck()
            modell.beiVordergrund()
            if let frage { modell.senden(frage) }
        }
        .task(id: umgebung.router.coachEntwurf) {
            guard let text = umgebung.router.coachEntwurf else { return }
            modell.entwurf = String(text.prefix(CoachModell.maxZeichen))
            umgebung.router.coachEntwurf = nil
            fokus = true
        }
        .task {
            for await ereignis in umgebung.ereignisse.strom() {
                if case .vordergrund = ereignis {
                    modell.pruefeMorgenCheck()
                    modell.beiVordergrund()
                }
            }
        }
        .haptik(.erfolg, bei: modell.handlung?.id)
        .haptik(.erfolg, bei: modell.erfolgSignal)
        .haptik(.warnung, bei: modell.warnungSignal)
        .haptik(.auswahl, bei: modell.auswahlSignal)
        .haptik(.stopp, bei: stoppSignal)
        .haptik(.start, bei: sendeZaehler)
        .confirmationDialog("Verlauf ausblenden?", isPresented: $ausblendenFrage, titleVisibility: .visible) {
            Button("Ausblenden", role: .destructive) { modell.verlaufAusblenden() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Der Chat und der Verlauf werden leer. Nichts wird gelöscht, der Coach kennt die letzten Nachrichten weiter.")
        }
        .alert("Mein Ziel", isPresented: $zielFrage) {
            TextField("Zum Beispiel: 5 kg abnehmen bis Sommer", text: $zielText)
            Button("Sichern") { modell.setzeZiel(zielText) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Ein Satz. Der Coach richtet seine Antworten danach aus. Leer lassen entfernt das Ziel.")
        }
    }

    // MARK: - Teile

    private var menue: some View {
        Menu {
            Button("Suchen", systemImage: "magnifyingglass") { blatt = .suche }
            Button("Verlauf", systemImage: "clock.arrow.circlepath") { blatt = .verlauf }
            Button("Gedächtnis", systemImage: "brain.head.profile") { blatt = .gedaechtnis }
            Button("Gemerkte Antworten", systemImage: "bookmark") { blatt = .merkliste }
            Divider()
            Button("Mein Ziel", systemImage: "target") { zielText = modell.ziel; zielFrage = true }
            Picker("Ton", selection: Binding(get: { modell.ton }, set: { modell.setzeTon($0) })) {
                ForEach(CoachEinstellungen.toene, id: \.wert) { Text($0.name).tag($0.wert) }
            }
            Toggle("Morgen-Check", systemImage: "sun.max", isOn: Binding(get: { modell.morgenAn }, set: { modell.setzeMorgen($0) }))
            Toggle("Coach pausieren", systemImage: "pause.circle", isOn: Binding(get: { modell.pausiert }, set: { modell.setzePause($0) }))
            Divider()
            if !modell.heute.isEmpty {
                Button("Verlauf ausblenden", systemImage: "eye.slash") { ausblendenFrage = true }
            }
            Button("Einstellungen", systemImage: "gearshape") { blatt = .einstellungen }
        } label: {
            Image(systemName: "ellipsis.circle")
                .frame(minWidth: Abstand.tippflaeche, minHeight: Abstand.tippflaeche)
        }
        .accessibilityLabel("Mehr zum Coach")
    }

    private var willkommen: some View {
        VStack(spacing: Abstand.l) {
            LumiView(stimmung: .bereit, groesse: 96)
            Text(CoachText.begruessung(stunde: Datum.kalender.component(.hour, from: modell.jetzt)))
                .font(.title2.weight(.semibold)).foregroundStyle(palette.text)
            Text("Ich bin dein Coach. Frag mich nach Schlaf, Schritten, Training oder Essen. Alles bleibt auf deinem iPhone.")
                .font(.body).foregroundStyle(palette.text2).multilineTextAlignment(.center)
            CoachChipFluss {
                ForEach(CoachVorschlag.leerFragen(modell.schnellfragen), id: \.self) { frage in
                    CoachVorschlagChip(frage: frage, symbol: CoachVorschlag.symbol(fuer: frage)) { modell.senden(frage) }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Abstand.xl)
        .accessibilityElement(children: .contain)
    }

    private func trenner(_ zeit: Date) -> some View {
        Text("\(CoachAnzeige.tag(zeit)), \(CoachAnzeige.uhrzeit(zeit))")
            .font(.caption).foregroundStyle(palette.text2)
            .frame(maxWidth: .infinity)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func zeile(_ nachricht: CoachNachricht, letzte: Bool) -> some View {
        let hervor = hervorgehoben == nachricht.id
        switch nachricht.rolle {
        case .nutzer:
            CoachNutzerBlase(modell: modell, nachricht: nachricht, hervor: hervor)
        case .coach:
            CoachAntwortZeile(modell: modell, nachricht: nachricht, letzte: letzte, hervor: hervor)
        }
    }

    private func scrolle(_ proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo("ende", anchor: .bottom)
        } else {
            withAnimation(Feder.weich) { proxy.scrollTo("ende", anchor: .bottom) }
        }
    }

    /// Neue Nachricht: eine Antwort des Coachs beginnt oben im Bild (lesen von vorn), alles andere läuft nach unten.
    private func antwortAnzeigen(_ proxy: ScrollViewProxy) {
        guard let letzte = modell.heute.last, letzte.rolle == .coach, letzte.text != CoachPersona.fehlerText else {
            scrolle(proxy)
            return
        }
        if reduceMotion {
            proxy.scrollTo(letzte.id, anchor: .top)
        } else {
            withAnimation(Feder.weich) { proxy.scrollTo(letzte.id, anchor: .top) }
        }
        stoppSignal += 1
        neueAntwort = true
        AccessibilityNotification.Announcement("Antwort vom Coach: " + String(CoachAnzeige.klartext(CoachAnzeige.kopierText(letzte.text)).prefix(160))).post()
    }

    private func springe(_ id: String, _ proxy: ScrollViewProxy) {
        guard modell.heute.contains(where: { $0.id == id }) else { return }
        hervorgehoben = id
        if reduceMotion {
            proxy.scrollTo(id, anchor: .center)
        } else {
            withAnimation(Feder.weich) { proxy.scrollTo(id, anchor: .center) }
        }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(reduceMotion ? nil : Feder.weich) { if hervorgehoben == id { hervorgehoben = nil } }
        }
    }

    private func nachUnten(_ proxy: ScrollViewProxy) -> some View {
        Button {
            stoppSignal += 1
            scrolle(proxy)
        } label: {
            HStack(spacing: Abstand.xs) {
                if neueAntwort { Text("Neue Antwort").font(.footnote.weight(.semibold)) }
                Image(systemName: "arrow.down").font(.footnote.weight(.bold))
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, Abstand.m)
            .frame(minWidth: Abstand.tippflaeche, minHeight: Abstand.tippflaeche)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .padding(Abstand.l)
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.8)))
        .accessibilityLabel(neueAntwort ? "Neue Antwort, nach unten" : "Nach unten")
    }

    // MARK: - Eingabe

    private var eingabe: some View {
        VStack(spacing: Abstand.s) {
            CoachEintragsKarte(modell: modell, gedaechtnisOeffnen: { blatt = .gedaechtnis })
                .padding(.horizontal, Abstand.l)
            if let handlung = modell.handlung { handlungsLeiste(handlung) }
            if modell.pausiert { pauseLeiste }
            if !modell.schnellfragen.isEmpty, !modell.heute.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Abstand.s) {
                        ForEach(modell.schnellfragen, id: \.self) { frage in
                            CoachVorschlagChip(frage: frage, symbol: nil) { modell.senden(frage) }
                        }
                    }
                    .padding(.horizontal, Abstand.l)
                }
            }
            if !modell.pausiert {
            HStack(alignment: .bottom, spacing: Abstand.s) {
                TextField("Frag deinen Coach", text: $modell.entwurf, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($fokus)
                    .submitLabel(.send)
                    .onSubmit { modell.senden() }
                    .padding(.horizontal, Abstand.l)
                    .padding(.vertical, Abstand.m)
                    .frame(minHeight: Abstand.tippflaeche)
                    .lumenKartenFlaeche()
                    .overlay(RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous).stroke(palette.haar, lineWidth: 1))
                    .onChange(of: modell.entwurf) {
                        if modell.entwurf.count > CoachModell.maxZeichen { modell.entwurf = String(modell.entwurf.prefix(CoachModell.maxZeichen)) }
                    }
                Button { sende() } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .symbolEffect(.bounce, value: sendeZaehler)
                        .foregroundStyle(palette.aufAkzent)
                        .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                        .background(palette.akzent, in: .circle)
                }
                .buttonStyle(.gelee)
                .disabled(!kannSenden)
                .opacity(kannSenden ? 1 : 0.35)
                .accessibilityLabel("Senden")
            }
            .padding(.horizontal, Abstand.l)
            }
            if CoachVorschlag.zaehlerSichtbar(anzahl: modell.entwurf.count, maximal: CoachModell.maxZeichen) {
                Text("\(modell.entwurf.count) von \(CoachModell.maxZeichen)")
                    .font(.caption.weight(CoachVorschlag.zaehlerWarnt(anzahl: modell.entwurf.count, maximal: CoachModell.maxZeichen) ? .bold : .regular))
                    .foregroundStyle(palette.text2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, Abstand.l)
            }
            Text("KI-Coach, kein Arzt")
                .font(.caption2).foregroundStyle(palette.text2)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, Abstand.s)
        .padding(.bottom, Abstand.s)
        .lumenLeiste()
    }

    private func sende() {
        guard kannSenden else { return }
        sendeZaehler += 1
        modell.senden()
    }

    private var pauseLeiste: some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: "pause.circle").accessibilityHidden(true)
            Text("Der Coach macht Pause.").font(.subheadline.weight(.semibold))
            Spacer(minLength: Abstand.s)
            Button("Weiter") { modell.setzePause(false) }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: Abstand.tippflaeche)
        }
        .foregroundStyle(palette.text)
        .padding(.horizontal, Abstand.l)
        .glassEffect(.regular, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        .padding(.horizontal, Abstand.l)
        .accessibilityElement(children: .combine)
    }

    private var kannSenden: Bool {
        !modell.denkt && !modell.entwurf.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func handlungsLeiste(_ handlung: CoachHandlung) -> some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: handlung.symbol).accessibilityHidden(true)
            Text(handlung.text).font(.subheadline.weight(.semibold)).lineLimit(2)
            Spacer(minLength: Abstand.s)
            if handlung.zurueck != nil {
                Button("Rückgängig") { modell.rueckgaengig() }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: Abstand.tippflaeche)
            }
        }
        .foregroundStyle(palette.text)
        .padding(.horizontal, Abstand.l)
        .glassEffect(.regular, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        .padding(.horizontal, Abstand.l)
        .accessibilityElement(children: .combine)
    }
}
