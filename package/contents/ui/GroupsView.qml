import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "data.js" as Data

// Skupiny s nadpisem a mřížkou dlaždic
ColumnLayout {
    id: view

    property var groups: []
    // předpona klíčů (index záložky), aby se stavy nepletly mezi záložkami
    property string keyPrefix: ""
    // klíč tlačítka -> true / "ok" / "error"
    property var running: ({})
    property var statuses: ({})
    // klíč dlaždice označené klávesnicí
    property string selectedKey: ""

    signal triggered(int groupIndex, int buttonIndex)

    // poloha všech dlaždic (pro navigaci šipkami)
    function tiles() {
        const list = [];
        for (let g = 0; g < groupsRepeater.count; g++) {
            const group = groupsRepeater.itemAt(g);
            if (!group || !group.visible) {
                continue;
            }
            for (let b = 0; b < group.tileRepeater.count; b++) {
                const tile = group.tileRepeater.itemAt(b);
                if (!tile) {
                    continue;
                }
                const pos = tile.mapToItem(view, 0, 0);
                list.push({ key: tile.key, x: pos.x, y: pos.y, width: tile.width, height: tile.height });
            }
        }
        return list;
    }

    spacing: Kirigami.Units.largeSpacing

    Repeater {
        id: groupsRepeater
        model: view.groups

        ColumnLayout {
            id: groupItem
            required property var modelData
            required property int index
            readonly property Item tileRepeater: buttonsRepeater

            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            visible: modelData.buttons.length > 0

            Kirigami.Heading {
                Layout.fillWidth: true
                visible: text.length > 0
                level: 5
                opacity: 0.7
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: groupItem.modelData.label
            }

            GridLayout {
                Layout.fillWidth: true
                columns: groupItem.modelData.columns
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                Repeater {
                    id: buttonsRepeater
                    model: groupItem.modelData.buttons

                    CommandTile {
                        required property var modelData
                        required property int index
                        readonly property string key: view.keyPrefix + groupItem.index + "-" + index

                        Layout.fillWidth: true
                        Layout.columnSpan: Math.min(Math.max(1, modelData.span || 1), groupItem.modelData.columns)
                        // shodná šířka sloupců bez ohledu na délku textu
                        Layout.preferredWidth: Layout.columnSpan
                        text: modelData.name || ""
                        iconName: modelData.icon || ""
                        command: modelData.command || ""
                        tooltipText: Data.tooltipText(modelData)
                        busy: !!view.running[key]
                        status: view.statuses[key] || ""
                        selected: key === view.selectedKey
                        onClicked: view.triggered(groupItem.index, index)
                    }
                }
            }
        }
    }
}
