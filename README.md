# Home Assistant Dashboard — Plasma 6 widget

*[Version française](README.fr.md)*

Shows a Home Assistant dashboard on the KDE Plasma desktop, with its cards redrawn in
native QML: it follows your Plasma theme, updates in real time and lets you act on your
devices with a click.

> **Transparency:** this widget was entirely vibe-coded: all of its code was written by an AI
> (Claude, through Claude Code) from the author's instructions. It was tested on a real
> Home Assistant instance, but the code has not been reviewed line by line.
> [Bug reports](https://github.com/pacorayban/ha-plasmoid/issues) are welcome.

## Requirements

- KDE Plasma 6
- The Qt WebSockets QML module: `qt6-websockets` (Arch), `qml6-module-qtwebsockets` (Debian/Ubuntu)
- A Home Assistant instance and a long-lived access token

## Installation

From the KDE Store: right-click the desktop → *Add Widgets…* → *Get New Widgets…* →
search for "Home Assistant Dashboard".

From a `.plasmoid` file:

```bash
kpackagetool6 -t Plasma/Applet -i hadashboard-<version>.plasmoid
```

From this repository:

```bash
./install.sh
```

Then right-click the desktop → *Add Widgets…* → "Home Assistant Dashboard".
Right-click the widget → *Configure*:

- **Address**: `http://homeassistant.local:8123` (or `https://…`)
- **Token**: your HA profile → *Security* tab → *Long-lived access tokens*
- **Dashboard**: the address copied from your browser (`https://…/dashboard-music/0`, the view
  is kept) or just its path (`dashboard-music`). `home` or `https://…/home/overview` = the HA
  *Home* page. Empty = the default dashboard, or the *Home* page if there is none (like the web UI).

The token is stored in plain text in `~/.config/plasma-org.kde.plasma.desktop-appletsrc`.

## What is shown

- The *Home* page (`/home`) is rebuilt as in HA: favorites (pinned entities plus HA's usage-based
  suggestions), areas by floor (compact cards that open the area's sub-view), devices without an
  area, and summaries (lights, climate, security, media, weather, maintenance) in a right-hand
  column, or after the favorites when the widget is narrow. The *Energy* summary is not supported.
- Other dashboards are read through the WebSocket API (`lovelace/config`). When HA generates them
  itself (the default "Overview", or a strategy dashboard), the widget rebuilds them: one card
  per area, then per device, then per domain.
- Views: masonry, sections (12-column grid) and panel; tabs when there are several views; badges.
- Supported cards: `entities`, `entity-filter`, `tile` (with brightness, cover, temperature and
  mode features), `button`, `glance`, `heading`, `sensor`, `entity`, `gauge`, `thermostat`,
  `light`, `markdown` (templates rendered by HA), `weather-forecast`, `media-control`,
  `picture`, `picture-entity`, `picture-glance`, `history-graph`, `statistics-graph` (drawn from
  history), `area`, `vertical-stack`, `horizontal-stack`, `grid`, `conditional` and `visibility`.
- Custom cards (`custom:*`, e.g. Mushroom): drawn as a tile if they have an `entity`, as a list if
  they have `entities`, otherwise as a "not supported" placeholder.
- Not supported: `map`, `logbook`, `calendar`, `iframe`, `todo-list`, energy cards.
- MDI icons are fetched from your HA instance (`/static/mdi/`), so they match the web UI exactly.
- Language and number format: those of your HA profile.

## Language

The widget follows the language of the Home Assistant profile (like the web UI), not the system
language: the states and names sent by HA are already in that language. Source strings are in
English, the French translation lives in `package/contents/code/Tr.js` (adding a language means
adding a dictionary there). The Plasma settings page follows the system language.

## Publishing on the KDE Store

```bash
./package.sh        # → dist/hadashboard-<version>.plasmoid
test/screenshots.sh # → dist/screenshots/*.png (light and dark, sample data)
```

On [store.kde.org](https://store.kde.org): *Add product* → category *Plasma 6 Applets*, then
upload the `.plasmoid` file. The store page text is in `STORE.md`.
Bump `Version` in `package/metadata.json` for every release.

## Development

```bash
python3 test/mock_ha.py                          # fake HA on :8765 (token "test")
python3 test/mock_ha.py --port 8766 --no-config  # no stored dashboard → Home page
python3 test/mock_ha.py --port 8767 --lang en    # English sample data
qml6 test/harness.qml                            # the widget in a window, outside Plasma
qml6 test/harness.qml -- --VIEW=1 --SHOT=/tmp/v1.png --AUTOQUIT=1
plasmawindowed org.pacorayban.hadashboard        # the installed widget, in a window
```

QML warnings show up in `journalctl --user -f`.

Layout:

- `package/contents/ui/HaClient.qml` — WebSocket connection, states, registries, translations, icons
- `package/contents/ui/DashboardView.qml` / `ViewContent.qml` — loading and laying out views
- `package/contents/ui/CardLoader.qml` — picks the component for each card type
- `package/contents/ui/cards/*.qml` — the cards
- `package/contents/code/Ha.js` — formatting, icons, colors, actions, conditions
- `package/contents/code/Strategy.js` — rebuilds HA's generated dashboards (Overview, Home)
- `package/contents/code/Tr.js` — UI strings and translations

## License

MIT, see [LICENSE](LICENSE).
