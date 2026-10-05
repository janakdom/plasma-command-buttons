import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.syntaxhighlighting

import "data.js" as Data

// Editor příkazu / skriptu: neproporcionální písmo, čísla řádků, zvýraznění syntaxe
// (podle shebangu), bez zalamování (vodorovně se scrolluje), automatické odsazení,
// Tab / Shift+Tab odsadí nebo zruší odsazení řádku či označeného bloku.
QQC2.ScrollView {
    id: editor

    property alias text: area.text
    property alias placeholderText: area.placeholderText

    readonly property string indentUnit: "    "
    // jazyk pro zvýraznění; mění se jen při změně shebangu. Není to vazba: přepnutí
    // zvýrazňovače přeformátuje text a vazba na text by se zacyklila.
    property string language: "Bash"

    function forceEditorFocus() {
        area.forceActiveFocus();
    }

    // vloží text na pozici kurzoru (nebo místo označeného textu)
    function insertAtCursor(snippet) {
        if (area.selectedText.length > 0) {
            area.remove(area.selectionStart, area.selectionEnd);
        }
        area.insert(area.cursorPosition, snippet);
        area.forceActiveFocus();
    }

    // vloží volání sdílené funkce $(nazev "param1" "param2") a označí první parametr,
    // takže ho stačí přepsat
    function insertCall(fn) {
        if (area.selectedText.length > 0) {
            area.remove(area.selectionStart, area.selectionEnd);
        }
        const start = area.cursorPosition;
        const snippet = Data.callSnippet(fn);
        area.insert(start, snippet);
        area.forceActiveFocus();
        if (fn.params.length > 0) {
            const first = start + snippet.indexOf('"') + 1;
            area.select(first, first + fn.params[0].length);
        }
    }

    // jazyk pro zvýraznění podle shebangu na prvním řádku
    function definitionFor(text) {
        const first = text.split("\n", 1)[0];
        if (!first.startsWith("#!")) {
            return "Bash";
        }
        if (/python/.test(first)) {
            return "Python";
        }
        if (/\b(node|deno|bun)\b/.test(first)) {
            return "JavaScript";
        }
        if (/\bperl\b/.test(first)) {
            return "Perl";
        }
        if (/\bruby\b/.test(first)) {
            return "Ruby";
        }
        if (/\bphp\b/.test(first)) {
            return "PHP (HTML)";
        }
        return "Bash";
    }

    // začátek řádku, na kterém je pozice pos
    function lineStart(pos) {
        return area.text.lastIndexOf("\n", pos - 1) + 1;
    }

    // Enter: nový řádek se stejným odsazením jako aktuální
    function newlineWithIndent() {
        if (area.selectedText.length > 0) {
            area.remove(area.selectionStart, area.selectionEnd);
        }
        const pos = area.cursorPosition;
        const indent = area.text.slice(lineStart(pos), pos).match(/^[ \t]*/)[0];
        area.insert(pos, "\n" + indent);
    }

    // odsadí (step > 0) nebo zruší odsazení (step < 0) řádků v označení / aktuálního řádku
    function indentLines(step) {
        const multiLine = area.selectedText.indexOf(" ") >= 0 || area.selectedText.indexOf("\n") >= 0;
        if (step > 0 && !multiLine) {
            insertAtCursor(indentUnit);
            return;
        }
        const start = lineStart(area.selectionStart);
        let end = area.selectionEnd;
        // označení končící na začátku řádku ten řádek nezahrnuje
        if (end > start && area.text[end - 1] === "\n") {
            end--;
        }
        const lines = area.text.slice(start, end).split("\n");
        const changed = lines.map(line => {
            if (step > 0) {
                return line.length > 0 ? indentUnit + line : line;
            }
            return line.replace(/^( {1,4}|\t)/, "");
        }).join("\n");
        area.remove(start, end);
        area.insert(start, changed);
        if (multiLine) {
            area.select(start, start + changed.length);
        }
    }

    QQC2.TextArea {
        id: area

        readonly property real lineHeight: lineCount > 0 ? contentHeight / lineCount : fontMetrics.lineSpacing
        readonly property real gutterWidth: fontMetrics.averageCharacterWidth * Math.max(2, String(lineCount).length) + Kirigami.Units.largeSpacing

        font: Kirigami.Theme.fixedWidthFont
        wrapMode: TextEdit.NoWrap
        textFormat: TextEdit.PlainText
        selectByMouse: true
        persistentSelection: true
        tabStopDistance: fontMetrics.averageCharacterWidth * 4
        leftPadding: gutterWidth + Kirigami.Units.largeSpacing

        onTextChanged: {
            const language = editor.definitionFor(text);
            if (language !== editor.language) {
                editor.language = language;
            }
        }

        Keys.onPressed: event => {
            const modifiers = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !modifiers) {
                editor.newlineWithIndent();
                event.accepted = true;
            } else if (event.key === Qt.Key_Tab && !modifiers && !(event.modifiers & Qt.ShiftModifier)) {
                editor.indentLines(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab && !modifiers) {
                editor.indentLines(-1);
                event.accepted = true;
            }
        }

        FontMetrics {
            id: fontMetrics
            font: area.font
        }

        // čísla řádků
        Repeater {
            model: area.text.length > 0 ? area.lineCount : 0

            QQC2.Label {
                required property int index
                x: Kirigami.Units.smallSpacing
                y: area.topPadding + index * area.lineHeight
                width: area.gutterWidth - Kirigami.Units.smallSpacing
                height: area.lineHeight
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                font: area.font
                opacity: 0.45
                text: index + 1
            }
        }
        Rectangle {
            x: area.gutterWidth + Kirigami.Units.smallSpacing
            y: area.topPadding
            width: 1
            height: Math.max(area.contentHeight, area.height - area.topPadding - area.bottomPadding)
            color: Kirigami.Theme.textColor
            opacity: 0.15
        }

        SyntaxHighlighter {
            textEdit: area
            definition: editor.language
            // tmavé nebo světlé barvy podle pozadí
            theme: Repository.defaultTheme(Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark
                ? Repository.DarkTheme : Repository.LightTheme)
        }
    }
}
