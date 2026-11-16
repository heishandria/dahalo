extends Batiment
## Palissade épineuse (GDD §5) : défense périmétrique. Elle BLOQUE les unités des autres clans
## (calque de collision propre à chaque clan) et laisse passer son propre clan et les zébus.
## Un guerrier adverse arrêté par elle la sabote automatiquement, puis reprend son ordre.
## Spec : docs/specs/defense.md

var pv := GameRules.PALISSADE_PV
var _ralentis: Array = []
var _derniere_alerte := -INF

@onready var zone: Area3D = $Zone


func _ready() -> void:
	super()
	collision_layer = 4 | (64 << faction)   # 3 = clic ; 7 = palissades du joueur, 8 = palissades de l'IA
	zone.body_entered.connect(_on_entree)
	zone.body_exited.connect(_on_sortie)


func subir(degats: float, _attaquant) -> void:
	if mort:
		return
	pv -= degats
	if faction == GameRules.PLAYER and GameClock.temps_ecoule - _derniere_alerte > 6.0:
		_derniere_alerte = GameClock.temps_ecoule
		EventBus.alerte.emit(global_position)
		EventBus.message.emit("Votre palissade est attaquée !")
	if pv <= 0.0:
		_detruire()


func _detruire() -> void:
	mort = true
	for u in _ralentis:
		if is_instance_valid(u):
			u.ralentissements = maxi(0, u.ralentissements - 1)
	_ralentis.clear()
	if faction == GameRules.PLAYER:
		EventBus.message.emit("Une palissade a été sabotée !")
	queue_free()


func _on_entree(corps: Node3D) -> void:
	if corps is Unite and corps.faction != faction and not corps in _ralentis:
		_ralentis.append(corps)
		corps.ralentissements += 1


func _on_sortie(corps: Node3D) -> void:
	if corps in _ralentis:
		_ralentis.erase(corps)
		if is_instance_valid(corps):
			corps.ralentissements = maxi(0, corps.ralentissements - 1)
