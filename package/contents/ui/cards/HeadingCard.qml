import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha

// HA "heading" card (section titles), also used for unknown cards that only have a title.
CardFrame {
    id: card

    frameless: true
    padding: Kirigami.Units.smallSpacing
    implicitHeight: row.implicitHeight + 2 * padding

    readonly property var badges: (config.badges || config.entities || []).map(Ha.entityConf).filter(function (e) { return e && e.entity; })

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: card.padding
        spacing: Kirigami.Units.smallSpacing

        HaIcon {
            visible: !!card.config.icon
            client: card.client
            icon: card.config.icon || ""
            color: card.dash.iconColor
        }
        Kirigami.Heading {
            Layout.fillWidth: true
            level: card.config.heading_style === "subtitle" ? 5 : 3
            text: card.config.heading || card.config.title || ""
            elide: Text.ElideRight
            TapHandler {
                enabled: !!card.config.tap_action
                onTapped: Ha.runAction(card.client, card.dash, card.config.tap_action, null, "none")
            }
        }

        Repeater {
            model: card.badges
            delegate: Row {
                required property var modelData
                readonly property var st: { card.client.revision; return card.client.states[modelData.entity]; }
                spacing: Kirigami.Units.smallSpacing / 2
                HaIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: modelData.show_icon !== false
                    client: card.client
                    icon: Ha.entityIcon(card.client, modelData.entity, parent.st, modelData.icon)
                    size: Kirigami.Units.iconSizes.small
                    color: card.dash.tint(Ha.activeColor(modelData.entity, parent.st), card.dash.iconColor)
                }
                PC3.Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: modelData.show_state !== false
                    text: Ha.stateDisplay(card.client, modelData.entity, parent.st)
                    font: Kirigami.Theme.smallFont
                }
                TapHandler { onTapped: card.dash.moreInfo(modelData.entity) }
            }
        }
    }
}
