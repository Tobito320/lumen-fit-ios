// Quelle: Lovea Health/Verlauf/VerlaufView.swift (VerlaufGruppe, VerlaufUebung, VerlaufZielSeite; neu im Lumen-Design)
import SwiftUI

/// Eine Muskelgruppe aus dem Verlauf: Sätze dieser Woche, Woche, Monat, Gesamt, die Teile mit Erholung und die Übungen, die sie belasten.
/// Tipp auf eine Übung öffnet ihren Verlauf.
struct VerlaufGruppeSeite: View {
    let gruppe: MuskelGruppe
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var statistikOffen = false
    @State private var ziel: VerlaufZiel?
    @State private var tipp = 0

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        let laeufe = VerlaufLogik.laeufe(q.sessions)
        let z = VerlaufLogik.gruppen(laeufe, heute: q.heute)[gruppe] ?? VerlaufLogik.Zeitraeume()
        let koerper = q.koerper
        let ohne = VerlaufLogik.ohneSaetze(q.sessions, gym: q.gym, heute: q.heute, jetzt: q.jetzt)
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                if z.woche.saetze == 0, !ohne.isEmpty {
                    VerlaufHinweis(tage: ohne) {
                        tipp += 1
                        ziel = .trainingstage
                    }
                }
                HeroKarte {
                    VStack(alignment: .leading, spacing: 2) {
                        RollZahl(wert: z.woche.saetze, format: .number.precision(.fractionLength(0...1)))
                            .font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                        Text("Sätze diese Woche").font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)
                }
                ListenKarte {
                    zeile("Einheiten diese Woche", "\(z.woche.einheiten)×")
                    Haarlinie()
                    VerlaufKlapp(titel: "Weitere Statistiken", offen: $statistikOffen) {
                        zeile("Dieser Monat", VerlaufLogik.kurz(z.monat))
                        Haarlinie()
                        zeile("Insgesamt", VerlaufLogik.kurz(z.gesamt))
                    }
                    .padding(.horizontal, Abstand.l)
                }
                abschnitt("Teile diese Woche") {
                    ForEach(MuskelTeil.allCases.filter { $0.gruppe == gruppe }, id: \.self) { t in
                        teilZeile(t, saetze: koerper.woche[t] ?? 0, erholung: koerper.erholung[t] ?? 100)
                        Haarlinie()
                    }
                }
                uebungen(laeufe, heute: q.heute)
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenHintergrund()
        .navigationTitle(gruppe.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $ziel) { VerlaufZielAnsicht(ziel: $0) }
        .haptik(.auswahl, bei: tipp)
    }

    private func zeile(_ links: String, _ rechts: String) -> some View {
        HStack(spacing: Abstand.m) {
            Text(links).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.m)
            Text(rechts).foregroundStyle(palette.text2).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.horizontal, Abstand.l)
        .frame(minHeight: Abstand.tippflaeche)
        .accessibilityElement(children: .combine)
    }

    /// Ein Teil mit Sätzen und Erholung; die Stufe steht als Wort dabei, nicht nur als Zeichen.
    private func teilZeile(_ t: MuskelTeil, saetze: Double, erholung e: Int) -> some View {
        let stufe = MuskelLogik.stufe(e)
        let rechts = e >= 90 ? VerlaufLogik.saetzeText(saetze) : "\(VerlaufLogik.saetzeText(saetze)) · \(e) %"
        return HStack(spacing: Abstand.m) {
            Image(systemName: stufe == .erholt ? "circle.fill" : stufe == .fast ? "circle.lefthalf.filled" : "circle")
                .font(.caption).foregroundStyle(palette.text2).accessibilityHidden(true)
            Text(t.name).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.m)
            Text(rechts).foregroundStyle(palette.text2).multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
        .padding(.horizontal, Abstand.l)
        .frame(minHeight: Abstand.tippflaeche)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(t.name), \(rechts), \(KoerperLogik.stufenWort(stufe))")
    }

    private func abschnitt<I: View>(_ titel: String, @ViewBuilder inhalt: () -> I) -> some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            GymAbschnitt(titel: titel)
            ListenKarte { inhalt() }
        }
    }

    @ViewBuilder
    private func uebungen(_ laeufe: [VerlaufLogik.Lauf], heute: String) -> some View {
        let liste = VerlaufLogik.uebungen(gruppe, laeufe, heute: heute)
        abschnitt("Übungen") {
            if liste.isEmpty {
                Text("Noch keine Übung für \(gruppe.name) eingetragen. Sobald du eine trainierst, steht sie hier.")
                    .font(.subheadline).foregroundStyle(palette.text2)
                    .padding(Abstand.l)
            } else {
                ForEach(liste) { u in
                    Button {
                        tipp += 1
                        ziel = .uebung(u.id)
                    } label: {
                        HStack(spacing: Abstand.m) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(u.uebung.name).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                                Text("\(u.monat)× diesen Monat · \(u.gesamt)× insgesamt").font(.footnote).foregroundStyle(palette.text2)
                            }
                            Spacer(minLength: Abstand.s)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                        }
                        .padding(.horizontal, Abstand.l)
                        .padding(.vertical, Abstand.s)
                        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.federnd)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Öffnet die Übung")
                    Haarlinie()
                }
            }
        }
    }
}

/// Eine Übung aus dem Verlauf: bester e1RM, Monat und Gesamt, die Tage mit ihren Sätzen.
struct VerlaufUebungSeite: View {
    let uebungId: String
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        let q = FortschrittQuelle(umgebung: umgebung)
        if let u = UebungsKatalog.nachId[uebungId] {
            let v = VerlaufLogik.uebung(u, VerlaufLogik.laeufe(q.sessions), heute: q.heute)
            ScrollView {
                VStack(alignment: .leading, spacing: Abstand.l) {
                    if let e = v.e1rm {
                        HeroKarte {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                                    RollZahl(wert: e, format: .number.precision(.fractionLength(0...1)).locale(Locale(identifier: "de_DE")))
                                        .font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                                    Text("kg").font(.title3.weight(.semibold))
                                }
                                Text("e1RM, geschätztes Maximum für eine Wiederholung").font(.subheadline)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    ListenKarte {
                        zeile("Diesen Monat", "\(v.monat)×")
                        Haarlinie()
                        zeile("Insgesamt", "\(v.gesamt)×")
                    }
                    VStack(alignment: .leading, spacing: Abstand.s) {
                        GymAbschnitt(titel: "Tage")
                        ListenKarte {
                            ForEach(v.tage) { t in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(Datum.anzeige(t.tag)).font(.subheadline.weight(.semibold)).foregroundStyle(palette.text)
                                    Text(t.text).font(.subheadline).foregroundStyle(palette.text2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(Abstand.l)
                                .accessibilityElement(children: .combine)
                                Haarlinie()
                            }
                        }
                    }
                }
                .padding(.horizontal, Abstand.l)
                .padding(.vertical, Abstand.m)
            }
            .lumenHintergrund()
            .navigationTitle(u.name)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            LeerZustand(stimmung: .denkt, satz: "Diese Übung gibt es nicht mehr im Katalog.").lumenHintergrund()
        }
    }

    private func zeile(_ links: String, _ rechts: String) -> some View {
        HStack {
            Text(links).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.m)
            Text(rechts).foregroundStyle(palette.text2)
        }
        .font(.subheadline)
        .padding(.horizontal, Abstand.l)
        .frame(minHeight: Abstand.tippflaeche)
        .accessibilityElement(children: .combine)
    }
}

/// Das Ziel eines Tipps im Verlauf als Seite.
struct VerlaufZielAnsicht: View {
    let ziel: VerlaufZiel

    var body: some View {
        switch ziel {
        case .gruppe(let g): VerlaufGruppeSeite(gruppe: g)
        case .uebung(let id): VerlaufUebungSeite(uebungId: id)
        case .trainingstage: TrainingVerlaufView()
        }
    }
}
