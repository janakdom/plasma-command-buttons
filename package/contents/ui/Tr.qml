pragma Singleton
import QtQuick

import "i18n_cs.js" as Cs
import "i18n_de.js" as De

// Překlady rozhraní. Zdrojový jazyk je angličtina; texty se zapisují jako Tr.t("English text").
// language: "" = podle systému (nepodporovaný jazyk → angličtina), jinak "en" / "cs" / "de".
// Vazby, které volají Tr.t(), se při změně jazyka samy přepočítají (čtou vlastnost effective).
QtObject {
    property string language: ""

    readonly property var supported: ["en", "cs", "de"]
    readonly property string systemLanguage: Qt.locale().name.split("_")[0]
    readonly property string effective: {
        const lang = language || systemLanguage;
        return supported.includes(lang) ? lang : "en";
    }

    function dictionary() {
        return effective === "cs" ? Cs.strings : effective === "de" ? De.strings : null;
    }

    // přeložený text; %1, %2… se nahradí argumenty
    function t(text, ...args) {
        const dict = dictionary();
        let result = dict && typeof dict[text] === "string" ? dict[text] : text;
        args.forEach((arg, i) => {
            result = result.split("%" + (i + 1)).join(String(arg));
        });
        return result;
    }

    // množné číslo: Tr.n(5, "%1 button", "%1 buttons") – čeština má 3 tvary (1 / 2–4 / 5+),
    // ve slovníku je pod klíčem jednotného čísla pole tvarů
    function n(count, singular, plural) {
        const dict = dictionary();
        const forms = dict && Array.isArray(dict[singular]) ? dict[singular] : [singular, plural];
        let form;
        if (effective === "cs") {
            form = count === 1 ? forms[0] : (count >= 2 && count <= 4) ? forms[1] : forms[2];
        } else {
            form = count === 1 ? forms[0] : forms[forms.length - 1];
        }
        return form.split("%1").join(String(count));
    }
}
