import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import ".."
import "../../code/Ha.js" as Ha

// HA "history-graph" (and "statistics-graph", drawn from history too).
CardFrame {
    id: card

    implicitHeight: col.implicitHeight + 2 * padding

    readonly property var ids: (config.entities || (config.entity ? [config.entity] : []))
        .map(Ha.entityConf).filter(function (e) { return e && e.entity; }).map(function (e) { return e.entity; })

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.padding
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Heading {
            Layout.fillWidth: true
            visible: !!card.config.title
            level: 4
            text: card.config.title || ""
            elide: Text.ElideRight
        }

        HistoryChart {
            Layout.fillWidth: true
            client: card.client
            dash: card.dash
            entityIds: card.ids
            hours: Number(card.config.hours_to_show || (card.config.days_to_show ? card.config.days_to_show * 24 : 24))
        }
    }
}
