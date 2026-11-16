extends Node3D
## Caméra RTS en vue isométrique 2,5D (GDD §2) : caméra orthographique inclinée.
## Déplacement clavier (ZQSD/WASD, flèches) ou bord d'écran, zoom à la molette.

@export var vitesse := 30.0
@export var defilement_bord := true
@export var marge_bord := 10.0
@export var zoom_min := 18.0
@export var zoom_max := 70.0
@export var pas_zoom := 3.0
@export var limite := 55.0

@onready var camera: Camera3D = $Camera3D

# Axes de l'écran projetés au sol (caméra placée en +X +Z, regardant vers -X -Z).
const AVANT := Vector3(-0.70710678, 0.0, -0.70710678)
const DROITE := Vector3(0.70710678, 0.0, -0.70710678)


func _ready() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(40.0, 40.0, 40.0)   # angle isométrique « vrai » (35,26°)
	camera.look_at(global_position, Vector3.UP)


func _process(delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("camera_gauche", "camera_droite"),
		Input.get_axis("camera_bas", "camera_haut"))

	if defilement_bord and not DisplayServer.is_touchscreen_available() and DisplayServer.window_is_focused():
		var souris := get_viewport().get_mouse_position()
		var taille := get_viewport().get_visible_rect().size
		if souris.x <= marge_bord:
			dir.x = -1.0
		elif souris.x >= taille.x - marge_bord:
			dir.x = 1.0
		if souris.y <= marge_bord:
			dir.y = 1.0
		elif souris.y >= taille.y - marge_bord:
			dir.y = -1.0

	if dir != Vector2.ZERO:
		var facteur_zoom := camera.size / 40.0
		position += (DROITE * dir.x + AVANT * dir.y) * vitesse * facteur_zoom * delta
		position.x = clampf(position.x, -limite, limite)
		position.z = clampf(position.z, -limite, limite)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		camera.size = clampf(camera.size - pas_zoom, zoom_min, zoom_max)
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		camera.size = clampf(camera.size + pas_zoom, zoom_min, zoom_max)


## Déplacement au doigt : la carte suit le doigt (relatif en pixels d'écran).
func glisser(relatif: Vector2) -> void:
	var pixels := get_viewport().get_visible_rect().size.y
	var unites_par_pixel := camera.size / maxf(pixels, 1.0)
	# En isométrique, un pixel vertical couvre plus de sol qu'un pixel horizontal (1 / sin 35,26°).
	var deplacement := DROITE * relatif.x * unites_par_pixel - AVANT * relatif.y * unites_par_pixel * 1.732
	position -= deplacement
	position.x = clampf(position.x, -limite, limite)
	position.z = clampf(position.z, -limite, limite)


## Zoom par pincement : facteur > 1 = dézoomer.
func zoomer(facteur: float) -> void:
	camera.size = clampf(camera.size * facteur, zoom_min, zoom_max)


## Centre la caméra sur une position du monde.
func centrer_sur(pos: Vector3) -> void:
	position = Vector3(pos.x, 0.0, pos.z)
