import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../code/Ha.js" as Ha
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
        currentView = i;
        viewSelected(i);
    }

    function navigate(path) {
        if (!path)
            return;
        var p = String(path).split("?")[0].replace(/^#/, "");
        var segs = p.split("/").filter(function (s) { return s !== ""; });
        var last = segs.length ? segs[segs.length - 1] : "";
        for (var i = 0; i < views.length; i++) {
            if (views[i].path && String(views[i].path) === last) {
                selectView(i);
                return;
            }
        }
        if (/^\d+$/.test(last) && Number(last) < views.length) {
            selectView(Number(last));
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

    function loadConfig() {
        if (!client || !client.ready)
            return;
        var path = dashboardPath.trim();
        client.call({ type: "lovelace/config", url_path: path === "" ? null : path, force: false })
            .then(function (raw) {
                dash.dashboard = Strategy.resolveDashboard(dash.client, raw);
                dash.loadError = "";
            }, function (err) {
                if (err && err.code === "config_not_found" && path === "") {
                    dash.dashboard = Strategy.resolveDashboard(dash.client, null);
                    dash.loadError = "";
                } else {
                    dash.dashboard = null;
                    dash.loadError = "Tableau de bord « " + (path || "par défaut") + " » introuvable : "
                                     + ((err && err.message) ? err.message : JSON.stringify(err));
                }
            });
    }

    Component.onCompleted: {
        currentView = viewIndex;
        loadConfig();
    }
    onViewIndexChanged: currentView = viewIndex
    onDashboardPathChanged: loadConfig()

    Connections {
        target: dash.client
        function onLoaded() { dash.loadConfig(); }
        function onLovelaceUpdated(urlPath) {
            var mine = dash.dashboardPath.trim();
            if ((urlPath || "") === mine || (!urlPath && mine === "lovelace"))
                dash.loadConfig();
        }
        function onServiceError(message) { dash.flash("Action refusée : " + message); }
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

            Flow {
                Layout.fillWidth: true
                visible: dash.tabIndices.length > 1
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: dash.tabIndices
                    delegate: PC3.ToolButton {
                        required property int modelData
                        readonly property var v: dash.views[modelData]
                        text: v.title || v.path || ("Vue " + (modelData + 1))
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
                visible: dash.tabIndices.length <= 1
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
                PC3.ToolTip.text: dash.client.ready ? "Connecté à Home Assistant " + dash.client.haVersion : dash.client.errorText
                PC3.ToolTip.visible: statusHover.hovered
                HoverHandler { id: statusHover }
            }

            PC3.ToolButton {
                icon.name: "view-refresh"
                display: QQC2.AbstractButton.IconOnly
                text: "Recharger"
                PC3.ToolTip.text: text
                PC3.ToolTip.visible: hovered
                onClicked: dash.client.reconnect()
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: dash.dashboard !== null && !dash.client.ready
            type: dash.client.status === "error" ? Kirigami.MessageType.Error : Kirigami.MessageType.Warning
            text: dash.client.status === "error" ? dash.client.errorText : "Reconnexion à Home Assistant…"
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
                text: dash.client.status === "unconfigured" ? "Widget non configuré"
                      : (dash.loadError !== "" ? "Tableau de bord indisponible" : "Connexion impossible")
                explanation: dash.client.status === "unconfigured"
                             ? "Renseignez l'adresse de Home Assistant et un jeton d'accès longue durée."
                             : (dash.loadError !== "" ? dash.loadError : dash.client.errorText)
                helpfulAction: Kirigami.Action {
                    icon.name: dash.client.status === "unconfigured" ? "configure" : "view-refresh"
                    text: dash.client.status === "unconfigured" ? "Configurer…" : "Réessayer"
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
