import CoreGraphics

/// Raster 4 pt (design.md Abschnitt 5).
enum Abstand {
    nonisolated static let xs: CGFloat = 4
    nonisolated static let s: CGFloat = 8
    nonisolated static let m: CGFloat = 12
    nonisolated static let l: CGFloat = 16
    nonisolated static let xl: CGFloat = 24
    nonisolated static let xxl: CGFloat = 32
    nonisolated static let tippflaeche: CGFloat = 44
}

enum Rundung {
    nonisolated static let klein: CGFloat = 10
    nonisolated static let feld: CGFloat = 12
    nonisolated static let karte: CGFloat = 16
}
