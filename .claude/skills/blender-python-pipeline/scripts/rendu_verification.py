# Rendus de vérification (lecture seule du .blend) : vues orthographiques autour des maillages visibles, et
# images d'actions (cycle d'animation), assemblées en une planche PNG. Moteur Workbench : rapide, sans réglage.
#
#   blender_lancer.sh modele.blend rendu_verification.py -- --sortie DOSSIER
#       [--vues face,profil,dos,trois_quarts,dessus] [--action NOM]… [--images 6] [--taille 384]
#       [--squelette NOM] [--fond 0.25]
#
# Repère : avant du modèle = -Y (convention Blender), haut = +Z. « face » regarde le modèle de face.
# Sortie : DOSSIER/planche_vues.png, DOSSIER/planche_<action>.png (+ images séparées).
import bpy, math, os, sys
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def option(nom, defaut=None, multiple=False):
    valeurs = [args[i + 1] for i, a in enumerate(args) if a == nom and i + 1 < len(args)]
    if multiple:
        return valeurs
    return valeurs[-1] if valeurs else defaut


SORTIE = os.path.abspath(option("--sortie", "rendus_verification"))
VUES = option("--vues", "face,profil,dos,trois_quarts").split(",")
ACTIONS = option("--action", multiple=True)
N_IMAGES = int(option("--images", "6"))
TAILLE = int(option("--taille", "384"))
FOND = float(option("--fond", "0.25"))
os.makedirs(SORTIE, exist_ok=True)

sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'
sc.display.shading.color_type = 'TEXTURE'
sc.render.resolution_x = TAILLE
sc.render.resolution_y = TAILLE
sc.render.resolution_percentage = 100
sc.render.film_transparent = False
sc.render.image_settings.file_format = 'PNG'
if sc.world is None:
    sc.world = bpy.data.worlds.new("Fond")
sc.world.color = (FOND, FOND, FOND)

squelette = None
nom_squelette = option("--squelette")
for o in bpy.data.objects:
    if o.type == 'ARMATURE' and (nom_squelette is None or o.name == nom_squelette):
        squelette = o
        break


def boite_maillages():
    """Boîte englobante (monde) des maillages visibles au rendu, pose courante comprise."""
    deps = bpy.context.evaluated_depsgraph_get()
    mini = Vector((1e9, 1e9, 1e9))
    maxi = Vector((-1e9, -1e9, -1e9))
    for o in bpy.data.objects:
        if o.type != 'MESH' or o.hide_render:
            continue
        ev = o.evaluated_get(deps)
        for c in ev.bound_box:
            p = ev.matrix_world @ Vector(c)
            mini = Vector(map(min, mini, p))
            maxi = Vector(map(max, maxi, p))
    return mini, maxi


cam_data = bpy.data.cameras.new("Camera_verification")
cam_data.type = 'ORTHO'
cam = bpy.data.objects.new("Camera_verification", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam
DIRECTIONS = {"face": Vector((0, -1, 0)), "profil": Vector((1, 0, 0)), "dos": Vector((0, 1, 0)),
              "trois_quarts": Vector((0.7, -0.7, 0.35)), "dessus": Vector((0.0, -0.35, 1.0)),
              "jeu": Vector((0.6, 0.6, 0.9))}


def cadrer(vue, mini, maxi):
    centre = (mini + maxi) / 2
    taille = max((maxi - mini).length, 0.1)
    d = DIRECTIONS[vue].normalized()
    cam.location = centre + d * taille * 3
    cam.rotation_euler = (centre - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam_data.ortho_scale = taille * 1.08
    cam_data.clip_end = taille * 10


def rendre(chemin):
    sc.render.filepath = chemin
    bpy.ops.render.render(write_still=True)
    return chemin


def planche(chemins, colonnes, chemin_sortie):
    """Assemble des PNG de même taille en grille (numpy fourni avec Blender)."""
    import numpy as np
    imgs = []
    for c in chemins:
        im = bpy.data.images.load(c)
        a = np.array(im.pixels[:], dtype=np.float32).reshape(im.size[1], im.size[0], 4)
        imgs.append(a)
        bpy.data.images.remove(im)
    h, w = imgs[0].shape[:2]
    lignes = math.ceil(len(imgs) / colonnes)
    grille = np.full((lignes * h, colonnes * w, 4), 1.0, dtype=np.float32)
    for k, a in enumerate(imgs):
        r, c = divmod(k, colonnes)
        y = (lignes - 1 - r) * h          # les pixels Blender partent du bas
        grille[y:y + h, c * w:(c + 1) * w] = a
    out = bpy.data.images.new("planche", width=colonnes * w, height=lignes * h)
    out.pixels = grille.ravel()
    out.filepath_raw = chemin_sortie
    out.file_format = 'PNG'
    out.save()
    print("OK planche : " + chemin_sortie)


# 1. Vues du modèle dans la pose courante (ou de repos).
mini, maxi = boite_maillages()
chemins = []
for vue in VUES:
    if vue not in DIRECTIONS:
        print("ATTENTION vue inconnue : " + vue)
        continue
    cadrer(vue, mini, maxi)
    chemins.append(rendre(os.path.join(SORTIE, "vue_%s.png" % vue)))
if chemins:
    planche(chemins, len(chemins), os.path.join(SORTIE, "planche_vues.png"))

# 2. Actions : N images régulièrement réparties, vues de profil et de face, cadrage fixe sur tout le cycle.
for nom in ACTIONS:
    a = bpy.data.actions.get(nom)
    if a is None or squelette is None:
        print("ATTENTION action ou squelette introuvable : %s" % nom)
        continue
    if squelette.animation_data is None:
        squelette.animation_data_create()
    squelette.animation_data.action = a
    if getattr(a, "slots", None):
        squelette.animation_data.action_slot = a.slots[0]
    debut, fin = a.frame_range
    images = [round(debut + (fin - debut) * k / N_IMAGES) for k in range(N_IMAGES)]
    mini = Vector((1e9, 1e9, 1e9))
    maxi = Vector((-1e9, -1e9, -1e9))
    for f in images:
        sc.frame_set(f)
        m1, m2 = boite_maillages()
        mini = Vector(map(min, mini, m1))
        maxi = Vector(map(max, maxi, m2))
    chemins = []
    for vue in ("profil", "face"):
        cadrer(vue, mini, maxi)
        for f in images:
            sc.frame_set(f)
            chemins.append(rendre(os.path.join(SORTIE, "%s_%s_%03d.png" % (nom, vue, f))))
    planche(chemins, N_IMAGES, os.path.join(SORTIE, "planche_%s.png" % nom))
print("OK rendus dans " + SORTIE)
