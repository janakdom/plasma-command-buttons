.pragma library

// Formát exportu: { app, version, tabs: [{ name, groups: [{ label, columns, buttons: [...] }] }] }
var APP_ID = "cz.janakd.commandbuttons";
var CLOSE_MODES = ["none", "immediate", "success"];
// zobrazení výstupu tlačítka: vždy / jen když příkaz selže / nikdy
var OUTPUT_MODES = ["show", "error", "hide"];

function normalizeButton(b) {
    b = b || {};
    return {
        name: String(b.name || ""),
        command: String(b.command || ""),
        icon: String(b.icon || ""),
        span: Math.max(1, parseInt(b.span) || 1),
        // closeOnRun = starší formát nastavení
        closeMode: CLOSE_MODES.indexOf(b.closeMode) >= 0 ? b.closeMode : (b.closeOnRun ? "immediate" : "none"),
        output: OUTPUT_MODES.indexOf(b.output) >= 0 ? b.output : "show",
        // nápověda při najetí myší; prázdná = zobrazí se příkaz
        tooltip: String(b.tooltip || ""),
        tooltipEnabled: b.tooltipEnabled !== false,
        // pracovní adresář skriptu; prázdný = domovská složka
        workdir: String(b.workdir || "")
    };
}

function normalizeGroups(list) {
    if (!Array.isArray(list)) {
        return [];
    }
    return list.map(function (g) {
        g = g || {};
        return {
            label: String(g.label || ""),
            columns: Math.max(1, parseInt(g.columns) || 2),
            buttons: (Array.isArray(g.buttons) ? g.buttons : []).map(normalizeButton)
        };
    });
}

function normalizeTabs(list) {
    if (!Array.isArray(list)) {
        return [];
    }
    return list.map(function (t, i) {
        t = t || {};
        return {
            name: String(t.name || ("Tab " + (i + 1))),
            groups: normalizeGroups(t.groups)
        };
    });
}

function parseJson(text) {
    try {
        return JSON.parse(text);
    } catch (e) {
        return undefined;
    }
}

// Načte záložky z konfigurace; starší konfigurace bez záložek (jen "groups")
// se převede na jednu záložku "Hlavní".
function loadTabs(tabsJson, groupsJson) {
    var tabs = parseJson(tabsJson);
    if (Array.isArray(tabs) && tabs.length > 0) {
        return normalizeTabs(tabs);
    }
    return [{ name: "Main", groups: normalizeGroups(parseJson(groupsJson)) }];
}

// Přijme export, holé pole záložek nebo holé pole skupin.
// Vrací { tabs, functions } nebo null, pokud soubor nedává smysl.
function parseImport(text) {
    var data = parseJson(text);
    if (data && Array.isArray(data.tabs)) {
        return { tabs: normalizeTabs(data.tabs), functions: normalizeFunctions(data.functions) };
    }
    if (Array.isArray(data) && data.length > 0) {
        if (data[0] && Array.isArray(data[0].groups)) {
            return { tabs: normalizeTabs(data), functions: [] };
        }
        if (data[0] && Array.isArray(data[0].buttons)) {
            return { tabs: [{ name: "Imported", groups: normalizeGroups(data) }], functions: [] };
        }
    }
    return null;
}

function exportJson(tabs, functions) {
    return JSON.stringify({ app: APP_ID, version: 1, tabs: tabs, functions: functions || [] }, null, 2);
}

function countButtons(tabs) {
    var n = 0;
    tabs.forEach(function (t) {
        t.groups.forEach(function (g) {
            n += g.buttons.length;
        });
    });
    return n;
}

// krátký popis tlačítka bez názvu: první řádek příkazu
function commandPreview(command) {
    var line = String(command).split("\n").map(function (l) { return l.trim(); })
        .filter(function (l) { return l.length > 0; })[0] || "";
    return line.length > 40 ? line.slice(0, 39) + "…" : line;
}

// text tooltipu tlačítka: vlastní nápověda, jinak začátek příkazu; "" = nezobrazovat
function tooltipText(button) {
    if (button.tooltipEnabled === false) {
        return "";
    }
    if (button.tooltip && button.tooltip.trim().length > 0) {
        return button.tooltip;
    }
    var lines = String(button.command || "").split("\n");
    return lines.length > 8 ? lines.slice(0, 8).join("\n") + "\n…" : String(button.command || "");
}


function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

// --- Proměnné v příkazech: %nazev% ---
// Název začíná písmenem, má aspoň 2 znaky a nekončí podtržítkem, aby se za proměnnou
// nepovažovaly formáty jako date +%Y%m%d nebo +%d_%H.
var VARIABLE_NAME = /^[A-Za-z][A-Za-z0-9_]*[A-Za-z0-9]$/;

// %nazev% nebo s filtry %nazev|urlencode|upper% (názvy filtrů bez ohledu na velikost písmen)
function variablePattern() {
    return /%([A-Za-z][A-Za-z0-9_]*[A-Za-z0-9])((?:\|[A-Za-z0-9]+)*)%/g;
}

function utf8Base64(text) {
    var bytes = unescape(encodeURIComponent(text));
    var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    var out = "";
    for (var i = 0; i < bytes.length; i += 3) {
        var n = (bytes.charCodeAt(i) << 16) | ((bytes.charCodeAt(i + 1) || 0) << 8) | (bytes.charCodeAt(i + 2) || 0);
        out += chars[(n >> 18) & 63] + chars[(n >> 12) & 63]
            + (i + 1 < bytes.length ? chars[(n >> 6) & 63] : "=")
            + (i + 2 < bytes.length ? chars[n & 63] : "=");
    }
    return out;
}

// filtry použitelné jako %nazev|filtr%
var FILTERS = {
    urlencode: function (v) { return encodeURIComponent(v); },
    base64: utf8Base64,
    json: function (v) { return JSON.stringify(v); },
    shell: function (v) { return shellQuote(v); },
    lower: function (v) { return v.toLowerCase(); },
    upper: function (v) { return v.toUpperCase(); }
};

// neznámé filtry v příkazu, např. ["urlEncode"] – ohlásí se místo tichého ignorování
function unknownFilters(command) {
    var unknown = [];
    var re = variablePattern();
    var m;
    while ((m = re.exec(command)) !== null) {
        m[2].split("|").slice(1).forEach(function (f) {
            if (!FILTERS.hasOwnProperty(f.toLowerCase()) && unknown.indexOf(f) < 0) {
                unknown.push(f);
            }
        });
    }
    return unknown;
}

function normalizeVariables(list) {
    if (!Array.isArray(list)) {
        return [];
    }
    return list.map(function (v) {
        v = v || {};
        return { name: String(v.name || ""), value: String(v.value || ""), secret: !!v.secret };
    });
}

function loadVariables(json) {
    return normalizeVariables(parseJson(json));
}

// { nazev: hodnota } jen z platně pojmenovaných proměnných
function variableMap(variables) {
    var map = {};
    variables.forEach(function (v) {
        if (VARIABLE_NAME.test(v.name)) {
            map[v.name] = v.value;
        }
    });
    return map;
}

// názvy proměnných použitých v příkazu (bez opakování, v pořadí výskytu)
function variableNames(command) {
    var names = [];
    var re = variablePattern();
    var m;
    while ((m = re.exec(command)) !== null) {
        if (names.indexOf(m[1]) < 0) {
            names.push(m[1]);
        }
    }
    return names;
}

function substitute(command, values) {
    return command.replace(variablePattern(), function (match, name, filters) {
        if (!Object.prototype.hasOwnProperty.call(values, name)) {
            return match;
        }
        return filters.split("|").slice(1).reduce(function (value, f) {
            f = f.toLowerCase();
            return FILTERS.hasOwnProperty(f) ? FILTERS[f](value) : value;
        }, String(values[name]));
    });
}

// --- Sdílené funkce ---
// Funkce z nastavení se při spuštění zpřístupní jako příkazy v PATH, takže jdou volat
// z bashe (pocasi=$(getWeather "$city")) i z jiných jazyků (subprocess…).
// Parametry jsou v těle dostupné pod svými názvy ($id), návratovou hodnotou je výstup.
var FUNCTION_NAME = /^[A-Za-z_][A-Za-z0-9_]*$/;

function parseParams(text) {
    return String(text || "").split(/[\s,]+/).filter(function (p) {
        return FUNCTION_NAME.test(p);
    });
}

function normalizeFunctions(list) {
    if (!Array.isArray(list)) {
        return [];
    }
    return list.map(function (f) {
        f = f || {};
        return {
            name: String(f.name || ""),
            params: Array.isArray(f.params) ? f.params.filter(function (p) { return FUNCTION_NAME.test(p); }) : parseParams(f.params),
            description: String(f.description || ""),
            body: String(f.body || "")
        };
    });
}

function loadFunctions(json) {
    return normalizeFunctions(parseJson(json));
}

function signature(fn) {
    return fn.name + "(" + fn.params.join(", ") + ")";
}

// volání pro vložení do skriptu, např. $(getWeather "city")
function callSnippet(fn) {
    return "$(" + fn.name + fn.params.map(function (p) { return ' "' + p + '"'; }).join("") + ")";
}

function escapeRegExp(text) {
    return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// funkce, které text používá – i nepřímo přes jiné funkce
function usedFunctions(text, functions) {
    var valid = functions.filter(function (f) { return FUNCTION_NAME.test(f.name); });
    var used = [];
    var queue = [text];
    while (queue.length > 0) {
        var current = queue.shift();
        valid.forEach(function (f) {
            if (used.indexOf(f) < 0 && new RegExp("(^|[^A-Za-z0-9_])" + escapeRegExp(f.name) + "([^A-Za-z0-9_]|$)").test(current)) {
                used.push(f);
                queue.push(f.body);
            }
        });
    }
    return used;
}

// Vestavěné funkce: dostupné vždy, v nastavení jen pro čtení. Čistý bash (+ coreutils base64).
// Popisy jsou anglicky – v rozhraní se překládají přes Tr.t().
var BUILTIN_FUNCTIONS = normalizeFunctions([
    {
        name: "urlencode",
        params: ["text"],
        description: "URL-encodes text (a b/c → a%20b%2Fc)",
        body: [
            "local LC_ALL=C i c out=",
            "for (( i = 0; i < ${#text}; i++ )); do",
            "    c=${text:i:1}",
            "    case $c in",
            "        [a-zA-Z0-9.~_-]) out+=$c ;;",
            "        *) printf -v c '%%%02X' \"'$c\"; out+=$c ;;",
            "    esac",
            "done",
            "printf '%s\\n' \"$out\""
        ].join("\n")
    },
    {
        name: "urldecode",
        params: ["text"],
        description: "Decodes URL-encoded text (%3A → :, + stays)",
        body: "printf '%b\\n' \"${text//%/\\\\x}\""
    },
    {
        name: "base64encode",
        params: ["text"],
        description: "Encodes text as Base64",
        body: "printf '%s' \"$text\" | base64 -w0\necho"
    },
    {
        name: "base64decode",
        params: ["text"],
        description: "Decodes Base64 text",
        body: "printf '%s' \"$text\" | base64 -d\necho"
    }
]).map(function (f) {
    f.builtin = true;
    return f;
});

function isBuiltinName(name) {
    return BUILTIN_FUNCTIONS.some(function (f) { return f.name === name; });
}

// vestavěné + vlastní funkce (vlastní se jménem vestavěné se ignorují)
function allFunctions(userFunctions) {
    return BUILTIN_FUNCTIONS.concat((userFunctions || []).filter(function (f) { return !isBuiltinName(f.name); }));
}

// skript + těla použitých funkcí (pro kontrolu chybějících proměnných a filtrů)
function withFunctionBodies(text, functions) {
    return [text].concat(usedFunctions(text, functions).map(function (f) { return f.body; })).join("\n");
}

// obsah spustitelného souboru funkce
function functionScript(fn, values) {
    var lines = ["#!/usr/bin/env bash", fn.name + "() {"];
    fn.params.forEach(function (p, i) {
        lines.push("    local " + p + '="${' + (i + 1) + '-}"');
    });
    lines.push(substitute(fn.body, values));
    lines.push("}");
    lines.push(fn.name + ' "$@"');
    return lines.join("\n");
}

// --- Spouštění ---
// Obsah tlačítka (příkaz nebo celý skript) se zapíše do dočasného souboru v $XDG_RUNTIME_DIR
// (tmpfs, přístupný jen uživateli) a spustí se: s shebangem (#!/usr/bin/env python3 …)
// jeho interpretem, jinak bashem. Soubor se po doběhnutí (i po vypršení limitu) smaže.
// $1 = skript, $2 = pracovní adresář (prázdný = domovská složka, ~ se rozbalí),
// dál dvojice název funkce + obsah jejího souboru (zpřístupní se v PATH).
var RUNNER = [
    'd=$(mktemp -d -p "${XDG_RUNTIME_DIR:-/tmp}" command-buttons-XXXXXX) || exit 1',
    'trap \'rm -rf "$d"\' EXIT',
    'trap \'exit 143\' TERM INT HUP',
    'f=$d/script',
    'printf \'%s\\n\' "$1" > "$f"',
    'dir=${2:-$HOME}',
    'shift 2',
    'mkdir "$d/bin"',
    'while (( $# >= 2 )); do',
    '    printf \'%s\\n\' "$2" > "$d/bin/$1"',
    '    chmod 700 "$d/bin/$1"',
    '    shift 2',
    'done',
    'export PATH="$d/bin:$PATH"',
    '[[ $dir == "~" || $dir == "~/"* ]] && dir=$HOME${dir:1}',
    'cd -- "$dir" || exit 1',
    'IFS= read -r first < "$f"',
    'if [[ $first == "#!"* ]]; then',
    '    read -ra interpreter <<< "${first:2}"',
    '    "${interpreter[@]}" "$f"',
    'else',
    '    bash "$f"',
    'fi'
].join("\n");

// Sestaví příkazový řádek pro spuštění. values = { nazev: hodnota } pro %nazev% i prostředí,
// functions = sdílené funkce (přibalí se jen ty, které skript používá).
function buildRunCommand(script, values, timeout, workdir, functions) {
    var env = Object.keys(values)
        .filter(function (name) { return VARIABLE_NAME.test(name); })
        .map(function (name) { return shellQuote(name + "=" + values[name]); });
    var cmd = (env.length > 0 ? "env " + env.join(" ") + " " : "")
        + "bash -c " + shellQuote(RUNNER) + " command-buttons "
        + shellQuote(substitute(script, values)) + " " + shellQuote(workdir || "")
        + usedFunctions(script, functions || []).map(function (f) {
            return " " + shellQuote(f.name) + " " + shellQuote(functionScript(f, values));
        }).join("");
    return timeout > 0 ? "timeout " + timeout + " " + cmd : cmd;
}
