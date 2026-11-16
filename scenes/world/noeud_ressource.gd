class_name NoeudRessource
extends StaticBody3D
## Source de ressource : baobab (bois), point d'eau (eau), buisson (nourriture). GDD §4.

@export_enum("bois", "eau", "nourriture") var type_ressource: String = "bois"
@export var quantite := 300.0
@export var infini := false   # les points d'eau ne s'épuisent pas, mais faiblissent en sécheresse
var id := 0

@onready var _visuels := {
	"bois": $Baobab,
	"eau": $PointEau,
	"nourriture": $Buisson,
}


func _ready() -> void:
	id = CommandBus.enregistrer(self)
	add_to_group("ressources")
	add_to_group("ressource_" + type_ressource)
	for t in _visuels:
		_visuels[t].visible = t == type_ressource
	if type_ressource == "eau":
		EventBus.meteo_change.connect(_on_meteo)
		_on_meteo(GameClock.secheresse)


func extraire(q: float) -> float:
	if type_ressource == "eau" and GameClock.secheresse:
		q *= GameRules.RENDEMENT_EAU_SECHERESSE
	if not infini:
		q = minf(q, quantite)
		quantite -= q
		if quantite <= 0.0:
			queue_free()
	return q


func epuise() -> bool:
	return not infini and quantite <= 0.0


func _on_meteo(secheresse: bool) -> void:
	# Le point d'eau rétrécit visuellement pendant la sécheresse.
	var s := 0.45 if secheresse else 1.0
	$PointEau.scale = Vector3(s, 1.0, s)
