import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

import "data.js" as Data

// Úprava sdílené funkce. Pracuje s kopií, změny se uloží až tlačítkem Uložit.
Kirigami.Dialog {
    id: dialog

    property var variables: []
    // všechny funkce (pro kontrolu názvu, vkládání a Otestovat)
    property var functions: []
    property int timeout: 30
    property int index: -1   // -1 = nová funkce

    signal saved(int index, var fn)
    signal deleted(int index)

    readonly property bool isNew: index < 0
    property bool editorExpanded: false
    // spouštění Otestovat (výsledek v tester.result)
    readonly property alias tester: tester

    // rozpracovaná funkce
    readonly property var draft: ({
        name: nameField.text.trim(),
        params: Data.parseParams(paramsField.text),
        description: descriptionField.text.trim(),
        body: bodyEditor.text
    })
    // ostatní vlastní funkce (bez upravované) a k nim vestavěné – pro vkládání a Otestovat
    readonly property var otherFunctions: functions.filter((f, i) => i !== index)
    readonly property var availableFunctions: Data.allFunctions(otherFunctions)

    readonly property string nameProblem: {
        if (draft.name.length === 0) {
            return "Zadej název funkce.";
        }
        if (!Data.FUNCTION_NAME.test(draft.name)) {
            return "Název smí obsahovat jen písmena bez diakritiky, číslice a _ a nesmí začínat číslicí.";
        }
        if (Data.isBuiltinName(draft.name)) {
            return "„" + draft.name + "“ je vestavěná funkce, zvol jiný název.";
        }
        if (otherFunctions.some(f => f.name === draft.name)) {
            return "Funkce s tímto názvem už existuje.";
        }
        return "";
    }

    function openNew() {
        index = -1;
        load({ name: "", params: [], description: "", body: "" });
        open();
        nameField.forceActiveFocus();
    }

    // po duplikování: označí název, aby ho stačilo přepsat
    function selectName() {
        nameField.forceActiveFocus();
        nameField.selectAll();
    }

    function openEdit(i) {
        index = i;
        load(functions[i]);
        open();
    }

    function load(fn) {
        nameField.text = fn.name;
        paramsField.text = fn.params.join(", ");
        descriptionField.text = fn.description;
        bodyEditor.text = fn.body;
        tester.result = null;
        editorExpanded = false;
        Qt.callLater(() => {
            for (let i = 0; i < argsRepeater.count; i++) {
                argsRepeater.itemAt(i).text = "";
            }
        });
    }

    function runTest() {
        const args = [];
        for (let i = 0; i < argsRepeater.count; i++) {
            args.push(Data.shellQuote(argsRepeater.itemAt(i).text));
        }
        tester.functions = availableFunctions.concat([draft]);
        tester.test([draft.name].concat(args).join(" "), "");
    }

    title: isNew ? "Nová funkce" : "Upravit funkci"
    preferredWidth: Kirigami.Units.gridUnit * 44
    padding: Kirigami.Units.largeSpacing

    standardButtons: Kirigami.Dialog.Save | Kirigami.Dialog.Cancel

    Component.onCompleted: {
        standardButton(Kirigami.Dialog.Save).enabled = Qt.binding(() => nameProblem === "" && draft.body.trim().length > 0);
    }

    onAccepted: saved(index, draft)

    ScriptTester {
        id: tester
        variables: dialog.variables
        timeout: dialog.timeout
    }

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.TextField {
                id: nameField
                Kirigami.FormData.label: "Název:"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 20
                font: Kirigami.Theme.fixedWidthFont
                placeholderText: "getWeather"
                validator: RegularExpressionValidator {
                    regularExpression: /[A-Za-z0-9_]*/
                }
            }
            QQC2.TextField {
                id: paramsField
                Kirigami.FormData.label: "Parametry:"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 20
                font: Kirigami.Theme.fixedWidthFont
                placeholderText: "city"
                QQC2.ToolTip.text: "Názvy vstupů oddělené čárkou. V těle funkce jsou dostupné jako $nazev."
                QQC2.ToolTip.visible: hovered
            }
            QQC2.TextField {
                id: descriptionField
                Kirigami.FormData.label: "Popis:"
                Layout.minimumWidth: Kirigami.Units.gridUnit * 20
                placeholderText: "Co funkce dělá a co vrací (zobrazí se při vkládání)"
            }
            QQC2.Label {
                Kirigami.FormData.label: "Volání:"
                font: Kirigami.Theme.fixedWidthFont
                opacity: 0.7
                text: dialog.nameProblem === "" ? Data.callSnippet(dialog.draft) : "—"
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: dialog.nameProblem !== "" && nameField.text.length > 0
            type: Kirigami.MessageType.Warning
            text: dialog.nameProblem
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing

            QQC2.Label {
                Layout.fillWidth: true
                text: "Tělo funkce (bash):"
            }
            QQC2.Button {
                id: insertVariableButton
                icon.name: "code-variable"
                text: "Vložit proměnnou…"
                onClicked: variablePicker.open()

                VariablePicker {
                    id: variablePicker
                    variables: dialog.variables
                    x: insertVariableButton.width - width
                    y: insertVariableButton.height
                    onPicked: name => bodyEditor.insertAtCursor("%" + name + "%")
                }
            }
            QQC2.Button {
                id: insertFunctionButton
                icon.name: "code-function"
                text: "Vložit funkci…"
                onClicked: functionPicker.open()

                FunctionPicker {
                    id: functionPicker
                    functions: dialog.availableFunctions
                    x: insertFunctionButton.width - width
                    y: insertFunctionButton.height
                    onPicked: fn => bodyEditor.insertCall(fn)
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
            id: bodyEditor
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * (dialog.editorExpanded ? 30 : 12)
            placeholderText: "curl -s \"https://wttr.in/$(urlencode \"$city\")?format=3\""
        }
        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Parametry máš v těle jako $nazev. Výsledek vrať výpisem (echo, printf), chybu přes return 1. "
                + "Proměnné z nastavení: %nazev% (i s filtry) nebo $nazev. Funkce může volat jiné funkce."
        }

        // Otestovat: zavolá funkci se zadanými hodnotami parametrů
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                id: argsRepeater
                model: dialog.draft.params

                QQC2.TextField {
                    required property string modelData
                    Layout.fillWidth: true
                    font: Kirigami.Theme.fixedWidthFont
                    placeholderText: modelData
                    onAccepted: dialog.runTest()
                }
            }
            QQC2.Button {
                icon.name: "media-playback-start"
                text: tester.running ? "Běží…" : "Otestovat"
                enabled: !tester.running && dialog.nameProblem === "" && dialog.draft.body.trim().length > 0
                onClicked: dialog.runTest()
                QQC2.ToolTip.text: "Zavolá funkci se zadanými hodnotami parametrů (bez uložení)"
                QQC2.ToolTip.visible: hovered
            }
        }

        TestResultView {
            Layout.fillWidth: true
            result: tester.result
            onCloseRequested: tester.result = null
        }

        QQC2.Button {
            Layout.topMargin: Kirigami.Units.largeSpacing
            visible: !dialog.isNew
            icon.name: "edit-delete"
            text: "Smazat funkci"
            onClicked: {
                dialog.deleted(dialog.index);
                dialog.close();
            }
        }
    }
}
