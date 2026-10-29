import SwiftUI

/// Der Chat von heute. Die Tage davor stehen im Verlauf (`CoachVerlaufView`), das Gedächtnis und die Einstellungen im Menü.
struct CoachChatView: View {
    @Bindable var modell: CoachModell
    var frage: String?

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var reduceMotion
    @State private var blatt: CoachBlatt?
    @FocusState private var fokus: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Abstand.l) {
                    if modell.morgenCheckSichtbar { CoachMorgenCheckKarte(modell: modell) }
                    if modell.heute.isEmpty, !modell.denkt { willkommen }
                    ForEach(Array(modell.heute.enumerated()), id: \.element.id) { index, nachricht in
                        if CoachText.trennerNoetig(vorher: index > 0 ? modell.heute[index - 1].zeit : nil, jetzt: nachricht.zeit, kalender: Datum.kalender) {
                            trenner(nachricht.zeit)
                        }
                        zeile(nachricht).id(nachricht.id)
                    }
                    if modell.denkt, let seit = modell.denkBeginn { CoachDenkAnzeige(seit: seit).id("denkt") }
                    Color.clear.frame(height: 1).id("ende")
                }
                .padding(.horizontal, Abstand.l)
                .padding(.top, Abstand.m)
                .padding(.bottom, Abstand.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(.bottom)
            .onChange(of: modell.heute.count) { scrolle(proxy) }
            .onChange(of: modell.denkt) { scrolle(proxy) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { eingabe }
        .navigationTitle(modell.einstellungen?.anzeigeName ?? CoachLokal.standardName)
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { menue }
            ToolbarItem(placement: .topBarTrailing) { AvatarKapsel() }
        }
        .sheet(item: $blatt) { CoachBlattAnsicht(blatt: $0, modell: modell) }
        .task(id: frage) {
            modell.pruefeMorgenCheck()
            modell.beiVordergrund()
            if let frage { modell.senden(frage) }
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
    }

    // MARK: - Teile

    private var menue: some View {
        Menu {
            Button("Verlauf", systemImage: "clock.arrow.circlepath") { blatt = .verlauf }
            Button("Gedächtnis", systemImage: "brain.head.profile") { blatt = .gedaechtnis }
            Button("Gemerkte Antworten", systemImage: "bookmark") { blatt = .merkliste }
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
    private func zeile(_ nachricht: CoachNachricht) -> some View {
        switch nachricht.rolle {
        case .nutzer:
            CoachNutzerBlase(text: nachricht.text)
        case .coach:
            VStack(alignment: .leading, spacing: Abstand.s) {
                if nachricht.text == CoachPersona.fehlerText {
                    CoachFehlerZeile(text: nachricht.text)
                } else {
                    CoachAntwortText(text: nachricht.text)
                }
                CoachChipLeiste(nachricht: nachricht, modell: modell)
                if nachricht.text != CoachPersona.fehlerText { CoachAktionsZeile(nachricht: nachricht, modell: modell) }
            }
        }
    }

    private func scrolle(_ proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo("ende", anchor: .bottom)
        } else {
            withAnimation(Feder.weich) { proxy.scrollTo("ende", anchor: .bottom) }
        }
    }

    // MARK: - Eingabe

    private var eingabe: some View {
        VStack(spacing: Abstand.s) {
            if let handlung = modell.handlung { handlungsLeiste(handlung) }
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
            HStack(alignment: .bottom, spacing: Abstand.s) {
                TextField("Frag deinen Coach", text: $modell.entwurf, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($fokus)
                    .submitLabel(.send)
                    .onSubmit { modell.senden() }
                    .padding(.horizontal, Abstand.l)
                    .padding(.vertical, Abstand.m)
                    .frame(minHeight: Abstand.tippflaeche)
                    .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Rundung.karte, style: .continuous).stroke(palette.haar, lineWidth: 1))
                    .onChange(of: modell.entwurf) {
                        if modell.entwurf.count > CoachModell.maxZeichen { modell.entwurf = String(modell.entwurf.prefix(CoachModell.maxZeichen)) }
                    }
                Button { modell.senden() } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .foregroundStyle(palette.aufAkzent)
                        .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
                        .background(palette.akzent, in: .circle)
                }
                .buttonStyle(.plain)
                .disabled(!kannSenden)
                .opacity(kannSenden ? 1 : 0.35)
                .accessibilityLabel("Senden")
            }
            .padding(.horizontal, Abstand.l)
            if CoachVorschlag.zaehlerSichtbar(anzahl: modell.entwurf.count, maximal: CoachModell.maxZeichen) {
                Text("\(modell.entwurf.count) von \(CoachModell.maxZeichen)")
                    .font(.caption.weight(CoachVorschlag.zaehlerWarnt(anzahl: modell.entwurf.count, maximal: CoachModell.maxZeichen) ? .bold : .regular))
                    .foregroundStyle(palette.text2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, Abstand.l)
            }
        }
        .padding(.top, Abstand.s)
        .padding(.bottom, Abstand.s)
        .lumenLeiste()
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
