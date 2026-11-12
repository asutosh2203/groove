#!/usr/bin/env bash
#
# Measure what plasmashell costs while the island does (or doesn't do) something.
# Read-only towards the system: it only reads /proc, and nvidia-smi if present.
#
#   scripts/perf-baseline.sh <label> [duration_s=60] [runs=3]
#   scripts/perf-baseline.sh frames-on     # enable Qt render timing for plasmashell (restarts it)
#   scripts/perf-baseline.sh frames-off    # revert that (restarts plasmashell)
#
# Per run it prints plasmashell CPU % (of one core, all threads), the busiest threads, RSS, GPU stats,
# and frames/s when render timing is on. A median over the runs is printed at the end and everything is
# appended to perf/results/ (gitignored).
#
# Frames/s: Qt prints one "Frame rendered ..." line per rendered frame when QSG_RENDER_TIMING=1. `frames-on`
# puts that variable in the systemd user environment and restarts plasmashell; `frames-off` removes it again.
# The count covers every plasmashell window (panels, desktop, popups), so compare like with like.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
results="$root/perf/results"
unit=plasma-plasmashell.service

if [ "${1:-}" = "frames-on" ]; then
    systemctl --user set-environment QSG_RENDER_TIMING=1
    systemctl --user restart "$unit"
    echo "Render timing ON for plasmashell. Run 'frames-off' when finished."
    exit 0
fi
if [ "${1:-}" = "frames-off" ]; then
    systemctl --user unset-environment QSG_RENDER_TIMING
    systemctl --user restart "$unit"
    echo "Render timing OFF; plasmashell restarted."
    exit 0
fi

label="${1:?usage: perf-baseline.sh <label> [duration_s] [runs] | frames-on | frames-off}"
duration="${2:-60}"
runs="${3:-3}"
pid="$(pgrep -x plasmashell | head -n1 || true)"
[ -n "$pid" ] || { echo "plasmashell is not running" >&2; exit 1; }
hz="$(getconf CLK_TCK)"
frames_on=0
systemctl --user show-environment | grep -q '^QSG_RENDER_TIMING=' && frames_on=1
nvidia=0
command -v nvidia-smi >/dev/null && nvidia=1
mkdir -p "$results"
out="$results/$(date +%Y%m%d-%H%M%S)-${label// /_}.txt"

# Which GPU does plasmashell draw on? Look at the render nodes and vendor device files it holds open,
# then map each render node to its kernel driver (amdgpu / nvidia / i915 ...).
gpu_driver="$(
    for fd in /proc/"$pid"/fd/*; do
        target="$(readlink "$fd" 2>/dev/null || true)"
        case "$target" in
            /dev/dri/renderD*) node="${target##*/}"; echo "$node($(basename "$(readlink -f /sys/class/drm/"$node"/device/driver 2>/dev/null)"))" ;;
            /dev/nvidia0) echo "nvidia0-device-open" ;;
        esac
    done | sort | uniq -c | tr -s ' ' | tr '\n' ';'
)"

# Total CPU ticks (user+system) of every thread, summed per thread name: "name ticks" lines.
thread_ticks() {
    local t
    for t in /proc/"$pid"/task/*/stat; do
        [ -r "$t" ] || continue
        # The name is in parentheses and may contain spaces, so cut around the last ')'.
        awk '{ s=$0; i=index(s,"("); j=0; for(k=length(s);k>0;k--) if (substr(s,k,1)==")") { j=k; break }
               name=substr(s,i+1,j-i-1); rest=substr(s,j+2); n=split(rest,f," ");
               gsub(/ /,"_",name); print name, f[12]+f[13] }' "$t" 2>/dev/null || true
    done | awk '{ a[$1]+=$2 } END { for (k in a) print k, a[k] }'
}
# Process-level CPU time (user+system, all threads). Unlike summing live threads this keeps the time of
# threads that have exited, so a render thread that starts and stops mid-run cannot make the total shrink.
total_ticks() {
    awk '{ s=$0; for(k=length(s);k>0;k--) if (substr(s,k,1)==")") break; n=split(substr(s,k+2),f," "); print f[12]+f[13] }' /proc/"$pid"/stat
}
rss_kb() { awk '/^VmRSS:/ { print $2 }' /proc/"$pid"/status; }
gpu_sample() { nvidia-smi --query-gpu=utilization.gpu,clocks.gr,power.draw,pstate --format=csv,noheader,nounits 2>/dev/null | head -n1; }

median() { sort -n | awk '{ v[NR]=$1 } END { if (NR==0) print "n/a"; else print (NR%2 ? v[(NR+1)/2] : (v[NR/2]+v[NR/2+1])/2) }'; }

echo "label=$label duration=${duration}s runs=$runs pid=$pid frames_logging=$frames_on" | tee -a "$out"
echo "plasmashell DRM driver(s): ${gpu_driver:-unknown}" | tee -a "$out"

cpu_all=(); rss_all=(); fps_all=(); gpu_all=()
for run in $(seq 1 "$runs"); do
    t0_ticks="$(total_ticks)"
    thread_ticks | sort > /tmp/perf-baseline.t0.$$
    start_epoch="$(date +%s)"
    rss_samples=(); gpu_samples=()
    end=$((start_epoch + duration))
    while [ "$(date +%s)" -lt "$end" ]; do
        rss_samples+=("$(rss_kb)")
        [ "$nvidia" = 1 ] && gpu_samples+=("$(gpu_sample | tr -d ' ')")
        sleep 5
    done
    t1_ticks="$(total_ticks)"
    thread_ticks | sort > /tmp/perf-baseline.t1.$$
    elapsed=$(( $(date +%s) - start_epoch ))
    cpu="$(awk -v a="$t0_ticks" -v b="$t1_ticks" -v hz="$hz" -v s="$elapsed" 'BEGIN { printf "%.2f", (b-a)/hz/s*100 }')"
    rss_avg="$(printf '%s\n' "${rss_samples[@]}" | awk '{ s+=$1; n++ } END { printf "%d", s/n/1024 }')"
    top="$(join /tmp/perf-baseline.t0.$$ /tmp/perf-baseline.t1.$$ 2>/dev/null | awk -v hz="$hz" -v s="$elapsed" '{ d=($3-$2)/hz/s*100; if (d>0.05) printf "%s %.2f\n", $1, d }' | sort -k2 -nr | head -n 3 | awk '{ printf "%s=%s%% ", $1, $2 }')"
    fps="n/a"; fps_windows=""
    if [ "$frames_on" = 1 ]; then
        # One "syncAndRender: frame rendered" line per frame, tagged with the window it belongs to.
        frame_lines="$(journalctl --user -b --since "@$start_epoch" --until "@$((start_epoch + elapsed))" -t plasmashell --no-pager 2>/dev/null | grep 'syncAndRender: frame rendered' || true)"
        frames="$(printf '%s' "$frame_lines" | grep -c . || true)"
        fps="$(awk -v f="$frames" -v s="$elapsed" 'BEGIN { printf "%.1f", f/s }')"
        fps_windows="$(printf '%s\n' "$frame_lines" | { grep -o '\[window 0x[0-9a-f]*\]' || true; } | sort | uniq -c | sort -nr | head -n 3 | awk -v s="$elapsed" '{ printf "%s=%.1ffps ", $3, $1/s }' || true)"
    fi
    gpu_txt="n/a"
    if [ "$nvidia" = 1 ] && [ "${#gpu_samples[@]}" -gt 0 ]; then
        gpu_txt="$(printf '%s\n' "${gpu_samples[@]}" | awk -F, '{ u+=$1; c+=$2; if ($3 ~ /^[0-9.]+$/) { p+=$3; pn++ } n++; st=$4 } END { printf "util=%.0f%% clock=%.0fMHz power=%s pstate=%s", u/n, c/n, (pn ? sprintf("%.1fW", p/pn) : "n/a"), st }')"
        gpu_all+=("$(printf '%s\n' "${gpu_samples[@]}" | awk -F, '{ u+=$1; n++ } END { printf "%.0f", u/n }')")
    fi
    echo "run $run: cpu=${cpu}% rss=${rss_avg}MB fps=$fps gpu[$gpu_txt] threads: ${top:-none}${fps_windows:+ windows: $fps_windows}" | tee -a "$out"
    cpu_all+=("$cpu"); rss_all+=("$rss_avg"); [ "$fps" != "n/a" ] && fps_all+=("$fps")
    rm -f /tmp/perf-baseline.t0.$$ /tmp/perf-baseline.t1.$$
done

mcpu="$(printf '%s\n' "${cpu_all[@]}" | median)"
mrss="$(printf '%s\n' "${rss_all[@]}" | median)"
mfps="n/a"; [ "${#fps_all[@]}" -gt 0 ] && mfps="$(printf '%s\n' "${fps_all[@]}" | median)"
mgpu="n/a"; [ "${#gpu_all[@]}" -gt 0 ] && mgpu="$(printf '%s\n' "${gpu_all[@]}" | median)%"
echo "MEDIAN $label: cpu=${mcpu}% rss=${mrss}MB fps=$mfps nvidia_util=$mgpu" | tee -a "$out"
echo "(results appended to ${out#"$root"/})"
