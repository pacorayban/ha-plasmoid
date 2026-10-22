import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha

// HA "gauge" card: half-circle gauge with severity colors.
CardFrame {
    id: card

    readonly property string entityId: config.entity || ""
    readonly property var st: { client.revision; return client.states[entityId]; }
    readonly property var attrs: st && st.attributes ? st.attributes : ({})
    readonly property var raw: config.attribute ? attrs[config.attribute] : (st ? st.state : undefined)
    readonly property bool numeric: Ha.isNumeric(raw)
    readonly property real minV: Number(config.min !== undefined ? config.min : 0)
    readonly property real maxV: Number(config.max !== undefined ? config.max : 100)
    readonly property real value: numeric ? Number(raw) : minV
    readonly property real ratio: Math.max(0, Math.min(1, (value - minV) / ((maxV - minV) || 1)))
    readonly property color gaugeColor: {
        var sev = config.severity;
        if (sev && numeric) {
            var levels = [["red", sev.red], ["yellow", sev.yellow], ["green", sev.green]]
                .filter(function (l) { return l[1] !== undefined; })
                .sort(function (a, b) { return b[1] - a[1]; });
            for (var i = 0; i < levels.length; i++)
                if (value >= levels[i][1])
                    return levels[i][0] === "red" ? "#db4437" : levels[i][0] === "yellow" ? "#ffa600" : "#43a047";
        }
        return Kirigami.Theme.highlightColor;
    }

    implicitHeight: col.implicitHeight + 2 * padding

    onRatioChanged: canvas.requestPaint()
    onGaugeColorChanged: canvas.requestPaint()

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Ha.runAction(card.client, card.dash, card.config.tap_action, card.entityId, "more-info")
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.padding
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(col.width, Kirigami.Units.gridUnit * 12) / 2 + Kirigami.Units.smallSpacing

            Canvas {
                id: canvas
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(col.width, Kirigami.Units.gridUnit * 12)
                height: width / 2 + 4
                onWidthChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var lw = width * 0.11;
                    var r = width / 2 - lw / 2 - 1;
                    var cx = width / 2, cy = height - 2;
                    var fg = Kirigami.Theme.textColor;
                    ctx.lineWidth = lw;
                    ctx.lineCap = "butt";
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, Math.PI, 2 * Math.PI, false);
                    ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.12);
                    ctx.stroke();
                    if (card.numeric) {
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, Math.PI, Math.PI + Math.PI * card.ratio, false);
                        ctx.strokeStyle = card.gaugeColor;
                        ctx.stroke();
                    }
                }
            }

            PC3.Label {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                text: card.numeric
                      ? Ha.withUnit(Ha.formatNumber(card.client, card.raw, Ha.displayPrecision(card.client, card.entityId)),
                                    card.config.unit !== undefined ? card.config.unit : (card.attrs.unit_of_measurement || ""))
                      : Ha.stateDisplay(card.client, card.entityId, card.st)
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.6
            }
        }

        PC3.Label {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            text: Ha.entityName(card.client, card.entityId, card.st, card.config.name)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            opacity: 0.85
        }
    }
}
