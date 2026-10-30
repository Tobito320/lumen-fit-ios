// Quelle: Lovea App/AppErklaerungen.swift (Texte und Regeln der Gym-Hinweise, `Erklaerung`, `ErklaerungPause`)
import SwiftUI
import TipKit

// Kurze Hinweise zu versteckten Funktionen im Gym (Wischen, "..."-Menüs, Tippen auf den Tagesnamen), wie in Lovea mit Apple TipKit.
// Jeder Hinweis kommt genau einmal, höchstens einer pro Stunde. Nach 14 Tagen ohne App-Start kommen sie noch einmal (`GymTippPause`).
// Wann ein Hinweis erscheint, entscheidet die reine Regel `GymTippRegeln`; die Ansichten fragen nur noch.

/// Alle Gym-Hinweise: nach dem ersten Erscheinen nicht wieder, auch ohne Wegtippen.
protocol GymTipErklaerung: Tip {}

extension GymTipErklaerung {
    var options: [any TipOption] { [Tips.MaxDisplayCount(1)] }
}

struct GymTipTrainingBeenden: GymTipErklaerung {
    var title: Text { Text("Training beenden") }
    var message: Text? { Text("Fertige Sätze zählen. Was offen bleibt, steht beim nächsten Mal wieder im Plan.") }
}

struct GymTipTrainingstagWechseln: GymTipErklaerung {
    var title: Text { Text("Anderer Trainingstag") }
    var message: Text? { Text("Tippen wechselt zu einem anderen Trainingstag, solange noch kein Satz fertig ist.") }
}

struct GymTipUebungMehr: GymTipErklaerung {
    var title: Text { Text("Mehr zur Übung") }
    var message: Text? { Text("Aufwärmsätze und Scheibenrechner, Supersatz, Gerät tauschen, auslassen oder entfernen.") }
}

struct GymTipCardioSchnell: GymTipErklaerung {
    var title: Text { Text("Laufband und Stairmaster") }
    var message: Text? { Text("Öffnet ein Cardio-Formular für Zeit und Strecke. Zählt nicht als Satz.") }
}

struct GymTipVolumen: GymTipErklaerung {
    var title: Text { Text("Volumen") }
    var message: Text? { Text("Kilogramm mal Wiederholungen, über alle gezählten Sätze addiert.") }
}

struct GymTipSatzWischen: GymTipErklaerung {
    var title: Text { Text("Satz kopieren oder löschen") }
    var message: Text? { Text("Nach rechts wischen kopiert einen Satz, nach links löscht ihn. Rückgängig geht kurz danach.") }
}

struct GymTipPlanZeile: GymTipErklaerung {
    var title: Text { Text("Übung in der Zeile") }
    var message: Text? { Text("Nach links wischen löscht. Nach rechts wischen doppelt die Übung.") }
}

struct GymTipSplitFuerDich: GymTipErklaerung {
    var title: Text { Text("Für dich") }
    var message: Text? { Text("Zeigt die Splits, die wir für dich empfehlen.") }
}

/// Die Hinweise des Gym-Moduls.
enum GymTippArt: String, CaseIterable, Sendable {
    case trainingBeenden, trainingstagWechseln, uebungMehr, cardioSchnell, volumen, satzWischen, planZeile, splitFuerDich

    var tipp: any Tip {
        switch self {
        case .trainingBeenden: GymTipTrainingBeenden()
        case .trainingstagWechseln: GymTipTrainingstagWechseln()
        case .uebungMehr: GymTipUebungMehr()
        case .cardioSchnell: GymTipCardioSchnell()
        case .volumen: GymTipVolumen()
        case .satzWischen: GymTipSatzWischen()
        case .planZeile: GymTipPlanZeile()
        case .splitFuerDich: GymTipSplitFuerDich()
        }
    }
}

/// Was die Ansicht weiß, wenn sie fragt, ob ein Hinweis kommt.
struct GymTippKontext: Equatable, Sendable {
    var trainingLaeuft = false
    /// Platz der Übungskarte im Training (0 = die oberste).
    var kartenIndex = 0
    var saetze = 0
    var volumen = 0.0
    /// Der Trainingstag lässt sich wechseln (nichts abgehakt, `WorkoutLogik.tagWechselbar`).
    var tagWechselbar = false
    var planUebungen = 0
}

/// Wann ein Hinweis erscheint. Reine Regeln: ein Hinweis, der eine Funktion erklärt, kommt nur dort, wo die Funktion gerade da ist, und die
/// Hinweise, die in jeder Karte stünden, nur in der obersten (sonst ploppt derselbe Hinweis fünfmal auf).
enum GymTippRegeln {
    /// Aus im Test-Host und bei den Demo-Argumenten (Bildschirmfotos ohne Sprechblasen).
    static func aktiv(argumente: [String], imTestHost: Bool) -> Bool {
        !imTestHost && !argumente.contains("-lumenFitDemo")
    }

    static func zeigen(_ art: GymTippArt, _ k: GymTippKontext) -> Bool {
        switch art {
        case .trainingBeenden: return k.trainingLaeuft
        case .trainingstagWechseln: return k.trainingLaeuft && k.tagWechselbar
        case .uebungMehr: return k.trainingLaeuft && k.kartenIndex == 0
        case .cardioSchnell: return !k.trainingLaeuft
        case .volumen: return k.trainingLaeuft && k.volumen > 0
        case .satzWischen: return k.trainingLaeuft && k.kartenIndex == 0 && k.saetze > 0
        case .planZeile: return k.planUebungen > 0
        case .splitFuerDich: return true
        }
    }
}

/// Nach langer Pause kommen die Hinweise noch einmal: TipKit zählt `MaxDisplayCount` für immer, darum leert die App nach 14 Tagen ohne Start den TipKit-Speicher.
enum GymTippPause {
    nonisolated static let tage = 14
    nonisolated static let schluessel = "lumen.gym.tipps.letzterStart"

    /// Wahr, wenn seit dem letzten Start mindestens `tage` Tage vergangen sind. Erster Start: nein.
    static func wiederZeigen(letzterStart: Date?, jetzt: Date) -> Bool {
        guard let letzterStart else { return false }
        return jetzt.timeIntervalSince(letzterStart) >= Double(tage) * 86_400
    }

    /// Vor `Tips.configure` aufrufen (TipKit verlangt das Leeren vor dem Konfigurieren).
    @MainActor
    static func vorKonfiguration(_ defaults: UserDefaults = .standard, jetzt: Date = .now) {
        if wiederZeigen(letzterStart: defaults.object(forKey: schluessel) as? Date, jetzt: jetzt) {
            try? Tips.resetDatastore()
        }
        defaults.set(jetzt, forKey: schluessel)
    }
}

/// Die einmalige TipKit-Konfiguration. Kein Eingriff in `LumenFitApp.init`: `GymModul.start` ruft sie beim App-Start.
@MainActor
enum GymTipps {
    private static var konfiguriert = false

    /// Idempotent. Höchstens ein neuer Hinweis pro Stunde, damit nicht alles auf einmal aufpoppt.
    static func konfiguriere() {
        guard !konfiguriert, GymTippRegeln.aktiv(argumente: ProcessInfo.processInfo.arguments, imTestHost: ModulStart.imTestHost) else { return }
        konfiguriert = true
        GymTippPause.vorKonfiguration()
        try? Tips.configure([.displayFrequency(.hourly)])
    }

    /// Ob die Sprechblasen in dieser Ausführung überhaupt an sind.
    static var an: Bool { GymTippRegeln.aktiv(argumente: ProcessInfo.processInfo.arguments, imTestHost: ModulStart.imTestHost) }
}

extension View {
    /// Sprechblase am Element, nur wenn die Regel es erlaubt (`GymTippRegeln`).
    func gymTipp(_ art: GymTippArt, _ kontext: GymTippKontext) -> some View {
        // Jede Art mit ihrem eigenen Typ und nil, wenn sie nicht gemeint ist: so bleibt die Ansicht dieselbe, wenn die Regel wechselt.
        let an = GymTipps.an && GymTippRegeln.zeigen(art, kontext)
        return self
            .popoverTip(an && art == .trainingBeenden ? GymTipTrainingBeenden() : nil)
            .popoverTip(an && art == .trainingstagWechseln ? GymTipTrainingstagWechseln() : nil)
            .popoverTip(an && art == .uebungMehr ? GymTipUebungMehr() : nil)
            .popoverTip(an && art == .cardioSchnell ? GymTipCardioSchnell() : nil)
            .popoverTip(an && art == .volumen ? GymTipVolumen() : nil)
            .popoverTip(an && art == .planZeile ? GymTipPlanZeile() : nil)
            .popoverTip(an && art == .splitFuerDich ? GymTipSplitFuerDich() : nil)
    }
}

/// Ein Hinweis als Zeile in der Liste, nur wenn die Regel es erlaubt.
struct GymTippZeile: View {
    let art: GymTippArt
    let kontext: GymTippKontext

    var body: some View {
        if GymTipps.an && GymTippRegeln.zeigen(art, kontext) {
            TipView(art.tipp)
        }
    }
}
