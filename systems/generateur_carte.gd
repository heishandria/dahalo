class_name GenerateurCarte
extends RefCounted
## Carte aléatoire à graine, façon « random map » d'Age of Empires (GDD §8).
## Équité : la carte est SYMÉTRIQUE PAR RAPPORT AU CENTRE. Tout ce qui est placé en p l'est aussi en -p,
## et la base de l'IA est l'image de celle du joueur. La même graine redonne exactement la même carte
## (indispensable pour le multijoueur en lockstep et pour rejouer une partie de test).
## Ne crée rien : renvoie une description (Dictionary) que main.gd transforme en entités.
## Spec : docs/specs/carte.md

const PAS_RIVIERE := 4.0
const CASE := 2.0                   # grille des plateaux (= grille du brouillard)
const N := 120                      # cases par côté ; le champ est donné aux (N + 1)² sommets
const MARGE_BORD := 8.0
const ESSAIS := 80

var _hasard := RandomNumberGenerator.new()
var _occupes: Array = []      # [Vector2 centre, rayon] : emplacements déjà pris
var _bases: Array = []        # Vector2 des deux bases
var _riviere := PackedVector2Array()
var _champ := PackedFloat32Array()   # champ des collines aux sommets de la grille (forme générale)
var _masque := PackedFloat32Array()  # 0 près des bases, de la rivière et des réservations (rien n'y pousse)
var _seuil := INF                    # seuil du champ : contour approximatif des collines
var _hauteurs := PackedFloat32Array()   # hauteur finale des collines aux sommets (après érosion)


## Description renvoyée :
##  graine, riviere (PackedVector2Array),
##  reperes : faction -> {base, avant, droite} (Vector3 ; avant = vers le centre de la carte),
##  arbres, points_eau, raketa, baobabs : Array de Vector3,
##  troupeaux : Array de [Vector3 centre, int nombre], migrations : Array de Vector3,
##  zones_test : Array de Vector3 (emplacements libres pour les duels du test de fumée),
##  plateaux : {hauteurs: PackedFloat32Array} — hauteur des collines aux (N+1)² sommets de la grille de 2 m.
func generer(graine: int) -> Dictionary:
	_hasard.seed = graine
	_occupes.clear()
	_champ = PackedFloat32Array()
	_masque = PackedFloat32Array()
	_hauteurs = PackedFloat32Array()
	_seuil = INF
	var carte := {"graine": graine, "arbres": [], "points_eau": [], "raketa": [], "baobabs": [],
			"troupeaux": [], "migrations": [], "zones_test": [], "reperes": {}}

	# Bases face à face, à un angle tiré au hasard.
	var angle := _hasard.randf() * TAU
	var axe := Vector2(cos(angle), sin(angle))       # du centre vers la base du joueur
	var travers := Vector2(-axe.y, axe.x)
	var base := axe * GameRules.CARTE_DISTANCE_BASES
	_bases = [base, -base]
	carte["reperes"][GameRules.PLAYER] = {"base": _v3(base), "avant": _v3(-axe), "droite": _v3(travers)}
	carte["reperes"][GameRules.AI] = {"base": _v3(-base), "avant": _v3(axe), "droite": _v3(-travers)}
	_occuper_paire(base, GameRules.CARTE_RAYON_BASE_LIBRE * 0.6)

	# Lit de rivière : il traverse toute la carte entre les deux bases. Fonction impaire = symétrique.
	var a1 := _hasard.randf_range(8.0, 16.0)
	var k1 := TAU / _hasard.randf_range(90.0, 140.0)
	var a2 := _hasard.randf_range(2.0, 6.0)
	var k2 := TAU / _hasard.randf_range(30.0, 50.0)
	_riviere = PackedVector2Array()
	var t := -400.0
	while t <= 400.0:
		_riviere.append(travers * t + axe * (a1 * sin(k1 * t) + a2 * sin(k2 * t)))
		t += PAS_RIVIERE
	carte["riviere"] = _riviere

	_kit_de_base(carte, axe, travers)

	# Duels du test de fumée : zones vides, loin des bases et de la rivière.
	for p in [travers * 70.0 + axe * 38.0, travers * -70.0 + axe * 38.0, travers * 25.0 + axe * 40.0]:
		_occuper_paire(p, 9.0)
		carte["zones_test"].append(_v3(p))

	# Trous d'eau creusés dans le sable du lit (pratique réelle dans l'Androy).
	for k in GameRules.RIVIERE_TROUS_EAU:
		for essai in ESSAIS:
			var s := _hasard.randf_range(20.0, 60.0)
			var p := travers * s + axe * (a1 * sin(k1 * s) + a2 * sin(k2 * s))
			if _dans_la_carte(p, 3.0) and _libre(p, 2.5):
				_occuper_paire(p, 2.5)
				_ajouter_paire(carte["points_eau"], p)
				break

	# Troupeaux sauvages : un au centre (dans le lit), puis une paire symétrique.
	var depart: Array = GameRules.ZEBUS_SAUVAGES_DEPART
	carte["troupeaux"].append([Vector3.ZERO, int(depart[0])])
	_occuper(Vector2.ZERO, 6.0)

	# Plateaux : après les bases, la rivière et les réservations, avant tout le reste (qui les évite).
	carte["plateaux"] = _plateaux(graine)
	# Les zébus paissent aussi sur les pentes douces : seules les collines infranchissables sont évitées.
	var p_troupeau := _placer_paire(6.0, 45.0, 6.0, GameRules.COLLINES_INFRANCHISSABLE)
	if p_troupeau != Vector2.INF:
		carte["troupeaux"].append([_v3(p_troupeau), int(depart[1])])
		carte["troupeaux"].append([_v3(-p_troupeau), int(depart[1])])
	else:
		push_warning("Carte : paire de troupeaux sauvages non placée (graine %d)" % graine)

	# Bosquets d'épineux neutres.
	for k in GameRules.CARTE_PAIRES_FORETS:
		var nombre := _hasard.randi_range(GameRules.CARTE_ARBRES_PAR_FORET.x, GameRules.CARTE_ARBRES_PAR_FORET.y)
		var rayon := 3.0 + nombre * 0.3
		var centre := _placer_paire(rayon, GameRules.CARTE_RAYON_BASE_LIBRE, 3.0)
		if centre != Vector2.INF:
			for arbre in _bosquet(centre, nombre, rayon):
				_ajouter_paire(carte["arbres"], arbre)

	for k in GameRules.CARTE_PAIRES_RAKETA:
		var p := _placer_paire(1.5, 22.0, 3.0)
		if p != Vector2.INF:
			_ajouter_paire(carte["raketa"], p)

	for k in GameRules.CARTE_PAIRES_BAOBABS:
		var p := _placer_paire(2.5, 25.0, 4.0)
		if p != Vector2.INF:
			_ajouter_paire(carte["baobabs"], p)

	# Points d'arrivée des migrations : le centre et des paires symétriques (lieux non réservés).
	carte["migrations"].append(Vector3.ZERO)
	for k in GameRules.CARTE_PAIRES_MIGRATION:
		for essai in ESSAIS:
			var p := _point_au_hasard(6.0)
			if _loin_des_bases(p, 45.0) and Terrain.distance_trace(p, _riviere) > 6.0 and not _sur_plateau(p, 6.0) \
					and not _sur_plateau(-p, 6.0):
				_ajouter_paire(carte["migrations"], p)
				break
	return carte


## Ressources propres à chaque base (bosquet, point d'eau, raketa), placées dans le repère de la base :
## même disposition pour les deux clans, à l'image l'une de l'autre.
func _kit_de_base(carte: Dictionary, axe: Vector2, travers: Vector2) -> void:
	var base: Vector2 = _bases[0]
	var avant := -axe
	var gauche := -travers
	var arriere := axe
	var foret := base + gauche * 15.0 + avant * 3.0
	for arbre in _bosquet(foret, 10, 6.0):
		_ajouter_paire(carte["arbres"], arbre)
	_occuper_paire(foret, 7.0)
	var eau := base + avant * 14.0 + travers * 4.0
	_ajouter_paire(carte["points_eau"], eau)
	_occuper_paire(eau, 3.0)
	for p in [base + gauche * 10.0 + arriere * 7.0, base + gauche * 13.0 + arriere * 11.0]:
		_ajouter_paire(carte["raketa"], p)
		_occuper_paire(p, 1.5)


# --- Plateaux en paliers ---

## Champ de bruit symétrique (même valeur en p et en -p), nul près des bases, de la rivière et des
## emplacements réservés. Plateau là où il dépasse un seuil choisi pour couvrir PLATEAUX_PART de la carte.
## On vérifie que les bases restent reliées entre elles et au centre ; sinon on réduit les plateaux.
func _plateaux(graine: int) -> Dictionary:
	var bruit := FastNoiseLite.new()
	bruit.seed = graine + 7
	bruit.frequency = 0.02
	bruit.fractal_octaves = 2
	var cotes := N + 1
	_champ.resize(cotes * cotes)
	_masque.resize(cotes * cotes)
	for j in cotes:
		for i in cotes:
			var p := _sommet(i, j)
			var n := maxf(bruit.get_noise_2d(p.x, p.y), bruit.get_noise_2d(-p.x, -p.y)) * 0.5 + 0.5
			_masque[j * cotes + i] = _masque_plateaux(p)
			_champ[j * cotes + i] = n * _masque[j * cotes + i]
	var tries := Array(_champ)
	tries.sort()
	var part := GameRules.PLATEAUX_PART
	for essai in 5:
		_seuil = maxf(float(tries[int((1.0 - part) * (tries.size() - 1))]), 0.05)
		if _bases_reliees():
			break
		part *= 0.6   # un plateau coupe la carte : on en met moins
		_seuil = INF
	_hauteurs.resize(cotes * cotes)
	_hauteurs.fill(0.0)
	if _seuil != INF:
		_supprimer_ilots(12)
		_former_collines(graine)
		_eroder(graine)
		_eboulements(25)
		_symetriser()
		if not _bases_reliees():
			push_warning("Collines : accès entre les bases coupé après l'érosion, collines retirées.")
			_hauteurs.fill(0.0)
	return {"hauteurs": _hauteurs}


# --- Collines : forme arrondie, puis érosion ---

## Forme de départ : la hauteur monte en douceur avec le champ (dôme arrondi), avec un peu de détail.
func _former_collines(graine: int) -> void:
	var detail := FastNoiseLite.new()
	detail.seed = graine + 9
	detail.frequency = 0.09
	detail.fractal_octaves = 3
	var c := N + 1
	for k in c * c:
		var forme := smoothstep(_seuil - 0.08, _seuil + 0.12, _champ[k])
		if forme <= 0.0:
			continue
		var p := _sommet(k % c, k / c)
		_hauteurs[k] = GameRules.COLLINES_HAUTEUR * pow(forme, 1.3) * (0.85 + 0.3 * detail.get_noise_2d(p.x, p.y))


## Érosion par gouttes de pluie (méthode classique « droplet erosion ») : chaque goutte descend la pente,
## arrache de la matière quand elle va vite et la dépose quand elle ralentit : ravines et cônes au pied.
## Unités : la grille (1 = une case de 2 m), hauteurs en mètres.
const EROSION_INERTIE := 0.05
const EROSION_CAPACITE := 3.0
const EROSION_CAPACITE_MIN := 0.01
const EROSION_DEPOT := 0.15
const EROSION_ARRACHAGE := 0.2
const EROSION_EVAPORATION := 0.03
const EROSION_GRAVITE := 4.0
const EROSION_ETAPES := 24


func _eroder(graine: int) -> void:
	var hasard := RandomNumberGenerator.new()
	hasard.seed = graine + 13
	var c := N + 1
	var departs: Array[int] = []
	for k in c * c:
		if _hauteurs[k] > 0.3:
			departs.append(k)
	if departs.is_empty():
		return
	for goutte in GameRules.COLLINES_GOUTTES:
		var depart: int = departs[hasard.randi() % departs.size()]
		var px := float(depart % c) + hasard.randf_range(-0.5, 0.5)
		var pz := float(depart / c) + hasard.randf_range(-0.5, 0.5)
		var dx := 0.0
		var dz := 0.0
		var vitesse := 1.0
		var eau := 1.0
		var sediment := 0.0
		for etape in EROSION_ETAPES:
			if px < 0.0 or pz < 0.0 or px >= c - 1 or pz >= c - 1:
				break
			var ici := _hauteur_et_pente(px, pz)
			dx = dx * EROSION_INERTIE - ici.y * (1.0 - EROSION_INERTIE)
			dz = dz * EROSION_INERTIE - ici.z * (1.0 - EROSION_INERTIE)
			var longueur := sqrt(dx * dx + dz * dz)
			if longueur < 0.000001:
				break   # cuvette plate : la goutte s'arrête
			dx /= longueur
			dz /= longueur
			var ancien_x := px
			var ancien_z := pz
			px += dx
			pz += dz
			if px < 0.0 or pz < 0.0 or px >= c - 1 or pz >= c - 1:
				break
			var denivele := _hauteur_et_pente(px, pz).x - ici.x
			var capacite := maxf(-denivele * vitesse * eau * EROSION_CAPACITE, EROSION_CAPACITE_MIN)
			if sediment > capacite or denivele > 0.0:
				var depot := minf(denivele, sediment) if denivele > 0.0 else (sediment - capacite) * EROSION_DEPOT
				sediment -= depot
				_modifier(ancien_x, ancien_z, depot)
			else:
				var arrache := minf((capacite - sediment) * EROSION_ARRACHAGE, -denivele)
				_modifier(ancien_x, ancien_z, -arrache)
				sediment += arrache
			vitesse = sqrt(maxf(0.0, vitesse * vitesse + denivele * EROSION_GRAVITE))
			eau *= 1.0 - EROSION_EVAPORATION


## Hauteur (x) et pente (y, z) interpolées en un point de la grille.
func _hauteur_et_pente(px: float, pz: float) -> Vector3:
	var c := N + 1
	var i := int(px)
	var j := int(pz)
	var fx := px - i
	var fz := pz - j
	var h00 := _hauteurs[j * c + i]
	var h10 := _hauteurs[j * c + i + 1]
	var h01 := _hauteurs[(j + 1) * c + i]
	var h11 := _hauteurs[(j + 1) * c + i + 1]
	var gx := (h10 - h00) * (1.0 - fz) + (h11 - h01) * fz
	var gz := (h01 - h00) * (1.0 - fx) + (h11 - h10) * fx
	var h := h00 * (1.0 - fx) * (1.0 - fz) + h10 * fx * (1.0 - fz) + h01 * (1.0 - fx) * fz + h11 * fx * fz
	return Vector3(h, gx, gz)


## Ajoute (ou retire) de la matière autour d'un point, répartie sur les 4 sommets voisins ; jamais sous le sol.
func _modifier(px: float, pz: float, quantite: float) -> void:
	var c := N + 1
	var i := int(px)
	var j := int(pz)
	var fx := px - i
	var fz := pz - j
	var poids := [(1.0 - fx) * (1.0 - fz), fx * (1.0 - fz), (1.0 - fx) * fz, fx * fz]
	var sommets := [j * c + i, j * c + i + 1, (j + 1) * c + i, (j + 1) * c + i + 1]
	for n in 4:
		var k: int = sommets[n]
		_hauteurs[k] = maxf(0.0, _hauteurs[k] + quantite * float(poids[n]))


## Éboulement : là où la pente dépasse COLLINES_PENTE_MAX, la matière glisse vers le bas (formes arrondies).
func _eboulements(passes: int) -> void:
	var c := N + 1
	var ecart_max := GameRules.COLLINES_PENTE_MAX * CASE
	for passe in passes:
		for j in range(1, c - 1):
			for i in range(1, c - 1):
				var k := j * c + i
				if _hauteurs[k] <= 0.01:
					continue
				for voisin in [k + 1, k - 1, k + c, k - c]:
					var ecart: float = _hauteurs[k] - _hauteurs[voisin]
					if ecart > ecart_max:
						var glisse := (ecart - ecart_max) * 0.25
						_hauteurs[k] -= glisse
						_hauteurs[voisin] += glisse
	# Rien près des bases, de la rivière et des emplacements réservés (dépôts de l'érosion compris).
	for k in c * c:
		_hauteurs[k] *= smoothstep(0.0, 0.3, _masque[k])


## Carte symétrique par rapport au centre : le sommet (i, j) et son image (N - i, N - j) prennent la moyenne.
func _symetriser() -> void:
	var total := (N + 1) * (N + 1)
	for k in total / 2 + 1:
		var moyenne := (_hauteurs[k] + _hauteurs[total - 1 - k]) * 0.5
		_hauteurs[k] = moyenne
		_hauteurs[total - 1 - k] = moyenne


func _masque_plateaux(p: Vector2) -> float:
	var m := 1.0
	for b in _bases:
		m *= smoothstep(GameRules.PLATEAUX_DISTANCE_BASES, GameRules.PLATEAUX_DISTANCE_BASES + 12.0, p.distance_to(b))
	var d_riviere := Terrain.distance_trace(p, _riviere) - GameRules.RIVIERE_LARGEUR * 0.5
	m *= smoothstep(6.0, 14.0, d_riviere)
	for o in _occupes:
		var r: float = o[1]
		m *= smoothstep(r + 3.0, r + 9.0, p.distance_to(o[0]))
	return m


func _sommet(i: int, j: int) -> Vector2:
	return Vector2(-GameRules.DEMI_CARTE + i * CASE, -GameRules.DEMI_CARTE + j * CASE)


## Champ des plateaux en un point (interpolé).
func _valeur(p: Vector2) -> float:
	var fx := clampf((p.x + GameRules.DEMI_CARTE) / CASE, 0.0, N - 0.001)
	var fz := clampf((p.y + GameRules.DEMI_CARTE) / CASE, 0.0, N - 0.001)
	var i := int(fx)
	var j := int(fz)
	var c := N + 1
	var haut := lerpf(_champ[j * c + i], _champ[j * c + i + 1], fx - i)
	var bas := lerpf(_champ[(j + 1) * c + i], _champ[(j + 1) * c + i + 1], fx - i)
	return lerpf(haut, bas, fz - j)


func _sur_plateau(p: Vector2, rayon: float, hauteur_max: float = 0.15) -> bool:
	if _hauteurs.is_empty():
		return false
	if _hauteur_en(p) > hauteur_max:
		return true
	for k in 8:
		var a := TAU * k / 8.0
		if _hauteur_en(p + Vector2(cos(a), sin(a)) * (rayon + 1.5)) > hauteur_max:
			return true
	return false


func _hauteur_en(p: Vector2) -> float:
	var px := clampf((p.x + GameRules.DEMI_CARTE) / CASE, 0.0, N - 0.001)
	var pz := clampf((p.y + GameRules.DEMI_CARTE) / CASE, 0.0, N - 0.001)
	return _hauteur_et_pente(px, pz).x


## Abaisse sous le seuil les plateaux de moins de `minimum` cases (îlots et rubans fins, peu lisibles).
func _supprimer_ilots(minimum: int) -> void:
	var c := N + 1
	var vu := PackedByteArray()
	vu.resize(c * c)
	for depart in c * c:
		if vu[depart] == 1 or _champ[depart] <= _seuil:
			continue
		var groupe: Array[int] = [depart]
		var file: Array[int] = [depart]
		vu[depart] = 1
		while not file.is_empty():
			var k: int = file.pop_back()
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var i: int = k % c + v.x
				var j: int = k / c + v.y
				if i < 0 or j < 0 or i >= c or j >= c:
					continue
				var k2 := j * c + i
				if vu[k2] == 0 and _champ[k2] > _seuil:
					vu[k2] = 1
					file.append(k2)
					groupe.append(k2)
		if groupe.size() < minimum:
			for k in groupe:
				_champ[k] = _seuil * 0.9


## Parcours des cases libres depuis la base du joueur : l'IA et le centre doivent être atteignables
## (par symétrie, la base de l'IA rejoint alors aussi le centre et le joueur).
func _bases_reliees() -> bool:
	var libre := PackedByteArray()
	libre.resize(N * N)
	for j in N:
		for i in N:
			var centre := _sommet(i, j) + Vector2(CASE, CASE) * 0.5
			var bloquee := _hauteur_en(centre) > GameRules.COLLINES_INFRANCHISSABLE if not _hauteurs.is_empty() \
					else _valeur(centre) > _seuil
			libre[j * N + i] = 0 if bloquee else 1
	var depart := _case(_bases[0])
	var vu := PackedByteArray()
	vu.resize(N * N)
	var file: Array[int] = [depart]
	vu[depart] = 1
	while not file.is_empty():
		var c: int = file.pop_back()
		var i := c % N
		var j := c / N
		for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ni: int = i + v.x
			var nj: int = j + v.y
			if ni < 0 or nj < 0 or ni >= N or nj >= N:
				continue
			var k := nj * N + ni
			if vu[k] == 0 and libre[k] == 1:
				vu[k] = 1
				file.append(k)
	return vu[_case(_bases[1])] == 1 and vu[_case(Vector2.ZERO)] == 1


func _case(p: Vector2) -> int:
	var i := clampi(int((p.x + GameRules.DEMI_CARTE) / CASE), 0, N - 1)
	var j := clampi(int((p.y + GameRules.DEMI_CARTE) / CASE), 0, N - 1)
	return j * N + i


## Arbres d'un bosquet, répartis en anneaux autour du centre (coordonnées monde).
func _bosquet(centre: Vector2, nombre: int, rayon: float) -> Array:
	var arbres: Array = []
	for i in nombre:
		var a := TAU * i / float(nombre) + _hasard.randf_range(-0.3, 0.3)
		var d := rayon * (0.3 + 0.7 * float(i % 3) / 2.0) * _hasard.randf_range(0.8, 1.0)
		arbres.append(centre + Vector2(cos(a), sin(a)) * d)
	return arbres


## Trouve p tel que p et -p soient libres ; les réserve. Vector2.INF si rien trouvé.
func _placer_paire(rayon: float, distance_bases: float, distance_riviere: float,
		hauteur_max: float = 0.15) -> Vector2:
	for essai in ESSAIS:
		var p := _point_au_hasard(rayon + MARGE_BORD)
		if p.length() < rayon + 4.0:
			continue  # p et -p se chevaucheraient
		if not _loin_des_bases(p, distance_bases + rayon):
			continue
		if Terrain.distance_trace(p, _riviere) < GameRules.RIVIERE_LARGEUR * 0.5 + distance_riviere + rayon:
			continue
		if _sur_plateau(p, rayon, hauteur_max) or _sur_plateau(-p, rayon, hauteur_max):
			continue
		if _libre(p, rayon):
			_occuper_paire(p, rayon)
			return p
	return Vector2.INF


func _point_au_hasard(marge: float) -> Vector2:
	var limite := GameRules.DEMI_CARTE - marge
	return Vector2(_hasard.randf_range(-limite, limite), _hasard.randf_range(-limite, limite))


func _dans_la_carte(p: Vector2, marge: float) -> bool:
	var limite := GameRules.DEMI_CARTE - MARGE_BORD - marge
	return absf(p.x) <= limite and absf(p.y) <= limite


func _loin_des_bases(p: Vector2, distance: float) -> bool:
	for b in _bases:
		if p.distance_to(b) < distance or (-p).distance_to(b) < distance:
			return false
	return true


## Vrai si p ET -p sont libres.
func _libre(p: Vector2, rayon: float) -> bool:
	for o in _occupes:
		var c: Vector2 = o[0]
		var r: float = o[1]
		if p.distance_to(c) < rayon + r + 3.0 or (-p).distance_to(c) < rayon + r + 3.0:
			return false
	return true


func _occuper(p: Vector2, rayon: float) -> void:
	_occupes.append([p, rayon])


func _occuper_paire(p: Vector2, rayon: float) -> void:
	_occuper(p, rayon)
	_occuper(-p, rayon)


func _ajouter_paire(liste: Array, p: Vector2) -> void:
	liste.append(_v3(p))
	liste.append(_v3(-p))


func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)
