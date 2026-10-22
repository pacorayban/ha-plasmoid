import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// Draws an MDI icon ("mdi:lightbulb") from the SVG path served by Home Assistant.
Item {
    id: root

    property var client
    property string icon: ""
    property color color: Kirigami.Theme.textColor
    property real size: Kirigami.Units.iconSizes.smallMedium

    implicitWidth: size
    implicitHeight: size

    readonly property string svgPath: {
        if (!client || !icon)
            return "";
        client.iconRevision;
        return client.iconPath(icon);
    }

    Shape {
        anchors.centerIn: parent
        width: root.size
        height: root.size
        visible: root.svgPath !== ""
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            fillRule: ShapePath.WindingFill
            strokeWidth: -1
            strokeColor: "transparent"
            scale: Qt.size(root.size / 24, root.size / 24)
            PathSvg { path: root.svgPath }
        }
    }
}
