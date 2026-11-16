extends Node3D
## Affichage du brouillard pour le joueur : voile sur le sol + masquage des objets non vus.
## - unités et zébus adverses ou sauvages : visibles seulement s'ils sont dans le champ de vision ;
## - bâtiments, champs, ressources, décor : visibles une fois la zone explorée (dernière image connue) ;
## - traces des voleurs : visibles si un Pisteur du clan volé passe à proximité.

const HAUTEUR_VOILE := 0.2

var _image: Image
var _texture: ImageTexture
var _octets := PackedByteArray()


func _ready() -> void:
	var n := Vision.N
	_octets.resize(n * n * 2)
	_image = Image.create_from_data(n, n, false, Image.FORMAT_RG8, _octets)
	_texture = ImageTexture.create_from_image(_image)

	var voile := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(GameRules.DEMI_CARTE * 2.0, GameRules.DEMI_CARTE * 2.0)
	voile.mesh = plan
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://systems/brouillard.gdshader")
	mat.set_shader_parameter("carte_vision", _texture)
	mat.set_shader_parameter("demi_carte", GameRules.DEMI_CARTE)
	voile.material_override = mat
	voile.position.y = HAUTEUR_VOILE
	voile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(voile)

	EventBus.vision_maj.connect(_maj)


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event.is_action_pressed("reveler_carte"):
		Vision.revele_tout = not Vision.revele_tout
		EventBus.message.emit("Carte révélée (débogage)." if Vision.revele_tout else "Brouillard rétabli.")


func _maj() -> void:
	var f := GameRules.PLAYER
	_maj_texture(f)

	for u in get_tree().get_nodes_in_group("unites"):
		if u.faction != f:
			u.visible = Vision.est_visible(f, u.global_position)
	for z in get_tree().get_nodes_in_group("zebus"):
		z.visible = z.proprietaire == f or Vision.est_visible(f, z.global_position)
	for groupe in ["ressources", "batiments", "decor"]:
		for n in get_tree().get_nodes_in_group(groupe):
			if n.get("faction") != f:
				n.visible = Vision.est_explore(f, n.global_position)
	for t in get_tree().get_nodes_in_group("traces"):
		t.maj_lecture(f)


func _maj_texture(f: int) -> void:
	var n := Vision.N
	var tout := Vision.revele_tout
	var vu: PackedByteArray = Vision.vu[f]
	var explore: PackedByteArray = Vision.explore[f]
	for i in n * n:
		_octets[i * 2] = 255 if (tout or vu[i] == 1) else 0
		_octets[i * 2 + 1] = 255 if (tout or explore[i] == 1) else 0
	_image.set_data(n, n, false, Image.FORMAT_RG8, _octets)
	_texture.update(_image)
