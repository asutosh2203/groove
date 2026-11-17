pragma ComponentBehavior: Bound

import QtQuick
import "../../controlcenter" as CC

// The sunrise or sunset glyph (D-55, D-26): the theme's own pair when it has one, else the bundled Adwaita pair, which no
// active icon theme here ships.
CC.ThemeGlyph {
    id: glyph

    property string kind: "sunset"

    names: glyph.kind === "sunrise" ? ["daytime-sunrise-symbolic", Qt.resolvedUrl("../../weather/icons/daytime-sunrise-symbolic.svg")] : ["daytime-sunset-symbolic", Qt.resolvedUrl("../../weather/icons/daytime-sunset-symbolic.svg")]
}
