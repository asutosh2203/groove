pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../controlcenter" as CC
import "../controlcenter/Tokens.js" as T
import "../logic/CapsuleScrub.js" as CapsuleScrub
import "../logic/DeckPlan.js" as DeckPlan

// The page-control capsule (D-51): a small pill floating just below the island, centred on it. One item per page in deck
// order: a glyph for Live and the Control Center, a dot per preset. A satellite of the deck, not a second island: it has the
// island's surface but no glow, and it is positioned and shown by PopupContent. A press that travels past a few pixels
// scrubs across the items (D-62); the one MouseArea owns click and scrub so a press stays grabbed outside the capsule and
// its release is never an outside click.
MouseArea {
    id: capsule

    required property var app
    required property bool control
    required property bool reduceMotion

    readonly property var items: capsule.app.deck.indicator

    implicitWidth: capsule.items ? capsule.items.length * T.deckCapsuleItem + 2 * T.deckCapsulePad : 0
    implicitHeight: T.deckCapsuleHeight
    width: implicitWidth
    height: implicitHeight
    // Clicks on the body do nothing, and are not outside clicks (the window's own handler would close the deck).
    acceptedButtons: Qt.LeftButton
    preventStealing: true
    transformOrigin: Item.Center
    scale: 1 + T.scrubSwell * swell

    property var scrub: CapsuleScrub.idle(0)
    property var centres: []
    property bool pressed: false
    property real pressX: 0
    readonly property bool scrubbing: capsule.scrub.scrubbing
    readonly property int scrubIndex: capsule.scrub.hover
    // Reduced motion: no swell, and pages switch on release only.
    property real scrubDwell: T.scrubDwell
    readonly property real dwell: capsule.reduceMotion ? Infinity : capsule.scrubDwell
    property real swell: capsule.scrubbing && !capsule.reduceMotion ? 1 : 0

    Behavior on swell {
        NumberAnimation {
            duration: T.scrubSwellMs
            easing.type: T.easingStandard
        }
    }

    function currentIndex() {
        return DeckPlan.indexOf(capsule.app.deck.cycle, capsule.app.deck.current);
    }

    function measure() {
        const rects = [];
        for (let i = 0; i < itemRepeater.count; ++i) {
            const item = itemRepeater.itemAt(i);
            rects.push({ "x": row.x + item.x, "w": item.width });
        }
        capsule.centres = CapsuleScrub.centres(rects);
    }

    function apply(r) {
        const was = capsule.scrub.scrubbing;
        capsule.scrub = r.state;
        if (r.timer > 0) {
            dwellTimer.interval = r.timer;
            dwellTimer.restart();
        } else if (r.timer === 0) {
            dwellTimer.stop();
        }
        capsule.app.deck.scrubbing = was || r.state.scrubbing;
        if (r.commit >= 0 && r.commit < capsule.items.length)
            capsule.app.deck.goTo(capsule.items[r.commit].id);
        capsule.app.deck.scrubbing = r.state.scrubbing;
    }

    function end(result) {
        capsule.pressed = false;
        capsule.apply(result);
    }

    onPressed: mouse => {
        capsule.measure();
        capsule.pressX = mouse.x;
        capsule.pressed = true;
        capsule.scrub = CapsuleScrub.idle(capsule.currentIndex());
    }
    onPositionChanged: mouse => {
        if (!capsule.pressed || (!capsule.scrubbing && Math.abs(mouse.x - capsule.pressX) < T.scrubThreshold))
            return ;
        const index = CapsuleScrub.pick(capsule.centres, mouse.x);
        if (!capsule.scrubbing || index !== capsule.scrubIndex)
            capsule.apply(CapsuleScrub.move(capsule.scrub, index, capsule.dwell));
    }
    onReleased: mouse => {
        if (!capsule.pressed)
            return ;
        if (capsule.scrubbing) {
            capsule.end(CapsuleScrub.release(capsule.scrub));
            return ;
        }
        capsule.pressed = false;
        const index = CapsuleScrub.hit(capsule.centres, T.deckCapsuleItem / 2, mouse.x);
        if (index >= 0)
            capsule.app.deck.goTo(capsule.items[index].id);
    }
    // A lost grab, or the capsule hiding (a pop-in, edit mode): nothing pending is committed.
    onCanceled: capsule.end(CapsuleScrub.cancel(capsule.scrub))
    onEnabledChanged: {
        if (!capsule.enabled && capsule.pressed)
            capsule.end(CapsuleScrub.cancel(capsule.scrub));
    }
    // The cycle changed mid-scrub: follow the deck and clamp the pointer's item (DeckPlan.reconcile has moved the page).
    onItemsChanged: {
        if (capsule.pressed)
            Qt.callLater(capsule.refresh);
    }

    function refresh() {
        if (!capsule.pressed || !capsule.items)
            return ;
        capsule.measure();
        capsule.scrub = CapsuleScrub.reconcile(capsule.scrub, capsule.items.length, capsule.currentIndex());
    }

    Timer {
        id: dwellTimer

        repeat: false
        onTriggered: capsule.apply(CapsuleScrub.rest(capsule.scrub))
    }

    RoundShape {
        anchors.fill: parent
        radius: height / 2
        fillTop: capsule.control ? T.surfaceControlTop : "#121216"
        fillBottom: capsule.control ? T.surfaceControlBottom : "#060608"
        strokeColor: capsule.control ? "#25252b" : "#202027"
        rimOpacity: capsule.app.rimLight
    }

    Row {
        id: row

        anchors.centerIn: parent

        // One delegate per page, kept as the pages' details change, so the colour, the dot and the glyph can animate.
        Repeater {
            id: itemRepeater

            model: capsule.items ? capsule.items.length : 0

            delegate: Item {
                id: entry

                required property int index

                readonly property var info: capsule.items && entry.index < capsule.items.length ? capsule.items[entry.index] : null
                // While scrubbing the highlight follows the pointer, which can run ahead of the page (scrubDwell > 0).
                readonly property bool current: capsule.scrubbing ? entry.index === capsule.scrubIndex : entry.info !== null && capsule.app.deck.current === entry.info.id
                property color tone: current ? T.textPrimary : hover.hovered && !capsule.scrubbing ? T.textSecondary : T.textTertiary

                // The visible detent: the highlight snaps in with a small overshoot.
                onCurrentChanged: {
                    if (entry.current && capsule.scrubbing && !capsule.reduceMotion)
                        detent.restart();
                }

                width: T.deckCapsuleItem
                height: T.deckCapsuleItem
                Accessible.role: Accessible.Button
                Accessible.name: entry.info === null ? "" : entry.info.id === "live" ? capsule.app.strings.deckLive : entry.info.id === "control" ? capsule.app.strings.deckControlCenter : capsule.app.strings.deckPage(entry.info.id)

                Behavior on tone {
                    enabled: !capsule.reduceMotion

                    ColorAnimation {
                        duration: T.motionHover
                        easing.type: T.easingStandard
                    }
                }

                // A glyph that changes with the content (the Live item) cross-fades from the old one to the new.
                Item {
                    id: glyphPair

                    property bool showA: true
                    property var namesA: []
                    property var namesB: []

                    anchors.centerIn: parent
                    width: T.deckGlyph
                    height: T.deckGlyph
                    visible: entry.info !== null && entry.info.kind === "glyph"

                    function follow(next) {
                        if (next === null)
                            return ;
                        const shown = glyphPair.showA ? glyphPair.namesA : glyphPair.namesB;
                        if (JSON.stringify(next) === JSON.stringify(shown))
                            return ;
                        if (glyphPair.showA) {
                            glyphPair.namesB = next;
                            glyphPair.showA = false;
                        } else {
                            glyphPair.namesA = next;
                            glyphPair.showA = true;
                        }
                    }

                    Component.onCompleted: glyphPair.namesA = entry.info === null ? [] : entry.info.glyphs

                    Connections {
                        function onInfoChanged() {
                            glyphPair.follow(entry.info === null ? null : entry.info.glyphs);
                        }

                        target: entry
                    }

                    CC.ThemeGlyph {
                        anchors.fill: parent
                        names: glyphPair.namesA
                        color: entry.tone
                        opacity: glyphPair.showA ? 1 : 0

                        Behavior on opacity {
                            enabled: !capsule.reduceMotion

                            NumberAnimation {
                                duration: T.motionFade
                                easing.type: T.easingStandard
                            }
                        }
                    }

                    CC.ThemeGlyph {
                        anchors.fill: parent
                        names: glyphPair.namesB
                        color: entry.tone
                        opacity: glyphPair.showA ? 0 : 1

                        Behavior on opacity {
                            enabled: !capsule.reduceMotion

                            NumberAnimation {
                                duration: T.motionFade
                                easing.type: T.easingStandard
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    visible: entry.info !== null && entry.info.kind === "dot"
                    width: entry.current ? T.deckDotActiveWidth : T.deckDotSize
                    height: T.deckDotSize
                    radius: height / 2
                    color: entry.tone

                    Behavior on width {
                        enabled: !capsule.reduceMotion

                        NumberAnimation {
                            duration: T.motionFast
                            easing.type: T.easingStandard
                        }
                    }
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                NumberAnimation {
                    id: detent

                    target: entry
                    property: "scale"
                    from: T.scrubDetentFrom
                    to: 1
                    duration: T.scrubDetentMs
                    easing.type: T.easingOvershoot
                    easing.overshoot: T.scrubOvershoot
                }
            }
        }
    }
}
