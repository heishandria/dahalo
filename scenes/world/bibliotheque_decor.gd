class_name BibliothequeDecor
extends RefCounted
## Modèles de décor issus des packs CC0 (voir assets/models/decor/LISEZMOI.md).
## Charge un glTF importé et renvoie son maillage, avec les matériaux de chaque surface, prêt pour un MultiMesh.
## Renvoie null si le modèle manque : l'appelant garde alors ses formes générées par le code.

const DOSSIER := "res://assets/models/decor/quaternius_megakit/"
# Textures remplacées au chargement : le feuillage rouge automnal du pack n'a rien à faire dans l'Androy.
const SUBSTITUTIONS := {"Leaves_TwistedTree_C.png": "Leaves_NormalTree_C.png"}

static var _cache := {}


static func maillage(nom: String) -> Mesh:
	if _cache.has(nom):
		return _cache[nom]
	var resultat: Mesh = null
	var chemin := DOSSIER + nom + ".gltf"
	if ResourceLoader.exists(chemin):
		var scene := load(chemin) as PackedScene
		if scene != null:
			var racine := scene.instantiate()
			var instances := racine.find_children("*", "MeshInstance3D", true, false)
			if not instances.is_empty():
				var mi := instances[0] as MeshInstance3D
				var copie := mi.mesh.duplicate() as Mesh
				for s in copie.get_surface_count():
					copie.surface_set_material(s, _substituer(mi.get_active_material(s)))
				resultat = copie
			racine.free()
	_cache[nom] = resultat
	return resultat


static func _substituer(materiau: Material) -> Material:
	var base := materiau as BaseMaterial3D
	if base == null or base.albedo_texture == null:
		return materiau
	var fichier := base.albedo_texture.resource_path.get_file()
	if not SUBSTITUTIONS.has(fichier):
		return materiau
	var copie := base.duplicate() as BaseMaterial3D
	copie.albedo_texture = load(DOSSIER + String(SUBSTITUTIONS[fichier]))
	return copie


## Tous les modèles de la liste qui existent (dans l'ordre) ; vide si aucun.
static func maillages(noms: Array) -> Array[Mesh]:
	var liste: Array[Mesh] = []
	for nom in noms:
		var m := maillage(nom)
		if m != null:
			liste.append(m)
	return liste


## Réduit les détails sur le Web et le mobile (moins d'instances : les modèles des packs sont plus lourds).
static func facteur_densite() -> float:
	return 0.35 if OS.has_feature("web") or OS.has_feature("mobile") else 1.0
