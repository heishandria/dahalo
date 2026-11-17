extends Control
## Mini-carte (GDD §9) : terrain exploré, unités, bâtiments, zébus, points d'eau, alertes de raid.
## Toucher / cliquer dessus déplace la caméra. Respecte le brouillard de guerre du joueur.

const TAILLE := 200.0
const FREQUENCE_S := 0.25
const DUREE_ALERTE_S := 6.0
const COULEUR_INEXPLORE := Color(0.03, 0.03, 0.05)
const COULEUR_EXPLORE := Color(0.42, 0.26, 0.16)
const COULEUR_VISIBLE := Color(0.72, 0.45, 0.26)
# Terrain particulier (une fois exploré) : plateaux et lit de rivière.
const COULEUR_PLATEAU := Color(0.86, 0.7, 0.48)
const COULEUR_RIVIERE := Color(0.9, 0.78, 0.55)

var _image: Image
var _texture: ImageTexture
var _octets := PackedByteArray()
var _alertes: Array = []   # [position, temps de fin]
var _chrono := 0.0
var _camera_rig = null
var _terrain := PackedByteArray()   # par case : 0 = sol, 1 = plateau, 2 = lit de rivière (calculé une fois)


func _ready() -> void:
	custom_minimum_size = Vector2(TAILLE, TAILLE)
	size = Vector2(TAILLE, TAILLE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var n := Vision.N
	_octets.resize(n * n * 3)
	_image = Image.create_from_data(n, n, false, Image.FORMAT_RGB8, _octets)
	_texture = ImageTexture.create_from_image(_image)
	EventBus.alerte.connect(_on_alerte)
	_camera_rig = get_node_or_null("../../CameraRig")   # HUD -> Main -> CameraRig


func _process(delta: float) -> void:
	_chrono += delta
	if _chrono < FREQUENCE_S:
		return
	_chrono = 0.0
	_maj_terrain()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	var mm := event as InputEventMouseMotion
	var pos := Vector2(-1, -1)
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pos = mb.position
	elif mm != null and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pos = mm.position
	if pos.x >= 0.0 and _camera_rig != null:
		_camera_rig.centrer_sur(_vers_monde(pos))
		accept_event()


func _on_alerte(position_monde: Vector3) -> void:
	_alertes.append([position_monde, GameClock.temps_ecoule + DUREE_ALERTE_S])


func _maj_terrain() -> void:
	var f := GameRules.PLAYER
	var n := Vision.N
	var tout := Vision.revele_tout
	var vu: PackedByteArray = Vision.vu[f]
	var explore: PackedByteArray = Vision.explore[f]
	if _terrain.is_empty():
		_calculer_terrain(n)
	for i in n * n:
		var c := COULEUR_INEXPLORE
		if tout or vu[i] == 1 or explore[i] == 1:
			match _terrain[i]:
				1:
					c = COULEUR_PLATEAU
				2:
					c = COULEUR_RIVIERE
				_:
					c = COULEUR_VISIBLE
			if not (tout or vu[i] == 1):
				c = c.darkened(0.4)   # exploré mais pas vu en ce moment
		_octets[i * 3] = c.r8
		_octets[i * 3 + 1] = c.g8
		_octets[i * 3 + 2] = c.b8
	_image.set_data(n, n, false, Image.FORMAT_RGB8, _octets)
	_texture.update(_image)


func _calculer_terrain(n: int) -> void:
	_terrain.resize(n * n)
	var case := 2.0 * GameRules.DEMI_CARTE / n
	for j in n:
		for i in n:
			var p := Vector3(-GameRules.DEMI_CARTE + (i + 0.5) * case, 0.0, -GameRules.DEMI_CARTE + (j + 0.5) * case)
			if Terrain.infranchissable(p):
				_terrain[j * n + i] = 1
			elif Terrain.dans_riviere(p):
				_terrain[j * n + i] = 2


func _draw() -> void:
	var f := GameRules.PLAYER
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, Vector2(TAILLE, TAILLE)), false)

	# Points d'eau et puits découverts
	for r in get_tree().get_nodes_in_group("ressource_eau"):
		if Vision.est_explore(f, r.global_position):
			draw_circle(_vers_carte(r.global_position), 3.0, Color(0.3, 0.6, 1.0))
	# Bâtiments : les siens toujours, ceux des autres une fois explorés
	for b in get_tree().get_nodes_in_group("batiments"):
		if b.faction == f or Vision.est_explore(f, b.global_position):
			var cote := 6.0 if b.get("type_batiment") in ["case_centrale", "enclos"] else 4.0
			draw_rect(Rect2(_vers_carte(b.global_position) - Vector2(cote, cote) * 0.5, Vector2(cote, cote)),
					GameRules.couleur_faction(b.faction))
	# Zébus : les siens toujours, les autres s'ils sont visibles
	for z in get_tree().get_nodes_in_group("zebus"):
		if z.proprietaire == f or Vision.est_visible(f, z.global_position):
			draw_rect(Rect2(_vers_carte(z.global_position) - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.95, 0.92, 0.85))
	# Unités : les siennes toujours, les ennemies si elles sont visibles
	for u in get_tree().get_nodes_in_group("unites"):
		if u.faction == f or Vision.est_visible(f, u.global_position):
			draw_circle(_vers_carte(u.global_position), 2.2, GameRules.couleur_faction(u.faction).lightened(0.2))
	# Traces des voleurs déjà repérées
	for t in get_tree().get_nodes_in_group("traces"):
		if t.lue and t.faction_volee == f:
			draw_rect(Rect2(_vers_carte(t.global_position) - Vector2(1, 1), Vector2(2, 2)), Color(0.55, 0.3, 0.15))
	# Zone vue par la caméra
	if _camera_rig != null:
		var cam: Camera3D = _camera_rig.get_node("Camera3D")
		var demi := cam.size * 0.9
		var centre := _vers_carte(_camera_rig.global_position)
		var ech := TAILLE / (GameRules.DEMI_CARTE * 2.0)
		draw_rect(Rect2(centre - Vector2(demi, demi) * ech, Vector2(demi, demi) * 2.0 * ech), Color(1, 1, 1, 0.7), false, 1.0)
	# Alertes : cercles rouges clignotants
	var maintenant := GameClock.temps_ecoule
	_alertes = _alertes.filter(func(a) -> bool: return a[1] > maintenant)
	for a in _alertes:
		var pulsation := 6.0 + 4.0 * absf(sin(maintenant * 6.0))
		draw_arc(_vers_carte(a[0]), pulsation, 0.0, TAU, 20, Color(1.0, 0.2, 0.15), 2.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(TAILLE, TAILLE)), Color(0.9, 0.8, 0.6, 0.8), false, 2.0)


func _vers_carte(p: Vector3) -> Vector2:
	var d := GameRules.DEMI_CARTE
	return Vector2((p.x + d) / (2.0 * d), (p.z + d) / (2.0 * d)) * TAILLE


func _vers_monde(p: Vector2) -> Vector3:
	var d := GameRules.DEMI_CARTE
	return Vector3(p.x / TAILLE * 2.0 * d - d, 0.0, p.y / TAILLE * 2.0 * d - d)
