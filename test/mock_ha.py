#!/usr/bin/env python3
"""Tiny fake Home Assistant server for testing the plasmoid without a real instance.

Speaks the HA WebSocket API (auth, states, registries, lovelace, history,
weather forecast, templates, services) and serves MDI icon chunks, fetched
once from demo.home-assistant.io and cached next to this script.

Usage: python3 mock_ha.py [--port 8765] [--no-config]
  --no-config  answer lovelace/config with config_not_found (auto-generated overview)
Token: "test"
"""
import argparse
import base64
import copy
import hashlib
import json
import math
import os
import random
import socket
import socketserver
import struct
import threading
import time
import urllib.request
from datetime import datetime, timedelta, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
ICON_CACHE = os.path.join(HERE, ".mdi-cache")
GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


def now_iso(offset_s=0):
    return (datetime.now(timezone.utc) - timedelta(seconds=offset_s)).isoformat()


def st(entity_id, state, attrs=None, ago=600):
    return {
        "entity_id": entity_id,
        "state": state,
        "attributes": attrs or {},
        "last_changed": now_iso(ago),
        "last_updated": now_iso(ago),
        "context": {"id": "x", "parent_id": None, "user_id": None},
    }


STATES = {s["entity_id"]: s for s in [
    st("light.salon_plafonnier", "on", {"friendly_name": "Plafonnier", "brightness": 180, "rgb_color": [255, 176, 92],
                                        "supported_color_modes": ["hs", "color_temp"], "color_mode": "hs"}),
    st("light.salon_lampe", "off", {"friendly_name": "Lampe d'appoint", "supported_color_modes": ["brightness"]}),
    st("light.chambre", "off", {"friendly_name": "Chambre", "supported_color_modes": ["onoff"]}),
    st("switch.cuisine_cafetiere", "on", {"friendly_name": "Cafetière"}),
    st("fan.chambre", "off", {"friendly_name": "Ventilateur"}),
    st("sensor.salon_temperature", "21.4", {"friendly_name": "Température salon", "device_class": "temperature",
                                            "unit_of_measurement": "°C", "state_class": "measurement"}),
    st("sensor.salon_humidite", "48", {"friendly_name": "Humidité salon", "device_class": "humidity",
                                       "unit_of_measurement": "%", "state_class": "measurement"}),
    st("sensor.bureau_co2", "812", {"friendly_name": "CO₂ bureau", "device_class": "carbon_dioxide",
                                    "unit_of_measurement": "ppm", "state_class": "measurement"}),
    st("sensor.batterie_porte", "15", {"friendly_name": "Batterie capteur porte", "device_class": "battery",
                                       "unit_of_measurement": "%", "state_class": "measurement"}),
    st("sensor.compteur_energie", "1234.567", {"friendly_name": "Énergie totale", "device_class": "energy",
                                               "unit_of_measurement": "kWh", "state_class": "total_increasing"}),
    st("sensor.dernier_reveil", now_iso(3700), {"friendly_name": "Dernier réveil", "device_class": "timestamp"}),
    st("binary_sensor.porte_entree", "off", {"friendly_name": "Porte d'entrée", "device_class": "door"}),
    st("binary_sensor.mouvement_couloir", "on", {"friendly_name": "Mouvement couloir", "device_class": "motion"}),
    st("climate.salon", "heat", {"friendly_name": "Chauffage salon", "temperature": 20.5, "current_temperature": 19.8,
                                 "hvac_modes": ["off", "heat", "auto"], "hvac_action": "heating", "min_temp": 7,
                                 "max_temp": 30, "target_temp_step": 0.5, "supported_features": 385}),
    st("cover.chambre_volet", "open", {"friendly_name": "Volet chambre", "current_position": 70,
                                       "device_class": "shutter", "supported_features": 15}),
    st("lock.porte", "locked", {"friendly_name": "Serrure entrée"}),
    st("media_player.salon_sonos", "playing", {"friendly_name": "Sonos salon", "media_title": "So What",
                                               "media_artist": "Miles Davis", "media_duration": 562,
                                               "media_position": 120, "supported_features": 21437,
                                               "volume_level": 0.3}),
    st("weather.maison", "partlycloudy", {"friendly_name": "Maison", "temperature": 17.2, "humidity": 62,
                                          "wind_speed": 12.4, "wind_speed_unit": "km/h", "temperature_unit": "°C",
                                          "supported_features": 3}),
    st("person.alex", "home", {"friendly_name": "Alex"}),
    st("person.sam", "not_home", {"friendly_name": "Sam"}),
    st("input_number.consigne_ballon", "55", {"friendly_name": "Consigne ballon", "min": 40, "max": 70, "step": 1,
                                             "mode": "slider", "unit_of_measurement": "°C"}),
    st("input_select.mode_maison", "Normal", {"friendly_name": "Mode maison", "options": ["Normal", "Absent", "Nuit"]}),
    st("input_boolean.invites", "off", {"friendly_name": "Mode invités"}),
    st("scene.soiree", now_iso(86400), {"friendly_name": "Soirée"}),
    st("script.arrosage", "off", {"friendly_name": "Arrosage jardin"}),
    st("automation.reveil", "on", {"friendly_name": "Réveil"}),
    st("sun.sun", "above_horizon", {"friendly_name": "Soleil"}),
    st("camera.entree", "idle", {"friendly_name": "Caméra entrée", "entity_picture": "/api/camera_proxy/camera.entree?token=abc"}),
    st("update.home_assistant", "off", {"friendly_name": "Mise à jour HA"}),
]}

AREAS = [
    {"area_id": "salon", "name": "Salon", "icon": "mdi:sofa", "floor_id": None,
     "temperature_entity_id": "sensor.salon_temperature", "humidity_entity_id": "sensor.salon_humidite"},
    {"area_id": "cuisine", "name": "Cuisine", "icon": "mdi:stove", "floor_id": None},
    {"area_id": "chambre", "name": "Chambre", "icon": "mdi:bed", "floor_id": None},
    {"area_id": "bureau", "name": "Bureau", "icon": "mdi:desk", "floor_id": None},
    {"area_id": "entree", "name": "Entrée", "icon": "mdi:door", "floor_id": None},
]

DEVICES = [
    {"id": "dev_hue_salon", "name": "Hue salon", "name_by_user": None, "area_id": "salon"},
    {"id": "dev_netatmo", "name": "Netatmo", "name_by_user": "Station Netatmo", "area_id": None},
    {"id": "dev_sonos", "name": "Sonos", "name_by_user": None, "area_id": "salon"},
]


def reg(entity_id, **kw):
    e = {"entity_id": entity_id, "area_id": None, "device_id": None, "platform": "demo", "translation_key": None,
         "entity_category": None, "hidden_by": None, "icon": None, "original_icon": None, "name": None,
         "options": {}}
    e.update(kw)
    return e


ENTITY_REGISTRY = [
    reg("light.salon_plafonnier", device_id="dev_hue_salon"),
    reg("light.salon_lampe", area_id="salon"),
    reg("light.chambre", area_id="chambre"),
    reg("switch.cuisine_cafetiere", area_id="cuisine", icon="mdi:coffee-maker"),
    reg("fan.chambre", area_id="chambre"),
    reg("sensor.salon_temperature", area_id="salon", options={"sensor": {"suggested_display_precision": 1}}),
    reg("sensor.salon_humidite", area_id="salon", options={"sensor": {"suggested_display_precision": 0}}),
    reg("sensor.bureau_co2", device_id="dev_netatmo"),
    reg("sensor.batterie_porte", area_id="entree"),
    reg("sensor.compteur_energie", options={"sensor": {"display_precision": 1}}),
    reg("binary_sensor.porte_entree", area_id="entree"),
    reg("binary_sensor.mouvement_couloir", area_id="entree"),
    reg("climate.salon", area_id="salon"),
    reg("cover.chambre_volet", area_id="chambre"),
    reg("lock.porte", area_id="entree"),
    reg("media_player.salon_sonos", device_id="dev_sonos"),
    reg("weather.maison", device_id="dev_netatmo"),
    reg("camera.entree", area_id="entree"),
    reg("update.home_assistant", entity_category="config"),
]

ICONS = {
    "light": {"_": {"default": "mdi:lightbulb", "state": {"off": "mdi:lightbulb-off"}}},
    "switch": {"_": {"default": "mdi:toggle-switch-variant", "state": {"off": "mdi:toggle-switch-variant-off"}}},
    "fan": {"_": {"default": "mdi:fan", "state": {"off": "mdi:fan-off"}}},
    "sensor": {"temperature": {"default": "mdi:thermometer"}, "humidity": {"default": "mdi:water-percent"},
               "carbon_dioxide": {"default": "mdi:molecule-co2"}, "energy": {"default": "mdi:lightning-bolt"},
               "timestamp": {"default": "mdi:clock"},
               "battery": {"default": "mdi:battery", "range": {"0": "mdi:battery-outline", "10": "mdi:battery-10",
                                                               "20": "mdi:battery-20", "50": "mdi:battery-50",
                                                               "90": "mdi:battery-90", "100": "mdi:battery"}}},
    "binary_sensor": {"_": {"default": "mdi:radiobox-blank", "state": {"on": "mdi:checkbox-marked-circle"}},
                      "door": {"default": "mdi:door-closed", "state": {"on": "mdi:door-open"}},
                      "motion": {"default": "mdi:motion-sensor-off", "state": {"on": "mdi:motion-sensor"}}},
    "climate": {"_": {"default": "mdi:thermostat"}},
    "cover": {"shutter": {"default": "mdi:window-shutter", "state": {"open": "mdi:window-shutter-open"}}},
    "lock": {"_": {"default": "mdi:lock", "state": {"unlocked": "mdi:lock-open-variant"}}},
    "media_player": {"_": {"default": "mdi:cast", "state": {"off": "mdi:cast-off", "playing": "mdi:cast-connected"}}},
    "weather": {"_": {"default": "mdi:weather-partly-cloudy",
                      "state": {"sunny": "mdi:weather-sunny", "partlycloudy": "mdi:weather-partly-cloudy",
                                "rainy": "mdi:weather-rainy", "cloudy": "mdi:weather-cloudy"}}},
    "person": {"_": {"default": "mdi:account", "state": {"not_home": "mdi:account-arrow-right"}}},
    "input_number": {"_": {"default": "mdi:ray-vertex"}},
    "input_select": {"_": {"default": "mdi:format-list-bulleted"}},
    "input_boolean": {"_": {"default": "mdi:check-circle-outline", "state": {"off": "mdi:close-circle-outline"}}},
    "scene": {"_": {"default": "mdi:palette"}},
    "script": {"_": {"default": "mdi:script-text", "state": {"on": "mdi:script-text-play"}}},
    "camera": {"_": {"default": "mdi:video"}},
}

TR = {
    "component.light.entity_component._.state.on": "Allumée",
    "component.light.entity_component._.state.off": "Éteinte",
    "component.switch.entity_component._.state.on": "Activé",
    "component.switch.entity_component._.state.off": "Désactivé",
    "component.fan.entity_component._.state.off": "Éteint",
    "component.fan.entity_component._.state.on": "Allumé",
    "component.input_boolean.entity_component._.state.off": "Désactivé",
    "component.input_boolean.entity_component._.state.on": "Activé",
    "component.binary_sensor.entity_component.door.state.off": "Fermée",
    "component.binary_sensor.entity_component.door.state.on": "Ouverte",
    "component.binary_sensor.entity_component.motion.state.off": "RAS",
    "component.binary_sensor.entity_component.motion.state.on": "Détecté",
    "component.climate.entity_component._.state.heat": "Chauffe",
    "component.climate.entity_component._.state.off": "Arrêt",
    "component.climate.entity_component._.state.auto": "Automatique",
    "component.climate.entity_component._.state_attributes.hvac_action.state.heating": "Chauffe en cours",
    "component.climate.entity_component._.state_attributes.hvac_action.state.idle": "Inactif",
    "component.climate.entity_component._.state_attributes.hvac_action.name": "Action",
    "component.cover.entity_component._.state.open": "Ouvert",
    "component.cover.entity_component._.state.closed": "Fermé",
    "component.lock.entity_component._.state.locked": "Verrouillé",
    "component.lock.entity_component._.state.unlocked": "Déverrouillé",
    "component.media_player.entity_component._.state.playing": "Lecture",
    "component.media_player.entity_component._.state.paused": "En pause",
    "component.media_player.entity_component._.state.off": "Éteint",
    "component.person.entity_component._.state.home": "À la maison",
    "component.person.entity_component._.state.not_home": "Absent",
    "component.weather.entity_component._.state.partlycloudy": "Partiellement nuageux",
    "component.weather.entity_component._.state.sunny": "Ensoleillé",
    "component.script.entity_component._.state.off": "Arrêté",
    "component.camera.entity_component._.state.idle": "Inactive",
    "component.light.title": "Lumière",
    "component.sensor.title": "Capteur",
    "component.person.title": "Personne",
    "component.scene.title": "Scène",
    "component.update.title": "Mise à jour",
}

LOVELACE = {
    "title": "Ma maison",
    "views": [
        {
            "title": "Maison", "path": "maison", "type": "sections", "max_columns": 3,
            "badges": [{"type": "entity", "entity": "person.alex"}, {"type": "entity", "entity": "person.sam"},
                       {"type": "entity", "entity": "sensor.salon_temperature"}],
            "sections": [
                {"type": "grid", "cards": [
                    {"type": "heading", "heading": "Salon", "icon": "mdi:sofa",
                     "badges": [{"entity": "sensor.salon_humidite"}]},
                    {"type": "tile", "entity": "light.salon_plafonnier", "features": [{"type": "light-brightness"}]},
                    {"type": "tile", "entity": "light.salon_lampe"},
                    {"type": "tile", "entity": "climate.salon", "features": [{"type": "target-temperature"}]},
                    {"type": "tile", "entity": "media_player.salon_sonos"},
                    {"type": "button", "entity": "switch.cuisine_cafetiere", "show_state": True},
                    {"type": "button", "entity": "scene.soiree"},
                    {"type": "button", "entity": "light.chambre"},
                    {"type": "button", "entity": "fan.chambre"},
                ]},
                {"type": "grid", "cards": [
                    {"type": "heading", "heading": "Sécurité", "icon": "mdi:shield-home"},
                    {"type": "tile", "entity": "lock.porte"},
                    {"type": "tile", "entity": "binary_sensor.porte_entree"},
                    {"type": "tile", "entity": "binary_sensor.mouvement_couloir"},
                    {"type": "tile", "entity": "sensor.batterie_porte"},
                    {"type": "tile", "entity": "cover.chambre_volet", "grid_options": {"columns": 12},
                     "features": [{"type": "cover-open-close"}]},
                ]},
                {"type": "grid", "cards": [
                    {"type": "heading", "heading": "Météo"},
                    {"type": "weather-forecast", "entity": "weather.maison", "forecast_type": "daily"},
                    {"type": "area", "area": "salon"},
                    {"type": "area", "area": "chambre"},
                ]},
            ],
        },
        {
            "title": "Détails", "path": "details",
            "cards": [
                {"type": "entities", "title": "Salon", "entities": [
                    "light.salon_plafonnier",
                    {"entity": "light.salon_lampe", "secondary_info": "last-changed"},
                    {"type": "section", "label": "Réglages"},
                    "input_number.consigne_ballon", "input_select.mode_maison", "input_boolean.invites",
                    {"type": "divider"},
                    "cover.chambre_volet", "lock.porte", "script.arrosage", "scene.soiree",
                    {"type": "attribute", "entity": "climate.salon", "attribute": "current_temperature", "suffix": " °C",
                     "name": "Température mesurée"},
                    {"type": "weblink", "name": "Documentation", "url": "https://www.home-assistant.io"},
                ]},
                {"type": "glance", "title": "Résumé", "entities": ["person.alex", "person.sam",
                                                                  "binary_sensor.porte_entree",
                                                                  "sensor.salon_temperature", "lock.porte"]},
                {"type": "sensor", "entity": "sensor.salon_temperature", "graph": "line"},
                {"type": "gauge", "entity": "sensor.bureau_co2", "min": 400, "max": 2000,
                 "severity": {"green": 400, "yellow": 1000, "red": 1500}},
                {"type": "thermostat", "entity": "climate.salon"},
                {"type": "light", "entity": "light.salon_plafonnier"},
                {"type": "markdown", "title": "Note",
                 "content": "Il fait **{{ states('sensor.salon_temperature') }} °C** au salon.\n\n- liste\n- *italique*"},
                {"type": "media-control", "entity": "media_player.salon_sonos"},
                {"type": "history-graph", "title": "Historique",
                 "entities": ["sensor.salon_temperature", "binary_sensor.porte_entree"]},
                {"type": "horizontal-stack", "cards": [
                    {"type": "button", "entity": "light.chambre"},
                    {"type": "button", "entity": "switch.cuisine_cafetiere"},
                ]},
                {"type": "conditional", "conditions": [{"condition": "state", "entity": "lock.porte", "state": "unlocked"}],
                 "card": {"type": "markdown", "content": "⚠️ **La porte est déverrouillée !**"}},
                {"type": "custom:mushroom-light-card", "entity": "light.chambre"},
                {"type": "map", "entities": ["person.alex"]},
                {"type": "picture-entity", "entity": "camera.entree"},
                {"type": "entity", "entity": "sensor.compteur_energie"},
                {"type": "sensor", "entity": "sensor.dernier_reveil"},
            ],
        },
    ],
}

TOGGLE_ON = {"light", "switch", "fan", "input_boolean", "automation", "script"}


class Hub:
    """Shared state + connected clients (for broadcasting state_changed)."""

    def __init__(self):
        self.lock = threading.Lock()
        self.clients = []

    def set_state(self, entity_id, state=None, **attrs):
        with self.lock:
            old = STATES[entity_id]
            new = copy.deepcopy(old)
            if state is not None:
                new["state"] = state
                if state != old["state"]:
                    new["last_changed"] = now_iso()
            new["attributes"].update(attrs)
            new["last_updated"] = now_iso()
            STATES[entity_id] = new
            clients = list(self.clients)
        for c in clients:
            c.emit_state_changed(entity_id, old, new)


HUB = Hub()


def call_service(domain, service, data, target):
    ids = target.get("entity_id") if target else data.get("entity_id")
    if isinstance(ids, str):
        ids = [ids]
    for eid in ids or []:
        d = eid.split(".")[0]
        s = STATES.get(eid)
        if not s:
            continue
        cur = s["state"]
        if service == "toggle":
            if d == "cover":
                HUB.set_state(eid, "closed" if cur == "open" else "open")
            else:
                HUB.set_state(eid, "off" if cur == "on" else "on")
        elif service == "turn_on":
            extra = {}
            if "brightness_pct" in data:
                extra["brightness"] = round(data["brightness_pct"] * 2.55)
            elif d == "light" and "brightness" not in s["attributes"]:
                extra["brightness"] = 200
            HUB.set_state(eid, "on" if d != "scene" else now_iso(), **extra)
        elif service == "turn_off":
            HUB.set_state(eid, "off")
        elif service == "open_cover":
            HUB.set_state(eid, "open", current_position=100)
        elif service == "close_cover":
            HUB.set_state(eid, "closed", current_position=0)
        elif service == "lock":
            HUB.set_state(eid, "locked")
        elif service == "unlock":
            HUB.set_state(eid, "unlocked")
        elif service == "set_temperature":
            HUB.set_state(eid, None, **{k: v for k, v in data.items() if k != "entity_id"})
        elif service == "set_hvac_mode":
            HUB.set_state(eid, data["hvac_mode"], hvac_action="heating" if data["hvac_mode"] == "heat" else "idle")
        elif service == "set_value":
            HUB.set_state(eid, str(data["value"]))
        elif service == "select_option":
            HUB.set_state(eid, data["option"])
        elif service == "media_play_pause":
            HUB.set_state(eid, "paused" if cur == "playing" else "playing")
        elif service == "press":
            HUB.set_state(eid, now_iso())


def history_for(entity_id, start, end):
    s = STATES.get(entity_id)
    if not s:
        return []
    out = []
    t0, t1 = start.timestamp(), end.timestamp()
    try:
        base = float(s["state"])
        n = 96
        for i in range(n):
            t = t0 + (t1 - t0) * i / n
            out.append({"s": f"{base + 1.5 * math.sin(i / 10) + random.uniform(-0.2, 0.2):.2f}", "lu": t})
        out.append({"s": s["state"], "lu": t1 - 60})
    except ValueError:
        t = t0
        on = "off"
        while t < t1:
            out.append({"s": on, "lu": t})
            t += random.uniform(1800, 7200)
            on = "on" if on == "off" else "off"
    return out


class Conn:
    def __init__(self, sock, no_config):
        self.sock = sock
        self.no_config = no_config
        self.send_lock = threading.Lock()
        self.state_subs = []

    # ---- framing
    def send(self, obj):
        data = json.dumps(obj).encode()
        header = bytearray([0x81])
        n = len(data)
        if n < 126:
            header.append(n)
        elif n < 65536:
            header.append(126)
            header += struct.pack(">H", n)
        else:
            header.append(127)
            header += struct.pack(">Q", n)
        with self.send_lock:
            self.sock.sendall(bytes(header) + data)

    def recv_exact(self, n):
        buf = b""
        while len(buf) < n:
            chunk = self.sock.recv(n - len(buf))
            if not chunk:
                raise ConnectionError()
            buf += chunk
        return buf

    def recv(self):
        while True:
            b1, b2 = self.recv_exact(2)
            op = b1 & 0x0F
            n = b2 & 0x7F
            if n == 126:
                n = struct.unpack(">H", self.recv_exact(2))[0]
            elif n == 127:
                n = struct.unpack(">Q", self.recv_exact(8))[0]
            mask = self.recv_exact(4) if b2 & 0x80 else b"\0\0\0\0"
            payload = bytes(c ^ mask[i % 4] for i, c in enumerate(self.recv_exact(n)))
            if op == 8:
                raise ConnectionError()
            if op == 9:
                with self.send_lock:
                    self.sock.sendall(bytes([0x8A, len(payload)]) + payload)
                continue
            if op == 1:
                return json.loads(payload.decode())

    def emit_state_changed(self, entity_id, old, new):
        for sid in list(self.state_subs):
            try:
                self.send({"id": sid, "type": "event", "event": {
                    "event_type": "state_changed", "data": {"entity_id": entity_id, "old_state": old, "new_state": new},
                    "origin": "LOCAL", "time_fired": now_iso()}})
            except OSError:
                pass

    def result(self, mid, result=None):
        self.send({"id": mid, "type": "result", "success": True, "result": result})

    def error(self, mid, code, message):
        self.send({"id": mid, "type": "result", "success": False, "error": {"code": code, "message": message}})

    # ---- protocol
    def run(self):
        self.send({"type": "auth_required", "ha_version": "2026.10.0"})
        auth = self.recv()
        if auth.get("access_token") != "test":
            self.send({"type": "auth_invalid", "message": "Invalid access token or password"})
            return
        self.send({"type": "auth_ok", "ha_version": "2026.10.0"})
        with HUB.lock:
            HUB.clients.append(self)
        try:
            while True:
                self.handle(self.recv())
        finally:
            with HUB.lock:
                HUB.clients.remove(self)

    def handle(self, m):
        mid, t = m.get("id"), m.get("type")
        if t == "ping":
            self.send({"id": mid, "type": "pong"})
        elif t == "get_config":
            self.result(mid, {"location_name": "Maison", "version": "2026.10.0",
                              "unit_system": {"temperature": "°C", "length": "km"}, "components": []})
        elif t == "get_states":
            self.result(mid, list(STATES.values()))
        elif t == "config/entity_registry/list":
            self.result(mid, ENTITY_REGISTRY)
        elif t == "config/device_registry/list":
            self.result(mid, DEVICES)
        elif t == "config/area_registry/list":
            self.result(mid, AREAS)
        elif t == "frontend/get_icons":
            self.result(mid, {"resources": ICONS if m.get("category") == "entity_component" else {}})
        elif t == "frontend/get_translations":
            self.result(mid, {"resources": TR})
        elif t == "frontend/get_user_data":
            self.result(mid, {"value": {"language": "fr", "number_format": "language"} if m.get("key") == "language" else None})
        elif t == "lovelace/config":
            if self.no_config:
                self.error(mid, "config_not_found", "No config found.")
            else:
                self.result(mid, LOVELACE)
        elif t == "subscribe_events":
            self.result(mid)
            if m.get("event_type") == "state_changed":
                self.state_subs.append(mid)
        elif t == "unsubscribe_events":
            if m.get("subscription") in self.state_subs:
                self.state_subs.remove(m["subscription"])
            self.result(mid)
        elif t == "call_service":
            self.result(mid, {"context": {"id": "x"}})
            call_service(m["domain"], m["service"], m.get("service_data") or {}, m.get("target"))
        elif t == "history/history_during_period":
            start = datetime.fromisoformat(m["start_time"].replace("Z", "+00:00"))
            end = datetime.fromisoformat(m.get("end_time", now_iso()).replace("Z", "+00:00"))
            self.result(mid, {e: history_for(e, start, end) for e in m.get("entity_ids", [])})
        elif t == "weather/subscribe_forecast":
            self.result(mid)
            today = datetime.now(timezone.utc).replace(hour=12, minute=0, second=0, microsecond=0)
            conds = ["sunny", "partlycloudy", "rainy", "cloudy", "sunny", "pouring", "partlycloudy"]
            self.send({"id": mid, "type": "event", "event": {"type": "daily", "forecast": [
                {"datetime": (today + timedelta(days=i)).isoformat(), "condition": conds[i],
                 "temperature": 18 + i, "templow": 9 + i % 3} for i in range(7)]}})
        elif t == "render_template":
            self.result(mid)
            text = m["template"].replace("{{ states('sensor.salon_temperature') }}",
                                         STATES["sensor.salon_temperature"]["state"])
            self.send({"id": mid, "type": "event", "event": {"result": text, "listeners": {}}})
        else:
            self.error(mid, "unknown_command", f"Unknown command {t}")


def fetch_icon(name):
    os.makedirs(ICON_CACHE, exist_ok=True)
    safe = os.path.basename(name)
    path = os.path.join(ICON_CACHE, safe)
    if not os.path.exists(path):
        url = "https://demo.home-assistant.io/static/mdi/" + safe
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 ha-plasmoid-test"})
        with urllib.request.urlopen(req, timeout=20) as r:
            data = r.read()
        with open(path, "wb") as f:
            f.write(data)
    with open(path, "rb") as f:
        return f.read()


class Handler(socketserver.BaseRequestHandler):
    no_config = False

    def handle(self):
        sock = self.request
        raw = b""
        while b"\r\n\r\n" not in raw:
            chunk = sock.recv(4096)
            if not chunk:
                return
            raw += chunk
        head = raw.split(b"\r\n\r\n")[0].decode("latin1")
        lines = head.split("\r\n")
        method, path, _ = lines[0].split(" ", 2)
        headers = {k.strip().lower(): v.strip() for k, v in (l.split(":", 1) for l in lines[1:] if ":" in l)}

        if path == "/api/websocket" and headers.get("upgrade", "").lower() == "websocket":
            accept = base64.b64encode(hashlib.sha1((headers["sec-websocket-key"] + GUID).encode()).digest()).decode()
            sock.sendall(("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                          f"Sec-WebSocket-Accept: {accept}\r\n\r\n").encode())
            try:
                Conn(sock, self.no_config).run()
            except (ConnectionError, OSError):
                pass
            return

        status, body, ctype = "404 Not Found", b"not found", "text/plain"
        if path.startswith("/static/mdi/"):
            try:
                body, status, ctype = fetch_icon(path[len("/static/mdi/"):]), "200 OK", "application/json"
            except Exception as e:  # noqa: BLE001
                body = str(e).encode()
        sock.sendall((f"HTTP/1.1 {status}\r\nContent-Type: {ctype}\r\nContent-Length: {len(body)}\r\n"
                      "Connection: close\r\n\r\n").encode() + body)


def simulate():
    """Move a few values so live updates can be seen."""
    while True:
        time.sleep(3)
        v = float(STATES["sensor.salon_temperature"]["state"]) + random.uniform(-0.3, 0.3)
        HUB.set_state("sensor.salon_temperature", f"{v:.2f}")
        HUB.set_state("sensor.bureau_co2", str(int(float(STATES["sensor.bureau_co2"]["state"]) + random.randint(-40, 40))))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--no-config", action="store_true")
    args = ap.parse_args()
    Handler.no_config = args.no_config
    socketserver.ThreadingTCPServer.allow_reuse_address = True
    socketserver.ThreadingTCPServer.daemon_threads = True
    srv = socketserver.ThreadingTCPServer(("127.0.0.1", args.port), Handler)
    threading.Thread(target=simulate, daemon=True).start()
    print(f"Fake Home Assistant on http://127.0.0.1:{args.port} (token: test)", flush=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
