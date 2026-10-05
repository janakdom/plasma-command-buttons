import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils
import org.kde.iconthemes as KIconThemes
import org.kde.kquickcontrols as KQuickControls

KCMUtils.SimpleKCM {
    id: page

    property string cfg_tabs
    property string cfg_tabsDefault
    property int cfg_lastTab
    property int cfg_lastTabDefault
    property bool cfg_pin
    property bool cfg_pinDefault
    property string cfg_title
    property string cfg_titleDefault
    property string cfg_variables
    property string cfg_variablesDefault
    property string cfg_functions
    property string cfg_functionsDefault
    property string cfg_prevTabShortcut
    property string cfg_prevTabShortcutDefault
    property string cfg_nextTabShortcut
    property string cfg_nextTabShortcutDefault
    property string cfg_groups
    property string cfg_groupsDefault
    property string cfg_panelIcon
    property string cfg_panelIconDefault
    property alias cfg_showOutput: showOutputCheck.checked
    property bool cfg_showOutputDefault
    property alias cfg_outputHideTimeout: hideTimeoutSpin.value
    property int cfg_outputHideTimeoutDefault
    property alias cfg_clearOutputOnOpen: clearOnOpenCheck.checked
    property bool cfg_clearOutputOnOpenDefault
    property alias cfg_timeout: timeoutSpin.value
    property int cfg_timeoutDefault

    // Výchozí karta nastavení je Tlačítka. Plasma vždy otevře první kartu (tuhle), takže
    // při prvním otevření okna (ještě není zobrazené) přepneme; při pozdějším kliknutí ne.
    Component.onCompleted: {
        const initial = typeof configDialog !== "undefined" && configDialog && !configDialog.visible;
        if (initial) {
            Qt.callLater(openButtonsPage);
        }
    }

    function openButtonsPage() {
        let root = page;
        while (root && !(typeof root.open === "function" && root.globalConfigModel !== undefined)) {
            root = root.parent;
        }
        const model = configDialog.configModel;
        if (!root || !model) {
            return;
        }
        for (let i = 0; i < model.count; i++) {
            const category = model.get(i);
            if (String(category.source).includes("configButtons")) {
                root.open(category);
                return;
            }
        }
    }

    function seconds(value, zeroText) {
        return value === 0 ? zeroText : value + " s";
    }

    // převod zkratky na přenositelný text ("Ctrl+Left"), lokalizovaný ("Ctrl+Vlevo") by se zpět nenačetl
    Shortcut {
        id: shortcutConverter
        enabled: false
    }
    function portable(keySequence) {
        shortcutConverter.sequence = keySequence;
        return shortcutConverter.portableText;
    }

    KIconThemes.IconDialog {
        id: iconDialog
        onIconNameChanged: if (iconName) page.cfg_panelIcon = iconName
    }

    Kirigami.FormLayout {
        QQC2.TextField {
            Kirigami.FormData.label: "Nadpis:"
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            placeholderText: "Příkazy"
            text: page.cfg_title
            onTextEdited: page.cfg_title = text
            QQC2.ToolTip.text: "Zobrazí se vlevo nahoře ve widgetu (pokud nemáš víc záložek) a v nápovědě ikony v panelu"
            QQC2.ToolTip.visible: hovered
        }

        QQC2.Button {
            Kirigami.FormData.label: "Ikona v panelu:"
            icon.name: page.cfg_panelIcon || "utilities-terminal"
            icon.width: Kirigami.Units.iconSizes.large
            icon.height: Kirigami.Units.iconSizes.large
            display: QQC2.AbstractButton.IconOnly
            text: "Změnit ikonu"
            onClicked: iconMenu.popup()
            QQC2.ToolTip.text: text
            QQC2.ToolTip.visible: hovered

            QQC2.Menu {
                id: iconMenu
                QQC2.MenuItem {
                    icon.name: "document-open-folder"
                    text: "Vybrat…"
                    onTriggered: iconDialog.open()
                }
                QQC2.MenuItem {
                    icon.name: "edit-clear"
                    text: "Výchozí"
                    enabled: page.cfg_panelIcon !== "utilities-terminal"
                    onTriggered: page.cfg_panelIcon = "utilities-terminal"
                }
            }
        }

        QQC2.SpinBox {
            id: timeoutSpin
            Kirigami.FormData.label: "Ukončit příkaz po:"
            from: 0
            to: 3600
            stepSize: 5
            textFromValue: value => page.seconds(value, "nikdy")
            valueFromText: text => parseInt(text) || 0
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Výstup příkazu"
        }

        QQC2.CheckBox {
            id: showOutputCheck
            text: "Zobrazit výstup v plovoucím okně"
        }

        QQC2.SpinBox {
            id: hideTimeoutSpin
            Kirigami.FormData.label: "Skrýt automaticky po:"
            enabled: showOutputCheck.checked
            from: 0
            to: 3600
            stepSize: 5
            textFromValue: value => page.seconds(value, "nikdy")
            valueFromText: text => parseInt(text) || 0
        }

        QQC2.CheckBox {
            id: clearOnOpenCheck
            enabled: showOutputCheck.checked
            text: "Při otevření widgetu začít s čistým výstupem"
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Klávesnice"
        }

        KQuickControls.KeySequenceItem {
            Kirigami.FormData.label: "Předchozí záložka:"
            keySequence: page.cfg_prevTabShortcut
            checkForConflictsAgainst: KQuickControls.ShortcutType.None
            onKeySequenceModified: page.cfg_prevTabShortcut = page.portable(keySequence)
        }

        KQuickControls.KeySequenceItem {
            Kirigami.FormData.label: "Další záložka:"
            keySequence: page.cfg_nextTabShortcut
            checkForConflictsAgainst: KQuickControls.ShortcutType.None
            onKeySequenceModified: page.cfg_nextTabShortcut = page.portable(keySequence)
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "V otevřeném widgetu: šipky vybírají tlačítko, Enter nebo mezerník ho spustí, Esc widget zavře. Zkratku pro otevření widgetu nastavíš v sekci Klávesové zkratky."
        }
    }
}
