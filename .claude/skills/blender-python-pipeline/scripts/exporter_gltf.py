# Export glTF binaire (.glb) avec les réglages sûrs pour un moteur de jeu ; l'ancien fichier de sortie, s'il
# existe, est conservé (renommé avec la date). Ne modifie pas le .blend.
#
#   blender_lancer.sh modele.blend exporter_gltf.py -- sortie.glb [--objets A,B,C] [--echantillonner]
#       [--sans-animations]
#
# --objets : noms des objets à exporter (sinon : tous les maillages, squelettes et vides visibles au rendu).
# --echantillonner : à utiliser si des contraintes (IK…) pilotent des os : le moteur ne les exécute pas.
import bpy, os, sys, time

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if not args:
    raise SystemExit("ERREUR : chemin de sortie .glb manquant")
sortie = os.path.abspath(args[0])
objets = None
if "--objets" in args:
    objets = args[args.index("--objets") + 1].split(",")
echantillonner = "--echantillonner" in args
animations = "--sans-animations" not in args

if os.path.exists(sortie):
    ancien = sortie[:-4] + time.strftime("_%Y%m%d-%H%M%S") + ".glb"
    os.rename(sortie, ancien)
    print("Ancienne sortie conservée : " + ancien)

if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
for o in bpy.data.objects:
    o.select_set(False)
choisis = []
for o in bpy.data.objects:
    if objets is not None:
        ok = o.name in objets
    else:
        ok = o.type in ('MESH', 'ARMATURE', 'EMPTY') and not o.hide_render
    if ok:
        o.select_set(True)
        choisis.append(o.name)
manquants = [n for n in (objets or []) if n not in choisis]
if manquants:
    raise SystemExit("ERREUR : objets introuvables : %s" % manquants)
for a in bpy.data.actions:
    a.use_fake_user = True      # sinon une action non assignée peut être perdue

bpy.ops.export_scene.gltf(filepath=sortie, export_format='GLB', use_selection=True,
                          export_animations=animations, export_animation_mode='ACTIONS',
                          export_force_sampling=echantillonner, export_optimize_animation_size=True)
print("OK export : %s (%d objets : %s ; échantillonnage %s)" % (sortie, len(choisis), ", ".join(choisis),
                                                                "oui" if echantillonner else "non"))
