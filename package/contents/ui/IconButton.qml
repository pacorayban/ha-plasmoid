import QtQuick
import org.kde.kirigami as Kirigami

// Round flat button showing an MDI icon.
Item {
    id: btn

    property var client
    property string icon: ""
    property color color: Kirigami.Theme.textColor
    property real size: Kirigami.Units.iconSizes.smallMedium
    property bool highlighted: false
    property color highlightColor: Kirigami.Theme.highlightColor
    property string toolTip: ""

    signal clicked()

    implicitWidth: size + Kirigami.Units.smallSpacing * 3
    implicitHeight: implicitWidth
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: btn.highlighted ? Qt.rgba(btn.highlightColor.r, btn.highlightColor.g, btn.highlightColor.b, 0.25)
             : (mouse.containsMouse ? Qt.rgba(btn.color.r, btn.color.g, btn.color.b, 0.12) : "transparent")
    }

    HaIcon {
        anchors.centerIn: parent
        client: btn.client
        icon: btn.icon
        size: btn.size
        color: btn.highlighted ? btn.highlightColor : btn.color
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
