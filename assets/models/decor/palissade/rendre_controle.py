# Rendus de contrôle de la palissade en situation (EEVEE) : tracé de segments bout à bout comme en jeu
# (ligne droite, angle à 90°, à 45°, à 15°), caméra orthographique du jeu (direction (1,1,1) de Godot, 35,26°),
# soleil venant de la gauche de l'écran à ~50°, sol de latérite, silhouette humaine de 1,64 m pour l'échelle.
#
#   Blender -b --factory-startup palissade_vNN.blend --python-exit-code 1 --python rendre_controle.py -- DOSSIER
#
# Sorties : DOSSIER/jeu_zoom18.png (zoom le plus proche du jeu), jeu_zoom40.png (zoom par défaut),
#           angle90_proche.png, angle45_proche.png, variantes_face.png (a, b, c côte à côte, de face).
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
SORTIE = os.path.abspath(args[0])
os.makedirs(SORTIE, exist_ok=True)

sc = bpy.context.scene
variantes = [bpy.data.objects["Palissade_" + n] for n in "abc"]
banniere = bpy.data.objects["Banniere"]
for ob in variantes + [banniere]:
	ob.hide_render = True

# Couleur de clan pour la bannière (comme le jeu le fait par material_override).
mat_clan = bpy.data.materials.new("Clan")
mat_clan.diffuse_color = (0.75, 0.12, 0.08, 1)
if not mat_clan.node_tree:
	mat_clan.use_nodes = True
bsdf = next(n for n in mat_clan.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
bsdf.inputs["Base Color"].default_value = (0.7, 0.1, 0.06, 1)
bsdf.inputs["Roughness"].default_value = 0.9


def poser(variante, centre, angle):
	"""Instance liée d'un segment (même maillage) + sa bannière, comme le jeu l'instancie."""
	o = bpy.data.objects.new(variante.name + "_inst", variante.data)
	o.location = centre
	o.rotation_euler = (0, 0, angle)
	sc.collection.objects.link(o)
	b = bpy.data.objects.new("Banniere_inst", banniere.data.copy())
	b.data.materials.clear()
	b.data.materials.append(mat_clan)
	b.parent = o
	b.location = banniere.location
	sc.collection.objects.link(b)
	return o


def trace(depart, directions_deg, choix):
	"""Pose des segments de 4 m bout à bout ; `directions_deg` = direction de chaque segment (pas de 15°)."""
	p = Vector(depart)
	for i, d in enumerate(directions_deg):
		a = math.radians(d)
		v = Vector((math.cos(a), math.sin(a), 0)) * 4.0
		poser(variantes[choix[i % len(choix)]], p + v / 2, a)
		p = p + v
	return p


# Tracé : 3 segments droits, angle droit, 2 segments, angle de 45°, 2 segments, angle de 15°, 1 segment.
trace((-10.0, -6.0, 0), [0, 0, 0, 90, 90, 135, 135, 150], [0, 1, 2, 0, 2, 1, 0, 2])
# Second tracé séparé : angle à 90° vers l'intérieur et diagonale seule (lecture des bouts).
trace((6.0, -10.0, 0), [45, 45, 135], [1, 2, 0])

# Sol de latérite.
bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
sol = bpy.context.active_object
mat_sol = bpy.data.materials.new("Laterite")
if not mat_sol.node_tree:
	mat_sol.use_nodes = True
b = next(n for n in mat_sol.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
b.inputs["Base Color"].default_value = (0.36, 0.17, 0.09, 1)
b.inputs["Roughness"].default_value = 1.0
sol.data.materials.append(mat_sol)

# Silhouette humaine de référence (1,64 m).
bpy.ops.mesh.primitive_cylinder_add(radius=0.17, depth=1.64, location=(-8.0, -7.6, 0.82))
humain = bpy.context.active_object
mat_h = bpy.data.materials.new("Reference")
mat_h.diffuse_color = (0.2, 0.25, 0.6, 1)
if not mat_h.node_tree:
	mat_h.use_nodes = True
next(n for n in mat_h.node_tree.nodes if n.type == 'BSDF_PRINCIPLED').inputs["Base Color"].default_value = (0.15, 0.2, 0.55, 1)
humain.data.materials.append(mat_h)

# Soleil : vient de la gauche de l'écran, ombres vers le bas à droite (+X Blender pour la caméra du jeu).
soleil_data = bpy.data.lights.new("Soleil", 'SUN')
soleil_data.energy = 4.0
soleil_data.angle = math.radians(1.5)
soleil = bpy.data.objects.new("Soleil", soleil_data)
direction = Vector((math.cos(math.radians(50)), 0.15, -math.sin(math.radians(50)))).normalized()
soleil.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
sc.collection.objects.link(soleil)
if sc.world is None:
	sc.world = bpy.data.worlds.new("Monde")
sc.world.use_nodes = True if not sc.world.node_tree else sc.world.use_nodes
fond = next((n for n in sc.world.node_tree.nodes if n.type == 'BACKGROUND'), None)
if fond:
	fond.inputs["Color"].default_value = (0.55, 0.6, 0.7, 1)
	fond.inputs["Strength"].default_value = 0.6

sc.render.engine = 'BLENDER_EEVEE'
sc.render.image_settings.file_format = 'PNG'
sc.view_settings.view_transform = 'Standard'
if hasattr(sc, "eevee"):
	for attr, val in (("taa_render_samples", 32), ("use_shadows", True)):
		if hasattr(sc.eevee, attr):
			setattr(sc.eevee, attr, val)

cam_data = bpy.data.cameras.new("Camera")
cam_data.type = 'ORTHO'
cam = bpy.data.objects.new("Camera", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam


def rendre(nom, cible, taille_verticale, largeur, hauteur, direction=(1, -1, 1)):
	"""Taille_verticale en mètres, comme `camera.size` de Godot (projection orthographique)."""
	sc.render.resolution_x, sc.render.resolution_y = largeur, hauteur
	cam_data.ortho_scale = taille_verticale * max(1.0, largeur / hauteur)
	d = Vector(direction).normalized()
	cam.location = Vector(cible) + d * 60
	cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
	cam_data.clip_end = 200
	sc.render.filepath = os.path.join(SORTIE, nom + ".png")
	bpy.ops.render.render(write_still=True)
	print("OK rendu", sc.render.filepath)


rendre("jeu_zoom18", (-2.0, -1.0, 0), 18, 1600, 900)
rendre("jeu_zoom40", (0.0, -2.0, 0), 40, 1600, 900)
rendre("angle90_proche", (2.0, -6.0, 0.6), 7, 1200, 800)
rendre("angle45_proche", (1.0, 1.5, 0.6), 7, 1200, 800)

# Variantes côte à côte, de face (vue rasante légère) et de dessus, pour juger silhouette et différences.
for ob in list(sc.objects):
	if ob.name.endswith("_inst") or ob.name.startswith("Banniere_inst"):
		ob.hide_render = True
for i, v in enumerate(variantes):
	poser(v, Vector((-30 + i * 5.2, 30, 0)), 0.0)
humain.location = (-36.0, 30.0, 0.82)
rendre("variantes_face", (-27.4, 30, 0.8), 3.2, 1800, 600, direction=(0, -1, 0.12))
rendre("variantes_dessus", (-27.4, 30, 0.8), 5.0, 1800, 700, direction=(0.0, -0.55, 1))
