// Quelle: Lovea Health/Koerper/KoerperBlatt.swift
import SwiftUI

/// Was ein Tipp auf eine Muskelgruppe dem Blatt meldet (für `.sheet(item:)`).
struct KoerperAuswahl: Identifiable, Equatable, Sendable {
    let gruppe: MuskelGruppe
    let teil: MuskelTeil?
    var id: String { gruppe.rawValue + "." + (teil?.rawValue ?? "") }
}

/// Das Blatt einer Muskelgruppe zum Einhängen in ein `.sheet`: liest die Daten selbst aus der Umgebung, so dass jede Stelle (Verlauf, Wochenseite, Felder, Karte)
/// nur `KoerperBlattView(gruppe:)` öffnen muss. Mit `teil` steht der Stand dieses Teils im Kopf und seine Übungen sind aufgeklappt.
struct KoerperBlattView: View {
    let gruppe: MuskelGruppe
    var teil: MuskelTeil?
    @Environment(AppUmgebung.self) private var umgebung

    init(gruppe: MuskelGruppe, teil: MuskelTeil? = nil) {
        self.gruppe = gruppe
        self.teil = teil
    }

    var body: some View {
        ScrollView {
            KoerperBlatt(daten: FortschrittQuelle(umgebung: umgebung).koerper, gruppe: gruppe, teil: teil)
                .padding(.horizontal, Abstand.l)
                .padding(.top, Abstand.xl)
                .padding(.bottom, Abstand.xxl)
        }
        .lumenHintergrund()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Inhalt des Blatts zu einer Muskelgruppe: Mini-Figur, Sätze gegen Ziel, Erholung in Prozent mit dem letzten Training, Teile mit Punkten, Übungen mit
/// Verlauf und "Nächstes Mal". Eine Übung klappt animiert auf.
struct KoerperBlatt: View {
    let daten: KoerperDaten
    let gruppe: MuskelGruppe
    var teil: MuskelTeil?
    @State private var offen: Set<String>
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var reduceMotion

    /// `offen`: welche Übungen aufgeklappt starten. Standard: die, deren Haupt-Teil angetippt wurde.
    init(daten: KoerperDaten, gruppe: MuskelGruppe, teil: MuskelTeil? = nil, offen: Set<String>? = nil) {
        self.daten = daten
        self.gruppe = gruppe
        self.teil = teil
        let uebungen = daten.gruppen[gruppe]?.uebungen ?? []
        _offen = State(initialValue: offen ?? Set(uebungen.filter { $0.teil == teil }.map(\.id)))
    }

    private var ziel: Int? { daten.ziele.saetze[gruppe] }
    private var teile: [MuskelTeil] { MuskelTeil.allCases.filter { $0.gruppe == gruppe } }
    private var uebungen: [KoerperLogik.UebungsZeile] { daten.gruppen[gruppe]?.uebungen ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            kopf
            abschnitt(String(localized: "Teile diese Woche"))
            ForEach(teile, id: \.self) { teilZeile($0) }
            abschnitt(String(localized: "Übungen"))
            if uebungen.isEmpty {
                Text("Noch nichts für \(gruppe.name) gemacht. Plane im Tab Gym eine Übung dafür ein.")
                    .font(.subheadline)
                    .foregroundStyle(palette.text2)
                    .padding(.vertical, Abstand.m)
            }
            ForEach(uebungen) { uebungZeile($0) }
        }
        .foregroundStyle(palette.text)
        .frame(maxWidth: .infinity, alignment: .leading)
        .haptik(.auswahl, bei: offen)
    }

    // MARK: Kopf

    /// Vorne und hinten nebeneinander, aber nur die Seiten, auf denen die Gruppe liegt.
    private var seiten: [SilhouetteSeite] {
        SilhouetteSeite.allCases.filter { seite in SilhouetteBild.flaechen(seite).contains { $0.gruppe == gruppe } }
    }

    private var kopf: some View {
        VStack(alignment: .leading, spacing: Abstand.l) {
            HStack(spacing: Abstand.m) {
                HStack(spacing: 2) {
                    ForEach(seiten, id: \.self) { SilhouetteAnsicht(seite: $0, daten: daten, fokus: gruppe) }
                }
                .frame(height: 132)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(gruppe.name).font(.title.weight(.bold)).fontDesign(.rounded).accessibilityAddTraits(.isHeader)
                    if let teil { Text(teil.name).font(.headline).foregroundStyle(palette.text2) }
                    Text(unterzeile).font(.footnote).foregroundStyle(palette.text2)
                    HStack(alignment: .firstTextBaseline, spacing: Abstand.xs) {
                        RollZahl(wert: daten.saetze(gruppe), format: .number.precision(.fractionLength(0...1))).font(.largeTitle.weight(.bold)).fontDesign(.rounded)
                        Text(ziel.map { String(localized: "von \($0) Sätzen") } ?? String(localized: "Sätze diese Woche")).font(.subheadline).foregroundStyle(palette.text2)
                    }
                    .padding(.top, Abstand.s)
                }
            }
            erholung
        }
    }

    /// Erholung in Prozent und das letzte Training, das sie treibt: für den angetippten Teil, sonst für den schlechtesten der Gruppe (derselbe, der die Karte
    /// färbt). Das Wort trägt die Stufe, das Muster davor nur die Zuordnung zur Karte.
    private var erholung: some View {
        let stand = daten.stand(gruppe, teil: teil)
        return VStack(alignment: .leading, spacing: Abstand.xs) {
            HStack(spacing: Abstand.s) {
                SilhouetteProbe(stufe: SilhouetteStufe(stand?.stufe)).frame(width: 14, height: 14).accessibilityHidden(true)
                Text(erholungTitel(stand)).font(.headline)
            }
            if let stand, teil == nil {
                Text(KoerperLogik.teilName(stand.teil)).font(.subheadline).foregroundStyle(palette.text2)
            }
            if let letztes = stand?.letztes {
                Text("Letztes Training: \(letztes.text)").font(.subheadline).foregroundStyle(palette.text2)
            } else if stand == nil {
                Text("Im Tab Gym hakst du Sätze ab, dann zeigt sich hier die Erholung.")
                    .font(.subheadline)
                    .foregroundStyle(palette.text2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func erholungTitel(_ stand: KoerperStand?) -> String {
        guard let stand else { return String(localized: "Kein Training erfasst") }
        return "\(KoerperLogik.stufenWort(stand.stufe)) · \(stand.prozent) %"
    }

    private var unterzeile: String {
        let g = daten.gruppen[gruppe]
        var teile: [String] = []
        if let rang = daten.ziele.prio.firstIndex(of: gruppe) { teile.append(String(localized: "Priorität \(rang + 1)")) }
        teile.append(String(localized: "\(g?.monat ?? 0)× diesen Monat"))
        teile.append(String(localized: "\(g?.gesamt ?? 0)× insgesamt"))
        return teile.joined(separator: " · ")
    }

    private func abschnitt(_ titel: String) -> some View {
        Text(titel)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(palette.text2)
            .padding(.top, Abstand.xl)
            .padding(.bottom, Abstand.xs)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Teile

    private func teilZeile(_ t: MuskelTeil) -> some View {
        let satz = daten.woche[t] ?? 0
        let e = daten.prozent(t)
        return HStack(spacing: Abstand.m) {
            Text(t.name).font(.body).fontWeight(t == teil ? .bold : .regular)
            Spacer(minLength: 0)
            SatzPunkte(saetze: satz)
            Text(e >= 90 ? "\(KoerperLogik.komma(satz)) Sätze" : "\(e) %")
                .font(.footnote)
                .foregroundStyle(palette.text2)
                .monospacedDigit()
                .frame(width: 72, alignment: .trailing)
        }
        .frame(minHeight: Abstand.tippflaeche)
        .overlay(alignment: .bottom) { Haarlinie() }
        .accessibilityElement(children: .combine)
    }

    // MARK: Übungen

    private func uebungZeile(_ z: KoerperLogik.UebungsZeile) -> some View {
        let auf = offen.contains(z.id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : Feder.weich) { if offen.remove(z.id) == nil { offen.insert(z.id) } }
            } label: {
                HStack(spacing: Abstand.m) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(z.name).font(.body.weight(.semibold))
                        Text(meta(z)).font(.caption).foregroundStyle(palette.text2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.text2)
                        .rotationEffect(.degrees(auf ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: Abstand.tippflaeche)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(auf ? "aufgeklappt" : "zugeklappt")
            if auf { verlauf(z) }
        }
        .overlay(alignment: .bottom) { Haarlinie() }
    }

    private func meta(_ z: KoerperLogik.UebungsZeile) -> String {
        let zuletzt = z.verlauf.first.map { String(localized: "zuletzt \($0.tag)") } ?? String(localized: "noch nie")
        return String(localized: "\(KoerperLogik.teilName(z.teil)) · \(zuletzt) · \(z.monat)× diesen Monat")
    }

    private func verlauf(_ z: KoerperLogik.UebungsZeile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(z.verlauf.indices, id: \.self) { i in
                let zeile = z.verlauf[i]
                HStack(alignment: .firstTextBaseline, spacing: Abstand.m) {
                    Text(zeile.tag).font(.footnote.weight(.semibold))
                    Spacer(minLength: 0)
                    Text(zeile.saetze).font(.footnote).foregroundStyle(palette.text2).monospacedDigit().multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 5)
            }
            if let v = z.vorschlag { vorschlag(v) }
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
    }

    private func vorschlag(_ v: KoerperLogik.Vorschlag) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Nächstes Mal").font(.caption.weight(.semibold)).foregroundStyle(palette.text2)
            Text(KoerperLogik.vorschlagText(v)).font(.subheadline)
        }
        .padding(Abstand.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.flaeche, in: .rect(cornerRadius: Rundung.feld, style: .continuous))
        .padding(.top, Abstand.s)
        .padding(.bottom, Abstand.m)
        .accessibilityElement(children: .combine)
    }
}

/// Ein Punkt pro Satz, ein halber für einen halben Satz (Mitarbeit). 4 bis 8 Punkte, darüber ein Plus.
private struct SatzPunkte: View {
    let saetze: Double
    @Environment(\.palette) private var palette

    var body: some View {
        let n = max(4, min(8, Int(saetze.rounded(.up))))
        HStack(spacing: 3) {
            ForEach(0..<n, id: \.self) { i in punkt(min(1, max(0, saetze - Double(i)))) }
            if saetze > 8 { Text("+").font(.caption2).foregroundStyle(palette.text2) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(KoerperLogik.komma(saetze)) Sätze")
    }

    private func punkt(_ anteil: Double) -> some View {
        Circle()
            .fill(anteil >= 1 ? palette.text : palette.haar)
            .overlay(alignment: .leading) { if anteil > 0 && anteil < 1 { Rectangle().fill(palette.text).frame(width: 3.5) } }
            .clipShape(Circle())
            .frame(width: 7, height: 7)
    }
}
