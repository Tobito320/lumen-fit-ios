// Quelle: Lovea Zyklus/ZyklusSperre.swift
import LocalAuthentication
import Observation
import SwiftUI

enum ZyklusSperreLogik {
    nonisolated static func gesperrt(aktiv: Bool, entsperrt: Bool) -> Bool { aktiv && !entsperrt }
}

/// Face ID oder Gerätecode vor dem Zyklus. Die Prüfung kommt als Closure, damit Tests ohne Gerät laufen.
/// Sperre an ist der Standard; sie schließt sich, sobald die App in den Hintergrund geht (`ZyklusEinstieg`).
@MainActor @Observable
final class ZyklusSperre {
    @ObservationIgnored private let store: ZyklusStore
    @ObservationIgnored private let pruefer: () async -> Bool
    private(set) var entsperrt = false
    private(set) var pruefungLaeuft = false
    private(set) var fehlgeschlagen = false

    init(store: ZyklusStore, pruefer: @escaping () async -> Bool = ZyklusSperre.systemPruefung) {
        self.store = store
        self.pruefer = pruefer
    }

    var aktiv: Bool {
        get { store.werte.sperre }
        set {
            store.aendere { $0.sperre = newValue }
            if !newValue { entsperrt = false }
        }
    }

    var gesperrt: Bool { ZyklusSperreLogik.gesperrt(aktiv: aktiv, entsperrt: entsperrt) }

    func entsperren() async {
        guard gesperrt, !pruefungLaeuft else { return }
        pruefungLaeuft = true
        fehlgeschlagen = false
        let ok = await pruefer()
        pruefungLaeuft = false
        if ok { entsperrt = true } else { fehlgeschlagen = true }
    }

    func sperren() { entsperrt = false }

    static func systemPruefung() async -> Bool {
        let kontext = LAContext()
        var fehler: NSError?
        guard kontext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &fehler) else { return false }
        return (try? await kontext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Dein Zyklus bleibt privat.")) ?? false
    }
}

/// Die Sperrseite: Schloss, ein Satz, ein Knopf. Fragt beim Erscheinen einmal nach Face ID oder Code.
struct ZyklusSperreAnsicht: View {
    let sperre: ZyklusSperre
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: Abstand.l) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(palette.text)
                .accessibilityHidden(true)
            Text("Nur für dich").font(.title2.bold()).foregroundStyle(palette.text)
            Text(sperre.fehlgeschlagen ? "Das hat nicht geklappt. Versuch es noch einmal." : "Entsperre mit Face ID oder Code.")
                .font(.body)
                .foregroundStyle(palette.text2)
                .multilineTextAlignment(.center)
            Button { Task { await sperre.entsperren() } } label: {
                Label("Entsperren", systemImage: "lock.open.fill")
            }
            .buttonStyle(.lumenHauptknopf)
        }
        .padding(Abstand.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .lumenHintergrund()
        .task { await sperre.entsperren() }
    }
}
