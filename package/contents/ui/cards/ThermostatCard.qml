import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha
import "../../code/Tr.js" as Tr

// HA "thermostat" card: ring with the target temperature, +/- and HVAC modes.
CardFrame {
    id: card

    readonly property string entityId: config.entity || ""
    readonly property var st: { client.revision; return client.states[entityId]; }
    readonly property var attrs: st && st.attributes ? st.attributes : ({})
    readonly property string unit: Ha.temperatureUnit(client)
    readonly property bool dual: (attrs.temperature === undefined || attrs.temperature === null)
                                 && attrs.target_temp_low !== undefined && attrs.target_temp_low !== null
    readonly property real minT: Number(attrs.min_temp !== undefined ? attrs.min_temp : 7)
    readonly property real maxT: Number(attrs.max_temp !== undefined ? attrs.max_temp : 35)
    readonly property real step: Number(attrs.target_temp_step || (unit.indexOf("F") >= 0 ? 1 : 0.5))
    readonly property int decimals: step < 1 ? 1 : 0

    property real pending: NaN
    property real pendingLow: NaN
    property real pendingHigh: NaN
    readonly property real target: !isNaN(pending) ? pending : Number(attrs.temperature)
    readonly property real low: !isNaN(pendingLow) ? pendingLow : Number(attrs.target_temp_low)
    readonly property real high: !isNaN(pendingHigh) ? pendingHigh : Number(attrs.target_temp_high)

    readonly property color accent: {
        var c = Ha.activeColor(entityId, st);
        return c === "" ? dash.disabledColor : dash.tint(c, Kirigami.Theme.highlightColor);
    }

    function fmt(v) {
        return isNaN(v) ? "—" : Ha.formatNumber(client, v, decimals);
    }

    function bump(which, dir) {
        function next(v) {
            var base = isNaN(v) ? (minT + maxT) / 2 : v;
            return Math.max(minT, Math.min(maxT, Math.round((base + dir * step) / step) * step));
        }
        if (which === "low") pendingLow = next(low);
        else if (which === "high") pendingHigh = next(high);
        else pending = next(target);
        sendTimer.restart();
    }

    Timer {
        id: sendTimer
        interval: 1500
        onTriggered: {
            var data = card.dual ? { target_temp_low: card.low, target_temp_high: card.high } : { temperature: card.target };
            Ha.svc(card.client, "climate", "set_temperature", card.entityId, data);
            clearTimer.restart();
        }
    }
    Timer {
        id: clearTimer
        interval: 4000
        onTriggered: { card.pending = NaN; card.pendingLow = NaN; card.pendingHigh = NaN; }
    }

    onTargetChanged: ring.requestPaint()
    onLowChanged: ring.requestPaint()
    onHighChanged: ring.requestPaint()
    onAccentChanged: ring.requestPaint()

    implicitHeight: col.implicitHeight + 2 * padding

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.padding
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            PC3.Label {
                Layout.fillWidth: true
                text: Ha.entityName(card.client, card.entityId, card.st, card.config.name)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            IconButton {
                client: card.client
                icon: "mdi:dots-vertical"
                onClicked: card.dash.moreInfo(card.entityId)
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Math.min(col.width, Kirigami.Units.gridUnit * 11)
            implicitHeight: implicitWidth * 0.85

            Canvas {
                id: ring
                anchors.fill: parent
                onWidthChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.reset();
                    var lw = width * 0.06;
                    var r = width / 2 - lw;
                    var cx = width / 2, cy = width / 2;
                    var a0 = Math.PI * 0.75, span = Math.PI * 1.5;
                    var fg = Kirigami.Theme.textColor;
                    ctx.lineCap = "round";
                    ctx.lineWidth = lw;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, a0, a0 + span, false);
                    ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.12);
                    ctx.stroke();
                    function ratio(v) { return Math.max(0, Math.min(1, (v - card.minT) / ((card.maxT - card.minT) || 1))); }
                    var from = 0, to = 0;
                    if (card.dual) { from = ratio(card.low); to = ratio(card.high); }
                    else if (!isNaN(card.target)) { to = ratio(card.target); }
                    else return;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, a0 + span * from, a0 + span * Math.max(to, from + 0.001), false);
                    ctx.strokeStyle = card.accent;
                    ctx.stroke();
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -parent.height * 0.05
                spacing: 0

                PC3.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: card.attrs.hvac_action
                          ? Ha.attributeValueDisplay(card.client, card.entityId, "hvac_action", card.attrs.hvac_action)
                          : Ha.stateDisplay(card.client, card.entityId, card.st)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }
                PC3.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: card.dual ? card.fmt(card.low) + " – " + card.fmt(card.high) : card.fmt(card.target)
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * (card.dual ? 2 : 3)
                    font.weight: Font.Light
                }
                PC3.Label {
                    Layout.alignment: Qt.AlignHCenter
                    visible: card.attrs.current_temperature !== undefined && card.attrs.current_temperature !== null
                    text: Tr.tr(card.client, "Currently %1", Ha.withUnit(card.fmt(Number(card.attrs.current_temperature)), card.unit))
                    font: Kirigami.Theme.smallFont
                    opacity: 0.75
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: !card.dual && card.st && card.st.state !== "off" && card.st.state !== "unavailable"
            spacing: Kirigami.Units.gridUnit
            IconButton { client: card.client; icon: "mdi:minus"; size: Kirigami.Units.iconSizes.medium; onClicked: card.bump("single", -1) }
            IconButton { client: card.client; icon: "mdi:plus"; size: Kirigami.Units.iconSizes.medium; onClicked: card.bump("single", 1) }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            visible: card.dual && card.st && card.st.state !== "off"
            spacing: Kirigami.Units.smallSpacing
            IconButton { client: card.client; icon: "mdi:minus"; onClicked: card.bump("low", -1) }
            IconButton { client: card.client; icon: "mdi:plus"; onClicked: card.bump("low", 1) }
            Item { implicitWidth: Kirigami.Units.gridUnit }
            IconButton { client: card.client; icon: "mdi:minus"; onClicked: card.bump("high", -1) }
            IconButton { client: card.client; icon: "mdi:plus"; onClicked: card.bump("high", 1) }
        }

        Flow {
            Layout.alignment: Qt.AlignHCenter
            visible: (card.attrs.hvac_modes || []).length > 1
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: card.attrs.hvac_modes || []
                IconButton {
                    required property var modelData
                    client: card.client
                    icon: Ha.HVAC_ICONS[modelData] || "mdi:thermostat"
                    highlighted: card.st && card.st.state === modelData
                    highlightColor: card.dash.tint(Ha.activeColor(card.entityId, { state: modelData, attributes: {} }), Kirigami.Theme.highlightColor)
                    onClicked: Ha.svc(card.client, "climate", "set_hvac_mode", card.entityId, { hvac_mode: modelData })
                }
            }
        }
    }
}
