pragma ComponentBehavior: Bound

// Claude Code 1x1 (D-60): the left block alone. A click raises the waiting session, else the latest live one, else nothing.
ClaudeBase {
    id: view

    readonly property var target: view.face.target
    clickAction: view.target !== null && view.agents && view.agents.raisable[view.target] === true ? ({ "type": "agent", "value": view.target }) : null

    LeftBlock {
        anchors.fill: parent
        base: view
    }
}
