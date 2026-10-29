import SwiftUI
import UIKit

/// Health-Zugriff im Klartext (Idee 75): je Datentyp der Grund und eine Zeile "Daten da" oder "keine Daten in 30 Tagen", dazu der Weg in die Einstellungen.
/// Die Seite behauptet nie, ein Recht sei erlaubt oder abgelehnt: HealthKit verrät das beim Lesen nie. Sie liest nur und fragt keine Rechte.
struct ProfilHealthZugriffView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    @State private var befund: ProfilHealthProbe.Befund?

    var body: some View {
        let einstellungen = umgebung.daten?.einstellungen.werte ?? Einstellungen()
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.xl) {
                Text(ProfilHealthProbe.erklaerung).font(.body).foregroundStyle(palette.text2)

                VStack(alignment: .leading, spacing: Abstand.s) {
                    ProfilGruppenKopf(text: "Was Lumen Fit liest")
                    ListenKarte {
                        ForEach(HealthTyp.allCases, id: \.self) { typ in
                            zeile(typ)
                            if typ != HealthTyp.allCases.last { Haarlinie() }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Abstand.s) {
                    ProfilGruppenKopf(text: "Ändern")
                    if !einstellungen.healthGefragt {
                        Button {
                            Task {
                                _ = await umgebung.healthLeser.zugriff(fuer: Set(HealthTyp.allCases))
                                umgebung.daten?.einstellungen.aendere { $0.healthGefragt = true }
                                await pruefe()
                            }
                        } label: {
                            Label("Health-Abfrage anzeigen", systemImage: "heart.fill").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(palette.aufAkzent)
                    }
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Label("Einstellungen öffnen", systemImage: "gearshape").frame(maxWidth: .infinity, minHeight: Abstand.tippflaeche)
                    }
                    .buttonStyle(.bordered)
                    Text("Weg in die Einstellungen: \(ProfilHealthProbe.wegText).")
                        .font(.footnote).foregroundStyle(palette.text2).padding(.horizontal, Abstand.xs)
                }

                VStack(alignment: .leading, spacing: Abstand.s) {
                    ProfilGruppenKopf(text: "Schreiben")
                    ListenKarte {
                        Toggle(isOn: Binding(get: { einstellungen.healthSchreiben },
                                             set: { an in umgebung.daten?.einstellungen.aendere { $0.healthSchreiben = an } })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Training und Gewicht in Health speichern").font(.body).foregroundStyle(palette.text)
                                Text("Standard aus. Beim ersten Speichern fragt iOS nach dem Schreiben.").font(.footnote).foregroundStyle(palette.text2)
                            }
                        }
                        .padding(Abstand.l).frame(minHeight: Abstand.tippflaeche)
                    }
                }
            }
            .padding(Abstand.l)
        }
        .navigationTitle("Health-Zugriff")
        .navigationBarTitleDisplayMode(.inline)
        .lumenHintergrund()
        .task { await pruefe() }
    }

    private func zeile(_ typ: HealthTyp) -> some View {
        let stand = befund.map { ProfilHealthProbe.zeile(typ, $0) }
        return HStack(alignment: .top, spacing: Abstand.m) {
            Image(systemName: ProfilHealthProbe.symbol(typ)).font(.body.weight(.semibold)).foregroundStyle(palette.text).frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(ProfilHealthProbe.name(typ)).font(.body).foregroundStyle(palette.text)
                Text(ProfilHealthProbe.grund(typ)).font(.footnote).foregroundStyle(palette.text2)
                if let stand {
                    Label(ProfilHealthProbe.text(stand), systemImage: stand == .datenDa ? "checkmark.circle.fill" : (stand == .keineDaten ? "circle.dashed" : "questionmark.circle"))
                        .font(.footnote.weight(.semibold)).foregroundStyle(palette.text)
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Abstand.l)
        .accessibilityElement(children: .combine)
    }

    private func pruefe() async {
        let heute = Datum.text(umgebung.uhr())
        befund = await ProfilHealthProbe.probe(leser: umgebung.healthLeser, heute: heute)
    }
}
