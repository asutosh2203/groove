import QtQuick
import QtTest
import "../contents/ui" as UI

// Outside text must never become rich text: an <img> in a notification title or a track name would make Kove load a remote
// URL. The tag below uses a local file and a fixed size, so the check needs no network: rendered as an image the label is at
// least 60 px tall, rendered as text it is one line.
Item {
    id: testRoot
    width: 400
    height: 300

    readonly property string tag: "<img src=\"" + Qt.resolvedUrl("../contents/icon.svg") + "\" width=\"60\" height=\"60\"> Alice"

    // The reference: what AutoText does with the same string (the old behaviour).
    Text {
        id: autoText
        text: testRoot.tag
    }

    UI.PlasmaLabel {
        id: label
        y: 100
        text: testRoot.tag
    }

    UI.IslandButton {
        id: button
        x: 180
        y: 220
        width: 28
        height: 28
        iconName: "media-playback-pause"
        tooltipText: testRoot.tag
    }

    TestCase {
        name: "PlainLabels"
        when: windowShown

        function test_referenceRendersTheImage() {
            verify(autoText.implicitHeight >= 60, "AutoText should lay the tag out as a 60 px image");
        }

        function test_plasmaLabelShowsTheTagAsText() {
            compare(label.textFormat, Text.PlainText);
            verify(label.implicitHeight < 40);
            compare(label.lineCount, 1);
        }

        function test_tooltipShowsTheTagAsText() {
            let tip = null;
            for (let i = 0; i < button.data.length; i++) {
                if (button.data[i].spot !== undefined)
                    tip = button.data[i];
            }
            verify(tip !== null);
            compare(tip.contentItem.textFormat, Text.PlainText);
            compare(tip.contentItem.text, testRoot.tag);
        }
    }
}
