# Kove icon set

Single-colour glyphs drawn for Kove, on a 24 px grid with 1.8 px round strokes. They are recoloured at runtime, so the
fill is irrelevant (only the alpha is used). Licensed with the project (GPL-3.0-or-later, see `REUSE.toml`).

Use them for glyphs the system icon themes (Breeze, WhiteSur) do not have, such as an agent prompt or a "move" arrow.
Anything the themes already provide stays a theme symbolic name (D-26).

- Files are named `<name>.kove.svg`, never like a theme icon, so Kirigami can never resolve them through the theme.
- Load them by URL through `CC.ThemeGlyph` with the name `kove:<name>`; it recolours them like any other glyph.

| Name | Use |
|---|---|
| `prompt` | An agent: a ">" chevron, an underscore and a thought dot (working, done) |
| `prompt-calm` | The same without the thought dot (waiting: the accent badge replaces it) |
