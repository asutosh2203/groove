import QtQuick
import QtQuick.Window
import QtTest
import "../contents/ui/shell"

// The glow must ask for frames only while it is moving or fading (D-41). The software backend used here cannot draw
// shaders, so this tests the controller and the frame count, not pixels.
TestCase {
    id: tc

    name: "CursorGlow"
    when: windowShown
    width: 300
    height: 200

    property int frames: 0

    Connections {
        target: tc.Window.window
        function onFrameSwapped() { tc.frames += 1; }
    }

    Item { id: maskItem; width: 300; height: 200 }

    CursorGlow {
        id: glow

        width: 300
        height: 200
        mask: maskItem
        animationsOff: false
    }

    function init() {
        glow.hovering = false;
        glow.pointer = Qt.point(0, 0);
        glow.animationsOff = false;
        tryVerify(function() { return glow.fade === 0 && !glow.animating; }, 2000);
    }

    function test_nothing_is_drawn_or_animated_at_rest() {
        compare(glow.visible, false);
        compare(glow.animating, false);
        wait(100);
        const before = frames;
        wait(300);
        compare(frames, before);
    }

    function test_it_animates_while_entering_and_stops_when_settled() {
        glow.pointer = Qt.point(120, 80);
        glow.hovering = true;
        tryVerify(function() { return glow.animating; }, 1000);
        tryVerify(function() { return glow.fade === 1 && !glow.animating; }, 2000);
        compare(glow.glowX, 120);
        compare(glow.glowY, 80);
    }

    function test_a_resting_pointer_inside_costs_no_frames() {
        glow.pointer = Qt.point(60, 40);
        glow.hovering = true;
        tryVerify(function() { return glow.fade === 1 && !glow.animating; }, 2000);
        wait(100);
        const before = frames;
        wait(400);
        compare(frames, before);
    }

    function test_a_moving_pointer_follows_then_settles() {
        glow.pointer = Qt.point(20, 20);
        glow.hovering = true;
        tryVerify(function() { return glow.fade === 1 && !glow.animating; }, 2000);
        glow.pointer = Qt.point(250, 150);
        tryVerify(function() { return glow.animating; }, 1000);
        tryVerify(function() { return !glow.animating; }, 2000);
        fuzzyCompare(glow.glowX, 250, 0.3); // it settles within the 0.3 px threshold
        fuzzyCompare(glow.glowY, 150, 0.3);
    }

    function test_leaving_fades_out_and_stops() {
        glow.pointer = Qt.point(20, 20);
        glow.hovering = true;
        tryVerify(function() { return glow.fade === 1 && !glow.animating; }, 2000);
        glow.hovering = false;
        tryVerify(function() { return glow.fade === 0 && !glow.animating; }, 2000);
        compare(glow.visible, false);
    }

    function test_with_animations_off_it_jumps_without_flight_or_fade() {
        glow.animationsOff = true;
        glow.pointer = Qt.point(200, 100);
        glow.hovering = true;
        tryVerify(function() { return glow.fade === 1 && !glow.animating; }, 1000);
        compare(glow.glowX, 200);
        glow.hovering = false;
        tryVerify(function() { return glow.fade === 0 && !glow.animating; }, 1000);
    }
}
