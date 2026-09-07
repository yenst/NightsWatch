import QtQuick
import Quickshell
import "Plugin" as NW
import qs.Commons
ShellRoot {
    QtObject {
        id: mock
        property var ports: [
            {key:"a",port:3000,proto:"tcp",process:"node",pid:24180,startTime:"1",category:"own",project:"NightsWatch",scope:"Local only",address:"127.0.0.1",endpoint:"127.0.0.1:3000",cwd:"~/Projects/NightsWatch",command:"node server.js",canStop:true},
            {key:"b",port:5173,proto:"tcp",process:"vite",pid:24181,startTime:"1",category:"own",project:"bl4nktv",scope:"All interfaces",endpoint:"0.0.0.0:5173",cwd:"~/Projects/bl4nktv",command:"vite --host",canStop:true},
            {key:"c",port:8000,proto:"tcp",process:"python3",pid:24182,startTime:"1",category:"own",project:"sandbox",scope:"Local only",endpoint:"127.0.0.1:8000",cwd:"~/Projects/sandbox",command:"python3 -m http.server",canStop:true}
        ]
        Component.onCompleted: {
            var more = []
            for (var i = 0; i < 7; i++) more.push({key:"extra"+i,port:9000+i,proto:"tcp",process:"test",pid:0,startTime:"",category:i<2?"apps":"system",project:"test",scope:"Local only",canStop:false})
            ports = ports.concat(more)
        }
        property bool ready: true
        property bool refreshing: false
        property bool stopping: false
        property bool truncated: false
        property string error: ""
        property string notice: ""
        property string warning: ""
        property string updatedAt: "16:48"
        function refresh() {}
        function copyAddress(address) { notice = "Address copied." }
        property int lastStopped: 0
        function copyText(value, message) { notice = message }
        function stopProcess(p) { lastStopped = p.pid }
    }
    FloatingWindow {
        id: win
        visible: true
        color: Color.background
        implicitWidth: Style.space(404)
        implicitHeight: Style.space(600)
        Rectangle {
            id: frame
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: content.implicitHeight + 4
            color: Color.background
            border.color: Color.accent
            border.width: 2
            NW.Content { id: content; anchors.fill: parent; anchors.margins: 2; service: mock; selectedKey: "a" }
        }
        Timer {
            interval: 250; running: true; repeat: true
            property int step: 0
            function check(value, message) { if (!value) throw new Error("UI TEST FAILED: " + message) }
            onTriggered: {
                if (step === 0) {
                    check(content.rows.length === 3, "initial rows")
                    content.query = "5173"
                    check(content.rows.length === 1 && content.rows[0].process === "vite", "filter")
                    content.query = "nothing-matches"
                    check(content.rows.length === 0, "no matches")
                    content.reset(); content.move(1); check(content.selectedKey === "a", "first row")
                    content.move(1); check(content.selectedKey === "b", "next row")
                    content.inspect(content.rows[1]); check(content.inspecting && content.selected.port === 5173, "inspect")
                    content.stopNow(content.selected); check(mock.lastStopped === 24181, "immediate stop")
                    content.stopNow(null); check(mock.lastStopped === 24181, "missing process ignored")
                    content.stopNow({canStop:false,pid:99}); check(mock.lastStopped === 24181, "non-owned process ignored")
                    mock.stopping = true; content.stopNow(content.rows[0]); check(mock.lastStopped === 24181, "busy ignored"); mock.stopping = false
                    content.back(); check(!content.inspecting, "back")
                    content.category = "system"; check(content.rows.length === 5, "system filter")
                    content.back(); check(content.category === "own", "back to own")
                    content.inspect(content.rows[0]); var saved = mock.ports; mock.ports = saved.slice(1)
                    check(content.selected === null && content.inspecting, "closed listener")
                    mock.ports = saved; content.reset(); content.selectedKey = "a"
                    console.log("UI TEST PASS: filter, empty, navigation, inspect, immediate stop, ownership guard, category, disappearing listener")
                } else if (step === 1) {
                    frame.grabToImage(function(r) { r.saveToFile(Quickshell.env("NIGHTSWATCH_CAPTURE_DIR") + "/implementation.png") }, Qt.size(frame.width * 2, frame.height * 2))
                } else if (step === 2) { content.inspect(content.rows[0])
                } else if (step === 3) {
                    frame.grabToImage(function(r) { r.saveToFile(Quickshell.env("NIGHTSWATCH_CAPTURE_DIR") + "/detail.png") }, Qt.size(frame.width * 2, frame.height * 2))
                } else if (step === 4) {
                    var longPorts = JSON.parse(JSON.stringify(mock.ports))
                    longPorts[0].command = "node server.js " + "--long-argument=value ".repeat(90)
                    mock.ports = longPorts
                } else if (step === 5) {
                    frame.grabToImage(function(r) { r.saveToFile(Quickshell.env("NIGHTSWATCH_CAPTURE_DIR") + "/long-command.png") }, Qt.size(frame.width * 2, frame.height * 2))
                } else Qt.quit()
                step++
            }
        }
    }
}
