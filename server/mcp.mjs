#!/usr/bin/env node
// MCP-Server (stdio) zur Verwaltung des Lumen-Fit-Servers: Konten, Schalter, Sperren. Ohne Abhängigkeit, JSON-RPC 2.0, eine Nachricht pro Zeile.
// Spricht nur mit /admin/* des Workers. Admin-Key: LUMENFIT_ADMIN_KEY_PFAD oder ~/.config/lumenfit/admin.key (Inhalt wird nie ausgegeben).
// HTTP-Brücke: ~/.local/bin/mcp-lovea-http mit LOVEA_MCP=<dieses Skript> PORT=8935 (Dienst mcp-lumenfit).
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";

const BASIS = {
  test: process.env.LUMENFIT_URL_TEST ?? "https://lumen-fit-test.ahmedhdplay12345.workers.dev",
  live: process.env.LUMENFIT_URL_LIVE ?? "https://lumen-fit-live.ahmedhdplay12345.workers.dev",
};
const umgebung = { type: "string", enum: ["test", "live"], description: "Worker, Standard live (dort liegen die echten Konten)." };
const kontoId = { type: "string", description: "Konto-ID aus lumenfit_konten" };

export const WERKZEUGE = [
  {
    name: "lumenfit_konten",
    description: "Alle Konten des Lumen-Fit-Servers: ID, Name, App-Version, zuletzt gesehen, gesperrt, lovea_person, Schalter je Konto, dazu die globalen Schalter. Keine Geheimnisse.",
    inputSchema: { type: "object", properties: { umgebung } },
  },
  {
    name: "lumenfit_konto_setzen",
    description: "Schalter eines Kontos ändern, wirkt ohne App-Build beim nächsten GET /config. einstellungen = Merge-Patch (null entfernt den Schlüssel), z. B. {loveaVerbinden: true} zusammen mit lovea_person ahmed|annika. Lovea-Verbinden nur für Ahmed und Annika setzen, sonst nie.",
    inputSchema: {
      type: "object",
      properties: {
        umgebung, id: kontoId,
        einstellungen: { type: "object", description: "Schalter je Konto, z. B. {\"loveaVerbinden\": true, \"nameAendernTage\": 3}" },
        lovea_person: { type: ["string", "null"], enum: ["ahmed", "annika", null], description: "Welche Lovea-Person das Konto importieren darf; null entzieht sie." },
        lovea_import_zuruecksetzen: { type: "boolean", description: "true: der Merker \"Lovea-Import fertig\" wird gelöscht, die App importiert beim nächsten Start nochmal (nichts wird doppelt)." },
      },
      required: ["id"],
    },
  },
  {
    name: "lumenfit_nutzung",
    description: "Nutzung je Konto (aus den gebündelten Meldungen der App, nur Zähler, nie Inhalte oder Gesundheitswerte): zuletzt aktiv, aktive Tage der letzten 7 und 30 Tage, meistgenutzte Bereiche und Funktionen, nie genutzte (laut Liste der App), App-Version und ob der Lovea-Import fertig ist.",
    inputSchema: { type: "object", properties: { umgebung } },
  },
  {
    name: "lumenfit_fehler",
    description: "Fehler aus der echten Nutzung (nur Zähler mit festen Namen, nie Texte oder Stacks): neue und häufigste Fehler je App-Version mit Anzahl, Anzahl Konten, erstem und letztem Tag, iOS und Gerätetyp. Dazu fehlgeschlagene Serveraufrufe je fester Route und Status. Unter 5 Konten steht einzelfall: true, das ist kein Trend. Nur Konten, die der Nutzungsmeldung zugestimmt haben.",
    inputSchema: { type: "object", properties: { umgebung, tage: { type: "integer", minimum: 1, maximum: 90, description: "Fenster in Tagen, Standard 30." } } },
  },
  {
    name: "lumenfit_auswertung",
    description: "Auswertung der Nutzung ohne App-Build: erster Griff am Tag (Tab und Funktion), Tageszeit der Starts, Sitzungsdauer, Top und Flop, häufigste Wege und Absprünge, Zeit bis zum Ziel, Abbruchstellen je Ablauf (QR-Verbinden, Studio-Suche, Essen eintragen), gesehen aber nie angetippt, Einstellungen als Stand, Tempo und Streichkandidaten (erst ab 30 Tagen Daten und mehreren Konten, Nutzung 0). Unter 5 Konten steht einzelfall: true, das ist kein Trend.",
    inputSchema: { type: "object", properties: { umgebung, tage: { type: "integer", minimum: 1, maximum: 90, description: "Fenster in Tagen, Standard 30." } } },
  },
  {
    name: "lumenfit_import_beleg",
    description: "Import-Beleg je Konto mit Lovea-Person: wann der Import fertig war, der letzte Beleg der App (je Op-Art: geholt, übernommen, roh, ausgeschlossen, unbekannt, geplant, im lokalen Speicher wiedergefunden; nur Zahlen) und der letzte Fehler (Art, Zeit, bis wohin geladen). Vergleich mit Lovea: scripts/import-vergleich.mjs.",
    inputSchema: { type: "object", properties: { umgebung } },
  },
  {
    name: "lumenfit_config_setzen",
    description: "Globale Schalter ändern (gelten für alle Konten, ein Konto-Schalter gewinnt). Merge-Patch, null entfernt. Start: profilAnlegenErlaubt (false), nameAendernTage (7). loveaVerbinden gibt es nicht global.",
    inputSchema: { type: "object", properties: { umgebung, einstellungen: { type: "object" } }, required: ["einstellungen"] },
  },
  {
    name: "lumenfit_konto_sperren",
    description: "Konto sperren (gesperrt=true, Standard) oder wieder freigeben (false). Ein gesperrtes Konto bekommt auf allen App-Wegen 403.",
    inputSchema: { type: "object", properties: { umgebung, id: kontoId, gesperrt: { type: "boolean" } }, required: ["id"] },
  },
];

function standardKey() {
  const pfade = [process.env.LUMENFIT_ADMIN_KEY_PFAD, join(homedir(), ".config", "lumenfit", "admin.key")].filter(Boolean);
  for (const p of pfade) {
    try { return readFileSync(p, "utf8").trim(); } catch {}
  }
  throw new Error("Admin-Key nicht gefunden (~/.config/lumenfit/admin.key)");
}

export async function werkzeugAufrufen(name, a = {}, { holen = fetch, key, basis = BASIS } = {}) {
  const w = WERKZEUGE.find((x) => x.name === name);
  if (!w) throw new Error(`Werkzeug unbekannt: ${name}`);
  let pfad, methode = "GET", body;
  if (name === "lumenfit_konten") pfad = "/admin/konten";
  else if (name === "lumenfit_nutzung") pfad = "/admin/nutzung";
  else if (name === "lumenfit_fehler" || name === "lumenfit_auswertung") {
    pfad = name === "lumenfit_fehler" ? "/admin/fehler" : "/admin/auswertung";
    if (a.tage !== undefined) {
      if (!Number.isInteger(a.tage) || a.tage < 1 || a.tage > 90) throw new Error("tage: ganze Zahl von 1 bis 90");
      pfad += `?tage=${a.tage}`;
    }
  }
  else if (name === "lumenfit_import_beleg") pfad = "/admin/import-beleg";
  else if (name === "lumenfit_config_setzen") [pfad, methode, body] = ["/admin/config", "PATCH", a.einstellungen];
  else {
    if (typeof a.id !== "string" || !a.id) throw new Error("id fehlt");
    pfad = `/admin/konto/${encodeURIComponent(a.id)}`;
    methode = "PATCH";
    if (name === "lumenfit_konto_sperren") body = { gesperrt: a.gesperrt ?? true };
    else {
      body = {};
      if (a.einstellungen !== undefined) body.einstellungen = a.einstellungen;
      if (a.lovea_person !== undefined) body.lovea_person = a.lovea_person;
      if (a.lovea_import_zuruecksetzen === true) body.lovea_import = null;
      if (!Object.keys(body).length) throw new Error("mindestens einstellungen, lovea_person oder lovea_import_zuruecksetzen angeben");
    }
  }
  const url = basis[a.umgebung ?? "live"];
  if (!url) throw new Error("umgebung: test oder live");
  const r = await holen(url + pfad, {
    method: methode,
    headers: { "X-Admin-Key": key ?? standardKey(), "content-type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await r.text();
  if (!r.ok) throw new Error(`Server ${r.status}: ${text.slice(0, 300)}`);
  return JSON.parse(text);
}

async function antworten(msg) {
  const { id, method, params } = msg;
  if (method === "initialize") {
    return {
      protocolVersion: params?.protocolVersion ?? "2025-06-18",
      capabilities: { tools: {} },
      serverInfo: { name: "lumenfit", version: "1.0.0" },
      instructions: "Verwaltung des Lumen-Fit-Servers (Cloudflare-Worker): Konten ansehen, Nutzung je Konto (lumenfit_nutzung), Fehler (lumenfit_fehler), Auswertung (lumenfit_auswertung), Schalter je Konto und global ändern, Konten sperren. Änderungen wirken ohne App-Build. loveaVerbinden nur für Ahmed (lovea_person ahmed) und Annika (annika) setzen, sonst für niemanden.",
    };
  }
  if (method === "ping") return {};
  if (method === "tools/list") return { tools: WERKZEUGE };
  if (method === "tools/call") {
    try {
      const e = await werkzeugAufrufen(params?.name, params?.arguments);
      return { content: [{ type: "text", text: JSON.stringify(e, null, 1) }] };
    } catch (e) {
      return { content: [{ type: "text", text: e.message }], isError: true };
    }
  }
  if (id !== undefined) throw Object.assign(new Error(`Methode unbekannt: ${method}`), { code: -32601 });
}

if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const senden = (o) => process.stdout.write(JSON.stringify(o) + "\n");
  createInterface({ input: process.stdin }).on("line", async (zeile) => {
    if (!zeile.trim()) return;
    let msg;
    try { msg = JSON.parse(zeile); } catch { return senden({ jsonrpc: "2.0", id: null, error: { code: -32700, message: "Parse error" } }); }
    if (msg.id === undefined) return;
    try {
      senden({ jsonrpc: "2.0", id: msg.id, result: await antworten(msg) });
    } catch (e) {
      senden({ jsonrpc: "2.0", id: msg.id, error: { code: e.code ?? -32603, message: e.message } });
    }
  });
}
