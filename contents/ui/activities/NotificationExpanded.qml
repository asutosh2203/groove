import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ".."

// Expanded notification: one content row whose height is shared by the icon cell and the
// information column. The row is as tall as its text needs (minimum 48px), centred in the card.
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
    readonly property int maxBodyLines: app ? app.notificationBodyLines : 3
    readonly property real rowHeight: Math.min(height, Math.max(48, info.implicitHeight))
    readonly property real artSize: Math.min(rowHeight, 52)

    Item {
        id: contentRow

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: notificationPage.rowHeight

        RowLayout {
            anchors.fill: parent
            spacing: 12

            // Icon cell: same top and bottom as the information column; the artwork sits at its top.
            Item {
                id: iconCell

                Layout.fillHeight: true
                Layout.preferredWidth: notificationPage.artSize

                // Photos and thumbnails: cropped to fill (never stretched) and rounded.
                Image {
                    id: photo

                    width: notificationPage.artSize
                    height: notificationPage.artSize
                    visible: notificationPage.hasImage
                    source: notificationPage.hasImage ? notificationPage.mainImage : ""
                    sourceSize: Qt.size(128, 128)
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
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
                }

                // Application icons keep their own transparent artwork; no tile behind them.
                Kirigami.Icon {
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

            ColumnLayout {
                id: info

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                spacing: 2

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

                    Rectangle {
                        Layout.preferredWidth: 5
                        Layout.preferredHeight: 5
                        radius: 2.5
                        color: notificationPage.hasNotification ? notificationPage.app.notificationAccent(notificationPage.notificationRow) : "#ff9f0a"
                    }
                }

                PlasmaLabel {
                    id: titleLabel

                    Layout.fillWidth: true
                    text: notificationPage.hasNotification ? notificationPage.app.notificationTitle(notificationPage.notificationRow) : i18n("Notification")
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    maximumLineCount: 2
                }

                PlasmaLabel {
                    id: bodyLabel

                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: notificationPage.bodyText
                    textFormat: Text.PlainText
                    color: "#9a9ca6"
                    font.pixelSize: 11
                    lineHeight: 1.1
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                    // As many lines as the setting allows and the card can hold.
                    maximumLineCount: Math.max(1, Math.min(notificationPage.maxBodyLines, Math.floor((notificationPage.height - 14 - titleLabel.implicitHeight - 6) / (fontMetrics.height * 1.1))))
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }

    FontMetrics {
        id: fontMetrics

        font: bodyLabel.font
    }
}
