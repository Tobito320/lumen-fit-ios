import Foundation

/// Die Foto-Mahlzeit per KI im Modul essen: je Profil ein Auftrags-Store (Ordner `essen-ki` im Profilordner), je App ein Freigabe-Prüfer.
/// Der Server setzt `kiFotoErlaubt` für alle auf true (ein Konto-Schalter `false` sperrt); der Knopf hängt nur daran und an einem aktiven Profil, nicht an Coach oder Lovea. Das Limit hält der Server (429 `tageslimit`).
enum EssenKiModul {
    nonisolated static let ordnerName = "essen-ki"

    @MainActor private static var storeAblage: (umgebung: ObjectIdentifier, profil: ProfilID, store: EssenKiAuftragStore)?
    @MainActor private static var freigabeAblage: (umgebung: ObjectIdentifier, freigabe: EssenKiFreigabe)?

    @MainActor private static func zugang(_ umgebung: AppUmgebung) -> EssenKiKontoZugang {
        EssenKiKontoZugang(zugang: KontoZugang.lade(), schluesselbund: umgebung.schluesselbund, version: KontoDienst.appVersion)
    }

    /// Der Store des aktiven Profils; nil ohne Profil.
    @MainActor static func store(_ umgebung: AppUmgebung) -> EssenKiAuftragStore? {
        guard let profil = umgebung.profil.aktiv?.id else { return nil }
        let kennung = ObjectIdentifier(umgebung)
        if let vorhanden = storeAblage, vorhanden.umgebung == kennung, vorhanden.profil == profil { return vorhanden.store }
        let ordner = umgebung.profilOrdner(profil).appendingPathComponent(ordnerName, isDirectory: true)
        let neu = EssenKiAuftragStore(ordner: ordner, sender: EssenKiClient(zugang: zugang(umgebung), lader: umgebung.http),
                                      hintergrund: EssenKiSystemHintergrund())
        storeAblage = (kennung, profil, neu)
        return neu
    }

    @MainActor static func freigabe(_ umgebung: AppUmgebung) -> EssenKiFreigabe {
        let kennung = ObjectIdentifier(umgebung)
        if let vorhanden = freigabeAblage, vorhanden.umgebung == kennung { return vorhanden.freigabe }
        let neu = EssenKiFreigabe(zugang: zugang(umgebung), lader: umgebung.http, uhr: umgebung.uhr)
        freigabeAblage = (kennung, neu)
        return neu
    }
}
