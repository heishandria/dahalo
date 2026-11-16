class_name NoeudRessource
extends StaticBody3D
## Source de ressource récoltable par les villageois. Spec : docs/specs/economie.md
##  - nature (faction WILD, accessible à tous) : épineux (bois), point d'eau (eau), raketa (nourriture)
##  - construite (appartient à un clan) : puits (eau) ; les champs héritent de ce script (champ.gd)

const VARIANTES := {
	"epineux": {"type": "bois", "noeud": "Epineux"},
	"point_eau": {"type": "eau", "noeud": "PointEau"},
	"raketa": {"type": "nourriture", "noeud": "Raketa"},
}

@export var variante := ""        # pour les sources naturelles : clé de VARIANTES
@export_enum("bois", "eau", "nourriture") var type_ressource: String = "bois"
@export var type_batiment := ""   # non vide pour une source construite (« puits », « champ »)
@export var quantite := 100.0
@export var infini := false
@export var rendement := 1.0              # multiplicateur de la cadence de récolte
@export var rendement_secheresse := 1.0   # multiplicateur supplémentaire pendant la sécheresse
@export var bonus_eau := 0.0              # eau gagnée par unité récoltée pendant la sécheresse (raketa)
@export var repousse_s := 0.0             # > 0 : la source repousse après épuisement (arbres)

var faction := GameRules.WILD
var id := 0
var en_repousse := false
var _quantite_max := 0.0
var _chrono_repousse := 0.0


func _ready() -> void:
	if variante != "" and VARIANTES.has(variante):
		type_ressource = VARIANTES[variante]["type"]
	for v in VARIANTES:
		var n := get_node_or_null(String(VARIANTES[v]["noeud"])) as Node3D
		if n:
			n.visible = v == variante
	_quantite_max = quantite
	id = CommandBus.enregistrer(self)
	add_to_group("ressources")
	add_to_group("ressource_" + type_ressource)
	if type_batiment != "":
		add_to_group("batiments")
		add_to_group("batiments_%d" % faction)
		add_to_group(type_batiment)
	var banniere := get_node_or_null("Banniere") as MeshInstance3D
	if banniere:
		var m := StandardMaterial3D.new()
		m.albedo_color = GameRules.couleur_faction(faction)
		banniere.material_override = m
	if variante == "point_eau":
		EventBus.meteo_change.connect(_on_meteo)
		_on_meteo(GameClock.secheresse)


func _process(delta: float) -> void:
	if not en_repousse:
		return
	_chrono_repousse -= delta
	if _chrono_repousse <= 0.0:
		en_repousse = false
		quantite = _quantite_max
		_maj_visuel_repousse()


# --- API utilisée par les villageois et l'IA ---

func peut_etre_recolte_par(f: int) -> bool:
	return faction == GameRules.WILD or faction == f


## Récoltable maintenant ?
func disponible() -> bool:
	return not en_repousse and (infini or quantite > 0.0)


## Disparue pour de bon ?
func epuise() -> bool:
	return not infini and quantite <= 0.0 and repousse_s <= 0.0


## Un villageois doit-il attendre sur place si la source n'est pas disponible ? (vrai pour un champ qui pousse)
func attendre_recolte() -> bool:
	return false


func extraire(q: float, f: int) -> float:
	if not disponible():
		return 0.0
	q *= rendement
	if GameClock.secheresse:
		q *= rendement_secheresse
		if bonus_eau > 0.0:
			ResourceManager.ajouter(f, "eau", q * bonus_eau)
	if not infini:
		q = minf(q, quantite)
		quantite -= q
		if quantite <= 0.0:
			_sur_epuisement()
		else:
			_maj_visuel_arbre()
	return q


func _sur_epuisement() -> void:
	if repousse_s > 0.0:
		en_repousse = true
		_chrono_repousse = repousse_s
		_maj_visuel_repousse()
	else:
		queue_free()


func _maj_visuel_repousse() -> void:
	# Arbre abattu : il disparaît complètement (plus cliquable) jusqu'à la repousse.
	var arbre := get_node_or_null("Epineux") as Node3D
	if arbre == null or variante != "epineux":
		return
	arbre.visible = not en_repousse
	var collision := get_node_or_null("Collision") as CollisionShape3D
	if collision:
		collision.set_deferred("disabled", en_repousse)
	_maj_visuel_arbre()


## L'arbre rapetisse à chaque coup de hache, jusqu'à disparaître.
func _maj_visuel_arbre() -> void:
	var arbre := get_node_or_null("Epineux") as Node3D
	if arbre == null or variante != "epineux" or _quantite_max <= 0.0:
		return
	var reste := clampf(quantite / _quantite_max, 0.0, 1.0)
	arbre.scale = Vector3.ONE * (0.4 + 0.6 * reste)


func _on_meteo(secheresse: bool) -> void:
	# Le point d'eau rétrécit visuellement pendant la sécheresse.
	var eau := get_node_or_null("PointEau") as Node3D
	if eau:
		var s := 0.45 if secheresse else 1.0
		eau.scale = Vector3(s, 1.0, s)
