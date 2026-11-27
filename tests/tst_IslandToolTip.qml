import QtQuick
import QtTest
import "../contents/ui" as UI

Item {
    id: testRoot
    width: 240
    height: 140

    UI.IslandButton {
        id: topEdge
        x: 106
        y: 2
        width: 28
        height: 28
        iconName: "media-playback-pause"
        tooltipText: "Show the welcome tour again"
    }

    UI.IslandButton {
        id: leftEdge
        x: 0
        y: 80
        width: 28
        height: 28
        iconName: "media-playback-pause"
        tooltipText: "Show the welcome tour again"
    }

    UI.IslandButton {
        id: middle
        x: 106
        y: 80
        width: 28
        height: 28
        iconName: "media-playback-pause"
        tooltipText: "Pause"
    }

    TestCase {
        name: "IslandToolTip"
        when: windowShown

        function tipOf(button) {
            for (let i = 0; i < button.data.length; i++) {
                if (button.data[i].spot !== undefined)
                    return button.data[i];
            }
            return null;
        }

        function shown(button) {
            mouseMove(testRoot, 1, 138);
            mouseMove(button, 10, 10);
            const tip = tipOf(button);
            verify(tip !== null);
            tryVerify(() => tip.opened, 3000);
            return button.mapFromItem(null, 0, 0) && { "tip": tip, "rect": button.mapToItem(null, tip.x, tip.y) };
        }

        function test_at_the_top_edge_the_tooltip_flips_below_and_stays_inside() {
            const r = shown(topEdge);
            verify(r.rect.y >= 0);
            verify(r.rect.y > topEdge.y);
            verify(r.rect.y + r.tip.height <= testRoot.height);
        }

        function test_near_the_left_edge_the_tooltip_slides_in() {
            const r = shown(leftEdge);
            verify(r.rect.x >= 0);
            verify(r.rect.x + r.tip.width <= testRoot.width);
        }

        function test_with_room_above_it_stays_above() {
            const r = shown(middle);
            verify(r.rect.y + r.tip.height <= middle.y);
            verify(r.rect.y >= 0);
        }
    }
}
