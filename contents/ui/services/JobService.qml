pragma ComponentBehavior: Bound

import QtQuick
import org.kde.notificationmanager as NotificationManager
import "../logic/Jobs.js" as Jobs

// The jobs backend (file copies, downloads): which job row is showing and how it reads, plus suspend and cancel. Jobs
// share Plasma's notification model, which NotificationService owns, so it is injected. Translated text stays with
// the caller (see Jobs.js); the decisions are pure.
Item {
    id: service

    // The NotificationService: its model and its rowValue / firstRowOfType.
    required property var notifications

    // The number of running jobs went up.
    signal jobStarted()

    readonly property int activeCount: notifications.model.activeJobsCount
    readonly property bool hasJobs: activeCount > 0
    property int lastActiveJobsCount: 0

    function activeRow() {
        return notifications.firstRowOfType(NotificationManager.Notifications.JobType);
    }

    // The running and paused jobs for the Live page (LiveLayout.js). Created is a plain date role (D-50 only bans
    // JobDetailsRole through data()); the details come through the role delegate.
    function runningRows() {
        // Never true: reading it makes a binding that calls this re-evaluate when a job starts or ends, even while the
        // model has no rows yet (an empty model's row count does not notify).
        if (activeCount < 0)
            return [];
        const out = [];
        const types = notifications.types();
        for (let i = 0; i < types.length; ++i) {
            if (types[i] !== NotificationManager.Notifications.JobType)
                continue;
            const state = jobState(i);
            if (state !== NotificationManager.Notifications.JobStateRunning && state !== NotificationManager.Notifications.JobStateSuspended)
                continue;
            const d = details(i);
            const bytes = Jobs.bytes(d);
            out.push({
                "id": String(notifications.rowValue(i, NotificationManager.Notifications.IdRole, i)),
                "row": i,
                "created": notifications.createdMs(i),
                "percent": percentage(i),
                "processed": bytes.processed,
                "total": bytes.total,
                "remaining": Jobs.meta(d, false).remaining ?? -1,
                "kind": Jobs.kind(d, icon(i))
            });
        }
        return out;
    }

    function details(row) {
        return notifications.rowValue(row, NotificationManager.Notifications.JobDetailsRole, null);
    }

    // May be empty: the caller supplies the translated fallback.
    function titleText(row) {
        return Jobs.titleText(details(row), notifications.rowValue(row, NotificationManager.Notifications.SummaryRole, ""));
    }

    function text(row) {
        return Jobs.text(details(row), notifications.rowValue(row, NotificationManager.Notifications.BodyRole, ""), notifications.rowValue(row, NotificationManager.Notifications.ApplicationNameRole, ""));
    }

    function icon(row) {
        return Jobs.icon(details(row), notifications.rowValue(row, NotificationManager.Notifications.ApplicationIconNameRole, ""), notifications.rowValue(row, NotificationManager.Notifications.DesktopEntryRole, ""));
    }

    function glyphNames(row) {
        return Jobs.glyphNames(details(row), icon(row));
    }

    function jobState(row) {
        return Jobs.state(details(row), notifications.rowValue(row, NotificationManager.Notifications.JobStateRole, NotificationManager.Notifications.JobStateRunning));
    }

    function percentage(row) {
        return Jobs.percentage(details(row), notifications.rowValue(row, NotificationManager.Notifications.PercentageRole, -1));
    }

    function suspendable(row) {
        return Jobs.suspendable(details(row), notifications.rowValue(row, NotificationManager.Notifications.SuspendableRole, false));
    }

    function killable(row) {
        return Jobs.killable(details(row), notifications.rowValue(row, NotificationManager.Notifications.KillableRole, false));
    }

    function isSuspended(row) {
        return jobState(row) === NotificationManager.Notifications.JobStateSuspended;
    }

    function meta(row) {
        return Jobs.meta(details(row), isSuspended(row));
    }

    function fileCount(row) {
        return Jobs.fileCount(details(row));
    }

    function destination(row) {
        return Jobs.destination(details(row));
    }

    function toggleSuspended(row) {
        if (row < 0 || row >= notifications.model.count || !suspendable(row))
            return ;
        const idx = notifications.model.index(row, 0);
        if (isSuspended(row))
            notifications.model.resumeJob(idx);
        else
            notifications.model.suspendJob(idx);
    }

    function cancel(row) {
        if (row < 0 || row >= notifications.model.count || !killable(row))
            return ;
        notifications.model.killJob(notifications.model.index(row, 0));
    }

    Component.onCompleted: lastActiveJobsCount = notifications.model.activeJobsCount

    Connections {
        function onActiveJobsCountChanged() {
            const count = service.notifications.model.activeJobsCount;
            if (count > service.lastActiveJobsCount)
                service.jobStarted();
            service.lastActiveJobsCount = count;
        }

        target: service.notifications.model
    }
}
