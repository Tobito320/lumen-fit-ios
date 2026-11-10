// Crew: Herausforderungen, Reaktionen und Einladungs-Link zwischen verbundenen Konten (Auftrag tasks/auftraege/crew.md, Abschnitt Server).
// Konto-Ids anderer Personen gehen nie hinaus: verbundene Personen erscheinen mit ihrer Verbindungs-Id, andere Teilnehmer einer
// Herausforderung mit einer Teilnehmer-Id (SHA-256 aus Herausforderung und Konto, 16 Hex-Zeichen). Fremde und unbekannte Ids sind nicht zu unterscheiden (404).
import { erlaubteBereiche, tokenNeu, bytesHex, TOKEN_FORM, EINLADUNG_MS, codeNeu, codeHash } from "./verbindungen.js";

const ID_FORM = /^[a-f0-9]{32}$/;
const ARTEN = ["tage", "saetze", "volumen", "rekorde", "uebung"];
const MODI = ["gegen", "gemeinsam"];
const REAKTIONEN = ["respekt", "stark", "anfeuern", "stups"];
const TAG_MS = 86400_000;
const LINK_MS = TAG_MS;
const MAX_LAUFEND = 10;
const MAX_LINKS = 3;
// Gegen Fluten: offene Einladungen je Empfänger, neue Herausforderungen je Ersteller in 24 Stunden, Reaktionen je Paar in 24 Stunden.
const MAX_EINGELADEN = 20;
const MAX_NEU_JE_TAG = 20;
const MAX_REAKTIONEN_JE_TAG = 30;
// Ziele so, wie die App sie baut (CrewLogik.ziel*): sonst wäre der Eindeutig-Index je Art und Ziel wirkungslos.
const ZIEL_FORM = /^(rekord:\d{4}-\d\d-\d\d:.+|(einheit|live|stups):\d{4}-\d\d-\d\d)$/;
// Steuerzeichen, Zeilen- und Absatztrenner und Formatzeichen (Umkehr der Leserichtung) kommen nicht in Texte.
const UNSAUBER = /[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]/u;
const ISO_FORM = /^\d{4}-\d\d-\d\dT[\d:.]{5,12}(Z|[+-]\d\d:\d\d)$/;

const ganz = (x, von, bis) => Number.isInteger(x) && x >= von && x <= bis;
const text = (x, min, max) => typeof x === "string" && x.length >= min && x.length <= max && !UNSAUBER.test(x);
const vor = (ms) => new Date(Date.now() - ms).toISOString();

// Je Konto, Weg und Minute begrenzt (wie in verbindungen.js, nur mit eigener Grenze).
async function drosseln(env, schluessel, grenze) {
  const fenster = Math.floor(Date.now() / 60000);
  await env.DB.prepare(
    "INSERT INTO drossel (schluessel, fenster, n) VALUES (?, ?, 1) ON CONFLICT(schluessel) DO UPDATE SET n = CASE WHEN fenster = excluded.fenster THEN n + 1 ELSE 1 END, fenster = excluded.fenster")
    .bind(schluessel, fenster).run();
  return (await env.DB.prepare("SELECT n FROM drossel WHERE schluessel = ?").bind(schluessel).first()).n <= grenze;
}

const seite = (zeile, id) => (zeile.a === id ? "a" : "b");
const pausiert = (zeile, h) => h.lesen(zeile.a_einst).pause === true || h.lesen(zeile.b_einst).pause === true;

// Eine Verbindung von mir (egal welcher Zustand), mit dem anderen Konto als o_id; null, wenn sie nicht meine ist.
const verbindung = (env, k, id) => env.DB.prepare(
  "SELECT v.*, o.id AS o_id, o.gesperrt AS o_gesperrt FROM verbindungen v JOIN konten o ON o.id = CASE WHEN v.a = ? THEN v.b ELSE v.a END WHERE v.id = ? AND (v.a = ? OR v.b = ?)")
  .bind(k.id, id, k.id, k.id).first();
const nutzbar = (z, h) => !!z && z.status === "aktiv" && !z.o_gesperrt && !pausiert(z, h);

const fragen = (n) => Array(n).fill("?").join(", ");

// Namen: Profilname aus der Zusammenfassung der Person, sonst der Kontoname, höchstens 40 Zeichen. Eine Abfrage je 90 Konten (D1: höchstens 100 Parameter).
async function namenLaden(env, ids) {
  const liste = [...new Set(ids)];
  const namen = new Map();
  for (let i = 0; i < liste.length; i += 90) {
    const teil = liste.slice(i, i + 90);
    const { results } = await env.DB.prepare(
      `SELECT k.id, k.name, CASE WHEN json_valid(p.daten) THEN json_extract(p.daten, '$.profilName') END AS pn FROM konten k LEFT JOIN partner_stand p ON p.konto = k.id WHERE k.id IN (${fragen(teil.length)})`)
      .bind(...teil).all();
    for (const z of results) namen.set(z.id, (typeof z.pn === "string" && z.pn.trim() ? z.pn : z.name).slice(0, 40));
  }
  return (id) => namen.get(id) ?? "";
}

async function uebersicht(k, env, h) {
  const { results: verb } = await env.DB.prepare(
    "SELECT v.*, o.id AS o_id FROM verbindungen v JOIN konten o ON o.id = CASE WHEN v.a = ? THEN v.b ELSE v.a END WHERE (v.a = ? OR v.b = ?) AND v.status = 'aktiv' AND o.gesperrt = 0")
    .bind(k.id, k.id, k.id).all();
  const aktiv = new Map(verb.map((z) => [z.o_id, z]));
  const verbunden = (id) => { const z = aktiv.get(id); return z && !pausiert(z, h) ? z : null; };
  const jetzt = new Date().toISOString();

  const { results: xs } = await env.DB.prepare(
    "SELECT x.*, t.status AS ich FROM herausforderungen x JOIN herausforderung_teilnehmer t ON t.herausforderung = x.id WHERE t.konto = ? AND t.status IN ('eingeladen', 'dabei') AND x.ende > ? ORDER BY x.ende DESC LIMIT 50")
    .bind(k.id, vor(14 * TAG_MS)).all();
  // Teilnehmer aller gezeigten Herausforderungen in einer Abfrage (höchstens 50 Ids).
  const { results: ts } = xs.length ? await env.DB.prepare(
    `SELECT herausforderung, konto, status, wert, aktualisiert FROM herausforderung_teilnehmer WHERE herausforderung IN (${fragen(xs.length)}) AND status IN ('eingeladen', 'dabei') ORDER BY rowid`)
    .bind(...xs.map((x) => x.id)).all() : { results: [] };
  const je = new Map(xs.map((x) => [x.id, []]));
  for (const t of ts) je.get(t.herausforderung).push(t);
  const ichDabei = new Map(xs.map((x) => [x.id, x.ich === "dabei"]));
  // Eingewilligt hat, wer verbunden ist oder wie ich dabei ist. Andere Unverbundene: ohne Namen, Wert und Zeit.
  const offen = (t) => t.konto === k.id || aktiv.has(t.konto) || (ichDabei.get(t.herausforderung) && t.status === "dabei");

  const { results: rs } = await env.DB.prepare("SELECT id, von, art, ziel, text, zeit FROM reaktionen WHERE an = ? AND zeit > ? ORDER BY zeit DESC LIMIT 200")
    .bind(k.id, vor(30 * TAG_MS)).all();
  const sichtbar = rs.filter((r) => verbunden(r.von)).slice(0, 100);
  const name = await namenLaden(env, [...ts.filter(offen).map((t) => t.konto), ...sichtbar.map((r) => r.von)]);

  const herausforderungen = [];
  for (const x of xs) {
    const teilnehmer = [];
    let n = 0;
    for (const t of je.get(x.id)) {
      const z = t.konto === k.id ? null : aktiv.get(t.konto); // die Id bleibt auch in der Pause gleich
      const o = offen(t);
      teilnehmer.push({
        id: z ? z.id : (await h.sha256(`${x.id}:${t.konto}`)).slice(0, 16), verbunden: !!z, ich: t.konto === k.id,
        name: o ? name(t.konto) : t.status === "eingeladen" ? "Eingeladen" : `Teilnehmer ${++n}`,
        status: t.status, wert: o ? t.wert : null, aktualisiert: o ? (t.aktualisiert ?? null) : null,
      });
    }
    herausforderungen.push({
      id: x.id, art: x.art, modus: x.modus, ziel: x.ziel ?? null, uebung: x.uebung ?? null, start: x.start, ende: x.ende,
      status: x.abgebrochen ? "abgebrochen" : x.ende < jetzt ? "beendet" : "laeuft", ersteller: x.ersteller === k.id, ich: x.ich, teilnehmer,
    });
  }

  const reaktionen = sichtbar.map((r) => ({ id: r.id, von: verbunden(r.von).id, name: name(r.von), art: r.art, ziel: r.ziel, text: r.text, zeit: r.zeit }));
  const { results: gs } = await env.DB.prepare("SELECT an, art, ziel FROM reaktionen WHERE von = ? AND zeit > ? ORDER BY zeit DESC LIMIT 300")
    .bind(k.id, vor(30 * TAG_MS)).all();
  const gesendet = gs.filter((g) => aktiv.has(g.an)).map((g) => ({ an: aktiv.get(g.an).id, art: g.art, ziel: g.ziel }));
  return h.json({ herausforderungen, reaktionen, gesendet });
}

async function laufende(env, k) {
  return (await env.DB.prepare(
    "SELECT COUNT(*) AS n FROM herausforderung_teilnehmer t JOIN herausforderungen x ON x.id = t.herausforderung WHERE t.konto = ? AND t.status = 'dabei' AND x.abgebrochen = 0 AND x.ende > ?")
    .bind(k.id, new Date().toISOString()).first()).n;
}

function erstellenPruefen(b, h) {
  if (!h.istObjekt(b)) return { fehler: "Objekt erwartet" };
  if (!ARTEN.includes(b.art)) return { fehler: "art ungültig" };
  if (!MODI.includes(b.modus)) return { fehler: "modus ungültig" };
  const jetzt = Date.now();
  let ende;
  if (b.tage !== undefined && b.ende === undefined) {
    if (!ganz(b.tage, 1, 28)) return { fehler: "tage: 1 bis 28" };
    ende = jetzt + b.tage * TAG_MS;
  } else if (b.ende !== undefined && b.tage === undefined) {
    ende = typeof b.ende === "string" && b.ende.length <= 40 && ISO_FORM.test(b.ende) ? Date.parse(b.ende) : NaN;
    if (!(ende >= jetzt + 3600_000 && ende <= jetzt + 28 * TAG_MS)) return { fehler: "ende: ISO, 1 Stunde bis 28 Tage" };
  } else return { fehler: "entweder tage oder ende" };
  let ziel = null;
  if (b.modus === "gemeinsam") {
    if (!ganz(b.ziel, 1, 10_000_000)) return { fehler: "ziel: 1 bis 10000000" };
    ziel = b.ziel;
  } else if (b.ziel !== undefined && b.ziel !== null) return { fehler: "ziel nur bei gemeinsam" };
  let uebung = null;
  if (b.art === "uebung") {
    if (typeof b.uebung !== "string" || !text(b.uebung.trim(), 1, 40)) return { fehler: "uebung: 1 bis 40 Zeichen" };
    uebung = b.uebung.trim();
  } else if (b.uebung !== undefined && b.uebung !== null) return { fehler: "uebung nur bei art uebung" };
  if (!Array.isArray(b.einladen) || !ganz(b.einladen.length, 1, MAX_LAUFEND - 1) || !b.einladen.every((x) => typeof x === "string" && ID_FORM.test(x)) || new Set(b.einladen).size !== b.einladen.length) {
    return { fehler: "einladen: 1 bis 9 verschiedene Verbindungs-Ids" };
  }
  return { wert: { art: b.art, modus: b.modus, ziel, uebung, ende: new Date(ende).toISOString(), einladen: b.einladen } };
}

async function erstellen(k, request, env, h) {
  if (!(await drosseln(env, `herausforderung:${k.id}`, 10))) return h.nein(429, "zu schnell");
  const r = erstellenPruefen(await h.koerper(request), h);
  if (r.fehler) return h.nein(400, r.fehler);
  const v = r.wert;
  const konten = new Set();
  for (const id of v.einladen) {
    const z = await verbindung(env, k, id);
    if (!nutzbar(z, h)) return h.nein(400, "einladen: nur aktive Verbindungen ohne Pause");
    konten.add(z.o_id);
  }
  if (konten.size !== v.einladen.length) return h.nein(400, "einladen: nur aktive Verbindungen ohne Pause");
  if ((await laufende(env, k)) >= MAX_LAUFEND) return h.nein(429, "zu viele laufende Herausforderungen");
  // Verlassen gibt den Platz frei: darum zählen auch die neuen der letzten 24 Stunden, abgebrochene mit.
  const neu = await env.DB.prepare("SELECT COUNT(*) AS n FROM herausforderungen WHERE ersteller = ? AND erstellt > ?").bind(k.id, vor(TAG_MS)).first();
  if (neu.n >= MAX_NEU_JE_TAG) return h.nein(429, "zu viele neue Herausforderungen heute");
  const t = new Date().toISOString();
  const voll = await env.DB.prepare(
    `SELECT 1 FROM herausforderung_teilnehmer t JOIN herausforderungen x ON x.id = t.herausforderung WHERE t.konto IN (${fragen(konten.size)}) AND t.status = 'eingeladen' AND x.abgebrochen = 0 AND x.ende > ? GROUP BY t.konto HAVING COUNT(*) >= ? LIMIT 1`)
    .bind(...konten, t, MAX_EINGELADEN).first();
  if (voll) return h.nein(429, "eine Person hat zu viele offene Einladungen");
  const id = bytesHex(16);
  // Aufräumen: was seit mehr als 30 Tagen vorbei ist, geht samt Teilnehmern.
  await env.DB.prepare("DELETE FROM herausforderung_teilnehmer WHERE herausforderung IN (SELECT id FROM herausforderungen WHERE ende < ?)").bind(vor(30 * TAG_MS)).run();
  await env.DB.prepare("DELETE FROM herausforderungen WHERE ende < ?").bind(vor(30 * TAG_MS)).run();
  await env.DB.prepare("INSERT INTO herausforderungen (id, ersteller, art, modus, ziel, uebung, start, ende, erstellt) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
    .bind(id, k.id, v.art, v.modus, v.ziel, v.uebung, t, v.ende, t).run();
  await env.DB.prepare("INSERT INTO herausforderung_teilnehmer (herausforderung, konto, status) VALUES (?, ?, 'dabei')").bind(id, k.id).run();
  for (const o of konten) await env.DB.prepare("INSERT INTO herausforderung_teilnehmer (herausforderung, konto, status) VALUES (?, ?, 'eingeladen')").bind(id, o).run();
  return h.json({ id }, 201);
}

async function antworten(k, id, aktion, env, h) {
  if (!(await drosseln(env, `antwort:${k.id}`, 30))) return h.nein(429, "zu schnell");
  const x = await env.DB.prepare(
    "SELECT x.*, t.status AS ich FROM herausforderungen x JOIN herausforderung_teilnehmer t ON t.herausforderung = x.id WHERE x.id = ? AND t.konto = ?").bind(id, k.id).first();
  if (!x) return h.nein(404, "not found");
  const setzen = (status) => env.DB.prepare("UPDATE herausforderung_teilnehmer SET status = ? WHERE herausforderung = ? AND konto = ?").bind(status, id, k.id).run();
  if (aktion === "verlassen") {
    if (x.ich !== "dabei") return h.nein(409, "nicht dabei");
    await setzen("ausgetreten");
    if (x.ersteller === k.id) {
      await env.DB.prepare("UPDATE herausforderungen SET abgebrochen = 1 WHERE id = ?").bind(id).run();
      // Offene Einladungen in eine abgebrochene Herausforderung sind hinfällig und sollen sich bei niemandem stapeln.
      await env.DB.prepare("DELETE FROM herausforderung_teilnehmer WHERE herausforderung = ? AND status = 'eingeladen'").bind(id).run();
    }
    return h.json({ ok: true });
  }
  if (x.ich !== "eingeladen") return h.nein(409, "keine offene Einladung");
  if (aktion === "ablehnen") { await setzen("abgelehnt"); return h.json({ ok: true }); }
  if (x.abgebrochen || x.ende <= new Date().toISOString()) return h.nein(409, "Herausforderung ist vorbei");
  if ((await laufende(env, k)) >= MAX_LAUFEND) return h.nein(429, "zu viele laufende Herausforderungen");
  await setzen("dabei");
  return h.json({ ok: true });
}

async function werteMelden(k, request, env, h) {
  if (!(await drosseln(env, `werte:${k.id}`, 30))) return h.nein(429, "zu schnell");
  const b = await h.koerper(request);
  if (!h.istObjekt(b) || !Array.isArray(b.werte) || b.werte.length > 20
    || !b.werte.every((w) => h.istObjekt(w) && typeof w.id === "string" && ID_FORM.test(w.id) && ganz(w.wert, 0, 1_000_000_000))) return h.nein(400, "werte: bis 20 Einträge {id, wert}");
  const t = new Date().toISOString();
  let gesetzt = 0;
  for (const w of b.werte) {
    // Nur wo ich dabei bin, nicht abgebrochen und höchstens 24 Stunden nach dem Ende; alles andere wird still übergangen.
    const r = await env.DB.prepare(
      "UPDATE herausforderung_teilnehmer SET wert = ?, aktualisiert = ? WHERE herausforderung = ? AND konto = ? AND status = 'dabei' AND EXISTS (SELECT 1 FROM herausforderungen x WHERE x.id = herausforderung_teilnehmer.herausforderung AND x.abgebrochen = 0 AND x.ende >= ?)")
      .bind(w.wert, t, w.id, k.id, vor(TAG_MS)).run();
    gesetzt += r.meta?.changes ?? 0;
  }
  return h.json({ ok: true, gesetzt });
}

// "Heute" kommt von der App (Ortszeit); der Server nimmt das UTC-Datum und das von jetzt + 2 Stunden (Mitteleuropa, UTC+1/+2), damit um Mitternacht nichts hakt.
const stupsTage = () => [0, 2 * 3600_000].map((d) => new Date(Date.now() + d).toISOString().slice(0, 10));

async function reagieren(k, request, env, h) {
  if (!(await drosseln(env, `reaktion:${k.id}`, 30))) return h.nein(429, "zu schnell");
  const b = await h.koerper(request);
  if (!h.istObjekt(b) || typeof b.an !== "string" || !ID_FORM.test(b.an)) return h.nein(400, "an: Verbindungs-Id");
  if (!REAKTIONEN.includes(b.art)) return h.nein(400, "art ungültig");
  if (!text(b.ziel, 1, 80) || !ZIEL_FORM.test(b.ziel)) return h.nein(400, "ziel: rekord:<tag>:<übung>, einheit:<tag>, live:<tag> oder stups:<tag>, bis 80 Zeichen");
  const anzeige = b.text ?? "";
  if (!text(anzeige, 0, 80)) return h.nein(400, "text: bis 80 Zeichen");
  if (b.art === "stups" && !stupsTage().some((tag) => b.ziel === `stups:${tag}`)) return h.nein(400, "stups: ziel stups:<heute>");
  const z = await verbindung(env, k, b.an);
  if (!z || z.status !== "aktiv" || z.o_gesperrt) return h.nein(404, "not found");
  if (!nutzbar(z, h) || !erlaubteBereiche(z, seite(z, k.id), h).includes("gym")) return h.nein(403, "keine Freigabe");
  const heute = await env.DB.prepare("SELECT COUNT(*) AS n FROM reaktionen WHERE von = ? AND an = ? AND zeit > ?").bind(k.id, z.o_id, vor(TAG_MS)).first();
  if (heute.n >= MAX_REAKTIONEN_JE_TAG) return h.nein(429, "zu viele Reaktionen an diese Person heute");
  await env.DB.prepare("DELETE FROM reaktionen WHERE zeit < ?").bind(vor(30 * TAG_MS)).run();
  await env.DB.prepare("INSERT OR IGNORE INTO reaktionen (id, von, an, art, ziel, text, zeit) VALUES (?, ?, ?, ?, ?, ?, ?)")
    .bind(bytesHex(16), k.id, z.o_id, b.art, b.ziel, anzeige, new Date().toISOString()).run();
  return h.json({ ok: true }, 201);
}

async function zuruecknehmen(k, request, env, h) {
  if (!(await drosseln(env, `zuruecknehmen:${k.id}`, 30))) return h.nein(429, "zu schnell");
  const b = await h.koerper(request);
  if (!h.istObjekt(b) || typeof b.an !== "string" || !ID_FORM.test(b.an) || !REAKTIONEN.includes(b.art) || !text(b.ziel, 1, 80)) return h.nein(400, "an, art, ziel erwartet");
  const z = await verbindung(env, k, b.an);
  if (!z) return h.nein(404, "not found");
  await env.DB.prepare("DELETE FROM reaktionen WHERE von = ? AND an = ? AND art = ? AND ziel = ?").bind(k.id, z.o_id, b.art, b.ziel).run();
  return h.json({ ok: true });
}

// Link-Einladung (Build 18) oder mit {"art":"code"} ein Code zum Abtippen (ab Build 19): dieselbe Tabelle wie der QR-Code, nur 24 Stunden gültig.
// Lang = laeuft_ab nach jetzt + 10 Minuten; einladungAnlegen löscht nur den gemerkten vorigen QR-Code. Links und Codes teilen sich die Kappe.
async function linkEinladung(k, request, env, h) {
  if (!(await drosseln(env, `link:${k.id}`, 10))) return h.nein(429, "zu schnell");
  const code = (await h.koerper(request))?.art === "code" ? codeNeu() : null;
  const jetzt = Date.now();
  // Die zwei neuesten offenen Links bleiben, mit dem neuen sind es drei; dazu Abgelaufenes wie beim QR-Code.
  await env.DB.prepare(
    "DELETE FROM einladungen WHERE hash IN (SELECT hash FROM einladungen WHERE konto = ? AND benutzt = 0 AND laeuft_ab > ? ORDER BY laeuft_ab DESC LIMIT -1 OFFSET ?) OR laeuft_ab < ?")
    .bind(k.id, jetzt + EINLADUNG_MS, MAX_LINKS - 1, jetzt - 3600_000).run();
  const token = code ? null : tokenNeu();
  const laeuftAb = jetzt + LINK_MS;
  await env.DB.prepare("INSERT INTO einladungen (hash, konto, laeuft_ab, benutzt) VALUES (?, ?, ?, 0)").bind(code ? await codeHash(code, h) : await h.sha256(token), k.id, laeuftAb).run();
  const zeit = { laeuftAb: new Date(laeuftAb).toISOString(), sekunden: LINK_MS / 1000 };
  return h.json(code ? { code: `${code.slice(0, 4)}-${code.slice(4)}`, ...zeit } : { token, ...zeit }, 201);
}

// Verwaltung, GET /admin/freunde (X-Admin-Key prüft index.js): je Konto nur Zahlen, dazu Verbindungen und Herausforderungen mit Konto-Ids.
// Keine Namen, keine Werte, kein Übungsname, kein Reaktionstext; Namen liefert /admin/konten. ?konto=<id> zeigt nur dieses Konto.
export async function freundeAdmin(url, env, h) {
  const nur = url.searchParams.get("konto");
  if (nur !== null && !h.ID_FORM.test(nur)) return h.nein(400, "konto: Konto-Id");
  const alle = async (sql) => (await env.DB.prepare(sql).all()).results;
  const konten = (await alle("SELECT id FROM konten ORDER BY gesehen DESC")).filter((k) => nur === null || k.id === nur);
  if (!konten.length && nur !== null) return h.nein(404, "unbekannt");
  const verbindungen = await alle("SELECT * FROM verbindungen ORDER BY erstellt");
  const herausforderungen = await alle("SELECT id, ersteller, art, modus, ende, erstellt, abgebrochen FROM herausforderungen ORDER BY ende DESC");
  const teilnehmer = await alle("SELECT herausforderung, konto, status, aktualisiert FROM herausforderung_teilnehmer");
  const reaktionen = await alle("SELECT von, an, zeit FROM reaktionen");
  const einladungen = (await env.DB.prepare("SELECT konto FROM einladungen WHERE benutzt = 0 AND laeuft_ab > ?").bind(Date.now()).all()).results;
  const jetzt = new Date().toISOString();
  const seit = vor(30 * TAG_MS);
  const status = (x) => (x.abgebrochen ? "abgebrochen" : x.ende < jetzt ? "beendet" : "laeuft");
  const laeuft = new Set(herausforderungen.filter((x) => status(x) === "laeuft").map((x) => x.id));
  const offen = verbindungen.filter((v) => v.status === "anfrage" || v.status === "aktiv");
  const zahl = (liste, f) => liste.filter(f).length;
  const mit = (x) => teilnehmer.filter((t) => t.herausforderung === x.id);
  return h.json({
    stand: jetzt,
    konten: konten.map(({ id }) => ({
      konto: id,
      freunde: zahl(offen, (v) => v.status === "aktiv" && (v.a === id || v.b === id)),
      anfragen_raus: zahl(offen, (v) => v.status === "anfrage" && v.a === id),
      anfragen_rein: zahl(offen, (v) => v.status === "anfrage" && v.b === id),
      einladungen_offen: zahl(einladungen, (e) => e.konto === id),
      herausforderungen_laufend: zahl(teilnehmer, (t) => t.konto === id && t.status === "dabei" && laeuft.has(t.herausforderung)),
      herausforderungen_eingeladen: zahl(teilnehmer, (t) => t.konto === id && t.status === "eingeladen" && laeuft.has(t.herausforderung)),
      reaktionen_raus_30t: zahl(reaktionen, (r) => r.von === id && r.zeit >= seit),
      reaktionen_rein_30t: zahl(reaktionen, (r) => r.an === id && r.zeit >= seit),
      // Letzte Änderung mit Beteiligung des Kontos: Verbindung, eigene Herausforderung, eigener Wert, gesendete Reaktion.
      letzte_aktivitaet: [
        ...verbindungen.filter((v) => v.a === id || v.b === id).map((v) => v.geaendert),
        ...herausforderungen.filter((x) => x.ersteller === id).map((x) => x.erstellt),
        ...teilnehmer.filter((t) => t.konto === id).map((t) => t.aktualisiert),
        ...reaktionen.filter((r) => r.von === id).map((r) => r.zeit),
      ].filter(Boolean).sort().at(-1) ?? null,
    })),
    verbindungen: offen.filter((v) => nur === null || v.a === nur || v.b === nur).map((v) => ({
      id: v.id, a: v.a, b: v.b, status: v.status, auto: !!v.auto,
      a_sieht: erlaubteBereiche(v, "a", h), b_sieht: erlaubteBereiche(v, "b", h), erstellt: v.erstellt, geaendert: v.geaendert,
    })),
    herausforderungen: herausforderungen.filter((x) => nur === null || x.ersteller === nur || mit(x).some((t) => t.konto === nur)).map((x) => ({
      id: x.id, art: x.art, modus: x.modus, status: status(x), ende: x.ende, ersteller: x.ersteller,
      teilnehmer: mit(x).map((t) => ({ konto: t.konto, status: t.status })),
    })),
  });
}

export async function freunde(request, url, env, h) {
  const { konto: k, antwort } = await h.kontoPruefen(request, env);
  if (antwort) return antwort;
  const m = request.method;
  const teile = url.pathname.split("/").filter(Boolean).slice(1); // nach "freunde"
  if (!teile.length && m === "GET") return uebersicht(k, env, h);
  if (teile[0] === "herausforderungen") {
    if (teile.length === 1 && m === "POST") return erstellen(k, request, env, h);
    if (teile.length === 3 && m === "POST" && ID_FORM.test(teile[1]) && ["annehmen", "ablehnen", "verlassen"].includes(teile[2])) return antworten(k, teile[1], teile[2], env, h);
  }
  if (teile[0] === "werte" && teile.length === 1 && m === "PUT") return werteMelden(k, request, env, h);
  if (teile[0] === "reaktionen" && teile.length === 1 && m === "POST") return reagieren(k, request, env, h);
  if (teile[0] === "reaktionen" && teile.length === 1 && m === "DELETE") return zuruecknehmen(k, request, env, h);
  if (teile[0] === "einladung" && teile.length === 1 && m === "POST") return linkEinladung(k, request, env, h);
  return h.nein(404, "not found");
}

// Landeseite des Links: ohne Konto und ohne Datenbank. Nur die Token-Form kommt durch (Buchstaben, Ziffern, _ und -), darum ist nichts zu maskieren.
const SEITEN_KOPF = {
  "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "x-robots-tag": "noindex", "referrer-policy": "no-referrer",
  "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'", "x-content-type-options": "nosniff",
};
const htmlSeite = (status, kopf, koerper, extra = "") => new Response(
  `<!doctype html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">${extra}<title>Lumen Fit</title>`
  + `<style>body{font:17px/1.4 -apple-system,system-ui,sans-serif;margin:0;min-height:100vh;display:grid;place-items:center;text-align:center;padding:24px}`
  + `a{display:inline-block;margin-top:16px;padding:14px 24px;border-radius:14px;background:#000;color:#fff;text-decoration:none;font-weight:600}</style></head>`
  + `<body><main><h1>${kopf}</h1>${koerper}</main></body></html>`, { status, headers: SEITEN_KOPF });

// Öffentlicher TestFlight-Link (Variable TESTFLIGHT_LINK der Umgebung, z. B. per `wrangler secret put`): wer die App noch nicht hat, holt sie hier.
// Nur die feste Form von Apple kommt in die Seite.
const TESTFLIGHT_FORM = /^https:\/\/testflight\.apple\.com\/join\/[A-Za-z0-9]{6,12}$/;

export function freundeSeite(url, env = {}) {
  const teile = url.pathname.split("/");
  if (teile.length !== 3 || teile[1] !== "f" || !TOKEN_FORM.test(teile[2])) return htmlSeite(404, "Link ungültig", "<p>Dieser Einladungs-Link passt nicht. Bitte um einen neuen.</p>");
  const ziel = `lumenfit://freund?d=${teile[2]}`;
  const tf = typeof env.TESTFLIGHT_LINK === "string" && TESTFLIGHT_FORM.test(env.TESTFLIGHT_LINK) ? env.TESTFLIGHT_LINK : null;
  const holen = tf ? `<p>Noch keine App?</p><a href="${tf}">Lumen Fit über TestFlight holen</a><p>Danach diesen Link noch einmal öffnen.</p>` : "";
  return htmlSeite(200, "Einladung zu Lumen Fit", `<p>Du wurdest eingeladen, dich zu verbinden.</p><a href="${ziel}">In Lumen Fit öffnen</a>${holen}`, `<meta http-equiv="refresh" content="0;url=${ziel}">`);
}
