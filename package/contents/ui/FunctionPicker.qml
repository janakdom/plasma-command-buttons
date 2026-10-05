import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

import "data.js" as Data

// Výběr sdílené funkce k vložení: hledání v názvu i popisu, Enter/klik vloží $(nazev "param").
QQC2.Popup {
    id: picker

    // [{ name, params, description, body }]
    property var functions: []

    signal picked(var fn)

    readonly property string query: search.text.trim().toLowerCase()
    readonly property var matches: functions
        .filter(f => Data.FUNCTION_NAME.test(f.name))
        .filter(f => f.name.toLowerCase().includes(query) || f.description.toLowerCase().includes(query))

    function pick(fn) {
        picked(fn);
        close();
    }

    width: Kirigami.Units.gridUnit * 26
    padding: Kirigami.Units.smallSpacing
    focus: true

    onOpened: {
        search.text = "";
        list.currentIndex = 0;
        search.forceActiveFocus();
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.SearchField {
            id: search
            Layout.fillWidth: true
            placeholderText: Tr.t("Search functions…")
            // jinak SearchField po chvíli psaní sám „potvrdí“ a vložil by první shodu
            autoAccept: false
            onTextChanged: list.currentIndex = 0
            Keys.onDownPressed: list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
            Keys.onUpPressed: list.currentIndex = Math.max(list.currentIndex - 1, 0)
            onAccepted: {
                if (list.currentIndex >= 0 && list.currentIndex < picker.matches.length) {
                    picker.pick(picker.matches[list.currentIndex]);
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 16)
            clip: true
            model: picker.matches
            highlightMoveDuration: 0
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

            delegate: QQC2.ItemDelegate {
                id: item
                required property var modelData
                required property int index

                width: ListView.view.width
                highlighted: ListView.isCurrentItem
                onClicked: picker.pick(modelData)

                contentItem: ColumnLayout {
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true

                        QQC2.Label {
                            Layout.fillWidth: true
                            font: Kirigami.Theme.fixedWidthFont
                            elide: Text.ElideRight
                            text: Data.signature(item.modelData)
                        }
                        QQC2.Label {
                            visible: !!item.modelData.builtin
                            opacity: 0.6
                            font: Kirigami.Theme.smallFont
                            text: Tr.t("built-in")
                        }
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        elide: Text.ElideRight
                        opacity: 0.6
                        font: Kirigami.Theme.smallFont
                        text: item.modelData.builtin ? Tr.t(item.modelData.description) : item.modelData.description
                    }
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: picker.matches.length === 0
            wrapMode: Text.Wrap
            opacity: 0.7
            text: picker.functions.length === 0
                ? Tr.t("No functions yet. Create them on the Functions page.")
                : Tr.t("Nothing found.")
        }
    }
}
