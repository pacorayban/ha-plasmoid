.pragma library

// Widget UI strings. Source strings are English; other languages come from the
// dictionaries below. The language follows the Home Assistant user profile
// (client.language), like the HA web UI, so the widget matches the states and
// names HA itself sends. To add a language, add a dictionary to DICTS.
//
// tr(client, text, args...)       "%1", "%2"... are replaced by args
// trp(client, n, one, many, args)  plural form, "%1" is n

var FR = {
    // States and times
    "Not found": "Introuvable",
    "Unavailable": "Indisponible",
    "Unknown": "Inconnu",
    "in a few seconds": "dans quelques secondes",
    "a few seconds ago": "il y a quelques secondes",
    "in %1 min": "dans %1 min",
    "%1 min ago": "il y a %1 min",
    "in %1 h": "dans %1 h",
    "%1 h ago": "il y a %1 h",
    "in %1 day": ["dans %1 jour", "dans %1 jours"],
    "%1 day ago": ["il y a %1 jour", "il y a %1 jours"],
    "Yes": "Oui",
    "No": "Non",
    " (night)": " (nuit)",
    "Currently %1": "Actuellement %1",

    // Controls
    "Activate": "Activer",
    "Run": "Exécuter",
    "Stop": "Arrêter",
    "Press": "Appuyer",
    "Lock": "Verrouiller",
    "Unlock": "Déverrouiller",
    "Open": "Ouvrir",
    "Back": "Retour",
    "Reload": "Recharger",
    "Reconnect": "Reconnecter",
    "Open Home Assistant": "Ouvrir Home Assistant",
    "Open in Home Assistant": "Ouvrir dans Home Assistant",
    "“%1” card not supported": "carte « %1 » non prise en charge",
    "View %1": "Vue %1",

    // Connection and loading
    "Connected": "Connecté",
    "Disconnected": "Déconnecté",
    "Connected to Home Assistant %1": "Connecté à Home Assistant %1",
    "Reconnecting to Home Assistant…": "Reconnexion à Home Assistant…",
    "Widget not configured": "Widget non configuré",
    "Enter the Home Assistant address and a long-lived access token.":
        "Renseignez l'adresse de Home Assistant et un jeton d'accès longue durée.",
    "Configure…": "Configurer…",
    "Retry": "Réessayer",
    "Cannot connect": "Connexion impossible",
    "Dashboard unavailable": "Tableau de bord indisponible",
    "Dashboard “%1” not found: %2": "Tableau de bord « %1 » introuvable : %2",
    "default": "par défaut",
    "Action refused: %1": "Action refusée : %1",
    "Connection closed": "Connexion fermée",
    "Connection lost": "Connexion perdue",
    "No answer from the server": "Pas de réponse du serveur",
    "Token rejected by Home Assistant": "Jeton refusé par Home Assistant",
    "Unknown error": "Erreur inconnue",
    "Not connected": "Non connecté",
    "Loading failed: %1": "Chargement impossible : %1",
    "The address must start with http:// or https://": "L'adresse doit commencer par http:// ou https://",

    // Generated dashboards
    "Overview": "Aperçu",
    "Helpers": "Entrées",
    "Home": "Accueil",
    "## Hello {{ user }}!": "## Bonjour {{ user }} !",
    "Favorites": "Favoris",
    "Areas": "Pièces",
    "Other areas": "Autres pièces",
    "Devices": "Appareils",
    "Unnamed device": "Appareil sans nom",
    "Others": "Autres",
    "Weather": "Météo",
    "Summaries": "Résumés",
    "Scenes": "Scènes",
    "Automations": "Automatisations",
    "Lights": "Lumières",
    "Climate": "Climat",
    "Security": "Sécurité",
    "Media players": "Lecteurs multimédias",
    "Maintenance": "Maintenance",
    "Energy": "Énergie",
    "People": "Personnes",
    "Alerts": "Alertes",
    "All off": "Éteintes",
    "On": "Allumées",

    // Summaries
    "%1 light on": ["%1 allumée", "%1 allumées"],
    "All lights off": "Toutes éteintes",
    "%1 lock unlocked": ["%1 déverrouillée", "%1 déverrouillées"],
    "%1 alarm disarmed": ["%1 alarme désarmée", "%1 alarmes désarmées"],
    "All secure": "Tout est sécurisé",
    "%1 playing": ["%1 en lecture", "%1 en lecture"],
    "Nothing playing": "Rien en lecture",
    "%1 alert": ["%1 alerte", "%1 alertes"],
    "All good": "Tout est en ordre",

    // Settings page
    "General": "Général",
    "Home Assistant address:": "Adresse de Home Assistant :",
    "Long-lived access token:": "Jeton d'accès longue durée :",
    "Create one in Home Assistant: your profile → Security tab → Long-lived access tokens. The token is stored in plain text in your Plasma session configuration.":
        "À créer dans Home Assistant : votre profil → onglet Sécurité → Jetons d'accès longue durée. Le jeton est stocké en clair dans la configuration Plasma de votre session.",
    "Dashboard:": "Tableau de bord :",
    "empty = Home Assistant home page": "vide = page d'accueil de HA",
    "Paste a dashboard address from the browser (e.g. https://…/dashboard-music/0) or just its path (dashboard-music). “home” or https://…/home/overview = the Home page.":
        "Collez l'adresse d'un tableau de bord depuis le navigateur (ex. https://…/dashboard-music/0) ou juste son chemin (dashboard-music). « home » ou https://…/home/overview = la page Accueil.",
    "Column width (px):": "Largeur de colonne (px) :",
    "Card opacity (%):": "Opacité des cartes (%) :",
    "Header:": "En-tête :",
    "Show tabs and the reload button": "Afficher les onglets et le bouton de rechargement"
};

var DICTS = { fr: FR };

// Plural rules: index of the plural form to use for n.
var PLURAL_RULES = {
    fr: function (n) { return n > 1 ? 1 : 0; }
};

function language(client) {
    var l = client && client.language ? String(client.language) : "en";
    return l.split(/[-_]/)[0].toLowerCase();
}

function fill(text, args, from) {
    var out = String(text);
    for (var i = from; i < args.length; i++)
        out = out.split("%" + (i - from + 1)).join(String(args[i]));
    return out;
}

function tr(client, text) {
    var d = DICTS[language(client)];
    var t = d ? d[text] : undefined;
    if (Array.isArray(t))
        t = t[0];
    return fill(t || text, arguments, 2);
}

function trp(client, n, one, many) {
    var lang = language(client);
    var d = DICTS[lang];
    var t = d ? d[one] : undefined;
    var form;
    if (Array.isArray(t))
        form = t[(PLURAL_RULES[lang] || function (x) { return x === 1 ? 0 : 1; })(n)];
    else if (typeof t === "string")
        form = t;
    else
        form = n === 1 ? one : many;
    var args = [n];
    for (var i = 4; i < arguments.length; i++)
        args.push(arguments[i]);
    return fill(form, args, 0);
}

// For places without a HA connection (settings page): the system language.
function systemClient() {
    return { language: Qt.locale().name };
}
