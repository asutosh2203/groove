.pragma library

// Time zone ids for the editor's fallback entry (D-56): the shape the registry accepts, and a readable name when Plasma's
// own time zone data is not available.
const ZONE = /^[A-Za-z0-9_+\-\/]{1,64}$/;

function validId(text) {
    return text === "local" || ZONE.test(String(text));
}

// "America/Argentina/Buenos_Aires" -> "Buenos Aires"; "local" has no city.
function fallbackCity(id) {
    const s = String(id);
    return s === "local" ? "" : s.split("/").pop().replace(/_/g, " ");
}
