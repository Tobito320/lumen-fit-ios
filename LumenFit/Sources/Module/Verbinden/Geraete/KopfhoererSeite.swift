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
            VerbindenAbschnitt(titel: "Was iOS nicht erlaubt",
                               fuss: "Den Akku der AirPods, ihre Sensoren für Hörer und die Einstellungen am Gerät zeigt iOS nur Apple selbst. Lumen Fit zeigt darum nur, ob ein Kopfhörer verbunden ist, und sagt in den Kopfhörer, wenn die Pause vorbei ist.") {
                EmptyView()
            }
        }
        .verbindenFormular()
        .navigationTitle("Kopfhörer und AirPods")
        .navigationBarTitleDisplayMode(.inline)
        .task { dienst?.beobachten() }
    }
}

/// Der Kopf: Symbol, Titel und Name des Geräts. Das Symbol wechselt weich, wenn der Kopfhörer kommt oder geht.
private struct KopfhoererKopf: View {
    let status: KopfhoererStatus
    @Environment(\.bewegungAus) private var ruhig

    var body: some View {
        Section {
            HeroKarte {
                HStack(spacing: Abstand.m) {
                    Image(systemName: KopfhoererLogik.symbol(status))
                        .font(.largeTitle)
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(KopfhoererLogik.titel(status)).font(.headline)
                        if let name = KopfhoererLogik.name(status) { Text(name).font(.subheadline).opacity(0.8) }
                    }
                }
                .animation(ruhig ? nil : Feder.weich, value: status)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
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
        VerbindenAbschnitt(titel: "Ansagen im Training", fuss: "Standard aus. Lumen Fit spricht kurz in die Kopfhörer und macht die Musik währenddessen leiser. Das klappt, solange die App läuft (offen oder durch das Training wach); mit gesperrtem iPhone und schlafender App bleibt es still.") {
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
