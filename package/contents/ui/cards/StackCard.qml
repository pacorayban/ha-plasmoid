import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ".."

// "vertical-stack", "horizontal-stack" and "grid": containers of other cards.
CardFrame {
    id: card

    frameless: true
    padding: 0
    implicitHeight: col.implicitHeight

    readonly property var cards: config.cards || []
    readonly property int cols: config.type === "horizontal-stack" ? Math.max(1, cards.length)
                               : config.type === "grid" ? Math.max(1, config.columns || 3)
                               : 1

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            visible: !!card.config.title
            level: 4
            text: card.config.title || ""
        }

        GridLayout {
            Layout.fillWidth: true
            columns: card.cols
            uniformCellWidths: card.cols > 1
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.smallSpacing

            Repeater {
                model: card.cards
                delegate: CardLoader {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    config: modelData
                    client: card.client
                    dash: card.dash
                }
            }
        }
    }
}
