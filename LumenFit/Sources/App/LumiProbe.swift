#if DEBUG
import SwiftUI

/// Start-Argument `-lumenFitLumi YES`: Lumi in allen 14 Zuständen auf Hell und Dunkel, klein (24 pt) und in einigen Stufen, damit CI-Bilder das
/// Aussehen zeigen (Vergleich mit dem Lumi-Set im Vault). Nur Debug.
struct LumiProbe: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.m) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Abstand.s)], spacing: Abstand.s) {
                    ForEach(LumiStimmung.allCases, id: \.self) { stimmung in
                        VStack(spacing: 4) {
                            HStack(spacing: 0) {
                                feld(stimmung, schema: .dark)
                                feld(stimmung, schema: .light)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            Text(stimmung.titel).font(.caption2).foregroundStyle(palette.text).lineLimit(1)
                        }
                    }
                }
                HStack(spacing: 6) {
                    ForEach(LumiStimmung.allCases, id: \.self) { LumiView(stimmung: $0, groesse: 24) }
                }
                HStack(spacing: Abstand.m) {
                    ForEach([1, 3, 6, 9], id: \.self) { stufe in
                        VStack {
                            LumiView(stimmung: .bereit, groesse: 56, stufe: stufe)
                            Text("Stufe \(stufe)").font(.caption).foregroundStyle(palette.text2)
                        }
                    }
                }
            }
            .padding(Abstand.m)
        }
        .background(palette.grund)
    }

    private func feld(_ stimmung: LumiStimmung, schema: ColorScheme) -> some View {
        LumiView(stimmung: stimmung, groesse: 50)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(schema == .dark ? Color.black : Color(white: 0.95))
            .environment(\.colorScheme, schema)
    }
}
#endif
