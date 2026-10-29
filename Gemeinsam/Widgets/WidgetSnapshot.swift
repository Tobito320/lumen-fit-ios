import Foundation

/// Stand für die Widgets, geschrieben von der App als `widget-stand.json` im Gruppenordner. Stub des Grundgerüsts: das Modul widgets
/// ersetzt den Inhalt (Bögen, Plan, Serie, Gewohnheiten, Essen) und liest und schreibt ihn.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    var geschrieben: Date
    var profilName: String
}
