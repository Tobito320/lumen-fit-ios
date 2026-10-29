#if DEBUG
import SwiftUI

/// Start-Argument `-lumenFitLumi YES`: Lumi in allen Stimmungen und einigen Stufen, damit CI-Bilder das Aussehen zeigen. Nur Debug.
struct LumiProbe: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Abstand.l) {
                ForEach(LumiStimmung.allCases, id: \.self) { stimmung in
                    HStack(spacing: Abstand.l) {
                        LumiView(stimmung: stimmung, groesse: 96)
                        Text(stimmung.beschreibung).font(.headline).foregroundStyle(palette.text)
                    }
                }
                HStack(spacing: Abstand.m) {
                    ForEach([1, 3, 6, 9], id: \.self) { stufe in
                        VStack {
                            LumiView(stimmung: .bereit, groesse: 64, stufe: stufe)
                            Text("Stufe \(stufe)").font(.caption).foregroundStyle(palette.text2)
                        }
                    }
                }
            }
            .padding(Abstand.l)
        }
        .background(palette.grund)
    }
}
#endif
