import Foundation
import UserNotifications

/// Lokale Mitteilungen (zum Beispiel "Partner ist im Gym"). Nie als geplante Erinnerung: `zeige` meldet sofort.
protocol Mitteiler: Sendable {
    func erlaubnisHolen() async -> Bool
    func zeige(id: String, titel: String, text: String, route: Route?) async
}

/// Der echte Mitteiler über `UNUserNotificationCenter`. Die Route steckt als `lumenfit://`-Link in `userInfo["link"]`.
struct SystemMitteiler: Mitteiler {
    func erlaubnisHolen() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func zeige(id: String, titel: String, text: String, route: Route?) async {
        // Rechte erst bei der ersten Mitteilung, nie beim Start (09.11.2026); einmal entschieden fragt iOS nicht mehr.
        if await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined {
            guard await erlaubnisHolen() else { return }
        }
        let inhalt = UNMutableNotificationContent()
        inhalt.title = titel
        inhalt.body = text
        if let route { inhalt.userInfo = ["link": RouteURL.url(fuer: route).absoluteString] }
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: inhalt, trigger: nil))
    }
}

/// Standard, solange nichts anderes gesetzt ist: tut nichts.
struct StilleMitteilung: Mitteiler {
    func erlaubnisHolen() async -> Bool { false }
    func zeige(id: String, titel: String, text: String, route: Route?) async {}
}
