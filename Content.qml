import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import qs.Commons
import qs.Ui

FocusScope {
    id: root
    required property var service
    signal closeRequested
    property string category: "own"
    property string query: ""
    property string selectedKey: ""
    property bool inspecting: false
    readonly property color ink: Color.popups.text
    readonly property color secondary: Qt.rgba(ink.r, ink.g, ink.b, 0.66)
    readonly property color line: Qt.rgba(ink.r, ink.g, ink.b, 0.16)
    readonly property real pad: Style.space(16)
    readonly property var counts: {
        var c = {
            own: 0,
            apps: 0,
            system: 0
        };
        for (var p of service.ports)
            c[p.category]++;
        return c;
    }
    readonly property var rows: service.ports.filter(function (p) {
        return p.category === root.category && (!root.query || [p.port, p.process, p.project, p.command, p.cwd, p.address, p.proto, p.pid].join(" ").toLowerCase().indexOf(root.query.toLowerCase()) >= 0);
    })
    readonly property var selected: service.ports.find(p => p.key === root.selectedKey) || null
    readonly property string message: service.error || service.notice || service.warning || (service.truncated ? "Showing the first 500 listeners. Narrow your search." : "")
    implicitHeight: header.height + (message ? messageBox.implicitHeight : 0) + (inspecting ? detailActions.height + detail.implicitHeight : searchArea.height + section.height + Math.max(Style.space(96), Math.min(rows.length, 6) * Style.space(48)) + groups.height)

    onCategoryChanged: Qt.callLater(function () {
        list.positionViewAtBeginning();
    })
    onQueryChanged: Qt.callLater(function () {
        list.positionViewAtBeginning();
    })

    function reset() {
        category = "own";
        query = "";
        selectedKey = "";
        inspecting = false;
        Qt.callLater(function () {
            list.positionViewAtBeginning();
        });
    }
    function back() {
        if (inspecting)
            inspecting = false;
        else if (query) {
            query = "";
            forceActiveFocus();
        } else if (category !== "own")
            category = "own";
        else
            closeRequested();
    }
    function move(delta) {
        if (inspecting || !rows.length)
            return;
        var index = rows.findIndex(p => p.key === selectedKey);
        index = (index + delta + rows.length) % rows.length;
        selectedKey = rows[index].key;
        list.positionViewAtIndex(index, ListView.Contain);
    }
    function inspect(port) {
        selectedKey = port.key;
        inspecting = true;
        detail.contentY = 0;
        commandScroll.contentY = 0;
        forceActiveFocus();
    }
    function stopNow(port) {
        if (!port || !port.canStop || service.stopping)
            return;
        service.stopProcess(port);
    }
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) {
            back();
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            move(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            move(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return && !inspecting && rows.length) {
            inspect(rows.find(p => p.key === selectedKey) || rows[0]);
            event.accepted = true;
        } else if (event.key === Qt.Key_Slash && !inspecting) {
            search.forceActiveFocus();
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete && selected) {
            stopNow(selected);
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Color.popups.background
    }
    Column {
        anchors.fill: parent
        Item {
            id: header
            width: parent.width
            height: Style.space(68)
            Icon {
                x: root.pad
                anchors.verticalCenter: parent.verticalCenter
                code: 0xF0200
                font.pixelSize: Style.font.display
                rotation: 180
                color: root.ink
            }
            Column {
                x: root.pad + Style.space(42)
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - refresh.width - timestamp.width - root.pad - Style.space(20)
                spacing: Style.space(4)
                Label {
                    text: "NightsWatch"
                    font.pixelSize: Style.font.title
                    font.bold: true
                    width: parent.width
                    elide: Text.ElideRight
                }
                Label {
                    text: !service.ready ? (service.error ? "SCAN UNAVAILABLE" : "READING PORTS") : counts.own + " LISTENING PORT" + (counts.own === 1 ? "" : "S")
                    font.pixelSize: Style.font.caption
                    font.letterSpacing: 1.5
                    color: root.secondary
                }
            }
            Label {
                id: timestamp
                anchors.right: refresh.left
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: service.updatedAt
                font.pixelSize: Style.font.bodySmall
                color: root.secondary
            }
            IconButton {
                id: refresh
                anchors.right: parent.right
                anchors.rightMargin: root.pad
                anchors.verticalCenter: parent.verticalCenter
                code: 0xF04E6
                hint: "Refresh ports"
                enabled: !service.refreshing
                opacity: enabled ? 1 : 0.45
                onClicked: service.refresh()
            }
            Hairline {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: root.pad
                anchors.bottomMargin: 0
            }
        }
        Item {
            id: messageBox
            width: parent.width
            implicitHeight: messageText.implicitHeight + Style.space(22)
            height: visible ? implicitHeight : 0
            visible: !!root.message
            Label {
                id: messageText
                x: root.pad
                y: Style.space(11)
                width: parent.width - root.pad * 2
                text: root.message
                wrapMode: Text.Wrap
                font.pixelSize: Style.font.bodySmall
                color: service.error ? Color.urgent : root.secondary
            }
        }
        Item {
            id: searchArea
            width: parent.width
            height: visible ? Style.space(54) : 0
            visible: !root.inspecting
            Rectangle {
                x: root.pad
                y: Style.space(18)
                width: parent.width - root.pad * 2
                height: Style.space(32)
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.035)
                border.width: 1
                border.color: search.activeFocus ? Color.accent : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
                Icon {
                    x: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                    code: 0xF0349
                    color: root.secondary
                    font.pixelSize: Style.font.title
                }
                TextInput {
                    id: search
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Style.space(40)
                    anchors.rightMargin: Style.space(30)
                    text: root.query
                    onTextEdited: root.query = text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.body
                    color: root.ink
                    selectionColor: Color.accent
                    selectedTextColor: Color.background
                    clip: true
                    selectByMouse: true
                    Accessible.name: "Filter ports or processes"
                    Keys.onEscapePressed: {
                        root.back();
                        root.forceActiveFocus();
                    }
                    onAccepted: if (root.rows.length)
                        root.inspect(root.rows[0])
                    Label {
                        anchors.fill: parent
                        visible: !search.text
                        text: "Filter ports or processes…"
                        color: root.secondary
                        font.pixelSize: search.font.pixelSize
                        elide: Text.ElideRight
                    }
                }
                Label {
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "/"
                    color: root.secondary
                    font.pixelSize: Style.font.body
                }
            }
        }
        Item {
            id: section
            visible: !root.inspecting
            width: parent.width
            height: visible ? Style.space(32) : 0
            IconButton {
                id: categoryBack
                visible: root.category !== "own"
                x: root.pad - Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                code: 0xF004D
                hint: "Back to your processes"
                onClicked: {
                    root.category = "own";
                    root.selectedKey = "";
                }
            }
            Label {
                x: root.pad + (categoryBack.visible ? Style.space(35) : 0)
                anchors.verticalCenter: parent.verticalCenter
                text: root.category === "own" ? "YOUR PROCESSES" : root.category === "apps" ? "APPS" : "SYSTEM"
                font.pixelSize: Style.font.caption
                font.bold: true
                color: root.secondary
            }
        }
        ListView {
            id: list
            visible: !root.inspecting
            width: parent.width
            height: visible ? Math.max(Style.space(32), Math.min(Math.max(Style.space(96), Math.min(root.rows.length, 6) * Style.space(48)), root.height - header.height - messageBox.height - searchArea.height - section.height - groups.height)) : 0
            clip: true
            model: root.rows
            currentIndex: -1
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: Controls.ScrollBar {
                policy: list.contentHeight > list.height ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff
            }
            Label {
                visible: root.rows.length === 0
                anchors.centerIn: parent
                width: parent.width - root.pad * 2
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: !service.ready ? (service.error ? "Ports are unavailable. Try refresh." : "Reading listening ports…") : root.query ? "No matching ports" : root.category === "own" ? "All quiet. No listening processes." : "No listening ports in this group"
                color: root.secondary
                font.pixelSize: Style.font.body
            }
            delegate: Item {
                id: portRow
                required property var modelData
                required property int index
                width: ListView.view.width
                height: Style.space(48)
                readonly property bool hot: hover.hovered || rowButton.activeFocus || killButton.hovered || root.selectedKey === modelData.key
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, portRow.hot ? 0.065 : 0)
                }
                HoverHandler {
                    id: hover
                }
                Hairline {
                    anchors.top: parent.top
                    width: parent.width
                }
                Controls.AbstractButton {
                    id: rowButton
                    anchors.fill: parent
                    activeFocusOnTab: true
                    Accessible.name: "Inspect port " + modelData.port + ", " + modelData.project
                    onClicked: root.inspect(modelData)
                    background: Item {}
                    contentItem: Item {}
                }
                Label {
                    x: root.pad
                    anchors.verticalCenter: parent.verticalCenter
                    text: ":" + modelData.port
                    font.pixelSize: Style.font.heading
                    font.bold: true
                }
                Rectangle {
                    x: Style.space(100)
                    y: Style.space(13)
                    width: 1
                    height: parent.height - Style.space(26)
                    color: root.line
                }
                Column {
                    x: Style.space(116)
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - Style.space(85)
                    spacing: Style.space(4)
                    Label {
                        text: modelData.project
                        width: parent.width
                        elide: Text.ElideRight
                        font.pixelSize: Style.font.body
                    }
                    Label {
                        text: (modelData.process || modelData.proto.toUpperCase()) + " · " + modelData.scope
                        width: parent.width
                        elide: Text.ElideRight
                        color: root.secondary
                        font.pixelSize: Style.font.bodySmall
                    }
                }
                IconButton {
                    id: killButton
                    flat: true
                    anchors.right: chevron.left
                    anchors.rightMargin: Style.space(6)
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: portRow.hot && modelData.canStop ? 1 : 0
                    enabled: modelData.canStop && !service.stopping && (portRow.hot || activeFocus)
                    code: 0xF015A
                    tint: Qt.tint(root.ink, Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.6))
                    hint: "Stop process on port " + modelData.port
                    onClicked: root.stopNow(modelData)
                }
                Icon {
                    id: chevron
                    anchors.right: parent.right
                    anchors.rightMargin: root.pad
                    anchors.verticalCenter: parent.verticalCenter
                    code: 0xF0142
                    color: root.secondary
                }
            }
        }
        Item {
            id: groups
            visible: !root.inspecting
            width: parent.width
            height: visible ? Style.space(48) : 0
            Hairline {
                width: parent.width
            }
            Rectangle {
                x: parent.width / 2
                y: Style.space(13)
                height: parent.height - Style.space(26)
                width: 1
                color: root.line
            }
            Repeater {
                model: [
                    {
                        name: "Apps",
                        kind: "apps",
                        icon: 0xF11D9
                    },
                    {
                        name: "System",
                        kind: "system",
                        icon: 0xF08BB
                    }
                ]
                Controls.AbstractButton {
                    id: groupButton
                    required property var modelData
                    required property int index
                    x: index * parent.width / 2
                    width: parent.width / 2
                    height: parent.height
                    activeFocusOnTab: true
                    Accessible.name: modelData.name + ", " + root.counts[modelData.kind] + " listening ports"
                    onClicked: {
                        root.category = root.category === modelData.kind ? "own" : modelData.kind;
                        root.selectedKey = "";
                        root.forceActiveFocus();
                    }
                    background: Rectangle {
                        color: groupButton.hovered || groupButton.activeFocus || root.category === modelData.kind ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.065) : "transparent"
                    }
                    contentItem: Item {
                        Icon {
                            x: root.pad
                            anchors.verticalCenter: parent.verticalCenter
                            code: modelData.icon
                            color: root.secondary
                            font.pixelSize: Style.font.iconLarge
                        }
                        Label {
                            x: root.pad + Style.space(39)
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            font.pixelSize: Style.font.body
                        }
                        Label {
                            anchors.right: groupChevron.left
                            anchors.rightMargin: Style.space(20)
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.counts[modelData.kind]
                            color: root.secondary
                        }
                        Icon {
                            id: groupChevron
                            anchors.right: parent.right
                            anchors.rightMargin: root.pad
                            anchors.verticalCenter: parent.verticalCenter
                            code: 0xF0142
                            color: root.secondary
                        }
                    }
                }
            }
        }
        Item {
            id: detailActions
            visible: root.inspecting
            width: parent.width
            height: visible ? Style.space(44) : 0
            IconButton {
                x: root.pad
                anchors.verticalCenter: parent.verticalCenter
                code: 0xF004D
                hint: "Back to ports"
                onClicked: root.inspecting = false
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: root.pad
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(14)
                IconButton {
                    code: 0xF018F
                    hint: "Copy address"
                    enabled: !!root.selected
                    onClicked: service.copyAddress(root.selected.endpoint)
                }
                IconButton {
                    code: 0xF015A
                    hint: "Stop process"
                    flat: true
                    tint: Qt.tint(root.ink, Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.6))
                    enabled: !!root.selected && root.selected.canStop && !service.stopping
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.stopNow(root.selected)
                }
            }
            Hairline {
                anchors.bottom: parent.bottom
                width: parent.width
            }
        }
        Flickable {
            id: detail
            width: parent.width
            visible: root.inspecting
            implicitHeight: Math.min(detailBody.implicitHeight, Style.space(420))
            height: visible ? Math.max(0, Math.min(implicitHeight, root.height - header.height - messageBox.height - detailActions.height)) : 0
            contentHeight: detailBody.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: Controls.ScrollBar {}
            Column {
                id: detailBody
                x: root.pad
                width: parent.width - root.pad * 2
                spacing: Style.space(12)
                Item {
                    width: 1
                    height: Style.space(4)
                }
                Label {
                    text: root.selected ? ":" + root.selected.port + "  " + root.selected.project : "This listener has closed"
                    width: parent.width
                    wrapMode: Text.Wrap
                    font.pixelSize: Style.font.heading
                    font.bold: true
                }
                Label {
                    text: root.selected ? root.selected.process + " · PID " + (root.selected.pid || "unavailable") : "It disappeared since the last scan."
                    width: parent.width
                    elide: Text.ElideRight
                    color: root.secondary
                    font.pixelSize: Style.font.bodySmall
                }
                Hairline {
                    width: parent.width
                }
                Repeater {
                    model: root.selected ? [
                        {
                            label: "Protocol",
                            value: root.selected.proto.toUpperCase()
                        },
                        {
                            label: "Scope",
                            value: root.selected.scope
                        },
                        {
                            label: "Address",
                            value: root.selected.endpoint
                        },
                        {
                            label: "Folder",
                            value: root.selected.cwd || "Not available"
                        }
                    ] : []
                    Column {
                        required property var modelData
                        width: parent.width
                        spacing: Style.space(10)
                        Row {
                            width: parent.width
                            spacing: Style.space(12)
                            Label {
                                width: Style.space(70)
                                text: modelData.label
                                color: root.secondary
                                font.pixelSize: Style.font.bodySmall
                            }
                            TextEdit {
                                width: parent.width - Style.space(82)
                                text: modelData.value
                                textFormat: TextEdit.PlainText
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextEdit.WrapAnywhere
                                color: root.ink
                                font.family: Style.font.family
                                font.pixelSize: Style.font.bodySmall
                                selectionColor: Color.accent
                                selectedTextColor: Color.background
                            }
                        }
                        Hairline {
                            width: parent.width
                        }
                    }
                }
                Item {
                    width: parent.width
                    height: visible ? Style.space(28) : 0
                    visible: !!root.selected
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "COMMAND"
                        color: root.secondary
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }
                    IconButton {
                        anchors.right: parent.right
                        code: 0xF018F
                        hint: "Copy command"
                        enabled: !!root.selected && !!root.selected.command
                        onClicked: service.copyText(root.selected.command, "Command copied.")
                    }
                }
                Rectangle {
                    visible: !!root.selected
                    width: parent.width
                    height: visible ? Style.space(104) : 0
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.025)
                    border.width: 1
                    border.color: root.line
                    Flickable {
                        id: commandScroll
                        anchors.fill: parent
                        anchors.margins: Style.space(10)
                        clip: true
                        contentHeight: commandText.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        Controls.ScrollBar.vertical: Controls.ScrollBar {}
                        TextEdit {
                            id: commandText
                            width: commandScroll.width - Style.space(10)
                            text: root.selected ? root.selected.command || "Not available" : ""
                            textFormat: TextEdit.PlainText
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.WrapAnywhere
                            color: root.ink
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            selectionColor: Color.accent
                            selectedTextColor: Color.background
                        }
                    }
                }
                Label {
                    visible: !!root.selected && !root.selected.canStop
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: "This process cannot be stopped by your user."
                    color: root.secondary
                    font.pixelSize: Style.font.bodySmall
                }
                Item {
                    width: 1
                    height: root.pad
                }
            }
        }
    }
    component Label: Text {
        textFormat: Text.PlainText
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        color: root.ink
    }
    component Hairline: Rectangle {
        height: 1
        color: root.line
    }
    component IconButton: Controls.AbstractButton {
        id: control
        property int code: 0
        property string hint: ""
        property bool flat: false
        padding: 0
        property color tint: root.secondary
        width: Style.space(28)
        height: Style.space(30)
        activeFocusOnTab: true
        Accessible.name: hint
        background: Rectangle {
            color: !control.flat && (control.hovered || control.activeFocus) ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.09) : "transparent"
        }
        contentItem: Item {
            TextMetrics {
                id: iconMetrics
                font.family: Style.font.family
                font.pixelSize: Style.font.iconLarge
                text: String.fromCodePoint(control.code)
            }
            Text {
                text: iconMetrics.text
                textFormat: Text.PlainText
                font: iconMetrics.font
                color: control.tint
                x: (parent.width - iconMetrics.tightBoundingRect.width) / 2 - iconMetrics.tightBoundingRect.x
                y: (parent.height - iconMetrics.tightBoundingRect.height) / 2 - baselineOffset - iconMetrics.tightBoundingRect.y
            }
        }
    }
    component ActionButton: Controls.AbstractButton {
        id: action
        implicitWidth: label.implicitWidth + Style.space(26)
        implicitHeight: Style.space(34)
        activeFocusOnTab: true
        Accessible.name: text
        opacity: enabled ? 1 : 0.4
        background: Rectangle {
            color: action.hovered || action.activeFocus ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent"
            border.width: 1
            border.color: root.line
        }
        contentItem: Label {
            id: label
            text: action.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: Style.font.bodySmall
        }
    }
}
