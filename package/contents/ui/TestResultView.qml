import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

// Výsledek tlačítka Otestovat v dialozích: stav (exit kód) a výstup.
ColumnLayout {
    id: view

    // { exitCode, output, timedOut } nebo null; exitCode -1 = nespuštěno (chyba před spuštěním)
    property var result: null

    signal closeRequested()

    visible: result !== null
    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            source: view.result && view.result.exitCode === 0 ? "dialog-ok-apply" : "dialog-error"
            isMask: true
            color: view.result && view.result.exitCode === 0
                ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
        }
        QQC2.Label {
            Layout.fillWidth: true
            font.weight: Font.DemiBold
            text: !view.result ? ""
                : view.result.exitCode === -1 ? Tr.t("Not run")
                : view.result.timedOut ? Tr.t("Time limit reached")
                : view.result.exitCode === 0 ? Tr.t("Done (exit 0)")
                : Tr.t("Error (exit %1)", view.result.exitCode)
        }
        QQC2.ToolButton {
            icon.name: "window-close"
            display: QQC2.AbstractButton.IconOnly
            text: Tr.t("Hide result")
            onClicked: view.closeRequested()
            QQC2.ToolTip.text: text
            QQC2.ToolTip.visible: hovered
        }
    }
    QQC2.ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(output.implicitHeight, Kirigami.Units.gridUnit * 10)

        QQC2.TextArea {
            id: output
            readOnly: true
            wrapMode: TextEdit.NoWrap
            textFormat: TextEdit.PlainText
            font: Kirigami.Theme.fixedWidthFont
            text: !view.result ? "" : (view.result.output || Tr.t("Nothing was printed."))
        }
    }
}
