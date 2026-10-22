import QtQuick
import QtWebSockets

// Connection to Home Assistant through its WebSocket API.
// Keeps states, registries, translations and MDI icon paths up to date.
// Bindings that read `states` should also read `revision` to refresh.
Item {
    id: client
    visible: false

    property string baseUrl: ""
    property string token: ""
    // Taken from the HA user profile once connected, like the web frontend does.
    property string language: Qt.locale().name.split("_")[0]
    property var locale: Qt.locale()

    readonly property string cleanUrl: baseUrl.trim().replace(/\/+$/, "")
    readonly property string wsUrl: cleanUrl.replace(/^http/i, "ws") + "/api/websocket"

    // idle | unconfigured | connecting | loading | ready | error
    property string status: "idle"
    property string errorText: ""
    readonly property bool ready: status === "ready"
    property string haVersion: ""

    property var states: ({})
    property var entities: ({})
    property var devices: ({})
    property var areas: ({})
    property var areaOrder: []
    property var floors: ({})
    property var floorOrder: []
    property string userName: ""
    property var iconDefs: ({})
    property var entityIconDefs: ({})
    property var translations: ({})
    property var haConfig: ({})

    property int revision: 0       // bumped when states change
    property int iconRevision: 0   // bumped when icon data arrives
    property int connectionId: 0   // bumped on each successful (re)connection

    signal loaded()
    signal lovelaceUpdated(var urlPath)
    signal serviceError(string message)

    property int _nextId: 1
    property var _pending: ({})
    property var _subs: ({})
    property bool _authFailed: false
    property bool _opening: false
    property bool _awaitingPong: false
    property int _retryDelay: 2000

    // Plain JS state (mutated in place, so reading it inside bindings never loops).
    property var _icons: ({ meta: null, loading: false, chunks: {}, cache: {} })

    onCleanUrlChanged: {
        _icons = { meta: null, loading: false, chunks: {}, cache: {} };
        iconRevision++;
        settingsTimer.restart();
    }
    onTokenChanged: settingsTimer.restart()

    function reconnect() {
        settingsTimer.stop();
        _authFailed = false;
        _retryDelay = 2000;
        _open();
    }

    function _closeSocket() {
        _opening = true;
        socket.active = false;
        _opening = false;
    }

    function _open() {
        retryTimer.stop();
        pingTimer.stop();
        _closeSocket();
        _failPending("Connexion fermée");
        _subs = {};
        if (cleanUrl === "" || token.trim() === "") {
            status = "unconfigured";
            return;
        }
        if (!/^https?:\/\//i.test(cleanUrl)) {
            status = "error";
            errorText = "L'adresse doit commencer par http:// ou https://";
            return;
        }
        status = "connecting";
        errorText = "";
        _opening = true;
        socket.url = wsUrl;
        socket.active = true;
        _opening = false;
    }

    function _onClosed() {
        pingTimer.stop();
        _failPending("Connexion perdue");
        _subs = {};
        if (_authFailed || status === "unconfigured" || status === "idle")
            return;
        if (status !== "error") {
            status = "connecting";
            if (errorText === "")
                errorText = "Connexion perdue";
        }
        retryTimer.interval = _retryDelay;
        retryTimer.start();
    }

    function _failPending(reason) {
        var p = _pending;
        _pending = {};
        for (var id in p)
            p[id].reject({ code: "connection_lost", message: reason });
    }

    WebSocket {
        id: socket
        active: false
        onTextMessageReceived: function (message) { client._onMessage(message); }
        onStatusChanged: {
            if (client._opening)
                return;
            if (socket.status === WebSocket.Error)
                client.errorText = socket.errorString;
            if (socket.status === WebSocket.Closed || socket.status === WebSocket.Error)
                client._onClosed();
        }
    }

    Timer {
        id: settingsTimer
        interval: 600
        onTriggered: client.reconnect()
    }

    Timer {
        id: retryTimer
        onTriggered: {
            client._retryDelay = Math.min(client._retryDelay * 2, 60000);
            client._open();
        }
    }

    Timer {
        id: pingTimer
        interval: 30000
        repeat: true
        onTriggered: {
            if (client._awaitingPong) {
                // No answer to the previous ping: the link is dead.
                client.errorText = "Pas de réponse du serveur";
                client._closeSocket();
                client._onClosed();
                return;
            }
            client._awaitingPong = true;
            client.call({ type: "ping" }).then(function () { client._awaitingPong = false; },
                                               function () {});
        }
    }

    Timer {
        id: batchTimer
        interval: 120
        onTriggered: client.revision++
    }

    // Icon data can arrive while a binding is being evaluated: refresh later.
    Timer {
        id: iconTimer
        interval: 30
        onTriggered: client.iconRevision++
    }

    Timer {
        id: metaRetryTimer
        interval: 30000
        onTriggered: client._loadIconMeta()
    }

    // ------------------------------------------------------------ protocol

    function _onMessage(text) {
        var msg;
        try {
            msg = JSON.parse(text);
        } catch (e) {
            return;
        }
        if (Array.isArray(msg))
            msg.forEach(_handle);
        else
            _handle(msg);
    }

    function _handle(m) {
        var p;
        switch (m.type) {
        case "auth_required":
            socket.sendTextMessage(JSON.stringify({ type: "auth", access_token: token.trim() }));
            break;
        case "auth_ok":
            haVersion = m.ha_version || "";
            status = "loading";
            errorText = "";
            _retryDelay = 2000;
            _awaitingPong = false;
            _loadAll();
            break;
        case "auth_invalid":
            _authFailed = true;
            status = "error";
            errorText = "Jeton refusé par Home Assistant" + (m.message ? " : " + m.message : "");
            _closeSocket();
            break;
        case "result":
            p = _pending[m.id];
            if (p) {
                delete _pending[m.id];
                if (m.success)
                    p.resolve(m.result);
                else
                    p.reject(m.error || { code: "unknown", message: "Erreur inconnue" });
            }
            break;
        case "pong":
            p = _pending[m.id];
            if (p) {
                delete _pending[m.id];
                p.resolve(true);
            }
            break;
        case "event":
            var h = _subs[m.id];
            if (h)
                h(m.event);
            break;
        }
    }

    function _send(msg, handler) {
        return new Promise(function (resolve, reject) {
            if (socket.status !== WebSocket.Open) {
                reject({ code: "not_connected", message: "Non connecté" });
                return;
            }
            var id = client._nextId++;
            msg.id = id;
            client._pending[id] = { resolve: resolve, reject: reject };
            if (handler)
                client._subs[id] = handler;
            socket.sendTextMessage(JSON.stringify(msg));
        });
    }

    function call(msg) {
        return _send(msg, null);
    }

    // Resolves to the subscription id, to pass to unsubscribe().
    function subscribe(msg, handler) {
        return _send(msg, handler).then(function () {
            return msg.id;
        }, function (e) {
            delete client._subs[msg.id];
            throw e;
        });
    }

    function unsubscribe(subId) {
        if (!subId || !_subs[subId])
            return;
        delete _subs[subId];
        if (socket.status === WebSocket.Open)
            call({ type: "unsubscribe_events", subscription: subId }).catch(function () {});
    }

    function callService(domain, service, data, target) {
        var m = { type: "call_service", domain: domain, service: service, service_data: data || {} };
        if (target)
            m.target = target;
        return call(m).catch(function (e) {
            var text = (e && e.message) ? e.message : JSON.stringify(e);
            console.warn("HA call_service " + domain + "." + service + " failed: " + text);
            client.serviceError(domain + "." + service + " : " + text);
        });
    }

    function history(entityIds, hours) {
        var end = new Date();
        var start = new Date(end.getTime() - hours * 3600 * 1000);
        return call({
            type: "history/history_during_period",
            start_time: start.toISOString(),
            end_time: end.toISOString(),
            entity_ids: entityIds,
            minimal_response: true,
            no_attributes: true,
            significant_changes_only: false
        });
    }

    function _loadAll() {
        function fallback(value, what) {
            return function (e) {
                console.warn("HA " + what + " failed: " + JSON.stringify(e));
                return value;
            };
        }
        var lang = language;
        Promise.all([
            call({ type: "get_config" }).catch(fallback({}, "get_config")),
            call({ type: "frontend/get_user_data", key: "language" }).catch(fallback({}, "user language"))
        ]).then(function (first) {
            client.haConfig = first[0] || {};
            var pref = (first[1] && first[1].value) || {};
            lang = pref.language || client.haConfig.language || Qt.locale().name.split("_")[0];
            client.language = lang;
            var fmt = pref.number_format || "language";
            if (fmt === "system")
                client.locale = Qt.locale();
            else if (fmt === "comma_decimal")
                client.locale = Qt.locale("en_US");
            else if (fmt === "decimal_comma")
                client.locale = Qt.locale("de_DE");
            else if (fmt === "space_comma")
                client.locale = Qt.locale("fr_FR");
            else
                client.locale = Qt.locale(lang.replace("-", "_"));
            return client._loadRest(lang);
        }).catch(function (e) {
            client.status = "error";
            client.errorText = "Chargement impossible : " + ((e && e.message) ? e.message : JSON.stringify(e));
        });
    }

    function _loadRest(lang) {
        function fallback(value, what) {
            return function (e) {
                console.warn("HA " + what + " failed: " + JSON.stringify(e));
                return value;
            };
        }
        return Promise.all([
            Promise.resolve(client.haConfig),
            call({ type: "get_states" }),
            call({ type: "config/entity_registry/list" }).catch(fallback([], "entity registry")),
            call({ type: "config/device_registry/list" }).catch(fallback([], "device registry")),
            call({ type: "config/area_registry/list" }).catch(fallback([], "area registry")),
            call({ type: "frontend/get_icons", category: "entity_component" }).catch(fallback({ resources: {} }, "icons")),
            call({ type: "frontend/get_translations", language: lang, category: "entity_component" }).catch(fallback({ resources: {} }, "translations")),
            call({ type: "frontend/get_translations", language: lang, category: "title" }).catch(fallback({ resources: {} }, "titles")),
            call({ type: "config/floor_registry/list" }).catch(fallback([], "floor registry")),
            call({ type: "auth/current_user" }).catch(fallback({}, "current user"))
        ]).then(function (r) {
            var fl = {}, forder = [];
            (r[8] || []).forEach(function (f) { fl[f.floor_id] = f; forder.push(f.floor_id); });
            client.floors = fl;
            client.floorOrder = forder;
            client.userName = (r[9] && r[9].name) || "";

            var st = {};
            r[1].forEach(function (s) { st[s.entity_id] = s; });
            client.states = st;

            var ents = {}, platforms = {};
            r[2].forEach(function (e) {
                ents[e.entity_id] = e;
                if (e.translation_key && e.platform)
                    platforms[e.platform] = true;
            });
            client.entities = ents;

            var devs = {};
            r[3].forEach(function (d) { devs[d.id] = d; });
            client.devices = devs;

            var ars = {}, order = [];
            r[4].forEach(function (a) { ars[a.area_id] = a; order.push(a.area_id); });
            client.areas = ars;
            client.areaOrder = order;

            client.iconDefs = (r[5] && r[5].resources) || {};

            var tr = {};
            [r[6], r[7]].forEach(function (x) {
                var res = (x && x.resources) || {};
                for (var k in res) tr[k] = res[k];
            });

            var plist = Object.keys(platforms);
            if (plist.length === 0) {
                client.translations = tr;
                return null;
            }
            return Promise.all([
                client.call({ type: "frontend/get_icons", category: "entity", integration: plist }).catch(fallback({ resources: {} }, "entity icons")),
                client.call({ type: "frontend/get_translations", language: lang, category: "entity", integration: plist }).catch(fallback({ resources: {} }, "entity translations"))
            ]).then(function (x) {
                client.entityIconDefs = (x[0] && x[0].resources) || {};
                var res = (x[1] && x[1].resources) || {};
                for (var k in res) tr[k] = res[k];
                client.translations = tr;
            });
        }).then(function () {
            return client.subscribe({ type: "subscribe_events", event_type: "state_changed" }, client._onStateChanged);
        }).then(function () {
            client.subscribe({ type: "subscribe_events", event_type: "lovelace_updated" }, function (ev) {
                client.lovelaceUpdated(ev && ev.data ? ev.data.url_path : null);
            }).catch(function () {});
            client.revision++;
            client.connectionId++;
            client.status = "ready";
            pingTimer.start();
            client.loaded();
        });
    }

    function _onStateChanged(ev) {
        var d = ev.data;
        if (!d || !d.entity_id)
            return;
        if (d.new_state)
            states[d.entity_id] = d.new_state;
        else
            delete states[d.entity_id];
        if (!batchTimer.running)
            batchTimer.start();
    }

    // ------------------------------------------------------------ icons
    // HA serves the MDI icon set as JSON chunks under /static/mdi/.
    // We fetch them like the web frontend does, so icons match exactly.

    function iconPath(icon) {
        if (!icon)
            return "";
        var s = String(icon);
        var i = s.indexOf(":");
        var prefix = i >= 0 ? s.substring(0, i) : "mdi";
        var name = i >= 0 ? s.substring(i + 1) : s;
        if (["mdi", "hass", "hassio", "hademo"].indexOf(prefix) < 0)
            name = "bookmark-outline"; // custom icon sets are not supported
        var icons = _icons;
        var cached = icons.cache[name];
        if (cached !== undefined)
            return cached;
        if (!icons.meta) {
            Qt.callLater(_loadIconMeta);
            return "";
        }
        var file = _findChunk(icons.meta, name);
        var chunk = icons.chunks[file];
        if (chunk === undefined) {
            icons.chunks[file] = null;
            // One closure per file: Qt.callLater merges calls to the same function.
            Qt.callLater(function () { client._loadChunk(file); });
            return "";
        }
        if (chunk === null)
            return ""; // still loading
        var p = chunk[name] || "";
        icons.cache[name] = p;
        return p;
    }

    function _getJson(url, cb) {
        var x = new XMLHttpRequest();
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE)
                return;
            var data = null;
            if (x.status === 200) {
                try {
                    data = JSON.parse(x.responseText);
                } catch (e) {
                    data = null;
                }
            }
            cb(data);
        };
        x.open("GET", url);
        x.send();
    }

    function _loadIconMeta() {
        var icons = _icons;
        if (icons.loading || icons.meta || cleanUrl === "")
            return;
        icons.loading = true;
        var base = cleanUrl;
        _getJson(base + "/static/mdi/iconMetadata.json", function (meta) {
            icons.loading = false;
            if (icons !== client._icons)
                return;
            if (meta && meta.parts) {
                icons.meta = meta;
                iconTimer.restart();
            } else {
                metaRetryTimer.start();
            }
        });
    }

    function _findChunk(meta, name) {
        var parts = meta.parts, last = parts[0];
        for (var i = 0; i < parts.length; i++) {
            if (parts[i].start !== undefined && name < parts[i].start)
                break;
            last = parts[i];
        }
        return last.file;
    }

    function _loadChunk(file) {
        var icons = _icons;
        _getJson(cleanUrl + "/static/mdi/" + file + ".json", function (data) {
            if (icons !== client._icons)
                return;
            icons.chunks[file] = data || {};
            iconTimer.restart();
        });
    }
}
