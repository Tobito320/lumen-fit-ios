// Gym-Coach-Wege des Servers direkt aufrufen (ohne claude.ai), z. B. zum Prüfen. Schlüssel aus ~/.config/lumenfit/coach.key, wird nie ausgegeben.
// node scripts/coach-ruf.mjs <test|live> <GET|POST> </coach/plan|/coach/verlauf|/coach/uebungen?suche=..|/coach/vorschlag|/coach/anwenden|/coach/rueckgaengig> ['{json}']
import fs from "node:fs";
const [env, m, pfad, body] = process.argv.slice(2);
if (!["test", "live"].includes(env) || !m || !pfad?.startsWith("/coach/")) { console.error("Aufruf: node scripts/coach-ruf.mjs test|live GET|POST /coach/... ['{json}']"); process.exit(2); }
const key = fs.readFileSync(process.env.HOME + "/.config/lumenfit/coach.key", "utf8").trim();
const r = await fetch(`https://lumen-fit-${env}.ahmedhdplay12345.workers.dev${pfad}`, { method: m, headers: { "X-Coach-Key": key, "content-type": "application/json" }, body });
console.log(r.status, await r.text());
process.exit(r.ok ? 0 : 1);
