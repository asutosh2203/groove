import QtQuick
import QtTest
import "../contents/ui/services"

// Runs against the machine's real notification model, so it asserts only what holds whatever is in it. The job rules
// are pure and tested in tests/jobs.test.cjs. It never suspends or cancels a real job: only rows that cannot exist.
TestCase {
    id: tc

    name: "JobService"
    when: windowShown

    QtObject {
        id: fakeLauncher

        property var desktopEntryInfo: ({})
        function lookupDesktopEntry(entry) {}
        function launch(id) {}
    }

    NotificationService {
        id: notifications

        launcher: fakeLauncher
    }

    JobService {
        id: jobs

        notifications: notifications
    }

    function test_has_jobs_follows_the_model() {
        compare(jobs.hasJobs, notifications.model.activeJobsCount > 0);
        compare(jobs.activeRow() >= 0, jobs.hasJobs || jobs.activeRow() >= 0);
    }

    function test_a_row_that_does_not_exist_reads_as_empty() {
        compare(jobs.details(-1), null);
        compare(jobs.titleText(-1), "");
        compare(jobs.text(-1), "");
        compare(jobs.icon(-1), "folder-download");
        compare(jobs.percentage(-1), -1);
        verify(!jobs.suspendable(-1));
        verify(!jobs.killable(-1));
        verify(!jobs.isSuspended(-1));
        compare(jobs.detailsParts(-1).kind, "none");
    }

    function test_actions_on_a_missing_row_do_nothing() {
        jobs.toggleSuspended(-1);
        jobs.toggleSuspended(99999);
        jobs.cancel(-1);
        jobs.cancel(99999);
        verify(true); // reaching here means nothing threw and nothing was sent to a real job
    }
}
