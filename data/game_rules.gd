class_name GameRules
extends RefCounted
## Règles et valeurs d'équilibrage centralisées.
## Valeurs de départ pour le prototype : à ajuster en playtest.

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
const RENDEMENT_EAU_SECHERESSE := 0.3  # multiplicateur de puisage pendant la sécheresse

# --- Consommation d'eau (anti-snowballing, GDD §7) ---
const CONSO_EAU_ZEBU_S := 0.05
const CONSO_EAU_VILLAGEOIS_S := 0.02
const MALUS_TRAVAIL_SOIF := 0.5        # les villageois assoiffés travaillent au ralenti

# --- Économie ---
const RESSOURCES_DEPART := {"bois": 150.0, "eau": 100.0, "nourriture": 150.0}
const COUT_ENCLOS := {"bois": 100.0}

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
