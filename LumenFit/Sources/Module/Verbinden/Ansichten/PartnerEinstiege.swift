import SwiftUI

/// Das Ziel eines Einstiegs: die Ansicht zur Freigabe-Art.
struct PartnerAnsichtZiel: View {
    let art: FreigabeArt

    var body: some View {
        switch art {
        case .plan: PartnerPlanAnsicht()
        case .verlauf: PartnerVerlaufAnsicht()
        case .tagebuch: PartnerTagebuchAnsicht()
        case .koerper: PartnerKoerperAnsicht()
        case .schritte, .gym, .schlaf, .essen: EmptyView()
        }
    }
}

/// Die Zeilen "Trainingsplan, Training und Verlauf, Tagebuch, Körperwerte" des Partners, je mit Pfeil in die Ansicht. Auf einer Karte stehen Haarlinien zwischen
/// den Zeilen (die Karte darum und eine Linie davor liefert der Aufrufer); `imFormular` lässt Linien und Pfeil weg, die setzt das Formular selbst.
struct PartnerEinstiegZeilen: View {
    let einstiege: [PartnerAnsichtLogik.Einstieg]
    var imFormular = false
    @Environment(\.palette) private var palette

    var body: some View {
        ForEach(Array(einstiege.enumerated()), id: \.element.id) { i, e in
            if i > 0, !imFormular { Haarlinie() }
            if imFormular {
                NavigationLink { PartnerAnsichtZiel(art: e.art) } label: { zeile(e) }
            } else {
                NavigationLink { PartnerAnsichtZiel(art: e.art) } label: { zeile(e) }
                    .buttonStyle(.federnd)
            }
        }
    }

    private func zeile(_ e: PartnerAnsichtLogik.Einstieg) -> some View {
        HStack(spacing: Abstand.m) {
            Image(systemName: e.symbol).frame(width: 28).foregroundStyle(palette.text2).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.titel).foregroundStyle(palette.text)
                if !e.untertitel.isEmpty { Text(e.untertitel).font(.footnote).foregroundStyle(palette.text2) }
            }
            Spacer(minLength: Abstand.m)
            if !imFormular { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.text2).accessibilityHidden(true) }
        }
        .padding(.horizontal, imFormular ? 0 : Abstand.l)
        .padding(.vertical, Abstand.s)
        .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Eine eigene Karte mit den Einstiegen, für Seiten ohne Partner-Karte (Freunde). Erscheint nur, wenn der Partner etwas davon freigegeben hat; auch bei älterem
/// Stand (dann zeigen die Ansichten den Hinweis). Sonst gar nichts, nicht einmal einen Platzhalter.
struct PartnerAnsichtenKarte: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        if let datei = PartnerAnsichtLogik.datei(PartnerAnsichtLogik.aktuellerStand(umgebung)) {
            let einstiege = PartnerAnsichtLogik.einstiege(datei, jetzt: umgebung.uhr())
            if !einstiege.isEmpty {
                ListenKarte {
                    Text("Mehr von \(datei.profilName)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.text2)
                        .padding(Abstand.l)
                        .accessibilityAddTraits(.isHeader)
                    Haarlinie()
                    PartnerEinstiegZeilen(einstiege: einstiege)
                }
            }
        }
    }
}
