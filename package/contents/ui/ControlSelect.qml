import QtQuick
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami

// Dropdown like HA's ha-control-select-menu: small label above the current
// value, arrow on the right, menu of options on click.
Rectangle {
    id: sel

    property string label: ""
    property string current: ""
    property var options: []

    signal picked(string option)

    implicitHeight: Kirigami.Units.gridUnit * 2.6
    implicitWidth: Kirigami.Units.gridUnit * 8
    radius: Math.round(Kirigami.Units.gridUnit * 0.6)
    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b,
                   mouse.containsMouse && enabled ? 0.16 : 0.08)
    opacity: enabled ? 1 : 0.4

    Column {
        anchors.left: parent.left
        anchors.right: arrow.left
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        PC3.Label {
            width: parent.width
            text: sel.label
            font: Kirigami.Theme.smallFont
            opacity: 0.75
            elide: Text.ElideRight
            visible: text !== ""
        }
        PC3.Label {
            width: parent.width
            text: sel.current || "—"
            elide: Text.ElideRight
        }
    }

    Kirigami.Icon {
        id: arrow
        anchors.right: parent.right
        anchors.rightMargin: Kirigami.Units.smallSpacing * 2
        anchors.verticalCenter: parent.verticalCenter
        width: Kirigami.Units.iconSizes.small
        height: width
        source: "arrow-down"
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: sel.enabled && sel.options.length > 0
        cursorShape: Qt.PointingHandCursor
        onClicked: menu.popup(sel, 0, sel.height)
    }

    QQC2.Menu {
        id: menu
        Repeater {
            model: sel.options
            delegate: QQC2.MenuItem {
                required property var modelData
                text: String(modelData)
                checkable: true
                checked: String(modelData) === sel.current
                onTriggered: sel.picked(String(modelData))
            }
        }
    }
}
