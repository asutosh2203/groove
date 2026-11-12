import QtQuick
import QtTest
import "../contents/ui/services"

// Runs against the machine's real notification model, so it asserts only what holds whatever is in it. The accessors
// are pure and tested in tests/notifications.test.cjs. It never opens or closes a real notification.
TestCase {
    id: tc

    name: "NotificationService"
    when: windowShown

    property var shown: 0
    property var dismissedWith: []

    QtObject {
        id: fakeLauncher

        property var desktopEntryInfo: ({})
        function lookupDesktopEntry(entry) {}
        function launch(id) {}
    }

    NotificationService {
        id: service

        launcher: fakeLauncher
        onNoticeShown: tc.shown++
        onDismissed: (closePopup, wasShowing) => tc.dismissedWith.push([closePopup, wasShowing])
    }

    function init() {
        shown = 0;
        dismissedWith = [];
        service.activeNoticeId = null;
        service.clearing = false;
    }

    function test_rows_outside_the_model_fall_back() {
        compare(service.rowValue(-1, 0, "fb"), "fb");
        compare(service.rowValue(9999, 0, "fb"), "fb");
        compare(service.noticeRowFor(null), -1);
        compare(service.noticeRowFor(undefined), -1);
        compare(service.noticeRowFor("no-such-id"), -1);
        verify(!service.openById("no-such-id"));
    }

    function test_count_and_rows_agree() {
        compare(service.rows(0).length, service.count());
        compare(service.hasNotifications, service.count() > 0);
        verify(service.rows(1).length <= 1);
        compare(service.overflowCount(service.count()), 0);
        compare(service.overflowCount(0), service.count());
        compare(service.latestRow(), service.count() > 0 ? service.rows(1)[0] : -1);
    }

    function test_arrival_of_a_bad_row_is_ignored() {
        service.noticeArrived(-1);
        service.noticeArrived(undefined);
        compare(service.activeNoticeId, null);
        compare(shown, 0);
    }

    function test_dismissing_reports_whether_anything_was_showing() {
        service.dismissNotice(true);
        compare(dismissedWith.length, 1);
        compare(dismissedWith[0][0], true);
        compare(dismissedWith[0][1], false); // nothing was presented
        service.activeNoticeId = "x";
        service.dismissNotice(false);
        compare(dismissedWith[1][1], true);
        compare(service.activeNoticeId, null);
    }

    function test_a_removed_presented_notification_is_dropped() {
        service.activeNoticeId = "id-that-is-not-in-the-model";
        service.syncNotice();
        compare(service.activeNoticeId, null);
        compare(dismissedWith.length, 1);
        compare(dismissedWith[0][0], true);
    }

    function test_no_arrivals_while_clearing() {
        service.clearing = true;
        verify(!service.isFresh(0));
    }

    function test_the_duration_follows_the_setting_without_a_presented_notice() {
        service.popupDurationMs = 5000;
        compare(service.durationMs, 5000);
        service.popupDurationMs = 3000;
        compare(service.durationMs, 3000);
    }

    function test_activity_needs_the_setting_and_a_presented_row() {
        service.activityEnabled = true;
        verify(!service.activityActive);
        service.activityEnabled = false;
        verify(!service.activityActive);
        service.activityEnabled = true;
    }

    function test_clear_all_flags_clearing_and_a_guard_resets_it() {
        // Only the flag, the dismiss signal and the guard timer; with an empty model nothing is closed.
        if (service.count() > 0)
            skip("the machine has notifications; Clear All would close them");
        service.clearAll();
        compare(dismissedWith.length, 1);
        tryCompare(service, "clearing", false, 2000);
    }
}
