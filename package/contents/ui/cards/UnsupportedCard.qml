import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."

// Placeholder for card types the widget cannot draw.
CardFrame {
    id: card

    implicitHeight: row.implicitHeight + 2 * padding
    opacity: 0.7

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.padding
        spacing: Kirigami.Units.smallSpacing

        HaIcon {
            client: card.client
            icon: "mdi:card-off-outline"
            color: card.dash.iconColor
        }
        PC3.Label {
            Layout.fillWidth: true
            text: (card.config.title ? card.config.title + " — " : "")
                  + "carte « " + (card.config.type || "?") + " » non prise en charge"
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: card.dash.openUrl("/")
    }
}
