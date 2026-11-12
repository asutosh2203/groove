import QtQuick
import org.kde.kirigami as Kirigami
import "Tokens.js" as T

// Phone glyph through the active icon theme. WhiteSur ships no phone symbolic,
// so smartphone-symbolic resolves via its Breeze inheritance; the chain never ends blank.
Item {
    id: glyph

    property color color: T.iconIdle

    Kirigami.Icon {
        id: smartphone
        visible: false
        source: "smartphone-symbolic"
    }

    Kirigami.Icon {
        id: phone
        visible: false
        source: "phone-symbolic"
    }

    Kirigami.Icon {
        anchors.fill: parent
        source: smartphone.valid ? "smartphone-symbolic" : phone.valid ? "phone-symbolic" : "kdeconnect-tray"
        isMask: true
        color: glyph.color
    }
}
