import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha
import "../../code/Strategy.js" as Strategy

// Home dashboard "home-summary" card (lights on, temperatures, security...)
// and "shortcut" card (icon + label + link).
CardFrame {
    id: card

    readonly property bool isShortcut: config.type === "shortcut"
    readonly property string key: config.summary || ""
    readonly property color accent: dash.tint(isShortcut ? (config.color || "primary") : (Strategy.SUMMARY_COLORS[key] || "primary"),
                                              Kirigami.Theme.highlightColor)

    function plural(n, one, many) {
        return n + " " + (n > 1 ? many : one);
    }

    readonly property string summaryText: {
        if (isShortcut)
            return "";
        client.revision;
        var ids = Strategy.summaryEntities(client, key);
        var st = function (id) { return client.states[id] ? client.states[id].state : ""; };
        switch (key) {
        case "light":
            var on = ids.filter(function (id) { return st(id) === "on"; }).length;
            return on ? plural(on, "allumée", "allumées") : "Toutes éteintes";
        case "climate":
            var temps = [];
            client.areaOrder.forEach(function (a) {
                var t = client.areas[a].temperature_entity_id;
                if (t && Ha.isNumeric(st(t)))
                    temps.push(Number(st(t)));
            });
            if (!temps.length)
                return "";
            var lo = Ha.formatNumber(client, Math.min.apply(null, temps), 1);
            var hi = Ha.formatNumber(client, Math.max.apply(null, temps), 1);
            return lo === hi ? lo + "°" : lo + " – " + hi + "°";
        case "security":
            var locks = ids.filter(function (id) { return Ha.domainOf(id) === "lock"; });
            var alarms = ids.filter(function (id) { return Ha.domainOf(id) === "alarm_control_panel"; });
            if (!locks.length && !alarms.length)
                return "";
            var open = locks.filter(function (id) { return ["unlocked", "jammed", "open"].indexOf(st(id)) >= 0; }).length;
            if (open)
                return plural(open, "déverrouillée", "déverrouillées");
            var disarmed = alarms.filter(function (id) { return st(id) === "disarmed"; }).length;
            if (disarmed)
                return plural(disarmed, "alarme désarmée", "alarmes désarmées");
            return "Tout est sécurisé";
        case "media_players":
            var playing = ids.filter(function (id) { return st(id) === "playing"; }).length;
            return playing ? plural(playing, "en lecture", "en lecture") : "Rien en lecture";
        case "maintenance":
            var issues = ids.filter(function (id) {
                var s = client.states[id];
                if (Ha.domainOf(id) === "sensor")
                    return Ha.isNumeric(s.state) && Number(s.state) <= 20;
                return s.state === "on";
            }).length;
            return issues ? plural(issues, "alerte", "alertes") : "Tout est en ordre";
        default:
            return "";
        }
    }

    implicitHeight: row.implicitHeight + 2 * padding

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Ha.runAction(card.client, card.dash, card.config.tap_action, null, "none")
    }

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.padding
        spacing: Kirigami.Units.largeSpacing

        Rectangle {
            implicitWidth: Kirigami.Units.gridUnit * 2.2
            implicitHeight: implicitWidth
            radius: width / 2
            color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.2)
            HaIcon {
                anchors.centerIn: parent
                client: card.client
                icon: card.isShortcut ? (card.config.icon || "mdi:link") : (Strategy.SUMMARY_ICONS[card.key] || "mdi:information")
                color: card.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PC3.Label {
                Layout.fillWidth: true
                text: card.isShortcut ? (card.config.label || "") : (Strategy.SUMMARY_LABELS[card.key] || card.key)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            PC3.Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.summaryText
                font: Kirigami.Theme.smallFont
                opacity: 0.75
                elide: Text.ElideRight
            }
        }
    }
}
