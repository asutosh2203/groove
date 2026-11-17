pragma ComponentBehavior: Bound

import QtQuick
import "../../controlcenter" as CC

// The sunrise or sunset glyph (D-55): always the bundled Adwaita pair (the weather exception of D-26), so the two glyphs match
// whatever the icon theme is; themes that have such names draw them in different styles.
CC.ThemeGlyph {
    id: glyph

    property string kind: "sunset"

    names: glyph.kind === "sunrise" ? [Qt.resolvedUrl("../../weather/icons/sunrise-glyph.svg")] : [Qt.resolvedUrl("../../weather/icons/sunset-glyph.svg")]
}
