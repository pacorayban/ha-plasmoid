import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import ".."

// HA "markdown" card. Jinja templates are rendered by HA (render_template).
CardFrame {
    id: card

    readonly property string content: String(config.content || "")
    readonly property bool hasTemplate: content.indexOf("{{") >= 0 || content.indexOf("{%") >= 0
    property string rendered: hasTemplate ? "" : content
    property var _token: null

    frameless: config.text_only === true
    implicitHeight: col.implicitHeight + 2 * padding

    function clean(s) {
        return String(s)
            .replace(/<ha-icon[^>]*>\s*<\/ha-icon>/g, "")
            .replace(/<\/?ha-alert[^>]*>/g, "");
    }

    function subscribe() {
        unsubscribe();
        if (!hasTemplate || !client.ready)
            return;
        var token = { alive: true, id: null };
        var cl = client;
        _token = token;
        cl.subscribe({ type: "render_template", template: content, strict: false, report_errors: false },
                         function (ev) {
                             if (token.alive && ev && ev.result !== undefined)
                                 card.rendered = String(ev.result);
                         }).then(function (id) {
            token.id = id;
            if (!token.alive)
                cl.unsubscribe(id);
        }, function (e) {
            // Non-admin users may not be allowed to render templates: show the raw text.
            if (token.alive)
                card.rendered = card.content.replace(/\{%[^%]*%\}/g, "");
        });
    }

    function unsubscribe() {
        if (_token) {
            _token.alive = false;
            if (_token.id)
                client.unsubscribe(_token.id);
        }
        _token = null;
    }

    Component.onCompleted: subscribe()
    Component.onDestruction: unsubscribe()
    Connections {
        target: card.client
        function onConnectionIdChanged() { card.subscribe(); }
    }

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
            wrapMode: Text.Wrap
        }

        PC3.Label {
            Layout.fillWidth: true
            text: card.clean(card.rendered)
            textFormat: Text.MarkdownText
            wrapMode: Text.Wrap
            onLinkActivated: function (link) { card.dash.openUrl(link); }
        }
    }
}
