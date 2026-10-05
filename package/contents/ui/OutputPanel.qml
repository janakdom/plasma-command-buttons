import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

// Výstup posledního příkazu. Okno se mu přizpůsobí podle naturalWidth/Height
// (omezeno velikostí obrazovky), takže se běžně nescrolluje.
ColumnLayout {
    id: panel

    property string title
    property string output
    property int exitCode: 0
    property bool timedOut: false

    // rozměry, které by panel zabral bez omezení (šířka = nejdelší řádek)
    readonly property real naturalWidth: Math.max(headerRow.implicitWidth,
        measure.implicitWidth + outputText.leftPadding + outputText.rightPadding)
    readonly property real naturalHeight: headerRow.implicitHeight + spacing + outputText.implicitHeight

    signal closeRequested()

    spacing: Kirigami.Units.smallSpacing

    // jen pro změření nejdelšího řádku
    TextEdit {
        id: measure
        visible: false
        Layout.preferredWidth: 0
        Layout.preferredHeight: 0
        wrapMode: TextEdit.NoWrap
        textFormat: TextEdit.PlainText
        font: outputText.font
        text: outputText.text
    }

    RowLayout {
        id: headerRow
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: panel.exitCode === 0 ? "dialog-ok-apply" : "dialog-error"
            isMask: true
            color: panel.exitCode === 0 ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
        }
        PlasmaComponents3.Label {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font.weight: Font.DemiBold
            text: panel.title
        }
        PlasmaComponents3.Label {
            visible: panel.exitCode !== 0
            textFormat: Text.PlainText
            color: Kirigami.Theme.negativeTextColor
            text: panel.timedOut ? "časový limit" : "exit " + panel.exitCode
        }
        PlasmaComponents3.ToolButton {
            icon.name: "edit-copy"
            display: PlasmaComponents3.AbstractButton.IconOnly
            text: "Kopírovat výstup"
            onClicked: {
                outputText.selectAll();
                outputText.copy();
                outputText.deselect();
            }
            PlasmaComponents3.ToolTip.text: text
            PlasmaComponents3.ToolTip.visible: hovered
        }
        PlasmaComponents3.ToolButton {
            icon.name: "window-close"
            display: PlasmaComponents3.AbstractButton.IconOnly
            text: "Zavřít výstup"
            onClicked: panel.closeRequested()
            PlasmaComponents3.ToolTip.text: text
            PlasmaComponents3.ToolTip.visible: hovered
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Kirigami.Units.cornerRadius
        color: Qt.alpha(Kirigami.Theme.textColor, 0.06)

        Flickable {
            id: flick
            anchors.fill: parent
            clip: true
            contentWidth: width
            contentHeight: outputText.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            // scrollbar jen u extrémně dlouhého výstupu
            QQC2.ScrollBar.vertical: PlasmaComponents3.ScrollBar {
                policy: flick.contentHeight > flick.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
            }

            TextEdit {
                id: outputText
                width: flick.width
                padding: Kirigami.Units.smallSpacing * 2
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                font: Kirigami.Theme.fixedWidthFont
                color: panel.output.length > 0 ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                selectionColor: Kirigami.Theme.highlightColor
                selectedTextColor: Kirigami.Theme.highlightedTextColor
                text: panel.output.length > 0 ? panel.output : "Příkaz nic nevypsal."
            }
        }
    }
}
