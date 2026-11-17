import QtQuick
import org.kde.kirigami as Kirigami

// Monochrome glyph from the active icon theme: shows the first name in `names` the theme
// can resolve (D-26), so a missing icon never renders blank. The last name is the final fallback.
// A name "kove:<name>" is one of Kove's own glyphs (ui/icons/<name>.kove.svg), loaded by URL.
Item {
    id: glyph

    property var names: []
    property color color: "white"
    readonly property string iconDir: Qt.resolvedUrl("../icons/")
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

    // Whether the theme has at least one of the names (the last name is otherwise assumed, so a caller that has a
    // different fallback can tell).
    readonly property bool anyValid: {
        glyph.revision;
        for (let i = 0; i < probes.count; ++i) {
            const probe = probes.itemAt(i) as Kirigami.Icon;
            if (probe && probe.valid)
                return true;
        }
        return false;
    }

    function iconSource(name) {
        return String(name).startsWith("kove:") ? glyph.iconDir + String(name).slice(5) + ".kove.svg" : name;
    }

    Repeater {
        id: probes

        model: glyph.names.map(name => glyph.iconSource(name))
        onItemAdded: glyph.revision++

        delegate: Kirigami.Icon {
            visible: false
            source: modelData
            onValidChanged: glyph.revision++
        }
    }

    Kirigami.Icon {
        anchors.fill: parent
        source: glyph.iconSource(glyph.resolvedName)
        isMask: true
        color: glyph.color
    }
}
