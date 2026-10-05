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
            return Tr.t("Enter a function name.");
        }
        if (!Data.FUNCTION_NAME.test(draft.name)) {
            return Tr.t("The name may only contain letters without accents, digits and _, and must not start with a digit.");
        }
        if (Data.isBuiltinName(draft.name)) {
            return Tr.t("“%1” is a built-in function, choose another name.", draft.name);
        }
        if (otherFunctions.some(f => f.name === draft.name)) {
            return Tr.t("A function with this name already exists.");
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

    title: isNew ? Tr.t("New function") : Tr.t("Edit function")
    preferredWidth: Kirigami.Units.gridUnit * 44
    padding: Kirigami.Units.largeSpacing

    // vlastní tlačítka místo standardních – ty by byly v jazyce systému, ne widgetu
    standardButtons: Kirigami.Dialog.NoButton
    customFooterActions: [
        Kirigami.Action {
            icon.name: "document-save"
            text: Tr.t("Save")
            enabled: dialog.nameProblem === "" && dialog.draft.body.trim().length > 0
            onTriggered: dialog.accept()
        },
        Kirigami.Action {
            icon.name: "dialog-cancel"
            text: Tr.t("Cancel")
            onTriggered: dialog.reject()
        }
    ]

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
                Kirigami.FormData.label: Tr.t("Name:")
                Layout.minimumWidth: Kirigami.Units.gridUnit * 20
                font: Kirigami.Theme.fixedWidthFont
                placeholderText: "getWeather"
                validator: RegularExpressionValidator {
                    regularExpression: /[A-Za-z0-9_]*/
                }
            }
            QQC2.TextField {
                id: paramsField
                Kirigami.FormData.label: Tr.t("Parameters:")
                Layout.minimumWidth: Kirigami.Units.gridUnit * 20
                font: Kirigami.Theme.fixedWidthFont
                placeholderText: "city"
                QQC2.ToolTip.text: Tr.t("Input names separated by commas. In the function body they are available as $name.")
                QQC2.ToolTip.visible: hovered
            }
            QQC2.TextField {
                id: descriptionField
                Kirigami.FormData.label: Tr.t("Description:")
                Layout.minimumWidth: Kirigami.Units.gridUnit * 20
                placeholderText: Tr.t("What the function does and returns (shown when inserting)")
            }
            QQC2.Label {
                Kirigami.FormData.label: Tr.t("Call:")
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
                text: Tr.t("Function body (bash):")
            }
            QQC2.Button {
                id: insertVariableButton
                icon.name: "code-variable"
                text: Tr.t("Insert variable…")
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
                text: Tr.t("Insert function…")
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
                text: dialog.editorExpanded ? Tr.t("Shrink editor") : Tr.t("Enlarge editor")
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
            text: Tr.t("Parameters are available in the body as $name. Return the result by printing it (echo, printf), signal an error with return 1. Variables from the settings: %name% (with filters) or $name. A function can call other functions.")
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
                text: tester.running ? Tr.t("Running…") : Tr.t("Test")
                enabled: !tester.running && dialog.nameProblem === "" && dialog.draft.body.trim().length > 0
                onClicked: dialog.runTest()
                QQC2.ToolTip.text: Tr.t("Calls the function with the parameter values you entered (without saving)")
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
            text: Tr.t("Delete function")
            onClicked: {
                dialog.deleted(dialog.index);
                dialog.close();
            }
        }
    }
}
