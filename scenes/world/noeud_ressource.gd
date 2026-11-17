class_name NoeudRessource
extends StaticBody3D
## Source de ressource récoltable par les villageois. Spec : docs/specs/economie.md
##  - nature (faction WILD, accessible à tous) : épineux (bois), point d'eau (eau), raketa (nourriture)
##  - construite (appartient à un clan) : puits (eau) ; les champs héritent de ce script (champ.gd)

const VARIANTES := {
	# calque 8 = obstacle contourné par le calcul de chemin ; 16 = obstacle physique seulement
	"epineux": {"type": "bois", "noeud": "Epineux", "calque": 16, "rayon": 0.45},
	"point_eau": {"type": "eau", "noeud": "PointEau", "calque": 8, "rayon": 1.0},
	"raketa": {"type": "nourriture", "noeud": "Raketa", "calque": 16, "rayon": 0.6},
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
var _mare = null   # visuel du point d'eau (scenes/world/mare.gd)


func _ready() -> void:
	if variante != "" and VARIANTES.has(variante):
		type_ressource = VARIANTES[variante]["type"]
		_configurer_obstacle()
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
		# Visuel réaliste (mare ou trou d'eau creusé dans le lit) à la place du disque de la scène.
		($PointEau as Node3D).visible = false
		_mare = preload("res://scenes/world/mare.gd").new()
		_mare.name = "Mare"
		_mare.dans_le_lit = Terrain.dans_riviere(global_position)
		add_child(_mare)
		_mare.saison(GameClock.secheresse, true)
		EventBus.meteo_change.connect(_on_meteo)


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
		var rs := rendement_secheresse
		if ResourceManager.a_technologie(f, "puits_profonds"):
			rs = lerpf(rs, 1.0, 0.5)   # pénalité de sécheresse divisée par 2
		q *= rs
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


## Collision « physique » de la source (les unités butent dessus) selon sa variante.
func _configurer_obstacle() -> void:
	var obstacle := get_node_or_null("Obstacle") as StaticBody3D
	var forme := get_node_or_null("Obstacle/Forme") as CollisionShape3D
	if obstacle == null or forme == null:
		return
	obstacle.collision_layer = int(VARIANTES[variante]["calque"])
	var cylindre := CylinderShape3D.new()
	cylindre.radius = float(VARIANTES[variante]["rayon"])
	cylindre.height = 3.0
	forme.shape = cylindre


func _maj_visuel_repousse() -> void:
	# Arbre abattu : il disparaît complètement (plus cliquable, plus d'obstacle) jusqu'à la repousse.
	var arbre := get_node_or_null("Epineux") as Node3D
	if arbre == null or variante != "epineux":
		return
	arbre.visible = not en_repousse
	for chemin in ["Collision", "Obstacle/Forme"]:
		var collision := get_node_or_null(chemin) as CollisionShape3D
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
	# Le point d'eau se retire visuellement pendant la sécheresse.
	if _mare != null:
		_mare.saison(secheresse)
