// Gym-Coach für Ahmeds claude.ai-Chat (über den Connector fernfunk-relais, Dienstbindung, Schlüssel COACH_KEY).
// Nur Ahmeds Konto (lovea_person 'ahmed'). Lesen: Plan, Verlauf, Übungskatalog. Ändern nur in zwei Schritten:
// /coach/vorschlag rechnet vorher/nachher und gibt ein Token, /coach/anwenden legt genau diesen Plan ins Postfach (gym.plan).
// Jede Anwendung merkt den Plan davor (Stapel, 10 Stück), /coach/rueckgaengig macht daraus wieder einen Vorschlag.
import katalogListe from "../LumenFit/Resources/Daten/uebungen.json" with { type: "json" };
import { ERLAUBT } from "./postfach.js";

const KATALOG = new Map(katalogListe.map((u) => [u.id, u]));
const TAGE = ["", "Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"];
const VORSCHLAG_STUNDEN = 24;
const MAX_VORSCHLAEGE = 5;
const MAX_STAPEL = 10;
const MAX_POSTFACH_BYTES = 60000;

const ist = (x) => x !== null && typeof x === "object" && !Array.isArray(x);
const klein = (s) => String(s ?? "").toLowerCase().normalize("NFKD").replace(/[̀-ͯ]/g, "").trim();
export const uebungName = (u) => u.name ?? KATALOG.get(u.uebung)?.name ?? u.uebung;
const tagLabel = (t) => `${t.name}${t.wochentage?.length ? ` (${t.wochentage.map((w) => TAGE[w]).join(", ")})` : ""}`;

// Gleiche Inhalte, gleicher Text: Schlüssel sortiert, null weg (Swift lässt nil-Felder aus, die App kodiert neu).
export function kanon(x) {
  if (Array.isArray(x)) return `[${x.map(kanon).join(",")}]`;
  if (ist(x)) return `{${Object.keys(x).filter((k) => x[k] !== null && x[k] !== undefined).sort().map((k) => `${JSON.stringify(k)}:${kanon(x[k])}`).join(",")}}`;
  return JSON.stringify(x);
}

function saetzeText(saetze) {
  if (!saetze?.length) return "–";
  const teile = saetze.map((s) => `${s.wdh}${s.kg != null ? `×${s.kg} kg` : ""}${s.failure ? " F" : ""}`);
  return teile.every((t) => t === teile[0]) ? `${saetze.length}× ${teile[0]}` : teile.join(", ");
}
const uebungText = (u) => (u.minuten != null ? `${u.minuten} min` : saetzeText(u.saetze));

/** Plan, wie der Coach ihn liest: Tage mit Wochentagen, Übungen mit Namen. */
export function lesbar(plan) {
  return {
    split: plan.splitName ?? null,
    ruhetage: (plan.ruhetage ?? []).map((w) => TAGE[w]),
    tage: plan.tage.map((t) => ({
      id: t.id, name: t.name, wochentage: t.wochentage.map((w) => TAGE[w]),
      uebungen: t.uebungen.map((u) => ({ id: u.id, uebung: u.uebung, name: uebungName(u), ...(u.minuten != null ? { minuten: u.minuten } : { saetze: u.saetze.map((s) => ({ wdh: s.wdh, kg: s.kg ?? null, ...(s.failure ? { failure: true } : {}), ...(s.typ ? { typ: s.typ } : {}) })) }) })),
    })),
  };
}

/** Zeilen "Tag · Übung: vorher → nachher" für alles, was sich unterscheidet. */
export function unterschiede(vorher, nachher) {
  const zeilen = [];
  const alt = new Map(vorher.tage.map((t) => [t.id, t]));
  for (const t of nachher.tage) {
    const a = alt.get(t.id);
    if (!a) { zeilen.push(`Neuer Tag ${tagLabel(t)}: ${t.uebungen.map(uebungName).join(", ")}`); continue; }
    alt.delete(t.id);
    if (a.name !== t.name || kanon(a.wochentage) !== kanon(t.wochentage)) zeilen.push(`Tag ${tagLabel(a)} → ${tagLabel(t)}`);
    const au = new Map(a.uebungen.map((u) => [u.id, u]));
    for (const u of t.uebungen) {
      const x = au.get(u.id);
      if (!x) { zeilen.push(`${tagLabel(t)} · neu: ${uebungName(u)} ${uebungText(u)}`); continue; }
      au.delete(u.id);
      if (x.uebung !== u.uebung || uebungName(x) !== uebungName(u)) zeilen.push(`${tagLabel(t)} · ${uebungName(x)} → ${uebungName(u)}: ${uebungText(u)}`);
      else if (uebungText(x) !== uebungText(u) || kanon(x) !== kanon(u)) zeilen.push(`${tagLabel(t)} · ${uebungName(u)}: ${uebungText(x)} → ${uebungText(u)}`);
    }
    for (const x of au.values()) zeilen.push(`${tagLabel(t)} · raus: ${uebungName(x)}`);
    const reihe = (tag) => tag.uebungen.map((u) => u.id).filter((id) => a.uebungen.some((v) => v.id === id) && t.uebungen.some((v) => v.id === id)).join();
    if (reihe(a) !== reihe(t)) zeilen.push(`${tagLabel(t)} · neue Reihenfolge: ${t.uebungen.map(uebungName).join(", ")}`);
  }
  for (const a of alt.values()) zeilen.push(`Tag raus: ${tagLabel(a)}`);
  if (kanon(vorher.ruhetage ?? []) !== kanon(nachher.ruhetage ?? [])) zeilen.push(`Ruhetage: ${(nachher.ruhetage ?? []).map((w) => TAGE[w]).join(", ") || "keine"}`);
  return zeilen;
}

function finde(liste, wert, schluessel, was) {
  const w = klein(wert);
  const genau = liste.filter((x) => x.id === wert || schluessel(x).some((s) => klein(s) === w));
  const treffer = genau.length ? genau : liste.filter((x) => schluessel(x).some((s) => klein(s).includes(w)));
  if (treffer.length === 1) return treffer[0];
  throw new Error(treffer.length ? `${was} "${wert}" ist mehrdeutig, nimm die id` : `${was} "${wert}" nicht gefunden`);
}

const kgOk = (k) => typeof k === "number" && Number.isFinite(k) && k >= 0 && k <= 500;
const wdhOk = (w) => Number.isInteger(w) && w >= 1 && w <= 100;

/** Kleine Änderungen an Übungen eines Plans: neuer Plan (Kopie), das Original bleibt. */
export function aendern(plan, aenderungen) {
  if (!Array.isArray(aenderungen) || !aenderungen.length || aenderungen.length > 20) throw new Error("aenderungen: 1 bis 20 Einträge");
  const neu = structuredClone(plan);
  for (const a of aenderungen) {
    if (!ist(a)) throw new Error("Änderung ungültig");
    const tag = finde(neu.tage, a.tag ?? "", (t) => [t.name, tagLabel(t), ...t.wochentage.map((w) => TAGE[w])], "Tag");
    const u = finde(tag.uebungen, a.uebung ?? "", (x) => [uebungName(x), x.uebung], "Übung");
    if (u.minuten != null) {
      if (!Number.isInteger(a.minuten) || a.minuten < 1 || a.minuten > 300) throw new Error(`${uebungName(u)} ist Cardio: nur minuten (1 bis 300)`);
      u.minuten = a.minuten;
      continue;
    }
    if (a.liste !== undefined) {
      if (!Array.isArray(a.liste) || !a.liste.length || a.liste.length > 30) throw new Error("liste: 1 bis 30 Sätze");
      u.saetze = a.liste.map((s) => {
        if (!ist(s) || !wdhOk(s.wdh) || (s.kg != null && !kgOk(s.kg))) throw new Error("liste: je Satz wdh 1 bis 100, kg 0 bis 500");
        return { wdh: s.wdh, ...(s.kg != null ? { kg: s.kg } : {}), failure: s.failure === true };
      });
    }
    if (a.saetze !== undefined) {
      if (!Number.isInteger(a.saetze) || a.saetze < 1 || a.saetze > 30) throw new Error("saetze: 1 bis 30");
      const vorlage = u.saetze.at(-1) ?? { wdh: 10, failure: false };
      u.saetze = a.saetze <= u.saetze.length ? u.saetze.slice(0, a.saetze) : [...u.saetze, ...Array.from({ length: a.saetze - u.saetze.length }, () => ({ ...vorlage }))];
    }
    if (a.wdh !== undefined) {
      if (!wdhOk(a.wdh)) throw new Error("wdh: 1 bis 100");
      u.saetze = u.saetze.map((s) => ({ ...s, wdh: a.wdh }));
    }
    if (a.kg !== undefined) {
      if (!kgOk(a.kg)) throw new Error("kg: 0 bis 500");
      u.saetze = u.saetze.map((s) => (s.typ === "w" ? s : { ...s, kg: a.kg }));
    }
    if (a.liste === undefined && a.saetze === undefined && a.wdh === undefined && a.kg === undefined) throw new Error("je Änderung mindestens kg, wdh, saetze oder liste");
  }
  return neu;
}

// Ganzer neuer Plan vom Coach: Katalog-ids prüfen, doppelte Katalognamen weg (sonst klebt der Name fest), Felder wie Splitname behalten.
export function ganzerPlan(alt, plan) {
  const fehler = ERLAUBT["gym.plan"](plan);
  if (fehler) throw new Error(fehler);
  const neu = structuredClone(plan);
  for (const t of neu.tage) for (const u of t.uebungen) {
    if (u.uebung === "eigen") { if (typeof u.name !== "string" || !u.name.trim()) throw new Error("eigene Übung braucht name"); continue; }
    const k = KATALOG.get(u.uebung);
    if (!k) throw new Error(`Übung ${u.uebung} nicht im Katalog, erst gym_uebungen suchen oder uebung "eigen" mit name`);
    if (u.name === k.name) delete u.name;
    for (const s of u.saetze) if (!wdhOk(s.wdh) || (s.kg != null && !kgOk(s.kg))) throw new Error(`${k.name}: wdh 1 bis 100, kg 0 bis 500`);
  }
  for (const f of ["ruhetage", "splitName", "wochen"]) if (!(f in neu) && f in alt) neu[f] = alt[f];
  return neu;
}

/** e1RM (Epley) und Bestwerte je Übung aus den Einheiten (kg in Zehnteln wie in partner_stand). */
export function verlauf(einheiten) {
  const je = new Map();
  const liste = einheiten.map((e) => ({
    tag: e.tag, name: e.name,
    uebungen: (e.uebungen ?? []).map((u) => {
      const saetze = (u.saetze ?? []).map((s) => ({ wdh: s.wdh, kg: s.kg != null ? s.kg / 10 : null }));
      const b = je.get(u.name) ?? { uebung: u.name, einheiten: 0, bester_satz: null, e1rm: 0, zuletzt: null };
      b.einheiten++;
      for (const s of saetze) {
        if (!s.kg || !s.wdh) continue;
        const e1 = Math.round(s.kg * (1 + s.wdh / 30) * 10) / 10;
        if (e1 > b.e1rm) { b.e1rm = e1; b.bester_satz = `${s.wdh}×${s.kg} kg (${e.tag})`; }
      }
      if (!b.zuletzt || e.tag > b.zuletzt.tag) b.zuletzt = { tag: e.tag, saetze: saetzeText(saetze) };
      je.set(u.name, b);
      return { name: u.name, saetze: saetzeText(saetze) };
    }),
  }));
  return { einheiten: liste.sort((a, b) => (a.tag < b.tag ? 1 : -1)), je_uebung: [...je.values()].sort((a, b) => b.e1rm - a.e1rm) };
}

export function katalogSuche(text, max = 15) {
  const w = klein(text).split(/\s+/).filter(Boolean);
  if (!w.length) return [];
  return katalogListe.filter((u) => w.every((x) => klein(`${u.name} ${u.en ?? ""} ${u.muskel ?? ""} ${u.geraet ?? ""}`).includes(x)))
    .slice(0, max).map((u) => ({ id: u.id, name: u.name, muskel: u.muskel, geraet: u.geraet }));
}

// ——— Worker-Teil ———

const lies = async (env, konto, s) => (await env.DB.prepare("SELECT wert FROM konto_merker WHERE konto = ? AND schluessel = ?").bind(konto, s).first())?.wert;
const schreib = (env, konto, s, wert) => env.DB.prepare("INSERT OR REPLACE INTO konto_merker (konto, schluessel, wert) VALUES (?, ?, ?)").bind(konto, s, JSON.stringify(wert)).run();

/** Der Plan, der gerade gilt: ein noch nicht abgeholter Coach-Plan im Postfach, sonst der zuletzt von der App gemeldete. */
async function aktuell(env, konto, lesen) {
  const offen = await env.DB.prepare("SELECT daten, erstellt FROM agent_postfach WHERE konto = ? AND art = 'gym.plan' AND abgeholt IS NULL ORDER BY id DESC LIMIT 1").bind(konto).first();
  if (offen) return { plan: lesen(offen.daten), zeit: offen.erstellt, quelle: "Coach-Änderung, App hat sie noch nicht geholt" };
  const g = lesen(await lies(env, konto, "plan_aktuell"));
  return g?.plan ? { plan: g.plan, zeit: g.zeit, quelle: "App" } : null;
}

async function vorschlagMerken(env, konto, v, lesen) {
  const jetzt = Date.now();
  const alt = (lesen(await lies(env, konto, "coach_vorschlaege")) ?? []);
  const liste = (Array.isArray(alt) ? alt : []).filter((x) => jetzt - x.zeit < VORSCHLAG_STUNDEN * 3600_000).slice(-(MAX_VORSCHLAEGE - 1));
  const token = crypto.randomUUID().slice(0, 8);
  await schreib(env, konto, "coach_vorschlaege", [...liste, { ...v, token, zeit: jetzt }]);
  return token;
}

export async function coach(request, url, env, { json, nein, koerper, lesen, gleich }) {
  if (!env.COACH_KEY || !gleich(request.headers.get("X-Coach-Key"), env.COACH_KEY)) return nein(401, "unauthorized");
  const konto = (await env.DB.prepare("SELECT id FROM konten WHERE lovea_person = 'ahmed' AND gesperrt = 0 ORDER BY gesehen DESC LIMIT 1").first())?.id;
  if (!konto) return nein(404, "kein Konto für Ahmed");
  const m = request.method;
  const p = url.pathname;
  try {
    if (p === "/coach/plan" && m === "GET") {
      const a = await aktuell(env, konto, lesen);
      if (!a) return json({ plan: null, hinweis: "Die App hat noch keinen Plan gemeldet. Ahmed soll Lumen Fit einmal öffnen." });
      return json({ stand: a.zeit, quelle: a.quelle, plan: lesbar(a.plan) });
    }
    if (p === "/coach/verlauf" && m === "GET") {
      const z = await env.DB.prepare("SELECT aktualisiert, daten FROM partner_stand WHERE konto = ?").bind(konto).first();
      const h = lesen(z?.daten)?.heute ?? {};
      const v = h.verlauf ?? {};
      const gewicht = (h.koerper?.gewicht ?? []).at(-1);
      return json({
        stand: z?.aktualisiert ?? null, hinweis: "Nur die letzten Einheiten, die die App teilt (bis 30). kg in kg.",
        trainings_gesamt: v.trainings ?? null, serie_wochen: v.serieWochen ?? null, im_gym: v.imGym ?? false,
        koerpergewicht: gewicht ? { tag: gewicht.tag, kg: gewicht.zehntel / 10 } : null,
        ...verlauf(Array.isArray(v.einheiten) ? v.einheiten : []),
      });
    }
    if (p === "/coach/uebungen" && m === "GET") return json({ treffer: katalogSuche(url.searchParams.get("suche") ?? "") });
    if (p === "/coach/vorschlag" && m === "POST") {
      const b = await koerper(request);
      const a = await aktuell(env, konto, lesen);
      if (!a) return nein(409, "Noch kein Plan von der App gemeldet. Ahmed soll Lumen Fit einmal öffnen.");
      if (!ist(b) || (b.plan === undefined) === (b.aenderungen === undefined)) return nein(400, "entweder plan (ganzer Plan) oder aenderungen (einzelne Übungen)");
      const nachher = b.plan !== undefined ? ganzerPlan(a.plan, b.plan) : aendern(a.plan, b.aenderungen);
      const zeilen = unterschiede(a.plan, nachher);
      if (!zeilen.length) return nein(400, "Das ändert nichts am Plan.");
      if (JSON.stringify(nachher).length > MAX_POSTFACH_BYTES) return nein(400, "Plan zu groß");
      const token = await vorschlagMerken(env, konto, { basis: kanon(a.plan), nachher, zeilen }, lesen);
      return json({ token, aenderungen: zeilen, gilt_stunden: VORSCHLAG_STUNDEN, hinweis: "Noch nichts geändert. Ahmed zeigen; erst nach seinem Ja gym_plan_aendern mit diesem token." });
    }
    if (p === "/coach/rueckgaengig" && m === "POST") {
      const stapel = lesen(await lies(env, konto, "coach_stapel"));
      const letzter = Array.isArray(stapel) ? stapel.at(-1) : null;
      if (!letzter) return nein(404, "Keine Coach-Änderung zum Rückgängigmachen.");
      const a = await aktuell(env, konto, lesen);
      if (!a) return nein(409, "Kein aktueller Plan bekannt.");
      const zeilen = unterschiede(a.plan, letzter.vorher);
      if (!zeilen.length) return nein(400, "Der Plan ist schon wie vor der letzten Coach-Änderung.");
      const token = await vorschlagMerken(env, konto, { basis: kanon(a.plan), nachher: letzter.vorher, zeilen, zurueck: true }, lesen);
      return json({ token, aenderungen: zeilen, von: new Date(letzter.zeit).toISOString(), hinweis: "Zurück zum Plan vor der letzten Coach-Änderung. Noch nichts geändert; nach Ahmeds Ja gym_plan_aendern mit diesem token." });
    }
    if (p === "/coach/anwenden" && m === "POST") {
      const b = await koerper(request);
      const liste = lesen(await lies(env, konto, "coach_vorschlaege"));
      const v = Array.isArray(liste) ? liste.find((x) => typeof b?.token === "string" && x.token === b.token) : null;
      if (!v || Date.now() - v.zeit > VORSCHLAG_STUNDEN * 3600_000) return nein(404, "Token unbekannt oder abgelaufen. Neu vorschlagen.");
      const a = await aktuell(env, konto, lesen);
      if (!a || kanon(a.plan) !== v.basis) return nein(409, "Der Plan hat sich seit dem Vorschlag geändert. Neu lesen und neu vorschlagen.");
      const offen = await env.DB.prepare("SELECT COUNT(*) AS n FROM agent_postfach WHERE konto = ? AND abgeholt IS NULL").bind(konto).first();
      if (offen.n >= 20) return nein(429, "Zu viele offene Einträge im Postfach. Ahmed soll Lumen Fit öffnen.");
      const jetzt = new Date().toISOString();
      await env.DB.prepare("INSERT INTO agent_postfach (konto, art, daten, erstellt) VALUES (?, 'gym.plan', ?, ?)").bind(konto, JSON.stringify(v.nachher), jetzt).run();
      const stapel = lesen(await lies(env, konto, "coach_stapel"));
      const s = Array.isArray(stapel) ? stapel : [];
      await schreib(env, konto, "coach_stapel", v.zurueck ? s.slice(0, -1) : [...s, { zeit: Date.now(), vorher: a.plan }].slice(-MAX_STAPEL));
      await schreib(env, konto, "coach_vorschlaege", liste.filter((x) => x.token !== v.token));
      return json({ ok: true, aenderungen: v.zeilen, hinweis: "Liegt bereit. Lumen Fit zeigt es beim nächsten Öffnen (ein laufendes Training liest den neuen Tag sofort). Rückweg: gym_rueckgaengig." });
    }
  } catch (e) {
    return nein(400, e.message);
  }
  return nein(404, "not found");
}
