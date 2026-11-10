// Quelle: Lovea App/LadeSprache.swift
import SwiftUI

/// Platzhalter, solange das Band noch liest: der Wert steht als graue Fläche da und atmet (Opazität 1 zu 0,45, 0,9 s). Die Bewegung läuft nur, solange gelesen wird.
/// Bei "Bewegung reduzieren" und im Stromsparmodus (`bewegungAus`) steht der Platzhalter still.
private struct BandLadendStil: ViewModifier {
    let label: String
    @Environment(\.bewegungAus) private var ruhig
    @State private var blass = false

    func body(content: Content) -> some View {
        content
            .redacted(reason: .placeholder)
            .opacity(blass ? 0.45 : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .onAppear {
                guard !ruhig else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { blass = true }
            }
            .onDisappear { withTransaction(Transaction(animation: nil)) { blass = false } }
    }
}

extension View {
    /// `an: false` lässt die Ansicht unverändert.
    @ViewBuilder
    func bandLadend(_ an: Bool = true, label: String = String(localized: "Liest")) -> some View {
        if an { modifier(BandLadendStil(label: label)) } else { self }
    }
}
