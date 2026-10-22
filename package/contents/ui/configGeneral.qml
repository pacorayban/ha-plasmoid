import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../code/Tr.js" as Tr

KCM.SimpleKCM {
    readonly property var sys: Tr.systemClient()
    property alias cfg_url: urlField.text
    property alias cfg_token: tokenField.text
    property alias cfg_dashboard: dashboardField.text
    property alias cfg_columnWidth: columnSpin.value
    property alias cfg_cardOpacity: opacitySpin.value
    property alias cfg_showHeader: headerCheck.checked
    property int cfg_viewIndex

    Kirigami.FormLayout {
        QQC2.TextField {
            id: urlField
            Kirigami.FormData.label: Tr.tr(sys, "Home Assistant address:")
            Layout.fillWidth: true
            placeholderText: "http://homeassistant.local:8123"
        }

        QQC2.TextField {
            id: tokenField
            Kirigami.FormData.label: Tr.tr(sys, "Long-lived access token:")
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "eyJhbGciOi…"
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            text: Tr.tr(sys, "Create one in Home Assistant: your profile → Security tab → Long-lived access tokens. The token is stored in plain text in your Plasma session configuration.")
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.75
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.TextField {
            id: dashboardField
            Kirigami.FormData.label: Tr.tr(sys, "Dashboard:")
            Layout.fillWidth: true
            placeholderText: Tr.tr(sys, "empty = Home Assistant home page")
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            text: Tr.tr(sys, "Paste a dashboard address from the browser (e.g. https://…/dashboard-music/0) or just its path (dashboard-music). “home” or https://…/home/overview = the Home page.")
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.75
        }

        QQC2.SpinBox {
            id: columnSpin
            Kirigami.FormData.label: Tr.tr(sys, "Column width (px):")
            from: 200
            to: 800
            stepSize: 20
        }

        QQC2.SpinBox {
            id: opacitySpin
            Kirigami.FormData.label: Tr.tr(sys, "Card opacity (%):")
            from: 0
            to: 100
            stepSize: 5
        }

        QQC2.CheckBox {
            id: headerCheck
            Kirigami.FormData.label: Tr.tr(sys, "Header:")
            text: Tr.tr(sys, "Show tabs and the reload button")
        }
    }
}
