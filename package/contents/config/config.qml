import QtQuick
import org.kde.plasma.configuration
import "../code/Tr.js" as Tr

ConfigModel {
    ConfigCategory {
        name: Tr.tr(Tr.systemClient(), "General")
        icon: "configure"
        source: "configGeneral.qml"
    }
}
