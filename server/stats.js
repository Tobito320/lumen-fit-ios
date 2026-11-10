// Stats (Freunde und Alle, Auftrag stats-auftrag-fitfreunde): Wochenzahlen nur von Konten, die "Freunde sehen mich" oder "Öffentlich in Alle" anhaben.
// Privat (Standard) schickt nichts: die App lädt die öffentliche Liste und rechnet Platz, Prozent und Nachbarn selbst.
// Konto-Ids gehen nie hinaus: Freunde erscheinen mit der Verbindungs-Id, Alle mit einer zufälligen öffentlichen Id. kg je Person sehen nur Freunde,
// in Alle gibt es kg nur als Verteilung je Übung ab 5 Personen. Fehler an die App sind Codes, die App zeigt eigene (übersetzte) Texte.
import { erlaubteBereiche, bytesHex, drosseln } from "./verbindungen.js";
import { namenLaden } from "./freunde.js";
import { spitznamePruefen } from "./spitzname.js";
import { KONTO_LOESCHER } from "./konto-loeschen.js";

const ID_FORM = /^[a-f0-9]{32}$/;
const UEBUNG_FORM = /^[A-Za-z0-9][A-Za-z0-9_-]{0,39}$/;
// Je Woche: Trainings (höchstens eins je Tag zählt, Puffer für Zeitzonen), Sets, neue Rekorde, Serie in Wochen.
const GRENZEN = [["trainings", 14], ["sets", 500], ["rekordeNeu", 100], ["serie", 520]];
const MAX_REKORDE = 30;
const MAX_KG = 1000;
const MAX_JAHR = 10;
const TAG_MS = 86400_000;
// Ab so vielen ungeprüften Meldungen verschiedener Konten ist ein Eintrag für alle ausgeblendet, bis die Verwaltung ihn freigibt.
const AUSBLENDEN_AB = 3;
const MELDEN_JE_TAG = 10;
const BLOCKIEREN_JE_TAG = 30;
// kg-Verteilung je Übung (gesamt und je Trainingsjahr) erst ab so vielen Personen, damit niemand einzeln erkennbar ist.
const MIN_VERTEILUNG = 5;
// shortcut: die ganze öffentliche Liste in einer Antwort (MAX_KONTEN in index.js ist 200); ab einigen tausend Teilnehmern seitenweise nach Platz.
const MAX_ALLE = 5000;
const ICH_PRIVAT = { freunde: false, oeffentlich: false, spitzname: null, ausgeblendet: false };

const ganz = (x, von, bis) => Number.isInteger(x) && x >= von && x <= bis;
const fragen = (n) => Array(n).fill("?").join(", ");
const vor = (ms) => new Date(Date.now() - ms).toISOString();

const BERLIN = new Intl.DateTimeFormat("en-CA", { timeZone: "Europe/Berlin", year: "numeric", month: "2-digit", day: "2-digit" });
function plusTage(tag, n) {
  const d = new Date(`${tag}T12:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}
// Montag der Woche nach Berliner Zeit als YYYY-MM-DD.
export function berlinMontag(ms) {
  const t = Object.fromEntries(BERLIN.formatToParts(new Date(ms)).map((p) => [p.type, p.value]));
  const tag = `${t.year}-${t.month}-${t.day}`;
  return plusTage(tag, -((new Date(`${tag}T12:00:00Z`).getUTCDay() + 6) % 7));
}

// Zahlen, wie sie jetzt gelten: aus der Vorwoche zählt die Woche 0 und die Serie nur, wenn in der Vorwoche trainiert wurde; noch älter alles 0.
function zahlen(z, montag) {
  const aktuell = z.montag >= montag;
  const vorwoche = !aktuell && z.montag >= plusTage(montag, -7);
  const [trainings, sets, neu] = aktuell ? [z.trainings, z.sets, z.rekorde_neu] : [0, 0, 0];
  return { punkte: 10 * trainings + sets + 5 * neu, trainings, sets, serie: aktuell || (vorwoche && z.trainings > 0) ? z.serie : 0 };
}

function rekordePruefen(x, h) {
  if (!h.istObjekt(x)) return null;
  const e = Object.entries(x);
  if (e.length > MAX_REKORDE || !e.every(([u, kg]) => UEBUNG_FORM.test(u) && typeof kg === "number" && kg > 0 && kg <= MAX_KG)) return null;
  return Object.fromEntries(e.map(([u, kg]) => [u, Math.round(kg * 100) / 100]));
}

const zeile = (env, konto) => env.DB.prepare("SELECT * FROM stats WHERE konto = ?").bind(konto).first();
async function ichAus(env, z) {
  if (!z) return ICH_PRIVAT;
  const n = z.oeffentlich ? (await env.DB.prepare("SELECT COUNT(*) AS n FROM stats_meldungen WHERE an = ? AND geprueft = 0").bind(z.konto).first()).n : 0;
  return { freunde: !!z.freunde, oeffentlich: !!z.oeffentlich, spitzname: z.spitzname ?? null, ausgeblendet: n >= AUSBLENDEN_AB };
}

async function setzen(k, request, env, h) {
  if (!(await drosseln(env, `stats:${k.id}`, 10))) return h.nein(429, "zu_schnell");
  const b = await h.koerper(request);
  if (!h.istObjekt(b) || typeof b.freunde !== "boolean" || typeof b.oeffentlich !== "boolean") return h.nein(400, "freunde und oeffentlich: true oder false");
  if (!b.freunde && !b.oeffentlich) {
    await env.DB.prepare("DELETE FROM stats WHERE konto = ?").bind(k.id).run();
    return h.json({ ok: true, ich: ICH_PRIVAT });
  }
  const jetzt = Date.now();
  // Montag der laufenden Woche; ein Tag Spielraum für Geräte in anderen Zeitzonen.
  if (typeof b.montag !== "string" || ![-1, 0, 1].some((d) => berlinMontag(jetzt + d * TAG_MS) === b.montag)) return h.nein(400, "montag: Montag dieser Woche");
  for (const [f, max] of GRENZEN) if (!ganz(b[f], 0, max)) return h.nein(400, `${f}: 0 bis ${max}`);
  const rekorde = rekordePruefen(b.rekorde ?? {}, h);
  if (!rekorde) return h.nein(400, `rekorde: bis ${MAX_REKORDE} Übungen {id: kg}`);
  let spitzname = null;
  let norm = null;
  let jahr = null;
  if (b.oeffentlich) {
    const s = spitznamePruefen(b.spitzname);
    if (!s.ok) return h.nein(422, `spitzname_${s.grund}`);
    if (!ganz(b.jahr, 1, MAX_JAHR)) return h.nein(400, `jahr: 1 bis ${MAX_JAHR}`);
    if (await env.DB.prepare("SELECT 1 AS x FROM stats WHERE spitzname_norm = ? AND konto != ?").bind(s.norm, k.id).first()) return h.nein(409, "spitzname_vergeben");
    ({ name: spitzname, norm } = s);
    jahr = b.jahr;
  }
  const alt = await zeile(env, k.id);
  const t = new Date(jetzt).toISOString();
  const sichtbar = [b.freunde ? 1 : 0, b.oeffentlich ? 1 : 0, spitzname, norm, jahr];
  try {
    if (alt && alt.montag > b.montag) {
      // Älteres Paket (z. B. aus der Warteschlange über Mitternacht): nur die Sichtbarkeit, die neueren Zahlen bleiben.
      await env.DB.prepare("UPDATE stats SET freunde = ?, oeffentlich = ?, spitzname = ?, spitzname_norm = ?, jahr = ?, aktualisiert = ? WHERE konto = ?")
        .bind(...sichtbar, t, k.id).run();
    } else {
      await env.DB.prepare(
        `INSERT INTO stats (konto, id, freunde, oeffentlich, spitzname, spitzname_norm, jahr, montag, trainings, sets, rekorde_neu, serie, rekorde, aktualisiert)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(konto) DO UPDATE SET freunde = excluded.freunde, oeffentlich = excluded.oeffentlich, spitzname = excluded.spitzname,
           spitzname_norm = excluded.spitzname_norm, jahr = excluded.jahr, montag = excluded.montag, trainings = excluded.trainings, sets = excluded.sets,
           rekorde_neu = excluded.rekorde_neu, serie = excluded.serie, rekorde = excluded.rekorde, aktualisiert = excluded.aktualisiert`)
        .bind(k.id, bytesHex(16), ...sichtbar, b.montag, b.trainings, b.sets, b.rekordeNeu, b.serie, JSON.stringify(rekorde), t).run();
    }
  } catch (e) {
    // Zwei gleichzeitig mit demselben Spitznamen: der eindeutige Index entscheidet.
    if (String(e?.message ?? e).includes("UNIQUE")) return h.nein(409, "spitzname_vergeben");
    throw e;
  }
  return h.json({ ok: true, ich: await ichAus(env, await zeile(env, k.id)) });
}

async function uebersicht(k, env, h) {
  if (!(await drosseln(env, `statslesen:${k.id}`, 30))) return h.nein(429, "zu_schnell");
  const montag = berlinMontag(Date.now());

  // Freunde: aktive Verbindungen ohne Pause, die mir Gym zeigen und selbst "Freunde sehen mich" anhaben.
  const { results: verb } = await env.DB.prepare(
    "SELECT v.*, o.id AS o_id FROM verbindungen v JOIN konten o ON o.id = CASE WHEN v.a = ? THEN v.b ELSE v.a END WHERE (v.a = ? OR v.b = ?) AND v.status = 'aktiv' AND o.gesperrt = 0")
    .bind(k.id, k.id, k.id).all();
  const vid = new Map(verb.filter((v) => erlaubteBereiche(v, v.a === k.id ? "a" : "b", h).includes("gym")).map((v) => [v.o_id, v.id]));
  let freunde = [];
  if (vid.size) {
    const { results } = await env.DB.prepare(`SELECT * FROM stats WHERE freunde = 1 AND konto IN (${fragen(vid.size)})`).bind(...vid.keys()).all();
    const name = await namenLaden(env, results.map((z) => z.konto));
    freunde = results.map((z) => ({ id: vid.get(z.konto), name: name(z.konto), ...zahlen(z, montag), rekorde: h.lesen(z.rekorde) })).sort((a, b) => b.punkte - a.punkte);
  }

  // Alle: Öffentliche aus dieser und der Vorwoche, ohne Gesperrte, für alle Ausgeblendete, von mir Gemeldete und Blockierte (beide Richtungen). Mich immer.
  const { results: oeff } = await env.DB.prepare(
    `SELECT s.* FROM stats s JOIN konten k ON k.id = s.konto WHERE s.oeffentlich = 1 AND k.gesperrt = 0 AND (s.konto = ?1 OR (s.montag >= ?2
       AND s.konto NOT IN (SELECT an FROM stats_meldungen WHERE von = ?1)
       AND s.konto NOT IN (SELECT an FROM stats_blockiert WHERE von = ?1)
       AND s.konto NOT IN (SELECT von FROM stats_blockiert WHERE an = ?1)
       AND s.konto NOT IN (SELECT an FROM stats_meldungen WHERE geprueft = 0 GROUP BY an HAVING COUNT(*) >= ?3)))
     ORDER BY CASE WHEN s.montag >= ?4 THEN 10 * s.trainings + s.sets + 5 * s.rekorde_neu ELSE 0 END DESC, s.spitzname LIMIT ?5`)
    .bind(k.id, plusTage(montag, -7), AUSBLENDEN_AB, montag, MAX_ALLE).all();
  const alle = oeff.map((z) => ({ id: z.id, name: z.spitzname, jahr: z.jahr, ...zahlen(z, montag), ich: z.konto === k.id }));

  // kg nur als Verteilung je Übung, gesamt und je Trainingsjahr, ab MIN_VERTEILUNG Personen; ohne mich, Gesperrte und für alle Ausgeblendete.
  const { results: rek } = await env.DB.prepare(
    `SELECT s.jahr, s.rekorde FROM stats s JOIN konten k ON k.id = s.konto WHERE s.oeffentlich = 1 AND k.gesperrt = 0 AND s.konto != ?1
       AND s.konto NOT IN (SELECT an FROM stats_meldungen WHERE geprueft = 0 GROUP BY an HAVING COUNT(*) >= ?2)`)
    .bind(k.id, AUSBLENDEN_AB).all();
  const je = new Map();
  for (const z of rek) {
    for (const [u, kg] of Object.entries(h.lesen(z.rekorde))) {
      for (const gruppe of ["alle", String(z.jahr)]) {
        const schluessel = `${u}\n${gruppe}`;
        if (!je.has(schluessel)) je.set(schluessel, new Map());
        je.get(schluessel).set(kg, (je.get(schluessel).get(kg) ?? 0) + 1);
      }
    }
  }
  // Maps statt Objekte: eine Übung "constructor" darf nichts an Object.prototype hängen.
  const rekorde = new Map();
  for (const [schluessel, werte] of je) {
    if ([...werte.values()].reduce((a, n) => a + n, 0) < MIN_VERTEILUNG) continue;
    const [u, gruppe] = schluessel.split("\n");
    if (!rekorde.has(u)) rekorde.set(u, new Map());
    rekorde.get(u).set(gruppe, [...werte].sort((a, b) => a[0] - b[0]));
  }
  return h.json({ montag, ich: await ichAus(env, await zeile(env, k.id)), freunde, alle, rekorde: Object.fromEntries([...rekorde].map(([u, g]) => [u, Object.fromEntries(g)])) });
}

// Melden und Blockieren gehen nur auf Einträge in Alle. Melden blendet für mich sofort aus, Blockieren in beide Richtungen.
async function markieren(k, request, env, h, tabelle, grenze) {
  if (!(await drosseln(env, `${tabelle}:${k.id}`, 10))) return h.nein(429, "zu_schnell");
  const b = await h.koerper(request);
  if (!h.istObjekt(b) || typeof b.id !== "string" || !ID_FORM.test(b.id)) return h.nein(400, "id: Eintrag aus Alle");
  const z = await env.DB.prepare("SELECT konto FROM stats WHERE id = ? AND oeffentlich = 1").bind(b.id).first();
  if (!z) return h.nein(404, "not found");
  if (z.konto === k.id) return h.nein(400, "nicht dich selbst");
  const n = (await env.DB.prepare(`SELECT COUNT(*) AS n FROM ${tabelle} WHERE von = ? AND zeit > ?`).bind(k.id, vor(TAG_MS)).first()).n;
  if (n >= grenze) return h.nein(429, "tageslimit");
  await env.DB.prepare(`INSERT OR IGNORE INTO ${tabelle} (von, an, zeit) VALUES (?, ?, ?)`).bind(k.id, z.konto, new Date().toISOString()).run();
  return h.json({ ok: true });
}

export async function stats(request, url, env, h) {
  const { konto: k, antwort } = await h.kontoPruefen(request, env);
  if (antwort) return antwort;
  const m = request.method;
  const weg = url.pathname.slice("/stats".length);
  if (weg === "" && m === "GET") return uebersicht(k, env, h);
  if (weg === "" && m === "PUT") return setzen(k, request, env, h);
  if (weg === "/melden" && m === "POST") return markieren(k, request, env, h, "stats_meldungen", MELDEN_JE_TAG);
  if (weg === "/blockieren" && m === "POST") return markieren(k, request, env, h, "stats_blockiert", BLOCKIEREN_JE_TAG);
  return h.nein(404, "not found");
}

// Verwaltung (X-Admin-Key prüft index.js): Teilnehmer und Meldungen mit Konto-Ids; Freigabe setzt die Meldungen auf geprüft.
// Für die Melder bleibt die Person ausgeblendet, nur die Zählung für alle beginnt neu.
export async function statsAdmin(request, url, env, h) {
  if (url.pathname === "/admin/stats" && request.method === "GET") {
    const { results: zeilen } = await env.DB.prepare("SELECT konto, id, freunde, oeffentlich, spitzname, jahr, montag, aktualisiert FROM stats ORDER BY aktualisiert DESC").all();
    const { results: meldungen } = await env.DB.prepare("SELECT von, an, zeit, geprueft FROM stats_meldungen ORDER BY zeit DESC").all();
    const offen = (konto) => meldungen.filter((m) => m.an === konto && !m.geprueft).length;
    return h.json({
      stand: new Date().toISOString(),
      teilnehmer: zeilen.map((z) => ({ ...z, freunde: !!z.freunde, oeffentlich: !!z.oeffentlich, meldungen: offen(z.konto), ausgeblendet: offen(z.konto) >= AUSBLENDEN_AB })),
      meldungen: meldungen.map((m) => ({ ...m, geprueft: !!m.geprueft })),
      blockiert: (await env.DB.prepare("SELECT COUNT(*) AS n FROM stats_blockiert").first()).n,
    });
  }
  const t = url.pathname.match(/^\/admin\/stats\/([A-Za-z0-9_-]{16,64})$/);
  if (t && request.method === "PATCH") {
    const b = await h.koerper(request);
    if (!h.istObjekt(b) || b.freigeben !== true) return h.nein(400, "freigeben: true");
    if (!(await zeile(env, t[1]))) return h.nein(404, "unbekannt");
    const r = await env.DB.prepare("UPDATE stats_meldungen SET geprueft = 1 WHERE an = ? AND geprueft = 0").bind(t[1]).run();
    return h.json({ ok: true, geprueft: r.meta?.changes ?? 0 });
  }
  return h.nein(404, "not found");
}

// Konto löschen (DELETE /konto, Stufe 7): Zeile, Meldungen und Blockaden in beide Richtungen, Drossel-Einträge dieser Wege.
export async function statsKontoLoeschen(env, konto) {
  await env.DB.prepare("DELETE FROM stats WHERE konto = ?1").bind(konto).run();
  await env.DB.prepare("DELETE FROM stats_meldungen WHERE von = ?1 OR an = ?1").bind(konto).run();
  await env.DB.prepare("DELETE FROM stats_blockiert WHERE von = ?1 OR an = ?1").bind(konto).run();
  await env.DB.prepare("DELETE FROM drossel WHERE schluessel IN ('stats:' || ?1, 'statslesen:' || ?1, 'stats_meldungen:' || ?1, 'stats_blockiert:' || ?1)").bind(konto).run();
}

KONTO_LOESCHER.push(statsKontoLoeschen);
