import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../code/Ha.js" as Ha
import "../code/Tr.js" as Tr
import "../code/Strategy.js" as Strategy

// Loads a Lovelace dashboard and shows one of its views, with tabs.
// Also provides the helpers cards call through `dash` (tint, moreInfo, navigate...).
Item {
    id: dash

    property var client
    property string dashboardPath: ""
    property int viewIndex: 0
    property int columnWidth: 320
    property real cardOpacity: 0.8
    property bool showHeader: true

    signal viewSelected(int index)
    signal configureRequested()

    property var dashboard: null
    property string loadError: ""
    property int currentView: 0
    property string flashText: ""
    property var backStack: []

    // The setting may be a bare path ("dashboard-music") or a full URL copied from
    // the browser ("https://ha.example/dashboard-music/0"): keep dashboard + view.
    function parseTarget(s) {
        var t = String(s || "").trim().replace(/^[a-z][a-z0-9+.-]*:\/\/[^\/]+/i, "");
        t = t.split("?")[0].split("#")[0];
        var segs = t.split("/").filter(function (x) { return x !== ""; });
        return { path: segs.length ? decodeURIComponent(segs[0]) : "",
                 view: segs.length > 1 ? decodeURIComponent(segs[1]) : "" };
    }

    readonly property var views: dashboard ? dashboard.views : []
    readonly property var tabIndices: {
        var out = [];
        for (var i = 0; i < views.length; i++)
            if (!views[i].subview)
                out.push(i);
        return out;
    }
    readonly property var view: views.length ? views[Math.max(0, Math.min(currentView, views.length - 1))] : null

    readonly property color iconColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.75)
    readonly property color disabledColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.4)

    // ------------------------------------------------------------ helpers used by cards

    // Turns a color name from Ha.js / card config into a color. "" -> fallback.
    function tint(c, fallback) {
        if (!c)
            return fallback;
        if (c === "primary" || c === "accent")
            return Kirigami.Theme.highlightColor;
        if (c === "disabled" || c === "none")
            return disabledColor;
        var named = Ha.NAMED_COLORS[c];
        return Qt.lighter(named || c, 1.0);
    }

    function moreInfo(entityId) {
        if (entityId)
            moreInfoPopup.openFor(entityId);
    }

    function selectView(i) {
        var target = views[i];
        if (target && target.subview) {
            var stack = backStack.slice();
            stack.push(currentView);
            backStack = stack;
        } else {
            backStack = [];
            viewSelected(i);
        }
        currentView = i;
    }

    function goBack() {
        var stack = backStack.slice();
        var prev = stack.length ? stack.pop() : 0;
        backStack = stack;
        currentView = prev;
    }

    function viewIndexFor(key) {
        for (var i = 0; i < views.length; i++)
            if (views[i].path !== undefined && String(views[i].path) === key)
                return i;
        if (/^\d+$/.test(key) && Number(key) < views.length)
            return Number(key);
        return -1;
    }

    function navigate(path) {
        if (!path)
            return;
        var p = String(path).split("?")[0].replace(/^#/, "");
        var segs = p.split("/").filter(function (s) { return s !== ""; });
        var last = segs.length ? segs[segs.length - 1] : "";
        var idx = viewIndexFor(last);
        if (idx >= 0) {
            selectView(idx);
            return;
        }
        openUrl(p.charAt(0) === "/" ? p : "/" + p);
    }

    function openUrl(url) {
        if (!url)
            return;
        Qt.openUrlExternally(Ha.absoluteUrl(client, url));
    }

    function flash(message) {
        flashText = message;
        flashTimer.restart();
    }

    // ------------------------------------------------------------ loading

    // Each load gets a number; answers from an older load are ignored.
    property int _loadGen: 0

    function setDashboard(d, t) {
        var keep = dashboard && view ? view.path : undefined;
        dashboard = d;
        loadError = "";
        var idx = -1;
        if (keep !== undefined)
            idx = viewIndexFor(String(keep));        // reload: stay on the same view
        if (idx < 0 && t.view !== "")
            idx = viewIndexFor(t.view);              // view given in the URL (may be a sub-view)
        if (idx < 0) {
            idx = Math.min(viewIndex, Math.max(0, views.length - 1));
            if (!views[idx] || views[idx].subview)
                idx = 0;
        }
        if (!views[idx] || !views[idx].subview)
            backStack = [];
        currentView = idx;
    }

    // HA's "Home" panel (/home): generated from its own settings and usage predictions.
    function loadHome(gen, t) {
        var cl = client;
        Promise.all([
            cl.call({ type: "frontend/get_system_data", key: "home" }).catch(function () { return { value: null }; }),
            cl.call({ type: "usage_prediction/common_control" }).catch(function () { return { entities: [] }; })
        ]).then(function (r) {
            if (gen === dash._loadGen)
                dash.setDashboard(Strategy.generateHome(cl, (r[0] && r[0].value) || {}, (r[1] && r[1].entities) || []), t);
        });
    }

    function loadConfig() {
        if (!client || !client.ready)
            return;
        // Parse here rather than reading `target`: when the setting just changed,
        // that binding may not be updated yet and would still hold the old URL.
        var t = parseTarget(dashboardPath);
        var gen = ++_loadGen;
        loadError = "";
        if (t.path === "home") {
            loadHome(gen, t);
            return;
        }
        var urlPath = (t.path === "" || t.path === "lovelace") ? null : t.path;
        client.call({ type: "lovelace/config", url_path: urlPath, force: false })
            .then(function (raw) {
                if (gen === dash._loadGen)
                    dash.setDashboard(Strategy.resolveDashboard(dash.client, raw), t);
            }, function (err) {
                if (gen !== dash._loadGen)
                    return;
                if (err && err.code === "config_not_found" && urlPath === null) {
                    // No "Overview" dashboard: like the web UI, fall back to the Home panel.
                    dash.loadHome(gen, t);
                } else {
                    dash.dashboard = null;
                    dash.loadError = Tr.tr(dash.client, "Dashboard “%1” not found: %2",
                                           t.path || Tr.tr(dash.client, "default"),
                                           (err && err.message) ? err.message : JSON.stringify(err));
                }
            });
    }

    Component.onCompleted: loadConfig()
    onDashboardPathChanged: {
        dashboard = null;
        loadConfig();
    }

    Connections {
        target: dash.client
        function onLoaded() { dash.loadConfig(); }
        function onLovelaceUpdated(urlPath) {
            var mine = dash.parseTarget(dash.dashboardPath).path;
            if ((urlPath || "") === mine || (!urlPath && mine === "lovelace"))
                dash.loadConfig();
        }
        function onServiceError(message) { dash.flash(Tr.tr(dash.client, "Action refused: %1", message)); }
    }

    Timer {
        id: flashTimer
        interval: 6000
        onTriggered: dash.flashText = ""
    }

    // ------------------------------------------------------------ UI

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            visible: dash.showHeader && dash.dashboard !== null
            spacing: Kirigami.Units.smallSpacing

            PC3.ToolButton {
                visible: !!dash.view && !!dash.view.subview
                icon.name: "go-previous"
                text: Tr.tr(dash.client, "Back")
                display: QQC2.AbstractButton.IconOnly
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered
                onClicked: dash.goBack()
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                visible: !!dash.view && !!dash.view.subview
                level: 4
                text: dash.view && dash.view.title ? dash.view.title : ""
                elide: Text.ElideRight
            }

            Flow {
                Layout.fillWidth: true
                visible: dash.tabIndices.length > 1 && !(dash.view && dash.view.subview)
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: dash.tabIndices
                    delegate: PC3.ToolButton {
                        required property int modelData
                        readonly property var v: dash.views[modelData]
                        text: v.title || v.path || Tr.tr(dash.client, "View %1", modelData + 1)
                        checkable: true
                        checked: dash.currentView === modelData
                        onClicked: {
                            dash.selectView(modelData);
                            checked = Qt.binding(function () { return dash.currentView === modelData; });
                        }
                    }
                }
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                visible: dash.tabIndices.length <= 1 && !(dash.view && dash.view.subview)
                level: 4
                text: dash.view && dash.view.title && !(dash.dashboard && dash.dashboard.generated)
                      ? dash.view.title : (dash.dashboard ? dash.dashboard.title : "")
                elide: Text.ElideRight
            }

            Rectangle {
                width: Kirigami.Units.smallSpacing * 2
                height: width
                radius: width / 2
                color: dash.client.ready ? "#4caf50" : (dash.client.status === "error" ? "#f44336" : "#ff9800")
                PC3.ToolTip.text: dash.client.ready ? Tr.tr(dash.client, "Connected to Home Assistant %1", dash.client.haVersion) : dash.client.errorText
                PC3.ToolTip.visible: statusHover.hovered
                HoverHandler { id: statusHover }
            }

            PC3.ToolButton {
                icon.name: "view-refresh"
                display: QQC2.AbstractButton.IconOnly
                text: Tr.tr(dash.client, "Reload")
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered
                onClicked: dash.client.reconnect()
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: dash.dashboard !== null && !dash.client.ready
            type: dash.client.status === "error" ? Kirigami.MessageType.Error : Kirigami.MessageType.Warning
            text: dash.client.status === "error" ? dash.client.errorText : Tr.tr(dash.client, "Reconnecting to Home Assistant…")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: dash.flashText !== ""
            type: Kirigami.MessageType.Error
            text: dash.flashText
            showCloseButton: true
        }

        // Empty states: not configured, connecting, error.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: dash.dashboard === null

            PC3.BusyIndicator {
                anchors.centerIn: parent
                visible: dash.loadError === "" && (dash.client.status === "connecting" || dash.client.status === "loading"
                                                   || dash.client.status === "idle" || dash.client.ready)
                running: visible
            }

            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 2
                visible: dash.client.status === "unconfigured" || dash.client.status === "error" || dash.loadError !== ""
                icon.name: dash.client.status === "unconfigured" ? "configure" : "network-disconnect"
                text: dash.client.status === "unconfigured" ? Tr.tr(dash.client, "Widget not configured")
                      : (dash.loadError !== "" ? Tr.tr(dash.client, "Dashboard unavailable") : Tr.tr(dash.client, "Cannot connect"))
                explanation: dash.client.status === "unconfigured"
                             ? Tr.tr(dash.client, "Enter the Home Assistant address and a long-lived access token.")
                             : (dash.loadError !== "" ? dash.loadError : dash.client.errorText)
                helpfulAction: Kirigami.Action {
                    icon.name: dash.client.status === "unconfigured" ? "configure" : "view-refresh"
                    text: dash.client.status === "unconfigured" ? Tr.tr(dash.client, "Configure…") : Tr.tr(dash.client, "Retry")
                    onTriggered: {
                        if (dash.client.status === "unconfigured")
                            dash.configureRequested();
                        else
                            dash.client.reconnect();
                    }
                }
            }
        }

        PC3.ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: dash.dashboard !== null
            contentWidth: availableWidth
            PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff

            ViewContent {
                width: scroll.availableWidth
                view: dash.view
                client: dash.client
                dash: dash
                columnWidth: dash.columnWidth
            }
        }
    }

    MoreInfo {
        id: moreInfoPopup
        client: dash.client
        dash: dash
    }
}
