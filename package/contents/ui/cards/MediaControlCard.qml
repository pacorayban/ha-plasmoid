import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha

// HA "media-control" card: the card takes the colour of the artwork, which sits
// on the right and fades into it; title, artist and transport buttons on the left.
CardFrame {
    id: card

    readonly property string entityId: config.entity || ""
    readonly property var st: { client.revision; return client.states[entityId]; }
    readonly property var attrs: st && st.attributes ? st.attributes : ({})
    readonly property bool isOff: !st || st.state === "off" || st.state === "standby" || st.state === "unavailable"
    readonly property string art: isOff ? "" : Ha.absoluteUrl(client, attrs.entity_picture_local || attrs.entity_picture)
    readonly property bool hasArt: art !== "" && artImage.status === Image.Ready

    // Average colour of the artwork, computed by the sampler below.
    property color artColor: "transparent"
    readonly property bool artDark: (0.299 * artColor.r + 0.587 * artColor.g + 0.114 * artColor.b) < 0.6
    readonly property color fg: hasArt && artColor.a > 0 ? (artDark ? "white" : "#1c1c1c") : Kirigami.Theme.textColor

    readonly property var buttons: Ha.mediaButtons(entityId, st, null)

    color: hasArt && artColor.a > 0 ? artColor
                                    : Qt.rgba(bgColor.r, bgColor.g, bgColor.b, cardOpacity)
    clip: true
    implicitHeight: Math.max(col.implicitHeight + 2 * padding, hasArt ? Kirigami.Units.gridUnit * 8 : 0)

    function media(b) {
        Ha.svc(client, "media_player", b.service, entityId, b.data);
    }

    // Artwork on the right, faded into the card colour and clipped to its corners.
    Item {
        id: artBox
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.min(height * 1.2, parent.width * 0.6)
        visible: card.hasArt
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: artMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }

        Image {
            id: artImage
            anchors.fill: parent
            source: card.art
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: card.artColor }
                GradientStop { position: 0.6; color: Qt.rgba(card.artColor.r, card.artColor.g, card.artColor.b, 0.4) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }
    Item {
        id: artMask
        anchors.fill: artBox
        visible: false
        layer.enabled: true
        Rectangle {
            // Rounded on the right only: the left side goes past the mask edge.
            anchors.fill: parent
            anchors.leftMargin: -card.radius
            radius: card.radius
            color: "black"
        }
    }

    // Samples the artwork to get its average colour.
    Canvas {
        id: sampler
        width: 16
        height: 16
        opacity: 0.01
        property string src: card.art
        onSrcChanged: if (src !== "") loadImage(src)
        onImageLoaded: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (src === "" || !isImageLoaded(src))
                return;
            ctx.drawImage(src, 0, 0, width, height);
            var d = ctx.getImageData(0, 0, width, height).data;
            var r = 0, g = 0, b = 0, n = 0;
            for (var i = 0; i < d.length; i += 4) {
                if (d[i + 3] < 128) continue;
                r += d[i]; g += d[i + 1]; b += d[i + 2]; n++;
            }
            if (n > 0)
                card.artColor = Qt.rgba(r / n / 255, g / n / 255, b / n / 255, 1);
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: card.dash.moreInfo(card.entityId)
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
            spacing: Kirigami.Units.smallSpacing
            HaIcon {
                client: card.client
                icon: Ha.entityIcon(card.client, card.entityId, card.st, card.config.icon)
                size: Kirigami.Units.iconSizes.small
                color: card.hasArt ? card.fg : card.dash.tint(Ha.activeColor(card.entityId, card.st), card.dash.disabledColor)
            }
            PC3.Label {
                Layout.fillWidth: true
                text: Ha.entityName(card.client, card.entityId, card.st, card.config.name)
                color: card.fg
                opacity: 0.85
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
            }
            IconButton {
                client: card.client
                icon: "mdi:dots-vertical"
                color: card.fg
                onClicked: card.dash.moreInfo(card.entityId)
            }
        }

        PC3.Label {
            Layout.fillWidth: true
            Layout.rightMargin: card.hasArt ? artBox.width * 0.35 : 0
            text: card.isOff ? Ha.stateDisplay(card.client, card.entityId, card.st)
                             : (card.attrs.media_title || Ha.stateDisplay(card.client, card.entityId, card.st))
            color: card.fg
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.15
            elide: Text.ElideRight
        }
        PC3.Label {
            Layout.fillWidth: true
            Layout.rightMargin: card.hasArt ? artBox.width * 0.35 : 0
            visible: !card.isOff && text !== ""
            text: card.attrs.media_artist || card.attrs.media_album_name || card.attrs.app_name || ""
            color: card.fg
            opacity: 0.8
            elide: Text.ElideRight
        }

        Row {
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: card.buttons
                delegate: IconButton {
                    required property var modelData
                    client: card.client
                    icon: modelData.icon
                    size: modelData.service === "media_pause" || modelData.service === "media_play"
                          ? Kirigami.Units.iconSizes.medium : Kirigami.Units.iconSizes.smallMedium
                    color: card.fg
                    enabled: !modelData.disabled
                    onClicked: card.media(modelData)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: !card.isOff && card.attrs.media_duration > 0 && card.attrs.media_position !== undefined
            height: 4
            radius: 2
            color: Qt.rgba(card.fg.r, card.fg.g, card.fg.b, 0.25)
            Rectangle {
                height: parent.height
                radius: 2
                width: parent.width * Math.min(1, (card.attrs.media_position || 0) / (card.attrs.media_duration || 1))
                color: card.fg
            }
        }
    }
}
