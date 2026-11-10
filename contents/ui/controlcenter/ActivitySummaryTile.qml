import QtQuick
import QtQuick.Layouts
import ".."
import "../activities" as Activities
import "Tokens.js" as T

Rectangle {
    id: activitySummary

    required property var app
    required property var notificationsSource
    property bool mediaOnly: false
    readonly property bool showMedia: app.hasPlayer
    readonly property bool showAnyActivity: mediaOnly ? showMedia : app.hasActivity
    readonly property string summaryMode: mediaOnly ? app.hasPlayer ? "media" : "idle" : app.activityMode()
    readonly property color activityColor: app.isPlaying || app.hasJobs || app.hasNotifications ? T.textCaption : T.textTertiary
    readonly property bool iconOnly: width < 100 || height < 62
    readonly property bool compact: width < 190 || height < 112
    readonly property real artSize: iconOnly ? Math.max(24, Math.min(width, height) - 18) : compact ? Math.max(36, Math.min(52, height - 22)) : Math.max(48, Math.min(72, height - 28))

    function previous() {
        app.mediaPrevious();
    }

    function playPause() {
        app.mediaPlayPause();
    }

    function next() {
        app.mediaNext();
    }

    radius: T.radiusCard
    color: T.card
    border.color: T.border
    border.width: 1
    clip: true
    Accessible.role: Accessible.Grouping
    Accessible.name: activitySummary.showAnyActivity ? app.primaryText() + ". " + app.secondaryText() : i18n("No activity")

    RowLayout {
        visible: !activitySummary.iconOnly
        anchors.fill: parent
        anchors.margins: activitySummary.compact ? 10 : 14
        spacing: activitySummary.compact ? 9 : 13

        MaskedArtworkTile {
            Layout.preferredWidth: activitySummary.artSize
            Layout.preferredHeight: activitySummary.artSize
            artworkSource: app.hasPlayer ? app.player.artUrl : ""
            cornerRadius: activitySummary.compact ? 10 : T.radiusInner
            glyphSize: activitySummary.compact ? 28 : 36
            mode: activitySummary.summaryMode
            progress: Math.max(0, notificationsSource.jobsPercentage) / 100
            playing: app.isPlaying
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    PlasmaLabel {
                        Layout.fillWidth: true
                        text: activitySummary.showAnyActivity ? app.primaryText() : activitySummary.mediaOnly ? i18n("Nothing playing") : i18n("Ready")
                        color: T.textPrimary
                        font.pixelSize: activitySummary.compact ? T.fontBody + 1 : T.fontTitle
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    PlasmaLabel {
                        Layout.fillWidth: true
                        text: activitySummary.showAnyActivity ? app.secondaryText() : activitySummary.mediaOnly ? "" : i18n("Media, notifications and jobs")
                        color: T.textSecondary
                        font.pixelSize: activitySummary.compact ? T.fontCaption : T.fontBody
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
                Activities.AudioBars {
                    visible: activitySummary.mediaOnly
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 12
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 3
                    playing: app.isPlaying
                    barWidth: 1.5
                }
                IslandBars {
                    visible: !activitySummary.mediaOnly && (!activitySummary.compact || width >= 260)
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 28
                    color: activitySummary.activityColor
                    playing: app.isPlaying || app.hasJobs || app.hasNotifications
                }
            }

            Item {
                visible: !activitySummary.compact
                Layout.fillHeight: true
            }

            ProgressBar {
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                visible: !activitySummary.compact && ((!activitySummary.mediaOnly && app.hasJobs) || (app.hasPlayer && app.player.length > 0))
                from: 0
                to: !activitySummary.mediaOnly && app.hasJobs ? 100 : Math.max(1, app.player ? app.player.length : 1)
                value: !activitySummary.mediaOnly && app.hasJobs ? Math.max(0, notificationsSource.jobsPercentage) : app.player ? app.player.position : 0
                accent: T.fillSoft
                trackColor: T.track
            }

            // Media-only transport row: time, flat controls, duration (same
            // arrangement as the expanded media card).
            RowLayout {
                visible: !activitySummary.compact && activitySummary.mediaOnly
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 0

                PlasmaLabel {
                    Layout.preferredWidth: 36
                    text: app.hasPlayer && app.player.length > 0 ? app.formatMediaTime(app.player.position) : ""
                    color: T.textCaption
                    font.pixelSize: T.fontCaption
                    font.features: { "tnum": 1 }
                }
                Item { Layout.fillWidth: true }
                IslandButton {
                    Layout.rightMargin: 8
                    iconName: "media-skip-backward"
                    flat: true
                    glyphSize: 17
                    implicitWidth: 34
                    focusColor: T.focusRing
                    tooltipText: i18n("Previous")
                    enabled: app.player && app.player.canGoPrevious
                    onClicked: activitySummary.previous()
                }
                IslandButton {
                    iconName: app.isPlaying ? "media-playback-pause" : "media-playback-start"
                    flat: true
                    glyphSize: 23
                    implicitWidth: 40
                    focusColor: T.focusRing
                    tooltipText: app.isPlaying ? i18n("Pause") : i18n("Play")
                    enabled: app.player && (app.player.canPlay || app.player.canPause)
                    onClicked: activitySummary.playPause()
                }
                IslandButton {
                    Layout.leftMargin: 8
                    iconName: "media-skip-forward"
                    flat: true
                    glyphSize: 17
                    implicitWidth: 34
                    focusColor: T.focusRing
                    tooltipText: i18n("Next")
                    enabled: app.player && app.player.canGoNext
                    onClicked: activitySummary.next()
                }
                Item { Layout.fillWidth: true }
                PlasmaLabel {
                    Layout.preferredWidth: 36
                    text: app.hasPlayer && app.player.length > 0 ? app.formatMediaTime(app.player.length) : ""
                    color: T.textCaption
                    font.pixelSize: T.fontCaption
                    font.features: { "tnum": 1 }
                    horizontalAlignment: Text.AlignRight
                }
            }

            RowLayout {
                visible: !activitySummary.compact && !activitySummary.mediaOnly
                Layout.fillWidth: true
                spacing: 8
                RowLayout {
                    visible: app.hasPlayer
                    spacing: 8
                    IslandButton { iconName: "media-skip-backward"; compact: true; focusColor: T.focusRing; tooltipText: i18n("Previous"); enabled: app.player && app.player.canGoPrevious; onClicked: activitySummary.previous() }
                    IslandButton { iconName: app.isPlaying ? "media-playback-pause" : "media-playback-start"; compact: true; emphasized: true; focusColor: T.focusRing; tooltipText: app.isPlaying ? i18n("Pause") : i18n("Play"); enabled: app.player && (app.player.canPlay || app.player.canPause); onClicked: activitySummary.playPause() }
                    IslandButton { iconName: "media-skip-forward"; compact: true; focusColor: T.focusRing; tooltipText: i18n("Next"); enabled: app.player && app.player.canGoNext; onClicked: activitySummary.next() }
                }
                PlasmaLabel {
                    Layout.fillWidth: true
                    text: activitySummary.mediaOnly ? app.hasPlayer ? app.player.identity || i18n("Media player") : "" : app.hasJobs ? i18n("Download active") : app.hasNotifications ? i18np("%1 unread", "%1 unread", notificationsSource.unreadNotificationsCount) : i18n("No activity")
                    color: T.textSecondary
                    font.pixelSize: T.fontCaption
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }
            }
        }
    }

    MaskedArtworkTile {
        visible: activitySummary.iconOnly
        anchors.centerIn: parent
        width: activitySummary.artSize
        height: width
        artworkSource: app.hasPlayer ? app.player.artUrl : ""
        cornerRadius: 10
        glyphSize: width * 0.7
        mode: activitySummary.summaryMode
        progress: Math.max(0, notificationsSource.jobsPercentage) / 100
        playing: app.isPlaying
    }

    IslandBars {
        visible: activitySummary.iconOnly && (activitySummary.mediaOnly ? app.isPlaying : app.isPlaying || app.hasJobs || app.hasNotifications) && width >= 58
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        spacing: 2
        color: activitySummary.activityColor
        playing: true
    }
}
