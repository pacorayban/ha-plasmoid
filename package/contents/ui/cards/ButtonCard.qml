import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha

// HA "button" card: big icon, name, optional state.
CardFrame {
    id: card

    readonly property string entityId: config.entity || ""
    readonly property var st: { client.revision; return entityId ? client.states[entityId] : undefined; }
    readonly property bool stateColor: config.state_color !== undefined ? config.state_color : true
    readonly property real iconSize: {
        var h = config.icon_height ? parseInt(config.icon_height) : NaN;
        return isNaN(h) ? Kirigami.Units.gridUnit * 2.6 : h;
    }

    implicitHeight: col.implicitHeight + 2 * padding

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Ha.runAction(card.client, card.dash, card.config.tap_action, card.entityId,
                                card.entityId ? Ha.defaultTapAction(card.entityId) : "none")
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.padding
        spacing: Kirigami.Units.smallSpacing

        HaIcon {
            Layout.alignment: Qt.AlignHCenter
            visible: card.config.show_icon !== false
            client: card.client
            icon: card.entityId ? Ha.entityIcon(card.client, card.entityId, card.st, card.config.icon)
                                : (card.config.icon || "mdi:gesture-tap-button")
            size: card.iconSize
            color: card.dash.tint(card.stateColor && card.entityId
                                  ? Ha.activeColor(card.entityId, card.st) : "", card.dash.iconColor)
        }
        PC3.Label {
            Layout.fillWidth: true
            visible: card.config.show_name !== false && text !== ""
            text: card.entityId ? Ha.entityName(card.client, card.entityId, card.st, card.config.name) : (card.config.name || "")
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        PC3.Label {
            Layout.fillWidth: true
            visible: card.config.show_state === true && card.entityId !== ""
            text: Ha.stateDisplay(card.client, card.entityId, card.st)
            horizontalAlignment: Text.AlignHCenter
            font: Kirigami.Theme.smallFont
            opacity: 0.75
            elide: Text.ElideRight
        }
    }
}
