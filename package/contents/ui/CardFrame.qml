import QtQuick
import org.kde.kirigami as Kirigami

// Base of every card: rounded translucent background plus shared properties.
Rectangle {
    id: frame

    property var config: ({})
    property var client
    property var dash
    property real padding: Kirigami.Units.largeSpacing
    property bool frameless: false

    readonly property color bgColor: Kirigami.Theme.backgroundColor
    readonly property color fgColor: Kirigami.Theme.textColor
    readonly property real cardOpacity: dash ? dash.cardOpacity : 0.8

    Kirigami.Theme.colorSet: Kirigami.Theme.View
    Kirigami.Theme.inherit: false

    radius: Math.round(Kirigami.Units.gridUnit * 0.7)
    color: frameless ? "transparent" : Qt.rgba(bgColor.r, bgColor.g, bgColor.b, cardOpacity)
    border.width: frameless ? 0 : 1
    border.color: Qt.rgba(fgColor.r, fgColor.g, fgColor.b, 0.10)
}
