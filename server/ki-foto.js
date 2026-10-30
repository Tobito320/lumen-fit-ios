// Quelle: Lovea server/ki.js (nur die Foto-Mahlzeit: Schema, Anweisung, Berechnung, Fehlerarten; ohne Durable Object, Portionsgedächtnis und Kostenbuch).
// POST /ki/foto: Foto einer Mahlzeit -> Zutaten mit Gramm und Nährwerten (OpenAI Responses API).
// Aus bis der Schalter `kiFotoErlaubt` (Konto oder global) true ist UND das Secret OPENAI_API_KEY gesetzt ist. Gesundheitsdaten gehen nur an OpenAI.
// Nichts wird geloggt: weder Bild noch Antwort noch Schlüssel. Reine Funktion ohne cloudflare:workers-Import -> unter Node testbar.

export const MODELL = "gpt-6-luna";
export const TAGESLIMIT = 40;
const OPENAI_URL = "https://api.openai.com/v1/responses";
const BODY_MAX = 1_600_000; // Zeichen des Anfragekörpers
const BILD_MAX = 1_400_000; // Base64-Zeichen (etwa 1 MB Bild)
const MIMES = new Set(["image/jpeg", "image/png", "image/webp"]);
const MAHLZEITEN = { fruehstueck: "Frühstück", mittag: "Mittagessen", abend: "Abendessen", snack: "Snack" };
const ALKOHOL = /bier|wein|sekt|vodka|wodka|rum|whisk|gin\b|likör|likoer|schnaps|alkohol|cocktail/i;
const UNSICHERHEIT = { hoch: 0.1, mittel: 0.2, niedrig: 0.35 };

// Fehlerart = Schlüssel `fehler`; die App ordnet sie nach Schlüssel, ersatzweise nach Status.
const nein = (status, fehler, extra = {}) => Response.json({ fehler, ...extra }, { status });
const r1 = (n) => Math.round(n * 10) / 10;

function zahl(wert, min, max, fallback = 0) {
  const n = Number(wert);
  if (wert === null || wert === undefined || wert === "" || !Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}

function text(wert, max) {
  return String(wert ?? "").replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim().slice(0, max);
}

const KOMPONENTE = {
  type: "object",
  additionalProperties: false,
  required: ["name", "gramm", "kcal_pro_100g", "protein_pro_100g", "kohlenhydrate_pro_100g", "fett_pro_100g", "sicherheit"],
  properties: {
    name: { type: "string" },
    gramm: { type: "number" },
    kcal_pro_100g: { type: "number" },
    protein_pro_100g: { type: "number" },
    kohlenhydrate_pro_100g: { type: "number" },
    fett_pro_100g: { type: "number" },
    sicherheit: { type: "string", enum: ["hoch", "mittel", "niedrig"] },
  },
};
const VERSTECKT = {
  type: "object",
  additionalProperties: false,
  required: ["name", "gramm", "kcal_pro_100g"],
  properties: { name: { type: "string" }, gramm: { type: "number" }, kcal_pro_100g: { type: "number" } },
};
export const ESSEN_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["ist_essen", "items", "versteckt", "frage", "bemerkung"],
  properties: {
    ist_essen: { type: "boolean" },
    items: { type: "array", items: KOMPONENTE },
    versteckt: { type: "array", items: VERSTECKT },
    frage: { type: ["string", "null"] },
    bemerkung: { type: "string" },
  },
};

export const ESSEN_ANWEISUNG = `Du bist die Ernährungs-Analyse in der Lumen-Fit-App. Du bekommst das Foto einer Mahlzeit oder eines Getränks.

Regeln:
1. Schätze für jede sichtbare Komponente die Menge in Gramm, die WIRKLICH auf dem Foto liegt. Nimm nicht die übliche Standardportion. Nutze Tellergröße, Besteck, Hand, Glas oder Verpackung als Maßstab. Getränke: 1 ml = 1 g.
2. Gib pro 100 g an: Kalorien, Eiweiß, Kohlenhydrate und Fett des Lebensmittels so, wie es auf dem Foto zubereitet ist (gekocht, gebraten, roh).
3. Nicht Sichtbares, aber sehr wahrscheinlich Enthaltenes (Bratöl, Butter, Soße, Dressing, Zucker im Getränk) kommt NICHT in items, sondern in versteckt, mit einer vorsichtigen Mengenannahme. Wenn nichts davon plausibel ist, bleibt die Liste leer.
4. Gibt der Nutzer einen Hinweis (zum Beispiel eine Menge oder ein Gericht), hat er Vorrang vor deiner Schätzung.
5. Zeigt das Foto kein Essen oder Trinken, setze ist_essen auf false und lass items und versteckt leer.
6. sicherheit: hoch, mittel oder niedrig je Komponente. Ist eine wichtige Komponente niedrig und würde eine Rückfrage die Schätzung klar verbessern, stelle genau EINE kurze Frage in frage. Sonst ist frage null.
7. Namen sind deutsch und kurz, zum Beispiel "Basmatireis, gekocht". Fasse Kleinkram (Gewürze, Garnitur) nicht einzeln auf.
8. bemerkung: ein kurzer, neutraler Satz (höchstens 120 Zeichen). Keine Bewertung, kein Lob, keine Schuldzuweisung.`;

// Rechnet aus Gramm und Nährwerten pro 100 g die Werte der Portion. Passen Kalorien und Makros nicht zusammen (mehr als 30 % Abweichung),
// gewinnen die Makros, außer bei Alkohol, der nicht in den Makros steckt.
export function itemBerechnen(roh) {
  const gramm = Math.round(zahl(roh?.gramm, 1, 2000, 100));
  const p = zahl(roh?.protein_pro_100g, 0, 100, 0);
  const k = zahl(roh?.kohlenhydrate_pro_100g, 0, 100, 0);
  const f = zahl(roh?.fett_pro_100g, 0, 100, 0);
  const name = text(roh?.name, 60) || "Unbekannt";
  let kcal100 = zahl(roh?.kcal_pro_100g, 0, 900, 0);
  const ausMakros = 4 * p + 4 * k + 9 * f;
  if (ausMakros > 0 && !ALKOHOL.test(name) && Math.abs(kcal100 - ausMakros) > 0.3 * ausMakros) kcal100 = ausMakros;
  const sicherheit = roh?.sicherheit in UNSICHERHEIT ? roh.sicherheit : "mittel";
  return {
    name,
    gramm,
    kcal_pro_100g: r1(kcal100),
    protein_pro_100g: r1(p),
    kohlenhydrate_pro_100g: r1(k),
    fett_pro_100g: r1(f),
    kcal: Math.round((gramm * kcal100) / 100),
    protein: r1((gramm * p) / 100),
    kohlenhydrate: r1((gramm * k) / 100),
    fett: r1((gramm * f) / 100),
    sicherheit,
  };
}

export function versteckBerechnen(roh) {
  const gramm = Math.round(zahl(roh?.gramm, 1, 200, 10));
  const kcal100 = zahl(roh?.kcal_pro_100g, 0, 900, 0);
  return { name: text(roh?.name, 60) || "Unbekannt", gramm, kcal: Math.round((gramm * kcal100) / 100) };
}

export function gesamtBerechnen(items, versteckt) {
  const summe = (liste, feld) => liste.reduce((s, i) => s + i[feld], 0);
  const kcal = summe(items, "kcal");
  const spanne = items.reduce((s, i) => s + i.kcal * (UNSICHERHEIT[i.sicherheit] ?? 0.2), 0);
  const vKcal = summe(versteckt, "kcal");
  return {
    kcal,
    kcal_min: Math.max(0, Math.round(kcal - spanne)),
    kcal_max: Math.round(kcal + spanne + vKcal),
    protein: r1(summe(items, "protein")),
    kohlenhydrate: r1(summe(items, "kohlenhydrate")),
    fett: r1(summe(items, "fett")),
    versteckt_kcal: vKcal,
    kcal_mit_versteckt: kcal + vKcal,
  };
}

function textAusAntwort(j) {
  if (typeof j?.output_text === "string") return j.output_text;
  const teile = [];
  for (const item of j?.output ?? []) {
    if (item?.type !== "message") continue;
    for (const c of item.content ?? []) if (c?.type === "output_text" && typeof c.text === "string") teile.push(c.text);
  }
  return teile.join("");
}

// OpenAI-Fehler -> Fehlerart der App (Status wie in der Vorlage).
async function fehlerAntwort(res) {
  let j = null;
  try { j = await res.json(); } catch { /* kein JSON */ }
  const code = j?.error?.code ?? j?.error?.type;
  if (res.status === 401 || res.status === 403) return nein(503, "nichtEingerichtet");
  if (res.status === 429) {
    if (code === "insufficient_quota" || code === "billing_hard_limit_reached") return nein(503, "guthaben");
    return nein(429, "zuVieleAnfragen");
  }
  return nein(502, "kiFehler");
}

const berlinTag = (jetzt) => new Intl.DateTimeFormat("sv-SE", { timeZone: "Europe/Berlin" }).format(jetzt);

// Ein Foto zählt, sobald es angenommen ist; schlägt es danach fehl, wird es zurückgegeben. Ein Statement: kein Zählen über das Limit, auch parallel.
const zaehlen = (env, konto, tag) => env.DB.prepare(
  "INSERT INTO ki_nutzung (konto, tag, n) VALUES (?, ?, 1) ON CONFLICT (konto, tag) DO UPDATE SET n = n + 1 WHERE n < ? RETURNING n",
).bind(konto, tag, TAGESLIMIT).first();
const zurueck = (env, konto, tag) => env.DB.prepare("UPDATE ki_nutzung SET n = MAX(0, n - 1) WHERE konto = ? AND tag = ?").bind(konto, tag).run();

/**
 * hilfen: { kontoPruefen, zusammen, globaleConfig } aus index.js (kein Import von dort, sonst ein Kreis).
 * holen: der Abruf zu OpenAI; Standard ist das globale fetch. Nie die Dienstbindung LOVEA, sonst ginge der Schlüssel an den falschen Worker.
 */
export async function kiFoto(request, env, hilfen, holen = (u, o) => fetch(u, o), jetzt = new Date()) {
  const { konto, antwort } = await hilfen.kontoPruefen(request, env);
  if (antwort) return antwort;
  if (hilfen.zusammen(konto, await hilfen.globaleConfig(env)).kiFotoErlaubt !== true) return nein(403, "nichtErlaubt");
  if (!env.OPENAI_API_KEY) return nein(503, "nichtEingerichtet");

  if (Number(request.headers.get("content-length")) > BODY_MAX) return nein(413, "bildZuGross");
  const roh = await request.text();
  if (roh.length > BODY_MAX) return nein(413, "bildZuGross");
  let b;
  try { b = JSON.parse(roh); } catch { return nein(400, "ungueltig"); }
  if (!b || typeof b !== "object" || Array.isArray(b)) return nein(400, "ungueltig");
  const bild = typeof b.bild === "string" ? b.bild.replace(/\s+/g, "") : "";
  const mime = b.mime ?? "image/jpeg";
  if (!bild || !MIMES.has(mime) || !/^[A-Za-z0-9+/]+={0,2}$/.test(bild)) return nein(400, "ungueltig");
  if (bild.length > BILD_MAX) return nein(413, "bildZuGross");
  const mahlzeit = b.mahlzeit in MAHLZEITEN ? b.mahlzeit : null;
  const hinweis = text(b.hinweis, 300);

  const tag = berlinTag(jetzt);
  const gezaehlt = await zaehlen(env, konto.id, tag);
  if (!gezaehlt) return nein(429, "tageslimit", { max: TAGESLIMIT });

  const anfrage = ["Analysiere das Foto dieser Mahlzeit."];
  if (mahlzeit) anfrage.push(`Mahlzeit: ${MAHLZEITEN[mahlzeit]}.`);
  if (hinweis) anfrage.push(`Hinweis des Nutzers (hat Vorrang): ${hinweis}`);

  let res;
  try {
    res = await holen(OPENAI_URL, {
      method: "POST",
      headers: { Authorization: `Bearer ${env.OPENAI_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: MODELL,
        store: false,
        instructions: ESSEN_ANWEISUNG,
        input: [{ role: "user", content: [{ type: "input_text", text: anfrage.join("\n") }, { type: "input_image", image_url: `data:${mime};base64,${bild}`, detail: "auto" }] }],
        reasoning: { effort: "low" },
        max_output_tokens: 2500,
        prompt_cache_key: "lumen-essen-v1",
        text: { format: { type: "json_schema", name: "essen", strict: true, schema: ESSEN_SCHEMA } },
      }),
      signal: AbortSignal.timeout(60_000),
    });
  } catch {
    await zurueck(env, konto.id, tag);
    return nein(502, "netz");
  }
  if (!res.ok) {
    await zurueck(env, konto.id, tag);
    return fehlerAntwort(res);
  }
  let ergebnis;
  try {
    const j = await res.json();
    if (j?.status === "incomplete" || j?.error) throw new Error("unvollstaendig");
    ergebnis = JSON.parse(textAusAntwort(j));
  } catch {
    await zurueck(env, konto.id, tag);
    return nein(502, "kiFehler");
  }
  const rest = Math.max(0, TAGESLIMIT - gezaehlt.n);
  const items = Array.isArray(ergebnis?.items) ? ergebnis.items.slice(0, 12).map(itemBerechnen) : [];
  const leer = { ok: true, ist_essen: false, items: [], versteckt: [], gesamt: gesamtBerechnen([], []), frage: null, bemerkung: text(ergebnis?.bemerkung, 120), rest, modell: MODELL };
  if (!ergebnis?.ist_essen || items.length === 0) return Response.json(leer);
  const versteckt = Array.isArray(ergebnis.versteckt) ? ergebnis.versteckt.slice(0, 5).map(versteckBerechnen) : [];
  return Response.json({
    ok: true,
    ist_essen: true,
    items,
    versteckt,
    gesamt: gesamtBerechnen(items, versteckt),
    frage: ergebnis.frage ? text(ergebnis.frage, 160) : null,
    bemerkung: text(ergebnis.bemerkung, 120),
    rest,
    modell: MODELL,
  });
}
