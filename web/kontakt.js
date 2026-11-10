// Kontaktformular: schickt Text und freiwillige Antwort-Adresse als JSON an den Lumen-Fit-Server (POST /kontakt). Keine Cookies, kein Speicher im Browser.
"use strict";
(() => {
  const form = document.getElementById("kontakt-form");
  if (!form) return;
  const status = document.getElementById("kontakt-status");
  const knopf = form.querySelector("button");
  const en = document.documentElement.lang === "en";
  const T = en
    ? { sendet: "Sending …", ok: "Thanks! Your message has arrived.", kurz: "Please write at least 10 characters.", viele: "Too many messages. Please try again in an hour.", adresse: "Please check the reply address.", fehler: "That didn't work. Please try again later." }
    : { sendet: "Wird gesendet …", ok: "Danke! Deine Nachricht ist angekommen.", kurz: "Bitte schreib mindestens 10 Zeichen.", viele: "Zu viele Nachrichten. Versuch es in einer Stunde nochmal.", adresse: "Bitte prüf die Adresse für die Antwort.", fehler: "Das hat nicht geklappt. Versuch es später nochmal." };
  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const text = form.text.value.trim();
    if (text.length < 10) { status.textContent = T.kurz; return; }
    knopf.disabled = true;
    status.textContent = T.sendet;
    try {
      const r = await fetch(form.dataset.ziel, {
        method: "POST", headers: { "content-type": "application/json" }, credentials: "omit", referrerPolicy: "no-referrer",
        body: JSON.stringify({ text, antwort: form.antwort.value.trim() }),
      });
      if (r.status === 201) { form.reset(); status.textContent = T.ok; }
      else if (r.status === 400) status.textContent = (await r.json().catch(() => ({}))).fehler === "antwort" ? T.adresse : T.kurz;
      else status.textContent = r.status === 429 ? T.viele : T.fehler;
    } catch {
      status.textContent = T.fehler;
    } finally {
      knopf.disabled = false;
    }
  });
})();
