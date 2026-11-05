// Quelle: Lovea server/essen.js (Suche und Barcode, ohne Name-Nachschlag). Lesend auf Loveas Produktdatenbank (Open Food Facts DACH in D1, Bindung ESSEN).
// GET /essen/suche?q=&n= und GET /essen/barcode/<code>, nur mit Konto-Login. Reine Funktion ohne cloudflare:workers-Import -> unter Node testbar.
export function normalisiere(roh) {
  const z = String(roh ?? "").replace(/\D/g, "");
  return z.length === 12 ? "0" + z : z;
}

function produkt(zeile) {
  if (!zeile) return null;
  let pro100 = {};
  try { pro100 = JSON.parse(zeile.pro100); } catch { /* kaputte Zeile: leere Werte statt Absturz */ }
  return {
    code: zeile.code, name: zeile.name, marke: zeile.marke ?? null, menge: zeile.menge ?? null,
    portion_g: zeile.portion_g ?? null, portion_name: zeile.portion_name ?? null, pro100,
  };
}

// FTS5-Anfrage aus freiem Text: nur Buchstaben/Ziffern, jedes Wort als Präfix (keine FTS-Syntax von außen).
export function ftsAnfrage(q) {
  const woerter = String(q ?? "").toLowerCase().match(/[\p{L}\p{N}]+/gu) ?? [];
  return woerter.slice(0, 6).map((w) => `"${w}"*`).join(" ");
}

export async function handleEssen(request, url, env, { kontoPruefen }) {
  const { antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  if (!env.ESSEN) return Response.json({ fehler: "nichtEingerichtet" }, { status: 503 });
  const teile = url.pathname.split("/").filter(Boolean); // ["essen", art, wert?]
  if (teile[1] === "barcode" && teile.length === 3) {
    const code = normalisiere(teile[2]);
    if (code.length < 6 || code.length > 14) return Response.json({ produkt: null }, { status: 404 });
    const zeile = await env.ESSEN.prepare("SELECT * FROM produkt WHERE code = ?").bind(code).first();
    return Response.json({ produkt: produkt(zeile) }, { status: zeile ? 200 : 404, headers: { "Cache-Control": "private, max-age=86400" } });
  }
  if (teile[1] === "suche" && teile.length === 2) {
    const anfrage = ftsAnfrage(url.searchParams.get("q"));
    const nRoh = Number.parseInt(url.searchParams.get("n") ?? "", 10);
    const n = Math.min(Math.max(Number.isFinite(nRoh) ? nRoh : 30, 1), 50);
    if (!anfrage) return Response.json({ treffer: [] });
    const { results } = await env.ESSEN.prepare(
      `SELECT p.* FROM produkt_fts f JOIN produkt p ON p.rowid = f.rowid
       WHERE produkt_fts MATCH ? ORDER BY bm25(produkt_fts) - p.beliebtheit * 0.01 LIMIT ?`).bind(anfrage, n).all();
    return Response.json({ treffer: results.map(produkt) });
  }
  return Response.json({ fehler: "not found" }, { status: 404 });
}
