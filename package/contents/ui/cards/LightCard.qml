import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha

// HA "light" card: big round toggle and brightness slider.
CardFrame {
    id: card

    readonly property string entityId: config.entity || ""
    readonly property var st: { client.revision; return client.states[entityId]; }
    readonly property var attrs: st && st.attributes ? st.attributes : ({})
    readonly property bool isOn: st ? st.state === "on" : false
    readonly property int brightness: isOn && attrs.brightness ? Math.round(attrs.brightness / 2.55) : 0
    readonly property bool dimmable: (attrs.supported_color_modes || []).some(function (m) { return m !== "onoff"; })
    readonly property color accent: isOn ? dash.tint(Ha.activeColor(entityId, st), Kirigami.Theme.highlightColor) : dash.disabledColor

    implicitHeight: col.implicitHeight + 2 * padding

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.padding
        spacing: Kirigami.Units.smallSpacing

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.gridUnit * 6
            implicitHeight: implicitWidth
            radius: width / 2
            color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.18)
            border.width: 3
            border.color: card.accent

            HaIcon {
                anchors.centerIn: parent
                client: card.client
                icon: Ha.entityIcon(card.client, card.entityId, card.st, card.config.icon)
                size: Kirigami.Units.gridUnit * 2.6
                color: card.accent
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Ha.toggle(card.client, card.entityId)
            }
        }

        PC3.Label {
            Layout.alignment: Qt.AlignHCenter
            text: card.isOn && card.dimmable ? card.brightness + " %" : Ha.stateDisplay(card.client, card.entityId, card.st)
            opacity: 0.8
        }

        PC3.Slider {
            id: slider
            Layout.fillWidth: true
            visible: card.dimmable
            from: 1
            to: 100
            value: card.brightness
            onMoved: sendTimer.restart()
            Timer {
                id: sendTimer
                interval: 300
                onTriggered: Ha.svc(card.client, "light", "turn_on", card.entityId, { brightness_pct: Math.round(slider.value) })
            }
        }

        PC3.Label {
            Layout.fillWidth: true
            text: Ha.entityName(card.client, card.entityId, card.st, card.config.name)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            TapHandler { onTapped: card.dash.moreInfo(card.entityId) }
        }
    }
}
