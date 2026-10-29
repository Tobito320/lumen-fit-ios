import SwiftUI

/// Ziele aus deinen Körperdaten (Idee 49): Kalorien und Protein aus Größe, Alter, Geschlecht, Gewicht und Ziel, mit Erklärung.
/// Alles ist überschreibbar, erst "Übernehmen" speichert. Fehlt eine Angabe, sagt die Karte welche, und rechnet nichts mit Standardwerten.
struct EssenZielKarte: View {
    let daten: DatenSatz
    let jetzt: Date
    let uebernommen: @MainActor () -> Void

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var aktivitaet: Int
    @State private var kcalEigen: Int?
    @State private var proteinEigen: Int?

    init(daten: DatenSatz, jetzt: Date, uebernommen: @escaping @MainActor () -> Void) {
        self.daten = daten
        self.jetzt = jetzt
        self.uebernommen = uebernommen
        _aktivitaet = State(initialValue: daten.essen.ernaehrungsZiele.aktivitaet)
    }

    private var essen: EssenStore { daten.essen }
    private var art: Zielart { daten.ziele.ziele.art }

    private var vorschlag: ZielVorschlag {
        var aktuell = essen.ernaehrungsZiele
        aktuell.aktivitaet = aktivitaet
        return ZielKarteLogik.vorschlag(koerper: daten.ziele.koerper, art: art, kg: essen.gewichtKg, aktuell: aktuell, heute: jetzt)
    }

    private var artText: String {
        switch art {
        case .aufbauen: "Aufbauen"
        case .halten: "Halten"
        case .abnehmen: "Abnehmen"
        }
    }

    var body: some View {
        let v = vorschlag
        let aktuell = essen.ernaehrungsZiele
        VStack(alignment: .leading, spacing: Abstand.m) {
            Text("Ziele aus deinen Körperdaten").font(.headline).foregroundStyle(palette.text)
            Text("Jetzt: \(aktuell.kcal) kcal und \(aktuell.protein) g Protein am Tag" + (aktuell.eingerichtet ? "" : " (geschätzt)"))
                .font(.subheadline).foregroundStyle(palette.text2)
            if let ziele = v.ziele {
                vorschlagsBereich(v, ziele)
            } else {
                fehlt(v)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Abstand.l)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
        .onChange(of: aktivitaet) { _, _ in kcalEigen = nil; proteinEigen = nil }
    }

    private func fehlt(_ v: ZielVorschlag) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Label(v.erklaerung, systemImage: "info.circle").font(.subheadline).foregroundStyle(palette.text)
            if v.fehlt.contains("Gewicht") {
                Button("Gewicht eintragen") { umgebung.router.oeffne(.gewichtEintragen) }
                    .buttonStyle(.bordered).frame(minHeight: Abstand.tippflaeche)
            }
            if v.fehlt.contains(where: { $0 != "Gewicht" }) {
                Button("Körperdaten eintragen") { umgebung.router.oeffne(.profil(.ziele)) }
                    .buttonStyle(.bordered).frame(minHeight: Abstand.tippflaeche)
            }
        }
    }

    private func vorschlagsBereich(_ v: ZielVorschlag, _ ziele: ErnaehrungsZiele) -> some View {
        let kcal = kcalEigen ?? ziele.kcal
        let protein = proteinEigen ?? ziele.protein
        return VStack(alignment: .leading, spacing: Abstand.m) {
            Pille(text: "Dein Ziel: \(artText)", symbolName: "target")
            Menu {
                Picker("Aktivität", selection: $aktivitaet) {
                    ForEach(ErnaehrungLogik.aktivitaeten.indices, id: \.self) { Text(ErnaehrungLogik.aktivitaeten[$0].name).tag($0) }
                }
            } label: {
                HStack {
                    Text("Aktivität").foregroundStyle(palette.text)
                    Spacer(minLength: Abstand.s)
                    Text(ErnaehrungLogik.aktivitaeten[min(max(aktivitaet, 0), ErnaehrungLogik.aktivitaeten.count - 1)].name).foregroundStyle(palette.text2)
                    Image(systemName: "chevron.up.chevron.down").foregroundStyle(palette.text2).accessibilityHidden(true)
                }
                .frame(minHeight: Abstand.tippflaeche)
                .contentShape(.rect)
            }
            .accessibilityLabel("Aktivität wählen")
            Stepper(value: Binding(get: { kcal }, set: { kcalEigen = $0 }), in: 1_200...6_000, step: 50) {
                HStack { Text("Kalorien"); Spacer(minLength: Abstand.s); Text("\(kcal) kcal").monospacedDigit().foregroundStyle(palette.text2) }
            }
            Stepper(value: Binding(get: { protein }, set: { proteinEigen = $0 }), in: 30...400, step: 5) {
                HStack { Text("Protein"); Spacer(minLength: Abstand.s); Text("\(protein) g").monospacedDigit().foregroundStyle(palette.text2) }
            }
            DisclosureGroup("So rechne ich") {
                Text(v.erklaerung).font(.subheadline).foregroundStyle(palette.text2).frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                uebernehmen(ziele, kcal: kcal, protein: protein)
            } label: {
                Text("Übernehmen").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
            }
            .buttonStyle(.lumenHauptknopf)
            .accessibilityHint("Speichert \(kcal) Kilokalorien und \(protein) Gramm Protein als deine Ziele")
        }
    }

    private func uebernehmen(_ ziele: ErnaehrungsZiele, kcal: Int, protein: Int) {
        let kg = essen.gewichtKg ?? 0
        let neu = ZielKarteLogik.angepasst(ziele, kcal: kcal, protein: protein, kg: kg)
        essen.zieleSichern(neu)
        daten.ziele.ziele.kalorien = neu.kcal
        daten.ziele.ziele.proteinGramm = neu.protein
        kcalEigen = nil
        proteinEigen = nil
        uebernommen()
    }
}
