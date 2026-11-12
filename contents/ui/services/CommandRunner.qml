pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support
import "../logic/Utils.js" as Utils

// The single place that runs shell commands for an island (the Plasma `executable` data engine). Services and the
// coordinator call run(); nobody else creates a data engine for commands. One instance per island, never a singleton.
Plasma5Support.DataSource {
    id: runner

    // command -> handlers waiting for its result
    property var waiting: ({})

    // Run `command`. With a `handler`, it is called as handler(stdout, data) when the command finishes; without one the
    // command is fire-and-forget. The engine dedupes identical command strings, so a command already in flight is not
    // started twice: every handler waiting on it gets the one result, and a handler is never added twice.
    function run(command, handler) {
        if (!command)
            return ;

        if (handler) {
            const list = waiting[command] || [];
            if (list.indexOf(handler) === -1)
                list.push(handler);

            waiting[command] = list;
        }
        connectSource(command);
    }

    engine: "executable"
    onNewData: (sourceName, data) => {
        const handlers = runner.waiting[sourceName] || [];
        delete runner.waiting[sourceName];
        const stdout = Utils.commandStdout(data);
        for (let i = 0; i < handlers.length; ++i)
            handlers[i](stdout, data);

        disconnectSource(sourceName);
    }
}
