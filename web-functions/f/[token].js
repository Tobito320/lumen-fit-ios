import { weiter } from "../_ziel.js";
// GET /f/<Token> -> Einladungsseite des Servers (öffnet Lumen Fit oder zeigt den Store-Link).
export const onRequestGet = ({ request, params }) =>
  /^[A-Za-z0-9_-]{8,200}$/.test(params.token) ? weiter(request, "/f/" + params.token) : new Response("Not found", { status: 404 });
