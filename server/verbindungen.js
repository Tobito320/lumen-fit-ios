// Verbindungen zwischen Konten (QR-Einladung) und die zwei Lovea-Konten (von selbst verbunden). Jede Auskunft über ein anderes Konto
// läuft über eine Zeile in `verbindungen` mit Status "aktiv"; der Server filtert die Daten je Verbindung und Bereich, bevor er sie ausliefert.
//
// Zeile: a fragt an (hat gescannt), b besitzt den Code. Einstellungen je Seite (a_einst, b_einst):
//   zeigt: Bereiche, die diese Seite der anderen zeigt (fehlt: nur Schritte und Gym)
//   ausblenden: Bereiche, die diese Seite von der anderen nicht sehen will
//   pause: nichts senden und nichts empfangen, bis es wieder aus ist
//   mitteilungen: Ereignisse der anderen Seite ankommen lassen (Standard an)
//   favorit, name: nur für die Anzeige dieser Seite
const EINLADUNG_MS = 10 * 60 * 1000;
const TOKEN_FORM = /^[A-Za-z0-9_-]{43}$/;
const ID_FORM = /^[a-f0-9]{32}$/;
const STANDARD_ZEIGT = ["schritte", "gym"];
const ALLE_ZEIGT = ["schritte", "gym", "schlaf", "essen", "plan", "verlauf", "tagebuch", "koerper", "stimmung", "gewohnheiten"];
// Ältere App-Builds schicken noch "zyklus" in zeigt/ausblenden: wird ohne Fehler verworfen, nie gespeichert und nie ausgegeben.
const ALT_BEREICH = "zyklus";
const MAX_AKTIV = 50;
const MAX_ANFRAGEN = 10;
// Abruf gedrosselt: je Konto höchstens so viele Einladungs-Wege (anlegen, ansehen, anfragen) je Minute.
const DROSSEL_JE_MINUTE = 10;

const bytesHex = (n) => [...crypto.getRandomValues(new Uint8Array(n))].map((x) => x.toString(16).padStart(2, "0")).join("");
function tokenNeu() {
  const b = crypto.getRandomValues(new Uint8Array(32)); // 256 Bit
  return btoa(String.fromCharCode(...b)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function drosseln(env, schluessel) {
  const fenster = Math.floor(Date.now() / 60000);
  await env.DB.prepare(
    "INSERT INTO drossel (schluessel, fenster, n) VALUES (?, ?, 1) ON CONFLICT(schluessel) DO UPDATE SET n = CASE WHEN fenster = excluded.fenster THEN n + 1 ELSE 1 END, fenster = excluded.fenster")
    .bind(schluessel, fenster).run();
  const z = await env.DB.prepare("SELECT n FROM drossel WHERE schluessel = ?").bind(schluessel).first();
  return z.n <= DROSSEL_JE_MINUTE;
}

const paar = (env, x, y) => env.DB.prepare("SELECT * FROM verbindungen WHERE (a = ? AND b = ?) OR (a = ? AND b = ?)").bind(x, y, y, x).first();
const konto = (env, id) => env.DB.prepare("SELECT * FROM konten WHERE id = ?").bind(id).first();
const jetztText = () => new Date().toISOString();

function seiteVon(zeile, id) { return zeile.a === id ? "a" : "b"; }
const andereSeite = (s) => (s === "a" ? "b" : "a");

function einstellung(zeile, seite, h) {
  const e = h.lesen(zeile[`${seite}_einst`]);
  const liste = (x) => (Array.isArray(x) ? [...new Set(x.filter((b) => ALLE_ZEIGT.includes(b)))] : null);
  return {
    zeigt: liste(e.zeigt) ?? STANDARD_ZEIGT,
    ausblenden: liste(e.ausblenden) ?? [],
    pause: e.pause === true,
    mitteilungen: e.mitteilungen !== false,
    favorit: e.favorit === true,
    name: typeof e.name === "string" ? e.name.slice(0, 24) : "",
  };
}

// Was der Leser (Seite) vom Besitzer (andere Seite) sehen darf. Leer bei Pause, Anfrage, Entfernung.
export function erlaubteBereiche(zeile, leser, h) {
  if (zeile.status !== "aktiv") return [];
  const ich = einstellung(zeile, leser, h);
  const sie = einstellung(zeile, andereSeite(leser), h);
  if (ich.pause || sie.pause) return [];
  return sie.zeigt.filter((b) => !ich.ausblenden.includes(b));
}

async function datenFuer(env, besitzerId, erlaubt, mitteilungen, h) {
  const z = await env.DB.prepare("SELECT daten, aktualisiert FROM partner_stand WHERE konto = ?").bind(besitzerId).first();
  if (!z) return null;
  const daten = h.filtern(h.lesen(z.daten), erlaubt, mitteilungen);
  return daten ? { daten, aktualisiert: z.aktualisiert } : null;
}

// Die zwei Lovea-Konten: Verbindung ohne Scan, beide Richtungen, alle Bereiche an.
// Wer sie entfernt hat, bekommt sie nicht neu: es bleibt eine Zeile "entfernt" zwischen den zwei Personen; per QR geht sie wieder.
export async function autoVerbinden(env, k, h) {
  if (!h.freigegeben(k)) return;
  const { results } = await env.DB.prepare("SELECT * FROM konten WHERE lovea_person = ? AND gesperrt = 0 ORDER BY gesehen DESC").bind(h.andere(k.lovea_person)).all();
  const sie = results.find((x) => h.freigegeben(x));
  if (!sie || (await paar(env, k.id, sie.id))) return;
  const weg = await env.DB.prepare(
    "SELECT 1 AS x FROM verbindungen v JOIN konten x ON x.id = v.a JOIN konten y ON y.id = v.b WHERE v.status = 'entfernt' AND x.lovea_person IN ('ahmed', 'annika') AND y.lovea_person IN ('ahmed', 'annika') AND x.lovea_person != y.lovea_person LIMIT 1").first();
  if (weg) return;
  const alles = JSON.stringify({ zeigt: ALLE_ZEIGT });
  const t = jetztText();
  await env.DB.prepare("INSERT INTO verbindungen (id, a, b, status, auto, a_einst, b_einst, erstellt, geaendert) VALUES (?, ?, ?, 'aktiv', 1, ?, ?, ?, ?)")
    .bind(bytesHex(16), k.id, sie.id, alles, alles, t, t).run();
}

// Alter Weg `GET /partner`: die Verbindung zur anderen Lovea-Person.
export async function partnerFuerLovea(env, k, h) {
  const { results } = await env.DB.prepare(
    "SELECT v.*, o.id AS o_id FROM verbindungen v JOIN konten o ON o.id = CASE WHEN v.a = ? THEN v.b ELSE v.a END WHERE (v.a = ? OR v.b = ?) AND v.status = 'aktiv' AND o.gesperrt = 0 AND o.lovea_person = ? ORDER BY o.gesehen DESC")
    .bind(k.id, k.id, k.id, h.andere(k.lovea_person)).all();
  for (const zeile of results) {
    const seite = seiteVon(zeile, k.id);
    const e = einstellung(zeile, seite, { lesen: h.lesen });
    // Alte App-Versionen kennen Stimmung und Gewohnheiten nicht: dieser alte Weg bleibt bei den früheren Bereichen.
    const erlaubt = erlaubteBereiche(zeile, seite, { lesen: h.lesen }).filter((b) => b !== "stimmung" && b !== "gewohnheiten");
    const r = await datenFuer(env, zeile.o_id, erlaubt, e.mitteilungen, h);
    if (r) return { partner: r.daten, aktualisiert: r.aktualisiert };
  }
  return null;
}

// Eintrag für die App. Status: aktiv | anfrageEingehend (ich besitze den Code) | anfrageAusgehend (ich habe gescannt).
async function eintrag(env, zeile, k, andereKonto, h) {
  const seite = seiteVon(zeile, k.id);
  const ich = einstellung(zeile, seite, h);
  const e = {
    id: zeile.id, name: andereKonto.name, auto: zeile.auto === 1, erstellt: zeile.erstellt,
    // Die zwei Lovea-Konten: die App legt diese Person in den bisherigen Partner-Platz (Heute, Schlaf, Ansichten).
    lovea: !!(k.lovea_person && andereKonto.lovea_person && k.lovea_person !== andereKonto.lovea_person),
    status: zeile.status === "aktiv" ? "aktiv" : seite === "b" ? "anfrageEingehend" : "anfrageAusgehend",
  };
  if (zeile.status !== "aktiv") return e;
  const erlaubt = erlaubteBereiche(zeile, seite, h);
  const r = await datenFuer(env, andereKonto.id, erlaubt, ich.mitteilungen, h);
  if (r?.daten.profilName) e.name = r.daten.profilName;
  return {
    ...e, ich, siehst: erlaubt, pausiert: ich.pause, zuletzt: r?.aktualisiert ?? null, daten: r?.daten ?? null,
  };
}

async function liste(env, k, h) {
  await autoVerbinden(env, k, h);
  const { results } = await env.DB.prepare("SELECT * FROM verbindungen WHERE (a = ? OR b = ?) AND status IN ('anfrage', 'aktiv') ORDER BY erstellt").bind(k.id, k.id).all();
  const eintraege = [];
  const lovea = new Map(); // je Lovea-Person nur die Verbindung zum zuletzt gesehenen Gerät (eine Neuinstallation lässt alte Zeilen zurück)
  for (const zeile of results) {
    const o = await konto(env, zeile.a === k.id ? zeile.b : zeile.a);
    if (!o || o.gesperrt) continue;
    if (zeile.auto === 1 && o.lovea_person) {
      const alt = lovea.get(o.lovea_person);
      if (alt && alt.gesehen >= o.gesehen) continue;
      lovea.set(o.lovea_person, { gesehen: o.gesehen, zeile });
    }
    eintraege.push({ zeile, o });
  }
  const ausgewaehlt = eintraege.filter(({ zeile, o }) => zeile.auto !== 1 || !o.lovea_person || lovea.get(o.lovea_person).zeile === zeile);
  const ergebnis = [];
  for (const { zeile, o } of ausgewaehlt) ergebnis.push(await eintrag(env, zeile, k, o, h));
  ergebnis.sort((x, y) => (y.ich?.favorit === true) - (x.ich?.favorit === true) || x.name.localeCompare(y.name));
  return ergebnis;
}

// Token prüfen: Besitzer, wenn gültig (vorhanden, nicht benutzt, nicht abgelaufen, Besitzer nicht gesperrt), sonst null. Immer dieselbe Antwort für alle Fehlerfälle.
async function einladungPruefen(env, token, h) {
  if (typeof token !== "string" || !TOKEN_FORM.test(token)) return null;
  const hash = await h.sha256(token);
  const z = await env.DB.prepare("SELECT * FROM einladungen WHERE hash = ? AND benutzt = 0 AND laeuft_ab > ?").bind(hash, Date.now()).first();
  if (!z) return null;
  const besitzer = await konto(env, z.konto);
  return besitzer && !besitzer.gesperrt ? { hash, besitzer } : null;
}

const UNGUELTIG = (h) => h.nein(404, "Einladung ungültig oder abgelaufen");

async function einladungAnlegen(k, env, h) {
  if (!(await drosseln(env, `einladung:${k.id}`))) return h.nein(429, "zu schnell");
  await env.DB.prepare("DELETE FROM einladungen WHERE konto = ? OR laeuft_ab < ?").bind(k.id, Date.now() - 3600_000).run();
  const token = tokenNeu();
  const laeuftAb = Date.now() + EINLADUNG_MS;
  await env.DB.prepare("INSERT INTO einladungen (hash, konto, laeuft_ab, benutzt) VALUES (?, ?, ?, 0)").bind(await h.sha256(token), k.id, laeuftAb).run();
  return h.json({ token, laeuftAb: new Date(laeuftAb).toISOString(), sekunden: EINLADUNG_MS / 1000 }, 201);
}

async function ansehen(k, request, env, h) {
  if (!(await drosseln(env, `scan:${k.id}`))) return h.nein(429, "zu schnell");
  const b = await h.koerper(request);
  const e = await einladungPruefen(env, b?.token, h);
  if (!e) return UNGUELTIG(h);
  if (e.besitzer.id === k.id) return h.nein(400, "Das ist dein eigener Code");
  const alt = await paar(env, k.id, e.besitzer.id);
  if (alt && alt.status !== "entfernt") return h.nein(409, "Ihr seid schon verbunden");
  return h.json({ name: e.besitzer.name, laeuftAb: new Date((await env.DB.prepare("SELECT laeuft_ab FROM einladungen WHERE hash = ?").bind(e.hash).first()).laeuft_ab).toISOString() });
}

async function anfragen(k, request, env, h) {
  if (!(await drosseln(env, `scan:${k.id}`))) return h.nein(429, "zu schnell");
  const b = await h.koerper(request);
  const e = await einladungPruefen(env, b?.token, h);
  if (!e) return UNGUELTIG(h);
  if (e.besitzer.id === k.id) return h.nein(400, "Das ist dein eigener Code");
  const alt = await paar(env, k.id, e.besitzer.id);
  if (alt && alt.status !== "entfernt") return h.nein(409, "Ihr seid schon verbunden");
  const offen = await env.DB.prepare("SELECT COUNT(*) AS n FROM verbindungen WHERE b = ? AND status = 'anfrage'").bind(e.besitzer.id).first();
  if (offen.n >= MAX_ANFRAGEN) return h.nein(429, "zu viele offene Anfragen");
  // Einmal nutzbar: nur wer die Zeile jetzt auf benutzt setzt, gewinnt.
  const r = await env.DB.prepare("UPDATE einladungen SET benutzt = 1 WHERE hash = ? AND benutzt = 0 AND laeuft_ab > ?").bind(e.hash, Date.now()).run();
  if ((r.meta?.changes ?? 0) !== 1) return UNGUELTIG(h);
  const t = jetztText();
  let id;
  if (alt) { // früher entfernt: dieselbe Zeile, frisch und mit Standard-Einstellungen
    id = alt.id;
    await env.DB.prepare("UPDATE verbindungen SET a = ?, b = ?, status = 'anfrage', auto = 0, a_einst = '{}', b_einst = '{}', geaendert = ? WHERE id = ?").bind(k.id, e.besitzer.id, t, id).run();
  } else {
    id = bytesHex(16);
    await env.DB.prepare("INSERT INTO verbindungen (id, a, b, status, auto, a_einst, b_einst, erstellt, geaendert) VALUES (?, ?, ?, 'anfrage', 0, '{}', '{}', ?, ?)").bind(id, k.id, e.besitzer.id, t, t).run();
  }
  return h.json({ id, name: e.besitzer.name }, 201);
}

const BOOL = ["pause", "mitteilungen", "favorit"];
function aendernPruefen(b, h) {
  if (!h.istObjekt(b)) return { fehler: "Objekt erwartet" };
  const aus = {};
  for (const [feld, wert] of Object.entries(b)) {
    if (feld === "zeigt" || feld === "ausblenden") {
      const liste = Array.isArray(wert) ? wert.filter((x) => x !== ALT_BEREICH) : wert;
      if (!Array.isArray(liste) || liste.length > ALLE_ZEIGT.length || liste.some((x) => !ALLE_ZEIGT.includes(x))) return { fehler: `${feld}: Liste bekannter Bereiche` };
      aus[feld] = [...new Set(liste)];
    } else if (BOOL.includes(feld)) {
      if (typeof wert !== "boolean") return { fehler: `${feld}: true oder false` };
      aus[feld] = wert;
    } else if (feld === "name") {
      if (typeof wert !== "string") return { fehler: "name: Text" };
      aus.name = [...wert.replace(/\p{Cc}/gu, "").trim()].slice(0, 24).join("");
    } else return { fehler: `unbekannt: ${feld}` };
  }
  return { wert: aus };
}

export async function verbindungen(request, url, env, h) {
  const { konto: k, antwort } = await h.kontoPruefen(request, env);
  if (antwort) return antwort;
  const m = request.method;
  const teile = url.pathname.split("/").filter(Boolean).slice(1); // nach "verbindungen"
  if (!teile.length && m === "GET") {
    const eintraege = await liste(env, k, h);
    // Was die App hochladen darf: die Bereiche, die mindestens eine aktive, nicht pausierte Verbindung von dir zeigt. Ohne Verbindung: nichts.
    const teilen = ALLE_ZEIGT.filter((b) => eintraege.some((e) => e.status === "aktiv" && !e.ich.pause && e.ich.zeigt.includes(b)));
    return h.json({ verbindungen: eintraege, teilen });
  }
  if (teile[0] === "einladung" && teile.length === 1 && m === "POST") return einladungAnlegen(k, env, h);
  if (teile[0] === "ansehen" && teile.length === 1 && m === "POST") return ansehen(k, request, env, h);
  if (teile[0] === "anfrage" && teile.length === 1 && m === "POST") return anfragen(k, request, env, h);
  if (!ID_FORM.test(teile[0] ?? "") || teile.length > 2) return h.nein(404, "not found");
  // Fremde und unbekannte Ids sind nicht zu unterscheiden.
  const zeile = await env.DB.prepare("SELECT * FROM verbindungen WHERE id = ? AND (a = ? OR b = ?) AND status != 'entfernt'").bind(teile[0], k.id, k.id).first();
  if (!zeile) return h.nein(404, "not found");
  const seite = seiteVon(zeile, k.id);
  const t = jetztText();
  const aktion = teile[1];
  if (aktion === "annehmen" && m === "POST") {
    if (zeile.status !== "anfrage" || seite !== "b") return h.nein(409, "keine offene Anfrage an dich");
    const aktiv = await env.DB.prepare("SELECT COUNT(*) AS n FROM verbindungen WHERE (a = ? OR b = ?) AND status = 'aktiv'").bind(k.id, k.id).first();
    if (aktiv.n >= MAX_AKTIV) return h.nein(429, "zu viele Verbindungen");
    await env.DB.prepare("UPDATE verbindungen SET status = 'aktiv', a_einst = '{}', b_einst = '{}', geaendert = ? WHERE id = ?").bind(t, zeile.id).run();
    return h.json({ ok: true });
  }
  if (aktion === "ablehnen" && m === "POST") {
    if (zeile.status !== "anfrage" || seite !== "b") return h.nein(409, "keine offene Anfrage an dich");
    await env.DB.prepare("DELETE FROM verbindungen WHERE id = ?").bind(zeile.id).run();
    return h.json({ ok: true });
  }
  if (!aktion && m === "PATCH") {
    if (zeile.status !== "aktiv") return h.nein(409, "nicht verbunden");
    const r = aendernPruefen(await h.koerper(request), h);
    if (r.fehler) return h.nein(400, r.fehler);
    const neu = { ...h.lesen(zeile[`${seite}_einst`]), ...r.wert };
    await env.DB.prepare(`UPDATE verbindungen SET ${seite}_einst = ?, geaendert = ? WHERE id = ?`).bind(JSON.stringify(neu), t, zeile.id).run();
    const frisch = await env.DB.prepare("SELECT * FROM verbindungen WHERE id = ?").bind(zeile.id).first();
    return h.json({ verbindung: await eintrag(env, frisch, k, await konto(env, zeile.a === k.id ? zeile.b : zeile.a), h) });
  }
  if (!aktion && m === "DELETE") {
    // Sofort auf beiden Seiten weg. Eine Anfrage verschwindet ganz; eine Verbindung bleibt als Zeile "entfernt" (damit die Lovea-Verbindung nicht von selbst wiederkommt).
    if (zeile.status === "anfrage") await env.DB.prepare("DELETE FROM verbindungen WHERE id = ?").bind(zeile.id).run();
    else {
      await env.DB.prepare("UPDATE verbindungen SET status = 'entfernt', a_einst = '{}', b_einst = '{}', geaendert = ? WHERE id = ?").bind(t, zeile.id).run();
      // Wer keine aktive Verbindung mehr hat, hinterlässt auch keine Zusammenfassung auf dem Server.
      for (const id of [zeile.a, zeile.b]) {
        await env.DB.prepare("DELETE FROM partner_stand WHERE konto = ? AND NOT EXISTS (SELECT 1 FROM verbindungen WHERE (a = ? OR b = ?) AND status = 'aktiv')").bind(id, id, id).run();
      }
    }
    return h.json({ ok: true });
  }
  return h.nein(404, "not found");
}
