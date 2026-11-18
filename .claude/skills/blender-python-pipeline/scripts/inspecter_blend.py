# Inventaire d'un fichier .blend (lecture seule) : objets, triangles, matériaux, images, squelettes, actions.
#
#   blender_lancer.sh modele.blend inspecter_blend.py -- [rapport.json]
#
# Affiche un résumé lisible et, si un chemin est donné, écrit le rapport complet en JSON.
import bpy, json, sys

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
sortie = args[0] if args else None


def triangles(o):
    try:
        m = o.data
        m.calc_loop_triangles()
        return len(m.loop_triangles)
    except Exception:
        return 0


def courbes_action(a):
    """F-courbes d'une action (Blender ≤ 4.3 : a.fcurves ; 4.4+ : couches/bandes/sacs de canaux)."""
    try:
        return list(a.fcurves)
    except AttributeError:
        r = []
        for couche in a.layers:
            for bande in couche.strips:
                for sac in bande.channelbags:
                    r += list(sac.fcurves)
        return r


rapport = {"fichier": bpy.data.filepath, "version_blender": bpy.app.version_string,
           "scene": {}, "objets": [], "materiaux": [], "images": [], "armatures": [], "actions": []}
sc = bpy.context.scene
rapport["scene"] = {"nom": sc.name, "ips": sc.render.fps, "images": [sc.frame_start, sc.frame_end],
                    "echelle_unites": sc.unit_settings.scale_length}
total = 0
for o in bpy.data.objects:
    e = {"nom": o.name, "type": o.type, "parent": o.parent.name if o.parent else None,
         "modificateurs": [m.type for m in o.modifiers], "echelle": [round(x, 4) for x in o.scale],
         "visible_rendu": not o.hide_render}
    if o.type == 'MESH':
        e["triangles"] = triangles(o)
        e["materiaux"] = [m.name if m else None for m in o.data.materials]
        e["groupes_sommets"] = len(o.vertex_groups)
        total += e["triangles"]
    rapport["objets"].append(e)
rapport["triangles_total"] = total
for m in bpy.data.materials:
    rapport["materiaux"].append({"nom": m.name, "utilisateurs": m.users})
for i in bpy.data.images:
    rapport["images"].append({"nom": i.name, "taille": list(i.size), "chemin": i.filepath,
                              "integree": i.packed_file is not None})
for a in bpy.data.armatures:
    rapport["armatures"].append({"nom": a.name, "os": [b.name for b in a.bones]})
for a in bpy.data.actions:
    rapport["actions"].append({"nom": a.name, "images": [round(x, 2) for x in a.frame_range],
                               "utilisateur_fictif": a.use_fake_user,
                               "emplacements": [s.identifier for s in getattr(a, "slots", [])],
                               "courbes": len(courbes_action(a))})

print("RÉSUMÉ %s (Blender %s)" % (bpy.data.filepath or "(sans nom)", bpy.app.version_string))
print("  Scène : %d i/s, images %d–%d" % (rapport["scene"]["ips"], *rapport["scene"]["images"]))
print("  Objets : %d, triangles (maillages) : %d" % (len(rapport["objets"]), total))
for e in rapport["objets"]:
    if e["type"] == 'MESH':
        print("    - %-30s %7d triangles  matériaux %s" % (e["nom"], e["triangles"], e["materiaux"]))
for a in rapport["armatures"]:
    print("  Squelette %s : %d os" % (a["nom"], len(a["os"])))
for a in rapport["actions"]:
    print("  Action %-36s images %s  fictif=%s" % (a["nom"], a["images"], a["utilisateur_fictif"]))
for i in rapport["images"]:
    print("  Image %-36s %s  %s" % (i["nom"], i["taille"], "intégrée" if i["integree"] else i["chemin"]))
if sortie:
    with open(sortie, "w", encoding="utf-8") as f:
        json.dump(rapport, f, ensure_ascii=False, indent=2)
    print("OK rapport écrit : " + sortie)
