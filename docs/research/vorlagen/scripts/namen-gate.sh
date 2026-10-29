#!/usr/bin/env bash
# Namens-Gate: kein Personenname und kein Studio im Quelltext, in Tests, Fixtures oder Commit-Texten.
# Die Namensliste steht NICHT im Git: Datei ~/.config/lumen-fit/namen.txt (ein Wort je Zeile) oder Umgebungsvariable NAMEN_GATE
# (Wörter mit | getrennt). Ausgabe nennt nur Fundstellen (Pfad:Zeile), nie das Wort. Exit 0 = sauber, 1 = Fund, 2 = Liste fehlt im Streng-Modus.
# Gilt in jedem Worktree. NAMEN_STRENG=1 verlangt die Liste (ci-fenster.sh setzt es vor dem öffentlichen Fenster).
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
LISTE="${NAMEN_DATEI:-$HOME/.config/lumen-fit/namen.txt}"
muster="${NAMEN_GATE:-}"
if [ -z "$muster" ] && [ -f "$LISTE" ]; then
  muster=$(grep -v '^[[:space:]]*\(#\|$\)' "$LISTE" | paste -sd'|' -)
fi
if [ -z "$muster" ]; then
  if [ "${NAMEN_STRENG:-0}" = "1" ]; then echo "FEHLT: Namensliste (Streng-Modus)"; exit 2; fi
  echo "Hinweis: keine Namensliste, Namens-Gate übersprungen"
  exit 0
fi
fund=0
# Arbeitsbaum: nur die Code-Ordner (SPEC.md zitiert den Auftrag 1:1 und ist ausgenommen)
treffer=$(git grep -n -i -w -E --untracked -e "$muster" -- LumenFit Gemeinsam LumenFitWidgets 2>/dev/null | cut -d: -f1,2)
if [ -n "$treffer" ]; then echo "FUND im Arbeitsbaum (Pfad:Zeile):"; echo "$treffer"; fund=1; fi
# Commit-Texte und Autorzeilen
if git log --all --format='%an%n%B' | grep -q -i -w -E "$muster"; then echo "FUND in Commit-Texten"; fund=1; fi
[ "$fund" = "0" ] && echo "sauber: Namens-Gate"
exit "$fund"
