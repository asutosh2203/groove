import QtQuick
import QtTest
import "../contents/ui/controlcenter" as Tiles

// D-46: the Control Center's media card reads the shown player only, even while a job owns the capsule.
Item {
    id: testRoot

    width: 400
    height: 300

    QtObject {
        id: app

        property bool playerShown: true
        readonly property bool hasActivity: true
        readonly property var decorClock: null
        function activityMode() { return "job"; }
        function primaryText() { return "Copying 4 files"; }
        function secondaryText() { return "to Documents/Holiday"; }
        readonly property var jobs: QtObject { readonly property bool hasJobs: true }
        readonly property var notifications: QtObject { readonly property bool hasNotifications: false }
        readonly property var media: QtObject {
            readonly property bool hasPlayer: app.playerShown
            readonly property bool isPlaying: true
            readonly property real length: 240000000
            readonly property var player: ({ "artUrl": "", "position": 0, "track": "Song", "artist": "Band" })
            readonly property var card: ({ "title": "Song", "subtitle": "Band" })
            readonly property string kind: "music"
            readonly property string placeholderKind: "music"
            function previous() {}
            function playPause() {}
            function next() {}
        }
    }

    QtObject {
        id: source

        property int jobsPercentage: 40
        property int unreadNotificationsCount: 0
    }

    Tiles.ActivitySummaryTile {
        id: tile

        width: 380
        height: 200
        app: app
        notificationsSource: source
        mediaOnly: true
    }

    TestCase {
        name: "ActivitySummaryTile"
        when: windowShown

        function test_media_card_shows_the_player_not_the_job() {
            compare(tile.titleText, "Song");
            compare(tile.subtitleText, "Band");
            verify(tile.Accessible.name.indexOf("Copying") < 0);
        }
    }
}
