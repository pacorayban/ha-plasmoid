import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami
import "../package/contents/ui"

// Runs the dashboard outside Plasma against test/mock_ha.py and saves screenshots.
// Env: HA_URL (default http://127.0.0.1:8765), HA_TOKEN (test), SHOT (output prefix),
//      VIEW (view index), WIDTH/HEIGHT, AUTOQUIT (1 = quit after the shots).
Window {
    id: win
    width: Number(Qt.application.arguments.length > 0 ? (env("WIDTH") || 1100) : 1100)
    height: Number(env("HEIGHT") || 900)
    visible: true
    // Stand-in for a dark wallpaper behind the widget.
    color: env("BG") || "#1b1e22"
    title: "HA dashboard harness"

    function env(name) {
        var v = Qt.application.arguments.filter(function (a) { return a.indexOf("--" + name + "=") === 0; })[0];
        return v ? v.split("=").slice(1).join("=") : "";
    }

    // grabToImage ignores the window color: draw the backdrop ourselves.
    Rectangle {
        anchors.fill: parent
        color: win.color
    }

    HaClient {
        id: haClient
        baseUrl: win.env("HA_URL") || "http://127.0.0.1:8765"
        token: win.env("HA_TOKEN") || "test"
    }

    DashboardView {
        id: dashView
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        client: haClient
        viewIndex: Number(win.env("VIEW") || 0)
        dashboardPath: win.env("DASHBOARD")
        columnWidth: Number(win.env("COLW") || 320)
        cardOpacity: 0.85
    }

    Component.onCompleted: haClient.reconnect()

    // --ACTION=domain.service:entity_id  → called 3 s after start (tests the state round trip)
    // --MOREINFO=entity_id               → opens the detail popup 3.5 s after start
    Timer {
        interval: 3000
        running: win.env("ACTION") !== ""
        onTriggered: {
            var a = win.env("ACTION").split(":");
            var ds = a[0].split(".");
            haClient.callService(ds[0], ds[1], {}, { entity_id: a[1] });
        }
    }
    Timer {
        interval: 3500
        running: win.env("MOREINFO") !== ""
        onTriggered: dashView.moreInfo(win.env("MOREINFO"))
    }

    Timer {
        interval: Number(win.env("DELAY") || 5000)
        running: win.env("SHOT") !== ""
        onTriggered: {
            win.contentItem.grabToImage(function (r) {
                r.saveToFile(win.env("SHOT"));
                console.log("saved " + win.env("SHOT"));
                if (win.env("AUTOQUIT") === "1")
                    Qt.quit();
            });
        }
    }
}
