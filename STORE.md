# KDE Store page

**Name:** Home Assistant Dashboard
**Category:** Plasma 6 Applets
**License:** MIT

## Summary

Your Home Assistant dashboards on the Plasma desktop, drawn natively and updated live.

## Description (English)

> **Transparency:** this widget was entirely vibe-coded: all of its code was written by an AI
> (Claude, through Claude Code) from my instructions. I tested it on my own Home Assistant
> instance, but I have not reviewed the code line by line. Bug reports are welcome.

Home Assistant Dashboard shows a Home Assistant dashboard on your desktop, with its cards
redrawn in native QML: it follows your Plasma theme, updates in real time over the WebSocket
API and lets you act on your devices with a click.

- Shows your own dashboards (masonry, sections and panel views, tabs, badges), or rebuilds
  Home Assistant's Home page: favorites, areas by floor with a sub-view per area, summaries.
- About 25 card types: entities, tile (with brightness, cover, temperature and mode controls),
  button, glance, heading, sensor, gauge, thermostat, light, markdown (templates rendered by HA),
  weather forecast, media control, pictures and cameras, history graphs, area, stacks and grids,
  conditional cards. Custom cards fall back to a tile or a list when possible.
- Exactly the same icons as the web UI (fetched from your instance).
- Detail popup with history and attributes for every entity.
- Interface in the language of your Home Assistant profile (English and French included).

Setup: right-click the widget → Configure, enter your Home Assistant address and a long-lived
access token (your HA profile → Security). Optionally paste the URL of a dashboard from your
browser, e.g. `https://ha.example.org/dashboard-music/0`, or `home` for the Home page.

Requires Plasma 6 and the Qt WebSockets QML module (`qt6-websockets` on Arch,
`qml6-module-qtwebsockets` on Debian/Ubuntu).

Not supported yet: map, logbook, calendar, iframe, to-do list and energy cards.
The token is stored in plain text in your Plasma configuration.

## Description (français)

> **Transparence :** ce widget a été entièrement « vibe-codé » : tout son code a été écrit par
> une IA (Claude, via Claude Code) à partir de mes instructions. Je l'ai testé sur ma propre
> instance Home Assistant, mais je n'ai pas relu le code ligne par ligne. Les signalements de
> bugs sont les bienvenus.

Home Assistant Dashboard affiche un tableau de bord Home Assistant sur le bureau, avec ses
cartes redessinées en QML natif : thème Plasma, mises à jour en temps réel, actions au clic.
Il reprend vos tableaux de bord ou reconstruit la page Accueil de HA (favoris, pièces par
étage, résumés). Interface dans la langue de votre profil Home Assistant.

Configuration : clic droit → Configurer, adresse de Home Assistant et jeton d'accès longue
durée (profil HA → Sécurité).
