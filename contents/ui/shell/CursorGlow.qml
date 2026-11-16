pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami
import "../controlcenter/Tokens.js" as T
import "../logic/GlowMotion.js" as Glow

// Cursor glow on an expanded surface (D-41). An overlay above the content that takes no input: the surface feeds it
// the pointer (a passive HoverHandler on the surface). Frames are requested only while the pointer moves, the position
// settles or the fade runs (GlowMotion.needsFrames); at rest nothing changes, so nothing renders.
// `mask` is the surface silhouette item (a layer-enabled shape): its alpha clips the glow to the shape.
Item {
    id: glow

    required property Item mask
    property bool hovering: false
    property point pointer: Qt.point(0, 0)
    // Plasma's animation speed factor 0 gives Kirigami durations of 1: then no follow and no fade.
    property bool animationsOff: Glow.animationsOff(Kirigami.Units.longDuration)

    property real glowX: 0
    property real glowY: 0
    property real fade: 0
    readonly property var cfg: ({ "tauMs": T.glowTauMs, "fadeMs": T.glowFadeMs, "settlePx": T.glowSettlePx })
    readonly property var input: ({ "tx": pointer.x, "ty": pointer.y, "hover": hovering, "off": animationsOff })
    readonly property bool needsFrames: Glow.needsFrames({ "x": glowX, "y": glowY, "s": fade }, input, cfg)
    readonly property alias animating: frames.running
    property var bloomState: Glow.bloomIdle()
    readonly property bool blooming: Glow.bloomActive(bloomState)

    // D-43: a bloom plays on the reply shelf's opening; none when animations are off.
    function bloom() {
        if (animationsOff)
            return ;

        glowX = pointer.x;
        glowY = pointer.y;
        bloomState = Glow.bloomStart(T.glowIntensity);
    }

    visible: fade > 0 || blooming

    FrameAnimation {
        id: frames

        running: glow.needsFrames || glow.blooming
        onTriggered: {
            const next = Glow.advance({ "x": glow.glowX, "y": glow.glowY, "s": glow.fade }, glow.input, frames.frameTime * 1000, glow.cfg);
            glow.glowX = next.x;
            glow.glowY = next.y;
            glow.fade = next.s;
            if (glow.blooming)
                glow.bloomState = Glow.bloomAdvance(glow.bloomState, frames.frameTime * 1000);
        }
    }

    ShaderEffect {
        anchors.fill: parent

        property var mask: glow.mask
        property point center: Qt.point(glow.glowX, glow.glowY)
        property size size: Qt.size(width, height)
        property real radius: T.glowRadius * (glow.blooming ? glow.bloomState.r : 1)
        property real intensity: glow.blooming ? glow.bloomState.i : T.glowIntensity
        property real falloff: T.glowFalloff
        property real strength: glow.blooming ? 1 : Glow.eased(glow.fade)

        fragmentShader: "../shaders/glow.frag.qsb"
    }
}
