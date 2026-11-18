.pragma library
.import "Utils.js" as Utils

// Remote cover art (https) is fetched with curl into a small cache and shown from disk: Qt's own HTTP client waits about
// 30 s on an IPv6 route that goes nowhere before it tries IPv4, so a remote Image URL shows the placeholder for that long.
// Pure decisions only; ArtworkCache.qml runs the command.
const MAX_URL = 2048;
const MAX_FILE = 8000000;
const CACHE_BYTES = 50 * 1024 * 1024;
const MAX_STATES = 64;

function isRemote(url) {
    return /^https?:\/\//i.test(String(url || ""));
}

// A URL is safe to put inside single quotes: no quote, whitespace or control characters, and a sane length.
function isFetchable(url) {
    const u = String(url || "");
    return isRemote(u) && u.length <= MAX_URL && !/['\s\x00-\x1f\x7f]/.test(u);
}

// FNV-1a, 32 bit: a stable file name from the URL (not a security hash; the length is added against collisions).
function fileName(url) {
    const u = String(url);
    let h = 0x811c9dc5;
    for (let i = 0; i < u.length; ++i) {
        h ^= u.charCodeAt(i);
        h = Math.imul(h, 0x01000193) >>> 0;
    }
    return "art-" + h.toString(16) + "-" + u.length.toString(36);
}

// The command that makes the file exist and prints its absolute path (nothing on failure); "" for a URL that is not
// fetchable. The script is a constant: the URL, the file name and the cache cap arrive as positional arguments ($1 $2 $3)
// and are only ever expanded inside double quotes, never evaluated. An existing file is reused and touched, so the art
// survives restarts and eviction (oldest first, past the cap) drops what has gone unused longest. No curl on the system
// prints nothing, which the caller treats as a failed fetch and falls back to Qt's own loader.
const SCRIPT = 'd="${XDG_CACHE_HOME:-$HOME/.cache}/kove/art"; f="$d/$2"; mkdir -p "$d" || exit 1; '
    + 'if [ -s "$f" ]; then touch "$f"; else command -v curl >/dev/null || exit 1; '
    + 'curl -fsSL --max-redirs 3 --connect-timeout 5 --max-time 15 --max-filesize ' + MAX_FILE
    + ' --proto =http,https --proto-redir =http,https -o "$f.part" -- "$1" '
    + '&& [ "$(stat -c %s "$f.part")" -le ' + MAX_FILE + ' ] && mv -f "$f.part" "$f" || { rm -f "$f.part"; exit 1; }; fi; '
    + 'echo "$f"; '
    + 'find "$d" -maxdepth 1 -type f -name "art-*" -printf "%T@ %s %p\\n" | sort -rn '
    + '| awk -v cap="$3" "{ t += \\$2; if (t > cap) { sub(/^[^ ]+ [^ ]+ /, \\"\\"); print } }" '
    + '| xargs -r -d "\\n" rm -f --; true';

function command(url, capBytes) {
    if (!isFetchable(url))
        return "";
    return "sh -c " + Utils.shellQuote(SCRIPT) + " kove-art " + Utils.shellQuote(url) + " " + fileName(url) + " " + (capBytes > 0 ? Math.floor(capBytes) : CACHE_BYTES);
}

// The path the command printed, or "" when it printed none.
function pathFrom(stdout) {
    const line = String(stdout || "").split("\n")[0].trim();
    return line.charAt(0) === "/" ? line : "";
}

// What the artwork items should load: a local file once fetched, nothing while it is being fetched (the placeholder shows),
// and the original URL when it is not remote or the fetch failed (the behaviour without a cache).
// states: url -> { path } when fetched, { failed: true } when not, absent while pending or not asked yet.
function sourceFor(url, states) {
    const u = String(url || "");
    if (!isFetchable(u))
        return u;
    const s = states[u];
    if (s)
        return s.path ? "file://" + s.path : u;
    return "";
}

// Records a result, forgetting the oldest entries past MAX_STATES. Mutates `states`.
function remember(states, url, entry) {
    delete states[url];
    states[url] = entry;
    const keys = Object.keys(states);
    for (let i = 0; i < keys.length - MAX_STATES; ++i)
        delete states[keys[i]];
}
