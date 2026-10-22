import QtQuick
import org.kde.kirigami as Kirigami

// Rounded square button with an MDI icon, like HA's ha-control-button
// (used by tile features: playback, volume, cover...).
Rectangle {
    id: btn

    property var client
    property string icon: ""
    property color tint: Kirigami.Theme.textColor
    property bool active: false        // filled with the tint (e.g. muted)

    signal clicked()

    implicitHeight: Kirigami.Units.gridUnit * 2.2
    implicitWidth: implicitHeight
    radius: Math.round(Kirigami.Units.gridUnit * 0.6)
    color: active ? Qt.rgba(tint.r, tint.g, tint.b, 0.35)
         : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                   mouse.containsMouse && enabled ? 0.16 : 0.08)
    opacity: enabled ? 1 : 0.4

    HaIcon {
        anchors.centerIn: parent
        client: btn.client
        icon: btn.icon
        size: Kirigami.Units.iconSizes.smallMedium
        color: btn.active ? btn.tint : Kirigami.Theme.textColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
