import SwiftUI

/// Die Einführung (Entwurf 10.11.2026): Willkommen mit Lumi, Name (ohne Passwort), Einladung, acht Fragen mit Fortschrittsbalken und "Überspringen",
/// Nutzungsfrage, Health und "Dein Plan steht". Es gibt nie ein Passwort beim Start; freiwillig legt man eines später unter Konto fest.
/// Das Profil entsteht erst mit "Los geht's" (`ProfilOnboardingFluss.abschliessenImHintergrund`). Mit einem Fluss `nochmal` läuft sie aus den Präferenzen
/// für ein bestehendes Profil: nur Fragen und Plan, kein neues Profil.
struct OnboardingView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @State private var fluss: ProfilOnboardingFluss
    @State private var arbeitet = false
    @State private var ersetzenFrage = false
    @FocusState private var fokus: Bool

    init(fluss: ProfilOnboardingFluss = ProfilOnboardingFluss()) {
        _fluss = State(initialValue: fluss)
    }

    var body: some View {
        VStack(spacing: Abstand.l) {
            kopf
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.xl) {
                    EinfuehrungKarte(fluss: fluss, fokus: $fokus)
                    if let fehler = fluss.fehler { FehlerKarte(titel: "Das hat nicht geklappt", hilfe: fehler) }
                }
                .padding(.horizontal, Abstand.l)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                .id(fluss.karte)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
            fuss
        }
        .padding(.vertical, Abstand.l)
        .animation(reduceMotion ? nil : Feder.weich, value: fluss.karte)
        .lumenHintergrund()
        .haptik(.auswahl, bei: fluss.karte)
        .confirmationDialog("Deinen Plan ersetzen?", isPresented: $ersetzenFrage, titleVisibility: .visible) {
            Button("Ersetzen", role: .destructive) { nochmalFertig(plan: true) }
        } message: {
            Text("Dein jetziger Plan wird durch diesen ersetzt. Alte Trainings bleiben.")
        }
    }

    // MARK: - Kopf und Fuß

    private var kopf: some View {
        HStack(spacing: Abstand.m) {
            if fluss.index > 0 {
                Button { fokus = false; fluss.zurueck() } label: { kopfSymbol("chevron.left") }
                    .accessibilityLabel("Zurück")
            } else if fluss.nochmal {
                Button { dismiss() } label: { kopfSymbol("xmark") }
                    .accessibilityLabel("Schließen")
            } else {
                Color.clear.frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
            }
            if fluss.karte != .willkommen {
                ProgressView(value: fluss.anteil)
                    .tint(palette.akzent)
                    .accessibilityLabel(fluss.stand)
                    .accessibilityValue("")
            } else {
                Spacer()
            }
            if fluss.karte.istFrage {
                Button("Überspringen") { fluss.ueberspringe() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.akzent)
                    .frame(minHeight: Abstand.tippflaeche)
            } else {
                Text("\(fluss.index + 1) von \(fluss.anzahl)")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(palette.text2)
                    .opacity(fluss.karte == .willkommen ? 0 : 1)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Abstand.l)
        .foregroundStyle(palette.text)
    }

    private func kopfSymbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.body.weight(.semibold))
            .frame(width: Abstand.tippflaeche, height: Abstand.tippflaeche)
            .background(palette.flaeche, in: .circle)
    }

    @ViewBuilder private var fuss: some View {
        VStack(spacing: Abstand.s) {
            switch fluss.karte {
            case .willkommen:
                knopf("Los geht's") { fluss.weiter() }
            case .einladung:
                knopf("Weiter") { fokus = false; fluss.weiter() }.disabled(!fluss.kannWeiter)
                zweitKnopf(fluss.einladungLeer ? "Mich hat niemand eingeladen" : "Ohne Code weiter") { fokus = false; fluss.einladung = ""; fluss.weiter() }
            case .nutzung:
                NutzungFrageKnoepfe { fluss.antworteNutzung($0) }
            case .health:
                knopf("Health erlauben") {
                    arbeitet = true
                    Task {
                        await fluss.healthFragen(leser: umgebung.healthLeser)
                        arbeitet = false
                        fluss.weiter()
                    }
                }
                .disabled(arbeitet)
                zweitKnopf("Später") { fluss.weiter() }.disabled(arbeitet)
            case .plan:
                planKnoepfe
            default:
                knopf("Weiter") { fokus = false; fluss.weiter() }.disabled(!fluss.kannWeiter)
                if fluss.hatVorschlag { zweitKnopf("Weiß ich nicht, nimm den Vorschlag") { fluss.nimmVorschlag() } }
            }
        }
        .padding(.horizontal, Abstand.l)
    }

    @ViewBuilder private var planKnoepfe: some View {
        if fluss.nochmal {
            if fluss.plan != nil {
                knopf("Diesen Plan übernehmen") {
                    if umgebung.daten?.training.plan.tage.isEmpty ?? true { nochmalFertig(plan: true) } else { ersetzenFrage = true }
                }
            }
            zweitKnopf("Nur Antworten speichern") { nochmalFertig(plan: false) }
        } else {
            knopf("Los geht's") { fertig(planUebernehmen: fluss.plan != nil) }.disabled(arbeitet)
            if fluss.plan != nil { zweitKnopf("Anderen Plan wählen") { fertig(planUebernehmen: false) }.disabled(arbeitet) }
        }
    }

    private func knopf(_ titel: LocalizedStringKey, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) { Text(titel).frame(maxWidth: .infinity) }
            .buttonStyle(.lumenHauptknopf)
    }

    private func zweitKnopf(_ titel: LocalizedStringKey, aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) { Text(titel).font(.body.weight(.medium)).frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche) }
            .buttonStyle(.plain)
            .foregroundStyle(palette.akzent)
    }

    // MARK: - Abschluss

    /// Legt das Profil an. Mit Plan bleibt die App bei Heute, ohne geht es zu den Plänen; ein Code öffnet danach "Verbinden".
    private func fertig(planUebernehmen: Bool) {
        arbeitet = true
        let router = umgebung.router
        Task {
            let ok = await fluss.abschliessenImHintergrund(in: umgebung, planUebernehmen: planUebernehmen)
            arbeitet = false
            guard ok else { return }
            if !planUebernehmen, let start = fluss.startRoute { router.oeffne(start) }
            // Zuletzt: `oeffne` leert das Blatt.
            if let code = fluss.einladungZumEinloesen { router.blatt = .freund(daten: code) }
        }
    }

    private func nochmalFertig(plan: Bool) {
        fluss.sichereNochmal(in: umgebung)
        if plan, let vorlage = fluss.plan { umgebung.daten?.training.planSichern(SplitLogik.alsPlan(vorlage)) }
        dismiss()
    }
}
