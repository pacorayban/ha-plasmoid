import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "../code/Tr.js" as Tr

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation
    switchWidth: Kirigami.Units.gridUnit * 8
    switchHeight: Kirigami.Units.gridUnit * 8

    toolTipMainText: "Home Assistant"
    toolTipSubText: haClient.ready ? Tr.tr(haClient, "Connected") : (haClient.errorText || Tr.tr(haClient, "Disconnected"))

    HaClient {
        id: haClient
        baseUrl: Plasmoid.configuration.url
        token: Plasmoid.configuration.token
    }

    compactRepresentation: MouseArea {
        onClicked: root.expanded = !root.expanded
        HaIcon {
            id: compactIcon
            anchors.centerIn: parent
            client: haClient
            icon: "mdi:home-assistant"
            size: Math.min(parent.width, parent.height) * 0.85
            color: Kirigami.Theme.textColor
        }
        Kirigami.Icon {
            anchors.fill: parent
            visible: compactIcon.svgPath === ""
            source: "go-home"
        }
    }

    fullRepresentation: DashboardView {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 40
        Layout.preferredHeight: Kirigami.Units.gridUnit * 30
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: Kirigami.Units.gridUnit * 10

        client: haClient
        dashboardPath: Plasmoid.configuration.dashboard
        viewIndex: Plasmoid.configuration.viewIndex
        columnWidth: Plasmoid.configuration.columnWidth
        cardOpacity: Plasmoid.configuration.cardOpacity / 100
        showHeader: Plasmoid.configuration.showHeader

        onViewSelected: function (index) { Plasmoid.configuration.viewIndex = index; }
        onConfigureRequested: Plasmoid.internalAction("configure").trigger()
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: Tr.tr(haClient, "Reconnect")
            icon.name: "view-refresh"
            onTriggered: haClient.reconnect()
        },
        PlasmaCore.Action {
            text: Tr.tr(haClient, "Open Home Assistant")
            icon.name: "internet-web-browser"
            enabled: haClient.cleanUrl !== ""
            onTriggered: Qt.openUrlExternally(haClient.cleanUrl)
        }
    ]

    Component.onCompleted: haClient.reconnect()
}
