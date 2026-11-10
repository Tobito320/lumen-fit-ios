// Quelle: Lovea Health/Einstellung/hinweise.json (als Swift-Liste eingebettet; die Studio-Tipps mit Studio-Namen sind weggelassen)
import Foundation

/// Kuratierte Kurz-Anleitung zu einer Geräteübung. `unsicher` = ohne Beleg, die Karte sagt dann "selbst prüfen".
struct EinstellHinweis: Equatable, Sendable {
    /// Alle Wörter müssen im normalisierten Übungsnamen vorkommen (`UebungsKatalog.normal`).
    let muster: [String]
    /// Kommt eines dieser Wörter im Namen vor, passt der Eintrag nicht.
    var ohne: [String] = []
    let anleitung: String
    let einstellung: String
    let fehler: String
    let unsicher: Bool
}

enum EinstellHinweise {
    /// Erster passender Eintrag; die Reihenfolge geht von speziell zu allgemein. Unbekannte Übung: nil.
    static func finden(name: String, in liste: [EinstellHinweis] = alle) -> EinstellHinweis? {
        let n = UebungsKatalog.normal(name)
        return liste.first { h in
            h.muster.allSatisfy { n.contains(UebungsKatalog.normal($0)) }
                && !h.ohne.contains { n.contains(UebungsKatalog.normal($0)) }
        }
    }

    static func finden(_ u: PlanUebung, in liste: [EinstellHinweis] = alle) -> EinstellHinweis? {
        finden(name: u.katalog?.name ?? u.anzeigeName, in: liste)
    }

    static let alle: [EinstellHinweis] = [
        EinstellHinweis(
            muster: ["schragbankdrucken", "maschine"],
            anleitung: String(localized: "Sitz so einstellen, dass die Griffe auf Höhe der oberen Brust starten. Schulterblätter an die Lehne, Füße fest am Boden. Drücken, oben nicht ganz durchstrecken."),
            einstellung: String(localized: "Sitzhöhe: Griffe beim Start knapp unter Schulterhöhe. Genaue Stufen sind je Gerät verschieden, einmal ausprobieren und unten speichern."),
            fehler: String(localized: "Sitz zu tief: Schultern rollen nach vorn und die Schulter übernimmt."),
            unsicher: true),
        EinstellHinweis(
            muster: ["schragbankdrucken"],
            anleitung: String(localized: "Schulterblätter zusammen und runter, Rücken leicht im Hohlkreuz, Füße fest am Boden. Stange oder Hanteln zur oberen Brust senken, Ellbogen etwa 45 bis 60 Grad vom Körper, dann hochdrücken."),
            einstellung: String(localized: "Lehne 15 bis 30 Grad. Ab etwa 45 Grad übernimmt die Schulter, die Brust arbeitet weniger. Neigung prüfen: iPhone-App Maßband, Reiter Wasserwaage, Handy flach auf die Lehne legen."),
            fehler: String(localized: "Lehne zu steil gestellt. Ellbogen 90 Grad zur Seite. Hintern hebt ab."),
            unsicher: false),
        EinstellHinweis(
            muster: ["bankdrucken"],
            anleitung: String(localized: "Schulterblätter zusammen und runter, Füße fest am Boden. Stange zur unteren Brust senken, Ellbogen etwa 45 bis 60 Grad vom Körper, dann hochdrücken."),
            einstellung: String(localized: "Flache Bank. Augen etwa unter der Stange, damit sie sicher in die Ablage geht."),
            fehler: String(localized: "Ellbogen weit nach außen. Hintern hebt ab. Stange springt von der Brust."),
            unsicher: false),
        EinstellHinweis(
            muster: ["brustpresse"],
            anleitung: String(localized: "Rücken fest an die Lehne, Schulterblätter zusammen. Griffe auf Brusthöhe nach vorn drücken, langsam zurückführen, Schultern bleiben unten."),
            einstellung: String(localized: "Sitzhöhe: Griffe auf Höhe der mittleren Brust. Genaue Stufen sind je Gerät verschieden, unten speichern."),
            fehler: String(localized: "Sitz zu hoch: Schultern ziehen hoch. Rücken löst sich von der Lehne."),
            unsicher: true),
        EinstellHinweis(
            muster: ["schulterdrucken", "maschine"],
            anleitung: String(localized: "Rücken an die Lehne, Griffe auf Schulterhöhe greifen, nach oben drücken, Nacken lang lassen, langsam zurück."),
            einstellung: String(localized: "Sitzhöhe: Griffe beim Start etwa auf Schulterhöhe. Stufen sind je Gerät verschieden, unten speichern."),
            fehler: String(localized: "Hohlkreuz. Schultern zu den Ohren. Ruckartig nach oben."),
            unsicher: true),
        EinstellHinweis(
            muster: ["latzug"],
            anleitung: String(localized: "Oberschenkel unter die Polster, Stange etwas weiter als schulterbreit greifen. Brust raus, zur oberen Brust ziehen, Ellbogen nach unten, langsam zurück."),
            einstellung: String(localized: "Polster so, dass die Oberschenkel fest sitzen und du nicht hochgezogen wirst. Gewicht nur so hoch, dass der Oberkörper still bleibt."),
            fehler: String(localized: "Mit viel Schwung nach hinten lehnen. Stange hinter den Nacken ziehen. Arme statt Rücken ziehen."),
            unsicher: false),
        EinstellHinweis(
            muster: ["rudern"],
            ohne: ["aufrechtes"],
            anleitung: String(localized: "Brust an das Polster oder gerader Rücken, Schulterblätter zusammen ziehen, Ellbogen nah am Körper nach hinten, kurz halten, langsam zurück."),
            einstellung: String(localized: "Sitz und Brustpolster so, dass die Arme am Start fast gestreckt sind und das Polster die Brust nur leicht berührt. Stufen je Gerät verschieden, unten speichern."),
            fehler: String(localized: "Mit dem Oberkörper schwingen. Schultern zu den Ohren. Rundrücken."),
            unsicher: true),
        EinstellHinweis(
            muster: ["beinpresse"],
            anleitung: String(localized: "Rücken und Hintern flach an die Lehne, Füße schulterbreit auf die Platte. Knie in Richtung Zehen beugen, kontrolliert zurückdrücken, Knie nicht ganz durchstrecken."),
            einstellung: String(localized: "Lehne so, dass die Knie unten etwa 90 Grad haben und der Hintern nicht abhebt. Sicherheitsstopper einstellen."),
            fehler: String(localized: "Hintern hebt unten ab, Becken rollt ein. Knie fallen nach innen. Knie hart durchgestreckt."),
            unsicher: false),
        EinstellHinweis(
            muster: ["beinstrecker"],
            anleitung: String(localized: "Rücken an die Lehne, Knie in Höhe der Gelenkachse. Beine strecken, oben kurz halten, langsam zurück."),
            einstellung: String(localized: "Achse des Geräts auf Höhe des Knies. Unteres Polster knapp über den Knöcheln. Stufen je Gerät verschieden, unten speichern."),
            fehler: String(localized: "Mit Schwung hochschleudern. Hintern hebt vom Sitz ab."),
            unsicher: true),
        EinstellHinweis(
            muster: ["beinbeuger"],
            anleitung: String(localized: "Knie in Höhe der Gelenkachse, Polster oberhalb der Ferse. Beine beugen, kurz halten, langsam zurück."),
            einstellung: String(localized: "Achse des Geräts auf Höhe des Knies. Stufen je Gerät verschieden, unten speichern."),
            fehler: String(localized: "Becken hebt ab. Zu viel Schwung."),
            unsicher: true),
        EinstellHinweis(
            muster: ["wadenheben"],
            ohne: ["donkey"],
            anleitung: String(localized: "Fußballen auf die Kante, Ferse tief sinken lassen, hoch auf die Zehenspitzen drücken, oben kurz halten."),
            einstellung: String(localized: "Polster so, dass die Beine fast gestreckt sind. Stufen je Gerät verschieden, unten speichern."),
            fehler: String(localized: "Zu kleiner Weg. Wippen mit Schwung."),
            unsicher: true),
    ]
}
