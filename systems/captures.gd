extends Node
## Captures d'écran automatiques (CI) : `godot --path . -- --captures=<dossier>` joue un court scénario
## et enregistre des images PNG, puis quitte. Le joueur ne joue pas ; l'IA, si.
## Il faut un vrai rendu (pas --headless) : la CI utilise un écran virtuel (xvfb) et le rendu Compatibility.
## Outil de vérification seulement : sélection et caméra, aucune action de jeu.

const ACCELERATION := 8.0
const BASE_JOUEUR := Vector3(-35, 0, 35)
const BASE_IA := Vector3(35, 0, -35)

var dossier := "user://captures"
var _numero := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="):
			dossier = arg.trim_prefix("--captures=")
	if DisplayServer.get_name() == "headless":
		push_error("Captures impossibles sans rendu (--headless) : lancer avec un écran, même virtuel (xvfb).")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(dossier)
	print("[captures] dossier : ", ProjectSettings.globalize_path(dossier))
	_scenario.call_deferred()


func _scenario() -> void:
	var monde := get_parent()
	var rig = monde.get_node("CameraRig")
	var selection = monde.find_child("Selection", true, false)
	rig.defilement_bord = false   # la souris ne doit pas déplacer la caméra pendant le scénario
	# Rendu logiciel lent en CI : plus de pas de physique par image pour que l'accélération tienne.
	Engine.max_physics_steps_per_frame = 64

	await _attendre_temps_de_jeu(1.0)
	rig.centrer_sur(BASE_JOUEUR)
	await _capturer("depart")
	rig.centrer_sur(Vector3(-62, 0, 10))   # bord ouest : raccord entre la zone de jeu et le relief
	await _capturer("bordure_relief")
	rig.centrer_sur(BASE_JOUEUR)

	for b in get_tree().get_nodes_in_group("case_centrale"):
		if b.faction == GameRules.PLAYER:
			selection.selectionner_batiment(b)
	await _capturer("panneau_case_centrale")
	selection.annuler()

	# Nuit : elle commence à 65 % du premier cycle.
	Engine.time_scale = ACCELERATION
	await _attendre_temps_de_jeu(GameRules.DUREE_JOUR_S * (1.0 - GameRules.PART_NUIT) + 10.0)
	Engine.time_scale = 1.0
	selection.annuler()
	await _capturer("nuit")

	# Base de l'IA après 5 minutes, carte révélée (débogage).
	Engine.time_scale = ACCELERATION
	await _attendre_temps_de_jeu(300.0)
	Engine.time_scale = 1.0
	Vision.revele_tout = true
	selection.annuler()
	rig.centrer_sur(BASE_IA)
	await _attendre_images(10)
	await _capturer("base_ia_5min")

	rig.centrer_sur(Vector3.ZERO)
	rig.zoomer(rig.zoom_max / rig.camera.size)
	await _attendre_images(10)
	await _capturer("vue_ensemble_5min")

	print("[captures] %d images" % _numero)
	get_tree().quit()


func _attendre_temps_de_jeu(secondes: float) -> void:
	while GameClock.temps_ecoule < secondes:
		await get_tree().process_frame


func _attendre_images(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _capturer(nom: String) -> void:
	await _attendre_images(5)   # laisser l'interface et le brouillard se mettre à jour
	await RenderingServer.frame_post_draw
	_numero += 1
	var chemin := "%s/%02d_%s.png" % [dossier, _numero, nom]
	var erreur := get_viewport().get_texture().get_image().save_png(chemin)
	print("[captures] %s%s" % [chemin, "" if erreur == OK else " : ÉCHEC (%d)" % erreur])
