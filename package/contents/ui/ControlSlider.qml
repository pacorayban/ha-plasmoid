import QtQuick
import org.kde.kirigami as Kirigami

// Pill-shaped slider like HA's ha-control-slider: tinted track, filled part,
// thin handle at the end of the fill. Emits valueSet() when the user is done.
Rectangle {
    id: slider

    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 0
    property color tint: Kirigami.Theme.highlightColor

    property real _dragValue: NaN
    readonly property real shown: isNaN(_dragValue) ? value : _dragValue
    readonly property real ratio: Math.max(0, Math.min(1, (shown - from) / ((to - from) || 1)))

    signal valueSet(real value)

    implicitHeight: Kirigami.Units.gridUnit * 2.2
    implicitWidth: Kirigami.Units.gridUnit * 8
    radius: Math.round(Kirigami.Units.gridUnit * 0.6)
    color: Qt.rgba(tint.r, tint.g, tint.b, 0.2)
    clip: true
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(slider.radius * 2, slider.width * slider.ratio)
        visible: slider.ratio > 0
        radius: slider.radius
        color: slider.tint

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: Kirigami.Units.smallSpacing * 1.5
            anchors.verticalCenter: parent.verticalCenter
            width: 4
            height: parent.height * 0.5
            radius: 2
            color: "white"
        }
    }

    function valueAt(x) {
        var r = Math.max(0, Math.min(1, x / width));
        var v = from + r * (to - from);
        return Math.round(v / stepSize) * stepSize;
    }

    MouseArea {
        anchors.fill: parent
        enabled: slider.enabled
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: function (mouse) { slider._dragValue = slider.valueAt(mouse.x); }
        onPositionChanged: function (mouse) { if (pressed) slider._dragValue = slider.valueAt(mouse.x); }
        onReleased: {
            var v = slider._dragValue;
            slider._dragValue = NaN;
            if (!isNaN(v))
                slider.valueSet(v);
        }
        onWheel: function (wheel) {
            var v = Math.max(slider.from, Math.min(slider.to, slider.value + (wheel.angleDelta.y > 0 ? 1 : -1) * slider.stepSize * 5));
            slider.valueSet(v);
        }
    }
}
