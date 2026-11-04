import SwiftUI

extension View {
    /// Lange drücken und ziehen (W-004): die Übung landet an der Stelle der Zeile, auf die sie fällt. Getragen wird nur die Plan-Id.
    /// Muster wie Lovea `ChatEingabeleiste` (Anhänge sortieren); `reorderable()` gibt es erst ab iOS 27.
    func uebungZiehen(_ id: String, ablegen: @escaping (_ von: String, _ auf: String) -> Void) -> some View {
        draggable(id)
            .dropDestination(for: String.self) { ids, _ in
                guard let von = ids.first, von != id else { return false }
                ablegen(von, id)
                return true
            }
    }
}
