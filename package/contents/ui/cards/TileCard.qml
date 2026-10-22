import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha

// HA "tile" card, with the most common features (brightness, cover, temperature, modes).
CardFrame {
    id: card

    readonly property string entityId: config.entity || ""
    readonly property string domain: Ha.domainOf(entityId)
    readonly property var st: { client.revision; return client.states[entityId]; }
    readonly property var attrs: st && st.attributes ? st.attributes : ({})
    readonly property bool active: Ha.isActive(entityId, st)
    readonly property color accent: {
        var c = Ha.activeColor(entityId, st);
        if (config.color && config.color !== "state")
            return c !== "" ? dash.tint(config.color, dash.iconColor) : dash.disabledColor;
        return c !== "" ? dash.tint(c, dash.iconColor) : dash.disabledColor;
    }
    readonly property bool vertical: config.vertical === true

    function stateText() {
        if (!st)
            return "Introuvable";
        if (config.hide_state)
            return "";
        if (config.state_content) {
            var parts = [].concat(config.state_content).map(function (k) {
                switch (k) {
                case "state": return card.defaultStateText();
                case "area_name":
                    var a = Ha.areaOfEntity(client, entityId);
                    return a && client.areas[a] ? client.areas[a].name : "";
                case "last_changed": return Ha.relativeTime(st.last_changed);
                case "last_updated": return Ha.relativeTime(st.last_updated);
                default:
                    var v = attrs[k];
                    if (v === undefined || v === null) return "";
                    if (Ha.isNumeric(v)) {
                        var unit = k === "temperature" ? (attrs.temperature_unit || Ha.temperatureUnit(client))
                                 : k === "humidity" || k === "current_position" ? "%" : "";
                        return Ha.withUnit(Ha.formatNumber(client, v, k === "temperature" ? 1 : -1), unit);
                    }
                    return Ha.attributeValueDisplay(client, entityId, k, v);
                }
            }).filter(function (x) { return x !== ""; });
            return parts.join(" · ");
        }
        return defaultStateText();
    }

    function defaultStateText() {
        var base = Ha.stateDisplay(client, entityId, st);
        if (domain === "light" && st.state === "on" && attrs.brightness)
            return Math.round(attrs.brightness / 2.55) + " %";
        if ((domain === "cover" || domain === "valve") && attrs.current_position !== undefined && st.state !== "closed")
            return base + " · " + attrs.current_position + " %";
        if (domain === "climate" && attrs.current_temperature !== undefined && attrs.current_temperature !== null)
            return base + " · " + Ha.withUnit(Ha.formatNumber(client, attrs.current_temperature, 1), Ha.temperatureUnit(client));
        if (domain === "media_player" && attrs.media_title)
            return attrs.media_title + (attrs.media_artist ? " · " + attrs.media_artist : "");
        return base;
    }

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

        GridLayout {
            Layout.fillWidth: true
            columns: card.vertical ? 1 : 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            Rectangle {
                id: iconBg
                Layout.alignment: card.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
                implicitWidth: Kirigami.Units.gridUnit * 2.2
                implicitHeight: implicitWidth
                radius: width / 2
                color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.2)

                HaIcon {
                    anchors.centerIn: parent
                    client: card.client
                    icon: Ha.entityIcon(card.client, card.entityId, card.st, card.config.icon)
                    size: Kirigami.Units.iconSizes.smallMedium
                    color: card.accent
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Ha.runAction(card.client, card.dash, card.config.icon_tap_action, card.entityId,
                                            Ha.isTapToggleable(card.entityId) ? "toggle" : "more-info")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 0

                PC3.Label {
                    Layout.fillWidth: true
                    text: Ha.entityName(card.client, card.entityId, card.st, card.config.name)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    horizontalAlignment: card.vertical ? Text.AlignHCenter : Text.AlignLeft
                }
                PC3.Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.stateText()
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                    elide: Text.ElideRight
                    horizontalAlignment: card.vertical ? Text.AlignHCenter : Text.AlignLeft
                }
            }
        }

        Repeater {
            model: card.config.features || []

            delegate: Loader {
                required property var modelData
                readonly property string ftype: modelData && modelData.type ? modelData.type : ""
                Layout.fillWidth: true
                visible: item !== null
                sourceComponent: {
                    switch (ftype) {
                    case "light-brightness": return card.domain === "light" ? brightnessComp : null;
                    case "cover-open-close": return coverComp;
                    case "target-temperature": return targetComp;
                    case "climate-hvac-modes": return hvacComp;
                    case "toggle": return toggleComp;
                    default: return null;
                    }
                }
            }
        }
    }

    Component {
        id: brightnessComp
        PC3.Slider {
            id: bslider
            from: 1
            to: 100
            value: card.st && card.st.state === "on" && card.attrs.brightness ? Math.round(card.attrs.brightness / 2.55) : 0
            onMoved: sendTimer.restart()
            Timer {
                id: sendTimer
                interval: 300
                onTriggered: Ha.svc(card.client, "light", "turn_on", card.entityId, { brightness_pct: Math.round(bslider.value) })
            }
        }
    }

    Component {
        id: coverComp
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Item { Layout.fillWidth: true }
            IconButton { client: card.client; icon: "mdi:arrow-up"; onClicked: Ha.svc(card.client, "cover", "open_cover", card.entityId) }
            IconButton { client: card.client; icon: "mdi:stop"; onClicked: Ha.svc(card.client, "cover", "stop_cover", card.entityId) }
            IconButton { client: card.client; icon: "mdi:arrow-down"; onClicked: Ha.svc(card.client, "cover", "close_cover", card.entityId) }
            Item { Layout.fillWidth: true }
        }
    }

    Component {
        id: toggleComp
        RowLayout {
            Item { Layout.fillWidth: true }
            PC3.Switch {
                checked: card.st ? card.st.state === "on" : false
                onToggled: Ha.toggle(card.client, card.entityId)
            }
        }
    }

    Component {
        id: targetComp
        RowLayout {
            id: tgt
            property real pending: NaN
            readonly property real current: !isNaN(pending) ? pending : Number(card.attrs.temperature)
            readonly property real step: Number(card.attrs.target_temp_step || 0.5)
            function bump(dir) {
                var base = isNaN(current) ? 20 : current;
                pending = Math.round((base + dir * step) / step) * step;
                sendTimer.restart();
            }
            Timer {
                id: sendTimer
                interval: 1200
                onTriggered: {
                    Ha.svc(card.client, "climate", "set_temperature", card.entityId, { temperature: tgt.pending });
                    tgt.pending = NaN;
                }
            }
            IconButton { client: card.client; icon: "mdi:minus"; onClicked: tgt.bump(-1) }
            PC3.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: isNaN(tgt.current) ? "—" : Ha.withUnit(Ha.formatNumber(card.client, tgt.current, 1), Ha.temperatureUnit(card.client))
            }
            IconButton { client: card.client; icon: "mdi:plus"; onClicked: tgt.bump(1) }
        }
    }

    Component {
        id: hvacComp
        Flow {
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: card.attrs.hvac_modes || []
                IconButton {
                    required property var modelData
                    client: card.client
                    icon: Ha.HVAC_ICONS[modelData] || "mdi:thermostat"
                    highlighted: card.st && card.st.state === modelData
                    highlightColor: card.dash.tint(Ha.activeColor(card.entityId, { state: modelData, attributes: {} }), Kirigami.Theme.highlightColor)
                    onClicked: Ha.svc(card.client, "climate", "set_hvac_mode", card.entityId, { hvac_mode: modelData })
                }
            }
        }
    }
}
