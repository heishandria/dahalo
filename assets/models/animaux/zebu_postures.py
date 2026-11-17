# Postures ajoutées au zébu (appelé par zebu_depuis_vache.py, avant la mise à l'échelle et l'export) :
#   Zebu_brouter_loop  : tête au sol, arrache l'herbe et mâche (jambes en IK, sabots plantés)
#   Zebu_se_coucher    : passe de debout à couché (avant d'abord, comme les bovins) ; joué à l'envers pour se lever
#   Zebu_couche_loop   : couché, tête haute, rumine
#   Zebu_dort_loop     : couché, tête posée le long du flanc, respiration lente
# Repère armature Blender : avant = -Y, gauche = +X, haut = +Z (unités de la vache, avant l'échelle 0,25).
# Couché, les jambes sont posées en cinématique directe : les contraintes IK sont coupées (influence clé à 0) ;
# toutes les actions clé l'influence pour que l'export échantillonné ne garde pas la valeur d'une autre action.
import bpy, math
from mathutils import Vector, Matrix, Quaternion

arm = bpy.data.objects["Armature"]
pose = arm.pose.bones
os_ = arm.data.bones
sc = bpy.context.scene
bpy.context.view_layer.objects.active = arm
if bpy.context.mode != 'POSE':
    bpy.ops.object.mode_set(mode='POSE')

JAMBES = {  # os de la chaîne : épaule/hanche (latéral), segment haut, segment bas, sabot ; avant ?
    "AvD": ("FrontLeg.R", "FrontUpLeg.R", "FrontLowLeg.R", "FrontFoot.R", True, -1),
    "AvG": ("FrontLeg.L", "FrontUpLeg.L", "FrontLowLeg.L", "FrontFoot.L", True, 1),
    "ArD": ("BackLeg.R", "BackUpLeg.R", "BackLowLeg.R", "BackFoot.R", False, -1),
    "ArG": ("BackLeg.L", "BackUpLeg.L", "BackLowLeg.L", "BackFoot.L", False, 1),
}
DESCENTE = 1.85     # le corps descend de 1,85 unité (0,46 m) : ventre au sol


def lisse(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def rot_repos(n):
    return os_[n].matrix_local.to_3x3()


def dir_repos(n):
    return (os_[n].tail_local - os_[n].head_local).normalized()


def longueur(n):
    return (os_[n].tail_local - os_[n].head_local).length


def placer(nom, tete, rotation):
    """Pose un os en espace armature : tête en `tete`, rotation (3x3) appliquée à son orientation de repos."""
    pose[nom].matrix = Matrix.Translation(tete) @ (rotation @ rot_repos(nom)).to_4x4()
    bpy.context.view_layer.update()


def orienter(nom, direction):
    """Tourne un os (tête fixe, là où son parent l'a mis) vers `direction` ; rend la rotation appliquée."""
    q = dir_repos(nom).rotation_difference(direction.normalized()).to_matrix()
    placer(nom, pose[nom].head.copy(), q)
    return q


def angle_repos(n):
    """Angle du segment depuis la verticale descendante, positif vers l'avant (-Y)."""
    d = dir_repos(n)
    return math.atan2(-d.y, -d.z)


def direction(theta, ecart, cote):
    """Direction d'un segment : angle `theta` depuis la verticale (vers l'avant si > 0), écarté vers l'extérieur."""
    d = Vector((0.0, -math.sin(theta), -math.cos(theta)))
    return Matrix.Rotation(-cote * ecart, 3, 'Y') @ d


def remise_a_zero():
    for pb in pose:
        pb.location = (0, 0, 0)
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def ik(influence):
    for pb in pose:
        for c in pb.constraints:
            if c.type == 'IK':
                c.influence = influence


def incliner_corps(descente_avant, descente_arriere, tangage_tete=0.0):
    """Abaisse et incline le corps (os Body) pour que l'avant descende de `descente_avant` et l'arrière de
    `descente_arriere` (épaules à y = -1,86, hanches à y = 2,2)."""
    ecart = 4.06
    angle = math.atan2(descente_avant - descente_arriere, ecart)   # > 0 : l'avant plonge
    centre_y = os_["Body"].head_local.y
    t = (centre_y + 1.86) / ecart
    descente = descente_avant + (descente_arriere - descente_avant) * t
    placer("Body", os_["Body"].head_local + Vector((0, 0, -descente)), Matrix.Rotation(angle, 3, 'X'))


def jambe(cle, t, ecart=0.0):
    """Jambe de debout (t = 0) à repliée sous le corps (t = 1) : le sabot suit un chemin au sol, la jambe est
    résolue en IK analytique à deux segments (genou vers l'avant pour l'avant, jarret vers l'arrière)."""
    lat, haut, bas, sabot, avant, cote = JAMBES[cle]
    debout = os_[bas].tail_local.copy()
    if avant:
        replie = Vector((debout.x, -1.0, 0.18))            # canon replié sous le poitrail, genou au sol devant
    else:
        replie = Vector((debout.x + cote * ecart, 1.55, 0.18))   # canon ramené sous le ventre, jarret au sol
    cible = debout.lerp(replie, t)
    cible.z += (0.3 if avant else 0.1) * math.sin(math.pi * t)   # le pied se soulève en se repliant
    hanche = pose[haut].head.copy()
    l1, l2 = longueur(haut), longueur(bas)
    v = cible - hanche
    d = max(min(v.length, l1 + l2 - 1e-4), abs(l1 - l2) + 1e-4)
    axe = v.normalized()
    pli = Vector((0, -1, 0)) if avant else Vector((0, 1, 0))
    perp = (pli - axe * pli.dot(axe)).normalized()
    a = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    genou = hanche + axe * a + perp * h
    orienter(haut, genou - hanche)
    q = orienter(bas, hanche + axe * d - genou)
    # Le sabot (os indépendant, enfant de la racine) suit le bout du canon.
    placer(sabot, pose[bas].tail.copy(), q)


def tete(cou_tangage, tete_tangage, cou_lacet=0.0, tete_lacet=0.0, garrot=0.0):
    """Rotations locales du garrot, du cou et de la tête (radians ; tangage > 0 : vers le bas)."""
    def loc(nom, axe, angle):
        return Quaternion(rot_repos(nom).inverted() @ Vector(axe), angle)
    pose["Shoulders"].rotation_quaternion = loc("Shoulders", (1, 0, 0), garrot)
    pose["Neck"].rotation_quaternion = loc("Neck", (0, 0, 1), cou_lacet) @ loc("Neck", (1, 0, 0), cou_tangage)
    pose["Head"].rotation_quaternion = loc("Head", (0, 0, 1), tete_lacet) @ loc("Head", (1, 0, 0), tete_tangage)
    bpy.context.view_layer.update()


def museau_a(z_cible, garrot, part_tete, cou_lacet=0.0, tete_lacet=0.0, mini=-0.3, maxi=1.6):
    """Trouve l'inclinaison du cou qui pose le museau (bout de l'os Head) à la hauteur `z_cible` ; la tête
    s'incline de `part_tete` fois l'angle du cou. Rend (cou, tête)."""
    for _ in range(30):
        milieu = (mini + maxi) / 2
        tete(milieu, milieu * part_tete, cou_lacet, tete_lacet, garrot)
        if pose["Head"].tail.z > z_cible:
            mini = milieu
        else:
            maxi = milieu
    return milieu, milieu * part_tete


def queue(phase, ampleur):
    for k, nom in enumerate(("Tail2", "Tail3", "Tail4")):
        a = ampleur * math.sin(2 * math.pi * phase - k * 0.7)
        pose[nom].rotation_quaternion = Quaternion(rot_repos(nom).inverted() @ Vector((0, 0, 1)), a)


def respiration(phase, ampleur=0.025):
    s = 1.0 + ampleur * (0.5 + 0.5 * math.sin(2 * math.pi * phase))
    for nom in ("Torso", "Hips"):
        pose[nom].scale = (s, 1.0, s)


def cles(action, image):
    for pb in pose:
        pb.keyframe_insert("location", frame=image)
        pb.keyframe_insert("rotation_quaternion", frame=image)
        pb.keyframe_insert("scale", frame=image)
        for c in pb.constraints:
            if c.type == 'IK':
                c.keyframe_insert("influence", frame=image)


def nouvelle(nom):
    a = bpy.data.actions.new(nom)
    a.use_fake_user = True
    arm.animation_data.action = a
    return a


def couche(t_avant, t_arriere, ecart_ar=0.0):
    """Corps et jambes pour une descente partielle (0 = debout, 1 = couché)."""
    incliner_corps(DESCENTE * lisse(t_avant), DESCENTE * lisse(t_arriere))
    for cle in ("AvD", "AvG"):
        jambe(cle, lisse(t_avant))
    # Une jambe arrière s'écarte sur le côté (le zébu se couche un peu de travers).
    jambe("ArD", lisse(t_arriere), ecart_ar)
    jambe("ArG", lisse(t_arriere), 0.0)


# --- 1. Brouter (4 s, 24 images/s) : jambes en IK, sabots au repos ---
IMAGES_BROUTER = 96
nouvelle("Zebu_brouter_loop")
for image in range(IMAGES_BROUTER + 1):
    p = image / IMAGES_BROUTER
    remise_a_zero()
    ik(1.0)
    w = 2 * math.pi * p
    incliner_corps(0.3, 0.0)
    # Museau au sol ; deux coups de tête de côté (arracher l'herbe), puis mastication tête basse.
    arrache = math.sin(2 * w) * lisse(1 - abs(p - 0.25) * 4) * 0.12
    mache = 0.035 * math.sin(6 * w)
    # La tête hérite du cou : elle se relève par rapport à lui (part négative) pour que le mufle aille devant.
    cou, tet = museau_a(0.4 + 0.12 * lisse(abs(math.sin(w))), math.radians(14), -0.45, cou_lacet=arrache, maxi=2.2)
    tete(cou, tet + mache, cou_lacet=arrache, garrot=math.radians(14))
    queue(p * 2, 0.25)
    cles(None, image + 1)

# --- 2. Se coucher (2,5 s) : l'avant s'agenouille, puis l'arrière se pose ---
IMAGES_COUCHER = 60
nouvelle("Zebu_se_coucher")
for image in range(IMAGES_COUCHER + 1):
    p = image / IMAGES_COUCHER
    remise_a_zero()
    ik(0.0)
    couche(p / 0.55, (p - 0.35) / 0.65, 0.45)
    tete(math.radians(-8) * math.sin(math.pi * p), 0.0)
    queue(p, 0.1)
    cles(None, image + 1)


def pose_couchee():
    remise_a_zero()
    ik(0.0)
    couche(1.0, 1.0, 0.45)


# --- 3. Couché, rumine (4 s) ---
IMAGES_COUCHE = 96
nouvelle("Zebu_couche_loop")
for image in range(IMAGES_COUCHE + 1):
    p = image / IMAGES_COUCHE
    pose_couchee()
    w = 2 * math.pi * p
    mache = 0.04 * math.sin(10 * w)
    tete(math.radians(4) + 0.03 * math.sin(w), mache, cou_lacet=0.08 * math.sin(w))
    respiration(p * 2)
    queue(p, 0.08)
    cles(None, image + 1)

# --- 4. Couché, dort (6 s) : tête ramenée le long du flanc ---
IMAGES_DORT = 144
nouvelle("Zebu_dort_loop")
for image in range(IMAGES_DORT + 1):
    p = image / IMAGES_DORT
    pose_couchee()
    # Menton posé au sol, tête un peu tournée.
    museau_a(0.3, math.radians(8), -0.55, cou_lacet=math.radians(22), tete_lacet=math.radians(12), maxi=2.2)
    respiration(p * 2, 0.035)
    cles(None, image + 1)

# --- 5. Les actions d'origine gardent l'IK active (clé d'influence à 1) ---
for nom in ("Zebu_repos_loop", "Zebu_marche_loop", "Zebu_course_loop"):
    a = bpy.data.actions.get(nom)
    if a:
        arm.animation_data.action = a
        ik(1.0)
        debut = int(a.frame_range[0])
        for pb in pose:
            for c in pb.constraints:
                if c.type == 'IK':
                    c.keyframe_insert("influence", frame=debut)

# Interpolation linéaire pour les actions calculées image par image.
def courbes(a):
    try:
        return list(a.fcurves)
    except AttributeError:
        r = []
        for couche_ in a.layers:
            for bande in couche_.strips:
                for cb in bande.channelbags:
                    r += list(cb.fcurves)
        return r

for nom in ("Zebu_brouter_loop", "Zebu_se_coucher", "Zebu_couche_loop", "Zebu_dort_loop"):
    for fc in courbes(bpy.data.actions[nom]):
        for k in fc.keyframe_points:
            k.interpolation = 'LINEAR'

remise_a_zero()
ik(1.0)
arm.animation_data.action = bpy.data.actions["Zebu_repos_loop"]
bpy.ops.object.mode_set(mode='OBJECT')
print("POSTURES OK")
