#!/bin/sh
# Generates store screenshots (light and dark Breeze) into dist/screenshots/,
# using the fake Home Assistant with English sample data. Your own Plasma
# settings are not touched: themes come from temporary config folders.
set -e
cd "$(dirname "$0")"
out="$(pwd)/../dist/screenshots"
tmp=$(mktemp -d)
port=8799
mkdir -p "$out"

python3 mock_ha.py --port $port --lang en >/dev/null 2>&1 &
mock=$!
trap 'kill $mock 2>/dev/null; rm -rf "$tmp"' EXIT
sleep 1

for theme in Light Dark; do
    mkdir -p "$tmp/cfg-$theme" "$tmp/cache-$theme"
    cp /usr/share/color-schemes/Breeze$theme.colors "$tmp/cfg-$theme/kdeglobals"
    printf '\n[General]\nColorScheme=Breeze%s\n' $theme >> "$tmp/cfg-$theme/kdeglobals"
    printf '[Theme]\nname=default\n' > "$tmp/cfg-$theme/plasmarc"
    lower=$(echo $theme | tr 'A-Z' 'a-z')
    wall=/usr/share/wallpapers/Next/contents/images/5120x2880.png
    [ $theme = Dark ] && wall=/usr/share/wallpapers/Next/contents/images_dark/5120x2880.png

    shot() { # name, extra harness args...
        name=$1; shift
        XDG_CONFIG_HOME="$tmp/cfg-$theme" XDG_CACHE_HOME="$tmp/cache-$theme" \
            timeout 40 qml6 harness.qml -- --HA_URL=http://127.0.0.1:$port --WALLPAPER=$wall --FRAME=1 \
            --SHOT="$out/$name-$lower.png" --AUTOQUIT=1 --DELAY=7000 "$@" >/dev/null 2>&1 &
        pids="$pids $!"
    }
    pids=""
    shot 1-home-page        --DASHBOARD=home --WIDTH=1440 --HEIGHT=900
    shot 2-dashboard        --DASHBOARD=lovelace/maison --WIDTH=1440 --HEIGHT=560
    shot 3-cards            --DASHBOARD=lovelace/details --WIDTH=1440 --HEIGHT=840
    shot 4-room             --DASHBOARD=home/areas-salon --WIDTH=1100 --HEIGHT=510
    shot 5-details-popup    --DASHBOARD=lovelace/maison --MOREINFO=sensor.salon_temperature --WIDTH=1440 --HEIGHT=600
    wait $pids   # not a bare "wait": it would also wait for the fake server
done
ls -1 "$out"
