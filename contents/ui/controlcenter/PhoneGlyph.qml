import QtQuick
import "Tokens.js" as T

// Phone glyph through the active icon theme. WhiteSur ships no phone symbolic,
// so smartphone-symbolic resolves via its Breeze inheritance.
ThemeGlyph {
    names: ["smartphone-symbolic", "phone-symbolic", "kdeconnect-tray"]
    color: T.iconIdle
}
