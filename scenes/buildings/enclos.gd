extends Batiment
## Enclos à zébus : chaque enclos ajoute de la capacité au cheptel (GDD §5).
## Un zébu escorté par un Dahalo du même clan qui entre dans la zone est sécurisé.
## Pâturage : le joueur (ou l'IA) peut mener le troupeau dehors le jour, gardé par un villageois
## (docs/specs/zebus.md §4).

const INTERVALLE_SCAN := 0.3
# Porte de l'enclos (ouverture de 2 m au sud, +Z) : point juste dedans, point juste dehors (repère de l'enclos).
const PORTE_DEDANS := Vector3(0, 0, 2.4)
const PORTE_DEHORS := Vector3(0, 0, 6.0)

@onready var zone: Area3D = $Zone
var _t := 0.0
var _delai_alerte := 0.0
var _delai_intrusion := 0.0
var _tas: MeshInstance3D       # tas de fourrage, baisse avec la nourriture du clan
var _eau_auge: MeshInstance3D  # eau de l'auge, baisse avec l'eau du clan
var _niveau_fourrage := 1.0
var _niveau_eau := 1.0
var paturage := false            # le troupeau est mené au pâturage (chaque jour, tant que c'est actif)
var gardien = null               # Unite (villageois) qui garde le troupeau
var centre_paturage := Vector3.ZERO
var _delai_vol_paturage := 0.0


func _ready() -> void:
	super()
	ResourceManager.ajouter_enclos(faction)
	var modele := Maisons.modele(type_batiment, Plantes.variante_en(global_position))
	if modele.has("fourrage"):
		_tas = _ajouter_maillage("Fourrage", modele["fourrage"], Maisons.FOURRAGE_ENCLOS)
		_eau_auge = _ajouter_maillage("EauAuge", modele["eau_auge"], Maisons.AUGE_ENCLOS)
		_maj_reserves(1.0)


func _ajouter_maillage(nom: String, maillage: Mesh, position_locale: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = nom
	instance.mesh = maillage
	instance.position = position_locale
	add_child(instance)
	return instance


## Part (0 à 1) du tas de fourrage ou de l'eau de l'auge qui reste, d'après les réserves du clan : plein tant
## qu'il reste RESERVE_ENCLOS_PLEIN_MIN minutes pour tout le cheptel, vide à zéro.
static func remplissage(f: int, ressource: String) -> float:
	var stock := ResourceManager.quantite(f, ressource)
	if stock <= 0.0:
		return 0.0
	var besoin := ResourceManager.conso_par_minute(f, ressource) * GameRules.RESERVE_ENCLOS_PLEIN_MIN
	if besoin <= 0.0:
		return 1.0
	return clampf(stock / besoin, 0.0, 1.0)


## Le tas s'affaisse et rétrécit, l'eau descend dans l'auge (en douceur) ; vides, ils disparaissent.
func _maj_reserves(part: float) -> void:
	if _tas == null:
		return
	_niveau_fourrage = lerpf(_niveau_fourrage, remplissage(faction, "nourriture"), part)
	_niveau_eau = lerpf(_niveau_eau, remplissage(faction, "eau"), part)
	_tas.visible = _niveau_fourrage > 0.03
	var largeur := lerpf(0.45, 1.0, sqrt(_niveau_fourrage))
	_tas.scale = Vector3(largeur, maxf(_niveau_fourrage, 0.05), largeur)
	_eau_auge.visible = _niveau_eau > 0.03
	_eau_auge.position.y = Maisons.AUGE_ENCLOS.y - 0.1 * (1.0 - _niveau_eau)


func _physics_process(delta: float) -> void:
	_t += delta
	_delai_alerte = maxf(0.0, _delai_alerte - delta)
	_delai_intrusion = maxf(0.0, _delai_intrusion - delta)
	_delai_vol_paturage = maxf(0.0, _delai_vol_paturage - delta)
	if _t < INTERVALLE_SCAN:
		return
	_t = 0.0
	_maj_reserves(0.15)
	if paturage and not _gardien_present():
		_arreter_paturage("Le gardien a quitté le troupeau : les zébus rentrent à l'enclos.")
	for b in zone.get_overlapping_bodies():
		if b is Zebu and b.etat == Zebu.Etat.SUIT and is_instance_valid(b.meneur) \
				and b.meneur.faction == faction:
			if ResourceManager.a_place(faction):
				b.securiser(self)
			elif faction == GameRules.PLAYER and _delai_alerte <= 0.0:
				_delai_alerte = 6.0
				EventBus.message.emit("Enclos pleins ! Construisez un nouvel enclos (touche E).")


## Appelé quand un Dahalo adverse commence à détacher un zébu : alerte immédiate, avant le vol.
## `lieu` : position du zébu (dans l'enclos ou au pâturage).
func signaler_intrusion(au_paturage: bool = false, lieu: Vector3 = Vector3.INF) -> void:
	if faction != GameRules.PLAYER:
		return
	EventBus.alerte.emit(global_position if lieu == Vector3.INF else lieu)
	if au_paturage:
		if _delai_vol_paturage <= 0.0:
			_delai_vol_paturage = 8.0
			EventBus.message.emit("Alerte : des Dahalo volent vos zébus au pâturage ! (%d s par zébu)"
					% int(GameRules.DUREE_CAPTURE_PATURAGE_S))
		return
	if _delai_intrusion <= 0.0:
		_delai_intrusion = 8.0
		EventBus.message.emit("Alerte : des Dahalo forcent votre enclos ! (%d s par zébu)" % int(GameRules.DUREE_DETACHER_S))


# --- Pâturage ---

## Vrai quand le troupeau doit être dehors : pâturage actif, gardien présent, en journée (après l'aube et
## jusqu'à un peu avant la nuit, le temps de rentrer).
func troupeau_dehors() -> bool:
	if not paturage or not _gardien_present():
		return false
	var duree_jour := GameRules.DUREE_JOUR_S * (1.0 - GameRules.PART_NUIT)
	var ecoule := GameClock.phase_jour() * GameRules.DUREE_JOUR_S
	return ecoule >= GameRules.PATURAGE_SORTIE_APRES_AUBE_S \
			and ecoule < duree_jour - GameRules.PATURAGE_RETOUR_AVANT_NUIT_S


func porte_dedans() -> Vector3:
	return global_position + PORTE_DEDANS


func porte_dehors() -> Vector3:
	return global_position + PORTE_DEHORS


## Commande « paturage » (CommandBus) : mener le troupeau dehors le jour, ou le garder au parc.
func mener_au_paturage(actif: bool) -> void:
	if not actif:
		_arreter_paturage("Le troupeau reste au parc." if paturage else "")
		return
	if paturage:
		return
	var v = _choisir_gardien()
	if v == null:
		_message("Il faut un villageois libre pour garder le troupeau au pâturage.")
		return
	centre_paturage = _choisir_paturage()
	gardien = v
	paturage = true
	v.garder(self)
	if not troupeau_dehors():
		var ecoule := GameClock.phase_jour() * GameRules.DUREE_JOUR_S
		var ce_matin := ecoule < GameRules.PATURAGE_SORTIE_APRES_AUBE_S
		_message("Le troupeau sortira au pâturage %s, avec son gardien." % ("dans un instant" if ce_matin else "demain matin"))
	else:
		_message("Le troupeau part au pâturage avec son gardien. Il rentrera avant la nuit.")


func _arreter_paturage(texte: String) -> void:
	paturage = false
	if is_instance_valid(gardien) and not gardien.mort and gardien.troupeau_garde == self:
		gardien.liberer_garde()
	gardien = null
	if texte != "":
		_message(texte)


func _gardien_present() -> bool:
	return is_instance_valid(gardien) and not gardien.mort and gardien.troupeau_garde == self


## Le villageois du clan le plus proche, de préférence inoccupé ; jamais un gardien d'un autre troupeau.
func _choisir_gardien():
	var meilleur = null
	var note_min := INF
	for u in get_tree().get_nodes_in_group("unites_%d" % faction):
		if u.mort or u.data.role != "villageois" or u.troupeau_garde != null:
			continue
		var note: float = u.global_position.distance_to(global_position) + (0.0 if u.est_inactif() else 1000.0)
		if note < note_min:
			note_min = note
			meilleur = u
	return meilleur


## Le meilleur coin d'herbe parmi quelques points tirés entre PATURAGE_DISTANCE_MIN et _MAX de l'enclos,
## du côté de la porte de préférence (pas au sommet des collines, pas hors de la carte).
func _choisir_paturage() -> Vector3:
	var vegetation := get_tree().get_first_node_in_group("vegetation")
	var limite := GameRules.DEMI_CARTE - GameRules.PATURAGE_RAYON - 2.0
	var meilleur := porte_dehors() + Vector3(0, 0, GameRules.PATURAGE_DISTANCE_MIN)
	var note_max := -INF
	for k in 16:
		var a := randf() * TAU
		var d := randf_range(GameRules.PATURAGE_DISTANCE_MIN, GameRules.PATURAGE_DISTANCE_MAX)
		var p := global_position + Vector3(cos(a), 0.0, sin(a)) * d
		if absf(p.x) > limite or absf(p.z) > limite or Terrain.infranchissable(p):
			continue
		var herbe: float = vegetation.densite_herbe(p) if vegetation != null else 0.5
		var cote_porte := 0.15 * sin(a)   # +Z : du côté de la porte
		var note := herbe + cote_porte + randf() * 0.1
		if note > note_max:
			note_max = note
			meilleur = p
	meilleur.y = 0.0
	return meilleur
