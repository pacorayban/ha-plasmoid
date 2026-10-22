import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha

// HA "entities" card (and "entity-filter").
CardFrame {
    id: card

    implicitHeight: col.implicitHeight + 2 * padding

    function matchesFilter(id) {
        var filters = config.state_filter || [];
        if (filters.length === 0)
            return true;
        var st = client.states[id];
        if (!st)
            return false;
        for (var i = 0; i < filters.length; i++) {
            var f = filters[i];
            var value = (typeof f === "object") ? f.value : f;
            var op = (typeof f === "object" && f.operator) ? f.operator : "==";
            var s = st.state;
            var ok = false;
            switch (op) {
            case "==": ok = String(s) === String(value); break;
            case "!=": ok = String(s) !== String(value); break;
            case ">": ok = Number(s) > Number(value); break;
            case ">=": ok = Number(s) >= Number(value); break;
            case "<": ok = Number(s) < Number(value); break;
            case "<=": ok = Number(s) <= Number(value); break;
            case "in": ok = (value || []).map(String).indexOf(String(s)) >= 0; break;
            case "not in": ok = (value || []).map(String).indexOf(String(s)) < 0; break;
            case "regex": ok = new RegExp(value).test(String(s)); break;
            default: ok = String(s) === String(value);
            }
            if (ok)
                return true;
        }
        return false;
    }

    readonly property var rows: {
        var list = (config.entities || []).map(Ha.entityConf).filter(function (e) { return !!e; });
        if (config.type === "entity-filter") {
            client.revision;
            list = list.filter(function (e) { return !e.entity || card.matchesFilter(e.entity); });
        }
        return list;
    }
    readonly property var switchable: rows.filter(function (r) {
        return r.entity && !r.type && Ha.hasSwitch(r.entity);
    }).map(function (r) { return r.entity; })
    readonly property bool anyOn: {
        client.revision;
        return switchable.some(function (id) { return client.states[id] && client.states[id].state === "on"; });
    }
    readonly property bool stateColor: config.state_color === true

    visible: config.type !== "entity-filter" || rows.length > 0 || config.show_empty === true

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.padding
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            visible: !!card.config.title || headerSwitch.visible
            spacing: Kirigami.Units.smallSpacing

            HaIcon {
                visible: !!card.config.icon
                client: card.client
                icon: card.config.icon || ""
            }
            Kirigami.Heading {
                Layout.fillWidth: true
                level: 4
                text: card.config.title || ""
                elide: Text.ElideRight
            }
            PC3.Switch {
                id: headerSwitch
                visible: card.config.show_header_toggle !== false && card.switchable.length >= 2
                checked: card.anyOn
                onToggled: {
                    card.client.callService("homeassistant", card.anyOn ? "turn_off" : "turn_on", {},
                                            { entity_id: card.switchable });
                    checked = Qt.binding(function () { return card.anyOn; });
                }
            }
        }

        Repeater {
            model: card.rows

            delegate: ColumnLayout {
                id: del
                required property var modelData
                readonly property var rc: modelData
                readonly property string rtype: rc.type ? String(rc.type) : (rc.entity ? "entity" : "")
                Layout.fillWidth: true
                spacing: 0

                Loader {
                    Layout.fillWidth: true
                    active: del.rtype === "entity" || (del.rtype !== "" && !["section", "divider", "attribute", "weblink", "button", "call-service", "text", "buttons"].includes(del.rtype) && !!del.rc.entity)
                    visible: active
                    sourceComponent: Component {
                        EntityRow {
                            client: card.client
                            dash: card.dash
                            conf: del.rc
                            stateColor: del.rc.state_color !== undefined ? del.rc.state_color : card.stateColor
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: del.rtype === "section"
                    visible: active
                    sourceComponent: Component {
                        ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }
                            Kirigami.Heading {
                                visible: !!del.rc.label
                                level: 5
                                text: del.rc.label || ""
                                opacity: 0.8
                            }
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: del.rtype === "divider"
                    visible: active
                    sourceComponent: Component {
                        Kirigami.Separator {
                            Layout.topMargin: Kirigami.Units.smallSpacing
                            Layout.bottomMargin: Kirigami.Units.smallSpacing
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: del.rtype === "attribute" || del.rtype === "text"
                    visible: active
                    sourceComponent: Component {
                        RowLayout {
                            readonly property var st: { card.client.revision; return card.client.states[del.rc.entity]; }
                            spacing: Kirigami.Units.largeSpacing
                            Layout.minimumHeight: Kirigami.Units.gridUnit * 2
                            HaIcon {
                                client: card.client
                                icon: Ha.entityIcon(card.client, del.rc.entity || "", parent.st, del.rc.icon)
                                color: card.dash.iconColor
                            }
                            PC3.Label {
                                Layout.fillWidth: true
                                text: del.rtype === "text" ? (del.rc.name || "")
                                      : Ha.entityName(card.client, del.rc.entity, parent.st, del.rc.name)
                                elide: Text.ElideRight
                            }
                            PC3.Label {
                                text: {
                                    if (del.rtype === "text")
                                        return del.rc.text || "";
                                    var v = parent.st && parent.st.attributes ? parent.st.attributes[del.rc.attribute] : undefined;
                                    var shown = Ha.isNumeric(v) ? Ha.formatNumber(card.client, v, -1)
                                              : Ha.attributeValueDisplay(card.client, del.rc.entity, del.rc.attribute, v);
                                    return (del.rc.prefix || "") + shown + (del.rc.suffix || "");
                                }
                            }
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: del.rtype === "weblink" || del.rtype === "button" || del.rtype === "call-service"
                    visible: active
                    sourceComponent: Component {
                        RowLayout {
                            spacing: Kirigami.Units.largeSpacing
                            Layout.minimumHeight: Kirigami.Units.gridUnit * 2
                            HaIcon {
                                client: card.client
                                icon: del.rc.icon || (del.rtype === "weblink" ? "mdi:link" : "mdi:gesture-tap-button")
                                color: card.dash.iconColor
                            }
                            PC3.Label {
                                Layout.fillWidth: true
                                text: del.rc.name || del.rc.url || ""
                                elide: Text.ElideRight
                            }
                            PC3.Button {
                                text: del.rtype === "weblink" ? "Ouvrir" : (del.rc.action_name || "Exécuter")
                                onClicked: {
                                    if (del.rtype === "weblink")
                                        card.dash.openUrl(del.rc.url);
                                    else if (del.rc.tap_action)
                                        Ha.runAction(card.client, card.dash, del.rc.tap_action, del.rc.entity, "none");
                                    else
                                        Ha.runAction(card.client, card.dash, { action: "perform-action", perform_action: del.rc.action || del.rc.service, data: del.rc.data || del.rc.service_data }, null, "none");
                                }
                            }
                        }
                    }
                }
            }
        }

        // Footer of scene / script buttons (as generated by the default overview).
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: !!card.config.footer && card.config.footer.type === "buttons"
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: card.config.footer && card.config.footer.entities ? card.config.footer.entities.map(Ha.entityConf) : []
                delegate: PC3.ToolButton {
                    required property var modelData
                    readonly property var st: { card.client.revision; return card.client.states[modelData.entity]; }
                    text: Ha.entityName(card.client, modelData.entity, st, modelData.name)
                    onClicked: Ha.runAction(card.client, card.dash, modelData.tap_action, modelData.entity, "toggle")
                    contentItem: Row {
                        spacing: Kirigami.Units.smallSpacing
                        HaIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            client: card.client
                            icon: Ha.entityIcon(card.client, modelData.entity, st, modelData.icon)
                            color: card.dash.iconColor
                        }
                        PC3.Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.parent.text
                        }
                    }
                }
            }
        }
    }
}
