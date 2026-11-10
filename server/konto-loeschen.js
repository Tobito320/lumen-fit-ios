// Konto löschen (App Store 5.1.1(v)): DELETE /konto mit den Konto-Kopfzeilen löscht alle Zeilen dieses Kontos. Die Zeile in `konten` geht zuletzt,
// damit ein Abbruch mittendrin wiederholbar bleibt (die Kopfzeilen gelten bis dahin). Danach ist das Konto unbekannt (401), die App legt ein neues an.
// Andere Dateien hängen ihre Tabellen mit `KONTO_LOESCHER.push(async (env, konto) => ...)` an (z. B. stats.js mit `statsKontoLoeschen`).
export const KONTO_LOESCHER = [];

// Platzhalter für den Ersteller einer Herausforderung, deren Ersteller sein Konto gelöscht hat (die Spalte ist NOT NULL).
export const GELOESCHT = "geloescht";

const SCHRITTE = [
  "DELETE FROM konto_merker WHERE konto = ?1",
  "DELETE FROM nutzung WHERE konto = ?1",
  "DELETE FROM nutzung_mehr WHERE konto = ?1",
  "DELETE FROM partner_stand WHERE konto = ?1",
  "DELETE FROM ki_nutzung WHERE konto = ?1",
  "DELETE FROM verbindungen WHERE a = ?1 OR b = ?1",
  "DELETE FROM einladungen WHERE konto = ?1",
  // Drossel-Schlüssel haben die Form <weg>:<konto>; genau vergleichen statt LIKE (Kennungen enthalten _).
  "DELETE FROM drossel WHERE substr(schluessel, instr(schluessel, ':') + 1) = ?1",
  "DELETE FROM schlaf_belege WHERE konto = ?1",
  "DELETE FROM agent_postfach WHERE konto = ?1",
  "DELETE FROM reaktionen WHERE von = ?1 OR an = ?1",
  // Eigene Herausforderungen enden wie beim Verlassen durch den Ersteller: abgebrochen, offene Einladungen weg, die Kennung ersetzt.
  "UPDATE herausforderungen SET abgebrochen = 1, ersteller = '" + GELOESCHT + "' WHERE ersteller = ?1",
  "DELETE FROM herausforderung_teilnehmer WHERE konto = ?1 OR (status = 'eingeladen' AND herausforderung IN (SELECT id FROM herausforderungen WHERE ersteller = '" + GELOESCHT + "'))",
  "DELETE FROM herausforderungen WHERE ersteller = '" + GELOESCHT + "' AND id NOT IN (SELECT herausforderung FROM herausforderung_teilnehmer)",
];

// hilfen: { kontoPruefen, json } aus index.js. Gesperrte Konten bekommen 403 wie überall (sonst ginge die Sperre per Löschen und Neuanlage verloren).
export async function kontoLoeschen(request, env, hilfen) {
  const { konto, antwort } = await hilfen.kontoPruefen(request, env);
  if (antwort) return antwort;
  for (const loescher of KONTO_LOESCHER) await loescher(env, konto.id);
  for (const sql of SCHRITTE) {
    const st = env.DB.prepare(sql);
    await (sql.includes("?1") ? st.bind(konto.id) : st).run();
  }
  await env.DB.prepare("DELETE FROM konten WHERE id = ?1").bind(konto.id).run();
  return hilfen.json({ ok: true });
}
