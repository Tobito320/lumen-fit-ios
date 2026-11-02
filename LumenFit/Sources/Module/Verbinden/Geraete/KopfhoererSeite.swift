import SwiftUI

/// Kopfhörer und AirPods: was iOS Apps wirklich erlaubt. Gebaut ist die Route (verbunden oder nicht, mit Namen) und die gesprochene Ansage im Training über die Kopfhörer.
/// Nicht gebaut, weil iOS es nicht hergibt: Akku der AirPods, Hörer-Daten, Einstellungen der AirPods. Die Kopfbewegung (CMHeadphoneMotionManager) braucht einen
/// Eintrag in der Info.plist und hat in Lumen Fit noch keine Funktion; sie steht als Idee in `Geräte.md`.
struct KopfhoererSeite: View {
    @Environment(\.palette) private var palette

    private var dienst: KopfhoererDienst? { VerbindenDienste.geteilt?.kopfhoerer }

    var body: some View {
        Form {
            if let dienst { KopfhoererKopf(status: dienst.status) }
            AnsageAbschnitt(dienst: dienst)
            VerbindenAbschnitt(fuss: "Akku, Sensoren und Einstellungen der AirPods gibt iOS Apps nicht frei.") {
                EmptyView()
            }
        }
        .verbindenFormular()
        .navigationTitle("Kopfhörer und AirPods")
        .navigationBarTitleDisplayMode(.inline)
        .task { dienst?.beobachten() }
    }
}

/// Der Stand als eine Zeile: Symbol und Titel links, Name des Geräts rechts. Das Symbol wechselt weich, wenn der Kopfhörer kommt oder geht.
private struct KopfhoererKopf: View {
    let status: KopfhoererStatus
    @Environment(\.bewegungAus) private var ruhig

    var body: some View {
        VerbindenAbschnitt {
            LabeledContent {
                if let name = KopfhoererLogik.name(status) { Text(name).lineLimit(1).minimumScaleFactor(0.8) }
            } label: {
                Label {
                    Text(KopfhoererLogik.titel(status)).lineLimit(1).minimumScaleFactor(0.8)
                } icon: {
                    Image(systemName: KopfhoererLogik.symbol(status)).contentTransition(.symbolEffect(.replace))
                }
            }
            .animation(ruhig ? nil : Feder.weich, value: status)
        }
    }
}

/// Ansagen im Training: Pause vorbei und Rekord, nur mit Kopfhörern (Standard) und nur, solange die App läuft.
private struct AnsageAbschnitt: View {
    let dienst: KopfhoererDienst?
    @AppStorage(AnsageRegel.pauseSchluessel) private var pause = false
    @AppStorage(AnsageRegel.rekordSchluessel) private var rekord = false
    @AppStorage(AnsageRegel.nurKopfhoererSchluessel) private var nurKopfhoerer = true

    var body: some View {
        VerbindenAbschnitt(titel: "Ansagen im Training", fuss: "Klappt nur, solange Lumen Fit offen oder durch das Training wach ist.") {
            Toggle(isOn: $pause) { Label("Pause vorbei ansagen", systemImage: "timer") }
                .frame(minHeight: Abstand.tippflaeche)
            Toggle(isOn: $rekord) { Label("Neuen Rekord ansagen", systemImage: "trophy.fill") }
                .frame(minHeight: Abstand.tippflaeche)
            Toggle(isOn: $nurKopfhoerer) { Label("Nur mit Kopfhörern", systemImage: "headphones") }
                .frame(minHeight: Abstand.tippflaeche)
            Button { dienst?.testen() } label: { Label("Ansage testen", systemImage: "speaker.wave.2.fill") }
                .frame(minHeight: Abstand.tippflaeche)
        }
    }
}
