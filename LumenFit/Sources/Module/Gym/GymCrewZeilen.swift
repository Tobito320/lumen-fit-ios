import SwiftUI

/// Woher die Crew-Ansichten ihre Personen holen: die aktiven Verbindungen (in der Demo die erfundenen aus `VerbindenDemo.crew`).
@MainActor
enum GymCrewQuelle {
    static func eintraege(_ umgebung: AppUmgebung) -> [VerbindungEintrag] {
        VerbindenDemo.crew.isEmpty ? umgebung.konto.verbindungen.personen : VerbindenDemo.crew
    }

    static func zeilen(_ umgebung: AppUmgebung, datum: String? = nil) -> [CrewZeile] {
        let jetzt = umgebung.uhr()
        let heute = Datum.text(jetzt)
        return GymCrewLogik.zeilen(eintraege: eintraege(umgebung), datum: datum ?? heute, heute: heute, jetzt: jetzt)
    }
}

/// Eine Zeile je Person der Crew: Punkt, Name, Status; darunter bei einer Person im Gym ihr letzter Satz. Höchstens sechs, dann "+ n". Keine Animation.
struct GymCrewZeilen: View {
    let zeilen: [CrewZeile]
    /// Höchstens so viele Zeilen, der Rest als "+ n" (im Tab Freunde alle).
    var grenze = GymCrewLogik.sichtbar
    @Environment(\.palette) private var palette

    var body: some View {
        let sichtbar = zeilen.prefix(grenze)
        let rest = zeilen.count - sichtbar.count
        VStack(alignment: .leading, spacing: Abstand.s) {
            ForEach(Array(sichtbar)) { zeile in
                // Antippbar: die Seite der Person (Crew).
                NavigationLink { CrewFreundSeite(id: zeile.id) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Circle().fill(zeile.zustand == .imGym ? palette.akzent : palette.text2).frame(width: 6, height: 6).accessibilityHidden(true)
                            Text(zeile.name).fontWeight(.semibold).foregroundStyle(palette.text)
                            Text(zeile.status).foregroundStyle(palette.text2).monospacedDigit()
                        }
                        if let satz = zeile.mitlauf {
                            Text(GymMitlaufLogik.text(satz)).font(.caption).foregroundStyle(palette.text2).padding(.leading, 11)
                        }
                    }
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Öffnet die Seite der Person")
            }
            if rest > 0 {
                Text("+ \(rest)").foregroundStyle(palette.text2).accessibilityLabel("und \(rest) weitere")
            }
        }
        .font(.footnote)
    }
}

/// Die Freunde als Abschnitt im Gym-Tab: oben immer der Einstieg zum Tab-Inhalt Freunde, darunter die Personen (ohne Personen nur der Einstieg).
struct GymCrewAbschnitt: View {
    @Environment(AppUmgebung.self) private var umgebung

    var body: some View {
        let zeilen = GymCrewQuelle.zeilen(umgebung)
        VStack(alignment: .leading, spacing: Abstand.s) {
            CrewEinstieg()
            if !zeilen.isEmpty { GymCrewZeilen(zeilen: zeilen) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Eine Zeile oben im laufenden Training für jede Person, die gerade selbst trainiert (höchstens zwei).
struct GymMitlaufZeile: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette

    var body: some View {
        let imGym = GymCrewQuelle.zeilen(umgebung).filter { $0.zustand == .imGym }.prefix(2)
        if !imGym.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(imGym)) { z in
                    Text("\(z.name) · \(z.mitlauf.map(GymMitlaufLogik.text) ?? "im Gym")")
                        .font(.footnote).foregroundStyle(palette.text2).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

/// Holt die Verbindungen neu, solange die Ansicht sichtbar und die App vorn ist UND jemand im Gym ist: alle 30 Sekunden, bei "Bewegung reduzieren" oder
/// Stromsparmodus alle 60. Ist niemand im Gym, läuft gar keine Schleife. Endet mit der Ansicht (Task-Abbruch), keine Hintergrund-Schleife.
private struct GymCrewAbruf: ViewModifier {
    private struct Schluessel: Equatable { var aktiv: Bool; var langsam: Bool; var jemandImGym: Bool }

    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduziert
    @Environment(\.stromsparmodus) private var spar

    func body(content: Content) -> some View {
        let jemand = GymCrewQuelle.zeilen(umgebung).contains { $0.zustand == .imGym }
        content.task(id: Schluessel(aktiv: phase == .active, langsam: reduziert || spar, jemandImGym: jemand)) {
            guard phase == .active, jemand else { return }
            let sekunden = reduziert || spar ? 60 : 30
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(sekunden)) } catch { return }
                await umgebung.konto.verbindungenNeuLaden()
            }
        }
    }
}

extension View {
    /// Nur an Ansichten, die Crew oder Mitlauf zeigen (Gym-Start, laufendes Training).
    func gymCrewAbruf() -> some View { modifier(GymCrewAbruf()) }
}
