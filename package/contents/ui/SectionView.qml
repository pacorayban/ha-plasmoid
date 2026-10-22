import QtQuick
import org.kde.kirigami as Kirigami
import "../code/Ha.js" as Ha

// One section of a "sections" view: its cards flow on a 12-column grid.
Item {
    id: sec

    property var section: ({})
    property var client
    property var dash

    implicitHeight: flow.implicitHeight
    visible: {
        client.revision;
        return Ha.checkConditions(client, section.visibility) && (section.cards || []).length > 0;
    }

    Flow {
        id: flow
        width: sec.width
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: sec.section.cards || []
            delegate: CardLoader {
                required property var modelData
                width: Math.max(Kirigami.Units.gridUnit * 3,
                                Math.floor((flow.width + flow.spacing) * Ha.gridColumns(modelData) / 12 - flow.spacing))
                config: modelData
                client: sec.client
                dash: sec.dash
            }
        }
    }
}
