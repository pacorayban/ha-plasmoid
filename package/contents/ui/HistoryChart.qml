import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../code/Ha.js" as Ha

// History of one or more entities: numeric ones as lines, others as timelines.
// `compact` draws a bare sparkline (used by the sensor card).
Item {
    id: chart

    property var client
    property var dash
    property var entityIds: []
    property real hours: 24
    property bool compact: false
    property real lineHeight: Kirigami.Units.gridUnit * (compact ? 3 : 6)

    property var series: []
    property var _alive: ({ v: true })
    readonly property var palette: ["#03a9f4", "#ff9800", "#4caf50", "#e91e63", "#9c27b0", "#00bcd4", "#ffc107", "#795548"]
    readonly property var numericSeries: series.filter(function (s) { return s.numeric; })
    readonly property var timelineSeries: series.filter(function (s) { return !s.numeric; })
    readonly property color textColor: Kirigami.Theme.textColor

    implicitHeight: layout.implicitHeight

    function load() {
        if (!client || !client.ready || entityIds.length === 0)
            return;
        var ids = entityIds.slice();
        var alive = _alive;
        client.history(ids, hours).then(function (res) {
            if (alive.v)
                chart.build(ids, res || {});
        }, function (e) {
            console.warn("HA history failed: " + JSON.stringify(e));
        });
    }

    function build(ids, res) {
        var out = [];
        for (var i = 0; i < ids.length; i++) {
            var id = ids[i];
            var pts = (res[id] || []).map(function (p) {
                var t = p.lu !== undefined ? p.lu * 1000 : Date.parse(p.last_updated || p.last_changed);
                return { t: t, s: p.s !== undefined ? p.s : p.state };
            });
            var st = client.states[id];
            if (st && (pts.length === 0 || pts[pts.length - 1].s !== st.state))
                pts.push({ t: Date.parse(st.last_updated), s: st.state });
            var someNum = pts.some(function (p) { return Ha.isNumeric(p.s); });
            var allNum = pts.every(function (p) { return Ha.isNumeric(p.s) || p.s === "unavailable" || p.s === "unknown"; });
            out.push({
                id: id,
                numeric: someNum && allNum,
                points: pts,
                color: palette[i % palette.length],
                unit: st && st.attributes ? (st.attributes.unit_of_measurement || "") : ""
            });
        }
        series = out;
        repaint();
    }

    function appendLive() {
        var changed = false;
        for (var i = 0; i < series.length; i++) {
            var s = series[i];
            var st = client.states[s.id];
            if (!st)
                continue;
            var t = Date.parse(st.last_updated);
            var last = s.points.length ? s.points[s.points.length - 1] : null;
            if (!last || t > last.t) {
                s.points.push({ t: t, s: st.state });
                changed = true;
            }
        }
        if (changed)
            repaint();
    }

    function repaint() {
        lineCanvas.requestPaint();
        timelineRepeater.model = null;
        timelineRepeater.model = timelineSeries;
    }

    onEntityIdsChanged: load()
    onHoursChanged: load()
    Component.onCompleted: load()
    Component.onDestruction: _alive.v = false

    Connections {
        target: chart.client
        function onConnectionIdChanged() { chart.load(); }
        function onRevisionChanged() { chart.appendLive(); }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: chart.repaint()
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.smallSpacing

        Canvas {
            id: lineCanvas
            Layout.fillWidth: true
            Layout.preferredHeight: chart.numericSeries.length > 0 ? chart.lineHeight : 0
            visible: chart.numericSeries.length > 0
            renderStrategy: Canvas.Cooperative

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var list = chart.numericSeries;
                if (list.length === 0 || width <= 0 || height <= 0)
                    return;
                var t1 = Date.now(), t0 = t1 - chart.hours * 3600 * 1000;
                var lo = Infinity, hi = -Infinity;
                list.forEach(function (s) {
                    s.points.forEach(function (p) {
                        if (Ha.isNumeric(p.s)) {
                            var v = Number(p.s);
                            lo = Math.min(lo, v);
                            hi = Math.max(hi, v);
                        }
                    });
                });
                if (!isFinite(lo))
                    return;
                if (hi - lo < 1e-9) { hi += 1; lo -= 1; }
                var pad = (hi - lo) * 0.1;
                lo -= pad; hi += pad;
                var top = chart.compact ? 2 : 4, bottom = height - 2;
                var left = 0, right = width;
                function X(t) { return left + (Math.max(t, t0) - t0) / (t1 - t0) * (right - left); }
                function Y(v) { return bottom - (v - lo) / (hi - lo) * (bottom - top); }

                list.forEach(function (s) {
                    ctx.beginPath();
                    var started = false, lastY = 0;
                    for (var i = 0; i < s.points.length; i++) {
                        var p = s.points[i];
                        if (!Ha.isNumeric(p.s)) { started = false; continue; }
                        var x = X(p.t), y = Y(Number(p.s));
                        if (!started) { ctx.moveTo(x, y); started = true; }
                        else ctx.lineTo(x, y);
                        lastY = y;
                    }
                    if (started)
                        ctx.lineTo(right, lastY);
                    ctx.strokeStyle = s.color;
                    ctx.lineWidth = 2;
                    ctx.lineJoin = "round";
                    ctx.stroke();
                    if (list.length === 1) {
                        ctx.lineTo(right, bottom);
                        var firstX = X(s.points[0].t);
                        ctx.lineTo(firstX, bottom);
                        ctx.closePath();
                        var sc = Qt.lighter(s.color, 1.0);
                        ctx.fillStyle = Qt.rgba(sc.r, sc.g, sc.b, 0.15);
                        ctx.fill();
                    }
                });

                if (!chart.compact) {
                    ctx.fillStyle = Qt.rgba(chart.textColor.r, chart.textColor.g, chart.textColor.b, 0.6);
                    ctx.font = Math.round(Kirigami.Theme.smallFont.pixelSize > 0 ? Kirigami.Theme.smallFont.pixelSize : 11) + "px sans-serif";
                    var unit = list[0].unit;
                    ctx.fillText(Ha.formatNumber(chart.client, hi - pad, 1) + " " + unit, 2, 12);
                    ctx.fillText(Ha.formatNumber(chart.client, lo + pad, 1) + " " + unit, 2, bottom - 4);
                }
            }
        }

        Repeater {
            id: timelineRepeater
            model: chart.timelineSeries
            delegate: ColumnLayout {
                id: tl
                required property var modelData
                Layout.fillWidth: true
                spacing: 2

                PC3.Label {
                    visible: !chart.compact
                    text: Ha.entityName(chart.client, tl.modelData.id, chart.client.states[tl.modelData.id])
                    font: Kirigami.Theme.smallFont
                    opacity: 0.8
                }
                Canvas {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit
                    onWidthChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        var pts = tl.modelData.points;
                        var t1 = Date.now(), t0 = t1 - chart.hours * 3600 * 1000;
                        for (var i = 0; i < pts.length; i++) {
                            var a = Math.max(pts[i].t, t0);
                            var b = i + 1 < pts.length ? pts[i + 1].t : t1;
                            if (b <= t0) continue;
                            var x0 = (a - t0) / (t1 - t0) * width, x1 = (b - t0) / (t1 - t0) * width;
                            var fake = { state: pts[i].s, attributes: {} };
                            var c = Ha.isActive(tl.modelData.id, fake) ? Ha.activeColor(tl.modelData.id, fake) : "";
                            var col = chart.dash.tint(c, Kirigami.Theme.disabledTextColor);
                            ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, c === "" ? 0.35 : 0.85);
                            ctx.fillRect(x0, 0, Math.max(1, x1 - x0), height);
                        }
                    }
                }
            }
        }

        Flow {
            Layout.fillWidth: true
            visible: !chart.compact && chart.numericSeries.length > 1
            spacing: Kirigami.Units.largeSpacing
            Repeater {
                model: chart.numericSeries
                delegate: Row {
                    required property var modelData
                    spacing: Kirigami.Units.smallSpacing
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10; height: 10; radius: 5
                        color: modelData.color
                    }
                    PC3.Label {
                        text: Ha.entityName(chart.client, modelData.id, chart.client.states[modelData.id])
                        font: Kirigami.Theme.smallFont
                    }
                }
            }
        }
    }
}
