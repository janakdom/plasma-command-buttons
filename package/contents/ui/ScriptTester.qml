import QtQuick
import org.kde.plasma.plasma5support as P5Support

import "data.js" as Data

// Spuštění skriptu pro Otestovat v dialozích nastavení.
// Kontroluje neznámé filtry a chybějící proměnné (i v tělech použitých funkcí).
P5Support.DataSource {
    id: tester

    property var variables: []
    property var functions: []
    property int timeout: 30

    property bool running: false
    // { exitCode, output, timedOut } nebo null; exitCode -1 = nespuštěno
    property var result: null

    property int counter: 0

    function notRun(message) {
        result = { exitCode: -1, timedOut: false, output: message };
    }

    function test(script, workdir) {
        const fullText = Data.withFunctionBodies(script, functions);
        const badFilters = Data.unknownFilters(fullText);
        if (badFilters.length > 0) {
            notRun("Neznámý filtr " + badFilters.map(f => "|" + f).join(", ")
                + ".\nDostupné: " + Object.keys(Data.FILTERS).map(f => "|" + f).join(" "));
            return;
        }
        const values = Data.variableMap(variables);
        const missing = Data.variableNames(fullText).filter(name => !(name in values));
        if (missing.length > 0) {
            notRun("Chybí hodnoty proměnných " + missing.map(n => "%" + n + "%").join(", ")
                + ".\nPřidej je na stránce Proměnné a potvrď Použít, ve widgetu se na ně zeptá při kliknutí.");
            return;
        }
        result = null;
        running = true;
        connectSource(Data.buildRunCommand(script, values, timeout, workdir || "", functions) + " #test" + (++counter));
    }

    engine: "executable"
    connectedSources: []

    onNewData: (sourceName, data) => {
        disconnectSource(sourceName);
        const exitCode = data["exit code"];
        const timedOut = exitCode === 124 && timeout > 0;
        running = false;
        result = {
            exitCode: exitCode,
            timedOut: timedOut,
            output: timedOut
                ? "Nedoběhlo do " + timeout + " s (časový limit v Obecné)."
                : [(data["stdout"] || "").trim(), (data["stderr"] || "").trim()].filter(s => s.length > 0).join("\n")
        };
    }
}
