import SwiftUI
import UIKit

/// Health-Zugriff im Klartext (Idee 75): kompakt eine Zeile je Einstellung. Je Datentyp "Daten da" oder "keine Daten in 30 Tagen" liegt eine Ebene tiefer
/// ("Was Lumen Fit liest", mit dem Grund je Typ). Die Seite behauptet nie, ein Recht sei erlaubt oder abgelehnt: HealthKit verrät das beim Lesen nie.
/// Sie liest nur und fragt keine Rechte (außer auf Knopfdruck "Health-Abfrage anzeigen").
struct ProfilHealthZugriffView: View {
    @Environment(AppUmgebung.self) private var umgebung
    @Environment(\.openURL) private var openURL
    @State private var befund: ProfilHealthProbe.Befund?

    var body: some View {
        let einstellungen = umgebung.daten?.einstellungen.werte ?? Einstellungen()
        List {
            ProfilAbschnitt(fuss: String(localized: "Health verrät nicht, ob Lesen gesperrt ist; du siehst nur, ob Daten ankommen.")) {
                NavigationLink { ProfilHealthTypenView(befund: befund, typen: einstellungen.healthTypen) } label: {
                    ProfilListenZeile(String(localized: "Was Lumen Fit liest"), symbol: "heart.text.square.fill", wert: lesenWert(einstellungen))
                }
            }
            ProfilAbschnitt(fuss: String(localized: "Weg: \(ProfilHealthProbe.wegText).")) {
                if !einstellungen.healthGefragt {
                    Button {
                        Task {
                            _ = await umgebung.healthLeser.zugriff(fuer: einstellungen.healthTypen)
                            umgebung.daten?.einstellungen.aendere { $0.healthGefragt = true }
                            await pruefe()
                        }
                    } label: {
                        Label("Health-Abfrage anzeigen", systemImage: "heart.fill")
                    }
                }
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Label("Einstellungen öffnen", systemImage: "gearshape")
                }
            }
            ProfilAbschnitt(fuss: String(localized: "Beim ersten Speichern fragt iOS nach dem Schreiben.")) {
                Toggle(isOn: Binding(get: { einstellungen.healthSchreiben },
                                     set: { an in umgebung.daten?.einstellungen.aendere { $0.healthSchreiben = an } })) {
                    ProfilListenZeile(String(localized: "Training und Gewicht speichern"))
                }
            }
        }
        .profilListe()
        .navigationTitle("Health-Zugriff")
        .task { await pruefe() }
    }

    /// "9 von 14 mit Daten"; solange die Prüfung läuft, nichts.
    private func lesenWert(_ einstellungen: Einstellungen) -> String? {
        befund.map { ProfilHealthProbe.zusammenfassung($0, typen: einstellungen.healthTypen) }
    }

    private func pruefe() async {
        let heute = Datum.text(umgebung.uhr())
        befund = await ProfilHealthProbe.probe(leser: umgebung.healthLeser, heute: heute)
    }
}

/// Je Datentyp eine Zeile: Name links, Stand rechts. Der Grund steht als kurze zweite Zeile darunter (reine Info-Liste, keine Einstellung).
private struct ProfilHealthTypenView: View {
    let befund: ProfilHealthProbe.Befund?
    /// Nur die Typen der gewählten Bereiche.
    let typen: Set<HealthTyp>
    @Environment(\.palette) private var palette

    var body: some View {
        List {
            ProfilAbschnitt {
                ForEach(HealthTyp.allCases.filter { typen.contains($0) }, id: \.self) { typ in zeile(typ) }
            }
        }
        .profilListe()
        .navigationTitle("Was Lumen Fit liest")
    }

    private func zeile(_ typ: HealthTyp) -> some View {
        LabeledContent {
            if let befund {
                Text(ProfilHealthProbe.text(ProfilHealthProbe.zeile(typ, befund)))
                    .foregroundStyle(palette.text2).lineLimit(1).minimumScaleFactor(0.8)
            } else {
                ProgressView().controlSize(.small)
            }
        } label: {
            Label {
                Text(ProfilHealthProbe.name(typ)).foregroundStyle(palette.text)
                Text(ProfilHealthProbe.grund(typ))
            } icon: {
                Image(systemName: ProfilHealthProbe.symbol(typ))
            }
        }
        .accessibilityElement(children: .combine)
    }
}
