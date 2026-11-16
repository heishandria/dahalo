extends Batiment
## Palissade épineuse (GDD §5) : défense périmétrique. Ne bloque pas le passage, mais les ennemis
## qui la traversent avancent beaucoup plus lentement. Les guerriers adverses peuvent la saboter.
## Spec : docs/specs/defense.md

var pv := GameRules.PALISSADE_PV
var _ralentis: Array = []

@onready var zone: Area3D = $Zone


func _ready() -> void:
	super()
	zone.body_entered.connect(_on_entree)
	zone.body_exited.connect(_on_sortie)


func subir(degats: float, _attaquant) -> void:
	if mort:
		return
	pv -= degats
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
