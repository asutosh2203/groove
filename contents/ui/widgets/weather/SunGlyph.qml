pragma ComponentBehavior: Bound

import QtQuick
import "../../controlcenter" as CC

// The sunrise or sunset glyph (D-55, D-26): the theme's own pair when it has one (WhiteSur-dark does), else the bundled
// Adwaita pair. The bundled files are not named like theme icons, or Kirigami would resolve them through the theme.
CC.ThemeGlyph {
    id: glyph

    property string kind: "sunset"

    names: glyph.kind === "sunrise" ? ["daytime-sunrise-symbolic", Qt.resolvedUrl("../../weather/icons/sunrise-glyph.svg")] : ["daytime-sunset-symbolic", Qt.resolvedUrl("../../weather/icons/sunset-glyph.svg")]
}
