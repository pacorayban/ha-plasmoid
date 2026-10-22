import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha
import "../../code/Tr.js" as Tr

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
            return Tr.tr(client, "Not found");
        if (config.hide_state)
            return "";
        if (config.state_content) {
            var parts = [].concat(config.state_content).map(function (k) {
                switch (k) {
                case "state": return card.defaultStateText();
                case "area_name":
                    var a = Ha.areaOfEntity(client, entityId);
                    return a && client.areas[a] ? client.areas[a].name : "";
                case "last_changed": return Ha.relativeTime(client, st.last_changed);
                case "last_updated": return Ha.relativeTime(client, st.last_updated);
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
                Layout.topMargin: Kirigami.Units.smallSpacing
                visible: item !== null
                onLoaded: if (item && item.hasOwnProperty("fcfg")) item.fcfg = modelData
                sourceComponent: card.featureComponent(ftype)
            }
        }
    }

    // Tile features (the controls under the tile), drawn like HA's.
    function featureComponent(type) {
        var mp = domain === "media_player";
        switch (type) {
        case "light-brightness": return domain === "light" ? brightnessComp : null;
        case "cover-open-close": return coverComp;
        case "cover-position": return coverPositionComp;
        case "target-temperature": return targetComp;
        case "climate-hvac-modes": return hvacComp;
        case "toggle": return toggleComp;
        case "fan-speed": return domain === "fan" ? fanSpeedComp : null;
        case "lock-commands": return domain === "lock" ? lockComp : null;
        case "numeric-input": return numericComp;
        case "select-options": return (domain === "select" || domain === "input_select") ? selectComp : null;
        case "media-player-playback": return mp ? playbackComp : null;
        case "media-player-volume-slider": return mp && Ha.supports(st, Ha.MP.VOLUME_SET) ? volumeSliderComp : null;
        case "media-player-volume-buttons": return mp && Ha.supports(st, Ha.MP.VOLUME_STEP) ? volumeButtonsComp : null;
        case "media-player-source": return mp && (attrs.source_list || []).length ? sourceComp : null;
        case "media-player-sound-mode": return mp && (attrs.sound_mode_list || []).length ? soundModeComp : null;
        default: return null;
        }
    }

    function mediaCall(b) {
        Ha.svc(client, "media_player", b.service, entityId, b.data);
    }

    Component {
        id: playbackComp
        RowLayout {
            property var fcfg: ({})
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: {
                    var all = Ha.mediaButtons(card.entityId, card.st, parent.fcfg.controls);
                    return parent.fcfg.hide_disabled_controls ? all.filter(function (b) { return !b.disabled; }) : all;
                }
                delegate: ControlButton {
                    required property var modelData
                    Layout.fillWidth: true
                    client: card.client
                    icon: modelData.icon
                    enabled: !modelData.disabled
                    active: modelData.on === true
                    tint: card.accent
                    onClicked: card.mediaCall(modelData)
                }
            }
        }
    }

    Component {
        id: volumeSliderComp
        RowLayout {
            property var fcfg: ({})
            spacing: Kirigami.Units.smallSpacing
            ControlSlider {
                Layout.fillWidth: true
                enabled: card.st && card.st.state !== "unavailable"
                tint: card.accent
                value: Math.round(Number(card.attrs.volume_level || 0) * 100)
                onValueSet: function (v) { Ha.svc(card.client, "media_player", "volume_set", card.entityId, { volume_level: v / 100 }); }
            }
            ControlButton {
                visible: parent.fcfg.show_mute_button !== false && Ha.supports(card.st, Ha.MP.VOLUME_MUTE)
                client: card.client
                icon: card.attrs.is_volume_muted ? "mdi:volume-off" : "mdi:volume-high"
                active: !!card.attrs.is_volume_muted
                tint: card.accent
                onClicked: Ha.svc(card.client, "media_player", "volume_mute", card.entityId, { is_volume_muted: !card.attrs.is_volume_muted })
            }
        }
    }

    Component {
        id: volumeButtonsComp
        RowLayout {
            property var fcfg: ({})
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: Ha.mediaButtons(card.entityId, card.st,
                                       parent.fcfg.show_mute_button === false ? ["volume_down", "volume_up"]
                                                                              : ["volume_down", "volume_up", "volume_mute"])
                delegate: ControlButton {
                    required property var modelData
                    Layout.fillWidth: true
                    client: card.client
                    icon: modelData.icon
                    enabled: !modelData.disabled
                    active: modelData.on === true
                    tint: card.accent
                    onClicked: card.mediaCall(modelData)
                }
            }
        }
    }

    Component {
        id: sourceComp
        ControlSelect {
            property var fcfg: ({})
            label: Ha.attributeNameDisplay(card.client, card.entityId, "source")
            current: card.attrs.source || ""
            options: fcfg.sources && fcfg.sources.length ? fcfg.sources : (card.attrs.source_list || [])
            enabled: card.st && card.st.state !== "unavailable" && card.st.state !== "off"
            onPicked: function (o) { Ha.svc(card.client, "media_player", "select_source", card.entityId, { source: o }); }
        }
    }

    Component {
        id: soundModeComp
        ControlSelect {
            property var fcfg: ({})
            label: Ha.attributeNameDisplay(card.client, card.entityId, "sound_mode")
            current: card.attrs.sound_mode || ""
            options: fcfg.sound_modes && fcfg.sound_modes.length ? fcfg.sound_modes : (card.attrs.sound_mode_list || [])
            enabled: card.st && card.st.state !== "unavailable" && card.st.state !== "off"
            onPicked: function (o) { Ha.svc(card.client, "media_player", "select_sound_mode", card.entityId, { sound_mode: o }); }
        }
    }

    Component {
        id: selectComp
        ControlSelect {
            property var fcfg: ({})
            current: card.st ? card.st.state : ""
            options: fcfg.options && fcfg.options.length ? fcfg.options : (card.attrs.options || [])
            onPicked: function (o) { Ha.svc(card.client, card.domain, "select_option", card.entityId, { option: o }); }
        }
    }

    Component {
        id: brightnessComp
        ControlSlider {
            from: 1
            to: 100
            tint: card.accent
            value: card.st && card.st.state === "on" && card.attrs.brightness ? Math.round(card.attrs.brightness / 2.55) : 0
            onValueSet: function (v) { Ha.svc(card.client, "light", "turn_on", card.entityId, { brightness_pct: Math.round(v) }); }
        }
    }

    Component {
        id: coverPositionComp
        ControlSlider {
            tint: card.accent
            value: Number(card.attrs.current_position || 0)
            onValueSet: function (v) { Ha.svc(card.client, "cover", "set_cover_position", card.entityId, { position: Math.round(v) }); }
        }
    }

    Component {
        id: fanSpeedComp
        ControlSlider {
            tint: card.accent
            stepSize: Number(card.attrs.percentage_step || 1)
            value: card.st && card.st.state === "on" ? Number(card.attrs.percentage || 0) : 0
            onValueSet: function (v) { Ha.svc(card.client, "fan", "set_percentage", card.entityId, { percentage: Math.round(v) }); }
        }
    }

    Component {
        id: numericComp
        ControlSlider {
            tint: card.accent
            from: Number(card.attrs.min !== undefined ? card.attrs.min : 0)
            to: Number(card.attrs.max !== undefined ? card.attrs.max : 100)
            stepSize: Number(card.attrs.step || 1)
            value: Number(card.st ? card.st.state : 0)
            onValueSet: function (v) { Ha.svc(card.client, card.domain, "set_value", card.entityId, { value: v }); }
        }
    }

    Component {
        id: coverComp
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            ControlButton { Layout.fillWidth: true; client: card.client; icon: "mdi:arrow-up"
                            onClicked: Ha.svc(card.client, "cover", "open_cover", card.entityId) }
            ControlButton { Layout.fillWidth: true; client: card.client; icon: "mdi:stop"
                            onClicked: Ha.svc(card.client, "cover", "stop_cover", card.entityId) }
            ControlButton { Layout.fillWidth: true; client: card.client; icon: "mdi:arrow-down"
                            onClicked: Ha.svc(card.client, "cover", "close_cover", card.entityId) }
        }
    }

    Component {
        id: lockComp
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            ControlButton { Layout.fillWidth: true; client: card.client; icon: "mdi:lock"
                            active: card.st && card.st.state === "locked"; tint: card.accent
                            onClicked: Ha.svc(card.client, "lock", "lock", card.entityId) }
            ControlButton { Layout.fillWidth: true; client: card.client; icon: "mdi:lock-open-variant"
                            active: card.st && card.st.state === "unlocked"; tint: card.accent
                            onClicked: Ha.svc(card.client, "lock", "unlock", card.entityId) }
        }
    }

    Component {
        id: toggleComp
        ControlSwitch {
            client: card.client
            tint: card.accent
            checked: card.st ? card.st.state === "on" : false
            enabled: card.st && card.st.state !== "unavailable"
            onToggled: Ha.toggle(card.client, card.entityId)
        }
    }

    Component {
        id: targetComp
        RowLayout {
            id: tgt
            spacing: Kirigami.Units.smallSpacing
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
            ControlButton { client: card.client; icon: "mdi:minus"; onClicked: tgt.bump(-1) }
            PC3.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: isNaN(tgt.current) ? "—" : Ha.withUnit(Ha.formatNumber(card.client, tgt.current, 1), Ha.temperatureUnit(card.client))
            }
            ControlButton { client: card.client; icon: "mdi:plus"; onClicked: tgt.bump(1) }
        }
    }

    Component {
        id: hvacComp
        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: card.attrs.hvac_modes || []
                ControlButton {
                    required property var modelData
                    Layout.fillWidth: true
                    client: card.client
                    icon: Ha.HVAC_ICONS[modelData] || "mdi:thermostat"
                    active: card.st && card.st.state === modelData
                    tint: card.dash.tint(Ha.activeColor(card.entityId, { state: modelData, attributes: {} }), Kirigami.Theme.highlightColor)
                    onClicked: Ha.svc(card.client, "climate", "set_hvac_mode", card.entityId, { hvac_mode: modelData })
                }
            }
        }
    }
}
