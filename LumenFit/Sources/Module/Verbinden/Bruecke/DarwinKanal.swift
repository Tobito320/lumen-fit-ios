import Foundation

/// Darwin-Benachrichtigungen als Anstoß zwischen Lumen Fit und Lovea (SPEC 5.5). Sie tragen keine Daten und wecken keine beendete App:
/// gelesen wird beim Öffnen (`Ereignis.vordergrund`) und im Hintergrund-Abruf. Die Namen sind eine Annahme (mit Lovea abzustimmen).
enum DarwinKanal {
    nonisolated static let zusammenfassung = "com.onlyus.lumen-fit.zusammenfassung"
    nonisolated static let bandStatus = "com.onlyus.lumen-fit.band-status"
    nonisolated static let partner = "com.onlyus.lovea.partner"
    nonisolated static let bandWunsch = "com.onlyus.lovea.band-wunsch"
    /// Lumen Alarm hat Weck-Wünsche für das Band abgelegt oder gestrichen (`docs/BAND-VERTRAG.md` in Lumen Alarm).
    nonisolated static let alarmWunsch = "com.onlyus.lumen-alarm.band-wunsch"

    /// Meldet `name` an alle Prozesse, die darauf hören.
    static func sende(_ name: String) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(name as CFString), nil, nil, true)
    }
}

/// Hört auf eine Darwin-Benachrichtigung, solange das Objekt lebt. Der Rückruf ist eine C-Funktion ohne Erfassung; der Zustand geht über einen
/// `Unmanaged`-Zeiger, danach läuft die Aufgabe auf dem Hauptakteur (SPEC 5.9 Vertrag 10).
final class DarwinBeobachter: Sendable {
    private let name: String
    private let aktion: @MainActor @Sendable () -> Void

    init(name: String, aktion: @escaping @MainActor @Sendable () -> Void) {
        self.name = name
        self.aktion = aktion
        let zeiger = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), zeiger, { _, beobachter, _, _, _ in
            guard let beobachter else { return }
            let ich = Unmanaged<DarwinBeobachter>.fromOpaque(beobachter).takeUnretainedValue()
            Task { @MainActor in ich.aktion() }
        }, name as CFString, nil, .deliverImmediately)
    }

    deinit {
        let zeiger = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), zeiger, CFNotificationName(name as CFString), nil)
    }
}
