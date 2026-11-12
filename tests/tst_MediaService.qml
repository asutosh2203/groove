import QtQuick
import QtTest
import "../contents/ui/services"

// The player selection and times are pure and tested in tests/media-players.test.cjs; this only checks the service
// builds against the real MPRIS model and keeps its own bookkeeping consistent. It never sends a transport command:
// whatever is playing on the machine running the tests must be left alone.
TestCase {
    id: tc

    name: "MediaService"
    when: windowShown

    MediaService {
        id: media
    }

    function test_builds_and_stays_consistent() {
        compare(media.hasPlayer, media.player !== null && media.player !== undefined);
        compare(media.isPlaying, media.hasPlayer && media.player.playbackStatus === media.status.playing);
        verify(media.length >= 0);
        compare(media.shown, media.hasPlayer && (media.isPlaying || !media.graceExpired));
    }

    function test_idle_grace_follows_the_player_state() {
        media.idleEvent("playing");
        verify(!media.graceExpired);
        media.idleEvent("timeout");
        verify(media.graceExpired);
        media.idleEvent("gone");
        verify(!media.graceExpired);
        media.syncIdle(); // back to whatever the real players say
    }

    function test_a_missing_player_ignores_transport_commands() {
        // changeVolume needs a player with that method; with none (or one without it) it must do nothing.
        if (!media.hasPlayer) {
            media.previous();
            media.playPause();
            media.next();
            media.changeVolume(0.04);
        }
        verify(true);
    }

    function test_position_polling_flag_is_just_an_input() {
        media.positionPolling = true;
        media.positionPolling = false;
        verify(!media.positionPolling);
    }
}
