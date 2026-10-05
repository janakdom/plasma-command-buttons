import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import QtQuick.Dialogs as Dialogs
import org.kde.iconthemes as KIconThemes

import "data.js" as Data

// Úprava jednoho tlačítka. Pracuje s kopií, změny se uloží až tlačítkem Uložit.
Kirigami.Dialog {
    id: dialog

    // názvy skupin a počty tlačítek v nich (pro výběr skupiny a pořadí)
    property var groupNames: []
    property var groupCounts: []
    // proměnné z nastavení pro vkládání do příkazu
    property var variables: []
    // sdílené funkce z nastavení (vkládání do příkazu, Otestovat)
    property var functions: []
    // časový limit z nastavení (platí i pro Otestovat)
    property int timeout: 30
    property int groupIndex: -1
    property int buttonIndex: -1   // -1 = nové tlačítko

    // signál nese hotová data, rodič je zapíše do konfigurace
    signal saved(int fromGroup, int fromIndex, int toGroup, int toPosition, var button)
    signal deleted(int groupIndex, int buttonIndex)

    readonly property bool isNew: buttonIndex < 0
    property string iconName: ""
    readonly property var closeModes: ["none", "immediate", "success"]
    readonly property var outputModes: ["show", "error", "hide"]

    property bool editorExpanded: false
    // spouštění Otestovat (výsledek v tester.result)
    readonly property alias tester: tester

    function openNew(group) {
        groupIndex = group;
        buttonIndex = -1;
        load({ name: "", command: "", icon: "", span: 1, closeMode: "none", output: "show", tooltip: "", tooltipEnabled: true, workdir: "" }, groupCounts[group] + 1);
        open();
        nameField.forceActiveFocus();
    }

    function openEdit(group, index, button) {
        groupIndex = group;
        buttonIndex = index;
        load(button, index + 1);
        open();
    }

    function load(b, position) {
        nameField.text = b.name || "";
        commandArea.text = b.command || "";
        iconName = b.icon || "";
        spanSpin.value = b.span || 1;
        closeCombo.currentIndex = Math.max(0, closeModes.indexOf(b.closeMode || "none"));
        outputCombo.currentIndex = Math.max(0, outputModes.indexOf(b.output || "show"));
        tooltipCheck.checked = b.tooltipEnabled !== false;
        tooltipArea.text = b.tooltip || "";
        workdirField.text = b.workdir || "";
        tester.result = null;
        editorExpanded = false;
        groupCombo.currentIndex = groupIndex;
        positionSpin.value = position;
    }

    title: isNew ? "Nové tlačítko" : "Upravit tlačítko"
    preferredWidth: Kirigami.Units.gridUnit * 44
    padding: Kirigami.Units.largeSpacing

    standardButtons: Kirigami.Dialog.Save | Kirigami.Dialog.Cancel

    Component.onCompleted: {
        standardButton(Kirigami.Dialog.Save).enabled = Qt.binding(() => commandArea.text.trim().length > 0);
    }

    onAccepted: {
        const toGroup = groupCombo.currentIndex;
        saved(groupIndex, buttonIndex, toGroup, positionSpin.value - 1, {
            name: nameField.text.trim(),
            command: commandArea.text,
            icon: iconName,
            span: spanSpin.value,
            closeMode: closeModes[closeCombo.currentIndex],
            output: outputModes[outputCombo.currentIndex],
            tooltip: tooltipArea.text.trim().length > 0 ? tooltipArea.text : "",
            tooltipEnabled: tooltipCheck.checked,
            workdir: workdirField.text.trim()
        });
    }

    ScriptTester {
        id: tester
        variables: dialog.variables
        functions: dialog.functions
        timeout: dialog.timeout
    }

    Dialogs.FolderDialog {
        id: folderDialog
        title: "Pracovní adresář"
        onAccepted: workdirField.text = decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, ""))
    }

    KIconThemes.IconDialog {
        id: iconDialog
        onIconNameChanged: if (iconName) dialog.iconName = iconName
    }

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                icon.name: dialog.iconName || "system-run"
                icon.width: Kirigami.Units.iconSizes.medium
                icon.height: Kirigami.Units.iconSizes.medium
                display: QQC2.AbstractButton.IconOnly
                text: "Změnit ikonu"
                onClicked: iconDialog.open()
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
            }
            QQC2.TextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: "Název tlačítka, např. Restart serveru"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing

            QQC2.Label {
                Layout.fillWidth: true
                text: "Příkaz nebo skript:"
            }
            QQC2.Button {
                id: insertVariableButton
                icon.name: "code-variable"
                text: "Vložit proměnnou…"
                onClicked: variablePicker.open()

                VariablePicker {
                    id: variablePicker
                    variables: dialog.variables
                    // pod tlačítkem, zarovnané k jeho pravému okraji
                    x: insertVariableButton.width - width
                    y: insertVariableButton.height
                    onPicked: name => commandArea.insertAtCursor("%" + name + "%")
                }
            }
            QQC2.Button {
                id: insertFunctionButton
                icon.name: "code-function"
                text: "Vložit funkci…"
                onClicked: functionPicker.open()

                FunctionPicker {
                    id: functionPicker
                    functions: dialog.functions
                    x: insertFunctionButton.width - width
                    y: insertFunctionButton.height
                    onPicked: fn => commandArea.insertCall(fn)
                }
            }
            QQC2.ToolButton {
                icon.name: dialog.editorExpanded ? "view-restore" : "view-fullscreen"
                display: QQC2.AbstractButton.IconOnly
                text: dialog.editorExpanded ? "Zmenšit editor" : "Zvětšit editor"
                onClicked: dialog.editorExpanded = !dialog.editorExpanded
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
            }
        }
        CommandEditor {
            id: commandArea
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * (dialog.editorExpanded ? 30 : 14)
            placeholderText: "Jeden příkaz, např. curl -s https://example.com/akce\n\nnebo celý skript:\nset -euo pipefail\nfor host in server1 server2; do\n    ssh \"$host\" uptime\ndone\n\nPrvní řádek #!/usr/bin/env python3 spustí skript v Pythonu."
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Spouští se jako skript (bash, nebo interpret ze shebangu #!). Proměnné jsou dostupné jako %nazev% "
                + "i jako proměnné prostředí ($nazev). Filtry: %nazev|urlencode%, |base64, |json, |shell, |lower, |upper "
                + "(dají se řetězit). Tab / Shift+Tab odsadí řádky."
        }

        // Otestovat: spustí skript hned a výsledek ukáže pod tlačítkem
        RowLayout {
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                icon.name: "media-playback-start"
                text: tester.running ? "Běží…" : "Otestovat"
                enabled: !tester.running && commandArea.text.trim().length > 0
                onClicked: tester.test(commandArea.text, workdirField.text.trim())
            }
            QQC2.Label {
                opacity: 0.7
                font: Kirigami.Theme.smallFont
                text: "Spustí skript hned teď (bez uložení) a ukáže výstup."
            }
        }

        TestResultView {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            result: tester.result
            onCloseRequested: tester.result = null
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing

            QQC2.ComboBox {
                id: closeCombo
                Kirigami.FormData.label: "Po kliknutí:"
                model: ["Nechat widget otevřený", "Hned widget zavřít", "Zavřít, když příkaz uspěje"]
            }

            RowLayout {
                Kirigami.FormData.label: "Pracovní adresář:"
                Layout.fillWidth: true

                QQC2.TextField {
                    id: workdirField
                    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
                    placeholderText: "~ (domovská složka)"
                }
                QQC2.Button {
                    icon.name: "document-open-folder"
                    display: QQC2.AbstractButton.IconOnly
                    text: "Vybrat složku"
                    onClicked: folderDialog.open()
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                }
            }

            QQC2.ComboBox {
                id: outputCombo
                Kirigami.FormData.label: "Výstup:"
                model: ["Zobrazit", "Zobrazit jen při chybě", "Nezobrazovat"]
                QQC2.ToolTip.text: "Fajfka nebo křížek na tlačítku se ukáže vždy"
                QQC2.ToolTip.visible: hovered
            }

            QQC2.CheckBox {
                id: tooltipCheck
                Kirigami.FormData.label: "Při najetí myší:"
                text: "Zobrazovat nápovědu"
            }

            QQC2.TextArea {
                id: tooltipArea
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 18
                Layout.minimumHeight: Kirigami.Units.gridUnit * 3
                visible: tooltipCheck.checked
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                placeholderText: "Vlastní text nápovědy, může mít víc řádků.\nKdyž zůstane prázdné, zobrazí se příkaz."
            }

            QQC2.SpinBox {
                id: spanSpin
                Kirigami.FormData.label: "Šířka:"
                from: 1
                to: 8
                textFromValue: value => value + (value === 1 ? " sloupec" : value < 5 ? " sloupce" : " sloupců")
                valueFromText: text => parseInt(text) || 1
            }

            QQC2.ComboBox {
                id: groupCombo
                Kirigami.FormData.label: "Skupina:"
                visible: dialog.groupNames.length > 1
                model: dialog.groupNames
                onActivated: positionSpin.value = positionSpin.to
            }

            QQC2.SpinBox {
                id: positionSpin
                Kirigami.FormData.label: "Pořadí:"
                from: 1
                // v cílové skupině může být o jedno víc, pokud tam tlačítko přesouváme
                to: Math.max(1, (dialog.groupCounts[groupCombo.currentIndex] || 0)
                    + (dialog.isNew || groupCombo.currentIndex !== dialog.groupIndex ? 1 : 0))
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                visible: !dialog.isNew
            }

            QQC2.Button {
                visible: !dialog.isNew
                icon.name: "edit-delete"
                text: "Smazat tlačítko"
                onClicked: {
                    dialog.deleted(dialog.groupIndex, dialog.buttonIndex);
                    dialog.close();
                }
            }
        }
    }
}
