.pragma library

// How long a notification popup stays up (D-33). Apps may shorten the user's setting but never lengthen it,
// a 2 s floor keeps short ones readable, and critical notifications stay at least 6 s.
const floorMs = 2000;
const criticalFloorMs = 6000;
const ceilingMs = 15000;
const criticalUrgency = 4; // KDE's enum: Low=1, Normal=2, Critical=4 (not freedesktop 0/1/2)

// requestedMs: the notification's own timeout (> 0 ms, 0 = never expires, -1 = server default).
// settingMs: the user's popup duration. urgency: KDE's NotificationManager urgency value.
function effectiveDurationMs(requestedMs, settingMs, urgency) {
    const setting = Number(settingMs);
    const base = isFinite(setting) && setting > 0 ? setting : floorMs;
    const requested = Number(requestedMs);
    let result = base;
    if (requestedMs !== null && requestedMs !== undefined && isFinite(requested) && requested > 0 && requested < base)
        result = Math.max(requested, floorMs);
    if (Number(urgency) === criticalUrgency)
        result = Math.max(result, criticalFloorMs);
    return Math.min(result, ceilingMs);
}
