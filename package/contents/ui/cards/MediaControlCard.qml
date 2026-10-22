import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha

// HA "media-control" card: artwork, title and transport buttons.
CardFrame {
    id: card

    readonly property string entityId: config.entity || ""
    readonly property var st: { client.revision; return client.states[entityId]; }
    readonly property var attrs: st && st.attributes ? st.attributes : ({})
    readonly property bool isOff: !st || st.state === "off" || st.state === "standby" || st.state === "unavailable"
    readonly property bool playing: st ? st.state === "playing" : false
    readonly property string art: isOff ? "" : Ha.absoluteUrl(client, attrs.entity_picture_local || attrs.entity_picture)

    implicitHeight: col.implicitHeight + 2 * padding
    clip: true

    function media(service) {
        Ha.svc(client, "media_player", service, entityId);
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.padding
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            Image {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                Layout.preferredHeight: Kirigami.Units.gridUnit * 4
                visible: card.art !== "" && status === Image.Ready
                source: card.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
            }
            HaIcon {
                visible: card.art === ""
                client: card.client
                icon: Ha.entityIcon(card.client, card.entityId, card.st, card.config.icon)
                size: Kirigami.Units.gridUnit * 2
                color: card.dash.tint(Ha.activeColor(card.entityId, card.st), card.dash.disabledColor)
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                PC3.Label {
                    Layout.fillWidth: true
                    text: card.isOff ? Ha.entityName(card.client, card.entityId, card.st, card.config.name)
                                     : (card.attrs.media_title || Ha.stateDisplay(card.client, card.entityId, card.st))
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                PC3.Label {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: card.isOff ? Ha.stateDisplay(card.client, card.entityId, card.st)
                                     : (card.attrs.media_artist || card.attrs.media_album_name || card.attrs.app_name || "")
                    elide: Text.ElideRight
                    opacity: 0.75
                }
                PC3.Label {
                    Layout.fillWidth: true
                    visible: !card.isOff
                    text: Ha.entityName(card.client, card.entityId, card.st, card.config.name)
                    font: Kirigami.Theme.smallFont
                    opacity: 0.6
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            IconButton {
                client: card.client
                icon: "mdi:power"
                visible: Ha.supports(card.st, card.isOff ? 128 : 256)
                highlighted: !card.isOff
                onClicked: card.media(card.isOff ? "turn_on" : "turn_off")
            }
            Item { Layout.fillWidth: true }
            IconButton {
                client: card.client
                icon: "mdi:skip-previous"
                visible: !card.isOff && Ha.supports(card.st, 16)
                onClicked: card.media("media_previous_track")
            }
            IconButton {
                client: card.client
                icon: card.playing ? "mdi:pause" : "mdi:play"
                size: Kirigami.Units.iconSizes.medium
                visible: !card.isOff && (Ha.supports(card.st, 1) || Ha.supports(card.st, 16384))
                onClicked: card.media("media_play_pause")
            }
            IconButton {
                client: card.client
                icon: "mdi:skip-next"
                visible: !card.isOff && Ha.supports(card.st, 32)
                onClicked: card.media("media_next_track")
            }
            Item { Layout.fillWidth: true }
            IconButton {
                client: card.client
                icon: "mdi:dots-vertical"
                onClicked: card.dash.moreInfo(card.entityId)
            }
        }

        PC3.ProgressBar {
            Layout.fillWidth: true
            visible: !card.isOff && card.attrs.media_duration > 0 && card.attrs.media_position !== undefined
            from: 0
            to: card.attrs.media_duration || 1
            value: card.attrs.media_position || 0
        }
    }
}
