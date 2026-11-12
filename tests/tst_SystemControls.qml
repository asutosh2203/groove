import QtQuick
import QtTest
import "../contents/ui/services"

// Safe on any machine: a fake runner stands in for the command engine (nothing is executed, so lock, logout, suspend,
// reboot and power off can never fire), and none of the hardware setters (brightness, volume, mute, profile, theme) is
// called. Only read paths and the command strings are exercised; the decisions are in tests/system-controls.test.cjs.
TestCase {
    id: tc

    name: "SystemControls"
    when: windowShown

    QtObject {
        id: fakeRunner

        property var calls: []
        property var handlers: ({})
        function run(command, handler) {
            calls.push(command);
            if (handler)
                handlers[command] = handler;
        }
    }

    SystemControls {
        id: service

        runner: fakeRunner
        onActionRun: tc.actions++
        onLayoutAnnounced: tc.announced++
    }

    property int actions: 0
    property int announced: 0

    function init() {
        fakeRunner.calls = [];
        fakeRunner.handlers = {};
        actions = 0;
        announced = 0;
        service.announceEnabled = true;
        service.cancelAnnouncement();
    }

    function test_every_power_action_runs_its_command_through_the_runner_and_closes_the_popup() {
        const expected = {
            "lock": "loginctl lock-session",
            "logout": "qdbus6 org.kde.Shutdown /Shutdown logout",
            "sleep": "systemctl suspend",
            "hibernate": "systemctl hibernate",
            "reboot": "systemctl reboot",
            "shutdown": "systemctl poweroff"
        };
        for (const action in expected) {
            fakeRunner.calls = [];
            service.runPowerAction(action);
            compare(fakeRunner.calls, [expected[action]], action);
        }
        compare(actions, 6);
    }

    function test_an_unknown_power_action_runs_nothing_but_still_closes_the_popup() {
        service.runPowerAction("bogus");
        service.runPowerAction("");
        service.runPowerAction("suspend; rm -rf ~");
        compare(fakeRunner.calls.length, 0);
        compare(actions, 3);
    }

    function test_lock_screen_runs_the_lock_command() {
        service.lockScreen();
        compare(fakeRunner.calls, ["loginctl lock-session"]);
        compare(actions, 1);
    }

    function test_account_refresh_runs_three_commands_and_parses_their_replies() {
        service.refreshAccount();
        compare(fakeRunner.calls.length, 3);
        compare(fakeRunner.calls[0], "whoami");
        compare(fakeRunner.calls[1], "hostname");
        fakeRunner.handlers["whoami"]("asutosh\n");
        fakeRunner.handlers["hostname"](" cursed-cachy ");
        compare(service.systemUsername, "asutosh");
        compare(service.systemHostname, "cursed-cachy");
        compare(service.faceUrl(), "file:///var/lib/AccountsService/icons/asutosh");
        service.applyAccountIcon("/home/asutosh/.face\n");
        compare(service.profileImageUrl, "file:///home/asutosh/.face");
        compare(service.faceUrl(), "file:///home/asutosh/.face");
        service.applyAccountIcon("");
        compare(service.faceUrl(), "file:///var/lib/AccountsService/icons/asutosh");
    }

    function test_the_layout_announcement_needs_the_setting_and_expires() {
        service.announceEnabled = false;
        service.announceLayout();
        verify(!service.announcementActive);
        compare(announced, 0);
        service.announceEnabled = true;
        service.announcementMs = 60;
        service.announceLayout();
        verify(service.announcementActive);
        compare(announced, 1);
        tryCompare(service, "announcementActive", false, 2000);
        service.announceLayout();
        service.cancelAnnouncement();
        verify(!service.announcementActive);
    }

    function test_read_paths_are_consistent_with_the_devices() {
        verify(service.screenPercent() >= 0 && service.screenPercent() <= 100);
        verify(service.keyboardPercent() >= 0 && service.keyboardPercent() <= 100);
        verify(service.volumePercent() >= 0 && service.volumePercent() <= 100);
        compare(service.systemAudioAvailable, service.defaultSink() !== null);
        verify(["performance", "saver", "balanced"].indexOf(service.profileKind()) !== -1);
        verify(["percent", "ac", "power"].indexOf(service.batteryKind()) !== -1);
        verify(service.profileIcon().indexOf("battery-profile-") === 0);
    }
}
