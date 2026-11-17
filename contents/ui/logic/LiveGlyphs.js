.pragma library

// The glyph for what the Live page shows, one source for the capsule's Live item, the job list header and every row
// (D-51, D-26: theme symbolic names with fallback chains; the last name always exists in the themes this ships for).
// Kinds: "music" and "video" for media, Jobs.kind for jobs ("download", "upload", "delete", "copy", "move", "generic"),
// and "transfer" for mixed kinds.

const generic = "folder-download-symbolic";
const chains = {
    "music": ["music-note-16th-symbolic", "audio-volume-high-symbolic", "media-playback-start-symbolic"],
    "video": ["video-x-generic-symbolic", "emblem-videos-symbolic", "media-playback-start-symbolic"],
    "copy": ["edit-copy-symbolic", generic],
    "move": ["edit-move-symbolic", "go-next-symbolic", generic],
    "download": ["download-symbolic", "go-down-symbolic", generic],
    "upload": ["document-send-symbolic", "upload-symbolic", "go-up-symbolic", generic],
    "delete": ["edit-delete-symbolic", "user-trash-symbolic", generic],
    "generic": ["edit-copy-symbolic", generic],
    "transfer": ["view-sort-symbolic", "document-swap-symbolic", generic]
};

function chain(kind) {
    return chains[kind] || chains.transfer;
}

// What the Live item shows: media wins (a film glyph for video), else the one kind all jobs share, else "transfer".
// A generic kind is not a noun, so it reads as mixed, like the list header.
function liveKind(hasMedia, mediaKind, jobKinds) {
    if (hasMedia)
        return mediaKind === "video" ? "video" : "music";
    const kinds = new Set(jobKinds);
    return kinds.size === 1 && !kinds.has("generic") ? jobKinds[0] : "transfer";
}
