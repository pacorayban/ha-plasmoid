import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha

// HA "sensor" and "entity" cards: name, big value, optional graph.
CardFrame {
    id: card

    readonly property string entityId: config.entity || ""
    readonly property var st: { client.revision; return client.states[entityId]; }
    readonly property var attrs: st && st.attributes ? st.attributes : ({})
    readonly property bool showGraph: config.type === "sensor" && config.graph === "line"

    readonly property var raw: config.attribute ? attrs[config.attribute] : (st ? st.state : undefined)
    readonly property bool numeric: Ha.isNumeric(raw)
    readonly property string valueText: {
        if (!st)
            return "—";
        if (config.attribute)
            return numeric ? Ha.formatNumber(client, raw, -1) : Ha.attributeValueDisplay(client, entityId, config.attribute, raw);
        if (numeric)
            return Ha.formatNumber(client, raw, Ha.displayPrecision(client, entityId));
        return Ha.stateDisplay(client, entityId, st);
    }
    readonly property string unitText: numeric ? (config.unit !== undefined ? config.unit : (config.attribute ? "" : (attrs.unit_of_measurement || ""))) : ""

    implicitHeight: col.implicitHeight + 2 * padding

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Ha.runAction(card.client, card.dash, card.config.tap_action, card.entityId, "more-info")
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.padding
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            PC3.Label {
                Layout.fillWidth: true
                text: Ha.entityName(card.client, card.entityId, card.st, card.config.name)
                elide: Text.ElideRight
                opacity: 0.85
            }
            HaIcon {
                client: card.client
                icon: Ha.entityIcon(card.client, card.entityId, card.st, card.config.icon)
                color: card.dash.tint(card.config.state_color ? Ha.activeColor(card.entityId, card.st) : "", card.dash.iconColor)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            PC3.Label {
                text: card.valueText
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.2
                font.weight: Font.Normal
                elide: Text.ElideRight
                Layout.maximumWidth: col.width
            }
            PC3.Label {
                visible: card.unitText !== ""
                Layout.alignment: Qt.AlignBaseline
                text: card.unitText
                opacity: 0.7
            }
            Item { Layout.fillWidth: true }
        }

        HistoryChart {
            Layout.fillWidth: true
            visible: card.showGraph
            client: card.client
            dash: card.dash
            compact: true
            entityIds: card.showGraph ? [card.entityId] : []
            hours: card.config.hours_to_show || 24
        }
    }
}
