#if DEBUG
import Foundation

/// Start-Argumente für CI-Bilder und Demo (nur Debug; Vertrag mit `ios-ci.yml`, SPEC 5.9 Vertrag 6):
/// `-lumenFitDemo YES`, `-lumenFitTab <heute|gym|essen|schlaf>`, `-lumenFitTheme <schlicht|monochrom|graphit|stahl|glut|wald>`,
/// `-lumenFitLumi YES` (Ansicht aller Stimmungen), `-lumenFitRoute <lumenfit://-Link>`, `-lumenFitFixtures <Ordner>`,
/// `-lumenFitScroll unten` (lange Seiten wie das Profil-Blatt starten am unteren Ende, für das zweite CI-Bild),
/// `-lumenFitTraining YES` (checkt in den ersten Plantag ein, für das Bild vom laufenden Training).
struct StartArgumente: Equatable {
    var demo = false
    var tab: LumenFitTab?
    var thema: ThemaID?
    var lumi = false
    var route: String?
    var fixtures: URL?
    var scrollUnten = false
    var training = false

    static func lies(_ defaults: UserDefaults = .standard) -> StartArgumente {
        var a = StartArgumente()
        a.demo = defaults.string(forKey: "lumenFitDemo") == "YES"
        a.tab = defaults.string(forKey: "lumenFitTab").flatMap { LumenFitTab(rawValue: $0) }
        a.thema = defaults.string(forKey: "lumenFitTheme").flatMap { ThemaID(rawValue: $0) }
        a.lumi = defaults.string(forKey: "lumenFitLumi") == "YES"
        a.route = defaults.string(forKey: "lumenFitRoute")
        a.fixtures = defaults.string(forKey: "lumenFitFixtures").map { URL(fileURLWithPath: $0, isDirectory: true) }
        a.scrollUnten = defaults.string(forKey: "lumenFitScroll") == "unten"
        a.training = defaults.string(forKey: "lumenFitTraining") == "YES"
        return a
    }
}
#endif
