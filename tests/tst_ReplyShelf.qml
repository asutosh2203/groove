import QtQuick
import QtTest
import "../contents/ui/services"

TestCase {
    id: tc

    name: "ReplyShelf"
    when: windowShown

    property var replies: []
    property var dismissals: 0
    property bool replyWorks: true

    QtObject {
        id: fake

        property var activeNoticeId: 7

        function replyById(id, text) {
            tc.replies.push([id, text]);
            return tc.replyWorks;
        }

        function dismissNotice(closePopup) {
            tc.dismissals++;
        }
    }

    ReplyShelf {
        id: shelf

        notifications: fake
        eligible: true
    }

    function init() {
        replies = [];
        dismissals = 0;
        replyWorks = true;
        fake.activeNoticeId = 7;
        shelf.eligible = true;
        shelf.hovering = false;
        shelf.dwellSpent = false;
        shelf.shelfState = { "phase": "closed", "error": "" };
        shelf.clear();
    }

    function test_ineligible_popup_cannot_open() {
        shelf.eligible = false;
        shelf.open();
        verify(!shelf.isOpen);
    }

    function test_dwell_fires_once_per_hover_session() {
        shelf.hovering = true;
        tryCompare(shelf, "isOpen", true, 1000);
        shelf.escapePressed();
        verify(!shelf.isOpen);
        wait(400);
        verify(!shelf.isOpen, "no reopen while the pointer stays");
        shelf.hovering = false;
        shelf.hovering = true;
        tryCompare(shelf, "isOpen", true, 1000);
        shelf.hovering = false;
    }

    function test_lifetime_holds_for_text_or_focus_only() {
        shelf.open();
        verify(!shelf.holding);
        shelf.draft = "hi";
        verify(shelf.holding);
        shelf.draft = "";
        shelf.fieldFocused = true;
        verify(shelf.holding);
    }

    function test_pointer_leave_closes_only_an_empty_unfocused_shelf() {
        shelf.hovering = true;
        shelf.open();
        shelf.draft = "typing";
        shelf.hovering = false;
        verify(shelf.isOpen);
        shelf.draft = "";
        shelf.hovering = true;
        shelf.hovering = false;
        verify(!shelf.isOpen);
    }

    function test_escape_closes_the_shelf_then_the_popup() {
        let closed = 0;
        shelf.popupCloseRequested.connect(() => closed++);
        shelf.open();
        shelf.escapePressed();
        verify(!shelf.isOpen);
        compare(closed, 0);
        shelf.escapePressed();
        compare(closed, 1);
    }

    function test_send_replies_dismisses_and_closes() {
        shelf.open();
        shelf.send();
        compare(replies.length, 0, "an empty draft cannot send");
        shelf.draft = "  on my way ";
        shelf.send();
        compare(JSON.stringify(replies), JSON.stringify([[7, "on my way"]]));
        compare(dismissals, 1);
        verify(!shelf.isOpen);
        compare(shelf.draft, "");
    }

    function test_failure_keeps_text_and_shows_an_error() {
        replyWorks = false;
        shelf.open();
        shelf.draft = "hello";
        shelf.send();
        compare(shelf.phase, "error");
        compare(shelf.draft, "hello");
        compare(dismissals, 0);
        shelf.edited();
        compare(shelf.phase, "open");
    }

    function test_a_new_notification_resets_the_shelf() {
        shelf.open();
        shelf.draft = "old";
        fake.activeNoticeId = 8;
        verify(!shelf.isOpen);
        compare(shelf.draft, "");
    }
}
