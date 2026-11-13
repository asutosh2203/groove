pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.mpris as Mpris
import "../logic/MediaIdle.js" as MediaIdle
import "../logic/MediaLength.js" as MediaLength
import "../logic/MediaPlayers.js" as MediaPlayers
import "../logic/Utils.js" as Utils

// The media backend: which MPRIS player the island shows, its held track length, the 30 s idle grace (D-35) and the
// transport controls. The decisions are pure (MediaPlayers.js, MediaLength.js, MediaIdle.js); this object feeds them
// the live players and runs the two timers. The owner reacts to mediaEvent() (activity bump) and says, through
// positionPolling, when a position readout can be seen.
Item {
    id: service

    // True while a position readout is visible (media pill, popup or Control Center card): the poll runs only then.
    property bool positionPolling: false

    // The shown player changed, or its playback status or track did.
    signal mediaEvent()

    // Bumped on any change that can alter which player is best or what it shows; the player and length re-read on it.
    property int revision: 0
    // When each player last started and stopped playing, by player key (MediaPlayers.noteStatus). Mutated in place and
    // read through `revision`, so a change bumps the revision rather than notifying on its own.
    property var activity: ({})
    // The player entries, untyped on purpose: qmllint types objectAt() as a bare QObject and cannot see the delegate's members.
    readonly property var entries: instantiator
    readonly property var player: {
        if (revision < 0) // never true: reading it re-evaluates this whenever a player changes
            return null;

        return best();
    }
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool isPlaying: hasPlayer && player.playbackStatus === Mpris.PlaybackStatus.Playing
    // The track length in microseconds, held across metadata updates that omit it (MediaLength.js).
    property real length: 0
    property var heldLength: null
    // A player that exists but hasn't played for 30 s hands the island back to the idle face; anything that starts
    // playing takes it back at once (D-35).
    property bool graceExpired: false
    readonly property bool shown: MediaIdle.shown(hasPlayer, isPlaying, graceExpired)
    readonly property var status: ({
        "playing": Mpris.PlaybackStatus.Playing,
        "paused": Mpris.PlaybackStatus.Paused,
        "stopped": Mpris.PlaybackStatus.Stopped
    })

    // Records a player's playback status (when it started or stopped playing, D-39). `key` is the player's bus name.
    function noteStatus(key, playbackStatus) {
        activity[key] = MediaPlayers.noteStatus(activity[key], playbackStatus === Mpris.PlaybackStatus.Playing, Date.now());
    }

    // The player to show: every player Plasma knows (the model also lists the active player a second time, so a player
    // already seen is skipped), ranked by MediaPlayers.pick with the recorded start and stop times.
    function best() {
        const views = [];
        const containers = [];
        for (let i = 0; entries && i < entries.count; ++i) {
            const entry = entries.objectAt(i);
            if (!entry || !entry.playerContainer || containers.indexOf(entry.playerContainer) !== -1)
                continue;

            const record = activity[entry.key];
            containers.push(entry.playerContainer);
            views.push({
                "playbackStatus": entry.playbackStatus,
                "track": entry.track,
                "artist": entry.artist,
                "album": entry.album,
                "artUrl": entry.artUrl,
                "length": entry.length,
                "identity": entry.identity,
                "desktopEntry": entry.desktopEntry,
                "canControl": entry.canControl,
                "canPlay": entry.canPlay,
                "canPause": entry.canPause,
                "startedAt": record ? record.startedAt : 0,
                "stoppedAt": record ? record.stoppedAt : 0
            });
        }
        const pick = MediaPlayers.pick(views, status);
        return pick.source === "candidate" ? containers[pick.index] : null;
    }

    function refreshLength() {
        heldLength = MediaLength.hold(heldLength, MediaPlayers.lengthKey(player), player ? Utils.finiteNumber(player.length, 0) : 0);
        length = heldLength.length;
    }

    function idleEvent(event) {
        const r = MediaIdle.reduce({ "expired": graceExpired }, event);
        graceExpired = r.expired;
        if (r.scheduleMs !== null) {
            idleTimer.interval = r.scheduleMs;
            idleTimer.restart();
        } else {
            idleTimer.stop();
        }
    }

    function syncIdle() {
        idleEvent(!hasPlayer ? "gone" : isPlaying ? "playing" : "notPlaying");
    }

    function previous() {
        const current = player;
        if (current && current.canGoPrevious)
            current.Previous();
    }

    function playPause() {
        const current = player;
        if (current && (current.canPlay || current.canPause))
            current.PlayPause();
    }

    function next() {
        const current = player;
        if (current && current.canGoNext)
            current.Next();
    }

    // delta is a fraction of full volume (0.04 = 4 %).
    function changeVolume(delta) {
        if (player && player.changeVolume)
            player.changeVolume(delta, true);

    }

    onRevisionChanged: refreshLength()
    // The island now shows a different player (or the first one): let the activity know.
    onPlayerChanged: {
        if (hasPlayer)
            mediaEvent();

    }
    onHasPlayerChanged: syncIdle()
    onIsPlayingChanged: syncIdle()
    // Refresh right away so the bar is current the moment it appears.
    onPositionPollingChanged: {
        if (positionPolling && player && player.updatePosition)
            player.updatePosition();

    }
    Component.onCompleted: syncIdle()

    Timer {
        id: idleTimer

        repeat: false
        onTriggered: service.idleEvent("timeout")
    }

    Timer {
        id: positionTimer

        interval: 1000
        running: service.positionPolling
        repeat: true
        onTriggered: {
            if (service.player && service.player.updatePosition)
                service.player.updatePosition();

        }
    }

    Mpris.Mpris2Model {
        id: mprisModel

        onCurrentPlayerChanged: service.revision++
    }

    Instantiator {
        id: instantiator

        model: mprisModel
        onObjectAdded: service.revision++
        onObjectRemoved: service.revision++

        delegate: QtObject {
            id: entry

            required property var model
            readonly property var playerContainer: entry.model.container
            readonly property int playbackStatus: entry.model.playbackStatus
            readonly property string track: entry.model.track || ""
            readonly property string artist: entry.model.artist || ""
            readonly property string album: entry.model.album || ""
            readonly property string artUrl: entry.model.artUrl || ""
            readonly property real length: Utils.finiteNumber(entry.model.length, 0)
            readonly property string identity: entry.model.identity || ""
            // The player's stable key: its bus name (the same for the duplicate row of the active player).
            readonly property string key: playerContainer && playerContainer.objectName ? playerContainer.objectName : identity
            readonly property string desktopEntry: entry.model.desktopEntry || ""
            readonly property bool canControl: entry.model.canControl || false
            readonly property bool canPlay: entry.model.canPlay || false
            readonly property bool canPause: entry.model.canPause || false

            Component.onCompleted: service.noteStatus(entry.key, entry.playbackStatus)
            onPlaybackStatusChanged: {
                service.noteStatus(entry.key, entry.playbackStatus);
                service.revision++;
            }
            onTrackChanged: service.revision++
            onArtistChanged: service.revision++
            onAlbumChanged: service.revision++
            onArtUrlChanged: service.revision++
            onLengthChanged: service.revision++
            onIdentityChanged: service.revision++
        }
    }

    Connections {
        function onPlaybackStatusChanged() {
            service.mediaEvent();
        }

        function onTrackChanged() {
            service.mediaEvent();
        }

        target: service.player
    }
}
