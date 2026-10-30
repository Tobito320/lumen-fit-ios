// Quelle: Lovea Health/Heute/FreitextKI.swift
import Foundation
#if canImport(FoundationModels)
import FoundationModels

@Generable
struct FreitextKIAntwort {
    @Guide(description: "Uhrzeit, zu der die Person schlafen gegangen ist, als HH:mm im 24-Stunden-Format. Leer, wenn nicht erwähnt.")
    var bett: String?
    @Guide(description: "Uhrzeit, zu der die Person aufgewacht oder aufgestanden ist, als HH:mm im 24-Stunden-Format. Leer, wenn nicht erwähnt.")
    var auf: String?
    @Guide(description: "Körpergewicht in Kilogramm. Leer, wenn nicht erwähnt.")
    var gewichtKg: Double?
    @Guide(description: "Getrunkenes Wasser in Millilitern, ein Glas sind 250. Kein Kaffee. Leer, wenn nicht erwähnt.")
    var wasserMl: Int?
    @Guide(description: "Eingenommenes Creatin in Gramm. Nur 'Creatin genommen' ohne Menge bedeutet 3.5. Leer, wenn nicht erwähnt.")
    var creatinGramm: Double?
}
#endif

/// Apples Sprachmodell auf dem Gerät (Apple Intelligence, deutsche Sprache). Sonst leer. Nichts verlässt das iPhone; die Server-Erkennung aus Lovea gibt es nicht.
enum FreitextKI {
    static func lesen(_ text: String, tag: String) async -> [FreitextEintrag] {
        #if canImport(FoundationModels)
        let modell = SystemLanguageModel.default
        guard case .available = modell.availability, modell.supportsLocale(Locale(identifier: "de_DE")) else { return [] }
        let session = LanguageModelSession(instructions: "Du liest kurze deutsche Tagebuch-Notizen, oft mit Tippfehlern, und trägst nur ein, was wirklich drinsteht. Nichts erfinden.")
        guard let a = try? await session.respond(to: text, generating: FreitextKIAntwort.self).content else { return [] }
        var ergebnis: [FreitextEintrag] = []
        if let b = a.bett.flatMap({ FreitextLogik.uhrzeiten(" \($0) ").first }), let u = a.auf.flatMap({ FreitextLogik.uhrzeiten(" \($0) ").first }),
           let s = FreitextLogik.schlafDaten(bett: b, auf: u, tag: tag) { ergebnis.append(s) }
        if let kg = a.gewichtKg, kg >= 20, kg < 400 { ergebnis.append(.gewicht(zehntel: Int((kg * 10).rounded()))) }
        if let ml = a.wasserMl, ml > 0, ml <= 8000 { ergebnis.append(.wasser(glaeser: max(1, Int((Double(ml) / FreitextLogik.glasMl).rounded())))) }
        if let g = a.creatinGramm, g > 0, g <= 30 { ergebnis.append(.creatin(klicks: max(1, Int((g / Habit.creatinGramm).rounded())))) }
        return ergebnis
        #else
        return []
        #endif
    }
}
