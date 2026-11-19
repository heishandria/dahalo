# Bibliothèque pour générer des animations par script (Blender, mode pose) : cinématique inverse analytique à
# deux os, pose d'un os en espace armature, rotations locales, accès aux F-courbes (toutes versions), mesure de la
# vitesse de calage d'un cycle de marche. À charger depuis un script :
#
#   import os, sys; sys.path.insert(0, "<chemin de ce dossier>"); from ik_deux_os import *
#
# Repère armature supposé : avant = -Y, haut = +Z (à adapter via le paramètre `avant`).
import math
import bpy
from mathutils import Matrix, Quaternion, Vector


def lisse(t):
    return t * t * (3 - 2 * t)


def placer(arm, nom, tete, rotation):
    """Pose l'os `nom` : tête en `tete` (espace armature), orientation `rotation` (3×3) appliquée au repos."""
    os_repos = arm.data.bones[nom]
    arm.pose.bones[nom].matrix = Matrix.Translation(tete) @ (rotation @ os_repos.matrix_local.to_3x3()).to_4x4()
    bpy.context.view_layer.update()


def orienter(arm, nom, tete, direction):
    """Pose l'os pour qu'il pointe vers `direction` (rotation minimale depuis sa direction de repos)."""
    b = arm.data.bones[nom]
    repos = (b.tail_local - b.head_local).normalized()
    placer(arm, nom, tete, repos.rotation_difference(direction.normalized()).to_matrix())


def jambe_deux_os(arm, os_haut, os_bas, cible, avant=Vector((0, -1, 0))):
    """Résout cuisse + mollet pour amener le bout du mollet sur `cible` ; genou plié vers `avant`
    (vers l'arrière : passer -avant). Si la cible est hors de portée, la jambe se tend vers elle."""
    b1, b2 = arm.data.bones[os_haut], arm.data.bones[os_bas]
    l1 = (b1.tail_local - b1.head_local).length
    l2 = (b2.tail_local - b2.head_local).length
    hanche = arm.pose.bones[os_haut].head.copy()
    v = cible - hanche
    d = min(max(v.length, 1e-4), l1 + l2 - 1e-4)
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    axe = v.normalized()
    perp = avant - axe * avant.dot(axe)
    perp = perp.normalized() if perp.length > 1e-6 else Vector((0, 0, 1))
    genou = hanche + axe * a + perp * h
    orienter(arm, os_haut, hanche, genou - hanche)
    orienter(arm, os_bas, genou, hanche + axe * d - genou)
    return genou


def portee_max(arm, os_haut, os_bas, marge=0.985):
    b1, b2 = arm.data.bones[os_haut], arm.data.bones[os_bas]
    return ((b1.tail_local - b1.head_local).length + (b2.tail_local - b2.head_local).length) * marge


def rot_locale(arm, nom, axe_armature, angle):
    """Quaternion local d'un os pour une rotation autour d'un axe donné en espace armature (au repos)."""
    axe = arm.data.bones[nom].matrix_local.to_3x3().inverted() @ Vector(axe_armature)
    return Quaternion(axe, angle)


def courbes(action):
    """F-courbes d'une action, quelle que soit la version de Blender (actions à emplacements en 4.4+)."""
    try:
        return list(action.fcurves)
    except AttributeError:
        r = []
        for couche in action.layers:
            for bande in couche.strips:
                for sac in bande.channelbags:
                    r += list(sac.fcurves)
        return r


def assigner(arm, action):
    """Assigne une action au squelette (et son premier emplacement en 4.4+)."""
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = action
    if getattr(action, "slots", None):
        arm.animation_data.action_slot = action.slots[0]


def interpolation_lineaire(action):
    for fc in courbes(action):
        for k in fc.keyframe_points:
            k.interpolation = 'LINEAR'


def vitesse_calage(arm, action, os_pieds, ips=None, tolerance=0.025):
    """Vitesse (m/s) du pied au sol d'un cycle sur place : médiane, sur les seules images où un pied touche le sol
    (point le plus bas, cheville ou orteils, à moins de `tolerance` du plus bas du cycle). Les phases de vol de la
    course sont ainsi exclues (avant : le pied « le plus bas » en l'air faussait la course d'un facteur 2 à 3).
    C'est la valeur que le jeu doit utiliser pour régler la vitesse de lecture."""
    import statistics
    sc = bpy.context.scene
    ips = ips or sc.render.fps
    assigner(arm, action)
    debut, fin = int(action.frame_range[0]), int(action.frame_range[1])
    points = {p: [] for p in os_pieds}
    for f in range(debut, fin + 1):
        sc.frame_set(f)
        for p in os_pieds:
            pb = arm.pose.bones[p]
            points[p].append(min((arm.matrix_world @ pb.head).copy(), (arm.matrix_world @ pb.tail).copy(),
                                 key=lambda v: v.z))
    plus_bas = min(v.z for p in os_pieds for v in points[p])
    vitesses = []
    for i in range(fin - debut):
        p = min(os_pieds, key=lambda q: points[q][i].z)
        if points[p][i].z > plus_bas + tolerance or points[p][i + 1].z > plus_bas + tolerance:
            continue                                   # aucun pied au sol (vol) ou pied qui décolle
        d = points[p][i + 1] - points[p][i]
        vitesses.append(math.hypot(d.x, d.y) * ips)
    return statistics.median(vitesses) if vitesses else 0.0
