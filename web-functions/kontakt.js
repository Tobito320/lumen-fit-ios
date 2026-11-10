import { weiter } from "./_ziel.js";
// POST /kontakt -> Server /kontakt (Drossel und Prüfung macht der Server).
export const onRequestPost = ({ request, env }) => weiter(request, "/kontakt", env);
