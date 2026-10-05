# Command Buttons

A KDE Plasma 6 panel widget with a grid of programmable buttons. Click the icon in your panel,
a popup slides up, and every button runs a shell command of your choice: a `curl` webhook,
a bash one‑liner, a script, or an app launcher.

> **Language:** the widget's user interface is currently in **Czech**. Translations are welcome (see [Contributing](#contributing)).

<!--
Screenshots: add images to a screenshots/ folder and reference them here, e.g.
![Popup with buttons](screenshots/popup.png)
![Button grid editor](screenshots/settings.png)
-->

## Features

- **Button grid in a panel popup.** Buttons are tiles with an icon and a label, grouped under
  optional headings. Each group has its own number of columns and a button can span several columns.
- **Commands or whole scripts.** A button can hold a one‑liner or a full script. Scripts run with bash,
  or with the interpreter from a shebang (`#!/usr/bin/env python3`, node, …). The editor has syntax
  highlighting, line numbers and auto‑indent, and a **Test** button shows the output right in the dialog.
- **Shared functions.** Define reusable functions with named parameters once, then call them from any
  button: `report=$(getWeather "$city")`. A searchable picker inserts the call together with
  the parameter names.
- **Variables.** Write `%name%` in a command and it is replaced with a value from the *Variables*
  settings page, which is handy for server addresses or API tokens. If a variable is not defined,
  the widget asks for its value when you click the button (and can remember it).
- **Tabs.** Split your buttons into tabs (e.g. *Server*, *Home*, *Network*) and switch between them.
  The popup has the height of the tallest tab, so it does not jump when switching.
- **Live feedback.** A spinner shows while a command is running, then a green check or a red cross
  appears on the tile for a moment.
- **Output window.** stdout and stderr appear in a floating window next to the popup. The window
  grows to fit the output, up to 60 % of the screen, so the button popup never changes size.
  It can hide itself after a delay or be cleared every time you open the widget.
- **Output per button.** Show the output always, only when the command fails, or never.
- **Close behaviour per button.** Keep the popup open, close it right after the click, or close it
  only if the command succeeds (exit code 0).
- **Pin.** A pin button keeps the popup open when you click elsewhere.
- **Keyboard control.** Use arrow keys to move between buttons, Enter to run, Esc to close, and
  Ctrl+←/→ to switch tabs (configurable).
- **Timeout.** Commands are stopped after a configurable time limit (30 s by default).
- **WYSIWYG settings.** The settings page shows the grid exactly as it will look. Click a tile to
  edit it, drag it to reorder or move it, or click **+** to add one.
- **Import / export.** Save all tabs and buttons to a JSON file, then load them on another machine.
  An import can replace your current buttons or be added as new tabs.

## Requirements

- KDE Plasma **6.0 or newer**
- `bash` and `timeout` (GNU coreutils), which come preinstalled on practically every distribution

## Installation

### From the KDE Store

Right‑click the panel → **Add or Manage Widgets…** → **Get New Widgets…** → **Download New Plasma Widgets**,
search for **Command Buttons** and click **Install**.

### From a `.plasmoid` file

Download the `.plasmoid` file from the [releases](../../releases), then install it with:

```bash
kpackagetool6 -t Plasma/Applet -i cz.janakd.commandbuttons-1.0.plasmoid
```

### From source

```bash
git clone <this repository>
cd <repository>
./install.sh        # installs, or upgrades an existing installation
```

The widget is installed into `~/.local/share/plasma/plasmoids/cz.janakd.commandbuttons`.
After an upgrade, restart Plasma so the new version is loaded:

```bash
systemctl --user restart plasma-plasmashell
```

Then add the widget to your panel: right‑click the panel → **Add or Manage Widgets…** → drag **Command Buttons** into the panel.

### Uninstall

```bash
kpackagetool6 -t Plasma/Applet -r cz.janakd.commandbuttons
```

## Guide

A step‑by‑step introduction. Every example can be copied straight into a button.

> The widget's interface is in Czech. Here is how the names used in this guide appear on screen:
>
> | In this guide | On screen |
> |---|---|
> | Settings pages *General*, *Variables*, *Buttons*, *Functions* | *Obecné*, *Proměnné*, *Tlačítka*, *Funkce* |
> | Add / Add group / Add tab | *Přidat* / *Přidat skupinu* / **+** next to the tabs |
> | Test | *Otestovat* |
> | Insert variable… / Insert function… | *Vložit proměnnou…* / *Vložit funkci…* |
> | After click, Output, Width, Working directory | *Po kliknutí*, *Výstup*, *Šířka*, *Pracovní adresář* |
> | Apply / OK | *Použít* / *OK* |

### 1. Your first button

1. Click the widget icon in the panel, then the **gear** icon in the popup. Settings open on the *Buttons* page.
2. Click the **+** tile in a group (or *Add group* first if the tab is empty).
3. Type a name, e.g. `Hello`, and this command:
   ```bash
   echo "Hello, $USER! Today is $(date '+%A, %d %B')."
   ```
4. Click **Test**. The output appears under the editor.
5. Click **Save**, then **Apply**.

Open the widget and click your new button. A spinner shows while it runs, then a green check mark,
and the output opens in a small window next to the widget.

More one‑liners to try:

| Name | Command |
|---|---|
| Weather | `curl -s 'https://wttr.in/?format=3'` |
| My public IP | `curl -s https://ifconfig.me` |
| Disk space | `df -h /` |
| Uptime | `uptime -p` |
| Biggest folders in Downloads | `du -sh ~/Downloads/* \| sort -rh \| head -5` |
| Open Downloads | `setsid -f dolphin ~/Downloads` |
| Open a website | `setsid -f xdg-open https://kde.org` |
| Coffee reminder | `notify-send "Coffee" "Time for a break"` |
| Lock the screen | `loginctl lock-session` |

> Use `setsid -f` in front of graphical apps. Without it the button keeps spinning until you close the app.

### 2. Decide what happens after a click

Every button has two simple settings in its editor:

- **After click:** keep the widget open, close it right away, or close it only when the command succeeds.
- **Output:** show it, show it only when something fails, or never show it.

Good combinations:

| Button | After click | Output |
|---|---|---|
| Lock the screen, open an app | close right away | don't show |
| Restart a service, run a deploy | close when it succeeds | only on error |
| Weather, disk space, IP address | keep open | show |

The green check mark or red cross on the tile always tells you whether the command worked.

### 3. Talk to web APIs with curl

```bash
# Read JSON and pick one value (needs jq)
curl -s https://api.github.com/repos/KDE/plasma-workspace | jq -r '.stargazers_count'
```

```bash
# Send a webhook with a JSON body
curl -s -X POST https://httpbin.org/post \
  -H 'Content-Type: application/json' \
  -d '{"event": "button-clicked", "source": "plasma"}'
```

```bash
# Check whether a site is up: prints the HTTP status code
curl -s -o /dev/null -w '%{http_code}\n' https://kde.org
```

Long commands can be split over several lines with `\` at the end of each line, exactly like in a terminal.

### 4. Use variables instead of repeating values

Put values you use in many buttons on the *Variables* page, e.g.:

| Name | Value |
|---|---|
| `city` | `Prague` |
| `webhook_url` | `https://httpbin.org/post` |
| `api_token` | `abc123` (click the lock icon to hide it) |

Then write `%name%` in any command:

```bash
curl -s "https://wttr.in/%city%?format=3"
```

```bash
curl -s -X POST "%webhook_url%" -H "Authorization: Bearer %api_token%" -d 'ping'
```

Change the value once and every button that uses it follows. **Insert variable…** above the editor lists
all your variables, so you don't have to remember their names.

**Filters** adjust a value on the way in:

```bash
curl -s "https://wttr.in/%city|urlencode%?format=3"               # "New York" → New%20York
curl -s -H "Authorization: Basic %login|base64%" https://example.com   # login = user:password
curl -s -H 'Content-Type: application/json' -d '{"text": %message|json%}' https://httpbin.org/post
                                                       # ↑ quotes in the message are escaped
```

(The last one works as long as the message has no apostrophe `'`. For any text, use the heredoc from section 10.)

**Ask when clicked:** if a command uses a variable that does not exist, the widget asks for it when you
click the button. That makes buttons with an input:

```bash
ping -c 3 %host%
```

Clicking it shows a field for `host`. Tick *Remember* and it becomes a normal variable.

Variables are also available as environment variables, so `$city` works too, including in Python.

### 5. Write whole scripts

A button can hold a complete script. Start with `set -euo pipefail` so the script stops at the first error,
and the tile then shows a red cross.

```bash
# Back up Documents into a dated archive
set -euo pipefail
mkdir -p ~/Backups
archive=~/Backups/documents-$(date +%F).tar.gz
tar -czf "$archive" -C ~/Documents .
echo "Saved $archive ($(du -h "$archive" | cut -f1))"
notify-send "Backup" "Documents saved"
```

```bash
# Check several websites at once
for site in kde.org github.com example.com; do
    code=$(curl -s -o /dev/null -w '%{http_code}' "https://$site")
    echo "$site → $code"
done
```

```bash
# Update a project; set "Working directory" to ~/projects/my-app
git pull --ff-only && git log --oneline -5
```

Other languages work too. The first line (the *shebang*) picks the interpreter:

```python
#!/usr/bin/env python3
import os, platform
print(f"Hello from Python {platform.python_version()} in {os.environ.get('city', 'somewhere')}")
```

The editor highlights the syntax, numbers the lines and keeps indentation; Tab / Shift+Tab indents a
selected block. Use **Test** while writing: it runs the script immediately without saving.

### 6. Share code with functions

When several buttons do almost the same thing, write it once on the *Functions* page.

**Example: weather for any city**

- Name: `getWeather`
- Parameters: `city`
- Description: `Short weather report for a city`
- Body:
  ```bash
  curl -s "https://wttr.in/$(urlencode "$city")?format=3"
  ```

Inside the body, each parameter is a normal bash variable (`$city`). The function *returns* whatever it prints.

Now use it in buttons:

```bash
getWeather "Prague"
```

```bash
getWeather "%city%"            # city from your variables
```

```bash
for c in Prague Vienna Berlin; do
    getWeather "$c"
done
```

```bash
report=$(getWeather "Oslo")     # store the result
notify-send "Weather" "$report"
```

Functions can call other functions:

```bash
# notify(title, message)
notify-send "$title" "$message"
```

```bash
# A button using both
notify "Weather" "$(getWeather "%city%")"
```

**Insert function…** in the editor inserts the call with its parameter names, e.g.
`$(getWeather "city")`, and selects the first parameter so you can type over it. A function's own
**Test** button has a field for each parameter.

A few functions are **built in** and always available: `urlencode`, `urldecode`, `base64encode`, `base64decode`.

### 7. Organise your buttons

- **Groups** have an optional heading and their own number of columns. A button can be wider than one column (*Width*).
- **Tabs** keep different sets apart, e.g. *Home*, *Work*, *System*. Add one with **+** next to the tabs.
- **Drag & drop** tiles to reorder them, into another group, or onto a tab name to move them to that tab.
- Leave the name empty to get an **icon‑only** button.
- **Tooltip:** write your own multi‑line hint, or turn it off.
- **Pin** (pin icon in the popup) keeps the widget open while you work in other windows.

### 8. Use the keyboard

Open the widget and press an arrow key to start selecting buttons. **Enter** runs the selected one,
**Esc** closes the widget, **Ctrl+←/→** switches tabs. A global shortcut that opens the widget can be set
in the settings under *Keyboard Shortcuts*.

### 9. Back up and share

On the *Buttons* page, **Export…** saves all tabs, buttons and functions to a JSON file.
**Import…** loads it again, either replacing everything or adding to what you have.
Variables are not exported, so tokens stay on your computer.

### 10. When something doesn't work

Click **Test** in the editor first. It shows the exact output and error message.

| You see | What to do |
|---|---|
| `…: command not found` | A typo (e.g. `fprint` instead of `printf`) or a tool that is not installed. Aliases from `~/.bashrc` are not available, so use the full command. |
| `$name` is sent literally, e.g. `{"id": "$id"}` | Bash does not expand variables inside `'single quotes'`. Use `"double quotes"`, or for JSON bodies use a heredoc (below). `%name%` variables work in both. |
| HTTP error `400` / `curl: (22)` | The request is wrong, often broken JSON. Check the body with **Test**, or build it with `%value\|json%`. |
| `SSL certificate problem` | The server uses a self‑signed certificate. Add `-k` to curl, only for servers you trust. |
| The button keeps spinning | A graphical app was started without `setsid -f`, or the command waits for input. |
| `Nedoběhlo do 30 s` / time limit | The command took too long. Raise the limit on the *General* page. |
| The command needs `sudo` | Use `pkexec` instead. It shows a graphical password prompt. |
| A function returns nothing | It must **print** its result (`echo`, `printf`), and calls must be on one line: `$(getWeather "Oslo")`. |
| Nothing visible happens | The button's *Output* may be set to *don't show*. The check mark or cross on the tile still shows the result. |

**JSON body with variables (heredoc):** curl reads the body from the lines between `<<EOF` and `EOF`,
and bash fills in the variables. The closing `EOF` must be alone at the very start of its line:

```bash
curl -s -X POST https://httpbin.org/post \
  -H 'Content-Type: application/json' \
  --data @- <<EOF
{
  "user": "$USER",
  "time": "$(date -Iseconds)",
  "city": "%city%"
}
EOF
```

## Reference

### Setting up buttons

Open the widget settings with the gear icon in the popup, or right‑click the panel icon → *Configure*.
The pages are *General*, *Variables*, *Buttons* (opened by default), *Functions*, then Plasma's own
*Keyboard Shortcuts* and *About*.

- **Tabs.** Use **+** next to the tab bar to add a tab. Under the tab bar you can rename the current tab;
  the ⋮ menu moves or deletes it. The widget only shows the tab bar when there are at least two tabs.
- **Groups.** Every group has an optional heading and a number of columns. Its ⋮ menu moves or deletes the group.
- **Drag & drop.** Drag a tile to reorder it. A line shows where it lands, before or after the tile under the cursor.
  Drop it on another group's tile, its **+** tile or anywhere in the group to move it there.
  Drop it on a tab name to move it to that tab (it lands at the end of the tab's last group).
  The page scrolls when you drag near its top or bottom edge. A click without dragging still opens the editor.
- **Buttons.** Click **+** inside a group to add a button, or click an existing tile to edit it.
  The edit dialog has these fields:

| Field | Meaning |
|---|---|
| Name and icon | Label and icon of the tile (click the icon to pick another one) |
| Command or script | A command or a whole script, see [Scripts](#scripts). **Test** runs it right away and shows the output under the editor |
| Working directory | Where the script starts (default: your home folder, `~` is expanded) |
| After click | Keep the widget open / Close it immediately / Close it when the command succeeds |
| Output | Show / Show only on error / Don't show. The check mark or cross on the tile appears either way |
| On mouse hover | Show a tooltip (can be turned off) with your own multi‑line text; if the text is empty, the command is shown |
| Width | How many grid columns the button spans |
| Group, Order | Where the button sits, and lets you move it into another group |

Changes are saved when you click **Apply** or **OK** in the settings window.

### General settings

| Setting | Default | Meaning |
|---|---|---|
| Title | *Příkazy* | Heading in the top‑left corner of the popup (shown when there is a single tab) and in the panel tooltip |
| Panel icon | `utilities-terminal` | Icon shown in the panel |
| Stop command after | 30 s | Kills commands that take too long (0 = never) |
| Show output in a floating window | on | Shows stdout/stderr of the last command |
| Hide automatically after | never | Hides the output window after N seconds |
| Start with a clean output when opened | off | Clears the previous output each time the widget opens |
| Previous / next tab | Ctrl+← / Ctrl+→ | Shortcuts for switching tabs in the open widget |

A global shortcut that *opens* the widget can be set in the **Keyboard Shortcuts** page,
which Plasma adds to every widget's settings.

### Keyboard

With the widget open:

| Key | Action |
|---|---|
| ↑ ↓ ← → | Select a button. Nothing is selected at first: ↑ starts at the bottom, ↓ at the top, ← at the end of the first row, → at its start. Movement wraps around rows and columns. |
| Enter / Space | Run the selected button |
| Esc | Close the widget (even when pinned) |
| Ctrl+← / Ctrl+→ | Previous / next tab (configurable) |

### Scripts

The command field is a small code editor. It has syntax highlighting chosen by the shebang,
line numbers and auto‑indent. Tab / Shift+Tab indents or unindents the line or the selected block.
A button expands the editor.

When a button runs, its content is written to a temporary file in `$XDG_RUNTIME_DIR`, which lives
in memory and is readable only by you. The file is executed and deleted afterwards, even after a timeout:

- with the interpreter from the first line if it starts with `#!` (e.g. `#!/usr/bin/env python3`),
- otherwise with `bash`.

```bash
set -euo pipefail
for host in web1 web2; do
    ssh "$host" 'systemctl is-active nginx'
done
```

```python
#!/usr/bin/env python3
import json, os, urllib.request
print(os.environ["city"])   # variables are also environment variables
```

### Functions

The **Functions** settings page holds code shared by all buttons, for example API calls you would
otherwise copy into many scripts. Every function has a name, named parameters, a description
and a bash body:

```bash
# getWeather(city)
curl -s "https://wttr.in/$(urlencode "$city")?format=3"
```

- Parameters are available in the body under their names (`$city`). The function returns
  whatever it prints. Use `return 1` to signal an error.
- Variables work inside functions too: `%name%`, filters and `$name`.
- When a button runs, every function it uses (directly or through another function) becomes a
  command on `PATH`. Call it from bash as `report=$(getWeather "$city")`, or from other
  languages through a subprocess.
- **Insert function…** in the button and function editors searches by name and description and inserts
  `$(name "param1" "param2")`. The first parameter is selected, so you can type over it.
- **Test** in the function editor calls the function with the values you enter for its parameters.
- **Duplicate** (copy icon) creates `name_kopie` right below the original and opens it with the name
  selected, so you can rename it straight away. Built‑in functions can be duplicated too, as a starting
  point for your own version.
- Functions are included in the import/export file. *Add* imports only functions whose name does not exist yet.

**Built‑in functions** are always available and need no setup. They are written in plain bash, so
they do not depend on Python or jq:

| Function | Result |
|---|---|
| `urlencode(text)` | URL‑encoded text, e.g. `$(urlencode "New York/2")` → `New%20York%2F2` (UTF‑8 aware) |
| `urldecode(text)` | the reverse |
| `base64encode(text)` / `base64decode(text)` | Base64 |

They are listed read‑only on the Functions page, where a click shows their code, and are marked
*built‑in* in **Insert function…**. A function of your own cannot use the same name.
Unlike the `%name|urlencode%` filter, they also work on values that exist only at runtime,
such as a parameter or a loop variable.

### Variables

On the **Variables** settings page you define `name = value` pairs. Write `%name%` anywhere in a
button's command and it is replaced with the value right before the command runs:

```bash
curl -s -H "Authorization: Bearer %token%" "https://%server%/api/deploy"
```

- Names consist of letters, digits and `_`. They start with a letter, are at least 2 characters long
  and do not end with `_`. Because of that, `date` formats such as `+%Y%m%d` or `+%d_%H` are left alone.
- Variables are also exported as **environment variables**, so scripts can use `$name`
  (or `os.environ["name"]` in Python).
- **Filters** transform a value: `%name|urlencode%`. Filters can be chained (`%name|upper|base64%`)
  and their names are case‑insensitive:

  | Filter | Result |
  |---|---|
  | `urlencode` | URL‑encoded, e.g. `New York/2` → `New%20York%2F2` |
  | `base64` | Base64 of the UTF‑8 value |
  | `json` | JSON string including quotes, e.g. for a request body |
  | `shell` | single‑quoted for bash, so spaces and quotes are safe |
  | `lower`, `upper` | lower / upper case |

  An unknown filter is reported as an error instead of being silently ignored.
- In the button editor, **Insert variable…** above the command opens a searchable list of your variables.
  Enter or a click inserts `%name%` at the cursor. Typing a name that does not exist yet offers to insert it as a new variable.
- A value can be marked as **secret** (lock icon). The settings page then hides it behind dots.
  Note that it is still stored in plain text in the Plasma configuration file.
- If a command uses a variable that is not defined, clicking the button opens a small form inside
  the widget asking for the missing values. Tick **Remember** to save them as variables.
  Enter moves to the next field and runs the command from the last one; Esc cancels.
- Values are inserted as they are, without quoting. Put the placeholder in quotes in your command
  (`"%path%"`) if the value can contain spaces or other special characters.
- Variables are not included in the import/export file, so tokens do not end up in shared configs.

## Command tips

```bash
# Webhook / REST call
curl -s -X POST https://example.com/hook -H 'Content-Type: application/json' -d '{"action":"deploy"}'

# Launch a GUI application (setsid -f returns right away, so the button does not stay "running")
setsid -f konsole

# Desktop notification
notify-send "Backup" "Finished"

# Command that needs root: use pkexec, which shows a graphical password prompt (sudo cannot ask here)
pkexec systemctl restart nginx

# Multi-line script
cd ~/project && git pull && ./deploy.sh
```

- Commands run as your user in a non‑interactive shell, so aliases from `~/.bashrc` are not available.
- Variable values are passed on the command line of the runner process, so other users on the same
  machine could see them in `ps` while the command runs. On a single‑user desktop this does not matter.
- When the time limit is reached, the command is killed (exit code 124) and the output window says so.
- The output is trimmed of leading and trailing whitespace; stderr is shown after stdout.

## Import / export format

**Export…** writes a JSON file like this (and **Import…** reads it back):

```json
{
  "app": "cz.janakd.commandbuttons",
  "version": 1,
  "tabs": [
    {
      "name": "Server",
      "groups": [
        {
          "label": "Docker",
          "columns": 2,
          "buttons": [
            {
              "name": "Restart app",
              "command": "ssh myserver 'docker restart app'",
              "icon": "view-refresh",
              "span": 1,
              "closeMode": "success",
              "output": "error",
              "tooltip": "Restarts the app container\non my server",
              "tooltipEnabled": true
            }
          ]
        }
      ]
    }
  ]
}
```

`closeMode` is one of `none`, `immediate` or `success`; `output` is one of `show`, `error` or `hide`. Import also accepts a bare array of tabs,
or a bare array of groups (which becomes a single tab).

> **Security:** an imported file can contain *any* command and the commands run with your
> privileges. Only import files you trust, and look through the commands before you click the buttons.

## Development

```
package/
├── metadata.json              # widget metadata (id, name, version)
└── contents/
    ├── config/
    │   ├── main.xml           # configuration schema
    │   └── config.qml         # settings pages
    └── ui/
        ├── main.qml           # widget: popup, running commands, keyboard control
        ├── GroupsView.qml     # groups with a grid of tiles
        ├── CommandTile.qml    # a single button tile
        ├── OutputPanel.qml    # command output
        ├── configButtons.qml  # settings: tabs, groups, buttons, import/export
        ├── ButtonEditDialog.qml
        ├── configVariables.qml # settings: variables
        ├── configFunctions.qml # settings: shared functions
        ├── FunctionEditDialog.qml
        ├── FunctionPicker.qml # insert a function call into a script
        ├── VariablePicker.qml # insert a variable into a script
        ├── CommandEditor.qml  # code editor (highlighting, line numbers, indentation)
        ├── ScriptTester.qml   # the Test button
        ├── TestResultView.qml
        ├── VariableForm.qml   # prompt for missing variables
        ├── configGeneral.qml  # settings: general, output, keyboard
        ├── data.js            # loading, normalizing and import/export of the configuration
        └── nav.js             # arrow-key navigation
```

Useful commands:

```bash
./install.sh                                       # install / upgrade locally
plasmawindowed cz.janakd.commandbuttons            # run the widget in a standalone window
journalctl --user -u plasma-plasmashell -f         # watch QML errors from the panel
./build.sh                                         # build a .plasmoid for release / the KDE Store
```

### Publishing to the KDE Store

1. Bump `Version` in `package/metadata.json`.
2. Run `./build.sh` to create `cz.janakd.commandbuttons-<version>.plasmoid`.
3. Upload it at [store.kde.org](https://store.kde.org) under *Plasma 6 Extensions → Plasma Widgets*
   and attach it to a GitHub release.

## Contributing

Issues and pull requests are welcome, especially translations of the user interface
(the strings are currently hard‑coded in Czech; moving them to `i18n()` would be the first step).

## License

[GPL-2.0-or-later](LICENSE) © Dominik Janák
