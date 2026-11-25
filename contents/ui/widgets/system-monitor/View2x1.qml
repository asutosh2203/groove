pragma ComponentBehavior: Bound

// System Monitor 2x1 (D-65): the cells for its span.
SysmonBase {
    id: view

    SysmonCells {
        anchors.fill: parent
        base: view
    }
}
