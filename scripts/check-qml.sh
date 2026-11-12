#!/usr/bin/env bash
#
# Lint every QML and JavaScript file under contents/ with qmllint (one tool handles `.pragma library` JS too).
#
# Fails on:
#   - qmllint errors (a non-zero exit, e.g. a syntax error);
#   - any [import] warning (a missing module would silently weaken every other check);
#   - any FILE whose warning count is above its entry in .github/qmllint-baseline.txt (a per-file ratchet: a file with no
#     entry has a baseline of 0, so new files must be warning-free);
#   - a probe failure: qmllint can silently stop analysing a file (e.g. a `const` inside an arrow function, 6.12), which
#     makes its warnings vanish and would pass the ratchet for the wrong reason. Every QML file is therefore linted a
#     second time as a temporary copy with one unresolved name appended; qmllint must report exactly one more warning.
#
# A file that drops by more than half gets a loud "verify the analysis didn't abort" warning. Lower the baseline with
#   scripts/check-qml.sh --lower-baseline
# which only ever writes lower numbers and refuses to run while anything fails. A file that moved needs its baseline
# line renamed by hand (same count).
#
# The baseline format is one "<count> <path>" line per file with warnings; it is defined by the qmllint in the CI
# container (pinned Arch snapshot), a different local Qt can count slightly differently. It only ever goes down.
#
# Env: QMLLINT (binary), QML_ROOT (tree to lint), QMLLINT_LOG (where the full output is written).
set -uo pipefail

root="${QML_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$root"

mode=check
case "${1:-}" in
    '') ;;
    --lower-baseline) mode=lower ;;
    *) echo "usage: $0 [--lower-baseline]" >&2; exit 2 ;;
esac

qmllint="${QMLLINT:-}"
if [ -z "$qmllint" ]; then
    if command -v qmllint >/dev/null 2>&1; then qmllint=qmllint; else qmllint=/usr/lib/qt6/bin/qmllint; fi
fi
log="${QMLLINT_LOG:-${TMPDIR:-/tmp}/qmllint.log}"
baseline_file=".github/qmllint-baseline.txt"

declare -A base=()
if [ ! -f "$baseline_file" ]; then echo "::error::$baseline_file is missing" >&2; exit 2; fi
while read -r n f _; do
    case "${n:-}" in ''|'#'*) continue ;; esac
    case "$n" in *[!0-9]*) echo "::error::$baseline_file: bad line '$n $f' (expected '<count> <path>')" >&2; exit 2 ;; esac
    [ -n "${f:-}" ] || { echo "::error::$baseline_file: a count without a path" >&2; exit 2; }
    base["$f"]="$n"
done < "$baseline_file"

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

# warnings per file
declare -A cur=()
attributed=0
while read -r n f; do
    [ -n "${f:-}" ] || continue
    cur["$f"]="$n"
    attributed=$((attributed + n))
done < <(sed -nE 's/^Warning: ([^:]+):[0-9]+:[0-9]+:.*/\1/p' "$log" | sort | uniq -c | awk '{print $1, $2}')

base_total=0
for f in "${!base[@]}"; do base_total=$((base_total + base[$f])); done

echo "qmllint: $("$qmllint" --version 2>&1 | head -n1)"
echo "files: $count ($qml QML, $js JS; $weather under weather/)"
echo "errors: $errors   warnings: $warnings (baseline $base_total)   [import] warnings: $imports   exit code: $rc"

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
if [ "$attributed" -ne "$warnings" ]; then
    echo "::error::$((warnings - attributed)) warning line(s) could not be attributed to a file"
    status=1
fi

# Per-file ratchet.
declare -A next=()
all_files="$(printf '%s\n' "${!cur[@]}" "${!base[@]}" | sort -u)"
while IFS= read -r f; do
    [ -n "$f" ] || continue
    c="${cur[$f]:-0}"
    b="${base[$f]:-0}"
    if [ "$c" -gt "$b" ]; then
        echo "::error file=$f::warnings went up: $c > baseline $b. Fix the new warnings; the baseline only ever goes down (a moved file keeps its count: rename its baseline line)."
        status=1
        next["$f"]="$b"
    elif [ "$c" -lt "$b" ]; then
        echo "::notice file=$f::warnings dropped $b -> $c: lower the baseline (scripts/check-qml.sh --lower-baseline)"
        if [ $((c * 2)) -lt "$b" ]; then
            echo "::warning file=$f::warnings fell from $b to $c (more than half): verify the analysis didn't abort. qmllint can silently stop analysing a file."
        fi
        next["$f"]="$c"
    else
        next["$f"]="$c"
    fi
done <<< "$all_files"

# Probe: every QML file, as a temporary copy with an unresolved name appended, must report exactly one more warning.
# qmllint can lose part of a file, so the name is planted at three places: the top (the first member of the root), the
# middle (before the root-level member line nearest the midpoint, searching forward first) and the end. No single probe form works in every
# file (a child item is invalid in a non-Item root, a function is ignored in some files), so two forms are tried at each
# place and either one passing is enough. A place where neither works is a blind spot, listed in
# .github/qmllint-probe-exempt.txt as "<path>" (all places) or "<path>:top|mid|end": the counts there are unverifiable,
# so adding a line is a review decision. A blind spot that is not listed fails.
probe_styles=('    Item { width: __bogusProbeName }' '    function __probe() { return __bogusProbeName }')
probe_places=(top mid end)
exempt_file=".github/qmllint-probe-exempt.txt"
declare -A exempt=()
if [ -f "$exempt_file" ]; then
    while read -r f _; do
        case "${f:-}" in ''|'#'*) continue ;; esac
        exempt["$f"]=1
    done < "$exempt_file"
fi
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -r contents "$tmp/contents"
qml_files=()
probes=()
while IFS= read -r f; do
    case "$f" in *.qml) ;; *) continue ;; esac
    qml_files+=("$f")
    for place in "${probe_places[@]}"; do
        for i in "${!probe_styles[@]}"; do
            out="$tmp/$(dirname "$f")/__probe${place}${i}_$(basename "$f")"
            awk -v ins="${probe_styles[$i]}" -v place="$place" '{ l[NR] = $0 } END {
                at = 0
                if (place == "end") { for (i = NR; i > 0; i--) if (l[i] ~ /^}/) { at = i; break } }
                else if (place == "top") { for (i = 1; i <= NR; i++) if (l[i] ~ /^[A-Za-z][A-Za-z0-9_.]* \{[ \t]*$/) { at = i + 1; break } }
                else { for (i = int(NR / 2); i <= NR; i++) if (l[i] ~ /^    [A-Za-z]/) { at = i; break }; if (!at) for (i = int(NR / 2); i > 0; i--) if (l[i] ~ /^    [A-Za-z]/) { at = i; break } }
                for (i = 1; i <= NR; i++) { if (i == at) print ins; print l[i] }
            }' "$f" > "$out"
            probes+=("$out")
        done
    done
done <<< "$files"
declare -A probed=()
if [ "${#probes[@]}" -gt 0 ]; then
    "$qmllint" "${probes[@]}" > "$tmp/probe.log" 2>&1 || true
    while read -r n f; do
        [ -n "${f:-}" ] || continue
        f="${f#"$tmp"/}"
        probed["$(dirname "$f")/$(basename "$f")"]="$n"
    done < <(sed -nE 's/^Warning: ([^:]+):[0-9]+:[0-9]+:.*/\1/p' "$tmp/probe.log" | sort | uniq -c | awk '{print $1, $2}')
fi
probe_bad=0
probe_exempt=0
for f in "${qml_files[@]}"; do
    want=$(( ${cur[$f]:-0} + 1 ))
    for place in "${probe_places[@]}"; do
        ok=0
        for i in "${!probe_styles[@]}"; do
            got="${probed["$(dirname "$f")/__probe${place}${i}_$(basename "$f")"]:-0}"
            [ "$got" -eq "$want" ] && ok=1
        done
        if [ -n "${exempt[$f]:-}" ] || [ -n "${exempt["$f:$place"]:-}" ]; then
            probe_exempt=$((probe_exempt + 1))
            if [ "$ok" -eq 1 ]; then
                echo "::notice file=$f::probe ($place) now works here: remove it from $exempt_file"
            fi
        elif [ "$ok" -ne 1 ]; then
            echo "::error file=$f::probe failed at the $place of the file (an unresolved name planted there should add exactly one warning): qmllint has silently stopped analysing part of this file, so its warning count means nothing"
            probe_bad=$((probe_bad + 1))
            status=1
        fi
    done
done
echo "probe: ${#qml_files[@]} QML files probed at ${#probe_places[@]} places, $probe_bad failed, $probe_exempt exempt (unverifiable: $exempt_file)"

if [ "$mode" = lower ]; then
    if [ "$status" -ne 0 ]; then
        echo "::error::not lowering the baseline while the check fails"
        exit "$status"
    fi
    {
        for f in "${!next[@]}"; do
            [ "${next[$f]}" -gt 0 ] && echo "${next[$f]} $f"
        done
    } | sort -k2 > "$baseline_file"
    echo "baseline written: $(awk '{s += $1} END {print s + 0}' "$baseline_file") warnings in $(grep -c . "$baseline_file") files"
fi
exit "$status"
