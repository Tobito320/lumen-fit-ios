// Kontaktformular der Webseite (Support): POST /kontakt ohne Konto, nur aus dem Browser der Webseite (CORS), gedrosselt je IP und insgesamt.
// Gespeichert werden nur Text, die freiwillige Antwort-Adresse und die Zeit; die IP nie im Klartext (nur als Hash im Drossel-Schlüssel, eine Stunde gültig).
// Löschung nach 180 Tagen. Lesen: GET /admin/kontakt mit X-Admin-Key.
const ORIGIN = "https://lumen-fit.pages.dev";
const MAX_BYTES = 8192;
const TEXT_MIN = 10;
const TEXT_MAX = 2000;
const ADRESSE_MAX = 200;
const ADRESSE_FORM = /^[^\s@<>"']{1,100}@[^\s@<>"']{1,99}\.[A-Za-z]{2,}$/;
const JE_IP_STUNDE = 5;
const ALLE_STUNDE = 60;
export const KONTAKT_TAGE = 180;
const STUNDE_MS = 3600_000;

const erlaubterOrigin = (env) => (typeof env.KONTAKT_ORIGIN === "string" && env.KONTAKT_ORIGIN ? env.KONTAKT_ORIGIN : ORIGIN);
const corsKopf = (origin) => ({
  "Access-Control-Allow-Origin": origin, "Access-Control-Allow-Methods": "POST", "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Max-Age": "86400", Vary: "Origin",
});
const antwort = (status, o, origin) => Response.json(o, { status, headers: origin ? corsKopf(origin) : {} });

// Zählt im Fenster der aktuellen Stunde; true, solange die Grenze nicht überschritten ist.
async function drosseln(env, schluessel, grenze) {
  const fenster = Math.floor(Date.now() / STUNDE_MS);
  await env.DB.prepare(
    "INSERT INTO drossel (schluessel, fenster, n) VALUES (?, ?, 1) ON CONFLICT(schluessel) DO UPDATE SET n = CASE WHEN fenster = excluded.fenster THEN n + 1 ELSE 1 END, fenster = excluded.fenster")
    .bind(schluessel, fenster).run();
  return (await env.DB.prepare("SELECT n FROM drossel WHERE schluessel = ?").bind(schluessel).first()).n <= grenze;
}

async function aufraeumen(env) {
  await env.DB.prepare("DELETE FROM kontakt WHERE zeit < ?").bind(new Date(Date.now() - KONTAKT_TAGE * 864e5).toISOString()).run();
  // Abgelaufene IP-Hashes nicht aufheben.
  await env.DB.prepare("DELETE FROM drossel WHERE schluessel LIKE 'kontakt:%' AND fenster < ?").bind(Math.floor(Date.now() / STUNDE_MS)).run();
}

// hilfen: { json, nein, adminOk, sha256 } aus index.js.
export async function kontakt(request, url, env, h) {
  if (url.pathname === "/admin/kontakt") {
    if (request.method !== "GET") return h.nein(404, "not found");
    if (!h.adminOk(request, env)) return h.nein(401, "unauthorized");
    await aufraeumen(env);
    const { results } = await env.DB.prepare("SELECT id, zeit, text, antwort FROM kontakt ORDER BY id DESC LIMIT 200").all();
    return h.json({ nachrichten: results });
  }
  const origin = request.headers.get("Origin");
  const erlaubt = origin === erlaubterOrigin(env) ? origin : null;
  if (request.method === "OPTIONS") return erlaubt ? new Response(null, { status: 204, headers: corsKopf(erlaubt) }) : new Response(null, { status: 403 });
  if (request.method !== "POST") return h.nein(404, "not found");
  if (!erlaubt) return antwort(403, { fehler: "origin" }, null);
  const roh = await request.text();
  if (new TextEncoder().encode(roh).length > MAX_BYTES) return antwort(413, { fehler: "zu groß" }, erlaubt);
  let b = null;
  try { b = JSON.parse(roh); } catch { /* bleibt null */ }
  const text = typeof b?.text === "string" ? b.text.trim() : "";
  const adresse = typeof b?.antwort === "string" ? b.antwort.trim() : "";
  if (text.length < TEXT_MIN || text.length > TEXT_MAX) return antwort(400, { fehler: "text" }, erlaubt);
  if (adresse && (adresse.length > ADRESSE_MAX || !ADRESSE_FORM.test(adresse))) return antwort(400, { fehler: "antwort" }, erlaubt);
  const ip = request.headers.get("CF-Connecting-IP") ?? "";
  const ipHash = (await h.sha256(`kontakt:${ip}`)).slice(0, 32);
  if (!(await drosseln(env, `kontakt:${ipHash}`, JE_IP_STUNDE)) || !(await drosseln(env, "kontakt:alle", ALLE_STUNDE))) {
    return antwort(429, { fehler: "zu viele" }, erlaubt);
  }
  await aufraeumen(env);
  await env.DB.prepare("INSERT INTO kontakt (zeit, text, antwort) VALUES (?, ?, ?)").bind(new Date().toISOString(), text, adresse || null).run();
  return antwort(201, { ok: true }, erlaubt);
}
