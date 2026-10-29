// Lumen-Fit-Server (Cloudflare Worker + D1): Konten, Einstellungen ohne Build, Lovea-Freigabe als Proxy.
// App-Wege: X-App-Key + X-Konto + X-Geheimnis. Verwaltung (/admin/*): nur X-Admin-Key.
// Reine fetch(request, env, holen)-Funktion ohne cloudflare:workers-Import -> unter Node testbar.

const STANDARD = { profilAnlegenErlaubt: false, loveaVerbinden: false, nameAendernTage: 7 };
const PERSONEN = ["ahmed", "annika"];
// shortcut: harte Obergrenze statt Ratenbegrenzung gegen Massen-Registrierung; bei mehr Geräten Grenze anheben oder Cloudflare-Regel davor.
const MAX_KONTEN = 200;
const ID_FORM = /^[A-Za-z0-9_-]{16,64}$/;
const GEHEIM_FORM = /^[A-Za-z0-9_-]{32,128}$/;
const SCHLUESSEL_FORM = /^[A-Za-z][A-Za-z0-9_]{0,40}$/;
const MAX_EINSTELLUNGEN_BYTES = 4000;
const MAX_LIMIT = 200;

const json = (o, status = 200) => Response.json(o, { status });
const nein = (status, fehler) => json({ fehler }, status);
const unauthorized = () => nein(401, "unauthorized");

// Konstante Zeit über die maximale Länge, auch bei unterschiedlicher Länge.
function gleich(a, b) {
  const enc = new TextEncoder();
  const x = enc.encode(a ?? "");
  const y = enc.encode(b ?? "");
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length, 1); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}
async function sha256(text) {
  const b = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, "0")).join("");
}
const appOk = (request, env) => !!env.APP_KEY && gleich(request.headers.get("X-App-Key"), env.APP_KEY);
const adminOk = (request, env) => !!env.ADMIN_KEY && gleich(request.headers.get("X-Admin-Key"), env.ADMIN_KEY);
const lesen = (text) => { try { return JSON.parse(text); } catch { return {}; } };
async function koerper(request) {
  try { return await request.json(); } catch { return null; }
}
const istObjekt = (x) => x !== null && typeof x === "object" && !Array.isArray(x);

// Merge-Patch: null löscht den Schlüssel. Liefert { wert } oder { fehler }.
function flicken(alt, patch, verboten = []) {
  if (!istObjekt(patch)) return { fehler: "Objekt erwartet" };
  const neu = { ...alt };
  for (const [k, v] of Object.entries(patch)) {
    if (!SCHLUESSEL_FORM.test(k)) return { fehler: `Schlüssel ungültig: ${k}` };
    if (verboten.includes(k) && v !== null && v !== false) return { fehler: `${k} gibt es nicht global, nur je Konto` };
    if (v === null) delete neu[k];
    else neu[k] = v;
  }
  if (JSON.stringify(neu).length > MAX_EINSTELLUNGEN_BYTES) return { fehler: "zu groß" };
  return { wert: neu };
}

// Standard < global < Konto. loveaVerbinden zählt nur, wenn das KONTO es gesetzt hat und eine Person hinterlegt ist.
function zusammen(konto, global) {
  const eigen = lesen(konto.einstellungen);
  const cfg = { ...STANDARD, ...global, ...eigen };
  cfg.loveaVerbinden = eigen.loveaVerbinden === true && PERSONEN.includes(konto.lovea_person);
  return cfg;
}
const globaleConfig = async (env) => lesen((await env.DB.prepare("SELECT einstellungen FROM globale_config WHERE id = 1").first())?.einstellungen);

// Meldet das Konto an: Antwort { konto } oder { antwort } (Fehler). Unbekannte ID und falsches Geheimnis sind nicht zu unterscheiden.
async function kontoPruefen(request, env) {
  if (!appOk(request, env)) return { antwort: unauthorized() };
  const id = request.headers.get("X-Konto") ?? "";
  const geheimnis = request.headers.get("X-Geheimnis") ?? "";
  const zeile = ID_FORM.test(id) ? await env.DB.prepare("SELECT * FROM konten WHERE id = ?").bind(id).first() : null;
  const hash = await sha256(geheimnis);
  if (!gleich(hash, zeile?.hash ?? "0".repeat(64)) || !zeile) return { antwort: unauthorized() };
  if (zeile.gesperrt) return { antwort: nein(403, "gesperrt") };
  return { konto: zeile };
}

async function registrieren(request, env) {
  if (!appOk(request, env)) return unauthorized();
  const b = await koerper(request);
  const name = typeof b?.name === "string" ? b.name.trim().slice(0, 40) : "";
  if (!istObjekt(b) || !ID_FORM.test(b.id ?? "") || !GEHEIM_FORM.test(b.geheimnis ?? "") || !name) return nein(400, "ungültig");
  const version = typeof b.version === "string" ? b.version.slice(0, 20) : "";
  const n = await env.DB.prepare("SELECT COUNT(*) AS n FROM konten").first();
  if (n.n >= MAX_KONTEN) return nein(429, "zu viele Konten");
  if (await env.DB.prepare("SELECT 1 AS x FROM konten WHERE id = ?").bind(b.id).first()) return nein(409, "vergeben");
  const jetzt = new Date().toISOString();
  await env.DB.prepare("INSERT INTO konten (id, hash, name, version, erstellt, gesehen) VALUES (?, ?, ?, ?, ?, ?)")
    .bind(b.id, await sha256(b.geheimnis), name, version, jetzt, jetzt).run();
  return json({ ok: true }, 201);
}

async function config(request, env) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  const version = (request.headers.get("X-App-Version") ?? konto.version).slice(0, 20);
  await env.DB.prepare("UPDATE konten SET gesehen = ?, version = ? WHERE id = ?").bind(new Date().toISOString(), version, konto.id).run();
  return json({ config: zusammen(konto, await globaleConfig(env)) });
}

function freigegeben(konto) {
  return lesen(konto.einstellungen).loveaVerbinden === true && PERSONEN.includes(konto.lovea_person);
}

async function loveaFreigabe(request, env) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  return json(freigegeben(konto) ? { erlaubt: true, person: konto.lovea_person } : { erlaubt: false });
}

// Proxy statt Schlüssel: nur GET /agent/ops, Person und Key setzt der Server, die App bekommt den Key nie.
async function loveaOps(request, url, env, holen) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  if (!freigegeben(konto)) return nein(403, "nicht freigegeben");
  if (!env.LOVEA_KEY) return nein(503, "nicht eingerichtet");
  const q = new URLSearchParams({ von: konto.lovea_person });
  for (const k of ["seit", "aufsteigend", "voll"]) if (url.searchParams.has(k)) q.set(k, url.searchParams.get(k));
  if (url.searchParams.has("limit")) q.set("limit", String(Math.min(MAX_LIMIT, Math.max(1, Number(url.searchParams.get("limit")) || 1))));
  let r;
  try {
    r = await holen(`${env.LOVEA_URL ?? "https://lovea.intern"}/agent/ops?${q}`, { headers: { "X-Lovea-Key": env.LOVEA_KEY, "X-Lovea-Person": konto.lovea_person } });
  } catch {
    return nein(502, "lovea");
  }
  if (!r.ok) return nein(502, "lovea");
  return new Response(r.body, { status: 200, headers: { "content-type": "application/json" } });
}

const oeffentlich = (z) => ({
  id: z.id, name: z.name, version: z.version, erstellt: z.erstellt, zuletzt_gesehen: z.gesehen,
  gesperrt: !!z.gesperrt, lovea_person: z.lovea_person, einstellungen: lesen(z.einstellungen),
});

async function verwalten(request, url, env) {
  if (!adminOk(request, env)) return unauthorized();
  const m = request.method;
  if (url.pathname === "/admin/konten" && m === "GET") {
    const { results } = await env.DB.prepare("SELECT * FROM konten ORDER BY gesehen DESC").all();
    return json({ konten: results.map(oeffentlich), global: { ...STANDARD, ...(await globaleConfig(env)) } });
  }
  if (url.pathname === "/admin/config" && m === "PATCH") {
    const r = flicken(await globaleConfig(env), await koerper(request), ["loveaVerbinden"]);
    if (r.fehler) return nein(400, r.fehler);
    await env.DB.prepare("UPDATE globale_config SET einstellungen = ? WHERE id = 1").bind(JSON.stringify(r.wert)).run();
    return json({ global: { ...STANDARD, ...r.wert } });
  }
  const t = url.pathname.match(/^\/admin\/konto\/([A-Za-z0-9_-]+)$/);
  if (t && m === "PATCH") {
    const zeile = await env.DB.prepare("SELECT * FROM konten WHERE id = ?").bind(t[1]).first();
    if (!zeile) return nein(404, "unbekannt");
    const b = await koerper(request);
    if (!istObjekt(b)) return nein(400, "Objekt erwartet");
    let person = zeile.lovea_person;
    if ("lovea_person" in b) {
      if (b.lovea_person !== null && !PERSONEN.includes(b.lovea_person)) return nein(400, "lovea_person: ahmed, annika oder null");
      person = b.lovea_person;
    }
    let gesperrt = zeile.gesperrt;
    if ("gesperrt" in b) {
      if (typeof b.gesperrt !== "boolean") return nein(400, "gesperrt: true oder false");
      gesperrt = b.gesperrt ? 1 : 0;
    }
    let einstellungen = lesen(zeile.einstellungen);
    if ("einstellungen" in b) {
      const r = flicken(einstellungen, b.einstellungen);
      if (r.fehler) return nein(400, r.fehler);
      einstellungen = r.wert;
    }
    if ("loveaVerbinden" in einstellungen && typeof einstellungen.loveaVerbinden !== "boolean") return nein(400, "loveaVerbinden: true oder false");
    if (einstellungen.loveaVerbinden === true && !person) return nein(400, "loveaVerbinden braucht lovea_person");
    await env.DB.prepare("UPDATE konten SET lovea_person = ?, gesperrt = ?, einstellungen = ? WHERE id = ?")
      .bind(person, gesperrt, JSON.stringify(einstellungen), zeile.id).run();
    return json({ konto: oeffentlich(await env.DB.prepare("SELECT * FROM konten WHERE id = ?").bind(zeile.id).first()) });
  }
  return nein(404, "not found");
}

export async function handleFetch(request, env, holen = (u, o) => (env.LOVEA ?? { fetch }).fetch(u, o)) {
  // Worker-zu-Worker über workers.dev ist im selben Konto gesperrt (1042): Lovea kommt über die Dienstbindung LOVEA.
  const url = new URL(request.url);
  const m = request.method;
  if (url.pathname === "/gesundheit" && m === "GET") return json({ ok: true });
  if (url.pathname === "/konto" && m === "POST") return registrieren(request, env);
  if (url.pathname === "/config" && m === "GET") return config(request, env);
  if (url.pathname === "/lovea/freigabe" && m === "GET") return loveaFreigabe(request, env);
  if (url.pathname === "/lovea/agent/ops" && m === "GET") return loveaOps(request, url, env, holen);
  if (url.pathname.startsWith("/admin/")) return verwalten(request, url, env);
  return nein(404, "not found");
}

export default { fetch: (request, env) => handleFetch(request, env) };
