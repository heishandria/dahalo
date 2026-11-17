extends Node
## Terrain de la partie : graine de la carte et lit de rivière à sec.
## Garde la distance au lit en tout point (grille), pour le jeu (ralentissement dans le sable),
## le rendu (shader du sol) et le relief (vallée de la rivière). Rempli par le générateur de carte.
## Spec : docs/specs/carte.md

const ETENDUE := GameRules.DEMI_CARTE + 160.0   # couvre aussi le relief autour de la zone de jeu
const CASE := 2.0
const N := 280                                  # = 2 × ETENDUE / CASE
const DISTANCE_MAX := 32.0                      # au-delà, la distance n'est pas utile (et vaut DISTANCE_MAX)

var graine := 0
var riviere := PackedVector2Array()             # tracé du lit (points dans le plan XZ)
var _distances := PackedFloat32Array()
var _texture: ImageTexture


func initialiser(nouvelle_graine: int, trace: PackedVector2Array) -> void:
	assert(N == int(2.0 * ETENDUE / CASE), "Terrain.N doit valoir 2 × ETENDUE / CASE")
	graine = nouvelle_graine
	riviere = trace
	_distances.resize(N * N)
	_distances.fill(DISTANCE_MAX)
	# Pour chaque segment, on ne met à jour que les cases proches : rapide même avec un long tracé.
	for k in trace.size() - 1:
		var a := trace[k]
		var b := trace[k + 1]
		if maxf(absf(a.x), absf(b.x)) > ETENDUE + DISTANCE_MAX or maxf(absf(a.y), absf(b.y)) > ETENDUE + DISTANCE_MAX:
			continue  # segment hors de la grille
		var i_min := _indice_axe(minf(a.x, b.x) - DISTANCE_MAX)
		var i_max := _indice_axe(maxf(a.x, b.x) + DISTANCE_MAX)
		var j_min := _indice_axe(minf(a.y, b.y) - DISTANCE_MAX)
		var j_max := _indice_axe(maxf(a.y, b.y) + DISTANCE_MAX)
		for j in range(j_min, j_max + 1):
			for i in range(i_min, i_max + 1):
				var p := Vector2(-ETENDUE + (i + 0.5) * CASE, -ETENDUE + (j + 0.5) * CASE)
				var d := distance_segment(p, a, b)
				var c := j * N + i
				if d < _distances[c]:
					_distances[c] = d
	_texture = null


## Distance (m) au milieu du lit, interpolée entre les cases ; DISTANCE_MAX au plus.
func distance_riviere(pos: Vector3) -> float:
	if _distances.is_empty():
		return DISTANCE_MAX
	var fx := clampf((pos.x + ETENDUE) / CASE - 0.5, 0.0, N - 1.001)
	var fz := clampf((pos.z + ETENDUE) / CASE - 0.5, 0.0, N - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var haut := lerpf(_distances[j * N + i], _distances[j * N + i + 1], tx)
	var bas := lerpf(_distances[(j + 1) * N + i], _distances[(j + 1) * N + i + 1], tx)
	return lerpf(haut, bas, tz)


func dans_riviere(pos: Vector3) -> bool:
	return distance_riviere(pos) <= GameRules.RIVIERE_LARGEUR * 0.5


## Multiplicateur de vitesse au sol à cet endroit (sable du lit : plus lent).
func facteur_vitesse(pos: Vector3) -> float:
	return GameRules.RIVIERE_RALENTISSEMENT if dans_riviere(pos) else 1.0


## Distances en texture (rouge = distance / DISTANCE_MAX), pour le shader du sol et du relief.
func texture_distances() -> ImageTexture:
	if _texture == null:
		var octets := PackedByteArray()
		octets.resize(N * N)
		for c in N * N:
			octets[c] = int(clampf(_distances[c] / DISTANCE_MAX, 0.0, 1.0) * 255.0) if not _distances.is_empty() else 255
		_texture = ImageTexture.create_from_image(Image.create_from_data(N, N, false, Image.FORMAT_R8, octets))
	return _texture


static func distance_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Distance d'un point au tracé complet (calcul exact, pour le générateur).
static func distance_trace(p: Vector2, trace: PackedVector2Array) -> float:
	var d := INF
	for k in trace.size() - 1:
		d = minf(d, distance_segment(p, trace[k], trace[k + 1]))
	return d


func _indice_axe(v: float) -> int:
	return clampi(int((v + ETENDUE) / CASE), 0, N - 1)
