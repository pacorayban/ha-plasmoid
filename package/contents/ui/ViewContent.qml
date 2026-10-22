import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "../code/Ha.js" as Ha

// One dashboard view: badges, then cards laid out as masonry columns,
// sections (12-column grids) or a single panel card.
Item {
    id: vc

    property var view
    property var client
    property var dash
    property int columnWidth: 320

    readonly property real gap: Kirigami.Units.largeSpacing
    readonly property string vtype: !view ? "masonry"
        : (view.type || (view.sections ? "sections" : (view.panel ? "panel" : "masonry")))
    readonly property int ncols: Math.max(1, Math.floor((width + gap) / (columnWidth + gap)))
    readonly property var sidebarSections: vtype === "sections" && view && view.sidebar ? (view.sidebar.sections || []) : []
    // Sidebar on the right when there is room for it plus two columns, otherwise on top.
    readonly property bool sidebarRight: sidebarSections.length > 0 && ncols >= 3
    // Narrow: like HA on a phone, summaries go after the first section, two per row.
    readonly property var mainSections: {
        var secs = vtype === "sections" && view ? (view.sections || []) : [];
        if (sidebarRight || sidebarSections.length === 0)
            return secs;
        var side = sidebarSections.map(function (s) {
            var copy = JSON.parse(JSON.stringify(s));
            copy.column_span = 99;
            copy.cards = (copy.cards || []).map(function (c) {
                if (c.type !== "heading")
                    c.grid_options = { columns: 6 };
                return c;
            });
            return copy;
        });
        return secs.slice(0, 1).concat(side).concat(secs.slice(1));
    }
    readonly property int sectionCols: Math.max(1, Math.min(sidebarRight ? ncols - 1 : ncols, (view && view.max_columns) || 4))

    readonly property var masonryColumns: {
        if (!view || vtype === "sections" || vtype === "panel")
            return [];
        var cards = view.cards || [];
        var n = Math.max(1, Math.min(ncols, cards.length));
        var cols = [], h = [];
        for (var i = 0; i < n; i++) { cols.push([]); h.push(0); }
        cards.forEach(function (c) {
            var idx = 0;
            for (var j = 1; j < n; j++)
                if (h[j] < h[idx]) idx = j;
            cols[idx].push(c);
            h[idx] += Ha.cardSize(c) + 1;
        });
        return cols;
    }

    readonly property var badges: (view && view.badges ? view.badges : [])
        .map(Ha.entityConf).filter(function (b) { return b && b.entity; })

    implicitHeight: col.implicitHeight

    ColumnLayout {
        id: col
        width: vc.width
        spacing: vc.gap

        // View header (e.g. the Home welcome message)
        CardLoader {
            Layout.fillWidth: true
            config: vc.view && vc.view.header && vc.view.header.card ? vc.view.header.card : null
            client: vc.client
            dash: vc.dash
        }

        // Badges
        Flow {
            Layout.fillWidth: true
            visible: vc.badges.length > 0
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: vc.badges
                delegate: Rectangle {
                    id: badge
                    required property var modelData
                    readonly property var st: { vc.client.revision; return vc.client.states[modelData.entity]; }
                    readonly property color bg: Kirigami.Theme.backgroundColor
                    readonly property color fg: Kirigami.Theme.textColor
                    visible: Ha.checkConditions(vc.client, modelData.visibility)
                    height: Kirigami.Units.gridUnit * 1.8
                    width: badgeRow.implicitWidth + Kirigami.Units.largeSpacing * 2
                    radius: height / 2
                    color: Qt.rgba(bg.r, bg.g, bg.b, vc.dash.cardOpacity)
                    border.width: 1
                    border.color: Qt.rgba(fg.r, fg.g, fg.b, 0.12)

                    Row {
                        id: badgeRow
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing
                        HaIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: badge.modelData.show_icon !== false
                            client: vc.client
                            icon: Ha.entityIcon(vc.client, badge.modelData.entity, badge.st, badge.modelData.icon)
                            size: Kirigami.Units.iconSizes.small
                            color: vc.dash.tint(badge.modelData.color && badge.modelData.color !== "state" ? badge.modelData.color
                                                : Ha.activeColor(badge.modelData.entity, badge.st),
                                                vc.dash.iconColor)
                        }
                        PC3.Label {
                            anchors.verticalCenter: parent.verticalCenter
                            font: Kirigami.Theme.smallFont
                            text: {
                                var parts = [];
                                var person = Ha.domainOf(badge.modelData.entity) === "person";
                                if (badge.modelData.show_name === true || (badge.modelData.show_name === undefined && person))
                                    parts.push(Ha.entityName(vc.client, badge.modelData.entity, badge.st, badge.modelData.name));
                                if (badge.modelData.show_state !== false)
                                    parts.push(Ha.stateDisplay(vc.client, badge.modelData.entity, badge.st));
                                return parts.join(" · ");
                            }
                        }
                    }
                    TapHandler {
                        onTapped: Ha.runAction(vc.client, vc.dash, badge.modelData.tap_action, badge.modelData.entity, "more-info")
                    }
                }
            }
        }

        // Masonry (default) and sidebar views
        RowLayout {
            Layout.fillWidth: true
            visible: vc.masonryColumns.length > 0
            spacing: vc.gap

            Repeater {
                model: vc.masonryColumns
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: vc.gap

                    Repeater {
                        model: parent.modelData
                        delegate: CardLoader {
                            required property var modelData
                            Layout.fillWidth: true
                            config: modelData
                            client: vc.client
                            dash: vc.dash
                        }
                    }
                }
            }
        }

        // Panel view: first card only, full width
        CardLoader {
            Layout.fillWidth: true
            config: vc.vtype === "panel" && vc.view && vc.view.cards && vc.view.cards.length ? vc.view.cards[0] : null
            client: vc.client
            dash: vc.dash
        }

        // Sections view (+ sidebar on the right)
        RowLayout {
            Layout.fillWidth: true
            visible: vc.vtype === "sections"
            spacing: vc.gap

            GridLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                columns: vc.sectionCols
                uniformCellWidths: true
                columnSpacing: vc.gap
                rowSpacing: vc.gap

                Repeater {
                    model: vc.mainSections
                    delegate: SectionView {
                        required property var modelData
                        Layout.columnSpan: Math.min(modelData.column_span || 1, vc.sectionCols)
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        section: modelData
                        client: vc.client
                        dash: vc.dash
                    }
                }
            }

            ColumnLayout {
                visible: vc.sidebarRight
                Layout.preferredWidth: vc.columnWidth
                Layout.maximumWidth: vc.columnWidth
                Layout.alignment: Qt.AlignTop
                spacing: vc.gap

                Repeater {
                    model: vc.sidebarRight ? vc.sidebarSections : []
                    delegate: SectionView {
                        required property var modelData
                        Layout.fillWidth: true
                        section: modelData
                        client: vc.client
                        dash: vc.dash
                    }
                }
            }
        }
    }
}
