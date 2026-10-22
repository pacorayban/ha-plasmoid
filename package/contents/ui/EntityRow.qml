import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../code/Ha.js" as Ha
import "../code/Tr.js" as Tr

// One entity line, as in HA's entities card: icon, name, and a control
// that depends on the domain (switch, button, slider, list or plain state).
RowLayout {
    id: row

    property var client
    property var dash
    property var conf: ({})
    property bool stateColor: false

    readonly property string entityId: conf && conf.entity ? conf.entity : ""
    readonly property string domain: Ha.domainOf(entityId)
    readonly property var st: {
        client.revision;
        return client.states[entityId];
    }
    readonly property string stamp: st ? st.last_updated + st.state : ""
    readonly property bool unavailable: !st || st.state === "unavailable"
    readonly property var attrs: st && st.attributes ? st.attributes : ({})

    spacing: Kirigami.Units.largeSpacing
    Layout.fillWidth: true
    Layout.minimumHeight: Kirigami.Units.gridUnit * 2

    function secondaryText() {
        if (!st || !conf.secondary_info)
            return "";
        switch (conf.secondary_info) {
        case "last-changed": return Ha.relativeTime(row.client, st.last_changed);
        case "last-updated": return Ha.relativeTime(row.client, st.last_updated);
        case "entity-id": return entityId;
        case "brightness": return attrs.brightness ? Math.round(attrs.brightness / 2.55) + " %" : "";
        case "position": return attrs.current_position !== undefined ? attrs.current_position + " %" : "";
        case "tilt-position": return attrs.current_tilt_position !== undefined ? attrs.current_tilt_position + " %" : "";
        default: return "";
        }
    }

    function controlFor() {
        if (unavailable)
            return stateComp;
        if (Ha.hasSwitch(entityId) && domain !== "group")
            return switchComp;
        if (domain === "group" && (st.state === "on" || st.state === "off"))
            return switchComp;
        switch (domain) {
        case "button": case "input_button": case "scene": case "script":
            return buttonComp;
        case "cover":
            return coverComp;
        case "lock":
            return lockComp;
        case "input_number": case "number":
            return attrs.mode === "box" ? stateComp : sliderComp;
        case "input_select": case "select":
            return selectComp;
        default:
            return stateComp;
        }
    }

    HaIcon {
        client: row.client
        icon: Ha.entityIcon(row.client, row.entityId, row.st, row.conf.icon)
        size: Kirigami.Units.iconSizes.smallMedium
        color: row.dash.tint(row.stateColor || row.domain === "light"
                             ? Ha.activeColor(row.entityId, row.st) : "", row.dash.iconColor)
        Layout.alignment: Qt.AlignVCenter
        TapHandler { onTapped: row.dash.moreInfo(row.entityId) }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        PC3.Label {
            Layout.fillWidth: true
            text: Ha.entityName(row.client, row.entityId, row.st, row.conf.name)
            elide: Text.ElideRight
        }
        PC3.Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: row.secondaryText()
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            elide: Text.ElideRight
        }
        TapHandler { onTapped: row.dash.moreInfo(row.entityId) }
    }

    Loader {
        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        Layout.maximumWidth: row.width * 0.6
        sourceComponent: row.controlFor()
    }

    Component {
        id: stateComp
        PC3.Label {
            text: Ha.stateDisplay(row.client, row.entityId, row.st)
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            opacity: row.unavailable ? 0.6 : 1
        }
    }

    Component {
        id: switchComp
        PC3.Switch {
            id: sw
            readonly property bool isOn: row.st ? row.st.state === "on" : false
            checked: isOn
            onToggled: {
                Ha.toggle(row.client, row.entityId);
                restore.restart();
            }
            function rebind() { checked = Qt.binding(function () { return sw.isOn; }); }
            Timer { id: restore; interval: 3000; onTriggered: sw.rebind() }
            Connections {
                target: row
                function onStampChanged() { sw.rebind(); }
            }
        }
    }

    Component {
        id: buttonComp
        PC3.Button {
            text: row.domain === "scene" ? Tr.tr(row.client, "Activate")
                  : row.domain === "script" ? (row.st && row.st.state === "on" ? Tr.tr(row.client, "Stop") : Tr.tr(row.client, "Run"))
                  : Tr.tr(row.client, "Press")
            onClicked: Ha.toggle(row.client, row.entityId)
        }
    }

    Component {
        id: lockComp
        PC3.Button {
            text: row.st && row.st.state === "locked" ? Tr.tr(row.client, "Unlock") : Tr.tr(row.client, "Lock")
            onClicked: Ha.toggle(row.client, row.entityId)
        }
    }

    Component {
        id: coverComp
        RowLayout {
            spacing: 0
            readonly property int pos: row.attrs.current_position !== undefined ? row.attrs.current_position : -1
            PC3.ToolButton {
                icon.name: "arrow-up"
                enabled: (row.st.state !== "opening" && row.st.state !== "open")
                         || (parent.pos >= 0 && parent.pos < 100)
                onClicked: Ha.svc(row.client, "cover", "open_cover", row.entityId)
            }
            PC3.ToolButton {
                icon.name: "media-playback-stop"
                onClicked: Ha.svc(row.client, "cover", "stop_cover", row.entityId)
            }
            PC3.ToolButton {
                icon.name: "arrow-down"
                enabled: row.st && row.st.state !== "closing" && row.st.state !== "closed"
                onClicked: Ha.svc(row.client, "cover", "close_cover", row.entityId)
            }
        }
    }

    Component {
        id: sliderComp
        RowLayout {
            PC3.Slider {
                id: slider
                Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                from: Number(row.attrs.min !== undefined ? row.attrs.min : 0)
                to: Number(row.attrs.max !== undefined ? row.attrs.max : 100)
                stepSize: Number(row.attrs.step || 1)
                value: Number(row.st ? row.st.state : 0)
                onMoved: sendTimer.restart()
                Timer {
                    id: sendTimer
                    interval: 400
                    onTriggered: Ha.svc(row.client, row.domain, "set_value", row.entityId, { value: slider.value })
                }
            }
            PC3.Label {
                text: Ha.withUnit(Ha.formatNumber(row.client, slider.value, -1), row.attrs.unit_of_measurement)
            }
        }
    }

    Component {
        id: selectComp
        // Wrapped so the Loader never resizes the ComboBox itself (Plasma's ComboBox
        // derives its implicit size from its own size and would loop).
        Item {
            implicitWidth: combo.width
            implicitHeight: combo.height
            PC3.ComboBox {
                id: combo
                width: Kirigami.Units.gridUnit * 8
                model: row.attrs.options || []
                currentIndex: (row.attrs.options || []).indexOf(row.st ? row.st.state : "")
                onActivated: function (index) {
                    Ha.svc(row.client, row.domain, "select_option", row.entityId, { option: model[index] });
                }
            }
        }
    }
}
