import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha

// HA "glance" card: a grid of icon + name + state.
CardFrame {
    id: card

    readonly property var items: (config.entities || []).map(Ha.entityConf).filter(function (e) { return e && e.entity; })
    readonly property int cols: Math.max(1, Math.min(config.columns || 5, items.length || 1))

    implicitHeight: col.implicitHeight + 2 * padding

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.padding
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            Layout.fillWidth: true
            visible: !!card.config.title
            level: 4
            text: card.config.title || ""
            elide: Text.ElideRight
        }

        GridLayout {
            Layout.fillWidth: true
            columns: card.cols
            uniformCellWidths: true
            rowSpacing: Kirigami.Units.largeSpacing
            columnSpacing: Kirigami.Units.smallSpacing

            Repeater {
                model: card.items
                delegate: ColumnLayout {
                    id: cell
                    required property var modelData
                    readonly property var st: { card.client.revision; return card.client.states[modelData.entity]; }
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: Kirigami.Units.smallSpacing

                    PC3.Label {
                        Layout.fillWidth: true
                        visible: card.config.show_name !== false && cell.modelData.show_name !== false
                        text: Ha.entityName(card.client, cell.modelData.entity, cell.st, cell.modelData.name)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font: Kirigami.Theme.smallFont
                    }
                    HaIcon {
                        Layout.alignment: Qt.AlignHCenter
                        visible: card.config.show_icon !== false && cell.modelData.show_icon !== false
                        client: card.client
                        icon: Ha.entityIcon(card.client, cell.modelData.entity, cell.st, cell.modelData.icon)
                        color: card.dash.tint(card.config.state_color !== false
                                              ? Ha.activeColor(cell.modelData.entity, cell.st) : "", card.dash.iconColor)
                    }
                    PC3.Label {
                        Layout.fillWidth: true
                        visible: card.config.show_state !== false && cell.modelData.show_state !== false
                        text: cell.modelData.attribute && cell.st
                              ? Ha.attributeValueDisplay(card.client, cell.modelData.entity, cell.modelData.attribute, cell.st.attributes[cell.modelData.attribute])
                              : Ha.stateDisplay(card.client, cell.modelData.entity, cell.st)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font: Kirigami.Theme.smallFont
                        opacity: 0.8
                    }

                    TapHandler {
                        onTapped: Ha.runAction(card.client, card.dash, cell.modelData.tap_action || card.config.tap_action,
                                               cell.modelData.entity, "more-info")
                    }
                }
            }
        }
    }
}
