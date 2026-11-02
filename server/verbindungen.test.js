import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { fakeD1 } from "./fake-d1.js";
import { handleFetch } from "./index.js";

const SCHEMA = readFileSync(new URL("./schema.sql", import.meta.url), "utf8");
const APP = "app-key-test";
const ADMIN = "admin-key-test";
const KONTEN = {
  ich: { id: "a".repeat(32), geheimnis: "g".repeat(48), name: "Ich" },
  du: { id: "b".repeat(32), geheimnis: "h".repeat(48), name: "Du" },
  fremd: { id: "c".repeat(32), geheimnis: "i".repeat(48), name: "Fremd" },
  vier: { id: "d".repeat(32), geheimnis: "j".repeat(48), name: "Vier" },
};
const kopf = (k) => ({ "X-App-Key": APP, "X-Konto": KONTEN[k].id, "X-Geheimnis": KONTEN[k].geheimnis });
const admin = { "X-Admin-Key": ADMIN, "content-type": "application/json" };
const heute = () => new Date().toISOString().slice(0, 10);

async function ruf(env, k, methode, pfad, body) {
  const headers = k === null ? {} : kopf(k);
  const r = await handleFetch(new Request("https://x.test" + pfad, { method: methode, headers, body: body === undefined ? undefined : JSON.stringify(body) }), env);
  const text = await r.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  return { status: r.status, json, text };
}
async function welt(...namen) {
  const env = { DB: fakeD1(SCHEMA), APP_KEY: APP, ADMIN_KEY: ADMIN, LOVEA_KEY: "x", LOVEA_URL: "https://lovea.test" };
  for (const n of namen) {
    const k = KONTEN[n];
    const r = await handleFetch(new Request("https://x.test/konto", { method: "POST", headers: { "X-App-Key": APP }, body: JSON.stringify({ id: k.id, geheimnis: k.geheimnis, name: k.name, version: "1" }) }), env);
    assert.equal(r.status, 201);
  }
  return env;
}
const volleDatei = (name, extra = {}) => ({
  version: 1, geschrieben: new Date().toISOString(), profilName: name,
  freigaben: ["schritte", "gym", "schlaf", "essen", "plan", "verlauf", "tagebuch", "koerper", "stimmung", "gewohnheiten"],
  heute: {
    stimmung: 4, stimmungWoche: { [heute()]: 4 },
    gewohnheiten: [{ id: "gym", name: "Gym", symbol: "dumbbell.fill", serie: 3, quote: 80, heute: true }, { id: "lesen", name: "Lesen", symbol: "book", serie: 12, quote: 55, heute: false }],
    tag: heute(), schritte: 4200, gymTageWoche: 2, schlafMinuten: 420, kcal: 1900, schlafZiel: 480, habitsFertig: ["gym", "wasser"],
    plan: { name: "PPL", tage: [{ name: "Push", wochentage: [1], uebungen: [{ name: "Bank", saetze: 3 }] }] },
    tagebuch: [{ tag: heute(), kcal: 1900, protein: 100, kohlenhydrate: 200, fett: 60, mahlzeiten: [{ mahlzeit: "mittag", name: "Reis", kcal: 500 }] }],
    koerper: { gewicht: [{ tag: heute(), zehntel: 800 }] },
    verlauf: { trainings: [{ tag: heute(), saetze: 10, uebungen: 3 }] },
    ...extra,
  },
  ereignisse: [
    { id: "e1", art: "gymEnde", zeit: new Date().toISOString(), text: "im Gym" },
    { id: "e2", art: "schlafGut", zeit: new Date().toISOString(), text: "gut geschlafen" },
  ],
});
const hochladen = async (env, k, name = KONTEN[k].name, extra) => assert.equal((await ruf(env, k, "PUT", "/partner", volleDatei(name, extra))).status, 200);
const lovea = (env, id, person) => handleFetch(new Request(`https://x.test/admin/konto/${id}`, {
  method: "PATCH", headers: admin, body: JSON.stringify({ einstellungen: { loveaVerbinden: true }, lovea_person: person }) }), env);

// "ich" besitzt den Code, "du" scannt, "ich" nimmt an. Liefert die Verbindungs-Id.
async function verbinden(env, besitzer = "ich", scanner = "du") {
  const { json: e } = await ruf(env, besitzer, "POST", "/verbindungen/einladung");
  const a = await ruf(env, scanner, "POST", "/verbindungen/anfrage", { token: e.token });
  assert.equal(a.status, 201);
  assert.equal((await ruf(env, besitzer, "POST", `/verbindungen/${a.json.id}/annehmen`)).status, 200);
  return a.json.id;
}
const meine = async (env, k) => (await ruf(env, k, "GET", "/verbindungen")).json.verbindungen;

test("Einladung: Token mit mindestens 128 Bit, nur der Hash liegt in der Datenbank, läuft nach 10 Minuten ab", async () => {
  const env = await welt("ich");
  const r = await ruf(env, "ich", "POST", "/verbindungen/einladung");
  assert.equal(r.status, 201);
  assert.match(r.json.token, /^[A-Za-z0-9_-]{43}$/, "32 Byte = 256 Bit");
  assert.equal(r.json.sekunden, 600);
  const zeilen = env.DB.roh.prepare("SELECT * FROM einladungen").all();
  assert.equal(zeilen.length, 1);
  assert.equal(zeilen[0].hash, createHash("sha256").update(r.json.token).digest("hex"));
  assert.ok(!JSON.stringify(zeilen).includes(r.json.token), "das Token selbst wird nie gespeichert");
  assert.ok(Math.abs(zeilen[0].laeuft_ab - (Date.now() + 600_000)) < 5000);
  const zweites = (await ruf(env, "ich", "POST", "/verbindungen/einladung")).json.token;
  assert.notEqual(zweites, r.json.token);
  assert.equal(env.DB.roh.prepare("SELECT COUNT(*) AS n FROM einladungen").get().n, 1, "ein neuer Code macht den alten ungültig");
});

test("Scannen: zeigt, wer es ist, gibt nichts frei; erst die Annahme öffnet Daten, Standard nur Schritte und Gym", async () => {
  const env = await welt("ich", "du");
  await hochladen(env, "ich");
  const { json: e } = await ruf(env, "ich", "POST", "/verbindungen/einladung");
  const peek = await ruf(env, "du", "POST", "/verbindungen/ansehen", { token: e.token });
  assert.equal(peek.status, 200);
  assert.equal(peek.json.name, "Ich");
  assert.deepEqual(await meine(env, "du"), [], "Ansehen legt nichts an");
  const a = await ruf(env, "du", "POST", "/verbindungen/anfrage", { token: e.token });
  assert.equal(a.status, 201);
  const dein = (await meine(env, "du"))[0];
  assert.equal(dein.status, "anfrageAusgehend");
  assert.equal(dein.daten, undefined, "vor der Annahme keine Daten");
  const sein = (await meine(env, "ich"))[0];
  assert.equal(sein.status, "anfrageEingehend");
  assert.equal(sein.name, "Du");
  assert.equal(sein.daten, undefined);
  assert.equal((await ruf(env, "du", "POST", `/verbindungen/${a.json.id}/annehmen`)).status, 409, "der Scanner kann sich nicht selbst annehmen");
  assert.equal((await ruf(env, "ich", "POST", `/verbindungen/${a.json.id}/annehmen`)).status, 200);
  const d = (await meine(env, "du"))[0];
  assert.equal(d.status, "aktiv");
  assert.deepEqual(d.siehst, ["schritte", "gym"]);
  assert.deepEqual(Object.keys(d.daten.heute).sort(), ["gymTageWoche", "habitsFertig", "schritte", "tag"].sort());
  assert.deepEqual(d.daten.heute.habitsFertig, ["gym"], "Wasser hängt an Essen");
  assert.deepEqual(d.daten.ereignisse.map((x) => x.id), ["e1"], "Schlaf-Ereignis nur mit Schlaf");
});

test("Bereich aus heißt Feld fehlt; ausblenden, Pause und Mitteilungen gelten sofort", async () => {
  const env = await welt("ich", "du");
  await hochladen(env, "ich");
  const id = await verbinden(env);
  const lies = async () => (await meine(env, "du"))[0];
  // Besitzer schaltet Essen und Plan an, Schritte aus.
  let r = await ruf(env, "ich", "PATCH", `/verbindungen/${id}`, { zeigt: ["gym", "essen", "plan"] });
  assert.equal(r.status, 200);
  let d = (await lies()).daten.heute;
  assert.equal(d.schritte, undefined);
  assert.equal(d.kcal, 1900);
  assert.equal(d.plan.tage.length, 1);
  assert.equal(d.schlafMinuten, undefined);
  assert.equal(d.tagebuch, undefined);
  assert.equal(d.koerper, undefined);
  assert.equal(d.verlauf, undefined);
  // Leser blendet Plan aus.
  await ruf(env, "du", "PATCH", `/verbindungen/${id}`, { ausblenden: ["plan"] });
  d = (await lies()).daten.heute;
  assert.equal(d.plan, undefined);
  assert.equal(d.kcal, 1900);
  assert.deepEqual((await lies()).siehst, ["gym", "essen"]);
  // Mitteilungen aus: keine Ereignisse.
  await ruf(env, "du", "PATCH", `/verbindungen/${id}`, { mitteilungen: false });
  assert.deepEqual((await lies()).daten.ereignisse, []);
  // Pause: nichts in beide Richtungen.
  await ruf(env, "du", "PATCH", `/verbindungen/${id}`, { pause: true });
  const p = await lies();
  assert.equal(p.pausiert, true);
  assert.deepEqual(p.siehst, []);
  assert.deepEqual(Object.keys(p.daten.heute), ["tag"]);
  const seins = (await meine(env, "ich"))[0];
  assert.deepEqual(seins.siehst, [], "auch der andere sieht in der Pause nichts von dir");
  assert.deepEqual(Object.keys(seins.daten?.heute ?? { tag: 1 }), ["tag"]);
  await ruf(env, "du", "PATCH", `/verbindungen/${id}`, { pause: false });
  assert.deepEqual((await lies()).siehst, ["gym", "essen"]);
});

test("Zyklus: nur wenn die Verbindung ihn zeigt UND die Person ihn hochgeladen hat; Standard aus", async () => {
  const env = await welt("ich", "du");
  const zyklus = { phase: "luteal", wunsch: "ruhig", satz: "Satz", tipps: ["a"], tag: 20 };
  await hochladen(env, "ich", "Ich", { zyklus });
  const id = await verbinden(env);
  assert.equal((await meine(env, "du"))[0].daten.heute.zyklus, undefined, "neue Verbindung: Zyklus aus");
  await ruf(env, "ich", "PATCH", `/verbindungen/${id}`, { zeigt: ["schritte", "zyklus"] });
  assert.equal((await meine(env, "du"))[0].daten.heute.zyklus.phase, "luteal");
  await hochladen(env, "ich", "Ich"); // Person hat den Zyklus in der App wieder ausgeschaltet: Feld fehlt im Upload
  assert.equal((await meine(env, "du"))[0].daten.heute.zyklus, undefined);
});

test("Fremdes Konto liest nichts, fremde Ids gibt es nicht, ohne Anmeldung 401", async () => {
  const env = await welt("ich", "du", "fremd");
  await hochladen(env, "ich");
  const id = await verbinden(env);
  assert.deepEqual(await meine(env, "fremd"), []);
  for (const [m, p, b] of [["PATCH", `/verbindungen/${id}`, { zeigt: [] }], ["DELETE", `/verbindungen/${id}`], ["POST", `/verbindungen/${id}/annehmen`], ["POST", `/verbindungen/${id}/ablehnen`]]) {
    const r = await ruf(env, "fremd", m, p, b);
    assert.equal(r.status, 404, `${m} ${p}`);
    assert.deepEqual(r.json, { fehler: "not found" }, "gleiche Antwort wie für eine Id, die es nie gab");
  }
  assert.equal((await ruf(env, "fremd", "DELETE", `/verbindungen/${"0".repeat(32)}`)).json.fehler, "not found");
  assert.equal((await meine(env, "du"))[0].status, "aktiv", "nichts davon hat etwas verändert");
  assert.equal((await ruf(env, "fremd", "GET", "/partner")).status, 403, "der alte Weg gibt Fremden nichts");
  assert.equal((await ruf(env, null, "GET", "/verbindungen")).status, 401);
  const falsch = await handleFetch(new Request("https://x.test/verbindungen", { headers: { ...kopf("fremd"), "X-Geheimnis": "z".repeat(48) } }), env);
  assert.equal(falsch.status, 401);
});

test("Entfernen: sofort auf beiden Seiten weg, nichts mehr lesbar, Rückfrage-Logik liegt in der App", async () => {
  const env = await welt("ich", "du");
  await hochladen(env, "ich");
  await hochladen(env, "du");
  const id = await verbinden(env);
  assert.equal((await meine(env, "ich")).length, 1);
  assert.equal((await ruf(env, "du", "DELETE", `/verbindungen/${id}`)).status, 200);
  assert.deepEqual(await meine(env, "du"), []);
  assert.deepEqual(await meine(env, "ich"), []);
  assert.equal(env.DB.roh.prepare("SELECT COUNT(*) AS n FROM partner_stand").get().n, 0, "ohne Verbindung bleibt keine Zusammenfassung auf dem Server");
  assert.equal((await ruf(env, "ich", "PATCH", `/verbindungen/${id}`, { pause: true })).status, 404);
  assert.equal((await ruf(env, "du", "DELETE", `/verbindungen/${id}`)).status, 404);
  const zeile = env.DB.roh.prepare("SELECT * FROM verbindungen WHERE id = ?").get(id);
  assert.deepEqual([zeile.status, zeile.a_einst, zeile.b_einst], ["entfernt", "{}", "{}"]);
});

test("Token: unbekannt, falsche Form, benutzt, abgelaufen und Selbstverbindung werden abgewiesen", async () => {
  const env = await welt("ich", "du", "fremd");
  for (const schlecht of [undefined, "", "x", "a".repeat(43), 5, { a: 1 }]) {
    assert.equal((await ruf(env, "du", "POST", "/verbindungen/anfrage", { token: schlecht })).status, 404);
  }
  const { json: e } = await ruf(env, "ich", "POST", "/verbindungen/einladung");
  // Selbstverbindung: abgewiesen, und das Token bleibt gültig.
  assert.equal((await ruf(env, "ich", "POST", "/verbindungen/anfrage", { token: e.token })).status, 400);
  assert.equal((await ruf(env, "ich", "POST", "/verbindungen/ansehen", { token: e.token })).status, 400);
  assert.deepEqual(await meine(env, "ich"), []);
  assert.equal((await ruf(env, "du", "POST", "/verbindungen/anfrage", { token: e.token })).status, 201);
  // Einmal nutzbar.
  const nochmal = await ruf(env, "fremd", "POST", "/verbindungen/anfrage", { token: e.token });
  assert.equal(nochmal.status, 404);
  assert.equal((await ruf(env, "fremd", "POST", "/verbindungen/ansehen", { token: e.token })).status, 404);
  // Abgelaufen.
  const { json: f } = await ruf(env, "ich", "POST", "/verbindungen/einladung");
  env.DB.roh.prepare("UPDATE einladungen SET laeuft_ab = ?").run(Date.now() - 1);
  const ab = await ruf(env, "fremd", "POST", "/verbindungen/anfrage", { token: f.token });
  assert.equal(ab.status, 404);
  assert.deepEqual(ab.json, nochmal.json, "abgelaufen, benutzt und unbekannt sehen gleich aus");
  assert.equal((await ruf(env, "fremd", "POST", "/verbindungen/ansehen", { token: f.token })).status, 404);
  assert.equal((await meine(env, "fremd")).length, 0);
});

test("Token einmal nutzbar auch bei zwei gleichzeitigen Scans; schon Verbundene verbrauchen es nicht", async () => {
  const env = await welt("ich", "du", "fremd");
  const { json: e } = await ruf(env, "ich", "POST", "/verbindungen/einladung");
  const [x, y] = await Promise.all([ruf(env, "du", "POST", "/verbindungen/anfrage", { token: e.token }), ruf(env, "fremd", "POST", "/verbindungen/anfrage", { token: e.token })]);
  assert.deepEqual([x.status, y.status].sort(), [201, 404]);
  const { json: g } = await ruf(env, "ich", "POST", "/verbindungen/einladung");
  const dupl = await ruf(env, "du", "POST", "/verbindungen/anfrage", { token: g.token });
  assert.equal(dupl.status, 409, "es gibt schon eine Anfrage");
  assert.equal(env.DB.roh.prepare("SELECT benutzt FROM einladungen").get().benutzt, 0, "das Token ist nicht verbraucht");
});

test("Abruf gedrosselt: mehr als 10 Versuche je Minute und Konto gibt 429", async () => {
  const env = await welt("ich", "du");
  const { json: e } = await ruf(env, "ich", "POST", "/verbindungen/einladung");
  const codes = [];
  for (let i = 0; i < 12; i++) codes.push((await ruf(env, "du", "POST", "/verbindungen/ansehen", { token: i < 11 ? "b".repeat(43) : e.token })).status);
  assert.deepEqual(codes.slice(0, 10), Array(10).fill(404));
  assert.deepEqual(codes.slice(10), [429, 429], "auch das echte Token geht in der Sperre nicht durch");
  assert.equal((await ruf(env, "ich", "POST", "/verbindungen/ansehen", { token: "b".repeat(43) })).status, 404, "andere Konten sind nicht betroffen");
});

test("Gesperrte Konten liefern nichts und ihre Codes gelten nicht", async () => {
  const env = await welt("ich", "du", "fremd");
  await hochladen(env, "ich");
  const id = await verbinden(env);
  const { json: e } = await ruf(env, "ich", "POST", "/verbindungen/einladung");
  await handleFetch(new Request(`https://x.test/admin/konto/${KONTEN.ich.id}`, { method: "PATCH", headers: admin, body: JSON.stringify({ gesperrt: true }) }), env);
  assert.deepEqual(await meine(env, "du"), []);
  assert.equal((await ruf(env, "fremd", "POST", "/verbindungen/anfrage", { token: e.token })).status, 404);
  assert.equal((await ruf(env, "ich", "GET", "/verbindungen")).status, 403);
  assert.ok(id);
});

test("Zu viele offene Anfragen an ein Konto werden abgewiesen", async () => {
  const env = await welt("ich");
  for (let i = 0; i < 11; i++) {
    const k = { id: String(i).padStart(2, "0").repeat(16), geheimnis: "q".repeat(48), name: `K${i}` };
    await handleFetch(new Request("https://x.test/konto", { method: "POST", headers: { "X-App-Key": APP }, body: JSON.stringify({ ...k, version: "1" }) }), env);
    env.DB.roh.exec("DELETE FROM drossel");
    const { json: e } = await ruf(env, "ich", "POST", "/verbindungen/einladung");
    const r = await handleFetch(new Request("https://x.test/verbindungen/anfrage", { method: "POST", headers: { "X-App-Key": APP, "X-Konto": k.id, "X-Geheimnis": k.geheimnis }, body: JSON.stringify({ token: e.token }) }), env);
    assert.equal(r.status, i < 10 ? 201 : 429);
  }
});

test("Einstellungen: ungültige Eingaben werden abgewiesen, Name wird bereinigt", async () => {
  const env = await welt("ich", "du");
  const id = await verbinden(env);
  for (const b of [{ zeigt: ["gewicht"] }, { zeigt: "alle" }, { pause: "ja" }, { unbekannt: 1 }, [], { name: 5 }]) {
    assert.equal((await ruf(env, "du", "PATCH", `/verbindungen/${id}`, b)).status, 400, JSON.stringify(b));
  }
  const r = await ruf(env, "du", "PATCH", `/verbindungen/${id}`, { name: "  Mama\u0007 und eine ganz lange Bezeichnung  ", favorit: true });
  assert.equal(r.json.verbindung.ich.name, "Mama und eine ganz lange");
  assert.equal(r.json.verbindung.ich.favorit, true);
  assert.equal((await meine(env, "ich"))[0].ich.favorit, false, "Einstellungen gehören je einer Seite");
});

test("Lovea-Konten sind ohne Scan verbunden, alle Bereiche an; eigenes Ausschalten bleibt", async () => {
  const env = await welt("ich", "du");
  await lovea(env, KONTEN.ich.id, "ahmed");
  await lovea(env, KONTEN.du.id, "annika");
  await hochladen(env, "ich", "Ahmed");
  await hochladen(env, "du", "Annika", { zyklus: { phase: "folikular", wunsch: "w", satz: "s", tipps: [] } });
  const bei = (await meine(env, "ich"))[0];
  assert.equal(bei.auto, true);
  assert.equal(bei.status, "aktiv");
  assert.equal(bei.name, "Annika");
  assert.deepEqual(bei.siehst, ["schritte", "gym", "schlaf", "essen", "plan", "verlauf", "tagebuch", "koerper", "stimmung", "gewohnheiten", "zyklus"]);
  assert.equal(bei.daten.heute.kcal, 1900);
  assert.equal(bei.daten.heute.stimmung, 4);
  assert.equal(bei.daten.heute.gewohnheiten.length, 2);
  assert.equal(bei.daten.heute.zyklus.phase, "folikular", "Annika hat den Zyklus in der App erlaubt (Feld im Upload)");
  const umgekehrt = (await meine(env, "du"))[0];
  assert.equal(umgekehrt.daten.heute.tagebuch.length, 1);
  assert.equal(umgekehrt.daten.heute.zyklus, undefined, "Ahmed hat keinen Zyklus hochgeladen");
  assert.equal(env.DB.roh.prepare("SELECT COUNT(*) AS n FROM verbindungen").get().n, 1, "eine Zeile für beide Richtungen");
  // Annika schaltet Schlaf bei sich aus: bleibt so, auch nach weiteren Abrufen.
  await ruf(env, "du", "PATCH", `/verbindungen/${bei.id}`, { zeigt: ["schritte", "gym", "essen"] });
  await meine(env, "du"); await meine(env, "ich");
  assert.equal((await meine(env, "ich"))[0].daten.heute.schlafMinuten, undefined);
  assert.equal((await meine(env, "du"))[0].daten.heute.schlafMinuten, 420, "Ahmeds Richtung bleibt an");
  // Alter App-Stand: GET /partner liefert dieselbe Auswahl.
  const alt = (await ruf(env, "ich", "GET", "/partner")).json.partner;
  assert.equal(alt.profilName, "Annika");
  assert.equal(alt.heute.schlafMinuten, undefined);
  assert.equal(alt.heute.kcal, 1900);
});

test("Lovea-Verbindung: entfernt bleibt entfernt, per QR geht sie wieder, neues Gerät legt sie nicht neu an", async () => {
  const env = await welt("ich", "du", "fremd");
  await lovea(env, KONTEN.ich.id, "ahmed");
  await lovea(env, KONTEN.du.id, "annika");
  await hochladen(env, "du", "Annika");
  const id = (await meine(env, "ich"))[0].id;
  assert.equal((await ruf(env, "ich", "DELETE", `/verbindungen/${id}`)).status, 200);
  assert.deepEqual(await meine(env, "ich"), []);
  assert.deepEqual(await meine(env, "du"), []);
  assert.deepEqual((await ruf(env, "ich", "GET", "/partner")).json, { partner: null, aktualisiert: null });
  // Neues Gerät derselben Person: Lovea-Konto, aber die Entfernung gilt zwischen den Personen.
  await handleFetch(new Request("https://x.test/konto", { method: "POST", headers: { "X-App-Key": APP }, body: JSON.stringify({ id: KONTEN.vier.id, geheimnis: KONTEN.vier.geheimnis, name: "Neu", version: "1" }) }), env);
  await lovea(env, KONTEN.vier.id, "ahmed");
  assert.deepEqual(await meine(env, "vier"), []);
  // Per QR wieder verbinden: Annika zeigt den Code, Ahmed scannt, Annika nimmt an.
  const wieder = await verbinden(env, "du", "ich");
  assert.equal(wieder, id, "dieselbe Zeile, frisch");
  const neu = (await meine(env, "ich"))[0];
  assert.equal(neu.auto, false);
  assert.deepEqual(neu.siehst, ["schritte", "gym"], "nach dem Wiederverbinden gelten die Standardwerte für neue Personen");
});

test("Lovea-Verbindung braucht beide Freigaben: ohne loveaVerbinden entsteht nichts", async () => {
  const env = await welt("ich", "du");
  await handleFetch(new Request(`https://x.test/admin/konto/${KONTEN.ich.id}`, { method: "PATCH", headers: admin, body: JSON.stringify({ lovea_person: "ahmed" }) }), env);
  await lovea(env, KONTEN.du.id, "annika");
  assert.deepEqual(await meine(env, "du"), []);
  assert.deepEqual(await meine(env, "ich"), []);
});

test("Alter Weg: PUT /partner begrenzt wie vorher, die gespeicherte Datei bleibt weit unter der Grenze", async () => {
  const env = await welt("ich");
  const t = heute();
  const lang = "x".repeat(60);
  const viel = volleDatei("Ich", {
    plan: { name: lang, ruhetage: [1, 2], tage: Array.from({ length: 14 }, () => ({ name: lang, wochentage: [1, 2, 3, 4, 5, 6, 7], uebungen: Array.from({ length: 20 }, () => ({ name: lang, saetze: 5 })) })) },
    tagebuch: Array.from({ length: 7 }, () => ({ tag: t, kcal: 1, protein: 1, kohlenhydrate: 1, fett: 1, mahlzeiten: Array.from({ length: 30 }, () => ({ mahlzeit: "snack", name: lang, kcal: 100 })) })),
    stimmungWoche: Object.fromEntries(Array.from({ length: 14 }, (_, i) => [`2026-10-${String(i + 1).padStart(2, "0")}`, 5])),
    gewohnheiten: Array.from({ length: 50 }, (_, i) => ({ id: `h${i}`.padEnd(60, "x"), name: lang, symbol: lang, serie: 9999, quote: 100, heute: true })),
    koerper: Object.fromEntries(["gewicht", "taille", "brust", "schulter", "bizeps", "oberschenkel", "koerperfett"].map((a) => [a, Array.from({ length: 90 }, () => ({ tag: t, zehntel: 999 }))])),
  });
  const roh = JSON.stringify(viel);
  assert.ok(roh.length < 262144, `Upload im größten Fall ${roh.length} Byte, Grenze 262144`);
  assert.equal((await ruf(env, "ich", "PUT", "/partner", viel)).status, 200);
  const gespeichert = env.DB.roh.prepare("SELECT daten FROM partner_stand").get().daten;
  assert.ok(gespeichert.length < 131072, `gespeichert ${gespeichert.length} Byte`);
});

test("Config: Band in Lumen Fit ist Standard an für ahmed, sonst aus; das Konto gewinnt", async () => {
  const env = await welt("ich", "du");
  const lies = async (k) => (await ruf(env, k, "GET", "/config")).json.config.bandStandard;
  assert.equal(await lies("ich"), false);
  await lovea(env, KONTEN.ich.id, "ahmed");
  await lovea(env, KONTEN.du.id, "annika");
  assert.equal(await lies("ich"), true);
  assert.equal(await lies("du"), false);
  await handleFetch(new Request(`https://x.test/admin/konto/${KONTEN.ich.id}`, { method: "PATCH", headers: admin, body: JSON.stringify({ einstellungen: { bandStandard: false } }) }), env);
  assert.equal(await lies("ich"), false);
});

test("Hochladen nur für die Bereiche, die eine aktive, nicht pausierte Verbindung zeigt (teilen)", async () => {
  const env = await welt("ich", "du", "fremd");
  assert.deepEqual((await ruf(env, "ich", "GET", "/verbindungen")).json.teilen, [], "ohne Verbindung nichts");
  const id = await verbinden(env);
  assert.deepEqual((await ruf(env, "ich", "GET", "/verbindungen")).json.teilen, ["schritte", "gym"]);
  await ruf(env, "ich", "PATCH", `/verbindungen/${id}`, { zeigt: ["schlaf", "tagebuch"] });
  assert.deepEqual((await ruf(env, "ich", "GET", "/verbindungen")).json.teilen, ["schlaf", "tagebuch"]);
  await ruf(env, "ich", "PATCH", `/verbindungen/${id}`, { pause: true });
  assert.deepEqual((await ruf(env, "ich", "GET", "/verbindungen")).json.teilen, []);
  assert.deepEqual((await ruf(env, "fremd", "GET", "/verbindungen")).json.teilen, []);
});

test("Lovea-Einträge tragen lovea: true, QR-Verbindungen nicht", async () => {
  const env = await welt("ich", "du", "fremd");
  await lovea(env, KONTEN.ich.id, "ahmed");
  await lovea(env, KONTEN.du.id, "annika");
  assert.equal((await meine(env, "ich"))[0].lovea, true);
  await verbinden(env, "fremd", "ich");
  const alle = await meine(env, "ich");
  assert.deepEqual(alle.map((e) => e.lovea).sort(), [false, true]);
});

test("Stimmung und Gewohnheiten: Standard-Verbindung sieht sie nicht, mit Freigabe ja, ungültige Werte fallen weg", async () => {
  const env = await welt("ich", "fremd");
  await hochladen(env, "ich", "Ich", { gewohnheiten: [{ id: "x", name: "Lesen", symbol: "book", serie: 5, quote: 400, heute: true }, { id: "", name: "ohne Id" }, { id: "y", name: "" }], stimmung: 9 });
  const code = await ruf(env, "ich", "POST", "/verbindungen/einladung");
  const a = await ruf(env, "fremd", "POST", "/verbindungen/anfrage", { token: code.json.token });
  await ruf(env, "ich", "POST", `/verbindungen/${a.json.id}/annehmen`);
  const standard = (await meine(env, "fremd"))[0].daten.heute;
  assert.equal(standard.stimmung, undefined);
  assert.equal(standard.stimmungWoche, undefined);
  assert.equal(standard.gewohnheiten, undefined);
  await ruf(env, "ich", "PATCH", `/verbindungen/${a.json.id}`, { zeigt: ["schritte", "gym", "stimmung", "gewohnheiten"] });
  const frei = (await meine(env, "fremd"))[0].daten.heute;
  assert.equal(frei.stimmung, undefined, "9 liegt außerhalb von 1 bis 5");
  assert.deepEqual(frei.gewohnheiten, [{ id: "x", name: "Lesen", symbol: "book", serie: 5, quote: 100, heute: true }], "Quote auf 100 gekappt, Einträge ohne Id oder Namen weg");
  assert.deepEqual(frei.stimmungWoche, { [heute()]: 4 });
  await ruf(env, "fremd", "PATCH", `/verbindungen/${a.json.id}`, { ausblenden: ["gewohnheiten"] });
  assert.equal((await meine(env, "fremd"))[0].daten.heute.gewohnheiten, undefined, "ausgeblendet bei mir: Feld fehlt");
});

test("Neue QR-Person ohne Lovea: ohne Upload leer ohne Fehler; Gym in der App aus heißt kein Gym beim Gegenüber, Schritte kommen", async () => {
  const env = await welt("ich", "du");
  const id = await verbinden(env);
  const leer = (await meine(env, "du"))[0];
  assert.equal(leer.status, "aktiv");
  assert.ok(!leer.daten, "noch nichts hochgeladen: leer, kein Fehler");
  // "ich" hat Gym ausgeschaltet: die App lädt nur Schritte hoch (die Verbindung würde Gym erlauben)
  const nurSchritte = volleDatei("Ich");
  nurSchritte.freigaben = ["schritte"];
  assert.equal((await ruf(env, "ich", "PUT", "/partner", nurSchritte)).status, 200);
  const d = (await meine(env, "du")).find((e) => e.id === id);
  assert.deepEqual(d.siehst, ["schritte", "gym"], "die Verbindung erlaubt Gym");
  assert.deepEqual(d.daten.freigaben, ["schritte"], "geteilt wird nur, was hochgeladen wurde");
  assert.equal(d.daten.heute.schritte, 4200);
  assert.equal(d.daten.heute.gymTageWoche, undefined);
  assert.deepEqual(d.daten.ereignisse, [], "kein Gym-Ereignis");
});

