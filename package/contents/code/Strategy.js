.pragma library
.import "Ha.js" as Ha
.import "Tr.js" as Tr

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
        titles[d] = d === "_helpers" ? Tr.tr(client, "Helpers") : Ha.domainTitle(client, d);
    });
    Object.keys(groups).sort(function (a, b) {
        return titles[a].localeCompare(titles[b]);
    }).forEach(function (d) {
        cards = cards.concat(computeCards(client, groups[d].sort(byName(client)), titles[d]));
    });

    return { title: Tr.tr(client, "Overview"), path: "default_view", cards: cards };
}

// Turns whatever lovelace/config returned into a dashboard we can draw.
// `raw` is null when the dashboard has no stored config.
function resolveDashboard(client, raw) {
    if (!raw || raw.strategy || !raw.views || raw.views.length === 0)
        return { title: Tr.tr(client, "Overview"), generated: true, views: [generateOverview(client)] };
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

// ======================================================================
// HA's new "Home" dashboard (/home): overview with favorites, floors and
// area cards, summaries in a sidebar, and one sub-view per area.
// Mirrors the frontend's home-* strategies (frontend 2026.x).

var SUMMARY_FILTERS = {
    light: [{ domain: "light", entity_category: "none" }],
    climate: [
        { domain: "climate", entity_category: "none" },
        { domain: "humidifier", entity_category: "none" },
        { domain: "fan", entity_category: "none" },
        { domain: "water_heater", entity_category: "none" },
        { domain: "cover", device_class: ["awning", "blind", "curtain", "shade", "shutter", "window", "none"], entity_category: "none" },
        { domain: "binary_sensor", device_class: ["window"], entity_category: "none" }
    ],
    security: [
        { domain: "camera", entity_category: "none" },
        { domain: "alarm_control_panel", entity_category: "none" },
        { domain: "lock", entity_category: "none" },
        { domain: "cover", device_class: ["door", "garage", "gate", "window"], entity_category: "none" },
        { domain: "binary_sensor", device_class: ["lock", "door", "window", "garage_door", "opening", "carbon_monoxide",
                                                 "gas", "glass_break", "moisture", "safety", "smoke", "tamper"],
          entity_category: "none" },
        { domain: "binary_sensor", device_class: ["tamper"], entity_category: "diagnostic" }
    ],
    media_players: [{ domain: "media_player", entity_category: "none" }],
    maintenance: [
        { domain: "sensor", device_class: ["battery"] },
        { domain: "binary_sensor", device_class: ["battery", "problem"] }
    ]
};

var SUMMARY_ICONS = {
    light: "mdi:lamps", climate: "mdi:home-thermometer", security: "mdi:security",
    media_players: "mdi:multimedia", maintenance: "mdi:wrench", energy: "mdi:lightning-bolt",
    persons: "mdi:account-multiple", alerts: "mdi:alarm-plus"
};
var SUMMARY_COLORS = {
    light: "amber", climate: "deep-orange", security: "blue-grey", media_players: "blue",
    maintenance: "grey", energy: "amber", persons: "green", alerts: "red"
};
var SUMMARY_LABELS = {
    light: "Lights", climate: "Climate", security: "Security", media_players: "Media players",
    maintenance: "Maintenance", energy: "Energy", persons: "People", alerts: "Alerts"
};

function summaryLabel(client, key) {
    return SUMMARY_LABELS[key] ? Tr.tr(client, SUMMARY_LABELS[key]) : key;
}

// HA entity filter: {domain, device_class (list, "none" = no class), entity_category ("none" = primary)}.
function matchFilter(client, id, f) {
    if (f.domain && Ha.domainOf(id) !== f.domain)
        return false;
    var st = client.states[id];
    if (!st)
        return false;
    if (f.device_class) {
        var dc = (st.attributes && st.attributes.device_class) || "none";
        if (f.device_class.indexOf(dc) < 0)
            return false;
    }
    if (f.entity_category) {
        var reg = client.entities[id];
        var cat = (reg && reg.entity_category) || "none";
        if (cat !== f.entity_category)
            return false;
    }
    return true;
}

function findEntities(client, ids, filters) {
    return ids.filter(function (id) {
        for (var i = 0; i < filters.length; i++)
            if (matchFilter(client, id, filters[i])) return true;
        return false;
    });
}

function summaryEntities(client, key) {
    return findEntities(client, Object.keys(client.states), SUMMARY_FILTERS[key] || []);
}

function isHidden(client, id) {
    var reg = client.entities[id];
    return !!(reg && (reg.hidden_by || reg.hidden));
}

function floorIcon(floor) {
    var l = floor.level;
    if (l === null || l === undefined) return "mdi:home";
    if (l >= 0 && l <= 3) return "mdi:home-floor-" + l;
    if (l === -1) return "mdi:home-floor-negative-1";
    return "mdi:home";
}

function favoriteCard(id) {
    if (Ha.domainOf(id) === "camera")
        return { type: "picture-entity", entity: id, show_name: false, show_state: false, grid_options: { columns: 6 } };
    return { type: "tile", entity: id, state_content: ["state", "area_name"] };
}

function areaCard(client, areaId) {
    return {
        type: "area", area: areaId, display_type: "compact", vertical: true,
        sensor_classes: client.areas[areaId].temperature_entity_id ? ["temperature"] : [],
        tap_action: { action: "navigate", navigation_path: "areas-" + areaId },
        grid_options: { columns: 4 }
    };
}

function deviceName(client, dev) {
    return dev ? (dev.name_by_user || dev.name || Tr.tr(client, "Unnamed device")) : Tr.tr(client, "Others");
}

// Sections listing entities grouped by device (used by area and "other devices" views).
function deviceSections(client, ids) {
    var byDevice = {}, order = [], loose = [];
    ids.forEach(function (id) {
        var reg = client.entities[id];
        var devId = reg && reg.device_id && client.devices[reg.device_id] ? reg.device_id : null;
        if (!devId) { loose.push(id); return; }
        if (!byDevice[devId]) { byDevice[devId] = []; order.push(devId); }
        byDevice[devId].push(id);
    });
    var groups = order.map(function (d) { return { dev: client.devices[d], ids: byDevice[d] }; });
    if (loose.length)
        groups.push({ dev: null, ids: loose });
    var out = [];
    groups.forEach(function (g) {
        var battery = g.ids.filter(function (id) { return matchFilter(client, id, { domain: "sensor", device_class: ["battery"] }); });
        var main = g.ids.filter(function (id) {
            return battery.indexOf(id) < 0 && matchFilter(client, id, { entity_category: "none" });
        });
        if (main.length === 0)
            return;
        out.push({
            type: "grid",
            cards: [{ type: "heading", heading: deviceName(client, g.dev), badges: battery.slice(0, 1).map(function (b) { return { entity: b }; }) }]
                .concat(main.sort(byName(client)).map(function (id) {
                    return { type: "tile", entity: id, name: { type: "entity" } };
                }))
        });
    });
    return out;
}

function generateHomeArea(client, areaId) {
    var area = client.areas[areaId];
    var badges = [];
    if (area.temperature_entity_id && client.states[area.temperature_entity_id])
        badges.push({ type: "entity", entity: area.temperature_entity_id, color: "red" });
    if (area.humidity_entity_id && client.states[area.humidity_entity_id])
        badges.push({ type: "entity", entity: area.humidity_entity_id, color: "indigo" });

    var ids = Object.keys(client.states).filter(function (id) {
        return Ha.areaOfEntity(client, id) === areaId && !isHidden(client, id);
    });
    var tile = function (id) { return { type: "tile", entity: id }; };
    var sections = [];
    var used = {};
    function addGroup(key, heading, icon, extraHeading) {
        var list = findEntities(client, ids, SUMMARY_FILTERS[key]).filter(function (id) { return !used[id]; });
        list.forEach(function (id) { used[id] = true; });
        if (!list.length)
            return;
        var h = { type: "heading", heading: heading, icon: icon };
        if (extraHeading) extraHeading(h, list);
        sections.push({ type: "grid", cards: [h].concat(list.sort(byName(client)).map(tile)) });
    }
    addGroup("light", summaryLabel(client, "light"), SUMMARY_ICONS.light, function (h, list) {
        var anyOn = { condition: "or", conditions: list.map(function (id) { return { condition: "state", entity: id, state: "on" }; }) };
        h.badges = [
            { type: "button", icon: "mdi:power", text: Tr.tr(client, "All off"),
              tap_action: { action: "perform-action", perform_action: "light.turn_on", target: { area_id: areaId } },
              visibility: [{ condition: "not", conditions: [anyOn] }] },
            { type: "button", icon: "mdi:power", text: Tr.tr(client, "On"), color: "orange",
              tap_action: { action: "perform-action", perform_action: "light.turn_off", target: { area_id: areaId } },
              visibility: [anyOn] }
        ];
    });
    addGroup("climate", summaryLabel(client, "climate"), SUMMARY_ICONS.climate);
    addGroup("security", summaryLabel(client, "security"), SUMMARY_ICONS.security);
    addGroup("media_players", summaryLabel(client, "media_players"), SUMMARY_ICONS.media_players);

    var scenes = ids.filter(function (id) { return matchFilter(client, id, { domain: "scene", entity_category: "none" }); });
    if (scenes.length)
        sections.push({ type: "grid", cards: [{ type: "heading", heading: Tr.tr(client, "Scenes"), icon: "mdi:palette" }].concat(scenes.map(tile)) });
    scenes.forEach(function (id) { used[id] = true; });

    var automations = ids.filter(function (id) { return matchFilter(client, id, { domain: "automation", entity_category: "none" }); });
    automations.forEach(function (id) { used[id] = true; });

    var rest = ids.filter(function (id) { return !used[id]; });
    var devSecs = deviceSections(client, rest);
    if (devSecs.length) {
        sections.push({ type: "grid", column_span: 3, cards: [{ type: "heading", heading_style: "subtitle", heading: "" }] });
        sections = sections.concat(devSecs);
    }
    if (automations.length)
        sections.push({ type: "grid", cards: [{ type: "heading", heading: Tr.tr(client, "Automations"), icon: "mdi:robot" }].concat(automations.map(tile)) });

    if (sections.length === 1)
        sections[0].column_span = 2;
    return {
        title: area.name, path: "areas-" + areaId, icon: area.icon, subview: true, type: "sections",
        max_columns: Math.max(2, Math.min(3, sections.length)), badges: badges, sections: sections
    };
}

function summaryCard(key) {
    var nav = { light: "/light", climate: "/climate", security: "/security", media_players: "media-players",
                maintenance: "/maintenance", energy: "/energy" }[key];
    return { type: "home-summary", summary: key, tap_action: { action: "navigate", navigation_path: nav } };
}

function generateHomeOverview(client, cfg, predicted) {
    var maxColumns = 3;
    var sections = [];

    // Favorites: pinned entities, then HA's usage-based suggestions.
    var favs = (cfg.favorite_entities || []).filter(function (id) { return !!client.states[id]; });
    var limit = Math.max(8, favs.length);
    var favIds = favs.slice();
    if (!cfg.hide_suggested_entities) {
        (predicted || []).forEach(function (id) {
            if (favIds.length < limit && client.states[id] && !isHidden(client, id) && favIds.indexOf(id) < 0)
                favIds.push(id);
        });
    }
    if (favIds.length)
        sections.push({ type: "grid", column_span: maxColumns,
                        cards: [{ type: "heading", heading: Tr.tr(client, "Favorites"), heading_style: "title" }].concat(favIds.map(favoriteCard)) });

    // Floors and their areas.
    var floors = client.floorOrder.map(function (f) { return client.floors[f]; }).filter(function (f) { return !!f; });
    var areasOf = function (floorId) {
        return client.areaOrder.filter(function (a) { return (client.areas[a].floor_id || null) === floorId; });
    };
    var looseAreas = client.areaOrder.filter(function (a) {
        var f = client.areas[a].floor_id;
        return !f || !client.floors[f];
    });
    var usedFloors = floors.filter(function (f) { return areasOf(f.floor_id).length > 0; });
    var floorCount = usedFloors.length + (looseAreas.length ? 1 : 0);
    usedFloors.forEach(function (f) {
        sections.push({ type: "grid", column_span: maxColumns, cards: [{
            type: "heading", heading: floorCount > 1 ? f.name : Tr.tr(client, "Areas"), heading_style: "title",
            icon: f.icon || floorIcon(f) }].concat(areasOf(f.floor_id).map(function (a) { return areaCard(client, a); })) });
    });

    var hasOtherDevices = Object.keys(client.states).some(function (id) {
        var reg = client.entities[id];
        return reg && reg.device_id && !Ha.areaOfEntity(client, id) && !reg.entity_category && !isHidden(client, id);
    });
    if (looseAreas.length || hasOtherDevices) {
        var cards = looseAreas.map(function (a) { return areaCard(client, a); });
        if (hasOtherDevices)
            cards.push({ type: "tile", entity: "zone.home", vertical: true, name: Tr.tr(client, "Devices"), icon: "mdi:devices",
                         hide_state: true, tap_action: { action: "navigate", navigation_path: "other-devices" },
                         grid_options: { columns: 4 } });
        var heading = !usedFloors.length && !looseAreas.length ? ""
                    : !usedFloors.length ? Tr.tr(client, "Areas")
                    : !looseAreas.length ? Tr.tr(client, "Devices") : Tr.tr(client, "Other areas");
        sections.push({ type: "grid", column_span: maxColumns,
                        cards: (heading ? [{ type: "heading", heading: heading, heading_style: "title" }] : []).concat(cards) });
    }

    // Summaries (sidebar on wide screens).
    var weather = Object.keys(client.states).filter(function (id) {
        return matchFilter(client, id, { domain: "weather", entity_category: "none" });
    }).sort()[0];
    var builders = {
        light: function () { return summaryEntities(client, "light").length ? summaryCard("light") : null; },
        climate: function () { return summaryEntities(client, "climate").length ? summaryCard("climate") : null; },
        security: function () { return summaryEntities(client, "security").length ? summaryCard("security") : null; },
        media_players: function () { return summaryEntities(client, "media_players").length ? summaryCard("media_players") : null; },
        maintenance: function () { return summaryEntities(client, "maintenance").length ? summaryCard("maintenance") : null; },
        weather: function () {
            return weather ? { type: "tile", entity: weather, name: Tr.tr(client, "Weather"), state_content: ["temperature", "state"] } : null;
        },
        energy: function () { return null; } // needs the energy collection: not supported
    };
    var items = cfg.shortcuts && cfg.shortcuts.length ? cfg.shortcuts
        : ["light", "climate", "security", "media_players", "weather", "energy", "maintenance"]
            .map(function (k) { return { type: "summary", key: k }; });
    var summaries = [];
    items.forEach(function (it) {
        if (it.type === "summary" || !it.type) {
            if (it.hidden) return;
            var b = builders[it.key];
            var c = b ? b() : null;
            if (c) summaries.push(c);
        } else {
            summaries.push({ type: "shortcut", label: it.label, icon: it.icon, color: it.color,
                             tap_action: { action: "navigate", navigation_path: it.path } });
        }
    });

    var view = { title: Tr.tr(client, "Home"), path: "overview", icon: "mdi:home", type: "sections", max_columns: maxColumns,
                 sections: sections };
    if (summaries.length)
        view.sidebar = { sections: [{ type: "grid", cards: [{ type: "heading", heading: Tr.tr(client, "Summaries"), heading_style: "title" }]
            .concat(summaries.map(function (c) { c.grid_options = { columns: 12 }; return c; })) }] };
    if (!cfg.hide_welcome_message)
        view.header = { card: { type: "markdown", text_only: true, content: Tr.tr(client, "## Hello {{ user }}!") } };
    return view;
}

function generateHome(client, cfg, predicted) {
    cfg = cfg || {};
    var views = [generateHomeOverview(client, cfg, predicted)];
    client.areaOrder.forEach(function (a) { views.push(generateHomeArea(client, a)); });

    var players = summaryEntities(client, "media_players").filter(function (id) { return !isHidden(client, id); });
    views.push({ title: summaryLabel(client, "media_players"), path: "media-players", icon: SUMMARY_ICONS.media_players, subview: true,
                 type: "sections", sections: [{ type: "grid", column_span: 3, cards: players.map(function (id) {
                     return { type: "media-control", entity: id };
                 }) }] });

    var loose = Object.keys(client.states).filter(function (id) {
        var reg = client.entities[id];
        return reg && reg.device_id && !Ha.areaOfEntity(client, id) && !isHidden(client, id);
    });
    views.push({ title: Tr.tr(client, "Devices"), path: "other-devices", icon: "mdi:devices", subview: true, type: "sections",
                 max_columns: 3, sections: deviceSections(client, loose) });

    return { title: Tr.tr(client, "Home"), generated: true, home: true, views: views };
}
