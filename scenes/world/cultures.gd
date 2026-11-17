class_name Cultures
extends RefCounted
## Plants des champs, modélisés par le code (cultures du Sud : maïs et sorgho).
## Un maillage par espèce et par stade : « vert » (en culture), « mur » (sec, épis ou têtes de grains),
## « chaume » (tiges coupées d'un champ en friche). Couleurs par sommet ; le champ fait grandir les plants
## en changeant l'échelle verticale du MultiMesh (voir scenes/world/champ.gd).

static var _cache := {}
static var _materiau: StandardMaterial3D


static func plante(espece: String, stade: String) -> Mesh:
	var cle := espece + "_" + stade
	if _cache.has(cle):
		return _cache[cle]
	if _materiau == null:
		_materiau = StandardMaterial3D.new()
		_materiau.vertex_color_use_as_albedo = true
		_materiau.vertex_color_is_srgb = true
		_materiau.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materiau.roughness = 0.85
	var h := RandomNumberGenerator.new()
	h.seed = hash(cle)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mais := espece == "mais"
	if stade == "chaume":
		for k in 3:
			var pied := Vector3(h.randf_range(-0.06, 0.06), 0, h.randf_range(-0.06, 0.06))
			_tige(st, pied, pied + Vector3(h.randf_range(-0.04, 0.04), h.randf_range(0.15, 0.35), h.randf_range(-0.04, 0.04)),
					0.018, Color(0.72, 0.62, 0.44))
	else:
		var mur := stade == "mur"
		var hauteur := 2.0 if mais else 1.7
		var vert_tige := Color(0.38, 0.52, 0.22)
		var sec := Color(0.78, 0.66, 0.44)
		var couleur_tige := sec * 0.9 if mur else vert_tige
		var sommet := Vector3(h.randf_range(-0.05, 0.05), hauteur, h.randf_range(-0.05, 0.05))
		_tige(st, Vector3.ZERO, sommet, 0.022 if mais else 0.016, couleur_tige)
		# Feuilles : longues lanières arquées qui partent de la tige et retombent.
		var nb := 8 if mais else 7
		for k in nb:
			var y := hauteur * (0.12 + 0.75 * float(k) / nb)
			var angle := k * 2.4 + h.randf_range(-0.3, 0.3)
			var longueur := (0.75 if mais else 0.6) * (1.0 - 0.35 * float(k) / nb) * h.randf_range(0.85, 1.1)
			var largeur := 0.075 if mais else 0.045
			var couleur := sec * h.randf_range(0.8, 1.05) if mur else Color(0.34, 0.5, 0.18) * h.randf_range(0.85, 1.12)
			if mur and h.randf() < 0.3:
				couleur = Color(0.55, 0.5, 0.32)   # quelques feuilles encore un peu vertes
			_feuille(st, sommet * (y / hauteur), angle, longueur, largeur, couleur, mur, h)
		if mur:
			if mais:
				# Épis enveloppés dans leurs spathes, et panicule au sommet.
				for k in h.randi_range(1, 2):
					var y := hauteur * h.randf_range(0.45, 0.6)
					var a := h.randf() * TAU
					var depart := sommet * (y / hauteur)
					var dir := Vector3(cos(a) * 0.45, 1.0, sin(a) * 0.45).normalized()
					_fuseau(st, depart + dir * 0.04, depart + dir * 0.26, 0.045, Color(0.86, 0.76, 0.52))
				for k in 5:
					var a := TAU * k / 5.0
					_tige(st, sommet, sommet + Vector3(cos(a) * 0.12, 0.2, sin(a) * 0.12), 0.006, Color(0.75, 0.6, 0.38))
			else:
				# Tête de grains du sorgho, brun-rouge, un peu penchée.
				var tete := sommet + Vector3(0.05, 0.05, 0.0)
				_fuseau(st, tete, tete + Vector3(0.08, 0.32, 0.03), 0.075, Color(0.55, 0.26, 0.16))
	st.generate_normals()
	var m := st.commit()
	m.surface_set_material(0, _materiau)
	_cache[cle] = m
	return m


static func _tige(st: SurfaceTool, a: Vector3, b: Vector3, rayon: float, couleur: Color) -> void:
	var axe := (b - a).normalized()
	var x := axe.cross(Vector3.FORWARD).normalized()
	var z := axe.cross(x)
	for s in 5:
		var a0 := TAU * s / 5.0
		var a1 := TAU * (s + 1) / 5.0
		var p := [a + (x * cos(a0) + z * sin(a0)) * rayon, a + (x * cos(a1) + z * sin(a1)) * rayon,
				b + (x * cos(a1) + z * sin(a1)) * rayon * 0.6, b + (x * cos(a0) + z * sin(a0)) * rayon * 0.6]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(couleur * (0.85 if i < 2 else 1.05))
			st.add_vertex(p[i])


## Feuille : lanière en 4 tronçons, qui monte puis retombe en s'effilant (plus tombante et tordue si sèche).
static func _feuille(st: SurfaceTool, depart: Vector3, angle: float, longueur: float, largeur: float, couleur: Color,
		seche: bool, h: RandomNumberGenerator) -> void:
	var dehors := Vector3(cos(angle), 0, sin(angle))
	var cote := Vector3(-dehors.z, 0, dehors.x)
	var points: Array[Vector3] = []
	var n := 4
	for k in n + 1:
		var t := float(k) / n
		var montee := 0.35 * sin(t * PI * 0.7) - (0.55 if seche else 0.3) * t * t
		points.append(depart + dehors * longueur * t + Vector3(0, montee * longueur, 0) + cote * h.randf_range(-0.02, 0.02))
	for k in n:
		var l0 := largeur * (1.0 - float(k) / n)
		var l1 := largeur * (1.0 - float(k + 1) / n)
		var p := [points[k] - cote * l0, points[k] + cote * l0, points[k + 1] + cote * l1, points[k + 1] - cote * l1]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_color(couleur * (0.8 + 0.25 * float(k) / n))
			st.add_vertex(p[i])


## Fuseau (épi, tête de grains) : forme renflée au milieu.
static func _fuseau(st: SurfaceTool, a: Vector3, b: Vector3, rayon: float, couleur: Color) -> void:
	var axe := (b - a).normalized()
	var x := axe.cross(Vector3.FORWARD).normalized()
	var z := axe.cross(x)
	var anneaux := [0.0, 0.25, 0.6, 1.0]
	var rayons := [0.3, 1.0, 0.9, 0.2]
	for j in 3:
		for s in 6:
			var a0 := TAU * s / 6.0
			var a1 := TAU * (s + 1) / 6.0
			var c0: Vector3 = a.lerp(b, anneaux[j])
			var c1: Vector3 = a.lerp(b, anneaux[j + 1])
			var r0: float = rayon * rayons[j]
			var r1: float = rayon * rayons[j + 1]
			var p := [c0 + (x * cos(a0) + z * sin(a0)) * r0, c0 + (x * cos(a1) + z * sin(a1)) * r0,
					c1 + (x * cos(a1) + z * sin(a1)) * r1, c1 + (x * cos(a0) + z * sin(a0)) * r1]
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_color(couleur * (0.85 + 0.15 * float(j)))
				st.add_vertex(p[i])
