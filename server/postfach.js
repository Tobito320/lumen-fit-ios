// Postfach für Agenten: ein Agent legt über /admin/postfach eine Op für ein Konto ab, die App holt sie (GET /postfach), spielt sie lokal ein
// und quittiert (POST /postfach/quittung). Dazu meldet die App ihren Gym-Plan (PUT /postfach/plan), nur wenn das Konto planMelden gesetzt hat.
// Nur Arten aus ERLAUBT kommen an; die App führt sie über denselben Weg aus wie eigene Änderungen (gym.plan -> TrainingStore.planSichern).
const MAX_OFFEN = 20;
const MAX_BYTES = 60000;
const ist = (x) => x !== null && typeof x === "object" && !Array.isArray(x);
const reihe = (x, max) => Array.isArray(x) && x.length <= max;

// Gerade genug Form, damit die App den Plan sicher lesen kann (Swift `TrainingsPlan`): tage mit id, name, wochentage, uebungen mit id, uebung, saetze.
function planPruefen(p) {
  if (!ist(p) || !reihe(p.tage, 14) || !p.tage.length) return "plan.tage: 1 bis 14 Tage";
  for (const t of p.tage) {
    if (!ist(t) || typeof t.id !== "string" || typeof t.name !== "string" || !reihe(t.wochentage, 7) || !t.wochentage.every((w) => Number.isInteger(w) && w >= 1 && w <= 7) || !reihe(t.uebungen, 40)) return "Tag ungültig";
    for (const u of t.uebungen) {
      if (!ist(u) || typeof u.id !== "string" || typeof u.uebung !== "string" || !reihe(u.saetze, 30)) return "Übung ungültig";
      if (!u.saetze.every((s) => ist(s) && Number.isInteger(s.wdh) && typeof s.failure === "boolean")) return "Satz ungültig";
    }
    // Die App legt Übungen nach id ab: zwei gleiche in einem Tag ließen eine verschwinden.
    if (new Set(t.uebungen.map((u) => u.id)).size !== t.uebungen.length) return "Übungs-id doppelt";
  }
  return null;
}

export const ERLAUBT = { "gym.plan": planPruefen };

export async function postfachApp(request, url, env, { kontoPruefen, json, nein, koerper, lesen }) {
  const { konto, antwort } = await kontoPruefen(request, env);
  if (antwort) return antwort;
  const planMelden = lesen(konto.einstellungen).planMelden === true;
  const m = request.method;
  if (url.pathname === "/postfach" && m === "GET") {
    const { results } = await env.DB.prepare("SELECT id, art, daten FROM agent_postfach WHERE konto = ? AND abgeholt IS NULL ORDER BY id LIMIT ?").bind(konto.id, MAX_OFFEN).all();
    return json({ ops: results.map((z) => ({ id: z.id, art: z.art, daten: lesen(z.daten) })), planMelden });
  }
  if (url.pathname === "/postfach/quittung" && m === "POST") {
    const b = await koerper(request);
    if (!ist(b) || !reihe(b.ids, MAX_OFFEN) || !b.ids.every(Number.isInteger)) return nein(400, "ids ungültig");
    for (const id of b.ids) await env.DB.prepare("UPDATE agent_postfach SET abgeholt = ? WHERE konto = ? AND id = ? AND abgeholt IS NULL").bind(new Date().toISOString(), konto.id, id).run();
    return json({ ok: true });
  }
  if (url.pathname === "/postfach/plan" && m === "PUT") {
    if (!planMelden) return nein(403, "planMelden aus");
    const text = JSON.stringify((await koerper(request))?.plan ?? null);
    if (text.length > MAX_BYTES || planPruefen(lesen(text))) return nein(400, "plan ungültig");
    await env.DB.prepare("INSERT OR REPLACE INTO konto_merker (konto, schluessel, wert) VALUES (?, 'plan_aktuell', ?)").bind(konto.id, JSON.stringify({ zeit: new Date().toISOString(), plan: lesen(text) })).run();
    return json({ ok: true });
  }
  return nein(404, "not found");
}

// Nur nach Admin-Prüfung in index.js gerufen.
export async function postfachAdmin(request, url, env, { json, nein, koerper, lesen, ID_FORM }) {
  if (url.pathname === "/admin/postfach" && request.method === "POST") {
    const b = await koerper(request);
    if (!ist(b) || !ID_FORM.test(b.konto ?? "")) return nein(400, "konto ungültig");
    const pruefe = Object.hasOwn(ERLAUBT, b.art) ? ERLAUBT[b.art] : null;
    if (!pruefe) return nein(400, `art nicht erlaubt (erlaubt: ${Object.keys(ERLAUBT).join(", ")})`);
    const text = JSON.stringify(b.daten ?? null);
    if (text.length > MAX_BYTES) return nein(400, "zu groß");
    const fehler = pruefe(lesen(text));
    if (fehler) return nein(400, fehler);
    if (!(await env.DB.prepare("SELECT 1 AS x FROM konten WHERE id = ?").bind(b.konto).first())) return nein(404, "unbekannt");
    const offen = await env.DB.prepare("SELECT COUNT(*) AS n FROM agent_postfach WHERE konto = ? AND abgeholt IS NULL").bind(b.konto).first();
    if (offen.n >= MAX_OFFEN) return nein(429, "zu viele offene Einträge");
    await env.DB.prepare("INSERT INTO agent_postfach (konto, art, daten, erstellt) VALUES (?, ?, ?, ?)").bind(b.konto, b.art, text, new Date().toISOString()).run();
    return json({ ok: true, offen: offen.n + 1 }, 201);
  }
  if (url.pathname === "/admin/postfach/plan" && request.method === "GET") {
    const id = url.searchParams.get("konto") ?? "";
    if (!ID_FORM.test(id)) return nein(400, "konto ungültig");
    const z = await env.DB.prepare("SELECT wert FROM konto_merker WHERE konto = ? AND schluessel = 'plan_aktuell'").bind(id).first();
    return json({ konto: id, stand: z ? lesen(z.wert) : null });
  }
  return null;
}
