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
}
const NOMS_BATIMENTS := {
	"case_centrale": "Case centrale",
	"enclos": "Enclos",
	"champ": "Champ",
	"camp_bois": "Camp de bûcherons",
	"puits": "Puits",
	"tsena": "Tsena",
}

# --- Champs (maïs / sorgho) ---
const CHAMP_POUSSE_S := 60.0
const CHAMP_RECOLTE := 150.0
const CHAMP_RESEMIS := {"bois": 15.0}
const POUSSE_SECHERESSE := 0.5         # la sécheresse ralentit la pousse

# --- Sources naturelles ---
const ARBRE_BOIS := 100.0
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
