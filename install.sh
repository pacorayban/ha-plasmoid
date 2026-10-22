#!/bin/sh
# Installs (or updates) the widget for the current user.
set -e
cd "$(dirname "$0")"
if kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q '^org.pacorayban.hadashboard$'; then
    kpackagetool6 -t Plasma/Applet -u package
else
    kpackagetool6 -t Plasma/Applet -i package
fi
echo "Pour recharger un widget déjà sur le bureau : plasmashell --replace &  (ou se reconnecter)"
