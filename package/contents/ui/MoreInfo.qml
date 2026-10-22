import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../code/Ha.js" as Ha
import "../code/Tr.js" as Tr

// Detail popup for one entity (HA's "more-info" dialog, simplified):
// a control card when it makes sense, then the attributes.
QQC2.Popup {
    id: pop

    property var client
    property var dash
    property string entityId: ""

    readonly property var st: { client.revision; return entityId ? client.states[entityId] : undefined; }
    readonly property string domain: Ha.domainOf(entityId)

    readonly property var hiddenAttributes: ["friendly_name", "icon", "entity_picture", "entity_picture_local",
        "supported_features", "supported_color_modes", "color_mode", "unit_of_measurement", "device_class",
        "state_class", "entity_id", "hidden", "assumed_state", "editable", "id", "restored", "options",
        "min", "max", "step", "mode", "hvac_modes", "fan_modes", "preset_modes", "swing_modes",
        "effect_list", "min_mireds", "max_mireds", "min_color_temp_kelvin", "max_color_temp_kelvin",
        "access_token", "forecast", "xy_color", "hs_color", "rgbw_color", "rgbww_color", "source_list",
        "sound_mode_list", "media_content_id", "frontend_stream_type", "target_temp_step", "min_temp",
        "max_temp", "min_humidity", "max_humidity", "available_modes", "icon_color", "event_types"]

    readonly property var attributeKeys: {
        if (!st || !st.attributes)
            return [];
        var hidden = hiddenAttributes;
        return Object.keys(st.attributes).filter(function (k) { return hidden.indexOf(k) < 0; });
    }

    readonly property var cardConfig: {
        if (!entityId)
            return null;
        switch (domain) {
        case "climate": return { type: "thermostat", entity: entityId };
        case "light": return { type: "light", entity: entityId };
        case "media_player": return { type: "media-control", entity: entityId };
        case "weather": return { type: "weather-forecast", entity: entityId };
        case "camera": case "image": return { type: "picture-entity", entity: entityId, show_name: false, show_state: false };
        case "cover": return { type: "tile", entity: entityId, features: [{ type: "cover-open-close" }] };
        case "sensor": case "binary_sensor": case "number": case "input_number": case "counter":
        case "person": case "device_tracker": case "switch": case "input_boolean": case "lock":
        case "fan": case "automation":
            return { type: "history-graph", entities: [entityId], hours_to_show: 24 };
        default:
            return null;
        }
    }
    readonly property bool rowControl: ["input_number", "number", "input_select", "select", "button",
                                        "input_button", "scene", "script", "lock"].indexOf(domain) >= 0

    function openFor(id) {
        entityId = id;
        open();
    }

    function formatValue(v) {
        if (v === null || v === undefined)
            return "—";
        if (Array.isArray(v))
            return v.map(function (x) { return typeof x === "object" ? JSON.stringify(x) : String(x); }).join(", ");
        if (typeof v === "object")
            return JSON.stringify(v);
        if (typeof v === "boolean")
            return v ? Tr.tr(client, "Yes") : Tr.tr(client, "No");
        if (Ha.isNumeric(v))
            return Ha.formatNumber(client, v, -1);
        return String(v);
    }

    modal: true
    focus: true
    closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside
    width: Math.min(parent.width - Kirigami.Units.gridUnit, Kirigami.Units.gridUnit * 24)
    height: Math.min(parent.height - Kirigami.Units.gridUnit,
                     content.implicitHeight + topPadding + bottomPadding + Kirigami.Units.largeSpacing)
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    padding: Kirigami.Units.largeSpacing

    background: Rectangle {
        Kirigami.Theme.colorSet: Kirigami.Theme.View
        Kirigami.Theme.inherit: false
        color: Kirigami.Theme.backgroundColor
        radius: Math.round(Kirigami.Units.gridUnit * 0.7)
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
    }

    contentItem: PC3.ScrollView {
        id: scroll
        contentWidth: availableWidth
        PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff

        ColumnLayout {
            id: content
            width: scroll.availableWidth
            spacing: Kirigami.Units.largeSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                HaIcon {
                    client: pop.client
                    icon: Ha.entityIcon(pop.client, pop.entityId, pop.st)
                    size: Kirigami.Units.iconSizes.medium
                    color: pop.dash.tint(Ha.activeColor(pop.entityId, pop.st), pop.dash.iconColor)
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Kirigami.Heading {
                        Layout.fillWidth: true
                        level: 3
                        text: Ha.entityName(pop.client, pop.entityId, pop.st)
                        wrapMode: Text.Wrap
                    }
                    PC3.Label {
                        Layout.fillWidth: true
                        text: Ha.stateDisplay(pop.client, pop.entityId, pop.st)
                              + (pop.st ? " · " + Ha.relativeTime(pop.client, pop.st.last_changed) : "")
                        opacity: 0.75
                        wrapMode: Text.Wrap
                    }
                }
                PC3.Switch {
                    visible: Ha.hasSwitch(pop.entityId) && pop.st && (pop.st.state === "on" || pop.st.state === "off")
                    checked: pop.st ? pop.st.state === "on" : false
                    onToggled: Ha.toggle(pop.client, pop.entityId)
                }
                PC3.ToolButton {
                    icon.name: "window-close"
                    onClicked: pop.close()
                }
            }

            CardLoader {
                Layout.fillWidth: true
                config: pop.opened ? pop.cardConfig : null
                client: pop.client
                dash: pop.dash
            }

            Loader {
                Layout.fillWidth: true
                active: pop.opened && pop.rowControl
                visible: active
                sourceComponent: Component {
                    EntityRow {
                        client: pop.client
                        dash: pop.dash
                        conf: ({ entity: pop.entityId })
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
                visible: pop.attributeKeys.length > 0
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.smallSpacing
                visible: pop.attributeKeys.length > 0

                Repeater {
                    model: pop.attributeKeys.length * 2
                    delegate: PC3.Label {
                        required property int index
                        readonly property string key: pop.attributeKeys[Math.floor(index / 2)] || ""
                        Layout.fillWidth: index % 2 === 1
                        Layout.alignment: Qt.AlignTop
                        text: index % 2 === 0
                              ? Ha.attributeNameDisplay(pop.client, pop.entityId, key)
                              : (pop.st ? Ha.attributeValueDisplay(pop.client, pop.entityId, key, pop.formatValue(pop.st.attributes[key])) : "")
                        opacity: index % 2 === 0 ? 0.7 : 1
                        wrapMode: Text.Wrap
                        font: Kirigami.Theme.smallFont
                    }
                }
            }

            PC3.Button {
                Layout.alignment: Qt.AlignRight
                text: Tr.tr(pop.client, "Open in Home Assistant")
                icon.name: "internet-web-browser"
                onClicked: {
                    pop.dash.openUrl("/history?entity_id=" + pop.entityId);
                    pop.close();
                }
            }
        }
    }
}
