#!/usr/bin/env bash
#
# Compile shaders/*.frag to contents/ui/shaders/*.frag.qsb (Qt 6 qsb, every backend Qt Quick may use) and keep a stamp in
# shaders/qsb.sha256: the sha256 of every source and of every compiled .qsb.
#   scripts/build-shaders.sh           rebuild the .qsb files and the stamp
#   scripts/build-shaders.sh --check   CI: fail if the committed sources or .qsb files do not match the stamp, or a source no longer compiles
# --check also does a byte-for-byte rebuild comparison, which only holds on the machine that built the .qsb: the CI container's
# qsb 6.12.0 emits different bytes for the same source, so CI sets QSB_STAMP_ONLY=1 and relies on the stamp. The stamp catches a
# stale, edited or swapped source or .qsb without comparing bytes across machines. Rebuild and commit after every shader edit.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
qsb="${QSB:-}"
if [ -z "$qsb" ]; then
    if command -v qsb >/dev/null 2>&1; then qsb=qsb; else qsb=/usr/lib/qt6/bin/qsb; fi
fi
out=contents/ui/shaders
stamp=shaders/qsb.sha256
mode="${1:-build}"
case "$mode" in build|--check) ;; *) echo "usage: $0 [--check]" >&2; exit 2 ;; esac

# cmp lives in diffutils, which the CI base image does not have; coreutils' sha256sum is always there.
same() { [ "$(sha256sum < "$1")" = "$(sha256sum < "$2")" ]; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
status=0
for src in shaders/*.frag; do
    name="$(basename "$src")"
    "$qsb" --qt6 -o "$work/$name.qsb" "$src"
done
# The stamp lines: every source, then every compiled .qsb, as they sit in the tree.
make_stamp() { (cd shaders && sha256sum -- *.frag); (cd "$out" && sha256sum -- *.qsb); }

if [ "$mode" = build ]; then
    mkdir -p "$out"
    cp "$work"/*.qsb "$out"/
    make_stamp > "$stamp"
    echo "built: $(ls "$work"/*.qsb | wc -l) shader(s), $("$qsb" --version)"
    exit 0
fi

make_stamp > "$work/stamp" || { echo "::error::a shader source or its .qsb is missing"; exit 1; }
same "$work/stamp" "$stamp" || { echo "::error::$stamp does not match the committed shaders/*.frag and $out/*.qsb: run scripts/build-shaders.sh and commit the result"; status=1; }
if [ -z "${QSB_STAMP_ONLY:-}" ]; then
    for built in "$work"/*.qsb; do
        name="$(basename "$built")"
        same "$built" "$out/$name" || { echo "::error::$out/$name is not what its source compiles to ($("$qsb" --version)): run scripts/build-shaders.sh and commit the result"; status=1; }
    done
fi
if [ "$status" -eq 0 ]; then
    if [ -n "${QSB_STAMP_ONLY:-}" ]; then echo "shaders: stamp matches the sources and .qsb files, and the sources compile (stamp only)"; else echo "shaders: committed .qsb matches its source (byte-for-byte)"; fi
fi
exit "$status"
