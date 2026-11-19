pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.clock as PlasmaClock
import "../.."
import "../../controlcenter/Tokens.js" as T
import "../../logic/ZoneNames.js" as ZoneNames

// The time zone editor (D-56): search Plasma's zone list by city, or "Local time". The stored value is "local" or an IANA
// id. If the private zone data cannot be loaded the field is a plain id entry, validated through Plasma's Clock.
Item {
    id: field

    required property var app
    required property Item focusRoot
    property string value: "local"
    // Where the private zone data lives; a test points it elsewhere to see the fallback.
    property url finderSource: "TimezoneSearch.qml"

    signal picked(string zone)

    readonly property var finder: finderLoader.item
    readonly property bool searching: field.finder !== null
    readonly property bool editing: input.activeFocus
    readonly property string shownName: field.value === "local" ? field.app.strings.editLocalTime : field.searching ? field.finder.cityOf(field.value) : ZoneNames.fallbackCity(field.value)
    property string typed: ""
    property bool invalid: false

    implicitWidth: T.editSidebar + 2 * T.editInset
    implicitHeight: T.editChipH

    Loader {
        id: finderLoader

        source: field.finderSource
    }

    // The fallback's check: Plasma's Clock says whether a zone id exists.
    PlasmaClock.Clock {
        id: probe

        timeZone: field.searching ? "UTC" : field.typed
    }

    QQC2.TextField {
        id: input

        anchors.left: parent.left
        anchors.right: parent.right
        height: T.editChipH
        text: field.shownName
        placeholderText: field.searching ? field.app.strings.editZonePlaceholder : field.app.strings.editZoneIdPlaceholder
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
            border.color: input.activeFocus || field.invalid ? T.textTertiary : T.border
        }
        onTextEdited: {
            field.invalid = false;
            field.typed = text;
            if (field.searching)
                field.finder.query = text;
        }
        // The fallback takes an id on Enter.
        onAccepted: {
            if (field.searching)
                return ;
            if (ZoneNames.validId(text) && probe.valid)
                field.choose(text);
            else
                field.invalid = true;
        }
        onActiveFocusChanged: {
            field.app.editor.fieldFocused = activeFocus;
            // The current city is selected, so typing replaces it.
            if (activeFocus)
                Qt.callLater(selectAll);
            if (!activeFocus) {
                field.typed = "";
                field.invalid = false;
                if (field.searching)
                    field.finder.query = "";
                text = field.shownName;
            }
        }
        Keys.onEscapePressed: event => {
            if (field.typed.length > 0) {
                text = "";
                field.typed = "";
                if (field.searching)
                    field.finder.query = "";
            } else {
                field.focusRoot.forceActiveFocus();
            }
            event.accepted = true;
        }
    }

    function choose(zone) {
        field.picked(zone);
        field.focusRoot.forceActiveFocus();
    }

    PlasmaLabel {
        visible: field.invalid && field.editing
        anchors.top: input.bottom
        anchors.topMargin: T.deckDotSize
        text: field.app.strings.editZoneUnknown
        color: T.textSecondary
        font.pixelSize: T.fontCaption
    }

    Rectangle {
        visible: field.searching && input.activeFocus
        anchors.top: input.bottom
        anchors.topMargin: T.deckDotSize
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(list.contentHeight, T.editEntry * 4)
        z: 1
        radius: T.radiusInner
        color: T.raised
        border.width: 1
        border.color: T.borderStrong
        clip: true

        ListView {
            id: list

            anchors.fill: parent
            interactive: contentHeight > height
            model: field.searching ? field.finder.zones : null
            // "Local time" is always the first choice.
            header: Rectangle {
                width: ListView.view.width
                height: T.editEntry
                color: "transparent"

                HoverHighlight {
                    containerRadius: T.radiusInner
                    shown: localHover.hovered
                }

                PlasmaLabel {
                    anchors.fill: parent
                    anchors.leftMargin: T.gap
                    verticalAlignment: Text.AlignVCenter
                    text: field.app.strings.editLocalTime
                    color: T.textPrimary
                    font.pixelSize: T.fontBody
                }

                HoverHandler {
                    id: localHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: field.choose("local")
                }
            }

            delegate: Rectangle {
                id: row

                required property string timeZoneId
                required property string city
                required property string region

                width: ListView.view.width
                height: T.editEntry
                color: "transparent"

                HoverHighlight {
                    containerRadius: T.radiusInner
                    shown: rowHover.hovered
                }

                PlasmaLabel {
                    anchors.fill: parent
                    anchors.leftMargin: T.gap
                    anchors.rightMargin: T.gap
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: row.city + "  ·  " + row.region
                    color: T.textPrimary
                    font.pixelSize: T.fontBody
                }

                HoverHandler {
                    id: rowHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: field.choose(row.timeZoneId)
                }
            }
        }
    }
}
