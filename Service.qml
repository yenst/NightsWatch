import QtQuick
import Quickshell.Io

Item {
    id: root
    property bool panelOpen: false
    property var ports: []
    property string error: ""
    property string warning: ""
    property string notice: ""
    onNoticeChanged: if (notice)
        noticeTimer.restart()
    property string updatedAt: ""
    property bool ready: false
    property bool truncated: false
    readonly property bool refreshing: scan.running
    readonly property bool stopping: stop.running
    readonly property string helper: decodeURIComponent(Qt.resolvedUrl("scripts/ports.py").toString()).replace(/^file:\/\//, "")
    Timer {
        id: noticeTimer
        interval: 6000
        onTriggered: root.notice = ""
    }

    function refresh() {
        if (!scan.running)
            scan.running = true;
    }
    function copyAddress(address) {
        copyText(address, "Address copied.");
    }
    function copyText(value, successMessage) {
        if (clipboard.running)
            return;
        clipboard.successMessage = successMessage;
        clipboard.command = ["/usr/bin/wl-copy", "--", value];
        clipboard.running = true;
    }
    Process {
        id: clipboard
        property string successMessage: "Copied."
        onExited: function (code) {
            root.notice = code === 0 ? clipboard.successMessage : "Could not copy the address.";
        }
    }
    function stopProcess(port) {
        if (stop.running || !port || !port.canStop)
            return;
        notice = "";
        stop.command = ["/usr/bin/python3", helper, "stop", String(port.pid), String(port.startTime)];
        stop.running = true;
    }
    Process {
        id: scan
        command: ["/usr/bin/python3", root.helper, "scan"]
        stdout: StdioCollector {
            id: scanOutput
            waitForEnd: true
        }
        onExited: function (code) {
            try {
                var result = JSON.parse(scanOutput.text);
                if (code !== 0 || result.error)
                    throw new Error(result.error || "Could not read listening ports");
                if (JSON.stringify(root.ports) !== JSON.stringify(result.ports))
                    root.ports = result.ports;
                root.warning = result.warning || "";
                root.truncated = !!result.truncated;
                root.updatedAt = Qt.formatTime(new Date(), "HH:mm");
                root.error = "";
                root.ready = true;
            } catch (e) {
                root.error = "Refresh failed. " + (e.message || "Try again.");
            }
        }
    }
    Process {
        id: stop
        stdout: StdioCollector {
            id: stopOutput
            waitForEnd: true
        }
        onExited: function (code) {
            try {
                var result = JSON.parse(stopOutput.text);
                root.notice = code === 0 && result.ok ? "Stop requested. The process may take a moment to exit." : (result.error || "Could not stop this process.");
            } catch (e) {
                root.notice = "Could not stop this process. Refresh and try again.";
            }
            root.refresh();
        }
    }
    Timer {
        interval: root.panelOpen ? 3000 : 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    onPanelOpenChanged: if (panelOpen)
        refresh()
}
