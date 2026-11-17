extends Batiment
## Enclos à zébus : chaque enclos ajoute de la capacité au cheptel (GDD §5).
## Un zébu escorté par un Dahalo du même clan qui entre dans la zone est sécurisé.

const INTERVALLE_SCAN := 0.3

@onready var zone: Area3D = $Zone
var _t := 0.0
var _delai_alerte := 0.0
var _delai_intrusion := 0.0
var _tas: MeshInstance3D       # tas de fourrage, baisse avec la nourriture du clan
var _eau_auge: MeshInstance3D  # eau de l'auge, baisse avec l'eau du clan
var _niveau_fourrage := 1.0
var _niveau_eau := 1.0


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
	if _t < INTERVALLE_SCAN:
		return
	_t = 0.0
	_maj_reserves(0.15)
	for b in zone.get_overlapping_bodies():
		if b is Zebu and b.etat == Zebu.Etat.SUIT and is_instance_valid(b.meneur) \
				and b.meneur.faction == faction:
			if ResourceManager.a_place(faction):
				b.securiser(self)
			elif faction == GameRules.PLAYER and _delai_alerte <= 0.0:
				_delai_alerte = 6.0
				EventBus.message.emit("Enclos pleins ! Construisez un nouvel enclos (touche E).")


## Appelé quand un Dahalo adverse commence à détacher un zébu : alerte immédiate, avant le vol.
func signaler_intrusion() -> void:
	if faction != GameRules.PLAYER:
		return
	EventBus.alerte.emit(global_position)
	if _delai_intrusion <= 0.0:
		_delai_intrusion = 8.0
		EventBus.message.emit("Alerte : des Dahalo forcent votre enclos ! (%d s par zébu)" % int(GameRules.DUREE_DETACHER_S))
