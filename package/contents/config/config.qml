import QtQuick
import org.kde.plasma.configuration

// Pořadí karet; Klávesové zkratky a O aplikaci přidává Plasma sama na konec.
// Výchozí otevřená karta je Tlačítka (přepíná na ni configGeneral.qml).
ConfigModel {
    ConfigCategory {
        name: "Obecné"
        icon: "preferences-desktop"
        source: "configGeneral.qml"
    }
    ConfigCategory {
        name: "Proměnné"
        icon: "code-variable"
        source: "configVariables.qml"
    }
    ConfigCategory {
        name: "Tlačítka"
        icon: "configure"
        source: "configButtons.qml"
    }
    ConfigCategory {
        name: "Funkce"
        icon: "code-function"
        source: "configFunctions.qml"
    }
}
