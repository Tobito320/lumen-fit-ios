import SwiftUI

/// Die Zeile "Crew" im Gym-Tab: darunter "2 im Gym · Duell: du führst · 1 neu", rechts die Zahl der neuen Reaktionen und Einladungen.
/// Auch ohne Personen sichtbar ("Freunde einladen und herausfordern"). Öffnet die Crew-Seite.
struct CrewEinstieg: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @AppStorage(CrewDienst.gesehenSchluessel) private var gesehen: Double = 0

    var body: some View {
        let dienst = CrewDienst.von(umgebung)
        let jetzt = umgebung.uhr()
        let imGym = GymCrewQuelle.zeilen(umgebung).filter { $0.zustand == .imGym }.count
        let neu = dienst.neue(seit: gesehen > 0 ? Date(timeIntervalSince1970: gesehen) : nil).count + dienst.einladungen.count
        let text = CrewLogik.einstiegText(imGym: imGym, herausforderung: CrewLogik.einstiegStand(dienst.antwort, jetzt: jetzt), neu: neu,
                                          personen: GymCrewQuelle.eintraege(umgebung).count)
        ListenKarte {
            NavigationLink {
                FreundeTabView()
            } label: {
                HStack(spacing: Abstand.m) {
                    Image(systemName: "person.3.fill")
                        .font(.body)
                        .foregroundStyle(palette.akzent)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Freunde").font(.body.weight(.semibold)).foregroundStyle(palette.text)
                        Text(text).font(.footnote).foregroundStyle(palette.text2).lineLimit(2).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: Abstand.s)
                    if neu > 0 {
                        Text("\(neu)")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(palette.aufAkzent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(palette.akzent, in: .capsule)
                            .accessibilityHidden(true)
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.text2)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Abstand.l)
                .padding(.vertical, Abstand.m)
                .frame(minHeight: Abstand.tippflaeche)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Öffnet Freunde mit Trainingspartner, Rangliste und Herausforderungen")
        }
        .task { await dienst.laden() }
    }
}
