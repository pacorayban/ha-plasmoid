.pragma library
.import "Tr.js" as Tr

// Shared helpers: names, states, icons, colors, actions and conditions.
// Every function takes the HaClient as first argument when it needs data.

var SWITCH_DOMAINS = ["automation", "fan", "group", "humidifier", "input_boolean",
                      "light", "remote", "siren", "switch"];

var TAP_TOGGLE_DOMAINS = SWITCH_DOMAINS.concat(["cover", "lock", "valve", "scene", "script",
                                                 "button", "input_button", "media_player",
                                                 "vacuum", "climate"]);

var COLORS = {
    amber: "#ffc107", orange: "#ff9800", deepOrange: "#ff6f22", red: "#f44336",
    blue: "#2196f3", lightBlue: "#03a9f4", cyan: "#00bcd4", teal: "#009688",
    green: "#4caf50", purple: "#926bc7", indigo: "#3f51b5", brown: "#a1887f",
    grey: "#9e9e9e"
};

var FALLBACK_ICONS = {
    alarm_control_panel: "mdi:shield", automation: "mdi:robot", binary_sensor: "mdi:radiobox-blank",
    button: "mdi:button-pointer", calendar: "mdi:calendar", camera: "mdi:video",
    climate: "mdi:thermostat", counter: "mdi:counter", cover: "mdi:window-shutter",
    device_tracker: "mdi:account", fan: "mdi:fan", group: "mdi:google-circles-communities",
    humidifier: "mdi:air-humidifier", image: "mdi:image", input_boolean: "mdi:toggle-switch",
    input_button: "mdi:button-pointer", input_datetime: "mdi:calendar-clock",
    input_number: "mdi:ray-vertex", input_select: "mdi:format-list-bulleted",
    input_text: "mdi:form-textbox", light: "mdi:lightbulb", lock: "mdi:lock",
    media_player: "mdi:cast", number: "mdi:ray-vertex", person: "mdi:account",
    remote: "mdi:remote", scene: "mdi:palette", script: "mdi:script-text",
    select: "mdi:format-list-bulleted", sensor: "mdi:eye", siren: "mdi:bullhorn",
    sun: "mdi:white-balance-sunny", switch: "mdi:toggle-switch-variant", text: "mdi:form-textbox",
    timer: "mdi:timer-outline", todo: "mdi:clipboard-list", update: "mdi:package-up",
    vacuum: "mdi:robot-vacuum", valve: "mdi:pipe-valve", water_heater: "mdi:thermometer",
    weather: "mdi:weather-partly-cloudy", zone: "mdi:map-marker-radius"
};

var WEATHER_ICONS = {
    "clear-night": "mdi:weather-night", "cloudy": "mdi:weather-cloudy",
    "exceptional": "mdi:alert-circle-outline", "fog": "mdi:weather-fog",
    "hail": "mdi:weather-hail", "lightning": "mdi:weather-lightning",
    "lightning-rainy": "mdi:weather-lightning-rainy", "partlycloudy": "mdi:weather-partly-cloudy",
    "pouring": "mdi:weather-pouring", "rainy": "mdi:weather-rainy", "snowy": "mdi:weather-snowy",
    "snowy-rainy": "mdi:weather-snowy-rainy", "sunny": "mdi:weather-sunny",
    "windy": "mdi:weather-windy", "windy-variant": "mdi:weather-windy-variant"
};

var HVAC_ICONS = {
    off: "mdi:power", heat: "mdi:fire", cool: "mdi:snowflake", heat_cool: "mdi:sun-snowflake-variant",
    auto: "mdi:thermostat-auto", dry: "mdi:water-percent", fan_only: "mdi:fan"
};

// ---------------------------------------------------------------- basics

function domainOf(entityId) {
    return entityId ? String(entityId).split(".")[0] : "";
}

function dig(obj) {
    for (var i = 1; i < arguments.length; i++) {
        if (obj === null || obj === undefined)
            return undefined;
        obj = obj[arguments[i]];
    }
    return obj;
}

function entityConf(e) {
    if (e === null || e === undefined)
        return null;
    return typeof e === "string" ? { entity: e } : e;
}

function isUnavailable(st) {
    return !st || st.state === "unavailable" || st.state === "unknown";
}

function isNumeric(v) {
    return v !== null && v !== "" && !isNaN(Number(v)) && isFinite(Number(v));
}

function hasSwitch(entityId) {
    return SWITCH_DOMAINS.indexOf(domainOf(entityId)) >= 0;
}

function isTapToggleable(entityId) {
    return TAP_TOGGLE_DOMAINS.indexOf(domainOf(entityId)) >= 0;
}

// Same idea as HA's stateActive(): is the entity "doing something"?
function isActive(entityId, st) {
    if (isUnavailable(st))
        return false;
    var s = st.state;
    switch (domainOf(entityId)) {
    case "cover": case "valve": return s !== "closed";
    case "lock": return s !== "locked";
    case "media_player": return s !== "standby" && s !== "off";
    case "vacuum": return s !== "docked";
    case "person": case "device_tracker": return s !== "not_home";
    case "alarm_control_panel": return s !== "disarmed";
    case "climate": case "water_heater": return s !== "off";
    case "timer": return s === "active";
    case "plant": return s === "problem";
    case "sun": return s === "above_horizon";
    case "sensor": case "number": case "input_number": case "weather": case "counter":
    case "input_text": case "text": case "input_select": case "select": case "input_datetime":
    case "button": case "input_button": case "scene": case "event": case "zone":
        return true;
    default: return s === "on";
    }
}

// ---------------------------------------------------------------- names

function entityName(client, entityId, st, cfgName) {
    if (typeof cfgName === "string" && cfgName !== "")
        return cfgName;
    if (st && st.attributes && st.attributes.friendly_name) {
        var full = String(st.attributes.friendly_name);
        if (cfgName && typeof cfgName === "object" && cfgName.type === "entity") {
            var reg0 = client.entities[entityId];
            var dev = reg0 && reg0.device_id ? client.devices[reg0.device_id] : null;
            var dn = dev ? String(dev.name_by_user || dev.name || "") : "";
            if (dn && full.length > dn.length && full.indexOf(dn) === 0) {
                var rest = full.substring(dn.length).replace(/^[\s:\-–]+/, "");
                if (rest)
                    return rest.charAt(0).toUpperCase() + rest.slice(1);
            }
        }
        return full;
    }
    var reg = client.entities[entityId];
    if (reg && reg.name)
        return reg.name;
    if (!entityId)
        return "";
    var part = String(entityId).split(".")[1] || entityId;
    return part.replace(/_/g, " ");
}

function domainTitle(client, domain) {
    return client.translations["component." + domain + ".title"] || domain.replace(/_/g, " ");
}

// ---------------------------------------------------------------- states

function relativeTime(client, iso) {
    var t = Date.parse(iso);
    if (isNaN(t))
        return String(iso);
    var diff = (Date.now() - t) / 1000;
    var future = diff < 0;
    diff = Math.abs(diff);
    if (diff < 45)
        return Tr.tr(client, future ? "in a few seconds" : "a few seconds ago");
    if (diff < 3600)
        return Tr.tr(client, future ? "in %1 min" : "%1 min ago", Math.round(diff / 60));
    if (diff < 86400)
        return Tr.tr(client, future ? "in %1 h" : "%1 h ago", Math.round(diff / 3600));
    var d = Math.round(diff / 86400);
    return future ? Tr.trp(client, d, "in %1 day", "in %1 days") : Tr.trp(client, d, "%1 day ago", "%1 days ago");
}

function displayPrecision(client, entityId) {
    var reg = client.entities[entityId];
    var p = dig(reg, "options", "sensor", "display_precision");
    if (p === undefined || p === null)
        p = dig(reg, "options", "sensor", "suggested_display_precision");
    return (p === undefined || p === null) ? -1 : p;
}

function formatNumber(client, value, precision) {
    var n = Number(value);
    var prec = precision;
    if (prec === undefined || prec === null || prec < 0) {
        var parts = String(value).split(".");
        prec = parts.length > 1 ? Math.min(parts[1].length, 2) : 0;
    }
    try {
        return n.toLocaleString(client.locale, "f", prec);
    } catch (e) {
        return n.toFixed(prec);
    }
}

function withUnit(text, unit) {
    if (unit === undefined || unit === null || unit === "")
        return text;
    return text + " " + unit;
}

function stateTranslation(client, entityId, st, s) {
    var d = domainOf(entityId);
    var reg = client.entities[entityId];
    var a = (st && st.attributes) || {};
    var t;
    if (reg && reg.translation_key && reg.platform) {
        t = client.translations["component." + reg.platform + ".entity." + d + "." + reg.translation_key + ".state." + s];
        if (t) return t;
    }
    if (a.device_class) {
        t = client.translations["component." + d + ".entity_component." + a.device_class + ".state." + s];
        if (t) return t;
    }
    t = client.translations["component." + d + ".entity_component._.state." + s];
    return t || null;
}

function attributeValueDisplay(client, entityId, attribute, value) {
    if (value === undefined || value === null)
        return "";
    var d = domainOf(entityId);
    var t = client.translations["component." + d + ".entity_component._.state_attributes." + attribute + ".state." + value];
    return t || String(value);
}

function attributeNameDisplay(client, entityId, attribute) {
    var d = domainOf(entityId);
    var t = client.translations["component." + d + ".entity_component._.state_attributes." + attribute + ".name"];
    if (t) return t;
    var s = String(attribute).replace(/_/g, " ");
    return s.charAt(0).toUpperCase() + s.slice(1);
}

function stateDisplay(client, entityId, st) {
    if (!st)
        return Tr.tr(client, "Not found");
    var s = st.state;
    if (s === "unavailable") return Tr.tr(client, "Unavailable");
    if (s === "unknown") return Tr.tr(client, "Unknown");
    var d = domainOf(entityId);
    var a = st.attributes || {};

    if (a.device_class === "timestamp" || d === "button" || d === "input_button"
            || d === "scene" || d === "event" || d === "conversation")
        return relativeTime(client, s);

    if (isNumeric(s) && (a.unit_of_measurement !== undefined || a.state_class !== undefined
            || d === "sensor" || d === "number" || d === "input_number" || d === "counter")) {
        return withUnit(formatNumber(client, s, displayPrecision(client, entityId)), a.unit_of_measurement);
    }

    var t = stateTranslation(client, entityId, st, s);
    if (t) return t;
    return a.unit_of_measurement ? withUnit(s, a.unit_of_measurement) : s;
}

// ---------------------------------------------------------------- icons

function pickIcon(def, st) {
    if (!def)
        return null;
    var s = st ? st.state : undefined;
    if (def.state && s !== undefined && def.state[s])
        return def.state[s];
    if (def.range && st && isNumeric(s)) {
        var v = Number(s), best = null, bestKey = -Infinity;
        for (var k in def.range) {
            var kn = Number(k);
            if (kn <= v && kn > bestKey) { bestKey = kn; best = def.range[k]; }
        }
        if (best) return best;
    }
    return def.default || null;
}

function entityIcon(client, entityId, st, cfgIcon) {
    if (cfgIcon)
        return cfgIcon;
    if (st && st.attributes && st.attributes.icon)
        return st.attributes.icon;
    var reg = client.entities[entityId];
    if (reg && reg.icon)
        return reg.icon;
    var d = domainOf(entityId);
    var r;
    if (reg && reg.translation_key && reg.platform) {
        r = pickIcon(dig(client.entityIconDefs, reg.platform, d, reg.translation_key), st);
        if (r) return r;
    }
    var comp = client.iconDefs[d];
    if (comp) {
        var dc = st && st.attributes ? st.attributes.device_class : undefined;
        if (dc && comp[dc]) {
            r = pickIcon(comp[dc], st);
            if (r) return r;
        }
        r = pickIcon(comp["_"], st);
        if (r) return r;
    }
    if (d === "weather" && st && WEATHER_ICONS[st.state])
        return WEATHER_ICONS[st.state];
    if (reg && reg.original_icon)
        return reg.original_icon;
    return FALLBACK_ICONS[d] || "mdi:bookmark";
}

// ---------------------------------------------------------------- colors

function rgbColor(arr) {
    if (!arr || arr.length < 3) return "";
    function h(x) { var s = Math.round(x).toString(16); return s.length < 2 ? "0" + s : s; }
    return "#" + h(arr[0]) + h(arr[1]) + h(arr[2]);
}

// Returns a color string, "primary" for the theme accent, or "" for "no color".
function activeColor(entityId, st) {
    if (isUnavailable(st))
        return "";
    var s = st.state, a = st.attributes || {};
    switch (domainOf(entityId)) {
    case "light":
        if (s !== "on") return "";
        return rgbColor(a.rgb_color) || COLORS.amber;
    case "switch": case "input_boolean": case "automation": case "script": case "siren":
    case "remote": case "group":
        return s === "on" ? COLORS.amber : "";
    case "fan": return s === "on" ? COLORS.cyan : "";
    case "humidifier": return s === "on" ? COLORS.blue : "";
    case "cover": case "valve": return s !== "closed" ? COLORS.purple : "";
    case "lock": return s === "locked" ? COLORS.green : COLORS.red;
    case "climate":
        var mode = a.hvac_action || s;
        if (mode === "heating" || mode === "heat") return COLORS.deepOrange;
        if (mode === "cooling" || mode === "cool") return COLORS.blue;
        if (mode === "drying" || mode === "dry") return COLORS.orange;
        if (mode === "fan" || mode === "fan_only") return COLORS.cyan;
        if (mode === "heat_cool") return COLORS.amber;
        if (mode === "auto") return COLORS.green;
        return "";
    case "water_heater": return s !== "off" ? COLORS.orange : "";
    case "media_player": return (s === "playing" || s === "paused" || s === "on" || s === "idle" || s === "buffering") ? COLORS.lightBlue : "";
    case "person": case "device_tracker": return s === "home" ? COLORS.green : (s === "not_home" ? "" : COLORS.blue);
    case "binary_sensor":
        if (s !== "on") return "";
        if (["problem", "smoke", "gas", "carbon_monoxide", "moisture", "safety", "tamper", "heat", "battery"].indexOf(a.device_class) >= 0)
            return COLORS.red;
        return COLORS.amber;
    case "alarm_control_panel":
        if (s === "disarmed") return COLORS.green;
        if (s === "triggered") return COLORS.red;
        return COLORS.red;
    case "sun": return s === "above_horizon" ? COLORS.amber : "";
    case "vacuum": return s === "cleaning" ? COLORS.teal : "";
    case "timer": return s === "active" ? COLORS.amber : "";
    case "update": return s === "on" ? COLORS.orange : "";
    case "sensor":
        if (a.device_class === "battery" && isNumeric(s))
            return Number(s) <= 20 ? COLORS.red : (Number(s) <= 50 ? COLORS.orange : COLORS.green);
        return "primary";
    default: return "primary";
    }
}

// ---------------------------------------------------------------- actions

function svc(client, domain, service, entityId, data) {
    return client.callService(domain, service, data || {}, entityId ? { entity_id: entityId } : undefined);
}

function toggle(client, entityId) {
    var d = domainOf(entityId);
    var st = client.states[entityId];
    var s = st ? st.state : "";
    switch (d) {
    case "lock": return svc(client, "lock", s === "locked" ? "unlock" : "lock", entityId);
    case "cover": case "valve": return svc(client, d, "toggle", entityId);
    case "scene": return svc(client, "scene", "turn_on", entityId);
    case "script": return svc(client, "script", s === "on" ? "turn_off" : "turn_on", entityId);
    case "button": case "input_button": return svc(client, d, "press", entityId);
    case "media_player": return svc(client, "media_player", (s === "off" || s === "standby") ? "turn_on" : "turn_off", entityId);
    case "vacuum": return svc(client, "vacuum", s === "cleaning" ? "return_to_base" : "start", entityId);
    case "climate": return svc(client, "climate", s === "off" ? "turn_on" : "turn_off", entityId);
    case "group": return svc(client, "homeassistant", "toggle", entityId);
    default:
        if (SWITCH_DOMAINS.indexOf(d) >= 0)
            return svc(client, d, "toggle", entityId);
        return svc(client, "homeassistant", "toggle", entityId);
    }
}

// Runs a Lovelace tap_action. `dash` provides moreInfo(), navigate() and openUrl().
function runAction(client, dash, action, entityId, defaultAction) {
    var act = (action && action.action) ? action : { action: defaultAction || "more-info" };
    switch (act.action) {
    case "toggle":
        if (entityId) toggle(client, entityId);
        break;
    case "more-info":
        var e = act.entity || entityId;
        if (e) dash.moreInfo(e);
        break;
    case "call-service":
    case "perform-action":
        var name = act.perform_action || act.service;
        if (!name) break;
        var p = String(name).split(".");
        client.callService(p[0], p[1], act.data || act.service_data || {}, act.target);
        break;
    case "navigate":
        dash.navigate(act.navigation_path);
        break;
    case "url":
        dash.openUrl(act.url_path);
        break;
    default:
        break;
    }
}

function defaultTapAction(entityId) {
    return isTapToggleable(entityId) ? "toggle" : "more-info";
}

// ---------------------------------------------------------------- conditions

function asList(v) {
    return Array.isArray(v) ? v.map(String) : [String(v)];
}

function checkCondition(client, c) {
    if (!c) return true;
    var type = c.condition || (c.entity ? "state" : "");
    var st, s;
    switch (type) {
    case "state":
        st = client.states[c.entity];
        s = st ? st.state : "unavailable";
        if (c.state !== undefined && asList(c.state).indexOf(s) < 0) return false;
        if (c.state_not !== undefined && asList(c.state_not).indexOf(s) >= 0) return false;
        return true;
    case "numeric_state":
        st = client.states[c.entity];
        if (!st || !isNumeric(st.state)) return false;
        var v = Number(st.state);
        if (c.above !== undefined && isNumeric(c.above) && !(v > Number(c.above))) return false;
        if (c.below !== undefined && isNumeric(c.below) && !(v < Number(c.below))) return false;
        return true;
    case "and":
        return checkConditions(client, c.conditions);
    case "or":
        var list = c.conditions || [];
        for (var i = 0; i < list.length; i++)
            if (checkCondition(client, list[i])) return true;
        return list.length === 0;
    case "not":
        var l2 = c.conditions || [];
        for (var j = 0; j < l2.length; j++)
            if (checkCondition(client, l2[j])) return false;
        return true;
    default:
        return true; // screen, user, location...: always shown on the desktop
    }
}

function checkConditions(client, conds) {
    if (!conds || !conds.length)
        return true;
    for (var i = 0; i < conds.length; i++)
        if (!checkCondition(client, conds[i])) return false;
    return true;
}

// ---------------------------------------------------------------- layout

// Rough card height in "rows" (≈ 50 px), used to balance masonry columns.
function cardSize(cfg) {
    if (!cfg) return 1;
    var n = 0, i;
    switch (cfg.type) {
    case "entities": return (cfg.title ? 1 : 0) + (cfg.entities ? cfg.entities.length : 0) + (cfg.footer ? 1 : 0);
    case "tile": case "heading": return 1;
    case "button": return 2;
    case "glance": return (cfg.title ? 1 : 0) + 2 * Math.ceil(((cfg.entities || []).length || 1) / (cfg.columns || 5));
    case "thermostat": return 6;
    case "light": return 5;
    case "media-control": return 3;
    case "weather-forecast": return cfg.show_forecast === false ? 2 : 4;
    case "sensor": case "entity": return cfg.graph === "line" ? 4 : 2;
    case "gauge": return 3;
    case "markdown": return 1 + Math.ceil(String(cfg.content || "").length / 150);
    case "picture": case "picture-entity": case "picture-glance": return 4;
    case "history-graph": case "statistics-graph": return 4;
    case "area": return 3;
    case "vertical-stack":
        for (i = 0; i < (cfg.cards || []).length; i++) n += cardSize(cfg.cards[i]);
        return n;
    case "horizontal-stack":
        for (i = 0; i < (cfg.cards || []).length; i++) n = Math.max(n, cardSize(cfg.cards[i]));
        return n;
    case "grid":
        var cols = cfg.columns || 3, cards = cfg.cards || [];
        for (i = 0; i < cards.length; i += cols) {
            var m = 0;
            for (var j = i; j < Math.min(i + cols, cards.length); j++) m = Math.max(m, cardSize(cards[j]));
            n += m;
        }
        return n;
    case "conditional": return cardSize(cfg.card);
    default:
        if (cfg.entities) return (cfg.entities.length || 1) + 1;
        return 2;
    }
}

// Width of a card inside a sections grid, in twelfths.
function gridColumns(cfg) {
    var go = cfg.grid_options;
    if (go && go.columns !== undefined)
        return go.columns === "full" ? 12 : Math.max(1, Math.min(12, Number(go.columns)));
    var lo = cfg.layout_options;
    if (lo && lo.grid_columns !== undefined)
        return lo.grid_columns === "full" ? 12 : Math.max(1, Math.min(12, Number(lo.grid_columns) * 3));
    switch (cfg.type) {
    case "tile": return 6;
    case "button": return 3;
    case "area": return 6;
    default: return 12;
    }
}

// ---------------------------------------------------------------- misc

// Named colors accepted by HA cards (tile `color:` option, etc.).
var NAMED_COLORS = {
    "red": "#f44336", "pink": "#e91e63", "purple": "#926bc7", "deep-purple": "#6e41ab",
    "indigo": "#3f51b5", "blue": "#2196f3", "light-blue": "#03a9f4", "cyan": "#00bcd4",
    "teal": "#009688", "green": "#4caf50", "light-green": "#8bc34a", "lime": "#cddc39",
    "yellow": "#ffeb3b", "amber": "#ffc107", "orange": "#ff9800", "deep-orange": "#ff6f22",
    "brown": "#795548", "light-grey": "#bdbdbd", "grey": "#9e9e9e", "dark-grey": "#606060",
    "blue-grey": "#607d8b", "black": "#000000", "white": "#ffffff"
};

function areaOfEntity(client, entityId) {
    var reg = client.entities[entityId];
    if (!reg)
        return null;
    if (reg.area_id)
        return reg.area_id;
    var dev = reg.device_id ? client.devices[reg.device_id] : null;
    return dev ? dev.area_id : null;
}

function areaEntities(client, areaId) {
    var out = [];
    for (var id in client.states) {
        var reg = client.entities[id];
        if (reg && (reg.hidden_by || reg.entity_category))
            continue;
        if (areaOfEntity(client, id) === areaId)
            out.push(id);
    }
    return out;
}

// Absolute URL for an image path coming from HA ("/api/camera_proxy/...").
function absoluteUrl(client, url) {
    if (!url)
        return "";
    var s = String(url);
    if (/^(https?|data|file):/i.test(s))
        return s;
    return client.cleanUrl + (s.charAt(0) === "/" ? "" : "/") + s;
}

function temperatureUnit(client) {
    return dig(client.haConfig, "unit_system", "temperature") || "°C";
}

function supports(st, bit) {
    var f = st && st.attributes ? Number(st.attributes.supported_features || 0) : 0;
    return (f & bit) !== 0;
}

// ---------------------------------------------------------------- media players

var MP = {
    PAUSE: 1, SEEK: 2, VOLUME_SET: 4, VOLUME_MUTE: 8, PREVIOUS_TRACK: 16, NEXT_TRACK: 32,
    TURN_ON: 128, TURN_OFF: 256, PLAY_MEDIA: 512, VOLUME_STEP: 1024, SELECT_SOURCE: 2048,
    STOP: 4096, PLAY: 16384, SHUFFLE_SET: 32768, SELECT_SOUND_MODE: 65536, REPEAT_SET: 262144
};

var MP_CONTROL_FEATURES = {
    turn_on: [MP.TURN_ON], turn_off: [MP.TURN_OFF], power: [MP.TURN_ON, MP.TURN_OFF],
    media_play: [MP.PLAY], media_pause: [MP.PAUSE], media_play_pause: [MP.PLAY, MP.PAUSE],
    media_stop: [MP.STOP], media_previous_track: [MP.PREVIOUS_TRACK], media_next_track: [MP.NEXT_TRACK],
    volume_down: [MP.VOLUME_STEP], volume_up: [MP.VOLUME_STEP], volume_mute: [MP.VOLUME_MUTE],
    shuffle: [MP.SHUFFLE_SET], repeat: [MP.REPEAT_SET]
};

// Buttons of HA's "media-player-playback" tile feature (same defaults and
// enabled/disabled rules as the web UI). Each: {icon, service, data, disabled}.
function mediaButtons(entityId, st, controls) {
    if (!st)
        return [];
    var a = st.attributes || {};
    var assumed = a.assumed_state === true;
    var active = isActive(entityId, st);
    var playing = st.state === "playing";
    var context = playing || st.state === "paused" || assumed;
    var unavailable = st.state === "unavailable";
    var list = controls && controls.length ? controls
        : (assumed ? ["turn_on", "turn_off", "media_previous_track", "media_play", "media_pause", "media_next_track"]
                   : ["power", "media_previous_track", "media_play_pause", "media_next_track"]);
    var out = [];
    list.forEach(function (c) {
        var bits = MP_CONTROL_FEATURES[c];
        if (!bits || !bits.some(function (b) { return supports(st, b); }))
            return;
        var canPause = supports(st, MP.PAUSE);
        switch (c) {
        case "turn_on": out.push({ icon: "mdi:power-on", service: "turn_on", disabled: unavailable || (active && !assumed) }); break;
        case "turn_off": out.push({ icon: "mdi:power-off", service: "turn_off", disabled: !active && !assumed }); break;
        case "power":
            out.push({ icon: "mdi:power-standby", service: active ? "turn_off" : "turn_on",
                       disabled: unavailable || !supports(st, active ? MP.TURN_OFF : MP.TURN_ON) });
            break;
        case "media_play": out.push({ icon: "mdi:play", service: "media_play", disabled: !assumed && (!active || playing) }); break;
        case "media_pause": out.push({ icon: "mdi:pause", service: "media_pause", disabled: !playing && !assumed }); break;
        case "media_play_pause":
            out.push({ icon: !playing ? "mdi:play" : (canPause ? "mdi:pause" : "mdi:stop"),
                       service: !playing ? "media_play" : (canPause ? "media_pause" : "media_stop"), disabled: !active });
            break;
        case "media_stop": out.push({ icon: "mdi:stop", service: "media_stop", disabled: !context }); break;
        case "media_previous_track": out.push({ icon: "mdi:skip-previous", service: "media_previous_track", disabled: !context }); break;
        case "media_next_track": out.push({ icon: "mdi:skip-next", service: "media_next_track", disabled: !context }); break;
        case "volume_down": out.push({ icon: "mdi:volume-minus", service: "volume_down", disabled: !active }); break;
        case "volume_up": out.push({ icon: "mdi:volume-plus", service: "volume_up", disabled: !active }); break;
        case "volume_mute":
            out.push({ icon: a.is_volume_muted ? "mdi:volume-off" : "mdi:volume-high", service: "volume_mute",
                       data: { is_volume_muted: !a.is_volume_muted }, disabled: !active, on: !!a.is_volume_muted });
            break;
        case "shuffle":
            out.push({ icon: a.shuffle === true ? "mdi:shuffle" : "mdi:shuffle-disabled", service: "shuffle_set",
                       data: { shuffle: a.shuffle !== true }, disabled: !context });
            break;
        case "repeat":
            var next = a.repeat === "off" || !a.repeat ? "all" : (a.repeat === "all" ? "one" : "off");
            out.push({ icon: a.repeat === "all" ? "mdi:repeat" : (a.repeat === "one" ? "mdi:repeat-once" : "mdi:repeat-off"),
                       service: "repeat_set", data: { repeat: next }, disabled: !context });
            break;
        }
    });
    return out;
}
