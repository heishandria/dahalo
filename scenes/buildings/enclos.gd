extends Batiment
## Enclos à zébus : chaque enclos ajoute de la capacité au cheptel (GDD §5).
## Un zébu escorté par un Dahalo du même clan qui entre dans la zone est sécurisé.

const INTERVALLE_SCAN := 0.3

@onready var zone: Area3D = $Zone
var _t := 0.0
var _delai_alerte := 0.0


func _ready() -> void:
	super()
	ResourceManager.ajouter_enclos(faction)


func _physics_process(delta: float) -> void:
	_t += delta
	_delai_alerte = maxf(0.0, _delai_alerte - delta)
	if _t < INTERVALLE_SCAN:
		return
	_t = 0.0
	for b in zone.get_overlapping_bodies():
		if b is Zebu and b.etat == Zebu.Etat.SUIT and is_instance_valid(b.meneur) \
				and b.meneur.faction == faction:
			if ResourceManager.a_place(faction):
				b.securiser(self)
			elif faction == GameRules.PLAYER and _delai_alerte <= 0.0:
				_delai_alerte = 6.0
				EventBus.message.emit("Enclos pleins ! Construisez un nouvel enclos (touche E).")
