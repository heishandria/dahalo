# Animation de mort générique pour le squelette commun Dahalo (Racine, Bassin, Colonne, Thorax, Cou, Tete,
# Clavicule_*, Bras_*, Avant_bras_*, Main_*, Doigts_*, Cuisse_*, Mollet_*, Pied_* ; D = côté −X, avant = −Y).
# Chute sans effet sanglant (bible §4, CLAUDE.md) : à-coup de l'impact, jambes qui cèdent, chute en avant de
# trois-quarts, mains en avant, corps immobile au sol, tête tournée sur le côté. Le jeu garde le corps puis l'efface.
#
# Principe : le corps est posé « debout » (Racine au repos), puis la Racine tourne tout le corps vers le sol ;
# le contact au sol est calculé à chaque image d'après l'épaisseur réelle du maillage autour de chaque os
# (pas d'enfoncement, pas de corps qui flotte).
#
# Bibliothèque (depuis un script d'animation) :
#     from mort import creer_mort
#     creer_mort(arm, "Chef_mort", tenue=lambda t: ..., accessoire="Fusil")
# Étape autonome (ajoute l'action à un .blend animé, puis exporte toutes les actions) :
#     Blender -b X_anim.blend --python mort.py -- SORTIE.blend SORTIE.glb --prefixe Villageoise [--cote -1]
import bpy, math, os, sys
from mathutils import Matrix, Vector
from mathutils.geometry import intersect_point_line

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ik_deux_os import assigner, courbes, jambe_deux_os, lisse, placer  # noqa: E402

COTES = ("D", "G")
CORPS = ["Bassin", "Colonne", "Thorax", "Cou", "Tete"] + \
    ["%s_%s" % (n, c) for c in COTES for n in ("Clavicule", "Bras", "Avant_bras", "Main", "Cuisse", "Mollet", "Pied")]
RAYON_DEFAUT = {"Bassin": 0.13, "Colonne": 0.12, "Thorax": 0.13, "Cou": 0.06, "Tete": 0.10, "Clavicule": 0.05,
                "Bras": 0.05, "Avant_bras": 0.04, "Main": 0.03, "Cuisse": 0.08, "Mollet": 0.06, "Pied": 0.04}


def _bornes(t, a, b):
    return min(1.0, max(0.0, (t - a) / (b - a)))


def rayons_os(arm):
    """Épaisseur du corps autour de chaque os (médiane des distances sommet → segment de l'os), d'après le maillage."""
    rayons = {}
    inv = arm.matrix_world.inverted()
    for o in bpy.data.objects:
        if o.type != 'MESH' or not any(m.type == 'ARMATURE' and m.object == arm for m in o.modifiers):
            continue
        noms = {g.index: g.name for g in o.vertex_groups}
        distances = {}
        for v in o.data.vertices:
            if not v.groups:
                continue
            g = max(v.groups, key=lambda x: x.weight)
            nom = noms.get(g.group)
            if nom not in CORPS or g.weight < 0.6:
                continue
            b = arm.data.bones[nom]
            p = inv @ o.matrix_world @ v.co
            q, f = intersect_point_line(p, b.head_local, b.tail_local)
            q = b.head_local.lerp(b.tail_local, min(1.0, max(0.0, f)))
            distances.setdefault(nom, []).append((p - q).length)
        for nom, d in distances.items():
            if len(d) >= 20:
                d.sort()
                rayons[nom] = d[len(d) // 2]
    for nom in CORPS:
        rayons.setdefault(nom, RAYON_DEFAUT[nom.split("_")[0] if nom.count("_") == 1 else "Avant_bras"])
    return rayons


def creer_mort(arm, nom_action, images=45, cote=1, tenue=None, t_lacher=0.36, accessoire=None, angle=87.0):
    """Crée l'action `nom_action` (images+1 clés, non bouclée). cote : +1 chute vers +X (côté G), −1 vers −X.
    tenue(t) : appelé tant que t < t_lacher, après la pose du corps et avant la chute (mains sur un accessoire…).
    accessoire : os d'un objet tenu, lâché à t_lacher, qui tombe à plat à côté du corps."""
    pose, os_ = arm.pose.bones, arm.data.bones
    vue = bpy.context.view_layer
    bpy.context.view_layer.objects.active = arm
    if bpy.context.object.mode != 'POSE':
        bpy.ops.object.mode_set(mode='POSE')
    rayons = rayons_os(arm)
    tete_repos = {n: os_[n].head_local.copy() for n in CORPS}
    longueur = {n: (os_[n].tail_local - os_[n].head_local).length for n in CORPS}
    jambe = longueur["Cuisse_D"] + longueur["Mollet_D"]
    bras = longueur["Bras_D"] + longueur["Avant_bras_D"]
    chute = Vector((0.45 * cote, -1.0, 0.0)).normalized()      # en avant, de trois-quarts
    axe = Vector((0, 0, 1)).cross(chute).normalized()          # tourner autour de cet axe amène le haut vers `chute`
    racine_repos = os_["Racine"].matrix_local.copy()

    ancienne = bpy.data.actions.get(nom_action)
    if ancienne:
        bpy.data.actions.remove(ancienne)
    action = bpy.data.actions.new(nom_action)
    assigner(arm, action)
    for pb in pose:
        pb.rotation_mode = 'QUATERNION'

    def contact():
        """Hauteur du point de corps le plus bas (surface, pas l'os) en espace armature."""
        bas = 1e9
        for n in CORPS:
            pb = pose[n]
            for f in (0.0, 0.5, 1.0):
                bas = min(bas, pb.head.lerp(pb.tail, f).z - rayons[n])
        return bas

    mains_lachees, acc_lache, decalage_repos = {}, None, None
    for image in range(images + 1):
        t = image / images
        bpy.context.scene.frame_set(1)
        for pb in pose:
            pb.location = (0, 0, 0)
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.scale = (1, 1, 1)
        vue.update()

        impact = math.sin(math.pi * _bornes(t, 0.0, 0.16))      # à-coup : 0 → 1 → 0
        cede = lisse(_bornes(t, 0.08, 0.40))                    # les jambes cèdent
        u = _bornes(t, 0.32, 0.78)
        bascule = u * u                                         # chute accélérée (pesanteur)
        if 0.78 < t <= 0.90:
            bascule = 1.0 - 0.05 * math.sin(math.pi * _bornes(t, 0.78, 0.90))   # petit rebond au contact
        detente = lisse(_bornes(t, 0.38, 0.82))                 # le corps se déplie pendant la chute
        plie = cede * (1.0 - detente)                           # flexion du buste et des jambes, effacée au sol

        # Bassin : recul à l'impact, descente en flexion, remonte (dans le repère du corps) pendant la chute.
        descente = 0.30 * jambe * plie
        bassin = tete_repos["Bassin"] + Vector((0.02 * cote * cede, 0.05 * impact + 0.05 * plie, -descente))
        placer(arm, "Bassin", bassin, Matrix.Rotation(math.radians(12 * plie - 6 * impact), 3, 'X'))
        vue.update()
        for c in COTES:
            cheville = tete_repos["Pied_" + c].copy()
            if detente > 0:                                     # jambes qui se déplient vers l'arrière du corps
                ecart = 0.05 if c == "G" else -0.05
                cheville = cheville.lerp(cheville + Vector((ecart, 0.14, -0.04)), detente)
            jambe_deux_os(arm, "Cuisse_" + c, "Mollet_" + c, cheville, avant=Vector((0, -1, 0)))
            vue.update()
            placer(arm, "Pied_" + c, pose["Pied_" + c].head.copy(), Matrix.Rotation(math.radians(25 * detente), 3, 'X'))
        # Dos et tête : rejetés en arrière à l'impact, puis le buste s'affaisse en avant ; tête tournée vers le côté au sol.
        for n, avant, arriere in (("Colonne", 16, 8), ("Thorax", 10, 6), ("Cou", 14, 12)):
            courbure = math.radians(avant * plie - arriere * impact)
            pose[n].rotation_quaternion = _rot(os_, n, Vector((1, 0, 0)), courbure)
        pose["Tete"].rotation_quaternion = _rot(os_, "Tete", Vector((0, 0, 1)), math.radians(-35 * cote) * detente) @ \
            _rot(os_, "Tete", Vector((1, 0, 0)), math.radians(10 * plie - 10 * impact))
        vue.update()

        tenu = tenue is not None and t < t_lacher
        if tenu:
            tenue(t)
            vue.update()
            for c in COTES:
                mains_lachees[c] = pose["Avant_bras_" + c].tail.copy()
        else:
            for c in COTES:
                sx = -1 if c == "D" else 1
                epaule = pose["Bras_" + c].head.copy()
                vers_sol = sx == cote                           # la main du côté de la chute va plus loin
                pendante = epaule + Vector((0.12 * sx, 0.0, -0.92 * bras))
                ecartee = epaule + Vector((0.30 * sx, 0.12, -0.70 * bras))
                en_avant = epaule + Vector(((0.30 if vers_sol else 0.18) * sx, -0.45 * bras, -0.45 * bras))
                # Au sol (repère du corps : le sol est le plan de la poitrine, un peu devant l'épaule) : bras du côté
                # de la chute près de la tête, l'autre le long du corps ; jamais plus loin devant (sinon le corps
                # reste appuyé sur un bras tendu).
                au_sol = (epaule + Vector((0.40 * sx, -0.10, 0.35 * bras)) if vers_sol
                          else epaule + Vector((0.20 * sx, -0.08, -0.85 * bras)))
                cible = pendante.lerp(ecartee, impact)
                cible = cible.lerp(en_avant, lisse(_bornes(t, 0.35, 0.65)))
                cible = cible.lerp(au_sol, lisse(_bornes(t, 0.60, 0.84)))
                if c in mains_lachees:                          # mains qui quittent l'accessoire sans saut
                    cible = mains_lachees[c].lerp(cible, lisse(_bornes(t, t_lacher, t_lacher + 0.12)))
                jambe_deux_os(arm, "Bras_" + c, "Avant_bras_" + c, cible, avant=Vector((0.4 * sx, 0.8, -0.3)))
                vue.update()

        # Chute : rotation de tout le corps (Racine) puis contact au sol.
        rotation = Matrix.Rotation(math.radians(angle) * bascule, 4, axe)
        pose["Racine"].matrix = rotation @ racine_repos
        vue.update()
        bas = contact()
        if decalage_repos is None:
            decalage_repos = bas                                # 1re image : les pieds restent où ils sont
        pose["Racine"].matrix = Matrix.Translation((0, 0, decalage_repos - bas)) @ rotation @ racine_repos
        vue.update()

        if accessoire and accessoire in pose:
            if tenu:
                acc_lache = (pose[accessoire].matrix.copy(), t)
            elif acc_lache is not None:
                m0, t0 = acc_lache
                v = _bornes(t, t0, min(1.0, t0 + 0.30))
                canon = m0.to_3x3().col[1].copy()
                canon.z = 0
                canon = canon.normalized() if canon.length > 0.2 else chute
                cote_x = canon.cross(Vector((0, 0, 1))).normalized()
                pos_sol = m0.translation + chute * 0.45 + cote_x * 0.15 * cote
                pos_sol.z = 0.03
                # Couché sur le flanc : canon horizontal, dessus (axe Z de l'os) à l'horizontale.
                m_sol = Matrix((canon.cross(cote_x), canon, cote_x)).transposed()
                q = m0.to_quaternion().slerp(m_sol.to_quaternion(), lisse(v))
                p = m0.translation.lerp(pos_sol, v)
                p.z = m0.translation.z + (pos_sol.z - m0.translation.z) * v * v
                m = q.to_matrix().to_4x4()
                m.translation = p
                pose[accessoire].matrix = m
                vue.update()

        for pb in pose:
            pb.keyframe_insert("location", frame=image + 1)
            pb.keyframe_insert("rotation_quaternion", frame=image + 1)

    for fc in courbes(action):
        for k in fc.keyframe_points:
            k.interpolation = 'LINEAR'
    action.use_fake_user = True
    print("ACTION %s : %d images (%.2f s à 30 i/s), chute vers %s" % (
        nom_action, images + 1, images / 30.0, "+X" if cote > 0 else "-X"))
    return action


def _rot(os_, nom, axe_armature, angle):
    from mathutils import Quaternion
    return Quaternion(os_[nom].matrix_local.to_3x3().inverted() @ axe_armature, angle)


if __name__ == "__main__" and "--" in sys.argv:
    args = sys.argv[sys.argv.index("--") + 1:]
    SORTIE_BLEND, SORTIE_GLB = args[0], args[1]

    def option(nom, defaut):
        return type(defaut)(args[args.index(nom) + 1]) if nom in args else defaut

    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    prefixe = option("--prefixe", arm.name.split("_")[0])
    bpy.context.scene.render.fps = 30
    creer_mort(arm, prefixe + "_mort", images=option("--images", 45), cote=option("--cote", 1))
    repos = next((a for a in bpy.data.actions if a.name.endswith("_repos_loop")), None)
    if repos:
        assigner(arm, repos)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.wm.save_as_mainfile(filepath=SORTIE_BLEND)
    bpy.ops.object.select_all(action='DESELECT')
    for o in bpy.context.view_layer.objects:
        if o.type in ('MESH', 'ARMATURE'):
            o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=SORTIE_GLB, export_format='GLB', use_selection=True, export_animations=True,
                              export_animation_mode='ACTIONS', export_optimize_animation_size=True,
                              export_force_sampling=False)
    print("OK %s + %s" % (SORTIE_BLEND, SORTIE_GLB))
