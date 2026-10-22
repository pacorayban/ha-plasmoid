import QtQuick
import org.kde.kirigami as Kirigami

// Wide on/off switch like HA's ha-control-switch (tile "toggle" feature):
// the filled half sits on the right when on, with a power icon.
Rectangle {
    id: sw

    property var client
    property bool checked: false
    property color tint: Kirigami.Theme.highlightColor

    signal toggled()

    implicitHeight: Kirigami.Units.gridUnit * 2.2
    implicitWidth: Kirigami.Units.gridUnit * 8
    radius: Math.round(Kirigami.Units.gridUnit * 0.6)
    color: sw.checked ? Qt.rgba(tint.r, tint.g, tint.b, 0.2)
                      : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: knob
        width: parent.width / 2
        height: parent.height
        radius: parent.radius
        x: sw.checked ? parent.width - width : 0
        color: sw.checked ? sw.tint
             : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.25)
        Behavior on x { NumberAnimation { duration: Kirigami.Units.shortDuration } }

        HaIcon {
            anchors.centerIn: parent
            client: sw.client
            icon: sw.checked ? "mdi:power" : "mdi:power-off"
            size: Kirigami.Units.iconSizes.small
            color: sw.checked ? "white" : Kirigami.Theme.textColor
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: sw.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
