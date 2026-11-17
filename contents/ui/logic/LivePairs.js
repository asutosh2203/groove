.pragma library

// The Live page (D-51): its cards ranked, shown two at a time. A card is { key, priority, recency } (priority from
// ActivityResolver, recency a number, larger = more recent). No auto-rotation: the pair changes only on a click.

// D-38 priority first, then recency, then the key so the order is stable.
function rank(cards) {
    return cards.slice().sort((a, b) => b.priority - a.priority || b.recency - a.recency || (a.key < b.key ? -1 : a.key > b.key ? 1 : 0));
}

function pairCount(count) {
    return Math.ceil(count / 2);
}

// An index past the end falls back to the previous pair (or the first); never below 0.
function clampPair(pairIndex, count) {
    return Math.max(0, Math.min(pairIndex, pairCount(count) - 1));
}

// What to draw for pair `pairIndex`: the two cards, the "+N" chip (cards after this pair, 0 = no chip), and whether
// "‹" shows. A higher-priority arrival does not change the index, so the viewer stays on the same pair number.
function view(cards, pairIndex) {
    const ranked = rank(cards);
    const index = clampPair(pairIndex, ranked.length);
    const start = index * 2;
    return {
        "pairIndex": index,
        "cards": ranked.slice(start, start + 2),
        "more": Math.max(0, ranked.length - start - 2),
        "canBack": index > 0
    };
}
