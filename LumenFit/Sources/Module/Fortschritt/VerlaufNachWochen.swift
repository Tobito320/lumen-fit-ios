import SwiftUI

extension FortschrittQuelle {
    /// Der Name des Plantags einer Einheit; nil, wenn sie keinen hat (dann heißt die Karte "Training").
    func einheitTitel(_ s: GymSession) -> String? {
        guard let name = daten?.training.tag(id: s.tag)?.name, !name.isEmpty else { return nil }
        return name
    }

    /// Das letzte beendete Training mit allen Zahlen; nil ohne Einheit.
    var letztesTraining: EinheitDaten? {
        guard let s = FortschrittLogik.nachWochen(sessions, heute: heute, jetzt: jetzt).first?.sessions.first else { return nil }
        return FortschrittLogik.einheit(s, titel: einheitTitel(s), frueher: sessions)
    }
}

/// Alle beendeten Einheiten wie in Hevy: je Woche eine Gruppe, neueste zuerst. Die neueste Woche und die davor stehen offen mit ihren Karten, ältere Wochen
/// sind Zeilen "KW 41" und öffnen erst beim Tipp (dann erst rechnet die Karte). Ein Tipp auf eine Karte öffnet die Einheit zum Nachlesen.
struct VerlaufNachWochen: View {
    let sessions: [GymSession]
    let heute: String
    var jetzt: Date?
    @State private var offen: Set<String> = []
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        let gruppen = FortschrittLogik.nachWochen(sessions, heute: heute, jetzt: jetzt)
        let q = FortschrittQuelle(umgebung: umgebung)
        VStack(alignment: .leading, spacing: Abstand.l) {
            ForEach(Array(gruppen.enumerated()), id: \.offset) { i, g in
                if i < 2 {
                    VStack(alignment: .leading, spacing: Abstand.s) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(g.titel).font(.title3.weight(.bold)).accessibilityAddTraits(.isHeader)
                            Spacer(minLength: Abstand.s)
                            Text(Self.einheitenText(g.sessions.count)).font(.footnote).foregroundStyle(palette.text2)
                        }
                        karten(g.sessions, q: q)
                    }
                } else {
                    aeltere(g, q: q)
                }
            }
        }
    }

    private func aeltere(_ g: (titel: String, sessions: [GymSession]), q: FortschrittQuelle) -> some View {
        let schluessel = g.sessions.first?.id ?? g.titel
        let ist = offen.contains(schluessel)
        let montag = Datum.montagDerWoche(Datum.text(g.sessions.first?.start ?? Date()))
        return VStack(alignment: .leading, spacing: Abstand.s) {
            Button {
                if ist { offen.remove(schluessel) } else { offen.insert(schluessel) }
            } label: {
                HStack(spacing: Abstand.s) {
                    Text(g.titel).font(.headline).foregroundStyle(palette.text)
                    Spacer(minLength: Abstand.s)
                    Text("\(Self.einheitenText(g.sessions.count)) · \(FortschrittLogik.wochenSpanne(montag))")
                        .font(.footnote).foregroundStyle(palette.text2).lineLimit(1).minimumScaleFactor(0.8)
                    Image(systemName: ist ? "chevron.up" : "chevron.down").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                }
                .padding(.horizontal, Abstand.l)
                .frame(minHeight: 56)
                .background(palette.flaeche, in: .rect(cornerRadius: Rundung.karte, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(ist ? "geöffnet" : "geschlossen")
            .accessibilityHint(ist ? "Schließt die Woche" : "Zeigt die Einheiten der Woche")
            if ist { karten(g.sessions, q: q) }
        }
    }

    private func karten(_ liste: [GymSession], q: FortschrittQuelle) -> some View {
        ForEach(liste) { s in
            EinheitKarte(daten: FortschrittLogik.einheit(s, titel: q.einheitTitel(s), frueher: sessions))
        }
    }

    static func einheitenText(_ n: Int) -> String { n == 1 ? "1 Einheit" : "\(n) Einheiten" }
}

/// Die Karte einer Einheit: Name und Tag, Dauer, Volumen, Sätze, Rekorde, darunter jede Übung mit Satzzahl und schwerstem Satz.
private struct EinheitKarte: View {
    let daten: EinheitDaten
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationLink {
            EinheitNachlesenView(sessionId: daten.id)
        } label: {
            VStack(alignment: .leading, spacing: Abstand.m) {
                HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
                    Text(daten.titel).font(.headline).foregroundStyle(palette.text)
                    Spacer(minLength: Abstand.s)
                    Text(FortschrittLogik.kurzDatum(daten.start)).font(.footnote).foregroundStyle(palette.text2)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
                }
                HStack(alignment: .top, spacing: Abstand.m) {
                    zahl("Dauer", daten.dauer.map { TrainingLogik.dauerText($0) } ?? "–")
                    zahl("Volumen", FortschrittLogik.volumenText(daten.volumen))
                    zahl("Sätze", "\(daten.saetze)")
                    if daten.rekorde > 0 { zahl("Rekorde", "\(daten.rekorde)", symbol: "trophy.fill") }
                }
                if !daten.zeilen.isEmpty {
                    Haarlinie()
                    VStack(alignment: .leading, spacing: Abstand.s) {
                        ForEach(daten.zeilen) { z in zeile(z) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Abstand.l)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .lumenKartenFlaeche()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sprechtext)
        .accessibilityHint("Öffnet die Einheit")
    }

    private func zahl(_ titel: String, _ wert: String, symbol: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titel).font(.footnote).foregroundStyle(palette.text2)
            HStack(spacing: Abstand.xs) {
                if let symbol { Image(systemName: symbol).foregroundStyle(palette.akzent).accessibilityHidden(true) }
                Text(wert).font(.subheadline.weight(.bold)).monospacedDigit().foregroundStyle(palette.text)
            }
        }
    }

    private func zeile(_ z: EinheitUebungZeile) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
            Text("\(z.saetze) × \(z.name)").font(.subheadline).foregroundStyle(palette.text).multilineTextAlignment(.leading)
            Spacer(minLength: Abstand.s)
            if z.rekord { Image(systemName: "trophy.fill").font(.footnote).foregroundStyle(palette.akzent).accessibilityHidden(true) }
            if let bester = z.bester {
                Text(WorkoutLogik.satzText(bester)).font(.subheadline).foregroundStyle(palette.text2).monospacedDigit()
            }
        }
    }

    private var sprechtext: String {
        let dauer = daten.dauer.map { ", Dauer \(TrainingLogik.dauerText($0))" } ?? ""
        let rekorde = daten.rekorde > 0 ? ", \(daten.rekorde) \(daten.rekorde == 1 ? "Rekord" : "Rekorde")" : ""
        return "\(daten.titel), \(FortschrittLogik.kurzDatum(daten.start))\(dauer), Volumen \(FortschrittLogik.volumenText(daten.volumen)), \(daten.saetze) Sätze\(rekorde)"
    }
}
