#!/usr/bin/env bash
# Typnamen-Gate: ein Typname darf im ganzen Ziel nur einmal vorkommen (neun Module bauen parallel und sehen einander nicht;
# ein doppelter Name merkt sonst erst der Compiler in CI). Prüft Deklarationen ohne Einrückung, ohne private/fileprivate.
# Aufruf: bash scripts/typnamen-doppelt.sh [Ordner...]  (Standard: LumenFit/Sources Gemeinsam LumenFitWidgets/Sources LumenFit/Tests)
# Exit 0 = eindeutig, 1 = Doppelte (Namen und Pfade werden genannt).
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
if [ "$#" -gt 0 ]; then ordner=("$@"); else ordner=(LumenFit/Sources Gemeinsam LumenFitWidgets/Sources LumenFit/Tests); fi
pfade=(); for o in "${ordner[@]}"; do pfade+=("$o/*.swift"); done
treffer=$(git grep -n -E --untracked -e '^(@[A-Za-z]+ )*((public|internal|final|open|nonisolated) )*(struct|class|enum|protocol|actor|typealias) [A-Z][A-Za-z0-9_]*' -- "${pfade[@]}" 2>/dev/null \
  | grep -v -E ':[0-9]+:[[:space:]]*(private|fileprivate) ' \
  | sed -E 's/^([^:]+):([0-9]+):.*(struct|class|enum|protocol|actor|typealias) ([A-Z][A-Za-z0-9_]*).*/\4 \1:\2/')
doppelt=$(echo "$treffer" | awk 'NF { n[$1]++; o[$1] = o[$1] " " $2 } END { for (k in n) if (n[k] > 1) print k ":" o[k] }' | sort)
if [ -n "$doppelt" ]; then echo "Doppelte Typnamen:"; echo "$doppelt"; exit 1; fi
echo "sauber: Typnamen eindeutig ($(echo "$treffer" | awk 'NF' | wc -l | tr -d ' ') Typen)"
