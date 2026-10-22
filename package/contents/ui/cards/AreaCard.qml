import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha

// HA "area" card: area name, key sensors and quick toggles per domain.
CardFrame {
    id: card

    readonly property string areaId: config.area || ""
    readonly property var area: client.areas[areaId]
    readonly property var ids: area ? Ha.areaEntities(client, areaId) : []

    function firstSensor(deviceClass, registryKey) {
        if (area && area[registryKey] && client.states[area[registryKey]])
            return area[registryKey];
        for (var i = 0; i < ids.length; i++) {
            var st = client.states[ids[i]];
            if (Ha.domainOf(ids[i]) === "sensor" && st && st.attributes.device_class === deviceClass)
                return ids[i];
        }
        return "";
    }

    readonly property var sensorIds: {
        var out = [];
        var t = firstSensor("temperature", "temperature_entity_id");
        var h = firstSensor("humidity", "humidity_entity_id");
        if (t) out.push(t);
        if (h) out.push(h);
        return out;
    }
    readonly property var toggleDomains: ["light", "switch", "fan"].filter(function (d) {
        return card.ids.some(function (id) { return Ha.domainOf(id) === d; });
    })

    readonly property bool compact: config.vertical === true || config.display_type === "compact"
    readonly property bool lightsOn: {
        client.revision;
        return ids.some(function (id) { return Ha.domainOf(id) === "light" && client.states[id] && client.states[id].state === "on"; });
    }
    readonly property string sensorText: {
        client.revision;
        var list = compact && config.sensor_classes ? sensorIds.slice(0, Math.max(1, config.sensor_classes.length)) : sensorIds;
        if (compact && (!config.sensor_classes || config.sensor_classes.length === 0))
            list = [];
        return list.map(function (id) { return Ha.stateDisplay(client, id, client.states[id]); }).join(" · ");
    }

    implicitHeight: (compact ? compactCol.implicitHeight : col.implicitHeight) + 2 * padding

    // Compact vertical style used by the Home dashboard: icon, name, temperature.
    ColumnLayout {
        id: compactCol
        visible: card.compact
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.padding
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            readonly property color tone: card.lightsOn ? card.dash.tint("amber", "") : card.dash.iconColor
            implicitWidth: Kirigami.Units.gridUnit * 2.2
            implicitHeight: implicitWidth
            radius: width / 2
            color: Qt.rgba(tone.r, tone.g, tone.b, 0.18)
            HaIcon {
                anchors.centerIn: parent
                client: card.client
                icon: card.area && card.area.icon ? card.area.icon : "mdi:texture-box"
                color: parent.tone
            }
        }
        PC3.Label {
            Layout.fillWidth: true
            text: card.area ? card.area.name : card.areaId
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
        PC3.Label {
            // Always present so every compact area card has the same height.
            Layout.fillWidth: true
            text: card.sensorText
            font: Kirigami.Theme.smallFont
            opacity: 0.75
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Ha.runAction(card.client, card.dash, card.config.tap_action, null, "none")
    }

    ColumnLayout {
        id: col
        visible: !card.compact
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.padding
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            HaIcon {
                client: card.client
                icon: card.area && card.area.icon ? card.area.icon : "mdi:texture-box"
                color: card.dash.iconColor
            }
            Kirigami.Heading {
                Layout.fillWidth: true
                level: 4
                text: card.area ? card.area.name : card.areaId
                elide: Text.ElideRight
            }
        }

        PC3.Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: {
                card.client.revision;
                return card.sensorIds.map(function (id) {
                    return Ha.stateDisplay(card.client, id, card.client.states[id]);
                }).join(" · ");
            }
            opacity: 0.8
            elide: Text.ElideRight
        }

        Row {
            visible: card.toggleDomains.length > 0
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: card.toggleDomains
                delegate: IconButton {
                    required property var modelData
                    readonly property var domainIds: card.ids.filter(function (id) { return Ha.domainOf(id) === modelData; })
                    readonly property bool anyOn: {
                        card.client.revision;
                        return domainIds.some(function (id) { return card.client.states[id] && card.client.states[id].state === "on"; });
                    }
                    client: card.client
                    icon: Ha.FALLBACK_ICONS[modelData]
                    highlighted: anyOn
                    highlightColor: modelData === "fan" ? Ha.COLORS.cyan : Ha.COLORS.amber
                    onClicked: card.client.callService(modelData, anyOn ? "turn_off" : "turn_on", {}, { entity_id: domainIds })
                }
            }
        }
    }
}
