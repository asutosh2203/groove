import QtQuick
import QtTest
import "../contents/ui"
import "../contents/ui/controlcenter/Tokens.js" as T

// D-61: the highlight ends T.hoverInset inside its container and its corners are concentric with it.
Item {
    id: host

    width: 300
    height: 200

    // A 14 px container with a row padded 10 px from the left and right edges and 14 px from a divider on the left.
    Rectangle {
        id: container

        x: 20
        y: 20
        width: 200
        height: 100
        radius: T.radiusInner

        Item {
            id: padded

            x: 14
            y: 10
            width: container.width - 14 - 10
            height: 30

            HoverHighlight {
                id: highlight

                containerRadius: T.radiusInner
                leftGap: 14
                rightGap: 10
                topGap: 10
                bottomGap: T.hoverInset + 2
            }
        }

        Item {
            id: filling

            anchors.fill: parent

            HoverHighlight {
                id: whole

                containerRadius: T.radiusInner
                shown: true
            }
        }
    }

    TestCase {
        name: "HoverHighlight"
        when: windowShown
        parent: host

        function test_hidden_until_shown() {
            compare(highlight.visible, false);
            highlight.shown = true;
            compare(highlight.visible, true);
        }

        function test_padded_row_ends_inset_from_the_container() {
            const tl = padded.mapFromItem(highlight, 0, 0);
            const inContainer = container.mapFromItem(highlight, 0, 0);
            compare(inContainer.x, T.hoverInset);
            compare(inContainer.y, T.hoverInset);
            compare(inContainer.x + highlight.width, container.width - T.hoverInset);
            compare(inContainer.y + highlight.height, 10 + 30 + 2);
            verify(tl.x < 0);
        }

        function test_radius_is_concentric() {
            compare(highlight.radius, T.radiusInner - T.hoverInset);
        }

        function test_row_filling_the_container_is_inset_on_every_side() {
            const p = container.mapFromItem(whole, 0, 0);
            compare(p.x, T.hoverInset);
            compare(p.y, T.hoverInset);
            compare(whole.width, container.width - 2 * T.hoverInset);
            compare(whole.height, container.height - 2 * T.hoverInset);
        }
    }
}
