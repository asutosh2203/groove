import QtQuick
import QtTest
import "../contents/ui/controlcenter" as CC

// D-69: the Control Center header's button restarts the tour; it has a name for assistive tech and hides in edit mode.
Item {
    id: testRoot

    width: 100
    height: 60

    property int retakes: 0

    QtObject {
        id: app

        readonly property var strings: QtObject {
            readonly property string tourRetake: "Show the welcome tour"
        }
        readonly property var tour: QtObject {
            function retake() { testRoot.retakes++; }
        }
        readonly property var layoutService: QtObject {
            property bool editMode: false
        }
    }

    CC.TourRetakeButton {
        id: button

        x: 10
        y: 10
        app: app
    }

    TestCase {
        name: "TourRetake"
        when: windowShown

        function init() {
            testRoot.retakes = 0;
            app.layoutService.editMode = false;
        }

        function test_aClickRetakes() {
            verify(button.visible);
            compare(button.width, 24);
            mouseMove(button, 12, 12);
            mouseClick(button, 12, 12);
            compare(testRoot.retakes, 1);
        }

        function test_hoverFollowsThePointerAndNeverSticks() {
            mouseMove(button, 12, 12);
            verify(button.hovered, "hovered while the pointer is over it");
            mouseClick(button, 12, 12);
            mouseMove(testRoot, 90, 50);
            verify(!button.hovered, "not hovered after a click and leaving");
            mouseMove(button, 12, 12);
            verify(button.hovered);
            mouseMove(testRoot, 90, 50);
            verify(!button.hovered);
        }

        function test_theKeyboardRetakes() {
            button.forceActiveFocus();
            keyClick(Qt.Key_Return);
            keyClick(Qt.Key_Space);
            compare(testRoot.retakes, 2);
        }

        function test_hiddenWhileTheLayoutIsEdited() {
            app.layoutService.editMode = true;
            verify(!button.visible);
        }

        function test_hasANameForAssistiveTech() {
            compare(button.Accessible.name, "Show the welcome tour");
            compare(button.Accessible.role, Accessible.Button);
        }
    }
}
