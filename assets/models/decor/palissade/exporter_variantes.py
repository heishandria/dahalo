"""Exporte un GLB par variante, avec le fanion indépendant de la faction."""
import os
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
if len(args) != 1:
	raise SystemExit("usage : exporter_variantes.py -- DOSSIER_SORTIE")

dossier_sortie = os.path.abspath(args[0])
os.makedirs(dossier_sortie, exist_ok=True)

variantes = {lettre: bpy.data.objects.get("Palissade_" + lettre) for lettre in "abc"}
banniere = bpy.data.objects.get("Banniere")
if any(obj is None or obj.type != "MESH" for obj in variantes.values()) or \
		banniere is None or banniere.type != "MESH":
	raise RuntimeError("Le .blend doit contenir Palissade_a/b/c et Banniere en maillages.")

if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
	bpy.ops.object.mode_set(mode="OBJECT")

for lettre, variante in variantes.items():
	bpy.ops.object.select_all(action="DESELECT")
	variante.select_set(True)
	banniere.select_set(True)
	bpy.context.view_layer.objects.active = variante
	variante.data.calc_loop_triangles()
	banniere.data.calc_loop_triangles()
	triangles = len(variante.data.loop_triangles) + len(banniere.data.loop_triangles)
	sortie = os.path.join(dossier_sortie, "palissade_%s.glb" % lettre)
	bpy.ops.export_scene.gltf(
		filepath=sortie,
		export_format="GLB",
		use_selection=True,
		export_apply=True,
		export_yup=True,
		export_materials="EXPORT",
		export_image_format="AUTO",
		export_animations=False,
		export_cameras=False,
		export_lights=False,
	)
	print("OK %s : %d triangles (banniere incluse)" % (sortie, triangles))
