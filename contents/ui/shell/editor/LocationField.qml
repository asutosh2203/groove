pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import "../.."
import "../../controlcenter/Tokens.js" as T

// The location editor: a search field with a results list under it. The stored value is "island" or { name, lat, lon };
// picking a result stores the city name with its coordinates. Takes keyboard focus only when clicked (the D3 spike):
// the deck's window is already active, so focusing the field changes no window flag.
Item {
    id: field

    required property var app
    // The current setting value: "island" or { name, lat, lon }.
    property var value: "island"
    // The deck's focus root, to hand focus back when Esc defocuses the field.
    required property Item focusRoot

    signal picked(var location)

    // The search, for the tests to feed results into.
    readonly property alias search: search

    readonly property bool editing: input.activeFocus
    readonly property string shownName: field.value === "island" ? "" : String(field.value.name)

    implicitHeight: input.height

    LocationSearch {
        id: search

        strings: field.app.strings
    }

    QQC2.TextField {
        id: input

        anchors.left: parent.left
        anchors.right: parent.right
        height: T.editChipH
        // The current city shows as the field's text until the user starts typing.
        text: field.shownName
        placeholderText: field.app.strings.editLocationPlaceholder
        placeholderTextColor: T.textTertiary
        color: T.textPrimary
        font.pixelSize: T.fontBody
        selectByMouse: true
        activeFocusOnPress: true
        leftPadding: T.gap
        rightPadding: T.gap
        background: Rectangle {
            radius: input.height / 2
            color: T.row
            border.width: 1
            border.color: input.activeFocus ? T.textTertiary : T.border
        }
        onTextEdited: search.typed(text)
        onAccepted: search.submit(text)
        onActiveFocusChanged: {
            field.app.editor.fieldFocused = activeFocus;
            // The current city is selected, so typing replaces it.
            if (activeFocus)
                Qt.callLater(selectAll);
            if (!activeFocus) {
                search.clear();
                text = field.shownName;
            }
        }
        // Esc clears what was typed, then leaves the field (D3 spike); the form's own Esc step comes after.
        Keys.onEscapePressed: event => {
            if (search.query.length > 0 && text.length > 0) {
                text = "";
                search.clear();
            } else {
                field.focusRoot.forceActiveFocus();
            }
            event.accepted = true;
        }
    }

    Rectangle {
        id: list

        anchors.top: input.bottom
        anchors.topMargin: T.deckDotSize
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(results.contentHeight, T.editRow * 4) + (status.visible ? status.height : 0)
        visible: input.activeFocus && (search.results.length > 0 || search.statusText.length > 0)
        z: 1
        radius: T.radiusInner
        color: T.raised
        border.width: 1
        border.color: T.borderStrong
        clip: true

        PlasmaLabel {
            id: status

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: T.gap
            height: visible ? T.editChipH : 0
            visible: search.statusText.length > 0
            verticalAlignment: Text.AlignVCenter
            text: search.statusText
            color: T.textSecondary
            font.pixelSize: T.fontCaption
        }

        ListView {
            id: results

            anchors.top: status.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            interactive: contentHeight > height
            model: search.results

            delegate: Rectangle {
                id: row

                required property var modelData

                width: results.width
                height: T.editChipH + T.deckDotSize
                color: hover.hovered ? T.rowHover : "transparent"

                PlasmaLabel {
                    anchors.fill: parent
                    anchors.leftMargin: T.gap
                    anchors.rightMargin: T.gap
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: row.modelData.text
                    color: T.textPrimary
                    font.pixelSize: T.fontBody
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        field.picked({ "name": row.modelData.name, "lat": row.modelData.lat, "lon": row.modelData.lon });
                        field.focusRoot.forceActiveFocus();
                    }
                }
            }
        }
    }
}
