import QtQuick
import org.kde.kirigami as Kirigami

// Monochrome glyph from the active icon theme: shows the first name in `names` the theme
// can resolve (D-26), so a missing icon never renders blank. The last name is the final fallback.
Item {
    id: glyph

    property var names: []
    property color color: "white"
    // Bumped when a probe is created or its validity changes, so resolvedName re-evaluates.
    property int revision: 0
    readonly property string resolvedName: {
        glyph.revision;
        for (let i = 0; i < probes.count - 1; ++i) {
            const probe = probes.itemAt(i) as Kirigami.Icon;
            if (probe && probe.valid)
                return glyph.names[i];
        }
        return glyph.names.length > 0 ? glyph.names[glyph.names.length - 1] : "";
    }

    Repeater {
        id: probes

        model: glyph.names
        onItemAdded: glyph.revision++

        delegate: Kirigami.Icon {
            visible: false
            source: modelData
            onValidChanged: glyph.revision++
        }
    }

    Kirigami.Icon {
        anchors.fill: parent
        source: glyph.resolvedName
        isMask: true
        color: glyph.color
    }
}
