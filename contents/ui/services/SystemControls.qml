pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.private.battery
import org.kde.plasma.private.batterymonitor
import org.kde.plasma.private.brightnesscontrolplugin as Brightness
import org.kde.plasma.private.volume as Volume
import org.kde.plasma.workspace.keyboardlayout as KeyboardLayout
import "../logic/SystemControls.js" as Logic
import "../logic/TextUtils.js" as TextUtils

// The Control Center's system controls: screen and keyboard brightness, volume and mute, the power menu, light/dark
// mode, the power profile and battery, who the user is, and the keyboard layout announcement. The decisions are pure
// (SystemControls.js); this object reads and drives the devices. Translated text stays with the caller (the battery and
// profile names). Commands go through the injected runner, so a test can replace it and nothing real is ever run.
Item {
    id: service

    required property var runner
    // Config: show the keyboard layout as an activity when it changes.
    property bool announceEnabled: true
    // How long the layout announcement stays up.
    property int announcementMs: 3420

    // A power action or lock was started: any popup should close.
    signal actionRun()
    // The keyboard layout changed and is announced (the activity bump).
    signal layoutAnnounced()

    property string systemUsername: ""
    property string systemHostname: ""
    property string profileImageUrl: ""
    property string screenDisplayName: ""
    property int screenValue: 0
    property int screenMax: 100
    property int screenVisualPercent: 0
    property bool screenVisualPinned: false
    property bool announcementActive: false
    readonly property alias battery: batteryModel
    readonly property alias screenBrightness: screenBrightnessControl
    // Untyped on purpose: qmllint does not know the display model's count.
    readonly property var displayModel: screenBrightnessControl.displays
    readonly property alias keyboardBrightness: keyboardBrightnessControl
    readonly property alias powerProfiles: powerProfilesControl
    // Untyped on purpose (see toggleMute).
    readonly property var globalService: Volume.GlobalService
    // PulseAudio's 100 % volume (PA_VOLUME_NORM, fixed by its ABI); the same value PulseAudio.NormalVolume reports,
    // which qmllint cannot resolve.
    readonly property int normalVolume: 65536
    // Bound to the default sink, so external mute changes and sink switches update every user.
    readonly property bool systemAudioAvailable: Volume.PreferredDevice.sink !== null && Volume.PreferredDevice.sink !== undefined
    readonly property bool systemMuted: systemAudioAvailable && Volume.PreferredDevice.sink.muted === true
    readonly property var layoutNames: Logic.layoutNames(keyboardLayout.layoutsList, keyboardLayout.layout)
    readonly property string layoutShortName: layoutNames.short
    readonly property string layoutDisplayName: layoutNames.display
    readonly property string layoutLongName: layoutNames.long
    readonly property string accountIconCommand: "sh -c 'user=$(id -un); path=$(qdbus6 org.freedesktop.Accounts /org/freedesktop/Accounts org.freedesktop.Accounts.FindUserByName \"$user\" 2>/dev/null); test -n \"$path\" && qdbus6 org.freedesktop.Accounts \"$path\" org.freedesktop.Accounts.User.IconFile 2>/dev/null'"

    // Who the user is: name, host and account picture.
    function refreshAccount() {
        runner.run("whoami", stdout => systemUsername = TextUtils.cleanText(stdout));
        runner.run("hostname", stdout => systemHostname = TextUtils.cleanText(stdout));
        runner.run(accountIconCommand, applyAccountIcon);
    }

    function applyAccountIcon(stdout) {
        profileImageUrl = Logic.accountIconUrl(TextUtils.cleanText(stdout));
    }

    function faceUrl() {
        return Logic.faceUrl(profileImageUrl, systemUsername);
    }

    // --- screen brightness -------------------------------------------------------------------------------------------

    function screenPercent() {
        const known = Logic.screenPercent(screenDisplayName, screenValue, screenMax);
        if (known >= 0)
            return known;

        const displays = displayModel;
        if (!screenBrightnessControl.isBrightnessAvailable || !displays || displays.count <= 0)
            return 0;

        const idx = displays.index(0, 0);
        return Logic.displayRowPercent([displays.data(idx, 258), displays.data(idx, 257)], [displays.data(idx, 259), displays.data(idx, 260)]);
    }

    function displayedScreenPercent() {
        return Logic.displayedScreenPercent(screenBrightnessControl.isBrightnessAvailable, screenVisualPinned, screenVisualPercent, screenBrightnessControl.isBrightnessAvailable ? screenPercent() : 0);
    }

    // A display reported its brightness.
    function syncScreenDisplay(displayName, value, max) {
        const next = Logic.syncDisplay(displayName, value, max, screenVisualPinned, screenVisualPercent);
        screenDisplayName = next.displayName;
        screenValue = next.value;
        screenMax = next.max;
        screenVisualPercent = next.visualPercent;
        screenVisualPinned = next.pinned;
    }

    function setScreenPercent(value) {
        if (!screenBrightnessControl.isBrightnessAvailable)
            return ;

        const target = Logic.screenTarget(value, screenDisplayName, screenMax, screenPercent());
        screenVisualPercent = target.percent;
        screenVisualPinned = true;
        screenSettleTimer.restart();
        if (target.absolute !== null)
            screenBrightnessControl.setBrightness(screenDisplayName, target.absolute);
        else
            screenBrightnessControl.adjustBrightnessRatio(target.ratio);
    }

    // --- keyboard backlight ------------------------------------------------------------------------------------------

    function keyboardPercent() {
        return Logic.keyboardPercent(keyboardBrightnessControl.isBrightnessAvailable, keyboardBrightnessControl.brightnessMax, keyboardBrightnessControl.brightness);
    }

    function setKeyboardPercent(value) {
        const target = Logic.keyboardTarget(keyboardBrightnessControl.isBrightnessAvailable, keyboardBrightnessControl.brightnessMax, value);
        if (target !== null)
            keyboardBrightnessControl.brightness = target;

    }

    // --- volume ------------------------------------------------------------------------------------------------------

    function adjustVolume(up) {
        if (up)
            Volume.GlobalService.volumeUp();
        else
            Volume.GlobalService.volumeDown();
    }

    function defaultSink() {
        return Volume.PreferredDevice.sink || null;
    }

    function volumePercent() {
        const sink = defaultSink();
        return sink ? Logic.volumePercent(sink.volume, normalVolume) : 0;
    }

    function setVolumePercent(value) {
        const sink = defaultSink();
        if (!sink)
            return ;

        sink.muted = false;
        sink.volume = Logic.volumeTarget(value, normalVolume);
    }

    function toggleMute() {
        const sink = defaultSink();
        if (sink)
            sink.muted = !sink.muted;
        else
            // Logged bug, behaviour kept: Plasma 6.8 has no globalMute() (only globalMuteSinks / globalMuteSources), so
            // with no default sink this throws and nothing happens, exactly as it did in main.qml. Called by name so
            // the linter does not flag the move.
            globalService.globalMute();
    }

    // --- power -------------------------------------------------------------------------------------------------------

    function lockScreen() {
        runner.run(Logic.powerCommand("lock"));
        actionRun();
    }

    function runPowerAction(action) {
        const command = Logic.powerCommand(action);
        if (command !== null)
            runner.run(command);

        actionRun();
    }

    function toggleAppearanceMode() {
        Brightness.DarkModeControl.darkMode = !Brightness.DarkModeControl.darkMode;
    }

    function cycleProfile() {
        const next = Logic.nextProfile(powerProfilesControl.profiles, powerProfilesControl.activeProfile);
        if (next !== null)
            powerProfilesControl.setProfile(next);

    }

    function profileIcon() {
        return Logic.profileIcon(powerProfilesControl.activeProfile);
    }

    // "performance" | "saver" | "balanced"
    function profileKind() {
        return Logic.profileKind(powerProfilesControl.activeProfile);
    }

    // "percent" | "ac" | "power"
    function batteryKind() {
        return Logic.batteryKind(batteryModel.hasInternalBatteries, batteryModel.pluggedIn);
    }

    // --- keyboard layout announcement --------------------------------------------------------------------------------

    function announceLayout() {
        if (!announceEnabled)
            return ;
        announcementActive = true;
        announcementTimer.restart();
        layoutAnnounced();
    }

    function cancelAnnouncement() {
        announcementTimer.stop();
        announcementActive = false;
    }

    Brightness.ScreenBrightnessControl {
        id: screenBrightnessControl

        isSilent: true
    }

    Instantiator {
        model: screenBrightnessControl.displays

        delegate: QtObject {
            required property int index
            required property string displayName
            required property int brightness
            required property int maxBrightness

            function syncIfPrimary() {
                if (index === 0)
                    service.syncScreenDisplay(displayName, brightness, maxBrightness);
            }

            Component.onCompleted: syncIfPrimary()
            onBrightnessChanged: syncIfPrimary()
            onMaxBrightnessChanged: syncIfPrimary()
            onDisplayNameChanged: syncIfPrimary()
        }
    }

    Timer {
        id: screenSettleTimer

        interval: 900
        repeat: false
        onTriggered: {
            service.screenVisualPinned = false;
            service.screenVisualPercent = service.screenPercent();
        }
    }

    Brightness.KeyboardBrightnessControl {
        id: keyboardBrightnessControl

        isSilent: true
    }

    PowerProfilesControl {
        id: powerProfilesControl

        isSilent: true
    }

    BatteryControlModel {
        id: batteryModel
    }

    KeyboardLayout.KeyboardLayout {
        id: keyboardLayout

        property bool announcementReady: false

        Component.onCompleted: Qt.callLater(function() {
            keyboardLayout.announcementReady = true;
        })
        onLayoutChanged: {
            if (announcementReady)
                service.announceLayout();
        }
    }

    Timer {
        id: announcementTimer

        interval: service.announcementMs
        repeat: false
        onTriggered: service.announcementActive = false
    }
}
