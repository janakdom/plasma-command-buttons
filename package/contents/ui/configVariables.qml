import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils

import "data.js" as Data

KCMUtils.SimpleKCM {
    id: page

    property string cfg_variables
    property string cfg_variablesDefault
    property string cfg_functions
    property string cfg_functionsDefault
    property string cfg_tabs
    property string cfg_tabsDefault
    property int cfg_lastTab
    property int cfg_lastTabDefault
    property bool cfg_pin
    property bool cfg_pinDefault
    property string cfg_title
    property string cfg_titleDefault
    property string cfg_prevTabShortcut
    property string cfg_prevTabShortcutDefault
    property string cfg_nextTabShortcut
    property string cfg_nextTabShortcutDefault
    property string cfg_groups
    property string cfg_groupsDefault
    property string cfg_panelIcon
    property string cfg_panelIconDefault
    property bool cfg_showOutput
    property bool cfg_showOutputDefault
    property int cfg_outputHideTimeout
    property int cfg_outputHideTimeoutDefault
    property bool cfg_clearOutputOnOpen
    property bool cfg_clearOutputOnOpenDefault
    property int cfg_timeout
    property int cfg_timeoutDefault

    // Pracovní kopie. Psaní mění data na místě (bez překreslení), přidání/smazání volá commit().
    property var variablesData: []
    // zvyšuje se při každé změně, aby se přepočítaly kontroly názvů
    property int revision: 0

    readonly property var problems: {
        revision;
        const result = [];
        const seen = {};
        variablesData.forEach(v => {
            if (v.name.length === 0) {
                return;
            }
            if (!Data.VARIABLE_NAME.test(v.name)) {
                result.push("„" + v.name + "“ není platný název");
            } else if (seen[v.name]) {
                result.push("„" + v.name + "“ je tu víckrát, platí poslední");
            }
            seen[v.name] = true;
        });
        return result;
    }

    function save() {
        cfg_variables = JSON.stringify(variablesData);
        revision++;
    }

    function commit() {
        save();
        variablesData = JSON.parse(cfg_variables);
    }

    function moveVariable(from, to) {
        const v = variablesData.splice(from, 1)[0];
        variablesData.splice(to, 0, v);
        commit();
    }

    function sortByName() {
        variablesData.sort((a, b) => a.name.localeCompare(b.name));
        commit();
    }

    function addVariable() {
        variablesData.push({ name: "", value: "", secret: false });
        commit();
        Qt.callLater(() => {
            const row = rows.itemAt(rows.count - 1);
            if (row) {
                row.focusName();
            }
        });
    }

    Component.onCompleted: variablesData = Data.loadVariables(cfg_variables)

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            text: "V příkazu tlačítka napiš <tt>%nazev%</tt> a před spuštěním se nahradí hodnotou. "
                + "Když proměnná v seznamu není, widget se na hodnotu zeptá při kliknutí."
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            opacity: 0.7
            font: Kirigami.Theme.smallFont
            text: "Například <tt>curl -H \"Authorization: Bearer %token%\" https://%server%/api</tt>. "
                + "Hodnota se vloží tak, jak je; obsahuje-li mezery, dej proměnnou v příkazu do uvozovek. "
                + "Název: písmena, číslice a _, aspoň 2 znaky, začíná písmenem a nekončí podtržítkem."
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.problems.length > 0
            type: Kirigami.MessageType.Warning
            text: page.problems.join("<br>")
        }

        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.gridUnit * 2
            visible: page.variablesData.length === 0
            icon.name: "code-variable"
            text: "Zatím žádné proměnné"
            explanation: "Hodí se pro adresy serverů, tokeny nebo cokoli, co používá víc tlačítek."
            helpfulAction: Kirigami.Action {
                icon.name: "list-add"
                text: "Přidat proměnnou"
                onTriggered: page.addVariable()
            }
        }

        Repeater {
            id: rows
            model: page.variablesData

            RowLayout {
                id: row
                required property var modelData
                required property int index
                readonly property var variable: page.variablesData[index]

                function focusName() {
                    nameField.forceActiveFocus();
                }

                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                QQC2.TextField {
                    id: nameField
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 15
                    font: Kirigami.Theme.fixedWidthFont
                    placeholderText: "nazev"
                    text: row.modelData.name
                    validator: RegularExpressionValidator {
                        regularExpression: /[A-Za-z0-9_]*/
                    }
                    onTextEdited: {
                        row.variable.name = text;
                        page.save();
                    }
                }
                QQC2.Label {
                    text: "="
                    opacity: 0.7
                }
                QQC2.TextField {
                    Layout.fillWidth: true
                    placeholderText: "hodnota"
                    echoMode: secretButton.checked && !revealButton.checked ? TextInput.Password : TextInput.Normal
                    text: row.modelData.value
                    onTextEdited: {
                        row.variable.value = text;
                        page.save();
                    }
                }
                QQC2.ToolButton {
                    id: revealButton
                    visible: secretButton.checked
                    checkable: true
                    icon.name: checked ? "password-show-off" : "password-show-on"
                    display: QQC2.AbstractButton.IconOnly
                    text: checked ? "Skrýt hodnotu" : "Ukázat hodnotu"
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.ToolButton {
                    id: secretButton
                    checkable: true
                    checked: row.modelData.secret
                    icon.name: checked ? "object-locked" : "object-unlocked"
                    display: QQC2.AbstractButton.IconOnly
                    text: checked ? "Tajná hodnota (skrytá)" : "Označit jako tajnou (heslo, token)"
                    onToggled: {
                        row.variable.secret = checked;
                        page.save();
                    }
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.ToolButton {
                    icon.name: "go-up"
                    display: QQC2.AbstractButton.IconOnly
                    text: "Posunout výš"
                    enabled: row.index > 0
                    onClicked: page.moveVariable(row.index, row.index - 1)
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.ToolButton {
                    icon.name: "go-down"
                    display: QQC2.AbstractButton.IconOnly
                    text: "Posunout níž"
                    enabled: row.index < page.variablesData.length - 1
                    onClicked: page.moveVariable(row.index, row.index + 1)
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.ToolButton {
                    icon.name: "edit-delete"
                    display: QQC2.AbstractButton.IconOnly
                    text: "Smazat proměnnou"
                    onClicked: {
                        page.variablesData.splice(row.index, 1);
                        page.commit();
                    }
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                }
            }
        }

        RowLayout {
            visible: page.variablesData.length > 0
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                icon.name: "list-add"
                text: "Přidat proměnnou"
                onClicked: page.addVariable()
            }
            QQC2.Button {
                icon.name: "view-sort-ascending-name"
                text: "Seřadit podle názvu"
                enabled: page.variablesData.length > 1
                onClicked: page.sortByName()
            }
        }
    }
}
