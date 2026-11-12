import QtQuick
import QtTest
import "../contents/ui/services"

TestCase {
    id: tc

    name: "CommandRunner"
    when: windowShown

    property var got: []

    CommandRunner {
        id: runner
    }

    function init() {
        got = [];
    }

    function collect(stdout) {
        tc.got.push(String(stdout));
    }

    function test_handler_gets_stdout() {
        runner.run("printf hello", tc.collect);
        tryCompare(tc.got, "length", 1, 5000);
        compare(tc.got[0], "hello");
    }

    function test_identical_commands_share_one_result() {
        const other = function(stdout) { tc.got.push("other:" + stdout); };
        runner.run("sleep 0.3; printf shared", tc.collect);
        runner.run("sleep 0.3; printf shared", other);
        runner.run("sleep 0.3; printf shared", tc.collect); // same handler again: not added twice
        tryCompare(tc.got, "length", 2, 5000);
        wait(400);
        compare(tc.got.length, 2);
        verify(tc.got.indexOf("shared") !== -1);
        verify(tc.got.indexOf("other:shared") !== -1);
    }

    function test_results_route_to_their_own_caller() {
        runner.run("printf one", function(s) { tc.got.push("a:" + s); });
        runner.run("printf two", function(s) { tc.got.push("b:" + s); });
        tryCompare(tc.got, "length", 2, 5000);
        verify(tc.got.indexOf("a:one") !== -1);
        verify(tc.got.indexOf("b:two") !== -1);
    }

    function test_fire_and_forget_and_empty_commands_are_harmless() {
        runner.run("true");
        runner.run("");
        runner.run(undefined, tc.collect);
        wait(300);
        compare(tc.got.length, 0);
    }

    function test_a_finished_command_can_run_again() {
        runner.run("printf again", tc.collect);
        tryCompare(tc.got, "length", 1, 5000);
        runner.run("printf again", tc.collect);
        tryCompare(tc.got, "length", 2, 5000);
    }
}
