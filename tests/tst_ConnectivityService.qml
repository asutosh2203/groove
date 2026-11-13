import QtQuick
import QtTest
import "../contents/ui/services"

// A fake runner stands in for the command engine: nothing is executed, so no radio is touched and no process starts.
// The handlers it records are called with canned output, exactly as the real runner would.
TestCase {
    id: tc

    name: "ConnectivityService"
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
        function reply(command, stdout) {
            handlers[command](stdout);
        }
    }

    ConnectivityService {
        id: service

        runner: fakeRunner
    }

    function init() {
        fakeRunner.calls = [];
        fakeRunner.handlers = {};
    }

    function test_bluetooth_refresh_runs_both_commands_and_parses_the_replies() {
        service.refreshBluetooth();
        compare(fakeRunner.calls, ["bluetoothctl show", "bluetoothctl devices Connected"]);
        fakeRunner.reply("bluetoothctl show", "Controller AA (public)\n\tAlias: laptop\n\tPowered: yes");
        fakeRunner.reply("bluetoothctl devices Connected", "Device AA:BB Buds\nDevice CC:DD Mouse");
        verify(service.bluetoothAvailable);
        verify(service.bluetoothPowered);
        compare(service.bluetoothAdapterName, "laptop");
        compare(service.bluetoothDeviceCount(), 2);
        compare(service.bluetoothSummary().kind, "devices");
        fakeRunner.reply("bluetoothctl show", "No default controller available");
        verify(!service.bluetoothAvailable);
        compare(service.bluetoothSummary().kind, "noAdapter");
    }

    function test_toggling_bluetooth_power_sends_the_opposite_command() {
        service.bluetoothPowered = true;
        service.toggleBluetoothPower();
        service.bluetoothPowered = false;
        service.toggleBluetoothPower();
        compare(fakeRunner.calls, ["bluetoothctl power off", "bluetoothctl power on"]);
        service.bluetoothPowered = false;
    }

    function test_wifi_refresh_runs_the_three_nmcli_commands_and_parses() {
        service.refreshWifi();
        compare(fakeRunner.calls, [service.wifiScanCommand, service.networkStatusCommand, service.networkIpCommand]);
        fakeRunner.reply(service.wifiScanCommand, "*:Home:80:wlan0\n :Other:40:wlan0");
        compare(service.wifiNetworks.length, 2);
        fakeRunner.reply(service.networkStatusCommand, "wifi:wlan0:connected:Home");
        compare(service.networkDevices.length, 1);
    }

    function test_kde_connect_refresh_and_actions() {
        service.refreshKdeConnectDevices();
        compare(fakeRunner.calls[0], "kdeconnect-cli --refresh");
        compare(fakeRunner.calls.length, 3); // refresh + paired + connected
        fakeRunner.calls = [];
        service.runKdeConnectDeviceAction("  ", "ring");
        service.runKdeConnectDeviceAction("abc", "nonsense");
        compare(fakeRunner.calls.length, 0);
        service.runKdeConnectDeviceAction("a'b", "ring");
        compare(fakeRunner.calls, ["kdeconnect-cli --device 'a'\"'\"'b' --ring"]);
        service.runKdeConnectDeviceAction("abc", "browse");
        compare(fakeRunner.calls[1], "qdbus6 org.kde.kdeconnect '/modules/kdeconnect/devices/abc/sftp' org.kde.kdeconnect.device.sftp.startBrowsing");
    }

    function test_kde_connect_devices_follow_the_paired_and_connected_lists() {
        service.kdeConnectPaired = [{ id: "a", name: "Phone" }, { id: "b", name: "Tablet" }];
        service.kdeConnectConnected = [{ id: "a", name: "Phone" }];
        compare(service.kdeConnectDevices(0).length, 2);
        compare(service.kdeConnectDevices(1).length, 1);
        compare(service.kdeConnectReachableCount(), 1);
    }

    function test_polling_is_off_until_asked() {
        verify(!service.polling);
    }
}
