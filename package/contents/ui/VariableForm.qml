import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Formulář na doplnění proměnných, které nejsou v nastavení. Překryje tlačítka ve widgetu.
Rectangle {
    id: form

    // { name, missing: [Tr.t("name"), …] } nebo null
    property var prompt: null
    property real margin: Kirigami.Units.largeSpacing

    readonly property var missing: prompt ? prompt.missing : []

    signal submitted(var values, bool remember)
    signal cancelled()

    function submit() {
        const values = {};
        for (let i = 0; i < fieldsRepeater.count; i++) {
            const item = fieldsRepeater.itemAt(i);
            values[item.name] = item.value;
        }
        submitted(values, rememberCheck.checked);
    }

    color: Kirigami.Theme.backgroundColor

    onVisibleChanged: {
        if (visible) {
            rememberCheck.checked = false;
            Qt.callLater(() => {
                const first = fieldsRepeater.itemAt(0);
                if (first) {
                    first.focusField();
                }
            });
        }
    }

    // šipky a Esc nesmí propadnout do navigace po tlačítkách pod formulářem
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            cancelled();
            event.accepted = true;
        } else if ([Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right].includes(event.key)) {
            event.accepted = true;
        }
    }

    // zachytí kliknutí, aby nešla spouštět tlačítka pod formulářem
    MouseArea {
        anchors.fill: parent
    }

    PlasmaComponents3.ScrollView {
        id: scroll
        anchors.fill: parent
        anchors.margins: form.margin
        contentWidth: availableWidth

        ColumnLayout {
            width: scroll.availableWidth
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 3
                wrapMode: Text.Wrap
                text: Tr.t("Run “%1”", form.prompt ? form.prompt.name : "")
            }
            PlasmaComponents3.Label {
                Layout.fillWidth: true
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                wrapMode: Text.Wrap
                opacity: 0.7
                text: form.missing.length === 1
                    ? Tr.t("The command uses a variable that is not in the settings:")
                    : Tr.t("The command uses variables that are not in the settings:")
            }

            Repeater {
                id: fieldsRepeater
                model: form.missing

                ColumnLayout {
                    id: fieldItem
                    required property string modelData
                    required property int index
                    readonly property string name: modelData
                    readonly property string value: field.text

                    function focusField() {
                        field.forceActiveFocus();
                    }

                    Layout.fillWidth: true
                    spacing: 0

                    PlasmaComponents3.Label {
                        font: Kirigami.Theme.fixedWidthFont
                        text: "%" + fieldItem.name + "%"
                    }
                    PlasmaComponents3.TextField {
                        id: field
                        Layout.fillWidth: true
                        placeholderText: Tr.t("Value")
                        // Enter přejde na další políčko, v posledním spustí příkaz
                        onAccepted: {
                            const next = fieldsRepeater.itemAt(fieldItem.index + 1);
                            if (next) {
                                next.focusField();
                            } else {
                                form.submit();
                            }
                        }
                    }
                }
            }

            PlasmaComponents3.CheckBox {
                id: rememberCheck
                Layout.topMargin: Kirigami.Units.smallSpacing
                focusPolicy: Qt.NoFocus
                text: Tr.t("Save as variables for next time")
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing

                Item {
                    Layout.fillWidth: true
                }
                PlasmaComponents3.Button {
                    focusPolicy: Qt.NoFocus
                    icon.name: "dialog-cancel"
                    text: Tr.t("Cancel")
                    onClicked: form.cancelled()
                }
                PlasmaComponents3.Button {
                    focusPolicy: Qt.NoFocus
                    icon.name: "media-playback-start"
                    text: Tr.t("Run")
                    onClicked: form.submit()
                }
            }
        }
    }
}
