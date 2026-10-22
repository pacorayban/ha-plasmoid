.pragma library
.import "Ha.js" as Ha

// Rebuilds HA's auto-generated "Overview" (the original-states strategy):
// one card per area, then one per device, then one per domain.
// Used when the dashboard has no stored config or relies on a strategy.

var HIDE_DOMAIN = ["ai_task", "automation", "configurator", "device_tracker", "event",
                   "geo_location", "notify", "persistent_notification", "script", "sun",
                   "tag", "todo", "zone", "assist_satellite", "conversation", "stt", "tts",
                   "wake_word"];
var HIDE_PLATFORM = ["backup", "mobile_app"];
var HELPER_DOMAINS = ["counter", "input_boolean", "input_button", "input_datetime",
                      "input_number", "input_select", "input_text", "schedule", "timer"];
var SENSOR_DOMAINS = ["alarm_control_panel", "binary_sensor", "calendar", "camera",
                      "device_tracker", "event", "image", "person", "plant", "sensor",
                      "sun", "weather"];

function byName(client) {
    return function (a, b) {
        var na = Ha.entityName(client, a, client.states[a]).toLowerCase();
        var nb = Ha.entityName(client, b, client.states[b]).toLowerCase();
        return na.localeCompare(nb);
    };
}

function computeCards(client, ids, title) {
    var cards = [], rows = [], footer = [];
    for (var i = 0; i < ids.length; i++) {
        var id = ids[i], d = Ha.domainOf(id);
        if (d === "alarm_control_panel") cards.push({ type: "tile", entity: id });
        else if (d === "camera") cards.push({ type: "picture-entity", entity: id });
        else if (d === "image") cards.push({ type: "picture-entity", entity: id, show_state: false });
        else if (d === "climate") cards.push({ type: "thermostat", entity: id });
        else if (d === "media_player") cards.push({ type: "media-control", entity: id });
        else if (d === "weather") cards.push({ type: "weather-forecast", entity: id, show_forecast: false });
        else if (d === "scene" || d === "script") footer.push(id);
        else rows.push(id);
    }
    if (rows.length === 0 && footer.length > 0) {
        rows = footer;
        footer = [];
    }
    rows.sort(function (a, b) {
        var ca = SENSOR_DOMAINS.indexOf(Ha.domainOf(a)) >= 0 ? 1 : 0;
        var cb = SENSOR_DOMAINS.indexOf(Ha.domainOf(b)) >= 0 ? 1 : 0;
        if (ca !== cb) return ca - cb;
        return byName(client)(a, b);
    });
    if (rows.length > 0) {
        var card = { type: "entities", title: title, entities: rows };
        if (footer.length > 0)
            card.footer = { type: "buttons", entities: footer };
        cards.unshift(card);
    } else if (cards.length > 0 && title) {
        cards.unshift({ type: "heading", heading: title, heading_style: "subtitle" });
    }
    if (cards.length < 2)
        return cards;
    return [{ type: "vertical-stack", cards: cards }];
}

function visibleEntities(client) {
    var out = [];
    var ids = Object.keys(client.states);
    for (var i = 0; i < ids.length; i++) {
        var id = ids[i];
        if (HIDE_DOMAIN.indexOf(Ha.domainOf(id)) >= 0)
            continue;
        var reg = client.entities[id];
        if (reg && (reg.entity_category || reg.hidden_by || reg.hidden
                    || HIDE_PLATFORM.indexOf(reg.platform) >= 0))
            continue;
        var st = client.states[id];
        if (st.attributes && st.attributes.hidden)
            continue;
        out.push(id);
    }
    return out;
}

function generateOverview(client) {
    var ids = visibleEntities(client);
    var remaining = {};
    ids.forEach(function (id) { remaining[id] = true; });

    var byArea = {}, byDevice = {};
    ids.forEach(function (id) {
        var reg = client.entities[id];
        if (!reg)
            return;
        var dev = reg.device_id ? client.devices[reg.device_id] : null;
        var areaId = reg.area_id || (dev ? dev.area_id : null);
        if (areaId && client.areas[areaId]) {
            (byArea[areaId] = byArea[areaId] || []).push(id);
            delete remaining[id];
        } else if (dev) {
            (byDevice[reg.device_id] = byDevice[reg.device_id] || []).push(id);
            delete remaining[id];
        }
    });
    // A device with a single entity is not worth its own card.
    Object.keys(byDevice).forEach(function (devId) {
        if (byDevice[devId].length === 1) {
            remaining[byDevice[devId][0]] = true;
            delete byDevice[devId];
        }
    });

    var cards = [];

    client.areaOrder.forEach(function (areaId) {
        if (!byArea[areaId]) return;
        cards = cards.concat(computeCards(client, byArea[areaId].sort(byName(client)), client.areas[areaId].name));
    });

    Object.keys(byDevice).sort(function (a, b) {
        var da = client.devices[a], db = client.devices[b];
        return String(da.name_by_user || da.name || "").localeCompare(String(db.name_by_user || db.name || ""));
    }).forEach(function (devId) {
        var dev = client.devices[devId];
        cards = cards.concat(computeCards(client, byDevice[devId].sort(byName(client)), dev.name_by_user || dev.name));
    });

    // Remaining entities grouped by domain.
    var groups = {};
    Object.keys(remaining).forEach(function (id) {
        var d = Ha.domainOf(id);
        if (HELPER_DOMAINS.indexOf(d) >= 0) d = "_helpers";
        (groups[d] = groups[d] || []).push(id);
    });
    if (groups.person) {
        cards.unshift({ type: "glance", entities: groups.person.sort(byName(client)), state_color: true });
        delete groups.person;
    }
    var titles = {};
    Object.keys(groups).forEach(function (d) {
        titles[d] = d === "_helpers" ? "Entrées" : Ha.domainTitle(client, d);
    });
    Object.keys(groups).sort(function (a, b) {
        return titles[a].localeCompare(titles[b]);
    }).forEach(function (d) {
        cards = cards.concat(computeCards(client, groups[d].sort(byName(client)), titles[d]));
    });

    return { title: "Aperçu", path: "default_view", cards: cards };
}

// Turns whatever lovelace/config returned into a dashboard we can draw.
// `raw` is null when the dashboard has no stored config.
function resolveDashboard(client, raw) {
    if (!raw || raw.strategy || !raw.views || raw.views.length === 0)
        return { title: "Aperçu", generated: true, views: [generateOverview(client)] };
    var views = [];
    for (var i = 0; i < raw.views.length; i++) {
        var v = raw.views[i];
        if (v.strategy) {
            var g = generateOverview(client);
            g.title = v.title || g.title;
            g.path = v.path;
            g.icon = v.icon;
            views.push(g);
        } else {
            views.push(v);
        }
    }
    return { title: raw.title || "Home Assistant", generated: false, views: views };
}
