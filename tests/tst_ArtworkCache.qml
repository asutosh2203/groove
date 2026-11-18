import QtQuick
import QtTest
import "../contents/ui/services"

// Remote cover art is fetched once per URL through the runner and shown from disk (D-37, ArtCache.js).
TestCase {
    id: tc

    name: "ArtworkCache"
    when: windowShown

    property var commands: []
    property var handlers: []
    readonly property string url: "https://i.scdn.co/image/abc"

    QtObject {
        id: fakeRunner

        function run(command, handler) {
            tc.commands.push(command);
            tc.handlers.push(handler);
        }
    }

    ArtworkCache {
        id: cache

        runner: fakeRunner
    }

    ArtworkCache {
        id: bare
    }

    function init() {
        tc.commands = [];
        tc.handlers = [];
        cache.url = "";
        cache.results = ({});
    }

    function test_remote_url_is_fetched_once_and_shown_from_disk() {
        cache.url = tc.url;
        compare(tc.commands.length, 1);
        verify(tc.commands[0].indexOf("curl") >= 0);
        compare(cache.source, "");  // the placeholder shows while it is fetched
        tc.handlers[0]("/home/u/.cache/kove/art/art-1\n");
        compare(cache.source, "file:///home/u/.cache/kove/art/art-1");
        cache.url = "";
        cache.url = tc.url;
        compare(tc.commands.length, 1);  // known: not fetched again
        compare(cache.source, "file:///home/u/.cache/kove/art/art-1");
    }

    function test_failed_fetch_falls_back_to_the_original_url() {
        cache.url = tc.url;
        tc.handlers[0]("");
        compare(cache.source, tc.url);
    }

    function test_local_urls_pass_through_without_a_command() {
        cache.url = "file:///tmp/cover.png";
        compare(tc.commands.length, 0);
        compare(cache.source, "file:///tmp/cover.png");
    }

    function test_unsafe_url_is_never_run() {
        cache.url = "https://x.test/a'; rm -rf ~ #";
        compare(tc.commands.length, 0);
    }

    function test_without_a_runner_the_url_passes_through() {
        bare.url = tc.url;
        compare(bare.source, tc.url);
    }
}
