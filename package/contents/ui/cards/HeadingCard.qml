import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha

// HA "heading" card (section titles), also used for unknown cards that only have a title.
// Badges can be entities or buttons, each with optional visibility conditions.
CardFrame {
    id: card

    frameless: true
    padding: Kirigami.Units.smallSpacing
    implicitHeight: Math.max(row.implicitHeight, card.config.heading_style === "title" ? Kirigami.Units.gridUnit * 2 : 0) + 2 * padding

    readonly property var badges: (config.badges || config.entities || []).map(Ha.entityConf)
        .filter(function (e) { return e && (e.entity || e.type === "button"); })

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
            level: card.config.heading_style === "subtitle" ? 5 : (card.config.heading_style === "title" ? 2 : 3)
            text: card.config.heading !== undefined ? card.config.heading : (card.config.title || "")
            elide: Text.ElideRight
            TapHandler {
                enabled: !!card.config.tap_action
                onTapped: Ha.runAction(card.client, card.dash, card.config.tap_action, null, "none")
            }
        }

        Repeater {
            model: card.badges
            delegate: Loader {
                id: badgeLoader
                required property var modelData
                visible: { card.client.revision; return Ha.checkConditions(card.client, modelData.visibility); }
                sourceComponent: modelData.type === "button" ? buttonBadge : entityBadge

                Component {
                    id: entityBadge
                    Row {
                        readonly property var st: { card.client.revision; return card.client.states[badgeLoader.modelData.entity]; }
                        spacing: Kirigami.Units.smallSpacing / 2
                        HaIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: badgeLoader.modelData.show_icon !== false
                            client: card.client
                            icon: Ha.entityIcon(card.client, badgeLoader.modelData.entity, parent.st, badgeLoader.modelData.icon)
                            size: Kirigami.Units.iconSizes.small
                            color: card.dash.tint(Ha.activeColor(badgeLoader.modelData.entity, parent.st), card.dash.iconColor)
                        }
                        PC3.Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: badgeLoader.modelData.show_state !== false
                            text: Ha.stateDisplay(card.client, badgeLoader.modelData.entity, parent.st)
                            font: Kirigami.Theme.smallFont
                        }
                        TapHandler { onTapped: card.dash.moreInfo(badgeLoader.modelData.entity) }
                    }
                }

                Component {
                    id: buttonBadge
                    Rectangle {
                        readonly property color tone: card.dash.tint(badgeLoader.modelData.color || "", card.dash.iconColor)
                        implicitHeight: Kirigami.Units.gridUnit * 1.5
                        implicitWidth: btnRow.implicitWidth + Kirigami.Units.largeSpacing * 2
                        radius: height / 2
                        color: btnMouse.containsMouse ? Qt.rgba(tone.r, tone.g, tone.b, 0.25) : Qt.rgba(tone.r, tone.g, tone.b, 0.12)
                        Row {
                            id: btnRow
                            anchors.centerIn: parent
                            spacing: Kirigami.Units.smallSpacing
                            HaIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !!badgeLoader.modelData.icon
                                client: card.client
                                icon: badgeLoader.modelData.icon || ""
                                size: Kirigami.Units.iconSizes.small
                                color: parent.parent.tone
                            }
                            PC3.Label {
                                anchors.verticalCenter: parent.verticalCenter
                                text: badgeLoader.modelData.text || ""
                                font: Kirigami.Theme.smallFont
                            }
                        }
                        MouseArea {
                            id: btnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Ha.runAction(card.client, card.dash, badgeLoader.modelData.tap_action, null, "none")
                        }
                    }
                }
            }
        }
    }
}
