.pragma library
.import "PomodoroEngine.js" as Pomodoro

// The read-only "note" fields of a settings form (D-64): a line a widget computes from its own resolved settings, such as
// the Pomodoro summary. Returns a description (never translated text; the form turns it into the user's language), or
// null when the widget has none.
function describe(widgetId, settings) {
    if (widgetId === "pomodoro") {
        const d = Pomodoro.derived(Pomodoro.config(settings));
        return { "kind": "pomodoro", "plain": d.plain, "roundMinutes": Math.round(d.roundMs / 60000), "cycleMinutes": Math.round(d.cycleMs / 60000) };
    }
    return null;
}
