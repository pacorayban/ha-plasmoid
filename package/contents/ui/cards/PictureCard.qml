import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha

// HA "picture", "picture-entity" and "picture-glance" cards.
// Camera images are refreshed every 10 s.
CardFrame {
    id: card

    readonly property string entityId: config.entity || ""
    readonly property string imageEntity: config.camera_image || config.image_entity || (config.type === "picture-entity" ? entityId : "")
    readonly property var st: { client.revision; return entityId ? client.states[entityId] : undefined; }
    readonly property var imgSt: { client.revision; return imageEntity ? client.states[imageEntity] : undefined; }
    readonly property bool isCamera: Ha.domainOf(imageEntity) === "camera"
    property int tick: 0

    readonly property string imageUrl: {
        var src = "";
        if (config.image && !(isCamera && config.camera_view === "live"))
            src = typeof config.image === "string" ? config.image : (config.image.media_content_id || "");
        if (!src && imgSt && imgSt.attributes)
            src = imgSt.attributes.entity_picture || "";
        if (!src && st && st.attributes)
            src = st.attributes.entity_picture || "";
        if (!src)
            return "";
        var url = Ha.absoluteUrl(client, src);
        if (isCamera)
            url += (url.indexOf("?") >= 0 ? "&" : "?") + "_t=" + tick;
        return url;
    }
    readonly property real aspect: {
        var a = config.aspect_ratio;
        if (a) {
            var s = String(a);
            if (s.indexOf(":") > 0) { var p = s.split(":"); return Number(p[1]) / Number(p[0]); }
            if (s.indexOf("x") > 0) { var q = s.split("x"); return Number(q[1]) / Number(q[0]); }
            if (s.indexOf("%") > 0) return parseFloat(s) / 100;
            return 1 / Number(s);
        }
        if (img.status === Image.Ready && img.implicitWidth > 0)
            return img.implicitHeight / img.implicitWidth;
        return 9 / 16;
    }
    readonly property var glanceEntities: config.type === "picture-glance"
        ? (config.entities || []).map(Ha.entityConf).filter(function (e) { return e && e.entity; }) : []

    padding: 0
    clip: true
    implicitHeight: width * aspect

    Timer {
        interval: 10000
        repeat: true
        running: card.isCamera && card.visible
        onTriggered: card.tick++
    }

    Image {
        id: img
        anchors.fill: parent
        source: card.imageUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: !card.isCamera
        // Keep the previous frame while the next camera frame loads.
        retainWhileLoading: true
    }

    HaIcon {
        anchors.centerIn: parent
        visible: img.status !== Image.Ready
        client: card.client
        icon: card.isCamera ? "mdi:video-off" : "mdi:image-off-outline"
        size: Kirigami.Units.gridUnit * 2
        color: card.dash.disabledColor
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Ha.runAction(card.client, card.dash, card.config.tap_action, card.entityId || card.imageEntity,
                                (card.entityId || card.imageEntity) ? "more-info" : "none")
    }

    // Bottom bar with name / state / glance icons.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: bar.implicitHeight + Kirigami.Units.smallSpacing * 2
        color: Qt.rgba(0, 0, 0, 0.45)
        visible: (card.config.type !== "picture" && (card.config.show_name !== false || card.config.show_state !== false))
                 || card.glanceEntities.length > 0 || !!card.config.title

        RowLayout {
            id: bar
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.largeSpacing
            anchors.rightMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            PC3.Label {
                Layout.fillWidth: true
                visible: text !== ""
                color: "white"
                elide: Text.ElideRight
                text: {
                    if (card.config.title)
                        return card.config.title;
                    if (card.config.type === "picture-entity" && card.config.show_name !== false && card.entityId)
                        return Ha.entityName(card.client, card.entityId, card.st, card.config.name);
                    return "";
                }
            }
            PC3.Label {
                visible: card.config.type === "picture-entity" && card.config.show_state !== false && !!card.entityId && !card.isCamera
                color: "white"
                text: Ha.stateDisplay(card.client, card.entityId, card.st)
            }
            Repeater {
                model: card.glanceEntities
                delegate: IconButton {
                    required property var modelData
                    readonly property var est: { card.client.revision; return card.client.states[modelData.entity]; }
                    client: card.client
                    icon: Ha.entityIcon(card.client, modelData.entity, est, modelData.icon)
                    color: Ha.activeColor(modelData.entity, est) !== "" && Ha.activeColor(modelData.entity, est) !== "primary"
                           ? card.dash.tint(Ha.activeColor(modelData.entity, est), "white") : "white"
                    onClicked: Ha.runAction(card.client, card.dash, modelData.tap_action, modelData.entity,
                                            Ha.isTapToggleable(modelData.entity) ? "toggle" : "more-info")
                }
            }
        }
    }
}
