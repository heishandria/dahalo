# Recibler des animations d'une bibliothèque humanoïde (squelette type Unreal / Quaternius UAL : pelvis, spine_01–03,
# neck_01, Head, clavicle/upperarm/lowerarm/hand_l|r, thigh/calf/foot_l|r) sur le squelette commun Dahalo, et les cuire
# en actions ordinaires (rendus de contrôle, audit et export inchangés).
#
# Méthode (par os, en espace armature) : rotation de l'os source depuis SA pose de repos, appliquée à l'os cible après
# une correction de repos (rotation minimale qui aligne la direction de repos cible sur la source : A-pose → T-pose).
# Le bassin suit le déplacement du pelvis, mis à l'échelle de la longueur des jambes. Os non reliés : pose de repos.
#
# Sources reconnues : Quaternius UAL / Unreal (.glb) et Mixamo (.fbx, os « mixamorig:… », une action par fichier).
#
#   Blender -b CIBLE.blend --python recibler_bibliotheque.py -- SOURCE.glb|.fbx SORTIE.blend [--glb SORTIE.glb] \
#       --prefixe Villageoise --actions Walk_Loop=marche_loop,Idle_Loop=repos_loop,Death01=mort [--remplacer]
# --arme-deux-mains Fusil : l'os de l'arme est replacé à chaque image, poignée dans la main droite, canon vers la
# main gauche, dessus vers le haut (animations « rifle » de Mixamo).
# « *=nom » prend la seule action du fichier (Mixamo). Sans --remplacer, les actions créées s'appellent
# <prefixe>_ual_<nom> (comparaison avec les actions existantes).
import bpy, os, sys
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ik_deux_os import assigner, courbes, vitesse_calage  # noqa: E402

UNREAL = {
    "Racine": "root", "Bassin": "pelvis", "Colonne": "spine_02", "Thorax": "spine_03", "Cou": "neck_01", "Tete": "Head",
}
MIXAMO = {"Bassin": "mixamorig:Hips", "Colonne": "mixamorig:Spine1", "Thorax": "mixamorig:Spine2",
          "Cou": "mixamorig:Neck", "Tete": "mixamorig:Head"}
for c, s, m in (("D", "r", "Right"), ("G", "l", "Left")):
    UNREAL.update({
        "Clavicule_" + c: "clavicle_" + s, "Bras_" + c: "upperarm_" + s, "Avant_bras_" + c: "lowerarm_" + s,
        "Main_" + c: "hand_" + s, "Doigts_" + c: "middle_01_" + s,
        "Cuisse_" + c: "thigh_" + s, "Mollet_" + c: "calf_" + s, "Pied_" + c: "foot_" + s,
    })
    MIXAMO.update({
        "Clavicule_" + c: "mixamorig:%sShoulder" % m, "Bras_" + c: "mixamorig:%sArm" % m,
        "Avant_bras_" + c: "mixamorig:%sForeArm" % m, "Main_" + c: "mixamorig:%sHand" % m,
        "Doigts_" + c: "mixamorig:%sHandMiddle1" % m, "Cuisse_" + c: "mixamorig:%sUpLeg" % m,
        "Mollet_" + c: "mixamorig:%sLeg" % m, "Pied_" + c: "mixamorig:%sFoot" % m,
    })

args = sys.argv[sys.argv.index("--") + 1:]
SOURCE, SORTIE = args[0], args[1]


def option(nom, defaut=None):
    return args[args.index(nom) + 1] if nom in args else defaut


PREFIXE = option("--prefixe")
ARME = option("--arme-deux-mains")
REMPLACER = "--remplacer" in args
ACTIONS = [p.split("=") for p in option("--actions").split(",")]

sc = bpy.context.scene
sc.render.fps, sc.render.fps_base = 30, 1.0
cible = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
avant, actions_avant = set(bpy.data.objects), set(bpy.data.actions)
if SOURCE.lower().endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=SOURCE)
else:
    bpy.ops.import_scene.gltf(filepath=SOURCE)
importes = set(bpy.data.objects) - avant
actions_source = [a for a in bpy.data.actions if a not in actions_avant]
noms_source = [a.name for a in actions_source]           # les références deviennent invalides après suppression
source = next(o for o in importes if o.type == 'ARMATURE')
for o in importes:
    o.hide_render = o.hide_viewport = o.type == 'MESH'

ps, pc = source.pose.bones, cible.pose.bones
bs, bc = source.data.bones, cible.data.bones
# Mixamo : préfixe variable selon le personnage choisi sur le site (mixamorig:, mixamorig2:…).
hanches = next((b.name for b in bs if b.name.endswith(":Hips")), None)
if hanches:
    prefixe_mixamo = hanches[:-len("Hips")]
    CORRESPONDANCE = {c: prefixe_mixamo + s.split(":", 1)[1] for c, s in MIXAMO.items()}
else:
    CORRESPONDANCE = UNREAL
reliees = {c: s for c, s in CORRESPONDANCE.items() if c in bc and s in bs}
ws, wc = source.matrix_world, cible.matrix_world


def repos(arm, b):
    return arm.matrix_world @ b.matrix_local


def direction(arm, b):
    return (arm.matrix_world.to_3x3() @ (b.tail_local - b.head_local)).normalized()


# Correction de repos : rotation minimale (monde) qui amène la direction de repos de l'os cible sur celle de la source.
correction = {c: direction(cible, bc[c]).rotation_difference(direction(source, bs[s])).to_matrix()
              for c, s in reliees.items()}
def longueur_monde(arm, b):
    return (arm.matrix_world @ b.tail_local - arm.matrix_world @ b.head_local).length


jambe_s = longueur_monde(source, bs[reliees["Cuisse_D"]]) + longueur_monde(source, bs[reliees["Mollet_D"]])
jambe_c = (bc["Cuisse_D"].tail_local - bc["Cuisse_D"].head_local).length + (bc["Mollet_D"].tail_local - bc["Mollet_D"].head_local).length
echelle = jambe_c / jambe_s
pelvis_repos = (ws @ bs[reliees["Bassin"]].matrix_local).translation
print("Os reliés : %d / %d ; échelle des déplacements %.3f" % (len(reliees), len(bc), echelle))

ordre = [b.name for b in cible.data.bones]                     # parents avant enfants (ordre de l'armature)
creees = []
for nom_source, nom_court in ACTIONS:
    a_src = actions_source[0] if nom_source == "*" and actions_source else bpy.data.actions.get(nom_source)
    if a_src is None:
        print("ATTENTION action source absente : " + nom_source)
        continue
    assigner(source, a_src)
    debut, fin = int(a_src.frame_range[0]), int(a_src.frame_range[1])
    nom = "%s_%s%s" % (PREFIXE, "" if REMPLACER else "ual_", nom_court)
    ancienne = bpy.data.actions.get(nom)
    if ancienne:
        bpy.data.actions.remove(ancienne)
    action = bpy.data.actions.new(nom)
    assigner(cible, action)
    for pb in pc:
        pb.rotation_mode = 'QUATERNION'
    for f in range(debut, fin + 1):
        sc.frame_set(f)
        pose_monde = {}
        for n in ordre:
            b = bc[n]
            rest_b = repos(cible, b)
            if b.parent:
                parent_pose = pose_monde[b.parent.name]
                rest_p = repos(cible, b.parent)
                base = parent_pose @ rest_p.inverted() @ rest_b      # os qui suit son parent sans bouger lui-même
            else:
                base = rest_b.copy()
            if n == ARME and "Main_D" in pose_monde and "Main_G" in pose_monde:
                paume = {c: pose_monde["Main_" + c].translation + pose_monde["Main_" + c].to_3x3().col[1] * 0.07
                         for c in ("D", "G")}
                canon = (paume["G"] - paume["D"]).normalized()
                haut = Vector((0, 0, 1)) - canon * canon.z
                haut = haut.normalized() if haut.length > 0.2 else Vector((0, -1, 0))
                x = canon.cross(haut).normalized()
                m = Matrix((x, canon, x.cross(canon))).transposed().to_4x4()
                m.translation = paume["D"]
            elif n in reliees:
                s = reliees[n]
                rot_src = (ws @ ps[s].matrix).to_3x3()
                delta = rot_src @ repos(source, bs[s]).to_3x3().inverted()
                rot = delta @ correction[n] @ rest_b.to_3x3()
                m = rot.to_4x4()
                m.translation = base.translation
                if n == "Bassin":
                    m.translation = rest_b.translation + ((ws @ ps[s].matrix).translation - pelvis_repos) * echelle
            else:
                m = base
            pose_monde[n] = m
            pb = pc[n]
            if b.parent:
                local = (rest_p.inverted() @ rest_b).inverted() @ pose_monde[b.parent.name].inverted() @ m
            else:
                local = rest_b.inverted() @ m
            pb.location = local.translation if n in ("Bassin", "Racine", ARME) else (0, 0, 0)
            pb.rotation_quaternion = local.to_quaternion()
            pb.keyframe_insert("location", frame=f - debut + 1)
            pb.keyframe_insert("rotation_quaternion", frame=f - debut + 1)
    for fc in courbes(action):
        for k in fc.keyframe_points:
            k.interpolation = 'LINEAR'
    action.use_fake_user = True
    creees.append(action)
    texte = "ACTION %s ← %s : %d images (%.2f s)" % (nom, nom_source, fin - debut + 1, (fin - debut) / 30)
    if nom_court.startswith(("marche", "course")):
        pieds = [n for n in ("Pied_D", "Pied_G") if n in bc]
        texte += " ; vitesse de calage %.3f m/s" % vitesse_calage(cible, action, pieds)
    print(texte)

# La source ne part pas dans le fichier : ni son squelette, ni son maillage, ni ses actions.
for o in importes:
    bpy.data.objects.remove(o, do_unlink=True)
for a in list(bpy.data.actions):
    if a.users == 0 and not a.use_fake_user:
        bpy.data.actions.remove(a)
noms_creees = {a.name for a in creees}
for nom in noms_source:
    if nom in bpy.data.actions and nom not in noms_creees:
        bpy.data.actions.remove(bpy.data.actions[nom])
repos_action = next((a for a in bpy.data.actions if a.name.endswith("_repos_loop") and "ual" not in a.name), None)
assigner(cible, repos_action or creees[0])
bpy.ops.wm.save_as_mainfile(filepath=SORTIE)
if option("--glb"):
    bpy.ops.object.select_all(action='DESELECT')
    for o in bpy.context.view_layer.objects:
        if o.type in ('MESH', 'ARMATURE'):
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=option("--glb"), export_format='GLB', use_selection=True, export_animations=True,
                              export_animation_mode='ACTIONS', export_optimize_animation_size=True,
                              export_force_sampling=False)
print("OK %s" % SORTIE)
