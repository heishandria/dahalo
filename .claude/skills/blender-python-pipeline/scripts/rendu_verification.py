# Rendus de vérification (lecture seule du .blend) : vues orthographiques autour des maillages visibles, et
# images d'actions (cycle d'animation), assemblées en une planche PNG. Moteur Workbench : rapide, sans réglage.
#
#   blender_lancer.sh modele.blend rendu_verification.py -- --sortie DOSSIER
#       [--vues face,profil,dos,trois_quarts,dessus] [--action NOM]… [--images 6] [--taille 384]
#       [--squelette NOM] [--fond 0.25] [--cacher OBJET,OBJET…]
#       [--rts [--tailles-vue 18,40,70] [--ecran 1080] [--agrandir 3]]   ← vues à la caméra du jeu
#
# --rts reproduit la caméra de systems/rts_camera.gd : orthographique, isométrique « vraie » (35,26° au-dessus de
# l'horizon), 4 orientations du personnage. --tailles-vue = Camera3D.size de Godot (hauteur de vue en mètres : zoom
# 18 à 70, 40 par défaut). Chaque vignette est un recadrage de l'écran (--ecran px de haut) À SA DENSITÉ RÉELLE
# (le personnage y a la taille en pixels qu'il aura en jeu), agrandie ensuite sans lissage pour être regardée.
# Avec --action : une planche RTS par action (image du milieu), la pose de repos d'abord.
#
# Repère : avant du modèle = -Y (convention Blender), haut = +Z. « face » regarde le modèle de face.
# Sortie : DOSSIER/planche_vues.png, DOSSIER/planche_<action>.png, DOSSIER/planche_rts[_<action>].png.
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
RTS = "--rts" in args
TAILLES_VUE = [float(d) for d in option("--tailles-vue", option("--distances", "18,40,70")).split(",")]
ECRAN = int(option("--ecran", "1080"))
AGRANDIR = int(option("--agrandir", "3"))
N_IMAGES = int(option("--images", "6"))
TAILLE = int(option("--taille", "384"))
FOND = float(option("--fond", "0.25"))
os.makedirs(SORTIE, exist_ok=True)
for nom in (option("--cacher", "") or "").split(","):
    if nom and nom in bpy.data.objects:
        bpy.data.objects[nom].hide_render = True     # accessoires hors sujet (ex. seau non animé)

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


def planche(chemins, colonnes, chemin_sortie, agrandir=1):
    """Assemble des PNG de même taille en grille (numpy fourni avec Blender) ; agrandir : sans lissage."""
    import numpy as np
    imgs = []
    for c in chemins:
        im = bpy.data.images.load(c)
        a = np.array(im.pixels[:], dtype=np.float32).reshape(im.size[1], im.size[0], 4)
        if agrandir > 1:
            a = a.repeat(agrandir, 0).repeat(agrandir, 1)
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

# 3. Vues RTS à la caméra du jeu (voir l'en-tête). Contrôle de lisibilité : rôle reconnaissable à la taille de vue
#    par défaut (40), silhouette lisible au zoom maximal (18), au moins une tache de couleur au zoom minimal (70).
def planche_rts(suffixe):
    import math as _m
    mini_r, maxi_r = boite_maillages()
    centre_r = (mini_r + maxi_r) / 2
    hauteur_px = {t: (maxi_r.z - mini_r.z) * _m.cos(_m.radians(35.26)) / t * ECRAN for t in TAILLES_VUE}
    cote = max(48, int(max(hauteur_px.values()) * 1.5))          # vignette carrée, en pixels d'écran réels
    sc.render.resolution_x = sc.render.resolution_y = cote
    ancien_fond = tuple(sc.world.color)
    sc.world.color = (0.30, 0.13, 0.06)                           # latérite (linéaire) : fond réel du jeu
    chemins_r = []
    for t in TAILLES_VUE:
        cam_data.ortho_scale = t * cote / ECRAN
        cam_data.clip_end = 200
        for nom_o, horizontal in (("face", (0, -1)), ("droite", (1, 0)), ("dos", (0, 1)), ("gauche", (-1, 0))):
            d = Vector((horizontal[0] * math.sqrt(2), horizontal[1] * math.sqrt(2), 1.0)).normalized()
            cam.location = centre_r + d * 60
            cam.rotation_euler = (centre_r - cam.location).to_track_quat('-Z', 'Y').to_euler()
            chemins_r.append(rendre(os.path.join(SORTIE, "rts%s_%d_%s.png" % (suffixe, int(t), nom_o))))
        print("RTS%s taille de vue %d : personnage ~%d px de haut sur un écran de %d px" % (
            suffixe, int(t), round(hauteur_px[t]), ECRAN))
    sc.world.color = ancien_fond
    sc.render.resolution_x = sc.render.resolution_y = TAILLE
    planche(chemins_r, 4, os.path.join(SORTIE, "planche_rts%s.png" % suffixe), agrandir=AGRANDIR)
    print(">>> Regarder planche_rts%s.png (lignes : tailles de vue %s ; colonnes : face, droite, dos, gauche)" % (
        suffixe, ",".join(str(int(t)) for t in TAILLES_VUE)))


if RTS:
    if ACTIONS and squelette is not None:
        for nom in ACTIONS:
            a = bpy.data.actions.get(nom)
            if a is None:
                continue
            squelette.animation_data.action = a
            if getattr(a, "slots", None):
                squelette.animation_data.action_slot = a.slots[0]
            sc.frame_set(round(sum(a.frame_range) / 2))
            planche_rts("_" + nom)
    else:
        planche_rts("")

print("OK rendus dans " + SORTIE)
