class_name GameRules
extends RefCounted
## Règles et valeurs d'équilibrage centralisées.
## Valeurs de départ pour le prototype : à ajuster en playtest. Spec : docs/specs/economie.md

# --- Factions ---
const PLAYER := 0
const AI := 1
const WILD := -1

# --- Victoire (GDD §3) ---
const ZEBUS_VICTOIRE := 50
const DUREE_PARTIE_S := 30.0 * 60.0
const CAPACITE_PAR_ENCLOS := 10

# --- Temps et climat (GDD §7) ---
const DUREE_JOUR_S := 240.0            # un cycle jour + nuit complet
const PART_NUIT := 0.35                # fraction du cycle passée de nuit
const CYCLES_ENTRE_SECHERESSES := 2    # jours normaux avant une sécheresse
const DUREE_SECHERESSE_CYCLES := 1

# --- Vision et brouillard de guerre (spec : docs/specs/vision.md) ---
const DEMI_CARTE := 60.0               # la carte va de -60 à +60 m
const TAILLE_CASE_VISION := 2.0        # 60 × 60 cases (garder Vision.N cohérent)
const FREQUENCE_VISION_S := 0.2
const VISION_BATIMENT := 12.0
const VISION_NUIT := 0.6               # multiplicateur de vision la nuit (bâtiments ; unités : voir .tres)
const DUREE_TRACES_S := 90.0
const PORTEE_LECTURE_TRACES := 15.0    # distance à laquelle un Pisteur repère une trace
const ECART_TRACES_M := 3.0

# --- Ressources ---
const RESSOURCES := ["nourriture", "eau", "bois", "ariary"]
const RESSOURCES_DEPART := {"nourriture": 150.0, "eau": 100.0, "bois": 150.0, "ariary": 50.0}

# --- Entretien du cheptel : seuls les zébus en enclos consomment ---
const CONSO_EAU_ZEBU_S := 0.05
const CONSO_NOURRITURE_ZEBU_S := 0.04
const INTERVALLE_FUITE_S := 20.0       # en manque d'eau ou de nourriture, un zébu s'enfuit à cet intervalle

# --- Bâtiments ---
const COUTS_BATIMENTS := {
	"enclos": {"bois": 100.0},
	"champ": {"bois": 60.0},
	"camp_bois": {"bois": 80.0},
	"puits": {"bois": 60.0, "ariary": 40.0},
	"tsena": {"bois": 150.0},
	"case_hommes": {"bois": 120.0},
	"palissade": {"bois": 15.0},
}
const NOMS_BATIMENTS := {
	"case_centrale": "Case centrale",
	"enclos": "Enclos",
	"champ": "Champ",
	"camp_bois": "Camp de bûcherons",
	"puits": "Puits",
	"tsena": "Tsena",
	"case_hommes": "Case des Hommes",
	"palissade": "Palissade épineuse",
}

# Emprise au sol (largeur x profondeur, en m) pour l'aperçu et l'anti-chevauchement.
const EMPRISES := {
	"case_centrale": Vector2(4, 4),
	"enclos": Vector2(8, 8),
	"champ": Vector2(6, 6),
	"camp_bois": Vector2(3, 3),
	"puits": Vector2(2.6, 2.6),
	"tsena": Vector2(5, 4),
	"case_hommes": Vector2(4.5, 3.5),
	"palissade": Vector2(4, 0.6),
}
const RAYONS_SOURCES := {"bois": 1.2, "eau": 1.9, "nourriture": 1.0}

# --- Formation : quel bâtiment forme quelles unités ---
const FORMATIONS := {
	"case_centrale": ["villageois", "pisteur"],
	"case_hommes": ["dahalo", "lanceur", "tireur"],
}

# --- Défense (spec : docs/specs/defense.md) ---
const PALISSADE_PV := 150.0
const PALISSADE_RALENTISSEMENT := 0.35   # vitesse des ennemis qui traversent une palissade

# --- Technologies (recherchées dans un bâtiment) ---
const TECHNOLOGIES := {
	"sagaies_acerees": {
		"nom": "Sagaies acérées",
		"batiment": "case_hommes",
		"cout": {"nourriture": 100.0, "bois": 50.0, "ariary": 40.0},
		"temps": 30.0,
	},
}
const BONUS_SAGAIES_ACEREES := 1.3       # dégâts des armes « sagaie » et « sagaie_jet »

# --- Champs (maïs / sorgho) ---
const CHAMP_POUSSE_S := 60.0          # temps de culture pour UN villageois (2 villageois = 2× plus vite)
const MAX_CULTIVATEURS := 3            # au-delà, les villageois en plus n'accélèrent plus la pousse
const CHAMP_RECOLTE := 150.0
const CHAMP_RESEMIS := {"bois": 15.0}
const POUSSE_SECHERESSE := 0.5         # la sécheresse ralentit la pousse

# --- Sources naturelles ---
const ARBRE_BOIS := 50.0              # ~5 allers-retours de villageois, puis l'arbre disparaît
const ARBRE_REPOUSSE_S := 240.0
const RAKETA_RENDEMENT := 0.6          # cueillette lente…
const RAKETA_BONUS_EAU := 0.5          # …mais en sécheresse, le raketa abreuve aussi
const POINT_EAU_SECHERESSE := 0.3
const PUITS_SECHERESSE := 0.6

# --- Tsena (marché) ---
const PRIX_ZEBU := 40.0
const PRIX_ZEBU_SECHERESSE := 0.5      # tout le monde vend pendant la sécheresse : les prix chutent
const DECOTE_ZEBU_VOLE := 0.4
const DELAI_ZEBU_VOLE_S := 180.0
const ACHATS := {
	"bois": {"quantite": 50.0, "prix": 30.0},
	"nourriture": {"quantite": 50.0, "prix": 30.0},
}

# --- Escorte (GDD §7) ---
const MAX_ZEBUS_ESCORTE := 5
const MALUS_VITESSE_ESCORTE := 0.6     # un troupeau en fuite avance lentement


static func couleur_faction(faction: int) -> Color:
	match faction:
		PLAYER:
			return Color(0.2, 0.5, 1.0)
		AI:
			return Color(0.75, 0.2, 0.75)
		_:
			return Color(0.6, 0.6, 0.6)


static func prix_zebu_actuel(vole_recemment: bool) -> float:
	var p := PRIX_ZEBU
	if GameClock.secheresse:
		p *= PRIX_ZEBU_SECHERESSE
	if vole_recemment:
		p *= DECOTE_ZEBU_VOLE
	return p
