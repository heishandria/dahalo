class_name GameRules
extends RefCounted
## Règles et valeurs d'équilibrage centralisées.
## Valeurs de départ pour le prototype : à ajuster en playtest. Spec : docs/specs/economie.md

# --- Factions ---
const PLAYER := 0
const AI := 1
const WILD := -1

# --- Victoire (GDD §3) ---
const ZEBUS_VICTOIRE := 40              # décidé le 16/11/2026 (le GDD donnait 50 en exemple)
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

# --- Troupeaux sauvages : arrivées au fil de la partie (spec : docs/specs/economie.md §9) ---
const ZEBUS_SAUVAGES_DEPART := [8, 6, 6]   # centre + deux troupeaux à égale distance des bases
const MIGRATION_NORMALE := 5               # à l'aube d'un jour normal
const MIGRATION_PLUIES := 10               # à l'aube qui suit une sécheresse (retour des pluies)
const ZEBUS_SAUVAGES_MAX := 30             # pas d'arrivée au-delà (évite d'encombrer la carte)
# Points d'arrivée, tous à égale distance des deux bases (diagonale de la carte).
const POINTS_MIGRATION := [Vector3(-48, 0, -48), Vector3(48, 0, 48), Vector3(-18, 0, -18), Vector3(18, 0, 18), Vector3(0, 0, 0)]

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
# Spec : docs/specs/ages.md. « age » = âge minimum ; « passage_age » = cette recherche fait changer d'âge.
const NOMS_AGES := {1: "Clan de la Brousse", 2: "Pistes et Convois", 3: "Seigneurs des Zébus"}
const TECHNOLOGIES := {
	# Passages d'âge (Case centrale)
	"age_2": {"nom": "Âge 2 : Pistes et Convois", "court": "Âge 2", "age": 1, "passage_age": 2,
		"batiment": "case_centrale", "cout": {"nourriture": 250.0, "bois": 200.0, "ariary": 60.0}, "temps": 40.0,
		"effet": "Débloque les technologies et le Tireur de l'Âge 2"},
	"age_3": {"nom": "Âge 3 : Seigneurs des Zébus", "court": "Âge 3", "age": 2, "passage_age": 3,
		"batiment": "case_centrale", "cout": {"nourriture": 400.0, "bois": 300.0, "ariary": 120.0}, "temps": 60.0,
		"effet": "Débloque les technologies de l'Âge 3"},
	# Âge 1 – Le Clan de la Brousse
	"cultures_traditionnelles": {"nom": "Cultures traditionnelles", "court": "Cultures", "age": 1,
		"batiment": "case_centrale", "cout": {"nourriture": 80.0, "bois": 60.0}, "temps": 25.0,
		"effet": "+25 % de récolte dans les champs"},
	"marcheurs_androy": {"nom": "Marcheurs de l'Androy", "court": "Marcheurs", "age": 1,
		"batiment": "case_centrale", "cout": {"nourriture": 100.0}, "temps": 25.0,
		"effet": "+15 % de vitesse pour toutes les unités"},
	"vannerie_cuirs": {"nom": "Vannerie et cuirs", "court": "Vannerie", "age": 1,
		"batiment": "case_centrale", "cout": {"nourriture": 50.0, "bois": 60.0}, "temps": 25.0,
		"effet": "Capacité de transport des villageois +50 %"},
	# Âge 2 – L'Âge des Pistes et des Convois
	"sagaies_acerees": {"nom": "Sagaies acérées", "court": "Sagaies", "age": 2,
		"batiment": "case_hommes", "cout": {"nourriture": 100.0, "bois": 50.0, "ariary": 40.0}, "temps": 30.0,
		"effet": "+30 % de dégâts pour les sagaies (Dahalo, Lanceur)"},
	"technique_pisteurs": {"nom": "Technique des pisteurs", "court": "Pistes", "age": 2,
		"batiment": "case_centrale", "cout": {"nourriture": 80.0, "ariary": 40.0}, "temps": 30.0,
		"effet": "Les traces des voleurs apparaissent sans Pisteur, et sur la mini-carte"},
	"puits_profonds": {"nom": "Puits profonds", "court": "Puits prof.", "age": 2,
		"batiment": "case_centrale", "cout": {"bois": 120.0, "ariary": 60.0}, "temps": 35.0,
		"effet": "Pénalité de sécheresse sur l'eau réduite de moitié"},
	# Âge 3 – Les Seigneurs des Zébus
	"pacte_eleveurs": {"nom": "Pacte des grands éleveurs", "court": "Pacte", "age": 3,
		"batiment": "case_centrale", "cout": {"nourriture": 200.0, "ariary": 120.0}, "temps": 45.0,
		"effet": "Naissance d'un veau par enclos bien tenu toutes les 90 s (12 naissances au plus)"},
	"raid_eclair": {"nom": "Raid éclair", "court": "Raid éclair", "age": 3,
		"batiment": "case_hommes", "cout": {"nourriture": 150.0, "ariary": 80.0}, "temps": 40.0,
		"effet": "Les Dahalo escortant un troupeau vont presque à pleine vitesse"},
	"maitres_tsena": {"nom": "Maîtres du Tsena", "court": "Maîtres Tsena", "age": 3,
		"batiment": "tsena", "cout": {"bois": 100.0, "ariary": 80.0}, "temps": 40.0,
		"effet": "Zébus vendus +25 %, achats −1/3, achat de zébus reproducteurs"},
}
const BONUS_SAGAIES_ACEREES := 1.3       # dégâts des armes « sagaie » et « sagaie_jet »
const BONUS_CULTURES := 1.25
const BONUS_MARCHEURS := 1.15
const BONUS_VANNERIE := 1.5
const MALUS_VITESSE_ESCORTE_RAID_ECLAIR := 0.85
const REPRODUCTION_S := 90.0
const PACTE_NAISSANCES_MAX := 12           # au-delà, il faut capturer, acheter ou voler
const BONUS_VENTE_MAITRES := 1.25
const REMISE_ACHAT_MAITRES := 2.0 / 3.0
const PRIX_ZEBU_REPRODUCTEUR := 80.0

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
# Vente de surplus (GDD §5 : le Tsena échange les surplus de bois et de nourriture)
const VENTES := {
	"bois": {"quantite": 50.0, "prix": 15.0},
	"nourriture": {"quantite": 50.0, "prix": 15.0},
}
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


static func prix_zebu_actuel(vole_recemment: bool, faction: int = -1) -> float:
	var p := PRIX_ZEBU
	if GameClock.secheresse:
		p *= PRIX_ZEBU_SECHERESSE
	if vole_recemment:
		p *= DECOTE_ZEBU_VOLE
	if faction >= 0 and ResourceManager.a_technologie(faction, "maitres_tsena"):
		p *= BONUS_VENTE_MAITRES
	return p


static func prix_vente_surplus(faction: int, prix_de_base: float) -> float:
	if ResourceManager.a_technologie(faction, "maitres_tsena"):
		return roundf(prix_de_base * BONUS_VENTE_MAITRES)
	return prix_de_base


static func prix_achat(faction: int, prix_de_base: float) -> float:
	if ResourceManager.a_technologie(faction, "maitres_tsena"):
		return roundf(prix_de_base * REMISE_ACHAT_MAITRES)
	return prix_de_base
