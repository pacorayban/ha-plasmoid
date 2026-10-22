import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
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
            Kirigami.FormData.label: "Adresse de Home Assistant :"
            Layout.fillWidth: true
            placeholderText: "http://homeassistant.local:8123"
        }

        QQC2.TextField {
            id: tokenField
            Kirigami.FormData.label: "Jeton d'accès longue durée :"
            Layout.fillWidth: true
            echoMode: TextInput.Password
            placeholderText: "eyJhbGciOi…"
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            text: "À créer dans Home Assistant : votre profil → onglet Sécurité → Jetons d'accès longue durée. "
                  + "Le jeton est stocké en clair dans la configuration Plasma de votre session."
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.75
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.TextField {
            id: dashboardField
            Kirigami.FormData.label: "Tableau de bord :"
            Layout.fillWidth: true
            placeholderText: "vide = page d'accueil de HA"
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            text: "Collez l'adresse d'un tableau de bord depuis le navigateur (ex. https://…/dashboard-music/0) "
                  + "ou juste son chemin (dashboard-music). « home » ou https://…/home/overview = la page Accueil."
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.75
        }

        QQC2.SpinBox {
            id: columnSpin
            Kirigami.FormData.label: "Largeur de colonne (px) :"
            from: 200
            to: 800
            stepSize: 20
        }

        QQC2.SpinBox {
            id: opacitySpin
            Kirigami.FormData.label: "Opacité des cartes (%) :"
            from: 0
            to: 100
            stepSize: 5
        }

        QQC2.CheckBox {
            id: headerCheck
            Kirigami.FormData.label: "En-tête :"
            text: "Afficher les onglets et le bouton de rechargement"
        }
    }
}
