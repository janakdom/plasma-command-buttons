import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

import "data.js" as Data
import "nav.js" as Nav

PlasmoidItem {
    id: root

    // jazyk rozhraní z nastavení ("" = podle systému)
    Binding {
        target: Tr
        property: "language"
        value: Plasmoid.configuration.language
    }

    readonly property var tabs: Data.loadTabs(Plasmoid.configuration.tabs, Plasmoid.configuration.groups)
    readonly property int currentTab: Math.max(0, Math.min(Plasmoid.configuration.lastTab, tabs.length - 1))
    readonly property int buttonCount: Data.countButtons(tabs)
    readonly property var variables: Data.loadVariables(Plasmoid.configuration.variables)
    // vestavěné (urlencode…) + vlastní funkce z nastavení
    readonly property var functions: Data.allFunctions(Data.loadFunctions(Plasmoid.configuration.functions))

    // tlačítko čekající na doplnění chybějících proměnných:
    // { tab, group, button, name, missing: [Tr.t("name"), …] } nebo null
    property var variablePrompt: null

    // "záložka-skupina-tlačítko" -> true, pokud jeho příkaz právě běží
    property var running: ({})
    // "záložka-skupina-tlačítko" -> "ok" / "error", krátce po doběhnutí
    property var statuses: ({})
    // "záložka-skupina-tlačítko" -> čas (ms), kdy výsledek z tlačítka zmizí; každé má vlastní
    property var statusExpiry: ({})
    readonly property int statusDuration: 2000

    property string lastName: ""
    property string lastOutput: ""
    property int lastExitCode: 0
    property bool lastTimedOut: false
    property bool hasResult: false

    property int runCounter: 0
    property var pending: ({})

    // výchozí ikona v panelu je logo widgetu; v nastavení jde zvolit ikonu z motivu
    Plasmoid.icon: Plasmoid.configuration.panelIcon || Qt.resolvedUrl("../icons/command-buttons.svg")
    // připnutý widget zůstane otevřený i po kliknutí mimo něj
    hideOnWindowDeactivate: !Plasmoid.configuration.pin
    readonly property string title: Plasmoid.configuration.title || Tr.t("Commands")
    toolTipMainText: title
    toolTipSubText: buttonCount === 0 ? Tr.t("No buttons yet")
        : Tr.n(buttonCount, "%1 button", "%1 buttons")

    onExpandedChanged: () => {
        if (root.expanded && Plasmoid.configuration.clearOutputOnOpen) {
            hasResult = false;
        }
        if (!root.expanded) {
            variablePrompt = null;
        }
    }

    // automatické zavření po kliknutí; připnutý widget zůstává otevřený
    function collapse() {
        if (!Plasmoid.configuration.pin) {
            root.expanded = false;
        }
    }

    function selectTab(index) {
        Plasmoid.configuration.lastTab = index;
    }

    function withKey(map, key, value) {
        const copy = Object.assign({}, map);
        if (value) {
            copy[key] = value;
        } else {
            delete copy[key];
        }
        return copy;
    }

    // Spustí tlačítko. %nazev% v příkazu nahradí hodnotou z Proměnných (nebo z extraValues);
    // pokud některá chybí, nejdřív si ji vyžádá formulářem ve widgetu.
    function runButton(tabIndex, groupIndex, buttonIndex, extraValues) {
        const group = tabs[tabIndex] && tabs[tabIndex].groups[groupIndex];
        const btn = group && group.buttons[buttonIndex];
        const key = tabIndex + "-" + groupIndex + "-" + buttonIndex;
        if (!btn || !btn.command || running[key]) {
            return;
        }
        // skript včetně těl použitých funkcí – i v nich můžou být proměnné a filtry
        const fullText = Data.withFunctionBodies(btn.command, functions);
        const badFilters = Data.unknownFilters(fullText);
        if (badFilters.length > 0) {
            lastName = btn.name || Data.commandPreview(btn.command);
            lastExitCode = -1;
            lastTimedOut = false;
            lastOutput = Tr.t("Unknown filter %1.\nAvailable: %2", badFilters.map(f => "|" + f).join(", "),
                Object.keys(Data.FILTERS).map(f => "|" + f).join(" "));
            hasResult = true;
            setStatus(key, "error");
            return;
        }
        const values = Object.assign(Data.variableMap(variables), extraValues || {});
        const missing = Data.variableNames(fullText).filter(name => !(name in values));
        if (missing.length > 0) {
            variablePrompt = { tab: tabIndex, group: groupIndex, button: buttonIndex,
                name: btn.name || Data.commandPreview(btn.command), missing: missing };
            return;
        }
        const cmd = Data.buildRunCommand(btn.command, values, Plasmoid.configuration.timeout, btn.workdir, functions);
        // Unikátní komentář zajistí, že stejný příkaz jde spustit opakovaně
        const source = cmd + " #cb" + (++runCounter);
        pending[source] = { key: key, name: btn.name || Data.commandPreview(btn.command),
            closeMode: btn.closeMode, output: btn.output };
        running = withKey(running, key, true);
        setStatus(key, "");
        executable.connectSource(source);
        if (btn.closeMode === "immediate") {
            root.collapse();
        }
    }

    function submitVariables(values, remember) {
        const prompt = variablePrompt;
        variablePrompt = null;
        if (!prompt) {
            return;
        }
        if (remember) {
            const list = variables.filter(v => !(v.name in values));
            Object.keys(values).forEach(name => list.push({ name: name, value: values[name], secret: false }));
            Plasmoid.configuration.variables = JSON.stringify(list);
        }
        runButton(prompt.tab, prompt.group, prompt.button, values);
    }

    Timer {
        id: hideOutputTimer
        interval: Plasmoid.configuration.outputHideTimeout * 1000
        onTriggered: root.hasResult = false
    }

    function setStatus(key, status) {
        statuses = withKey(statuses, key, status);
        const expiry = Object.assign({}, statusExpiry);
        if (status) {
            expiry[key] = Date.now() + statusDuration;
        } else {
            delete expiry[key];
        }
        statusExpiry = expiry;
    }

    // maže výsledky tlačítek, kterým uplynula jejich vlastní doba zobrazení
    Timer {
        interval: 100
        repeat: true
        running: Object.keys(root.statusExpiry).length > 0
        onTriggered: {
            const now = Date.now();
            Object.keys(root.statusExpiry)
                .filter(key => root.statusExpiry[key] <= now)
                .forEach(key => root.setStatus(key, ""));
        }
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            const info = root.pending[sourceName];
            disconnectSource(sourceName);
            if (!info) {
                return;
            }
            delete root.pending[sourceName];

            const exitCode = data["exit code"];
            const stdout = (data["stdout"] || "").trim();
            const stderr = (data["stderr"] || "").trim();

            root.running = root.withKey(root.running, info.key, false);
            root.setStatus(info.key, exitCode === 0 ? "ok" : "error");

            // výstup podle nastavení tlačítka: vždy / jen při chybě / nikdy
            const showOutput = info.output === "show" || (info.output === "error" && exitCode !== 0);
            if (showOutput) {
                root.lastName = info.name;
                root.lastExitCode = exitCode;
                root.lastTimedOut = exitCode === 124 && Plasmoid.configuration.timeout > 0;
                root.lastOutput = root.lastTimedOut
                    ? Tr.t("The command did not finish within %1 s and was stopped.", Plasmoid.configuration.timeout)
                    : [stdout, stderr].filter(s => s.length > 0).join("\n");
                root.hasResult = true;

                if (Plasmoid.configuration.outputHideTimeout > 0) {
                    hideOutputTimer.restart();
                } else {
                    hideOutputTimer.stop();
                }
            }
            if (info.closeMode === "success" && exitCode === 0) {
                root.collapse();
            }
        }
    }

    fullRepresentation: Item {
        id: full

        readonly property int maxColumns: root.tabs.reduce((m, t) =>
            t.groups.reduce((n, g) => Math.max(n, g.columns), m), 1)
        readonly property real margin: Kirigami.Units.largeSpacing

        // Ovládání klávesnicí: šipky = výběr dlaždice, Enter/mezerník = spustit,
        // Esc = zavřít. Po otevření není vybráno nic, výběr začne první šipkou.
        property string selectedKey: ""
        property real navAnchorX: -1

        function clearSelection() {
            selectedKey = "";
            navAnchorX = -1;
        }

        function navigate(direction) {
            const page = pagesRepeater.itemAt(root.currentTab);
            if (!page) {
                return;
            }
            const result = Nav.navigate(page.view.tiles(), selectedKey, direction, navAnchorX);
            selectedKey = result.key;
            navAnchorX = result.anchorX;
        }

        function activateSelected() {
            const parts = selectedKey.split("-").map(Number);
            if (parts.length === 3) {
                root.runButton(parts[0], parts[1], parts[2]);
            }
        }

        function switchTab(step) {
            const count = root.tabs.length;
            const keyboard = selectedKey !== "";
            clearSelection();
            root.selectTab((root.currentTab + step + count) % count);
            // když už se ovládá klávesnicí, označ v nové záložce první tlačítko
            if (keyboard) {
                Qt.callLater(navigate, "right");
            }
        }

        focus: true
        Component.onCompleted: forceActiveFocus()

        Connections {
            target: root
            function onExpandedChanged() {
                full.clearSelection();
                if (root.expanded) {
                    full.forceActiveFocus();
                }
            }
            function onTabsChanged() {
                full.clearSelection();
            }
        }

        Keys.onPressed: event => {
            const plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
            switch (event.key) {
            case Qt.Key_Up:
            case Qt.Key_Down:
            case Qt.Key_Left:
            case Qt.Key_Right:
                if (plain) {
                    navigate({ [Qt.Key_Up]: "up", [Qt.Key_Down]: "down",
                               [Qt.Key_Left]: "left", [Qt.Key_Right]: "right" }[event.key]);
                    event.accepted = true;
                }
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                if (selectedKey !== "") {
                    activateSelected();
                    event.accepted = true;
                }
                break;
            case Qt.Key_Escape:
                // zavře i připnutý widget
                root.expanded = false;
                event.accepted = true;
                break;
            }
        }

        Shortcut {
            sequence: Plasmoid.configuration.prevTabShortcut
            enabled: root.expanded && root.tabs.length > 1
            onActivated: full.switchTab(-1)
        }
        Shortcut {
            sequence: Plasmoid.configuration.nextTabShortcut
            enabled: root.expanded && root.tabs.length > 1
            onActivated: full.switchTab(1)
        }

        // Výška nejvyšší záložky – vše se vejde bez scrollování a okno
        // při přepínání záložek neskáče
        readonly property real buttonsHeight: heading.implicitHeight + pages.implicitHeight + 2 * margin

        // Výstup je v samostatném plovoucím okně, velikost popupu se tedy nemění.
        // Ručně nastavenou velikost Plasma pamatuje; menší než obsah ale nebude.
        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: buttonsHeight
        Layout.preferredWidth: Math.max(Kirigami.Units.gridUnit * 18,
            Math.min(Kirigami.Units.gridUnit * 40, maxColumns * Kirigami.Units.gridUnit * 6 + 2 * margin))
        Layout.preferredHeight: buttonsHeight

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            PlasmaExtras.PlasmoidHeading {
                id: heading
                Layout.fillWidth: true

                RowLayout {
                    anchors.fill: parent
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Heading {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        visible: root.tabs.length < 2
                        level: 1
                        elide: Text.ElideRight
                        text: root.title
                    }

                    PlasmaComponents3.TabBar {
                        id: tabBar
                        Layout.fillWidth: true
                        visible: root.tabs.length >= 2

                        // TabBar si currentIndex při přidávání tlačítek mění sám
                        function sync() {
                            currentIndex = root.currentTab;
                        }
                        Component.onCompleted: Qt.callLater(sync)
                        Connections {
                            target: root
                            function onCurrentTabChanged() { Qt.callLater(tabBar.sync); }
                            function onTabsChanged() { Qt.callLater(tabBar.sync); }
                        }

                        Repeater {
                            model: root.tabs

                            PlasmaComponents3.TabButton {
                                required property var modelData
                                required property int index
                                focusPolicy: Qt.NoFocus
                                text: modelData.name
                                onClicked: {
                                    full.clearSelection();
                                    root.selectTab(index);
                                }
                            }
                        }
                    }

                    PlasmaComponents3.ToolButton {
                        focusPolicy: Qt.NoFocus
                        checkable: true
                        checked: Plasmoid.configuration.pin
                        icon.name: "window-pin"
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        text: checked ? Tr.t("Unpin") : Tr.t("Pin – keep open when clicking elsewhere")
                        onToggled: Plasmoid.configuration.pin = checked
                        PlasmaComponents3.ToolTip.text: text
                        PlasmaComponents3.ToolTip.visible: hovered
                    }
                    PlasmaComponents3.ToolButton {
                        focusPolicy: Qt.NoFocus
                        icon.name: "configure"
                        display: PlasmaComponents3.AbstractButton.IconOnly
                        text: Tr.t("Edit buttons")
                        onClicked: Plasmoid.internalAction("configure").trigger()
                        PlasmaComponents3.ToolTip.text: text
                        PlasmaComponents3.ToolTip.visible: hovered
                    }
                }
            }

            StackLayout {
                id: pages
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: full.margin
                currentIndex: root.currentTab

                Repeater {
                    id: pagesRepeater
                    model: root.tabs

                    Item {
                        id: page
                        required property var modelData
                        required property int index
                        readonly property bool empty: modelData.groups.every(g => g.buttons.length === 0)
                        readonly property Item view: groupsView

                        implicitHeight: empty ? placeholder.implicitHeight : groupsView.implicitHeight

                        GroupsView {
                            id: groupsView
                            anchors.left: parent.left
                            anchors.right: parent.right
                            visible: !page.empty
                            groups: page.modelData.groups
                            keyPrefix: page.index + "-"
                            running: root.running
                            statuses: root.statuses
                            selectedKey: full.selectedKey
                            onTriggered: (g, b) => root.runButton(page.index, g, b)
                        }

                        PlasmaExtras.PlaceholderMessage {
                            id: placeholder
                            anchors.centerIn: parent
                            width: parent.width
                            visible: page.empty
                            iconName: "view-grid"
                            text: Tr.t("Nothing here yet")
                            explanation: Tr.t("Add buttons with your own commands.")
                            helpfulAction: Kirigami.Action {
                                icon.name: "list-add"
                                text: Tr.t("Add button")
                                onTriggered: Plasmoid.internalAction("configure").trigger()
                            }
                        }
                    }
                }
            }
        }

        // Formulář pro proměnné, které nejsou v nastavení (překryje tlačítka)
        VariableForm {
            anchors.fill: parent
            visible: root.variablePrompt !== null
            prompt: root.variablePrompt
            margin: full.margin
            onSubmitted: (values, remember) => {
                root.submitVariables(values, remember);
                full.forceActiveFocus();
            }
            onCancelled: {
                root.variablePrompt = null;
                full.forceActiveFocus();
            }
        }

        // Plovoucí okno s výstupem, přilepené k popupu na straně odvrácené od panelu
        PlasmaCore.Dialog {
            id: outputWindow

            visualParent: full
            location: Plasmoid.location
            flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
            hideOnWindowDeactivate: false
            visible: root.expanded && Plasmoid.configuration.showOutput && root.hasResult

            mainItem: OutputPanel {
                // Šířka podle nejdelšího řádku, výška podle obsahu; omezeno velikostí obrazovky
                width: Math.max(Kirigami.Units.gridUnit * 18,
                    Math.min(naturalWidth, full.Screen.desktopAvailableWidth * 0.6))
                height: Math.min(naturalHeight, full.Screen.desktopAvailableHeight * 0.6)
                title: root.lastName
                output: root.lastOutput
                exitCode: root.lastExitCode
                timedOut: root.lastTimedOut
                onCloseRequested: root.hasResult = false
            }
        }
    }
}
