import PhotosUI
import SwiftUI

/// Die Freunde-Seite (Idee 89, 90): die eigene Wochenkarte als Bild, Link oder QR teilen, Karten von Freunden lesen (Link, Zwischenablage, QR im Foto),
/// vor dem Übernehmen ansehen und die Wochen-Rangliste mit "Respekt" statt Like. Alles ohne Server; `daten` ist die Nutzlast eines geöffneten Links.
struct FreundeView: View {
    var daten: String?
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        Group {
            if let satz = umgebung.daten {
                FreundeInhalt(daten: satz, link: daten)
            } else {
                LeerZustand(stimmung: .bereit, satz: "Lege zuerst ein Profil an.")
            }
        }
        .navigationTitle("Freunde")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
    }
}

private struct FreundeInhalt: View {
    let daten: DatenSatz
    let link: String?
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var schema
    @State private var gelesen: Gelesen?
    @State private var bild: UIImage?
    @State private var foto: PhotosPickerItem?
    @State private var toast: ToastInhalt?

    private enum Gelesen: Equatable {
        case karte(FreundKarte)
        case fehler(String, String)
    }

    private var freunde: [FreundKarte] { daten.verbindung.freunde }
    private var absender: String { FreundeKarteCodec.absender(daten.profil) }

    private var eigene: FreundKarte {
        let jetzt = umgebung.uhr()
        return FreundeRangliste.eigene(name: umgebung.profil.aktiv?.name ?? "Ich", absender: absender, jetzt: jetzt,
                                       schritteJeTag: umgebung.gesundheit.tage.mapValues(\.schritte),
                                       gymTage: LoveaBrueckeDienst.gymTageDerWoche(daten.training.sessions, heute: Datum.text(jetzt)),
                                       schlafMinutenJeTag: umgebung.gesundheit.naechte.mapValues(\.schlafMinuten))
    }

    var body: some View {
        let karte = eigene
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                if let gelesen { gelesenKarte(gelesen) }
                PartnerAnsichtenKarte()
                eigeneKarte(karte)
                ranglisteKarte(karte)
                importKarte
            }
            .padding(.horizontal, Abstand.l)
            .padding(.vertical, Abstand.m)
        }
        .lumenToast($toast)
        .task(id: link) { if let link { pruefe(link) } }
        .task(id: Self.stempel(karte)) { rendere(karte) }
        .onChange(of: foto) { _, neu in if let neu { Task { await fotoLesen(neu) } } }
    }

    /// Ändert sich nichts Sichtbares an der Karte, bleibt das Bild; der Erstellzeitpunkt zählt nicht.
    private static func stempel(_ k: FreundKarte) -> String { "\(k.id)|\(k.name)|\(k.schritte)|\(k.gymTage)|\(k.schlafSchnittMinuten ?? -1)" }

    // MARK: Eigene Karte

    private func eigeneKarte(_ karte: FreundKarte) -> some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            Text("Deine Karte").font(.headline).foregroundStyle(palette.text)
            if let bild {
                Image(uiImage: bild)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: Rundung.karte, style: .continuous))
                    .accessibilityLabel("Deine Wochenkarte")
                    .accessibilityValue("\(karte.name), Woche ab \(FreundeText.woche(karte.woche)), \(FreundeText.zusammenfassung(karte))")
                HStack(spacing: Abstand.m) {
                    ShareLink(item: Image(uiImage: bild), preview: SharePreview("Meine Woche in Lumen Fit", image: Image(uiImage: bild))) {
                        Label("Als Bild teilen", systemImage: "photo")
                    }
                    ShareLink(item: FreundeKarteCodec.link(karte, absender: absender), message: Text("Meine Woche in Lumen Fit")) {
                        Label("Link teilen", systemImage: "link")
                    }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: Abstand.tippflaeche)
            }
            Text("Deine Karte zeigt nur diese Woche: Schritte, Gym-Tage und Schlaf im Schnitt. Sie geht nie ohne dein Teilen weg.")
                .font(.footnote)
                .foregroundStyle(palette.text2)
        }
    }

    @MainActor
    private func rendere(_ karte: FreundKarte) {
        let qr = FreundeQR.bild(FreundeKarteCodec.link(karte, absender: absender).absoluteString)
        let renderer = ImageRenderer(content: FreundeKartenBild(karte: karte, qr: qr, palette: palette).environment(\.colorScheme, schema))
        renderer.scale = 3
        bild = renderer.uiImage
    }

    // MARK: Rangliste

    private func ranglisteKarte(_ karte: FreundKarte) -> some View {
        let woche = FreundeRangliste.woche(freunde, eigene: karte) ?? karte.woche
        let zeilen = FreundeRangliste.rangliste(freunde, eigene: karte, woche: woche)
        return VStack(alignment: .leading, spacing: Abstand.m) {
            Text("Rangliste, Woche ab \(FreundeText.woche(woche))").font(.headline).foregroundStyle(palette.text)
            if zeilen.count <= 1 {
                LeerZustand(stimmung: .bereit, satz: "Noch keine Karte von Freunden für diese Woche. Lies eine Karte ein, dann erscheint hier die Rangliste.")
            } else {
                ListenKarte {
                    ForEach(zeilen) { zeile in
                        if zeile.id != zeilen.first?.id { Haarlinie() }
                        ranglistenZeile(zeile)
                    }
                }
            }
        }
    }

    private func ranglistenZeile(_ zeile: FreundeRangliste.Zeile) -> some View {
        HStack(spacing: Abstand.m) {
            Text("\(zeile.platz)")
                .font(.headline)
                .monospacedDigit()
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(zeile.eigene ? "\(zeile.karte.name) (du)" : zeile.karte.name).font(.body.weight(.semibold))
                Text(FreundeText.zusammenfassung(zeile.karte)).font(.footnote).foregroundStyle(palette.text2)
            }
            Spacer(minLength: Abstand.s)
            if !zeile.eigene { respektKnopf(zeile.karte) }
        }
        .foregroundStyle(palette.text)
        .padding(.horizontal, Abstand.l)
        .frame(minHeight: Abstand.tippflaeche)
        .contextMenu {
            if !zeile.eigene { Button("Karte entfernen", systemImage: "trash", role: .destructive) { entferne(zeile.karte) } }
        }
    }

    /// "Respekt" statt Like: ein stilles Zeichen, nur auf diesem Gerät gemerkt, ohne Zähler.
    private func respektKnopf(_ karte: FreundKarte) -> some View {
        Button {
            var liste = daten.verbindung.freunde
            if let i = liste.firstIndex(where: { $0.id == karte.id }) {
                liste[i].respekt.toggle()
                daten.verbindung.freunde = liste
            }
        } label: {
            Image(systemName: karte.respekt ? "hands.clap.fill" : "hands.clap")
                .frame(minWidth: Abstand.tippflaeche, minHeight: Abstand.tippflaeche)
        }
        .accessibilityLabel(karte.respekt ? "Respekt für \(karte.name) zurücknehmen" : "\(karte.name) Respekt geben")
        .haptik(.erfolg, bei: karte.respekt)
    }

    private func entferne(_ karte: FreundKarte) {
        daten.verbindung.freunde = daten.verbindung.freunde.filter { $0.id != karte.id }
    }

    // MARK: Karte lesen

    private var importKarte: some View {
        VStack(alignment: .leading, spacing: Abstand.m) {
            Text("Karte eines Freundes lesen").font(.headline).foregroundStyle(palette.text)
            HStack(spacing: Abstand.m) {
                PasteButton(payloadType: String.self) { texte in
                    let text = texte.first ?? ""
                    Task { @MainActor in pruefe(text) }
                }
                .buttonBorderShape(.capsule)
                PhotosPicker(selection: $foto, matching: .images) {
                    Label("QR-Code aus Foto", systemImage: "qrcode.viewfinder")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
            .frame(minHeight: Abstand.tippflaeche)
            Text("Einfacher: den QR-Code mit der Kamera-App scannen oder den Link antippen, dann öffnet sich diese Seite mit der Karte.")
                .font(.footnote)
                .foregroundStyle(palette.text2)
        }
    }

    @MainActor
    private func pruefe(_ text: String) {
        switch FreundeKarteCodec.lies(text) {
        case .success(let karte):
            gelesen = karte.id == eigene.id ? .fehler("Das ist deine eigene Karte", "Schick sie einem Freund und lies seine Karte ein.") : .karte(karte)
        case .failure(let fehler):
            let t = FreundeText.fehler(fehler)
            gelesen = .fehler(t.titel, t.hilfe)
        }
    }

    private func fotoLesen(_ auswahl: PhotosPickerItem) async {
        defer { foto = nil }
        guard let data = try? await auswahl.loadTransferable(type: Data.self), let bild = UIImage(data: data) else {
            gelesen = .fehler("Das Foto ließ sich nicht öffnen", "Wähle ein anderes Foto oder lies den Link ein.")
            return
        }
        guard let text = FreundeQR.text(in: bild) else {
            gelesen = .fehler("Kein QR-Code gefunden", "Das Foto muss den QR-Code ganz und scharf zeigen.")
            return
        }
        pruefe(text)
    }

    @ViewBuilder
    private func gelesenKarte(_ stand: Gelesen) -> some View {
        switch stand {
        case .fehler(let titel, let hilfe):
            VStack(alignment: .leading, spacing: Abstand.m) {
                FehlerKarte(titel: titel, hilfe: hilfe)
                Button("Schließen") { gelesen = nil }
                    .buttonStyle(.bordered)
                    .frame(minHeight: Abstand.tippflaeche)
            }
        case .karte(let karte):
            VStack(alignment: .leading, spacing: Abstand.m) {
                HeroKarte {
                    VStack(alignment: .leading, spacing: Abstand.xs) {
                        Text("Neue Karte").font(.footnote.weight(.semibold))
                        Text(karte.name).font(.title.bold())
                        Text("Woche ab \(FreundeText.woche(karte.woche))").font(.subheadline)
                        Text(FreundeText.zusammenfassung(karte)).font(.body).padding(.top, Abstand.xs)
                    }
                    .accessibilityElement(children: .combine)
                }
                HStack(spacing: Abstand.m) {
                    Button("Übernehmen") { uebernehme(karte) }
                        .buttonStyle(.lumenHauptknopf)
                    Button("Verwerfen") { gelesen = nil }
                        .buttonStyle(.bordered)
                }
                .frame(minHeight: Abstand.tippflaeche)
            }
        }
    }

    private func uebernehme(_ karte: FreundKarte) {
        daten.verbindung.freunde = FreundeRangliste.aufnehmen(karte, in: daten.verbindung.freunde)
        gelesen = nil
        toast = ToastInhalt(titel: "\(karte.name) ist dabei", zeile: "Die Rangliste ist aktuell.", stimmung: .stolz)
    }
}
