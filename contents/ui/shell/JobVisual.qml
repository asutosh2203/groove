pragma ComponentBehavior: Bound

import QtQuick

MaskedArtwork {
    id: self

    required property var app

    mode: "job"
    progress: self.app.activities.progressValueFor("job") / Math.max(1, self.app.activities.progressToFor("job"))
    playing: !self.app.jobs.isSuspended(self.app.jobs.activeRow())
}
