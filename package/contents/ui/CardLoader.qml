import QtQuick
import "../code/Ha.js" as Ha

// Picks the QML file for a Lovelace card config and handles
// `conditional` cards and `visibility` conditions.
Loader {
    id: loader

    property var config
    property var client
    property var dash

    property var _loaded: undefined
    readonly property bool _conditional: !!config && (config.type === "conditional" || !!config.visibility)

    readonly property var _map: ({
        "entities": "EntitiesCard", "entity-filter": "EntitiesCard",
        "tile": "TileCard", "button": "ButtonCard", "glance": "GlanceCard",
        "sensor": "SensorCard", "entity": "SensorCard", "gauge": "GaugeCard",
        "thermostat": "ThermostatCard", "light": "LightCard", "markdown": "MarkdownCard",
        "weather-forecast": "WeatherCard", "media-control": "MediaControlCard",
        "vertical-stack": "StackCard", "horizontal-stack": "StackCard", "grid": "StackCard",
        "heading": "HeadingCard", "picture": "PictureCard", "picture-entity": "PictureCard",
        "picture-glance": "PictureCard", "history-graph": "HistoryGraphCard",
        "statistics-graph": "HistoryGraphCard", "area": "AreaCard"
    })
    readonly property var _unsupported: ["map", "logbook", "calendar", "iframe", "todo-list",
                                         "shopping-list", "energy-date-selection", "empty-state",
                                         "starting", "recovery-mode"]

    function fileFor(cfg) {
        var t = String(cfg.type || "");
        if (_map[t])
            return _map[t];
        if (_unsupported.indexOf(t) >= 0 || t.indexOf("energy-") === 0)
            return "UnsupportedCard";
        // Unknown and custom:* cards: draw something sensible from their options.
        if (cfg.entity)
            return "TileCard";
        if (cfg.entities)
            return "EntitiesCard";
        if (cfg.cards)
            return "StackCard";
        if (cfg.title || cfg.heading)
            return "HeadingCard";
        return "UnsupportedCard";
    }

    function effectiveConfig() {
        if (!config || !client)
            return null;
        if (config.visibility && !Ha.checkConditions(client, config.visibility))
            return null;
        if (config.type === "conditional")
            return Ha.checkConditions(client, config.conditions) ? (config.card || null) : null;
        return config;
    }

    function sync() {
        var eff = effectiveConfig();
        if (eff === _loaded)
            return;
        _loaded = eff;
        if (!eff) {
            setSource("");
            visible = false;
            return;
        }
        visible = true;
        setSource(Qt.resolvedUrl("cards/" + fileFor(eff) + ".qml"),
                  { config: eff, client: client, dash: dash });
    }

    onConfigChanged: sync()
    Component.onCompleted: sync()

    Connections {
        target: loader._conditional ? loader.client : null
        function onRevisionChanged() { loader.sync(); }
    }

    onStatusChanged: {
        if (status === Loader.Error)
            console.warn("HA card failed to load: " + JSON.stringify(_loaded));
    }
}
