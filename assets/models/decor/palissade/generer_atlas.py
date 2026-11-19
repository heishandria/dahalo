# Atlas 1024 px de la palissade épineuse, dessiné par script (Pillow seul, sans photo) : aucune licence tierce.
#
#   python3 generer_atlas.py SORTIE.png [--graine 7]
#
# Disposition (ligne 0 de l'image = v 1 en UV) — chaque tuile alpha garde une marge transparente sur tout son
# pourtour : les bouts de rameaux finissent naturellement, jamais coupés net au bord d'une carte.
#   lignes   0–255 (v 0,75–1)    : FAGOT  — 2 tuiles 512 × 256 de branches épineuses couchées (alpha, découpe)
#   lignes 256–511 (v 0,50–0,75) : CRÊTE  — 2 tuiles 512 × 256 de rameaux dressés, pied en bas (alpha, découpe)
#   lignes 512–767 (v 0,25–0,50) : ÉCORCE grise délavée, fil le long de u, pied poussiéreux à u = 0 (opaque)
#   lignes 768–1023 (v 0–0,25)   : u 0–0,5 MASSE de branchages serrés (opaque, plus sombre vers v = 0) ;
#                                  u 0,5–0,75 RAQUETTE de raketa ; u 0,75–1 ÉTOFFE (bannière, recolorée en jeu)
# Sous les zones transparentes, la couleur reste celle du bois : pas de liseré sombre avec les mipmaps.
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageChops

args = sys.argv[1:]
if not args:
	print("usage : generer_atlas.py SORTIE.png [--graine N]")
	sys.exit(2)
SORTIE = args[0]
GRAINE = int(args[args.index("--graine") + 1]) if "--graine" in args else 7
random.seed(GRAINE)

TAILLE = 1024
S = 4                       # suréchantillonnage
T = TAILLE * S
BANDE = 256 * S

BOIS_FONCE = (52, 45, 40)
BOIS = (92, 82, 72)
BOIS_CLAIR = (138, 127, 112)
EPINE = (172, 161, 140)
FEUILLE = (92, 100, 56)
FOND_BOIS = (100, 90, 80)    # couleur sous les zones transparentes


def melange(a, b, t):
	return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def varier(c, amplitude=10):
	d = random.randint(-amplitude, amplitude)
	return tuple(max(0, min(255, c[i] + d + random.randint(-3, 3))) for i in range(3))


class Calque:
	"""Tuile de dessin : couleur + couverture, avec une marge où les branches s'arrêtent."""

	def __init__(self, largeur, hauteur, marge, fond=FOND_BOIS, opaque=False):
		self.l, self.h, self.marge = largeur, hauteur, marge
		self.couleur = Image.new("RGB", (largeur, hauteur), fond)
		self.alpha = Image.new("L", (largeur, hauteur), 255 if opaque else 0)
		self.dc = ImageDraw.Draw(self.couleur)
		self.da = ImageDraw.Draw(self.alpha)

	def dedans(self, x, y):
		m = self.marge
		return m <= x <= self.l - m and m <= y <= self.h - m

	def trait(self, x0, y0, x1, y1, largeur, teinte):
		l = max(1, int(largeur))
		self.dc.line([(x0, y0), (x1, y1)], fill=teinte, width=l)
		self.da.line([(x0, y0), (x1, y1)], fill=255, width=l)
		r = l / 2
		for (x, y) in ((x0, y0), (x1, y1)):
			self.dc.ellipse([x - r, y - r, x + r, y + r], fill=teinte)
			self.da.ellipse([x - r, y - r, x + r, y + r], fill=255)

	def polygone(self, points, teinte):
		self.dc.polygon(points, fill=teinte)
		self.da.polygon(points, fill=255)


def epine(c, x, y, angle, longueur, base, teinte):
	px, py = -math.sin(angle), math.cos(angle)
	pointe = (x + math.cos(angle) * longueur, y + math.sin(angle) * longueur)
	c.polygone([(x + px * base / 2, y + py * base / 2), (x - px * base / 2, y - py * base / 2), pointe], teinte)


def feuille(c, x, y, angle, l):
	px, py = -math.sin(angle), math.cos(angle)
	ca, sa = math.cos(angle), math.sin(angle)
	c.polygone([(x, y), (x + ca * l * 0.5 + px * l * 0.22, y + sa * l * 0.5 + py * l * 0.22), (x + ca * l, y + sa * l),
		(x + ca * l * 0.5 - px * l * 0.22, y + sa * l * 0.5 - py * l * 0.22)], varier(FEUILLE, 12))


def branche(c, x, y, angle, longueur, largeur, teinte, profondeur, feuilles=0.0, courbure=0.18, pas=7):
	"""Branche tordue récursive, garnie d'épines ; s'arrête à la marge de la tuile (bout naturel)."""
	l_pas = longueur / pas
	for i in range(pas):
		angle += random.uniform(-courbure, courbure)
		nx, ny = x + math.cos(angle) * l_pas, y + math.sin(angle) * l_pas
		if not c.dedans(nx, ny):
			return
		w = largeur * (1.0 - 0.65 * i / pas)
		c.trait(x, y, nx, ny, w, teinte)
		for _ in range(2):
			t = random.random()
			ex, ey = x + (nx - x) * t, y + (ny - y) * t
			a = angle + random.choice((-1, 1)) * random.uniform(0.6, 1.2)
			epine(c, ex, ey, a, w * random.uniform(1.4, 2.2) + 5 * S, max(2 * S, w * 0.55), melange(teinte, EPINE, 0.3))
		if feuilles and random.random() < feuilles:
			feuille(c, nx, ny, angle + random.uniform(-1.2, 1.2), random.uniform(7, 12) * S)
		if profondeur > 0 and random.random() < 0.42:
			branche(c, nx, ny, angle + random.choice((-1, 1)) * random.uniform(0.35, 0.9),
				longueur * random.uniform(0.3, 0.55), w * 0.75, varier(teinte, 6), profondeur - 1, feuilles, courbure)
		x, y = nx, ny


def tuile_fagot():
	c = Calque(T // 2, BANDE, marge=6 * S)
	L, H = c.l, c.h
	for couche in range(3):                                  # du fond (sombre) vers l'avant (plus clair)
		base = melange(BOIS_FONCE, BOIS_CLAIR, couche / 2.0)
		for _ in range(8 + couche * 2):
			y = random.uniform(H * 0.3, H * 0.75)
			gauche = random.random() < 0.5
			x = random.uniform(0.04, 0.3) * L if gauche else random.uniform(0.7, 0.96) * L
			angle = (0.0 if gauche else math.pi) + random.uniform(-0.25, 0.25)
			branche(c, x, y, angle, random.uniform(0.5, 0.9) * L, random.uniform(8, 13) * S, varier(base, 10), 2)
		for _ in range(8):                                   # rameaux qui s'échappent : bord déchiqueté
			x = random.uniform(0.1, 0.9) * L
			y = random.uniform(H * 0.4, H * 0.6)
			haut = random.random() < 0.65
			angle = (-math.pi / 2 if haut else math.pi / 2) + random.uniform(-0.9, 0.9)
			branche(c, x, y, angle, random.uniform(0.25, 0.45) * H, random.uniform(4, 6) * S, varier(base, 10), 1)
	return c


def tuile_crete():
	"""Touffe en éventail : rameaux partant du bas-centre, plus hauts au milieu, silhouette déchiquetée."""
	c = Calque(T // 2, BANDE, marge=6 * S)
	L, H = c.l, c.h
	for couche in range(3):
		base = melange(BOIS_FONCE, BOIS_CLAIR, couche / 2.0)
		for _ in range(9 + couche * 3):
			x = L * 0.5 + random.uniform(-0.18, 0.18) * L
			y = H - c.marge - random.uniform(1, H * 0.08)
			ecart = random.uniform(-1.0, 1.0)
			angle = -math.pi / 2 + ecart * 1.05
			longueur = (1.05 - 0.45 * abs(ecart)) * random.uniform(0.75, 1.0) * H
			branche(c, x, y, angle, longueur, random.uniform(8, 12) * S, varier(base, 10), 2,
				feuilles=0.12 if couche == 2 else 0.04, courbure=0.2)
	for _ in range(8):                                       # pied bourré : pas de jour au ras de la masse
		x = L * 0.5 + random.uniform(-0.25, 0.25) * L
		y = H - c.marge - random.uniform(1, H * 0.1)
		angle = random.choice((0.0, math.pi)) + random.uniform(-0.35, 0.35)
		branche(c, x, y, angle, random.uniform(0.2, 0.35) * L, random.uniform(8, 11) * S, varier(BOIS_FONCE, 8), 1)
	return c


def tuile_ecorce():
	L, H = T, BANDE
	bruit = Image.effect_noise((L // 48, H // 6), 50).resize((L, H), Image.BICUBIC)
	fil = Image.effect_noise((L // 128, H // 2), 70).resize((L, H), Image.BICUBIC)   # stries le long de u
	ecorce = ImageChops.add(bruit, fil, scale=2.0).filter(ImageFilter.GaussianBlur(S))
	image = Image.merge("RGB", [ecorce.point(lambda v, k=k: int(BOIS[k] + (v - 128) * 0.6)) for k in range(3)])
	d = ImageDraw.Draw(image)
	for _ in range(160):                                     # gerçures sombres longitudinales
		x = random.uniform(0, L)
		y = random.uniform(0, H)
		l = random.uniform(40, 200) * S
		d.line([(x, y), (x + l, y + random.uniform(-4, 4) * S)], fill=varier(BOIS_FONCE, 6), width=random.randint(2, 4) * S)
	for _ in range(60):                                      # reflets gris clair (bois délavé)
		x = random.uniform(0, L)
		y = random.uniform(0, H)
		l = random.uniform(30, 140) * S
		d.line([(x, y), (x + l, y + random.uniform(-3, 3) * S)], fill=varier(BOIS_CLAIR, 6), width=random.randint(2, 3) * S)
	image = image.filter(ImageFilter.GaussianBlur(S * 0.6))
	# poussière de latérite au pied (u = 0 → début de la bande)
	terre = Image.new("RGB", (L // 6, H), (146, 90, 60))
	degrade = Image.new("L", (L // 6, H), 0)
	dd = ImageDraw.Draw(degrade)
	for x in range(L // 6):
		dd.line([(x, 0), (x, H)], fill=int(160 * (1.0 - x / (L / 6)) ** 1.6))   # fort au pied, nul à 1/6
	image.paste(terre, (0, 0), degrade)
	return image


def tuile_masse():
	c = Calque(T // 2, BANDE, marge=-40 * S, fond=(36, 31, 27), opaque=True)
	L, H = c.l, c.h
	for couche in range(4):
		base = melange(BOIS_FONCE, BOIS_CLAIR, couche / 3.0 * 0.75)
		for _ in range(26):
			x = random.uniform(-0.1, 1.0) * L
			y = random.uniform(0, H)
			angle = random.uniform(-0.6, 0.6) + random.choice((0, math.pi))
			branche(c, x, y, angle, random.uniform(0.15, 0.4) * L, random.uniform(6, 10) * S, varier(base, 10), 1)
	image = c.couleur
	ombre = Image.linear_gradient("L").resize((L, H))            # 0 en haut (v haut) → 255 en bas (v 0)
	image.paste(Image.new("RGB", (L, H), (34, 28, 24)), (0, 0), ombre.point(lambda v: int(max(0, v - 80) * 0.85)))
	image.paste(Image.new("RGB", (L, H), (138, 84, 56)), (0, 0), ombre.point(lambda v: int(max(0, v - 205) * 3.2)))
	return image


def tuile_raquette():
	cote = BANDE
	VERT = (90, 110, 76)
	br = Image.effect_noise((cote // 24, cote // 24), 30).resize((cote, cote), Image.BICUBIC)
	image = Image.merge("RGB", [br.point(lambda v, k=k: int(VERT[k] + (v - 128) * 0.3)) for k in range(3)])
	# bord jaunâtre usé, fondu (dégradé radial flouté)
	bord = Image.new("L", (cote, cote), 255)
	ImageDraw.Draw(bord).ellipse([cote * 0.05, cote * 0.05, cote * 0.95, cote * 0.95], fill=0)
	bord = bord.filter(ImageFilter.GaussianBlur(cote * 0.03))
	image.paste(Image.new("RGB", (cote, cote), (124, 132, 88)), (0, 0), bord.point(lambda v: int(v * 0.7)))
	d = ImageDraw.Draw(image)
	pas_ar = cote / 7
	for j in range(9):
		for i in range(9):
			cx = (i + 0.5 * (j % 2)) * pas_ar + random.uniform(-3, 3) * S
			cy = j * pas_ar + random.uniform(-3, 3) * S
			if (cx - cote / 2) ** 2 + (cy - cote / 2) ** 2 > (cote * 0.42) ** 2:
				continue
			r = 3.5 * S
			d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(196, 182, 140))     # touffe de glochides pâle
			d.ellipse([cx - r * 0.5, cy - r * 0.5, cx + r * 0.5, cy + r * 0.5], fill=(110, 86, 60))
	return image.filter(ImageFilter.GaussianBlur(S * 0.5))


def tuile_etoffe():
	cote = BANDE
	e = Image.effect_noise((cote, cote), 14).point(lambda v: int(200 + (v - 128) * 0.3))
	return Image.merge("RGB", [e, e, e.point(lambda v: v - 12)])


couleur = Image.new("RGB", (T, T), FOND_BOIS)
alpha = Image.new("L", (T, T), 255)
for i in range(2):
	f = tuile_fagot()
	couleur.paste(f.couleur, (i * T // 2, 0))
	alpha.paste(f.alpha, (i * T // 2, 0))
	c = tuile_crete()
	couleur.paste(c.couleur, (i * T // 2, BANDE))
	alpha.paste(c.alpha, (i * T // 2, BANDE))
couleur.paste(tuile_ecorce(), (0, 2 * BANDE))
couleur.paste(tuile_masse(), (0, 3 * BANDE))
couleur.paste(tuile_raquette(), (T // 2, 3 * BANDE))
couleur.paste(tuile_etoffe(), (T // 2 + BANDE, 3 * BANDE))

alpha = alpha.filter(ImageFilter.GaussianBlur(S * 0.35))
couleur = couleur.resize((TAILLE, TAILLE), Image.LANCZOS)
alpha = alpha.resize((TAILLE, TAILLE), Image.LANCZOS)
# Couverture légèrement épaissie (rameaux fins encore lisibles après mipmaps) : seuil doux.
alpha = alpha.point(lambda v: 0 if v < 40 else min(255, int((v - 40) * 1.6)))
image = couleur.copy()
image.putalpha(alpha)
image.save(SORTIE, optimize=True)
print("OK atlas", SORTIE, image.size)
