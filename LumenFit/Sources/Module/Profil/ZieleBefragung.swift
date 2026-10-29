// Quelle: Lovea Health/Koerper/ZieleBefragung.swift
import SwiftUI

/// Rechnet aus den Antworten der Befragung die Reihenfolge und die Wochensätze. Regeln wie `zieleRechnen()`
/// in `design/erholung/erholung.html` (Lovea).
enum ZieleLogik {
    struct Wahl: Identifiable, Sendable {
        let id: String
        let name: String
        let hinweis: String
        let gruppen: [MuskelGruppe]
    }

    static let optionen: [Wahl] = [
        Wahl(id: "po", name: "Po und Beine formen", hinweis: "Po, Beinbeuger, Quadrizeps", gruppen: [.beine, .bauch]),
        Wahl(id: "stark", name: "Stärker werden", hinweis: "Mehr Gewicht bei den Grundübungen", gruppen: [.beine, .ruecken, .brust]),
        Wahl(id: "straff", name: "Straffen", hinweis: "Ganzer Körper, Muskeln halten", gruppen: [.beine, .ruecken, .schulter]),
        Wahl(id: "haltung", name: "Rücken und Haltung", hinweis: "Oberer Rücken, Schulter hinten, Rumpf", gruppen: [.ruecken, .schulter, .bauch]),
    ]

    static let auffuellen: [MuskelGruppe] = [.beine, .ruecken, .schulter, .bauch, .brust]

    /// `prio`: bis zu 5 Gruppen, wichtigste zuerst. `saetze`: alle Gruppen. Die ersten 2 der Prio 12, 14 oder 16
    /// (2, 3, 4+ Tage), der Rest der Prio 10, alle anderen 6.
    static func rechnen(ziele: Set<String>, tageProWoche: Int) -> (prio: [MuskelGruppe], saetze: [MuskelGruppe: Int]) {
        var prio: [MuskelGruppe] = []
        for g in optionen.filter({ ziele.contains($0.id) }).flatMap(\.gruppen) where !prio.contains(g) { prio.append(g) }
        for g in auffuellen where prio.count < 5 && !prio.contains(g) { prio.append(g) }
        prio = Array(prio.prefix(5))
        let hoch = tageProWoche >= 4 ? 16 : tageProWoche == 3 ? 14 : 12
        var saetze: [MuskelGruppe: Int] = [:]
        for g in MuskelGruppe.allCases {
            saetze[g] = prio.firstIndex(of: g).map { $0 < 2 ? hoch : 10 } ?? 6
        }
        return (prio, saetze)
    }

    /// Rang 1 bis 5 in `ziel.prio.<gruppe>`, 0 für Gruppen ohne Rang (überschreibt eine frühere Befragung).
    /// Gespeichert wie bei Lovea als Op `einstellung.setzen`; das Modul fortschritt liest `ziel.prio.*` und `ziel.saetze.*` (Annahme in SPEC 15).
    @MainActor
    static func speichern(prio: [MuskelGruppe], saetze: [MuskelGruppe: Int], in raum: LokalerRaum) {
        for g in MuskelGruppe.allCases {
            setze("ziel.prio.\(g.rawValue)", (prio.firstIndex(of: g) ?? -1) + 1, in: raum)
            setze("ziel.saetze.\(g.rawValue)", saetze[g] ?? 6, in: raum)
        }
    }

    @MainActor
    private static func setze(_ schluessel: String, _ wert: Int, in raum: LokalerRaum) {
        raum.senden(ProfilEinstellungD.art, ProfilEinstellungD(schluessel: schluessel, wert: .number(Double(wert))))
    }

    /// Das zuletzt gespeicherte Ergebnis (`ziel.prio.*`), für die Anzeige. nil ohne Befragung.
    @MainActor
    static func gespeichert(in raum: LokalerRaum) -> [MuskelGruppe]? {
        var rang: [MuskelGruppe: Int] = [:]
        for op in raum.ops(arten: [ProfilEinstellungD.art]) {
            guard let d = op.daten(ProfilEinstellungD.self), d.schluessel.hasPrefix("ziel.prio."),
                  let g = MuskelGruppe(rawValue: String(d.schluessel.dropFirst("ziel.prio.".count))), case .number(let n) = d.wert else { continue }
            rang[g] = Int(n)
        }
        let geordnet = rang.filter { $0.value > 0 }.sorted { ($0.value, $0.key.rawValue) < ($1.value, $1.key.rawValue) }.map(\.key)
        return geordnet.isEmpty ? nil : geordnet
    }
}

/// Rumpf der Op `einstellung.setzen` (wie Lovea: `schluessel`, `wert`).
struct ProfilEinstellungD: Codable, Sendable {
    static let art = "einstellung.setzen"
    var schluessel: String
    var wert: JSONValue
}

/// Blatt mit 3 Schritten: Ziele, Tage pro Woche, Reihenfolge. Rechnet daraus die Satzziele je Muskel.
struct ZieleBefragungView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var schritt = 0
    @State private var ziele: Set<String> = []
    @State private var tage: Int?
    @State private var gespeichert = 0

    private var ergebnis: (prio: [MuskelGruppe], saetze: [MuskelGruppe: Int]) {
        ZieleLogik.rechnen(ziele: ziele, tageProWoche: tage ?? 3)
    }
    private var kannWeiter: Bool { schritt == 0 ? !ziele.isEmpty : schritt == 1 ? tage != nil : true }

    var body: some View {
        VStack(alignment: .leading, spacing: Abstand.s) {
            Text("Frage \(schritt + 1) von 3").font(.subheadline.weight(.semibold)).foregroundStyle(palette.text2)
            kopf
            ScrollView { inhalt }
            weiterKnopf
        }
        .padding(.horizontal, Abstand.l)
        .padding(.vertical, Abstand.xl)
        .animation(reduceMotion ? nil : Feder.schnell, value: schritt)
        .lumenHintergrund()
        .haptik(.erfolg, bei: gespeichert)
    }

    @ViewBuilder private var kopf: some View {
        switch schritt {
        case 0: titel("Was willst du im Gym erreichen?", "Mehrere gehen.")
        case 1: titel("Wie oft trainierst du pro Woche?", "Danach richtet sich, wie viele Sätze pro Muskel realistisch sind.")
        default: titel("Das ist deine Reihenfolge", "Daraus rechnet die App deine Satzziele pro Woche. Ändern geht jederzeit.")
        }
    }

    private func titel(_ text: String, _ untertitel: String) -> some View {
        VStack(alignment: .leading, spacing: Abstand.xs) {
            Text(text).font(.title2.bold()).foregroundStyle(palette.text)
            Text(untertitel).font(.subheadline).foregroundStyle(palette.text2)
        }
        .padding(.bottom, Abstand.s)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var inhalt: some View {
        switch schritt {
        case 0:
            ListenKarte {
                ForEach(ZieleLogik.optionen) { o in
                    ProfilAuswahlZeile(titel: o.name, hinweis: o.hinweis, an: ziele.contains(o.id)) {
                        if ziele.contains(o.id) { ziele.remove(o.id) } else { ziele.insert(o.id) }
                    }
                    if o.id != ZieleLogik.optionen.last?.id { Haarlinie() }
                }
            }
        case 1:
            ListenKarte {
                ForEach(2...5, id: \.self) { n in
                    ProfilAuswahlZeile(titel: "\(n)× pro Woche", hinweis: nil, an: tage == n) { tage = n }
                    if n < 5 { Haarlinie() }
                }
            }
        default:
            ListenKarte {
                ForEach(Array(ergebnis.prio.enumerated()), id: \.element) { i, g in
                    HStack {
                        Text("\(i + 1). \(g.name)").font(.body.weight(.semibold)).foregroundStyle(palette.text)
                        Spacer()
                        Text("\(ergebnis.saetze[g] ?? 0) Sätze").font(.body.monospacedDigit()).foregroundStyle(palette.text2)
                    }
                    .padding(Abstand.l)
                    .frame(minHeight: Abstand.tippflaeche)
                    .accessibilityElement(children: .combine)
                    if i < ergebnis.prio.count - 1 { Haarlinie() }
                }
            }
        }
    }

    private var weiterKnopf: some View {
        Button {
            if schritt < 2 {
                schritt += 1
            } else if let raum = umgebung.daten?.raum {
                ZieleLogik.speichern(prio: ergebnis.prio, saetze: ergebnis.saetze, in: raum)
                gespeichert += 1
                dismiss()
            }
        } label: {
            Text(schritt < 2 ? "Weiter" : "Ziele speichern").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
        }
        .buttonStyle(.borderedProminent)
        .foregroundStyle(palette.aufAkzent)
        .disabled(!kannWeiter)
    }
}
