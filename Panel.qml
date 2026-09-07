import QtQuick
import qs.Commons
import qs.Ui

Panel {
    id: root
    moduleName: "jihmy.nightswatch"
    ipcTarget: "jihmy.nightswatch"
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    Service {
        id: monitor
        panelOpen: root.opened
    }

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: String.fromCodePoint(0xF0200)
        tooltipText: "NightsWatch · " + monitor.ports.filter(p => p.category === "own").length + " listening ports"
        useActiveColor: false
        dimmed: monitor.ready && monitor.ports.filter(p => p.category === "own").length === 0
        onPressed: function (b) {
            if (b === Qt.MiddleButton)
                monitor.refresh();
            else
                root.toggle();
        }
    }
    KeyboardPanel {
        id: popup
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        padding: 0
        contentWidth: popup.fittedContentWidth(Style.space(400))
        contentHeight: popup.fittedContentHeight(content.implicitHeight)
        focusTarget: content
        Content {
            id: content
            anchors.fill: parent
            service: monitor
            onCloseRequested: root.close()
        }
    }
    onOpenedChanged: {
        if (opened) {
            content.reset();
            Qt.callLater(function () {
                content.forceActiveFocus();
            });
        }
    }
}
