import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ".."
import "../controlcenter"
import "../controlcenter/Tokens.js" as T

// Expanded notification in the fixed media-popup footprint. One content row fills the inner area;
// the icon and the text stack are both centred in it, so they share one centre line.
Item {
    id: notificationPage

    property var app: null
    readonly property int notificationRow: app ? app.notificationLatestRow() : -1
    readonly property bool hasNotification: notificationRow >= 0
    readonly property var mainImage: hasNotification && app.notificationImagesEnabled ? app.notificationMainImage(notificationRow) : null
    readonly property bool hasImage: mainImage !== null && mainImage !== undefined && (typeof mainImage !== "string" || mainImage.length > 0)
    readonly property var iconName: hasNotification ? app.notificationMainIcon(notificationRow) : "notifications"
    // No real application icon: show the generic notification glyph, muted.
    readonly property bool genericIcon: !hasImage && (typeof iconName !== "string" || iconName.length === 0 || iconName === "notifications")
    readonly property string bodyText: hasNotification ? app.notificationBody(notificationRow) : ""
    readonly property real artSize: 44
    readonly property real createdMs: hasNotification ? app.notificationCreatedMs(notificationRow) : 0
    property real nowMs: Date.now()
    // "now", then "Nm ago" up to 59 minutes, then the clock time the notification arrived.
    readonly property string ageText: {
        if (createdMs <= 0)
            return "";
        const minutes = Math.floor(Math.max(0, nowMs - createdMs) / 60000);
        if (minutes < 1)
            return i18n("now");
        if (minutes < 60)
            return i18n("%1m ago", minutes);
        return Qt.formatTime(new Date(createdMs), Qt.locale(), Locale.ShortFormat);
    }
    onCreatedMsChanged: nowMs = Date.now()

    // Clickable (D-31) is decided and handled for the whole island in main.qml; the glyph follows its hover state.
    readonly property bool clickable: hasNotification && app.notificationClickable(notificationRow)

    Timer {
        interval: 30000
        repeat: true
        running: notificationPage.visible && notificationPage.createdMs > 0
        onTriggered: notificationPage.nowMs = Date.now()
    }
    readonly property real textWidth: Math.max(0, width - artSize - 12)
    readonly property string titleText: hasNotification ? app.notificationTitle(notificationRow) : i18n("Notification")
    // Density is chosen from the content measured at the roomy (short) sizes, so it depends only on the
    // text and cannot flip while the notification is shown: one-line title and at most a one-line body.
    readonly property bool shortLayout: titleMetrics.advanceWidth(titleText) <= textWidth && (bodyText.length === 0 || bodyText.indexOf("\n") < 0 && bodyMetrics.advanceWidth(bodyText) <= textWidth)

    FontMetrics {
        id: titleMetrics

        font.pixelSize: 16
        font.weight: Font.DemiBold
    }

    FontMetrics {
        id: bodyMetrics

        font.pixelSize: 12
    }

    RowLayout {
        id: contentRow

        anchors.fill: parent
        spacing: 12

        // Icon cell: spans the row and centres the artwork against the whole text stack.
        Item {
            id: iconCell

            Layout.fillHeight: true
            Layout.preferredWidth: notificationPage.artSize

            // Rounded frame for the sender photo. Web/Telegram avatars arrive as in-memory image data, which only
            // Kirigami.Icon can draw; file or http URLs still use Image so they keep their crop.
            Item {
                id: photo

                anchors.centerIn: parent
                width: notificationPage.artSize
                height: notificationPage.artSize
                visible: notificationPage.hasImage
                layer.enabled: visible
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSpreadAtMax: 1
                    maskSpreadAtMin: 1
                    maskThresholdMin: 0.5

                    maskSource: ShaderEffectSource {
                        sourceItem: Rectangle {
                            width: photo.width
                            height: photo.height
                            radius: Math.round(photo.width * 0.24)
                            color: "#ffffff"
                        }
                    }
                }

                Image {
                    anchors.fill: parent
                    visible: typeof notificationPage.mainImage === "string"
                    source: visible ? notificationPage.mainImage : ""
                    sourceSize: Qt.size(128, 128)
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                }

                Kirigami.Icon {
                    anchors.fill: parent
                    visible: notificationPage.hasImage && typeof notificationPage.mainImage !== "string"
                    source: visible ? notificationPage.mainImage : ""
                    roundToIconSize: false
                }
            }

            // Application icons keep their own transparent artwork; no tile behind them.
            Kirigami.Icon {
                anchors.centerIn: parent
                width: notificationPage.artSize
                height: notificationPage.artSize
                visible: !notificationPage.hasImage
                source: notificationPage.genericIcon ? "notifications" : notificationPage.iconName
                fallback: "notifications"
                isMask: notificationPage.genericIcon
                color: notificationPage.genericIcon ? "#8d8f99" : "transparent"
                roundToIconSize: false
            }
        }

        // Text stack: centred in the row as one group (spacers above and below).
        ColumnLayout {
            id: info

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            spacing: notificationPage.shortLayout ? 7 : 2

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                PlasmaLabel {
                    Layout.fillWidth: true
                    text: notificationPage.hasNotification ? notificationPage.app.notificationAppName(notificationPage.notificationRow) : i18n("Notification")
                    color: "#8d8f99"
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                // Same slot rule as the Control Center rows: the age at rest, the open glyph on hover, no layout shift.
                NotificationRowSlot {
                    visible: notificationPage.ageText.length > 0 || notificationPage.clickable
                    timeText: notificationPage.ageText
                    revealed: notificationPage.app && notificationPage.app.noticeHovered
                    clickable: notificationPage.clickable
                    timeColor: "#6e707a"
                    iconColor: "#9a9ca6"
                }

                Rectangle {
                    Layout.preferredWidth: 5
                    Layout.preferredHeight: 5
                    radius: 2.5
                    color: notificationPage.hasNotification ? notificationPage.app.notificationUrgencyColor(notificationPage.notificationRow) : "#D1D3D8"
                }
            }

            PlasmaLabel {
                Layout.fillWidth: true
                text: notificationPage.titleText
                color: "#ffffff"
                font.pixelSize: notificationPage.shortLayout ? 16 : 14
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
            }

            PlasmaLabel {
                Layout.fillWidth: true
                visible: text.length > 0
                text: notificationPage.bodyText
                textFormat: Text.PlainText
                color: "#9a9ca6"
                font.pixelSize: notificationPage.shortLayout ? 12 : 11
                lineHeight: 1.0
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
