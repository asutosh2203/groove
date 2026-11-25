pragma ComponentBehavior: Bound

// Pomodoro 1x1 (D-64): the left block alone.
PomodoroBase {
    id: view

    LeftBlock {
        anchors.fill: parent
        base: view
    }
}
