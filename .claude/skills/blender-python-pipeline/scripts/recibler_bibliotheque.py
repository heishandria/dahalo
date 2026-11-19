# Recibler des animations d'une bibliothèque humanoïde (squelette type Unreal / Quaternius UAL : pelvis, spine_01–03,
# neck_01, Head, clavicle/upperarm/lowerarm/hand_l|r, thigh/calf/foot_l|r) sur le squelette commun Dahalo, et les cuire
# en actions ordinaires (rendus de contrôle, audit et export inchangés).
#
# Méthode (par os, en espace armature) : rotation de l'os source depuis SA pose de repos, appliquée à l'os cible après
# une correction de repos (rotation minimale qui aligne la direction de repos cible sur la source : A-pose → T-pose).
# Le bassin suit le déplacement du pelvis, mis à l'échelle de la longueur des jambes. Os non reliés : pose de repos.
#
#   Blender -b CIBLE.blend --python recibler_bibliotheque.py -- SOURCE.glb SORTIE.blend [--glb SORTIE.glb] \
#       --prefixe Villageoise --actions Walk_Loop=marche_loop,Idle_Loop=repos_loop,Death01=mort [--remplacer]
# Sans --remplacer, les actions créées s'appellent <prefixe>_ual_<nom> (comparaison avec les actions existantes).
import bpy, os, sys
from mathutils import Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ik_deux_os import assigner, courbes, vitesse_calage  # noqa: E402

CORRESPONDANCE = {
    "Racine": "root", "Bassin": "pelvis", "Colonne": "spine_02", "Thorax": "spine_03", "Cou": "neck_01", "Tete": "Head",
}
for c, s in (("D", "r"), ("G", "l")):
    CORRESPONDANCE.update({
        "Clavicule_" + c: "clavicle_" + s, "Bras_" + c: "upperarm_" + s, "Avant_bras_" + c: "lowerarm_" + s,
        "Main_" + c: "hand_" + s, "Doigts_" + c: "middle_01_" + s,
        "Cuisse_" + c: "thigh_" + s, "Mollet_" + c: "calf_" + s, "Pied_" + c: "foot_" + s,
    })

args = sys.argv[sys.argv.index("--") + 1:]
SOURCE, SORTIE = args[0], args[1]


def option(nom, defaut=None):
    return args[args.index(nom) + 1] if nom in args else defaut


PREFIXE = option("--prefixe")
REMPLACER = "--remplacer" in args
ACTIONS = [p.split("=") for p in option("--actions").split(",")]

sc = bpy.context.scene
sc.render.fps, sc.render.fps_base = 30, 1.0
cible = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
avant = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=SOURCE)
importes = set(bpy.data.objects) - avant
source = next(o for o in importes if o.type == 'ARMATURE')
for o in importes:
    o.hide_render = o.hide_viewport = o.type == 'MESH'

ps, pc = source.pose.bones, cible.pose.bones
bs, bc = source.data.bones, cible.data.bones
reliees = {c: s for c, s in CORRESPONDANCE.items() if c in bc and s in bs}
ws, wc = source.matrix_world, cible.matrix_world


def repos(arm, b):
    return arm.matrix_world @ b.matrix_local


def direction(arm, b):
    return (arm.matrix_world.to_3x3() @ (b.tail_local - b.head_local)).normalized()


# Correction de repos : rotation minimale (monde) qui amène la direction de repos de l'os cible sur celle de la source.
correction = {c: direction(cible, bc[c]).rotation_difference(direction(source, bs[s])).to_matrix()
              for c, s in reliees.items()}
jambe_s = (bs["thigh_r"].tail_local - bs["thigh_r"].head_local).length + (bs["calf_r"].tail_local - bs["calf_r"].head_local).length
jambe_c = (bc["Cuisse_D"].tail_local - bc["Cuisse_D"].head_local).length + (bc["Mollet_D"].tail_local - bc["Mollet_D"].head_local).length
echelle = jambe_c / jambe_s
pelvis_repos = (ws @ bs["pelvis"].matrix_local).translation
print("Os reliés : %d / %d ; échelle des déplacements %.3f" % (len(reliees), len(bc), echelle))

ordre = [b.name for b in cible.data.bones]                     # parents avant enfants (ordre de l'armature)
creees = []
for nom_source, nom_court in ACTIONS:
    a_src = bpy.data.actions.get(nom_source)
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
            if n in reliees:
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
            pb.location = local.translation if n in ("Bassin", "Racine") else (0, 0, 0)
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
for nom_source, _ in ACTIONS:
    a = bpy.data.actions.get(nom_source)
    if a:
        bpy.data.actions.remove(a)
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
