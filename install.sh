#!/usr/bin/env bash
# Nainstaluje / aktualizuje plasmoid Command Buttons pro aktuálního uživatele.
set -euo pipefail
cd "$(dirname "$0")"
if kpackagetool6 -t Plasma/Applet -l | grep -q '^cz.janakd.commandbuttons$'; then
    kpackagetool6 -t Plasma/Applet -u package
else
    kpackagetool6 -t Plasma/Applet -i package
fi
echo "Hotovo. Změny v už přidaném widgetu se projeví po: systemctl --user restart plasma-plasmashell"
