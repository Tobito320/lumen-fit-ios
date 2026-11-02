import CoreLocation
import MapKit

/// Studio-Suche mit Apple Karten (MapKit) um die aktuelle Position. Die Standort-Frage kommt erst bei der ersten Suche (`NSLocationWhenInUseUsageDescription`).
/// Position und Treffer-Orte bleiben im Speicher dieser Instanz; gespeichert wird später nur der gewählte Name. Die Suchanfrage selbst geht an Apple (Datenschutz-Text).
/// Ohne Erlaubnis oder Netz: Treffer ohne Abstand oder eine leere Liste, das freie Textfeld bleibt.
@MainActor
final class AppleStudioSuche: StudioSuchPort {
    private var sitzung: CLServiceSession?
    private var ort: CLLocation?
    private var ortVersucht = false

    func suche(text: String) async -> [StudioTreffer] {
        if !ortVersucht {
            ortVersucht = true
            ort = await standort()
        }
        let anfrage = MKLocalSearch.Request()
        anfrage.naturalLanguageQuery = text.isEmpty ? "Fitnessstudio" : text
        anfrage.pointOfInterestFilter = MKPointOfInterestFilter(including: [.fitnessCenter])
        anfrage.resultTypes = .pointOfInterest
        if let ort { anfrage.region = MKCoordinateRegion(center: ort.coordinate, latitudinalMeters: 20_000, longitudinalMeters: 20_000) }
        guard let antwort = try? await MKLocalSearch(request: anfrage).start() else { return [] }
        let von = ort
        return antwort.mapItems.compactMap { item in
            guard let name = item.name else { return nil }
            return StudioTreffer(name: name, entfernungM: von.map { $0.distance(from: item.location) })
        }
    }

    /// Eine Position, höchstens 8 Sekunden; nil bei Ablehnung oder Zeitablauf.
    private func standort() async -> CLLocation? {
        sitzung = CLServiceSession(authorization: .whenInUse)
        return await withTaskGroup(of: CLLocation?.self) { gruppe in
            gruppe.addTask { await Self.ersteWerte() }
            gruppe.addTask {
                try? await Task.sleep(for: .seconds(8))
                return nil
            }
            let erste = await gruppe.next() ?? nil
            gruppe.cancelAll()
            return erste
        }
    }

    nonisolated private static func ersteWerte() async -> CLLocation? {
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if let l = update.location { return l }
                if update.authorizationDenied || update.authorizationDeniedGlobally { return nil }
            }
        } catch {
            return nil
        }
        return nil
    }
}
