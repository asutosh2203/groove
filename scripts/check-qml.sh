#!/usr/bin/env bash
#
# Lint every QML and JavaScript file under contents/ with qmllint (one tool handles `.pragma library` JS too).
#
# Fails on: qmllint errors (a non-zero exit, e.g. a syntax error), any [import] warning (a missing module would
# silently weaken every other check), and a warning count above the committed baseline (a ratchet: warnings may
# only go down). When the count drops below the baseline it says so, so the baseline can be lowered.
#
# The baseline in .github/qmllint-baseline.txt is defined by the qmllint in the CI container (pinned Arch snapshot);
# a different local Qt can count slightly differently. It only ever goes down.
#
# Env: QMLLINT (binary), QML_ROOT (tree to lint), QMLLINT_LOG (where the full output is written).
set -uo pipefail

root="${QML_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$root"

qmllint="${QMLLINT:-}"
if [ -z "$qmllint" ]; then
    if command -v qmllint >/dev/null 2>&1; then qmllint=qmllint; else qmllint=/usr/lib/qt6/bin/qmllint; fi
fi
log="${QMLLINT_LOG:-${TMPDIR:-/tmp}/qmllint.log}"
baseline_file=".github/qmllint-baseline.txt"
baseline="$(tr -d '[:space:]' < "$baseline_file" 2>/dev/null || true)"
case "$baseline" in ''|*[!0-9]*) echo "::error::$baseline_file must hold a single number" >&2; exit 2 ;; esac

files="$(find contents \( -name '*.qml' -o -name '*.js' \) | sort)"
count="$(printf '%s\n' "$files" | grep -c .)"
if [ "$count" -eq 0 ]; then echo "::error::no QML or JS files found under contents/" >&2; exit 2; fi

printf '%s\n' "$files" | xargs "$qmllint" > "$log" 2>&1
rc=$?

errors="$(grep -c '^Error' "$log" || true)"
warnings="$(grep -c '^Warning' "$log" || true)"
imports="$(grep -c '\[import\]' "$log" || true)"
qml="$(printf '%s\n' "$files" | grep -c '\.qml$' || true)"
js="$(printf '%s\n' "$files" | grep -c '\.js$' || true)"
weather="$(printf '%s\n' "$files" | grep -c '/weather/' || true)"

echo "qmllint: $("$qmllint" --version 2>&1 | head -n1)"
echo "files: $count ($qml QML, $js JS; $weather under weather/)"
echo "errors: $errors   warnings: $warnings (baseline $baseline)   [import] warnings: $imports   exit code: $rc"

status=0
if [ "$rc" -ne 0 ] || [ "$errors" -gt 0 ]; then
    echo "::error::qmllint reported errors (exit code $rc)"
    grep -E '^Error|\[syntax\]' "$log" | head -n 20
    status=1
fi
if [ "$imports" -gt 0 ]; then
    echo "::error::$imports [import] warning(s): a module could not be loaded, so type checks are incomplete"
    grep '\[import\]' "$log" | head -n 20
    status=1
fi
if [ "$warnings" -gt "$baseline" ]; then
    echo "::error::qmllint warnings went up: $warnings > baseline $baseline. Fix the new warnings; the baseline only ever goes down."
    status=1
elif [ "$warnings" -lt "$baseline" ]; then
    echo "::notice::qmllint warnings dropped to $warnings (baseline $baseline): lower .github/qmllint-baseline.txt to $warnings"
fi
exit "$status"
