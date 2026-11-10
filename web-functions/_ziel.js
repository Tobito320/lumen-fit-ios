// Pages Functions (Cloudflare, kostenlos): leiten Kontakt und Einladungen an den Lumen-Fit-Server weiter,
// damit die öffentliche Seite nur lumen-fit.pages.dev zeigt und die Server-Adresse nicht im Browser steht.
export const SERVER = "https://lumen-fit-live.ahmedhdplay12345.workers.dev";

export async function weiter(request, pfad, env = {}) {
  const kopf = new Headers();
  for (const k of ["content-type", "accept-language"]) {
    const v = request.headers.get(k);
    if (v) kopf.set(k, v);
  }
  kopf.set("origin", "https://lumen-fit.pages.dev");
  // Der Server sieht sonst nur die Cloudflare-Leitung: die echte IP (für die Drossel) nur mit dem geteilten Schlüssel weitergeben.
  const ip = request.headers.get("cf-connecting-ip");
  if (env.PROXY_SCHLUESSEL && ip) { kopf.set("x-lumen-proxy", env.PROXY_SCHLUESSEL); kopf.set("x-lumen-ip", ip); }
  const r = await fetch(SERVER + pfad, {
    method: request.method,
    headers: kopf,
    body: request.method === "POST" ? await request.text() : undefined,
    redirect: "manual",
  });
  const aus = new Headers();
  for (const k of ["content-type", "content-security-policy", "cache-control", "location"]) {
    const v = r.headers.get(k);
    if (v) aus.set(k, v);
  }
  return new Response(r.body, { status: r.status, headers: aus });
}
