pragma ComponentBehavior: Bound

import QtQuick
import org.kde.notificationmanager as NotificationManager
import ".."
import "../logic/NoticeDuration.js" as NoticeDuration
import "../logic/NotificationOpen.js" as NotificationOpen
import "../logic/Notifications.js" as Notif
import "../logic/TextUtils.js" as TextUtils
import "../logic/Utils.js" as Utils

// The notification backend: Plasma's notification model, how each row reads, which notification the island is
// presenting and for how long (D-33), click-through (D-31) and Clear All. The decisions are pure (Notifications.js,
// NotificationOpen.js, NoticeDuration.js); this object reads the live model and runs the timers. What belongs to the
// popup (closing it, bumping the activity) is reported through signals, never done from here.
Item {
    id: service

    // Opens the app behind a notification (AppLauncher).
    required property var launcher
    property bool activityEnabled: true
    property int bodyCharacters: 240
    // The user's popup duration setting, in ms (D-33 shortens it per notification).
    property int popupDurationMs: 4000
    property string fallbackAppName: "Notification"
    // The popup is hovered or focused: the presentation timer holds.
    property bool holdLifetime: false
    // The activity popup is still up, so letting the presentation end should close it too.
    property bool popupTimerRunning: false

    // A newer notification is now the one being presented.
    signal noticeShown()
    // A job row appeared (jobs share the model).
    signal jobArrived()
    // The presented notification was dropped; wasShowing says whether there was one, closePopup whether the popup
    // should close with it.
    signal dismissed(bool closePopup, bool wasShowing)
    // A click opened the notification's target; any popup should close.
    signal opened()

    readonly property alias model: notifications
    // Bumped on any model change so bindings that read rows re-evaluate.
    property int revision: 0
    // Identity of the notification the island is presenting as a temporary activity. History alone must not keep it alive.
    property var activeNoticeId: null
    property bool clearing: false
    readonly property bool activityActive: activityEnabled && noticeRowFor(activeNoticeId) >= 0
    readonly property bool hasNotifications: count() > 0
    readonly property int unreadCount: notifications.unreadNotificationsCount
    // How long the presented notification stays up (D-33): the user's setting, shortened by the app's own timeout
    // (2 s floor) and at least 6 s when critical. One value drives both the popup timer and the lifetime timer.
    readonly property int durationMs: {
        const row = noticeRowFor(activeNoticeId);
        return NoticeDuration.effectiveDurationMs(
            rowValue(row, NotificationManager.Notifications.TimeoutRole, -1), popupDurationMs,
            rowValue(row, NotificationManager.Notifications.UrgencyRole, NotificationManager.Notifications.NormalUrgency));
    }

    function rowValue(row, role, fallbackValue) {
        if (revision < 0) // never true: reading it re-evaluates callers whenever the model changes
            return fallbackValue;

        if (row < 0 || notifications.count <= row)
            return fallbackValue;

        const value = notifications.data(notifications.index(row, 0), role);
        return value === undefined || value === null ? fallbackValue : value;
    }

    // The model read into plain arrays, for the pure row decisions in Notifications.js.
    function types() {
        const out = [];
        for (let i = 0; i < notifications.count; ++i)
            out.push(rowValue(i, NotificationManager.Notifications.TypeRole, NotificationManager.Notifications.NoType));

        return out;
    }

    function items() {
        const out = [];
        for (let i = 0; i < notifications.count; ++i) {
            out.push({
                "type": rowValue(i, NotificationManager.Notifications.TypeRole, NotificationManager.Notifications.NoType),
                "id": rowValue(i, NotificationManager.Notifications.IdRole, ""),
                "closable": rowValue(i, NotificationManager.Notifications.ClosableRole, true) ? true : false
            });
        }
        return out;
    }

    function firstRowOfType(type) {
        return Notif.firstRowOfType(types(), type);
    }

    // Row indexes of the notifications (not jobs), newest first; limit 0 means all.
    function rows(limit) {
        return Notif.rowsOfType(types(), NotificationManager.Notifications.NotificationType, limit);
    }

    function count() {
        return rows(0).length;
    }

    function appName(row) {
        return Notif.appName(rowValue(row, NotificationManager.Notifications.ApplicationNameRole, ""), rowValue(row, NotificationManager.Notifications.DesktopEntryRole, ""), fallbackAppName);
    }

    function title(row) {
        return Notif.title(rowValue(row, NotificationManager.Notifications.SummaryRole, ""), appName(row));
    }

    function body(row) {
        return TextUtils.truncate(TextUtils.plainText(rowValue(row, NotificationManager.Notifications.BodyRole, "")), bodyCharacters);
    }

    function appIcon(row) {
        return Notif.appIcon(rowValue(row, NotificationManager.Notifications.ApplicationIconNameRole, ""), rowValue(row, NotificationManager.Notifications.DesktopEntryRole, ""));
    }

    function mainIcon(row) {
        return Notif.mainIcon(rowValue(row, NotificationManager.Notifications.IconNameRole, ""), appIcon(row));
    }

    function mainImage(row) {
        return Notif.mainImage(rowValue(row, NotificationManager.Notifications.ImageRole, null), rowValue(row, NotificationManager.Notifications.UrlsRole, []));
    }

    function hasMainImage(row) {
        return Utils.hasVisualValue(mainImage(row));
    }

    function urgency(row) {
        return Notif.urgency(rowValue(row, NotificationManager.Notifications.UrgencyRole, 1));
    }

    function accent(row) {
        return Notif.accent(urgency(row));
    }

    // Colour of the small urgency dot in the expanded notification. Visual only: priority uses urgency().
    function urgencyColor(row) {
        return Notif.urgencyColor(rowValue(row, NotificationManager.Notifications.UrgencyRole, NotificationManager.Notifications.NormalUrgency), {
            "low": NotificationManager.Notifications.LowUrgency,
            "critical": NotificationManager.Notifications.CriticalUrgency
        });
    }

    // Creation time (ms since epoch) of a notification row, 0 when unknown. Display only.
    function createdMs(row) {
        return Notif.createdMs(rowValue(row, NotificationManager.Notifications.CreatedRole, null));
    }

    function overflowCount(limit) {
        return Notif.overflow(count(), limit);
    }

    function noticeRowFor(id) {
        return Notif.rowOfId(items(), id, NotificationManager.Notifications.NotificationType);
    }

    // The row being presented, else the newest notification, else -1.
    function latestRow() {
        return Notif.latestRow(noticeRowFor(activeNoticeId), rows(1));
    }

    function isFresh(row) {
        return Notif.isFresh(rowValue(row, NotificationManager.Notifications.CreatedRole, null), Date.now(), clearing);
    }

    // A newer notification arrived: present it and (re)start its lifetime.
    function noticeArrived(row) {
        if (row === undefined || row < 0)
            return ;
        activeNoticeId = rowValue(row, NotificationManager.Notifications.IdRole, null);
        if (activeNoticeId === null)
            return ;
        lifetimeTimer.restart();
        noticeShown();
    }

    // Drop the notification activity without touching media, jobs or history.
    function dismissNotice(closePopup) {
        lifetimeTimer.stop();
        const wasShowing = activeNoticeId !== null;
        activeNoticeId = null;
        dismissed(closePopup, wasShowing);
    }

    // Called after the model changes: if the presented notification was removed (single dismissal, Clear All, expiry),
    // dismiss its activity.
    function syncNotice() {
        if (activeNoticeId !== null && noticeRowFor(activeNoticeId) < 0)
            dismissNotice(true);
    }

    // What a click on this notification would do (D-31). "none" rows are not clickable.
    function openTarget(row) {
        const entry = TextUtils.cleanText(rowValue(row, NotificationManager.Notifications.DesktopEntryRole, ""));
        const info = entry.length > 0 ? launcher.desktopEntryInfo[entry] : undefined;
        if (entry.length > 0 && info === undefined)
            launcher.lookupDesktopEntry(entry);

        return NotificationOpen.resolve(Notif.openInput(entry, rowValue(row, NotificationManager.Notifications.ExpiredRole, false), rowValue(row, NotificationManager.Notifications.HasDefaultActionRole, false), rowValue(row, NotificationManager.Notifications.UrlsRole, []), info));
    }

    function clickable(row) {
        return openTarget(row).kind !== "none";
    }

    // Click handlers pass a row index; resolve it to the notification id right away.
    function open(row) {
        return openById(rowValue(row, NotificationManager.Notifications.IdRole, null));
    }

    // The row is looked up by id at click time, so a model change since render can't retarget the click.
    function openById(id) {
        const row = noticeRowFor(id);
        if (row < 0)
            return false;

        const target = openTarget(row);
        if (target.kind === "none")
            return false;

        const idx = notifications.index(row, 0);
        const plan = Notif.openPlan(target.kind, rowValue(row, NotificationManager.Notifications.ClosableRole, true) ? true : false);
        if (plan.invokeAction)
            notifications.invokeDefaultAction(idx, NotificationManager.Notifications.Close);
        if (plan.openUrl)
            Qt.openUrlExternally(target.target);
        if (plan.launchApp)
            launcher.launch(target.target);
        if (plan.close)
            notifications.close(idx);
        // The model change also dismisses the activity; this covers the Control Center.
        opened();
        return true;
    }

    // Close every closable notification currently in the model window. Returns how many were closed.
    function closeRows() {
        const rowsToClose = Notif.closableRows(items(), NotificationManager.Notifications.NotificationType);
        for (let i = 0; i < rowsToClose.length; ++i)
            notifications.close(notifications.index(rowsToClose[i], 0));

        if (rowsToClose.length === 0)
            clearing = false;
        return rowsToClose.length;
    }

    // Clear All: the model exposes a limited window of history, so keep closing until nothing closable is left, then
    // drop the island activity.
    function clearAll() {
        clearing = true;
        guardTimer.restart();
        closeRows();
        dismissNotice(true);
    }

    NotificationManager.Notifications {
        id: notifications

        limit: 8
        showNotifications: true
        showJobs: true
        // Keep Plasma popup history visible in Dynamic Island after the system popup times out or is hidden. Closing it
        // here still calls close().
        showExpired: true
        showDismissed: true
        sortMode: NotificationManager.Notifications.SortByDate
        sortOrder: Qt.DescendingOrder
        groupMode: NotificationManager.Notifications.GroupDisabled
    }

    Connections {
        function onRowsInserted(parent, first, last) {
            service.revision++;
            let freshNoticeRow = -1;
            let hasInsertedJob = false;
            for (let row = first; row <= last; ++row) {
                const type = service.rowValue(row, NotificationManager.Notifications.TypeRole, NotificationManager.Notifications.NoType);
                if (type === NotificationManager.Notifications.JobType)
                    hasInsertedJob = true;
                else if (type === NotificationManager.Notifications.NotificationType && freshNoticeRow < 0 && service.isFresh(row))
                    freshNoticeRow = row;
            }
            if (hasInsertedJob)
                service.jobArrived();
            else if (freshNoticeRow >= 0)
                service.noticeArrived(freshNoticeRow);
        }

        function onRowsRemoved(parent, first, last) {
            service.revision++;
            service.syncNotice();
            if (service.clearing)
                Qt.callLater(service.closeRows);
        }

        function onDataChanged(topLeft, bottomRight, roles) {
            service.revision++;
            service.syncNotice();
        }

        function onModelReset() {
            service.revision++;
            service.syncNotice();
        }

        // Unread-count growth is deliberately not an arrival: Plasma marks a notification unread when its own popup
        // expires, which would re-show an already presented notification. Arrivals come from onRowsInserted.
        target: notifications
    }

    // Safety net so a Clear All can never leave arrivals suppressed.
    Timer {
        id: guardTimer

        interval: 700
        repeat: false
        onTriggered: service.clearing = false
    }

    PausableTimer {
        id: lifetimeTimer

        duration: service.durationMs
        hold: service.holdLifetime
        onTriggered: service.dismissNotice(service.popupTimerRunning)
    }
}
