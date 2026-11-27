import QtQuick
import QtTest
import "../contents/ui/weather" as W

// QML's XMLHttpRequest ignores `timeout`: a request that is accepted and never answered never finishes. The fake below is
// that request (open and send, then silence), so the watchdog alone must release `busy`, mark the failure, abort the request
// and leave the retry to run.
Item {
    id: testRoot

    property var made: []

    function silentRequest() {
        const r = {
            "readyState": 0,
            "status": 0,
            "responseText": "",
            "aborted": false,
            "opened": "",
            "onreadystatechange": null,
            "onerror": null,
            "open": function(method, url) { r.opened = url; r.readyState = 1; },
            "send": function() {},
            "abort": function() { r.aborted = true; }
        };
        testRoot.made.push(r);
        return r;
    }

    W.WeatherService {
        id: svc

        followsSettings: false
        locationName: "Testville"
        latitude: 1.5
        longitude: 2.5
        requestTimeoutMs: 200
        createRequest: () => testRoot.silentRequest()
    }

    TestCase {
        name: "WeatherWatchdog"

        function init() {
            testRoot.made = [];
        }

        function test_aStalledRequestReleasesBusy() {
            svc.refresh();
            compare(testRoot.made.length, 1);
            verify(svc.busy);
            verify(testRoot.made[0].opened.indexOf("latitude=1.5000") > 0);
            tryVerify(() => !svc.busy, 2000);
            verify(svc.failing);
            verify(testRoot.made[0].aborted);
            compare(svc.pending, null);
        }

        function test_aLateAnswerAfterTheWatchdogIsIgnored() {
            svc.refresh();
            const r = testRoot.made[0];
            tryVerify(() => !svc.busy, 2000);
            svc.failing = false;
            r.readyState = 4;
            r.status = 0;
            r.onreadystatechange();
            verify(!svc.failing, "the stale request must not touch the state again");
        }

        function test_theNextRefreshStartsAFreshRequest() {
            svc.refresh();
            tryVerify(() => !svc.busy, 2000);
            svc.refresh();
            compare(testRoot.made.length, 2);
            verify(svc.busy);
            tryVerify(() => !svc.busy, 2000);
        }
    }
}
