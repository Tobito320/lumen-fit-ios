import Foundation
import Observation

/// Liest die vom Lovea-Import abgelegten Ops (`schritte.setzen`, `schlaf.setzen`, `schlaf.zeiten`, `stimmung.setzen`) und hält ihren gefalteten Stand.
/// `GesundheitsStand` führt `stand` mit Health und Band zusammen; die Stimmung schreibt und liest dieser Store selbst.
@MainActor @Observable
final class ImportVerlaufStore {
    @ObservationIgnored private let raum: LokalerRaum
    private(set) var stand = ImportVerlaufStand()

    init(raum: LokalerRaum) {
        self.raum = raum
        stand = raum.falten(ImportVerlaufLogik.arten, ImportVerlaufStand(), live: { [weak self] op in
            guard let self else { return }
            ImportVerlaufLogik.nimmAuf(op, in: &self.stand)
        }) { ImportVerlaufLogik.nimmAuf($1, in: &$0) }
    }

    func stimmung(_ tag: String) -> ImportStimmung? { stand.stimmung[tag] }

    /// Setzt die Stimmung des Tages; "Brauche" und Satz des Tages bleiben (Teil-Op wie in Lovea).
    func setzeStimmung(_ stufe: StimmungStufe, tag: String) {
        raum.senden("stimmung.setzen", StimmungSetzenD(datum: tag, stimmung: stufe.rawValue))
    }
}
