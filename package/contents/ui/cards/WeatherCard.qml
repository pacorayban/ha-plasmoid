import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha
import "../../code/Tr.js" as Tr

// HA "weather-forecast" card: current conditions and a few forecast slots.
CardFrame {
    id: card

    readonly property string entityId: config.entity || ""
    readonly property var st: { client.revision; return client.states[entityId]; }
    readonly property var attrs: st && st.attributes ? st.attributes : ({})
    readonly property string tempUnit: attrs.temperature_unit || Ha.temperatureUnit(client)
    readonly property bool showForecast: config.show_forecast !== false
    readonly property bool showCurrent: config.show_current !== false
    readonly property string forecastType: {
        if (config.forecast_type)
            return config.forecast_type;
        if (Ha.supports(st, 1)) return "daily";
        if (Ha.supports(st, 4)) return "twice_daily";
        if (Ha.supports(st, 2)) return "hourly";
        return "daily";
    }
    property var forecast: []
    property var _token: null

    implicitHeight: col.implicitHeight + 2 * padding

    function subscribe() {
        unsubscribe();
        if (!showForecast || !client.ready || !entityId)
            return;
        var token = { alive: true, id: null };
        var cl = client;
        _token = token;
        cl.subscribe({ type: "weather/subscribe_forecast", entity_id: entityId, forecast_type: forecastType },
                         function (ev) {
                             if (token.alive)
                                 card.forecast = (ev && ev.forecast) ? ev.forecast : [];
                         }).then(function (id) {
            token.id = id;
            if (!token.alive)
                cl.unsubscribe(id);
        }, function (e) {
            // Older integrations still expose the forecast as an attribute.
            if (token.alive)
                card.forecast = card.attrs.forecast || [];
        });
    }

    function unsubscribe() {
        if (_token) {
            _token.alive = false;
            if (_token.id)
                client.unsubscribe(_token.id);
        }
        _token = null;
    }

    function slotLabel(item) {
        var d = new Date(item.datetime);
        if (isNaN(d.getTime()))
            return "";
        if (forecastType === "hourly")
            return Qt.formatTime(d, "HH:mm");
        var day = d.toLocaleDateString(client.locale, "ddd");
        if (forecastType === "twice_daily")
            return day + (item.is_daytime === false ? Tr.tr(client, " (night)") : "");
        return day;
    }

    function temp(v) {
        return (v === undefined || v === null) ? "" : Ha.formatNumber(client, v, 0) + "°";
    }

    Component.onCompleted: subscribe()
    Component.onDestruction: unsubscribe()
    onForecastTypeChanged: subscribe()
    Connections {
        target: card.client
        function onConnectionIdChanged() { card.subscribe(); }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Ha.runAction(card.client, card.dash, card.config.tap_action, card.entityId, "more-info")
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.padding
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            visible: card.showCurrent
            spacing: Kirigami.Units.largeSpacing

            HaIcon {
                client: card.client
                icon: card.st ? (Ha.WEATHER_ICONS[card.st.state] || Ha.entityIcon(card.client, card.entityId, card.st)) : "mdi:weather-cloudy-alert"
                size: Kirigami.Units.gridUnit * 3
                color: Kirigami.Theme.textColor
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PC3.Label {
                    Layout.fillWidth: true
                    text: Ha.stateDisplay(card.client, card.entityId, card.st)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                PC3.Label {
                    Layout.fillWidth: true
                    text: Ha.entityName(card.client, card.entityId, card.st, card.config.name)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    elide: Text.ElideRight
                }
            }
            ColumnLayout {
                spacing: 0
                PC3.Label {
                    Layout.alignment: Qt.AlignRight
                    text: card.attrs.temperature !== undefined
                          ? Ha.withUnit(Ha.formatNumber(card.client, card.attrs.temperature, 1), card.tempUnit) : ""
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.8
                }
                PC3.Label {
                    Layout.alignment: Qt.AlignRight
                    visible: text !== ""
                    text: {
                        var parts = [];
                        if (card.attrs.humidity !== undefined)
                            parts.push(Ha.formatNumber(card.client, card.attrs.humidity, 0) + " %");
                        if (card.attrs.wind_speed !== undefined)
                            parts.push(Ha.withUnit(Ha.formatNumber(card.client, card.attrs.wind_speed, 0), card.attrs.wind_speed_unit || ""));
                        return parts.join(" · ");
                    }
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: card.showForecast && card.forecast.length > 0
            spacing: 0

            Repeater {
                model: card.forecast.slice(0, Math.max(1, Math.min(7, Math.floor(col.width / (Kirigami.Units.gridUnit * 3.2)))))
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: 2
                    PC3.Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: card.slotLabel(modelData)
                        font: Kirigami.Theme.smallFont
                        opacity: 0.8
                    }
                    HaIcon {
                        Layout.alignment: Qt.AlignHCenter
                        client: card.client
                        icon: Ha.WEATHER_ICONS[modelData.condition] || "mdi:weather-cloudy"
                        color: Kirigami.Theme.textColor
                    }
                    PC3.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: card.temp(modelData.temperature)
                        font: Kirigami.Theme.smallFont
                    }
                    PC3.Label {
                        Layout.alignment: Qt.AlignHCenter
                        visible: modelData.templow !== undefined && modelData.templow !== null
                        text: card.temp(modelData.templow)
                        font: Kirigami.Theme.smallFont
                        opacity: 0.6
                    }
                }
            }
        }
    }
}
