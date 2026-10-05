import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils

import "data.js" as Data

KCMUtils.SimpleKCM {
    id: page

    property string cfg_functions
    property string cfg_functionsDefault
    property string cfg_variables
    property string cfg_variablesDefault
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

    property var functionsData: []

    function commit() {
        cfg_functions = JSON.stringify(functionsData);
        functionsData = JSON.parse(cfg_functions);
    }

    function moveFunction(from, to) {
        const f = functionsData.splice(from, 1)[0];
        functionsData.splice(to, 0, f);
        commit();
    }

    // první volný název nazev_kopie, nazev_kopie2, … (nesmí kolidovat s vlastní ani vestavěnou)
    function copyName(name) {
        const taken = n => Data.isBuiltinName(n) || functionsData.some(f => f.name === n);
        let candidate = name + "_kopie";
        for (let i = 2; taken(candidate); i++) {
            candidate = name + "_kopie" + i;
        }
        return candidate;
    }

    // kopie se vloží za originál (vestavěná na konec) a hned se otevře k přejmenování
    function duplicate(fn, afterIndex) {
        const copy = {
            name: copyName(fn.name),
            params: fn.params.slice(),
            description: fn.description,
            body: fn.body
        };
        const at = afterIndex >= 0 ? afterIndex + 1 : functionsData.length;
        functionsData.splice(at, 0, copy);
        commit();
        openEditor(at);
        editor.selectName();
    }

    function openEditor(index) {
        editor.functions = functionsData;
        editor.variables = Data.loadVariables(cfg_variables);
        editor.timeout = cfg_timeout;
        if (index < 0) {
            editor.openNew();
        } else {
            editor.openEdit(index);
        }
    }

    Component.onCompleted: functionsData = Data.loadFunctions(cfg_functions)

    FunctionEditDialog {
        id: editor
        parent: page.QQC2.Overlay.overlay

        onSaved: (index, fn) => {
            if (index < 0) {
                page.functionsData.push(fn);
            } else {
                page.functionsData[index] = fn;
            }
            page.commit();
        }
        onDeleted: index => {
            page.functionsData.splice(index, 1);
            page.commit();
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            text: "Funkce jsou kousky kódu sdílené všemi tlačítky. V tlačítku je zavoláš jako příkaz, "
                + "výsledek je to, co funkce vypíše: <tt>pocasi=$(getWeather \"%city%\")</tt>. "
                + "V editoru tlačítka je najdeš přes Vložit funkci…"
        }

        Kirigami.Heading {
            Layout.topMargin: Kirigami.Units.largeSpacing
            level: 4
            text: "Vlastní funkce"
        }

        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            visible: page.functionsData.length === 0
            icon.name: "code-function"
            text: "Zatím žádné funkce"
            explanation: "Hodí se na opakující se kód, třeba dotaz na stav zařízení nebo přihlášení k API. Vestavěné funkce najdeš níž."
            helpfulAction: Kirigami.Action {
                icon.name: "list-add"
                text: "Přidat funkci"
                onTriggered: page.openEditor(-1)
            }
        }

        Repeater {
            model: page.functionsData

            QQC2.ItemDelegate {
                id: row
                required property var modelData
                required property int index

                Layout.fillWidth: true
                onClicked: page.openEditor(index)

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                        source: "code-function"
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        QQC2.Label {
                            Layout.fillWidth: true
                            font.family: Kirigami.Theme.fixedWidthFont.family
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            text: Data.signature(row.modelData)
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            elide: Text.ElideRight
                            opacity: 0.7
                            text: row.modelData.description
                        }
                        QQC2.Label {
                            Layout.fillWidth: true
                            visible: Data.isBuiltinName(row.modelData.name)
                            wrapMode: Text.Wrap
                            color: Kirigami.Theme.negativeTextColor
                            text: "Nepoužívá se: stejný název má vestavěná funkce. Přejmenuj ji, nebo ji smaž."
                        }
                    }
                    QQC2.ToolButton {
                        icon.name: "go-up"
                        display: QQC2.AbstractButton.IconOnly
                        text: "Posunout výš"
                        enabled: row.index > 0
                        onClicked: page.moveFunction(row.index, row.index - 1)
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                    }
                    QQC2.ToolButton {
                        icon.name: "go-down"
                        display: QQC2.AbstractButton.IconOnly
                        text: "Posunout níž"
                        enabled: row.index < page.functionsData.length - 1
                        onClicked: page.moveFunction(row.index, row.index + 1)
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                    }
                    QQC2.ToolButton {
                        icon.name: "edit-copy"
                        display: QQC2.AbstractButton.IconOnly
                        text: "Duplikovat"
                        onClicked: page.duplicate(row.modelData, row.index)
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                    }
                    QQC2.ToolButton {
                        icon.name: "document-edit"
                        display: QQC2.AbstractButton.IconOnly
                        text: "Upravit"
                        onClicked: page.openEditor(row.index)
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                    }
                }
            }
        }

        QQC2.Button {
            visible: page.functionsData.length > 0
            icon.name: "list-add"
            text: "Přidat funkci"
            onClicked: page.openEditor(-1)
        }

        Kirigami.Heading {
            Layout.topMargin: Kirigami.Units.gridUnit
            level: 4
            text: "Vestavěné funkce"
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            opacity: 0.7
            text: "Dostupné vždy ve všech tlačítkách i funkcích. Kliknutím zobrazíš jejich kód."
        }

        Repeater {
            model: Data.BUILTIN_FUNCTIONS

            ColumnLayout {
                id: builtinRow
                required property var modelData
                property bool expanded: false

                Layout.fillWidth: true
                spacing: 0

                QQC2.ItemDelegate {
                    Layout.fillWidth: true
                    onClicked: builtinRow.expanded = !builtinRow.expanded

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            source: "code-function"
                            opacity: 0.7
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            QQC2.Label {
                                Layout.fillWidth: true
                                font.family: Kirigami.Theme.fixedWidthFont.family
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                text: Data.signature(builtinRow.modelData)
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                opacity: 0.7
                                text: builtinRow.modelData.description
                            }
                        }
                        QQC2.ToolButton {
                            icon.name: "edit-copy"
                            display: QQC2.AbstractButton.IconOnly
                            text: "Duplikovat jako vlastní funkci"
                            onClicked: page.duplicate(builtinRow.modelData, -1)
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                        }
                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            source: builtinRow.expanded ? "arrow-up" : "arrow-down"
                            opacity: 0.6
                        }
                    }
                }
                QQC2.TextArea {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.gridUnit * 2
                    visible: builtinRow.expanded
                    readOnly: true
                    wrapMode: TextEdit.NoWrap
                    textFormat: TextEdit.PlainText
                    font: Kirigami.Theme.fixedWidthFont
                    text: builtinRow.modelData.body
                }
            }
        }
    }
}
