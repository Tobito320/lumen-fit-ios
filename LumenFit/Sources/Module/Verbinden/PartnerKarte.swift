import SwiftUI

/// Die Karte des Trainingspartners (Idee 82, ab 09.11.2026 ein frei gewählter Freund statt fest der Lovea-Person): der Tab Freunde zeigt sie als "Heute"
/// (nur mit Lovea, bis Build 20), Schlaf und Essen betten sie ein, Gym mit "Eure Woche". Sie zeigt nur, was die Person freigibt und die Datei enthält.
/// Nicht verbunden, veraltet, falsche Version, nichts freigegeben: gar nichts, nicht einmal einen Platzhalter oder eine Fehlermeldung.
struct PartnerKarte: View {
    let bereich: PartnerBereich
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.bewegungAus) private var bewegungAus
    @State private var vergleichOffen = false

    private var stand: PartnerStand {
        VerbindenDemo.partner ?? umgebung.daten?.verbindung.partner ?? .nichtVerbunden
    }

    var body: some View {
        if let datei = PartnerAnzeige.zusammenfassung(stand) {
            let zeilen = PartnerAnzeige.zeilen(datei, bereich: bereich)
            // Die Ansichten: Heute alle, Essen das Tagebuch, Gym Plan und Verlauf.
            let einstiege = PartnerAnsichtLogik.einstiege(datei, jetzt: umgebung.uhr(), bereich: bereich)
            if !zeilen.isEmpty || !einstiege.isEmpty { karte(datei, zeilen, einstiege) }
        }
    }

    private func karte(_ datei: ZusammenfassungDatei, _ zeilen: [PartnerAnzeige.Zeile], _ einstiege: [PartnerAnsichtLogik.Einstieg]) -> some View {
        let name = datei.profilName
        return ListenKarte {
            kopf(name)
            if bereich == .gym {
                Haarlinie()
                CrewWocheZusammen(name: name, datei: datei).padding(Abstand.l)
            }
            ForEach(zeilen) { zeile in
                Haarlinie()
                if zeile.titel == String(localized: "Schritte"), !PartnerVergleich.partnerSchritte(datei).isEmpty {
                    Button { vergleichOffen = true } label: { schritteZeile(zeile, datei) }
                        .buttonStyle(.federnd)
                        .accessibilityHint("Zeigt die Woche im Vergleich mit dir")
                        .accessibilityAddTraits(.isButton)
                } else {
                    zeileInhalt(zeile)
                }
            }
            if bereich == .heute, PartnerAnzeige.energie(datei) != nil {
                Haarlinie()
                PartnerEnergieZeile(datei: datei)
            }
            if !einstiege.isEmpty {
                Haarlinie()
                PartnerEinstiegZeilen(einstiege: einstiege)
            }
        }
        .karteScrollt()
        .sheet(isPresented: $vergleichOffen) { SchritteVergleichSeite(partner: datei) }
        .haptik(.auswahl, bei: vergleichOffen)
    }

    /// "Trainingspartner" und der Name; ein Tipp öffnet seine Seite in der Crew (wenn die Verbindung bekannt ist).
    @ViewBuilder
    private func kopf(_ name: String) -> some View {
        let inhalt = HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(bereich == .heute ? "Heute" : "Trainingspartner")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.text2)
                Text(name)
                    .font(.headline)
                    .foregroundStyle(palette.text)
            }
            Spacer(minLength: 0)
        }
        .padding(Abstand.l)
        .contentShape(.rect)
        if let id = umgebung.konto.partnerId {
            NavigationLink { CrewFreundSeite(id: id) } label: {
                HStack {
                    inhalt
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).padding(.trailing, Abstand.l)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint("Öffnet die Seite der Person")
        } else {
            inhalt
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func zeileInhalt(_ zeile: PartnerAnzeige.Zeile) -> some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: zeile.symbol)
                .frame(width: 28)
                .foregroundStyle(palette.text2)
                .accessibilityHidden(true)
            Text(zeile.titel)
                .foregroundStyle(palette.text)
            Spacer(minLength: Abstand.m)
            Text(zeile.wert)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(palette.text)
        }
        .padding(.horizontal, Abstand.l)
        .frame(minHeight: Abstand.tippflaeche)
        .accessibilityElement(children: .combine)
    }

    /// Die Schritte-Zeile mit Ring gegen das Schrittziel des Partners (wenn bekannt) und Pfeil: ein Tipp öffnet den Wochenvergleich.
    private func schritteZeile(_ zeile: PartnerAnzeige.Zeile, _ datei: ZusammenfassungDatei) -> some View {
        let anteil = datei.heute.schritte.flatMap { s in datei.heute.schritteZiel.map { WidgetAnzeige.anteil(s, $0) } }
        return HStack(spacing: Abstand.m) {
            ZStack {
                if let anteil {
                    Circle().stroke(palette.haar, lineWidth: 3)
                    Circle().trim(from: 0, to: anteil)
                        .stroke(palette.text, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(bewegungAus ? nil : Feder.weich, value: anteil)
                }
                Image(systemName: zeile.symbol).font(.footnote).foregroundStyle(palette.text2)
            }
            .frame(width: 28, height: 28)
            .accessibilityHidden(true)
            Text(zeile.titel).foregroundStyle(palette.text)
            Spacer(minLength: Abstand.m)
            Text(zeile.wert)
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(palette.text)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true)
        }
        .padding(.horizontal, Abstand.l)
        .frame(minHeight: Abstand.tippflaeche)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
