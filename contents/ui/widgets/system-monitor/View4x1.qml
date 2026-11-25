pragma ComponentBehavior: Bound

// System Monitor 4x1 (D-65): the cells for its span.
SysmonBase {
    id: view

    SysmonCells {
        anchors.fill: parent
        base: view
    }
}
