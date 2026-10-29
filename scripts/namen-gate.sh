#!/usr/bin/env bash
# Namens-Gate: kein Personenname und kein Studio im Quelltext, in Skripten, Workflows, Tests, Fixtures oder Commit-Texten.
# Die Namensliste steht NICHT im Git: Datei ~/.config/lumen-fit/namen.txt (ein Wort je Zeile) oder Umgebungsvariable NAMEN_GATE
# (Wörter mit | getrennt). Ausgabe nennt nur Fundstellen (Pfad:Zeile oder Commit), nie das Wort. Exit 0 = sauber, 1 = Fund, 2 = Liste fehlt im Streng-Modus.
# Gilt in jedem Worktree. NAMEN_STRENG=1 verlangt die Liste (ci-fenster.sh und testflight-fenster.sh setzen es vor dem öffentlichen Fenster).
#
# Geprüft wird (Markdown ist bewusst ausgenommen: SPEC.md zitiert den Auftrag 1:1, die Docs dürfen Rollen und Namen des Auftraggebers nennen):
#   1. Arbeitsbaum: LumenFit, Gemeinsam, LumenFitWidgets, scripts, .github, project.yml (ohne *.md)
#   2. Commit-Texte und Autorzeilen aller Zweige
#   3. Historie, Dateiinhalte: jede Zeile, die ein Commit NACH scripts/namen-gate.basis hinzufügt (blockierend). Die Stände davor sind
#      eingefroren (Historie wird nie umgeschrieben); Treffer dort werden nur gezählt und gemeldet (nicht blockierend).
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
PFADE=(LumenFit Gemeinsam LumenFitWidgets scripts .github project.yml)
AUSNAHME=(':!*.md' ':!scripts/namen-gate.basis')
fund=0

# 1. Arbeitsbaum
treffer=$(git grep -n -i -w -E --untracked -e "$muster" -- "${PFADE[@]}" "${AUSNAHME[@]}" 2>/dev/null | cut -d: -f1,2)
if [ -n "$treffer" ]; then echo "FUND im Arbeitsbaum (Pfad:Zeile):"; echo "$treffer"; fund=1; fi

# 2. Commit-Texte und Autorzeilen
if git log --all --format='%an%n%B' | grep -q -i -w -E "$muster"; then echo "FUND in Commit-Texten"; fund=1; fi

# 3. Historie, Dateiinhalte
trefferZeile() { # COMMIT: 0, wenn der Commit in den geprüften Pfaden eine Zeile mit einem Namen hinzufügt
  git show --no-color --format= "$1" -- "${PFADE[@]}" "${AUSNAHME[@]}" 2>/dev/null | grep '^+' | grep -v '^+++' | grep -q -i -w -E "$muster"
}
basis=$(head -n1 scripts/namen-gate.basis 2>/dev/null || true)
if [ -n "$basis" ] && git cat-file -e "${basis}^{commit}" 2>/dev/null; then
  neu=""
  for c in $(git rev-list "$basis..HEAD"); do
    if trefferZeile "$c"; then neu="$neu $(git rev-parse --short "$c")"; fi
  done
  if [ -n "$neu" ]; then echo "FUND in neuen Commits (hinzugefügte Zeilen):$neu"; fund=1; fi
  alt=0
  for c in $(git rev-list "$basis"); do trefferZeile "$c" && alt=$((alt + 1)); done
  [ "$alt" -gt 0 ] && echo "Hinweis (nicht blockierend): $alt Commits bis zur Basis ${basis:0:7} fügen Code- oder Skriptzeilen mit einem Namen hinzu (eingefroren, nur der Besitzer-Vorname erwartet)"
else
  echo "Hinweis: scripts/namen-gate.basis fehlt oder passt nicht, Historien-Inhalte nicht geprüft"
fi

[ "$fund" = "0" ] && echo "sauber: Namens-Gate"
exit "$fund"
