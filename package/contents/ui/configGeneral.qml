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
    property string cfg_language
    property string cfg_languageDefault
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
        Tr.language = cfg_language;
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
        // jazyk rozhraní; projeví se po Použít / OK
        QQC2.ComboBox {
            Kirigami.FormData.label: Tr.t("Language:")
            readonly property var codes: ["", "en", "cs", "de"]
            // názvy jazyků jsou vždy ve vlastním jazyce, aby je každý našel
            model: [Tr.t("System default"), "English", "Čeština", "Deutsch"]
            currentIndex: Math.max(0, codes.indexOf(page.cfg_language))
            onActivated: index => page.cfg_language = codes[index]
        }

        QQC2.TextField {
            Kirigami.FormData.label: Tr.t("Title:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            placeholderText: Tr.t("Commands")
            text: page.cfg_title
            onTextEdited: page.cfg_title = text
            QQC2.ToolTip.text: Tr.t("Shown in the top-left corner of the widget (unless you have several tabs) and in the panel icon tooltip")
            QQC2.ToolTip.visible: hovered
        }

        QQC2.Button {
            Kirigami.FormData.label: Tr.t("Panel icon:")
            // prázdné = logo widgetu
            icon.name: page.cfg_panelIcon
            icon.source: page.cfg_panelIcon ? "" : Qt.resolvedUrl("../icons/command-buttons.svg")
            icon.width: Kirigami.Units.iconSizes.large
            icon.height: Kirigami.Units.iconSizes.large
            display: QQC2.AbstractButton.IconOnly
            text: Tr.t("Change icon")
            onClicked: iconMenu.popup()
            QQC2.ToolTip.text: text
            QQC2.ToolTip.visible: hovered

            QQC2.Menu {
                id: iconMenu
                QQC2.MenuItem {
                    icon.name: "document-open-folder"
                    text: Tr.t("Choose…")
                    onTriggered: iconDialog.open()
                }
                QQC2.MenuItem {
                    icon.name: "edit-clear"
                    text: Tr.t("Default")
                    enabled: page.cfg_panelIcon !== ""
                    onTriggered: page.cfg_panelIcon = ""
                }
            }
        }

        QQC2.SpinBox {
            id: timeoutSpin
            Kirigami.FormData.label: Tr.t("Stop command after:")
            from: 0
            to: 3600
            stepSize: 5
            // SpinBox přepočítá text jen při změně hodnoty nebo locale – locale proto sleduje jazyk widgetu
            locale: Qt.locale(Tr.effective)
            textFromValue: value => page.seconds(value, Tr.t("never"))
            valueFromText: text => parseInt(text) || 0
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Tr.t("Command output")
        }

        QQC2.CheckBox {
            id: showOutputCheck
            text: Tr.t("Show output in a floating window")
        }

        QQC2.SpinBox {
            id: hideTimeoutSpin
            Kirigami.FormData.label: Tr.t("Hide automatically after:")
            enabled: showOutputCheck.checked
            from: 0
            to: 3600
            stepSize: 5
            // SpinBox přepočítá text jen při změně hodnoty nebo locale – locale proto sleduje jazyk widgetu
            locale: Qt.locale(Tr.effective)
            textFromValue: value => page.seconds(value, Tr.t("never"))
            valueFromText: text => parseInt(text) || 0
        }

        QQC2.CheckBox {
            id: clearOnOpenCheck
            enabled: showOutputCheck.checked
            text: Tr.t("Start with a clean output when the widget opens")
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: Tr.t("Keyboard")
        }

        KQuickControls.KeySequenceItem {
            Kirigami.FormData.label: Tr.t("Previous tab:")
            keySequence: page.cfg_prevTabShortcut
            checkForConflictsAgainst: KQuickControls.ShortcutType.None
            onKeySequenceModified: page.cfg_prevTabShortcut = page.portable(keySequence)
        }

        KQuickControls.KeySequenceItem {
            Kirigami.FormData.label: Tr.t("Next tab:")
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
            text: Tr.t("In the open widget: arrow keys select a button, Enter or Space runs it, Esc closes the widget. A shortcut that opens the widget can be set in the Keyboard Shortcuts section.")
        }
    }
}
