pragma ComponentBehavior: Bound

import QtQuick
import "../../controlcenter/Tokens.js" as T
import "../../logic/Geocoding.js" as Geocoding

// Open-Meteo place search for the settings form: the user types, the request runs on Enter or after a short pause, and
// they pick a result (no GPS or IP guessing). One request at a time; the timer only runs between typing and the request.
Item {
    id: search

    required property var strings
    property var results: []
    // "", "searching", "short", "failed", "none" or "ready".
    property string status: ""
    property string query: ""

    function submit(text) {
        pause.stop();
        search.query = text;
        if (!Geocoding.validQuery(text)) {
            search.results = [];
            search.status = text.trim().length === 0 ? "" : "short";
            return ;
        }
        search.status = "searching";
        const request = new XMLHttpRequest();
        request.timeout = 15000;
        request.onreadystatechange = () => search.finish(request, text);
        request.ontimeout = () => {
            search.status = "failed";
        };
        request.open("GET", Geocoding.url(text, Qt.locale().name));
        request.send();
    }

    // A stale answer (the text changed since) is ignored.
    function finish(request, text) {
        if (request.readyState !== XMLHttpRequest.DONE || search.query !== text)
            return ;
        const rows = request.status === 200 ? Geocoding.parse(request.responseText) : null;
        search.results = rows === null ? [] : rows;
        search.status = rows === null ? "failed" : rows.length === 0 ? "none" : "ready";
    }

    // A pause in typing starts the search; Enter starts it at once.
    function typed(text) {
        search.query = text;
        search.results = [];
        search.status = "";
        pause.restart();
    }

    function clear() {
        pause.stop();
        search.query = "";
        search.results = [];
        search.status = "";
    }

    readonly property string statusText: search.status === "searching" ? search.strings.editSearching : search.status === "short" ? search.strings.editSearchShort : search.status === "failed" ? search.strings.editSearchFailed : search.status === "none" ? search.strings.editSearchNone : ""

    Timer {
        id: pause

        interval: T.editSearchPause
        onTriggered: search.submit(search.query)
    }
}
