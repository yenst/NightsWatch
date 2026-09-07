import QtQuick
import qs.Commons

// Material Design icons from Omarchy's installed Nerd Font library.
Text {
    property int code: 0xF1829
    text: String.fromCodePoint(code)
    textFormat: Text.PlainText
    font.family: Style.font.family
    font.pixelSize: Style.space(20)
    color: Color.foreground
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
