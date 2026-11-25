.pragma library

// The + and − buttons of a number field (D-56): one step on press, then repeats that speed up while held.

function next(value, direction, step, min, max) {
    return Math.min(max, Math.max(min, value + direction * step));
}

// ms before the repeat after `count` repeats: slow at first, ramping linearly to fast over `ramp` repeats.
function interval(count, slow, fast, ramp) {
    return Math.round(slow - (slow - fast) * Math.min(1, count / ramp));
}
