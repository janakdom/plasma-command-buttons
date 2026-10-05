import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.Dialogs as Dialogs
import QtCore
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCMUtils
import org.kde.plasma.plasma5support as P5Support

import "data.js" as Data

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
    property bool cfg_showOutput
    property bool cfg_showOutputDefault
    property int cfg_outputHideTimeout
    property int cfg_outputHideTimeoutDefault
    property bool cfg_clearOutputOnOpen
    property bool cfg_clearOutputOnOpenDefault
    property int cfg_timeout
    property int cfg_timeoutDefault

    // Pracovní kopie záložek. Drobné změny (názvy, sloupce) se zapisují na místě
    // bez překreslení, aby políčka neztrácela fokus; ostatní volají commit().
    property var tabsData: []
    property int currentTab: 0
    readonly property var groupsData: tabsData[currentTab] ? tabsData[currentTab].groups : []

    // data čekající na potvrzení importu
    property var pendingImport: null

    function save() {
        cfg_tabs = JSON.stringify(tabsData);
    }

    function commit() {
        save();
        tabsData = JSON.parse(cfg_tabs);
        currentTab = Math.max(0, Math.min(currentTab, tabsData.length - 1));
    }

    function emptyGroup() {
        return { label: "", columns: 2, buttons: [] };
    }

    function addTab() {
        tabsData.push({ name: "Záložka " + (tabsData.length + 1), groups: [emptyGroup()] });
        currentTab = tabsData.length - 1;
        commit();
        tabNameField.forceActiveFocus();
        tabNameField.selectAll();
    }

    function moveTab(from, to) {
        const t = tabsData.splice(from, 1)[0];
        tabsData.splice(to, 0, t);
        currentTab = to;
        commit();
    }

    // --- Drag & drop tlačítek ---
    // Cílová místa se registrují (dlaždice, dlaždice „+“, karty skupin, záložky) a při tažení
    // se podle pozice kurzoru hledá, kam se tlačítko pustí.
    property var dragSource: null      // { group, index, name, icon }
    property var dropTarget: null      // { kind: "tile" | "group" | "tab", group, index, side, tab }
    property point dragScenePos: Qt.point(0, 0)
    property var dropZones: []         // { item, kind, group, index, tab }

    function registerZone(zone) {
        dropZones.push(zone);
    }

    function unregisterZone(item) {
        dropZones = dropZones.filter(z => z.item !== item);
    }

    function zoneAt(sceneX, sceneY) {
        // dlaždice a záložky mají přednost před celou kartou skupiny
        const ordered = dropZones.filter(z => z.kind !== "group-card").concat(dropZones.filter(z => z.kind === "group-card"));
        for (const zone of ordered) {
            const item = zone.item;
            if (!item || !item.visible) {
                continue;
            }
            const p = item.mapFromItem(null, sceneX, sceneY);
            if (p.x >= 0 && p.y >= 0 && p.x <= item.width && p.y <= item.height) {
                if (zone.kind === "tile") {
                    return { kind: "tile", group: zone.group, index: zone.index, side: p.x < item.width / 2 ? "before" : "after" };
                }
                if (zone.kind === "tab") {
                    return { kind: "tab", tab: zone.tab };
                }
                return { kind: "group", group: zone.group };
            }
        }
        return null;
    }

    function startDrag(group, index) {
        const button = groupsData[group].buttons[index];
        dragSource = { group: group, index: index, name: button.name, icon: button.icon };
        dropTarget = null;
    }

    function updateDrag(scenePos) {
        dragScenePos = scenePos;
        const target = zoneAt(scenePos.x, scenePos.y);
        // puštění na vlastní záložku nic nedělá
        dropTarget = target && target.kind === "tab" && target.tab === currentTab ? null : target;
    }

    function finishDrag() {
        const source = dragSource;
        const target = dropTarget;
        dragSource = null;
        dropTarget = null;
        if (!source || !target) {
            return;
        }
        const button = groupsData[source.group].buttons[source.index];

        if (target.kind === "tab") {
            const tab = tabsData[target.tab];
            groupsData[source.group].buttons.splice(source.index, 1);
            if (tab.groups.length === 0) {
                tab.groups.push(emptyGroup());
            }
            tab.groups[tab.groups.length - 1].buttons.push(button);
            commit();
            showMessage(Kirigami.MessageType.Positive, "Tlačítko přesunuto do záložky „" + tab.name + "“.");
            return;
        }

        let to = target.kind === "tile"
            ? target.index + (target.side === "after" ? 1 : 0)
            : groupsData[target.group].buttons.length;
        if (target.group === source.group) {
            // na stejné místo – nic se nemění
            if (to === source.index || to === source.index + 1) {
                return;
            }
            if (source.index < to) {
                to--;
            }
        }
        groupsData[source.group].buttons.splice(source.index, 1);
        groupsData[target.group].buttons.splice(to, 0, button);
        commit();
    }

    // posouvání stránky, když se táhne u horního / dolního okraje
    Timer {
        interval: 30
        repeat: true
        running: page.dragSource !== null
        onTriggered: {
            const flick = page.flickable;
            if (!flick) {
                return;
            }
            const p = page.mapFromItem(null, page.dragScenePos.x, page.dragScenePos.y);
            const edge = Kirigami.Units.gridUnit * 2;
            let step = 0;
            if (p.y < edge) {
                step = -Math.ceil((edge - p.y) / 4);
            } else if (p.y > page.height - edge) {
                step = Math.ceil((p.y - (page.height - edge)) / 4);
            }
            if (step !== 0) {
                const max = Math.max(0, flick.contentHeight - flick.height);
                flick.contentY = Math.max(0, Math.min(max, flick.contentY + step));
                page.updateDrag(page.dragScenePos);
            }
        }
    }

    // náhled taženého tlačítka u kurzoru
    Rectangle {
        parent: page.QQC2.Overlay.overlay
        visible: page.dragSource !== null
        z: 1000
        x: page.dragScenePos.x + Kirigami.Units.smallSpacing
        y: page.dragScenePos.y + Kirigami.Units.smallSpacing
        width: dragPreview.implicitWidth + Kirigami.Units.largeSpacing * 2
        height: dragPreview.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Kirigami.Theme.highlightColor
        opacity: 0.92

        RowLayout {
            id: dragPreview
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                source: page.dragSource ? (page.dragSource.icon || "system-run") : ""
            }
            QQC2.Label {
                visible: text.length > 0
                text: page.dragSource ? page.dragSource.name : ""
            }
        }
    }

    function moveGroup(from, to) {
        const g = groupsData.splice(from, 1)[0];
        groupsData.splice(to, 0, g);
        commit();
    }

    function addGroup() {
        groupsData.push(emptyGroup());
        commit();
    }

    function openEditor(groupIndex, buttonIndex) {
        editor.groupNames = groupsData.map((g, i) => g.label || ("Skupina " + (i + 1)));
        editor.groupCounts = groupsData.map(g => g.buttons.length);
        editor.variables = Data.loadVariables(cfg_variables);
        editor.timeout = cfg_timeout;
        editor.functions = Data.allFunctions(Data.loadFunctions(cfg_functions));
        if (buttonIndex < 0) {
            editor.openNew(groupIndex);
        } else {
            editor.openEdit(groupIndex, buttonIndex, groupsData[groupIndex].buttons[buttonIndex]);
        }
    }

    function showMessage(type, text) {
        message.type = type;
        message.text = text;
        message.visible = true;
    }

    function urlToPath(url) {
        return decodeURIComponent(url.toString().replace(/^file:\/\//, ""));
    }

    function exportTo(path) {
        shell.run("export", "printf '%s\\n' " + Data.shellQuote(Data.exportJson(tabsData, Data.loadFunctions(cfg_functions)))
            + " > " + Data.shellQuote(path), path);
    }

    function importFrom(path) {
        shell.run("import", "cat -- " + Data.shellQuote(path), path);
    }

    // Nahradit: záložky i funkce ze souboru (funkce jen pokud je soubor obsahuje).
    // Přidat: záložky na konec, funkce jen ty, jejichž název ještě neexistuje.
    function applyImport(replace) {
        const imported = pendingImport;
        pendingImport = null;
        let functions = Data.loadFunctions(cfg_functions);
        let skipped = 0;
        if (replace) {
            tabsData = imported.tabs;
            currentTab = 0;
            if (imported.functions.length > 0) {
                functions = imported.functions;
            }
        } else {
            const names = tabsData.map(t => t.name);
            imported.tabs.forEach(t => {
                if (names.includes(t.name)) {
                    t.name += " (import)";
                }
            });
            currentTab = tabsData.length;
            tabsData = tabsData.concat(imported.tabs);
            imported.functions.forEach(f => {
                if (functions.some(existing => existing.name === f.name)) {
                    skipped++;
                } else {
                    functions.push(f);
                }
            });
        }
        cfg_functions = JSON.stringify(functions);
        commit();
        showMessage(Kirigami.MessageType.Positive, "Importováno."
            + (skipped > 0 ? " " + Data.plural(skipped, "funkce se stejným názvem už existovala", "funkce se stejným názvem už existovaly", "funkcí se stejným názvem už existovalo") + " a zůstaly beze změny." : "")
            + " Změny se uloží tlačítkem Použít nebo OK.");
    }

    // TabBar si currentIndex při přidávání tlačítek mění sám, proto ho synchronizujeme ručně
    onCurrentTabChanged: Qt.callLater(syncTabBar)
    onTabsDataChanged: Qt.callLater(syncTabBar)
    function syncTabBar() {
        tabBar.currentIndex = currentTab;
    }

    Component.onCompleted: {
        tabsData = Data.loadTabs(cfg_tabs, cfg_groups);
        currentTab = Math.max(0, Math.min(cfg_lastTab, tabsData.length - 1));
    }

    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []

        property var requests: ({})
        property int counter: 0

        function run(kind, command, path) {
            const source = command + " #cfg" + (++counter);
            requests[source] = { kind: kind, path: path };
            connectSource(source);
        }

        onNewData: (sourceName, data) => {
            const req = requests[sourceName];
            disconnectSource(sourceName);
            if (!req) {
                return;
            }
            delete requests[sourceName];

            const ok = data["exit code"] === 0;
            if (req.kind === "export") {
                if (ok) {
                    page.showMessage(Kirigami.MessageType.Positive, "Uloženo do " + req.path);
                } else {
                    page.showMessage(Kirigami.MessageType.Error,
                        "Soubor se nepodařilo uložit: " + (data["stderr"] || "").trim());
                }
                return;
            }

            const imported = ok ? Data.parseImport(data["stdout"]) : null;
            if (!imported || imported.tabs.length === 0) {
                page.showMessage(Kirigami.MessageType.Error, ok
                    ? "Soubor neobsahuje platnou konfiguraci tlačítek."
                    : "Soubor se nepodařilo načíst: " + (data["stderr"] || "").trim());
                return;
            }
            page.pendingImport = imported;
            importPrompt.subtitle = "Soubor obsahuje "
                + Data.plural(imported.tabs.length, "záložku", "záložky", "záložek") + ", "
                + Data.plural(Data.countButtons(imported.tabs), "tlačítko", "tlačítka", "tlačítek") + " a "
                + Data.plural(imported.functions.length, "funkci", "funkce", "funkcí")
                + ". Chceš jimi nahradit současná tlačítka a funkce, nebo je přidat?";
            importPrompt.open();
        }
    }

    Dialogs.FileDialog {
        id: exportDialog
        title: "Exportovat tlačítka"
        fileMode: Dialogs.FileDialog.SaveFile
        nameFilters: ["Konfigurace tlačítek (*.json)"]
        defaultSuffix: "json"
        currentFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation)
        selectedFile: currentFolder + "/command-buttons.json"
        onAccepted: page.exportTo(page.urlToPath(selectedFile))
    }

    Dialogs.FileDialog {
        id: importDialog
        title: "Importovat tlačítka"
        fileMode: Dialogs.FileDialog.OpenFile
        nameFilters: ["Konfigurace tlačítek (*.json)", "Všechny soubory (*)"]
        currentFolder: StandardPaths.writableLocation(StandardPaths.HomeLocation)
        onAccepted: page.importFrom(page.urlToPath(selectedFile))
    }

    Kirigami.PromptDialog {
        id: importPrompt
        parent: page.QQC2.Overlay.overlay
        title: "Importovat tlačítka"
        standardButtons: Kirigami.Dialog.Cancel
        customFooterActions: [
            Kirigami.Action {
                icon.name: "list-add"
                text: "Přidat k současným"
                onTriggered: {
                    page.applyImport(false);
                    importPrompt.close();
                }
            },
            Kirigami.Action {
                icon.name: "document-replace"
                text: "Nahradit vše"
                onTriggered: {
                    page.applyImport(true);
                    importPrompt.close();
                }
            }
        ]
        onRejected: page.pendingImport = null
    }

    ButtonEditDialog {
        id: editor
        parent: page.QQC2.Overlay.overlay

        onSaved: (fromGroup, fromIndex, toGroup, toPosition, button) => {
            if (fromIndex >= 0) {
                page.groupsData[fromGroup].buttons.splice(fromIndex, 1);
            }
            const target = page.groupsData[toGroup].buttons;
            target.splice(Math.max(0, Math.min(toPosition, target.length)), 0, button);
            page.commit();
        }
        onDeleted: (groupIndex, buttonIndex) => {
            page.groupsData[groupIndex].buttons.splice(buttonIndex, 1);
            page.commit();
        }
    }

    footer: QQC2.ToolBar {
        position: QQC2.ToolBar.Footer

        RowLayout {
            anchors.fill: parent

            QQC2.Label {
                Layout.fillWidth: true
                elide: Text.ElideRight
                opacity: 0.7
                text: Data.plural(page.tabsData.length, "záložka", "záložky", "záložek") + " · "
                    + Data.plural(Data.countButtons(page.tabsData), "tlačítko", "tlačítka", "tlačítek")
            }
            QQC2.Button {
                icon.name: "document-import"
                text: "Importovat…"
                onClicked: importDialog.open()
            }
            QQC2.Button {
                icon.name: "document-export"
                text: "Exportovat…"
                onClicked: exportDialog.open()
            }
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.InlineMessage {
            id: message
            Layout.fillWidth: true
            showCloseButton: true
            visible: false
        }

        // Záložky
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.TabBar {
                id: tabBar
                Layout.fillWidth: true

                Repeater {
                    model: page.tabsData

                    QQC2.TabButton {
                        id: tabButton
                        required property var modelData
                        required property int index
                        readonly property bool isDropTarget: page.dropTarget !== null
                            && page.dropTarget.kind === "tab" && page.dropTarget.tab === index
                        width: implicitWidth
                        text: modelData.name || "Bez názvu"
                        onClicked: page.currentTab = index

                        // cíl pro přetažení tlačítka do jiné záložky
                        Rectangle {
                            anchors.fill: parent
                            visible: tabButton.isDropTarget
                            color: Qt.alpha(Kirigami.Theme.highlightColor, 0.2)
                            border.width: 2
                            border.color: Kirigami.Theme.highlightColor
                            radius: Kirigami.Units.cornerRadius
                        }
                        Component.onCompleted: page.registerZone({ item: tabButton, kind: "tab", tab: index })
                        Component.onDestruction: page.unregisterZone(tabButton)
                    }
                }
            }
            QQC2.ToolButton {
                icon.name: "list-add"
                display: QQC2.AbstractButton.IconOnly
                text: "Přidat záložku"
                onClicked: page.addTab()
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
            }
        }

        // Nastavení aktuální záložky
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            QQC2.Label {
                text: "Název záložky:"
            }
            QQC2.TextField {
                id: tabNameField
                Layout.fillWidth: true
                placeholderText: "např. Server, Domácnost…"
                text: page.tabsData[page.currentTab] ? page.tabsData[page.currentTab].name : ""
                onTextEdited: {
                    page.tabsData[page.currentTab].name = text;
                    page.save();
                    const button = tabBar.itemAt(page.currentTab);
                    if (button) {
                        button.text = text || "Bez názvu";
                    }
                }
            }
            QQC2.ToolButton {
                icon.name: "overflow-menu"
                display: QQC2.AbstractButton.IconOnly
                text: "Akce záložky"
                onClicked: tabMenu.popup()
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered

                QQC2.Menu {
                    id: tabMenu
                    QQC2.MenuItem {
                        icon.name: "go-previous"
                        text: "Posunout doleva"
                        enabled: page.currentTab > 0
                        onTriggered: page.moveTab(page.currentTab, page.currentTab - 1)
                    }
                    QQC2.MenuItem {
                        icon.name: "go-next"
                        text: "Posunout doprava"
                        enabled: page.currentTab < page.tabsData.length - 1
                        onTriggered: page.moveTab(page.currentTab, page.currentTab + 1)
                    }
                    QQC2.MenuSeparator {}
                    QQC2.MenuItem {
                        icon.name: "edit-delete"
                        text: "Smazat záložku"
                        enabled: page.tabsData.length > 1
                        onTriggered: {
                            page.tabsData.splice(page.currentTab, 1);
                            page.commit();
                        }
                    }
                }
            }
        }

        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.gridUnit * 2
            visible: page.groupsData.length === 0
            icon.name: "view-grid"
            text: "Záložka je prázdná"
            explanation: "Tlačítka se řadí do skupin. Začni první skupinou."
            helpfulAction: Kirigami.Action {
                icon.name: "list-add"
                text: "Přidat skupinu"
                onTriggered: page.addGroup()
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            visible: page.groupsData.length > 0
            wrapMode: Text.Wrap
            opacity: 0.7
            text: "Takhle bude záložka ve widgetu vypadat. Kliknutím na tlačítko ho upravíš, tažením přesuneš "
                + "(i do jiné skupiny nebo na název záložky), přes + přidáš nové."
        }

        Repeater {
            model: page.groupsData

            delegate: Kirigami.AbstractCard {
                id: card
                required property var modelData
                required property int index
                property int columns: modelData.columns

                Layout.fillWidth: true
                showClickFeedback: false

                readonly property bool isDropTarget: page.dropTarget !== null
                    && page.dropTarget.kind === "group" && page.dropTarget.group === index
                Component.onCompleted: page.registerZone({ item: card, kind: "group-card", group: index })
                Component.onDestruction: page.unregisterZone(card)

                // zvýraznění skupiny, do které se tlačítko přidá na konec
                Rectangle {
                    anchors.fill: parent
                    visible: card.isDropTarget
                    color: "transparent"
                    border.width: 2
                    border.color: Kirigami.Theme.highlightColor
                    radius: Kirigami.Units.cornerRadius
                    z: 10
                }

                header: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.TextField {
                        Layout.fillWidth: true
                        font.weight: Font.DemiBold
                        placeholderText: "Nadpis skupiny (nepovinný)"
                        text: card.modelData.label
                        onTextEdited: {
                            page.groupsData[card.index].label = text;
                            page.save();
                        }
                    }
                    QQC2.SpinBox {
                        from: 1
                        to: 8
                        value: card.columns
                        textFromValue: value => Data.plural(value, "sloupec", "sloupce", "sloupců")
                        valueFromText: text => parseInt(text) || 1
                        onValueModified: {
                            card.columns = value;
                            page.groupsData[card.index].columns = value;
                            page.save();
                        }
                    }
                    QQC2.ToolButton {
                        icon.name: "overflow-menu"
                        display: QQC2.AbstractButton.IconOnly
                        text: "Akce skupiny"
                        onClicked: groupMenu.popup()
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered

                        QQC2.Menu {
                            id: groupMenu
                            QQC2.MenuItem {
                                icon.name: "go-up"
                                text: "Posunout skupinu výš"
                                enabled: card.index > 0
                                onTriggered: page.moveGroup(card.index, card.index - 1)
                            }
                            QQC2.MenuItem {
                                icon.name: "go-down"
                                text: "Posunout skupinu níž"
                                enabled: card.index < page.groupsData.length - 1
                                onTriggered: page.moveGroup(card.index, card.index + 1)
                            }
                            QQC2.MenuSeparator {}
                            QQC2.MenuItem {
                                icon.name: "edit-delete"
                                text: "Smazat skupinu"
                                onTriggered: {
                                    page.groupsData.splice(card.index, 1);
                                    page.commit();
                                }
                            }
                        }
                    }
                }

                contentItem: GridLayout {
                    columns: card.columns
                    columnSpacing: Kirigami.Units.smallSpacing
                    rowSpacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: card.modelData.buttons

                        QQC2.Button {
                            id: tile
                            required property var modelData
                            required property int index
                            readonly property bool isDragged: page.dragSource !== null
                                && page.dragSource.group === card.index && page.dragSource.index === index
                            readonly property string dropSide: page.dropTarget !== null && page.dropTarget.kind === "tile"
                                && page.dropTarget.group === card.index && page.dropTarget.index === index
                                ? page.dropTarget.side : ""

                            opacity: isDragged ? 0.35 : 1
                            Component.onCompleted: page.registerZone({ item: tile, kind: "tile", group: card.index, index: index })
                            Component.onDestruction: page.unregisterZone(tile)

                            // tažení myší přesune tlačítko; kliknutí bez tažení dál otevře úpravu
                            DragHandler {
                                target: null
                                cursorShape: active ? Qt.ClosedHandCursor : Qt.ArrowCursor
                                onActiveChanged: {
                                    if (active) {
                                        page.startDrag(card.index, tile.index);
                                        page.updateDrag(centroid.scenePosition);
                                    } else {
                                        page.finishDrag();
                                    }
                                }
                                onCentroidChanged: {
                                    if (active) {
                                        page.updateDrag(centroid.scenePosition);
                                    }
                                }
                            }

                            // svislá čára: tlačítko se vloží před / za tuto dlaždici
                            Rectangle {
                                visible: tile.dropSide !== ""
                                width: 4
                                radius: 2
                                height: parent.height
                                x: tile.dropSide === "before" ? -width / 2 - columnSpacingHalf : parent.width - width / 2 + columnSpacingHalf
                                color: Kirigami.Theme.highlightColor
                                readonly property real columnSpacingHalf: Kirigami.Units.smallSpacing / 2
                            }

                            Layout.fillWidth: true
                            Layout.columnSpan: Math.min(modelData.span, card.columns)
                            Layout.preferredWidth: Layout.columnSpan
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 3.5
                            // bez názvu jen větší ikona (stejně jako ve widgetu)
                            display: modelData.name ? QQC2.AbstractButton.TextUnderIcon : QQC2.AbstractButton.IconOnly
                            icon.name: modelData.icon || "system-run"
                            readonly property int iconSize: modelData.name ? Kirigami.Units.iconSizes.medium : Math.round(Kirigami.Units.iconSizes.medium * 1.25)
                            icon.width: iconSize
                            icon.height: iconSize
                            text: modelData.name
                            onClicked: page.openEditor(card.index, index)

                            QQC2.ToolTip.text: Data.tooltipText(modelData) || "Bez nápovědy"
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        }
                    }

                    // dlaždice pro přidání nového tlačítka
                    QQC2.AbstractButton {
                        id: addTile
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 3.5
                        text: "Přidat tlačítko"
                        onClicked: page.openEditor(card.index, -1)

                        readonly property bool isDropTarget: card.isDropTarget
                        Component.onCompleted: page.registerZone({ item: addTile, kind: "group", group: card.index })
                        Component.onDestruction: page.unregisterZone(addTile)

                        background: Rectangle {
                            radius: Kirigami.Units.cornerRadius
                            color: addTile.hovered || addTile.isDropTarget ? Qt.alpha(Kirigami.Theme.highlightColor, 0.1) : "transparent"
                            border.width: 1
                            border.color: addTile.hovered || addTile.visualFocus || addTile.isDropTarget
                                ? Kirigami.Theme.highlightColor
                                : Qt.alpha(Kirigami.Theme.textColor, 0.25)
                        }
                        contentItem: ColumnLayout {
                            spacing: Kirigami.Units.smallSpacing
                            Kirigami.Icon {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                                source: "list-add"
                                opacity: 0.7
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                opacity: 0.7
                                text: "Přidat"
                            }
                        }
                    }
                }
            }
        }

        QQC2.Button {
            visible: page.groupsData.length > 0
            icon.name: "list-add"
            text: "Přidat skupinu"
            onClicked: page.addGroup()
        }
    }
}
