// Quelle: Lovea Zyklus/ZyklusHeuteView.swift
import SwiftUI

/// Was Schlaf und Essen der letzten Wochen über die Periode sagen (`ZyklusAlltag`): liest Schlaf aus Health und Kalorien aus dem Essen-Tagebuch, bis gestern.
enum ZyklusAlltagQuelle {
    @MainActor
    static func hinweis(umgebung: AppUmgebung, heute: String) async -> ZyklusAlltag.Hinweis? {
        guard let daten = umgebung.daten else { return nil }
        let tage = (1...60).map { Datum.addTage(heute, -$0) }
        let nachts = await umgebung.healthLeser.schlafNaechte(von: Datum.addTage(heute, -60), bis: Datum.addTage(heute, -1))
        let schlaf = Dictionary(nachts.map { ($0.tag, $0.schlafMinuten) }, uniquingKeysWith: { _, neu in neu })
        let minuten = tage.compactMap { schlaf[$0] }.filter { $0 > 0 }
        let juengste = tage.prefix(14).compactMap { schlaf[$0] }.filter { $0 > 0 }
        let kcal = tage.prefix(14).map { daten.essen.summe($0).kcal }
        return ZyklusAlltag.hinweis(schlaf14: juengste, schlaf60: minuten, kcal14: kcal, kcalZiel: daten.essen.ernaehrungsZiele.kcal)
    }
}

/// Heute: Phasen-Ring, nächste Periode, heutige Einträge, Schnellknöpfe.
struct ZyklusHeuteView: View {
    let store: ZyklusStore
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @State private var blatt: ZyklusAuswahl?
    @State private var alltag: ZyklusAlltag.Hinweis?
    @State private var periodeGesetzt = 0

    var body: some View {
        let heute = store.heute
        let logik = store.logik(heute: heute)
        let ring = ZyklusHeuteLogik.ringText(logik: logik, heute: heute)
        let zeilen = ZyklusHeuteLogik.eintraege(store.tage[heute])
        ScrollView {
            VStack(spacing: Abstand.l) {
                Text(Datum.anzeige(heute))
                    .font(.title3.bold())
                    .foregroundStyle(palette.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                ZyklusRingAnsicht(abschnitte: ZyklusRingLogik.abschnitte(laenge: logik.mittlereZyklusLaenge, periodenLaenge: logik.mittlerePeriodenLaenge),
                                  fortschritt: ring.fortschritt, phase: ring.phase, titel: ring.titel, untertitel: ring.untertitel)
                if let hinweis = logik.verspaetungHinweis {
                    ZyklusKarte(titel: "Später als erwartet", symbol: "clock.fill") { ZyklusLeise(hinweis) }
                }
                if logik.verspaetung == nil, let r = logik.periodeZeitraum(breite: ZyklusZeitraum.breite(store.werte.zeitraum), spaeter: alltag?.spaeter ?? 0) {
                    vorhersage(r, logik: logik, heute: heute)
                }
                ZyklusKarte(titel: "Heute bei dir", symbol: "heart.text.square.fill") {
                    if zeilen.isEmpty {
                        ZyklusLeise("Noch nichts eingetragen. Wie geht es dir?")
                    } else {
                        ZyklusFluss {
                            ForEach(zeilen) { z in Pille(text: z.titel, symbolName: z.symbol) }
                        }
                    }
                    if let notiz = store.tage[heute]?.notiz, !notiz.isEmpty { ZyklusLeise(notiz) }
                }
                Button { blatt = ZyklusAuswahl(id: heute) } label: { Label("Heute eintragen", systemImage: "plus") }
                    .buttonStyle(.lumenHauptknopf)
                if store.tage[heute]?.blutung == nil {
                    Button {
                        if let t = ZyklusHeuteLogik.periodeStart(heute, tage: store.tage) {
                            store.setze(t)
                            periodeGesetzt += 1
                        }
                    } label: { Label("Periode beginnt heute", systemImage: "drop.fill").frame(minHeight: Abstand.tippflaeche) }
                        .buttonStyle(.federnd)
                        .foregroundStyle(palette.text)
                }
            }
            .padding(Abstand.l)
        }
        .lumenHintergrund()
        .haptik(.erfolg, bei: periodeGesetzt)
        .sheet(item: $blatt) { a in ZyklusEintragBlatt(store: store, datum: a.id) }
        .task(id: heute) { alltag = await ZyklusAlltagQuelle.hinweis(umgebung: umgebung, heute: heute) }
    }

    /// Nächste Periode als Zahl der Tage und Zeitraum; darunter der Alltag-Hinweis und wie die Vorhersage rechnet.
    private func vorhersage(_ r: ClosedRange<String>, logik: ZyklusLogik, heute: String) -> some View {
        let tage = logik.naechstePeriode.map { ZyklusHeuteLogik.tageBis(heute, $0) }
        return VStack(spacing: Abstand.s) {
            HeroKarte {
                VStack(alignment: .leading, spacing: Abstand.s) {
                    Text("Nächste Periode").font(.subheadline.weight(.semibold))
                    if let tage, tage >= 0 {
                        HStack(alignment: .firstTextBaseline, spacing: Abstand.s) {
                            RollZahl(wert: Double(tage), format: .number.precision(.fractionLength(0)))
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                            Text(tage == 1 ? "Tag" : "Tage").font(.title3.weight(.semibold))
                        }
                    }
                    Text(ZyklusZeitraum.text(r)).font(.headline)
                    if !logik.vorhersageSicher { Text("Noch ungenau: Es braucht mindestens drei Zyklen.").font(.footnote) }
                    ForEach(alltag?.texte ?? [], id: \.self) { t in
                        Label(t, systemImage: "moon.zzz.fill").font(.footnote)
                    }
                }
            }
            DisclosureGroup("So rechnet Lumen Fit") {
                Text(ZyklusZeitraum.erklaerung)
                    .font(.footnote)
                    .foregroundStyle(palette.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Abstand.xs)
            }
            .font(.footnote.weight(.semibold))
            .tint(palette.text)
            .frame(minHeight: Abstand.tippflaeche)
            Text(ZyklusZeitraum.keineVerhuetung).font(.footnote.weight(.semibold)).foregroundStyle(palette.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ZyklusAuswahl: Identifiable {
    let id: String
}
