pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.networkmanagement as PlasmaNM
import "../logic/Bluetooth.js" as Bluetooth
import "../logic/KdeConnectState.js" as KdeConnectState
import "../logic/NetworkState.js" as NetworkState
import "../logic/TextUtils.js" as TextUtils
import "../logic/Utils.js" as Utils

// Bluetooth, Wi-Fi / network and KDE Connect state for the Control Center. The commands (bluetoothctl, nmcli) and their
// parsing are unchanged (native sources are a later milestone); the decisions are pure (Bluetooth.js, NetworkState.js,
// KdeConnectState.js). Translated text stays with the caller. Nothing runs in the background while the Control Center
// is closed: the periodic refresh is gated by `polling`.
Item {
    id: service

    required property var runner
    // The Control Center is showing: refresh every 30 s.
    property bool polling: false

    property bool bluetoothPowered: false
    property bool bluetoothAvailable: false
    property string bluetoothAdapterName: ""
    property string bluetoothDevicesText: ""
    property var wifiNetworks: []
    property var networkDevices: []
    property var networkAddresses: []
    property var kdeConnectPaired: []
    property var kdeConnectConnected: []
    readonly property alias connections: enabledConnections
    readonly property var networkState: NetworkState.summarize(networkDevices, networkAddresses, wifiNetworks, enabledConnections.networkingEnabled, enabledConnections.wirelessEnabled && enabledConnections.wirelessHwEnabled)
    readonly property string wifiScanCommand: "env LC_ALL=C nmcli --colors no -t -f IN-USE,SSID,SIGNAL,DEVICE device wifi list --rescan no"
    readonly property string networkStatusCommand: "env LC_ALL=C nmcli --colors no -t -f TYPE,DEVICE,STATE,CONNECTION device status"
    readonly property string networkIpCommand: "env LC_ALL=C nmcli --colors no -t -f GENERAL.DEVICE,IP4.ADDRESS,IP6.ADDRESS device show"

    function refreshAll() {
        refreshBluetooth();
        refreshWifi();
        refreshKdeConnect();
    }

    function refreshBluetooth() {
        runner.run("bluetoothctl show", stdout => {
            bluetoothAvailable = Bluetooth.parseAvailable(stdout);
            bluetoothAdapterName = Bluetooth.parseAdapterName(stdout);
            bluetoothPowered = Bluetooth.parsePowered(stdout);
        });
        runner.run("bluetoothctl devices Connected", stdout => bluetoothDevicesText = Bluetooth.parseDevices(stdout));
    }

    function toggleBluetoothPower() {
        runner.run(bluetoothPowered ? "bluetoothctl power off" : "bluetoothctl power on");
        bluetoothRefreshTimer.restart();
    }

    function bluetoothDeviceCount() {
        return Bluetooth.deviceCount(bluetoothDevicesText);
    }

    function bluetoothSummary() {
        return Bluetooth.summary(bluetoothAvailable, bluetoothPowered, bluetoothDevicesText);
    }

    function bluetoothDetail() {
        return Bluetooth.detail(bluetoothAvailable, bluetoothPowered, bluetoothDevicesText, bluetoothAdapterName);
    }

    function refreshWifi() {
        runner.run(wifiScanCommand, stdout => wifiNetworks = NetworkState.parseWifi(stdout));
        runner.run(networkStatusCommand, stdout => networkDevices = NetworkState.parseDevices(stdout));
        runner.run(networkIpCommand, stdout => networkAddresses = NetworkState.parseAddresses(stdout));
    }

    function toggleWifi() {
        networkHandler.enableWireless(!enabledConnections.wirelessEnabled);
        wifiRefreshTimer.restart();
    }

    function wifiPrimaryNetwork() {
        return networkState.wifiSummary;
    }

    function wifiSignalPercent() {
        return Math.max(0, networkState.wifiSignal);
    }

    function refreshKdeConnect() {
        runner.run(KdeConnectState.pairedCommand, stdout => kdeConnectPaired = KdeConnectState.parseNames(stdout));
        runner.run(KdeConnectState.connectedCommand, stdout => kdeConnectConnected = KdeConnectState.parseNames(stdout));
    }

    function refreshKdeConnectDevices() {
        runner.run("kdeconnect-cli --refresh");
        refreshKdeConnect();
    }

    function kdeConnectDevices(limit) {
        const all = KdeConnectState.buildDevices(kdeConnectPaired, kdeConnectConnected);
        const maxRows = Math.max(0, Math.round(Utils.finiteNumber(limit, 0)));
        return maxRows > 0 ? all.slice(0, maxRows) : all;
    }

    function kdeConnectReachableCount() {
        return KdeConnectState.connectedCount(kdeConnectDevices(0));
    }

    function runKdeConnectDeviceAction(deviceId, action) {
        const id = TextUtils.cleanText(deviceId);
        if (id.length <= 0)
            return ;

        if (action === "ring")
            runner.run("kdeconnect-cli --device " + Utils.shellQuote(id) + " --ring");
        else if (action === "browse")
            runner.run("qdbus6 org.kde.kdeconnect /modules/kdeconnect/devices/" + id + "/sftp org.kde.kdeconnect.device.sftp.startBrowsing");
    }

    Timer {
        id: bluetoothRefreshTimer

        interval: 900
        repeat: false
        onTriggered: service.refreshBluetooth()
    }

    Timer {
        id: wifiRefreshTimer

        interval: 900
        repeat: false
        onTriggered: service.refreshWifi()
    }

    Timer {
        // Connectivity is only shown in the control center. Avoid running subprocesses in the background while the
        // island is idle.
        interval: 30000
        repeat: true
        running: service.polling
        triggeredOnStart: false
        onTriggered: service.refreshAll()
    }

    PlasmaNM.EnabledConnections {
        id: enabledConnections
    }

    // Declared but not read anywhere (it was like this in main.qml); kept so nothing about the startup changes.
    PlasmaNM.WirelessStatus {
        id: wirelessStatus
    }

    PlasmaNM.Handler {
        id: networkHandler
    }
}
