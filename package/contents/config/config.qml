import QtQuick
import org.kde.plasma.configuration

import "../ui"

// Pořadí karet; Klávesové zkratky a O aplikaci přidává Plasma sama na konec.
// Výchozí otevřená karta je Tlačítka (přepíná na ni configGeneral.qml).
ConfigModel {
    ConfigCategory {
        name: Tr.t("General")
        icon: "preferences-desktop"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: Tr.t("Variables")
        icon: "code-variable"
        source: "configVariables.qml"
    }
    ConfigCategory {
        name: Tr.t("Buttons")
        icon: "configure"
        source: "configButtons.qml"
    }
    ConfigCategory {
        name: Tr.t("Functions")
        icon: "code-function"
        source: "configFunctions.qml"
    }
}
