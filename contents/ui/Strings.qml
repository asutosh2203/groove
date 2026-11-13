pragma ComponentBehavior: Bound

import QtQuick
import "logic/Utils.js" as Utils

// Every user-visible string that is chosen in code, in one place. The services and the logic modules never translate:
// they return which line applies ("off", "noAdapter", ...) and this file turns that into the user's language.
//
// i18n() and i18np() are Plasma's global translation functions, supplied to the QML engine at runtime (KLocalizedContext).
// The linter cannot see them, so each call is reported as an unqualified access: a false positive that cannot be
// qualified. The suppression below is limited to this one block, so the rest of the codebase keeps full checking. One
// instance per island (no singleton); main.qml exposes it as `strings`.
QtObject {
    // qmllint disable unqualified
    readonly property string appTitle: i18n("Dynamic Island")
    readonly property string idleTitle: i18n("Control Center")
    readonly property string idleSubtitle: i18n("Brightness, audio, network, power")
    readonly property string notificationFallback: i18n("Notification")
    readonly property string previous: i18n("Previous")
    readonly property string pause: i18n("Pause")
    readonly property string play: i18n("Play")
    readonly property string next: i18n("Next")
    readonly property string themeSettings: i18n("Theme settings")
    readonly property string themeSettingsDetail: i18n("Choose light and dark themes in System Settings")
    readonly property string themeSettingsFooter: i18n("Click to open")

    // The current colour scheme, read only (D-40): the widget never switches it.
    function colorSchemeName(dark) {
        return dark ? i18n("Dark") : i18n("Light");
    }

    function notificationStatus(count) {
        if (count <= 0)
            return i18n("Quiet");
        if (count === 1)
            return i18n("1 notification");
        return i18np("%1 notification", "%1 notifications", count);
    }

    // The job's own title, or "Working" when it has none.
    function jobTitle(title) {
        return title.length > 0 ? title : i18n("Working");
    }

    // parts: Jobs.detailsParts
    function jobDetails(parts) {
        switch (parts.kind) {
        case "paused":
            return i18n("Paused");
        case "speed":
            return Utils.formatByteSize(parts.speed) + "/s";
        case "progress":
            return i18n("%1 of %2", Utils.formatByteSize(parts.processed), Utils.formatByteSize(parts.total));
        case "app":
            return parts.text;
        default:
            return "";
        }
    }

    function wifiTitle(hardwareEnabled, enabled) {
        if (!hardwareEnabled)
            return i18n("Unavailable");
        return enabled ? i18n("On") : i18n("Off");
    }

    // summary: Bluetooth.summary
    function bluetoothSummary(summary) {
        switch (summary.kind) {
        case "noAdapter":
            return i18n("No adapter");
        case "off":
            return i18n("Off");
        case "on":
            return i18n("On");
        case "device":
            return summary.text;
        default:
            return i18np("%1 device", "%1 devices", summary.count);
        }
    }

    // detail: Bluetooth.detail
    function bluetoothDetail(detail) {
        switch (detail.kind) {
        case "unavailable":
            return i18n("Bluetooth adapter unavailable");
        case "radioOff":
            return i18n("Radio disabled");
        case "devices":
        case "adapter":
            return detail.text;
        default:
            return i18n("No connected devices");
        }
    }

    // kind: KdeConnectState.summaryKind
    function kdeConnectSummary(kind, connectedCount) {
        if (kind === "connected")
            return i18np("%1 connected", "%1 connected", connectedCount);
        return kind === "away" ? i18n("Not nearby") : i18n("No devices");
    }

    // kind: SystemControls.profileKind
    function profileTitle(kind) {
        switch (kind) {
        case "performance":
            return i18n("Performance");
        case "saver":
            return i18n("Saver");
        default:
            return i18n("Balanced");
        }
    }

    // kind: SystemControls.batteryKind
    function batteryText(kind, percent) {
        switch (kind) {
        case "ac":
            return i18n("AC");
        case "power":
            return i18n("Power");
        default:
            return percent + "%";
        }
    }
    // qmllint enable unqualified
}
