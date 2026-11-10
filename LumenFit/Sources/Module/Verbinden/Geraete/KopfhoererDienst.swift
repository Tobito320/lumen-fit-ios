import AVFoundation
import Foundation
import Observation

/// Kopfhörer und AirPods: liest die Audio-Route (Name und Art, ohne Rechte) und spricht Ansagen im Training (Pause vorbei, Rekord). Nichts davon läuft von allein:
/// die Route wird nur gelesen, wenn die Seite offen ist oder eine Ansage fällig wäre, der Sprecher entsteht erst bei der ersten Ansage und die Audio-Sitzung
/// wird danach wieder freigegeben (die Musik des Nutzers wird nur leiser, solange gesprochen wird).
/// Grenze: Ansagen kommen nur, solange iOS die App laufen lässt (offen oder durch die Live Activity wach); mit gesperrtem iPhone und schlafender App bleibt es still,
/// dafür bräuchte die App den Hintergrundmodus Audio (Wunsch ans Grundgerüst, `project.yml`).
@MainActor
@Observable
final class KopfhoererDienst: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var status: KopfhoererStatus = .keine

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var beobachter: NSObjectProtocol?
    @ObservationIgnored private var sprecher: AVSpeechSynthesizer?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
    }

    /// Liest die Route jetzt und bei jedem Wechsel (Einstecken, Verbinden, Trennen), bis die App endet. Mehrfach rufen schadet nicht.
    func beobachten() {
        aktualisiere()
        guard beobachter == nil else { return }
        beobachter = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.aktualisiere() }
        }
    }

    func aktualisiere() {
        let ausgaenge = AVAudioSession.sharedInstance().currentRoute.outputs.map { AudioAusgang(art: Self.art($0.portType), name: $0.portName) }
        status = KopfhoererLogik.status(ausgaenge)
    }

    private nonisolated static func art(_ port: AVAudioSession.Port) -> AudioAusgang.Art {
        switch port {
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE: .bluetooth
        case .headphones, .headsetMic, .usbAudio: .kabel
        case .builtInSpeaker, .builtInReceiver: .lautsprecher
        default: .anderes
        }
    }

    // MARK: Ansagen

    /// Die Pause im Training ist zu Ende (gerufen von `BandDienstImpl.vibriere(.pauseEnde)`, also vom Gym, unabhängig davon, ob ein Band da ist).
    func pauseEnde() { ansagen(AnsageRegel.pauseSchluessel, AnsageRegel.pauseText) }

    /// Ein Satz war ein neuer Rekord (Ereignis `satzFertig`).
    func rekord() { ansagen(AnsageRegel.rekordSchluessel, AnsageRegel.rekordText) }

    /// Der Probe-Knopf: spricht ohne Regeln, damit man hört, wie es klingt und wohin es geht.
    func testen() { sprich(AnsageRegel.pauseText) }

    private func ansagen(_ schluessel: String, _ text: String) {
        aktualisiere()
        let nur = defaults.object(forKey: AnsageRegel.nurKopfhoererSchluessel) as? Bool ?? true
        guard AnsageRegel.sprechen(an: defaults.bool(forKey: schluessel), nurMitKopfhoerern: nur, status: status) else { return }
        sprich(text)
    }

    private func sprich(_ text: String) {
        let sitzung = AVAudioSession.sharedInstance()
        try? sitzung.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? sitzung.setActive(true)
        let sprecher = self.sprecher ?? AVSpeechSynthesizer()
        sprecher.delegate = self
        self.sprecher = sprecher
        let aeusserung = AVSpeechUtterance(string: text)
        aeusserung.voice = AVSpeechSynthesisVoice(language: Bundle.main.preferredLocalizations.first == "en" ? "en-US" : "de-DE") // Stimme passend zur App-Sprache
        sprecher.speak(aeusserung)
    }

    /// Fertig gesprochen (oder abgebrochen): die Sitzung freigeben, damit die Musik wieder laut wird.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.freigeben() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.freigeben() }
    }

    private func freigeben() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
