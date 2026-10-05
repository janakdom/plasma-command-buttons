import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

import "data.js" as Data

// Výběr proměnné k vložení do příkazu: hledání, náhled hodnoty, Enter/klik vloží %nazev%.
QQC2.Popup {
    id: picker

    // [{ name, value, secret }]
    property var variables: []

    signal picked(string name)

    readonly property string query: search.text.trim()
    readonly property var matches: variables
        .filter(v => Data.VARIABLE_NAME.test(v.name))
        .filter(v => v.name.toLowerCase().includes(query.toLowerCase()))
    // napsaný název, který zatím neexistuje → nabídnout jako novou proměnnou
    readonly property bool offerNew: Data.VARIABLE_NAME.test(query) && !variables.some(v => v.name === query)

    function pick(name) {
        picked(name);
        close();
    }

    function pickCurrent() {
        if (list.currentIndex >= 0 && list.currentIndex < matches.length) {
            pick(matches[list.currentIndex].name);
        } else if (offerNew) {
            pick(query);
        }
    }

    width: Kirigami.Units.gridUnit * 22
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
            placeholderText: Tr.t("Search or type a new name…")
            // jinak SearchField po chvíli psaní sám „potvrdí“ a vložil by první shodu
            autoAccept: false
            onTextChanged: list.currentIndex = 0
            Keys.onDownPressed: list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
            Keys.onUpPressed: list.currentIndex = Math.max(list.currentIndex - 1, 0)
            onAccepted: picker.pickCurrent()
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 14)
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
                onClicked: picker.pick(modelData.name)

                contentItem: RowLayout {
                    spacing: Kirigami.Units.largeSpacing

                    QQC2.Label {
                        font: Kirigami.Theme.fixedWidthFont
                        text: "%" + item.modelData.name + "%"
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideMiddle
                        opacity: 0.6
                        textFormat: Text.PlainText
                        text: item.modelData.secret ? "••••••" : item.modelData.value
                    }
                }
            }
        }

        QQC2.ItemDelegate {
            Layout.fillWidth: true
            visible: picker.offerNew
            highlighted: picker.matches.length === 0
            icon.name: "list-add"
            text: Tr.t("Insert new %1 (asked for when run)", "%" + picker.query + "%")
            onClicked: picker.pick(picker.query)
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: picker.matches.length === 0 && !picker.offerNew
            wrapMode: Text.Wrap
            opacity: 0.7
            text: picker.variables.length === 0
                ? Tr.t("No variables yet. Add them on the Variables page, or type a new name.")
                : Tr.t("Nothing found.")
        }
    }
}
