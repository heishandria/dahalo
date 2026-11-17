# Transforme la vache du « Farm Animals Pack » de Quaternius (CC0) en zébu malgache (omby) :
# bosse graisseuse sur le garrot, fanon sous le cou, pis retiré, oreilles tombantes, cornes en lyre, corps affiné,
# maillage lissé ; robe en couleurs de sommets (teintée par zébu dans le jeu). Squelette et animations conservés :
# Idle -> Zebu_repos_loop, Walk -> Zebu_marche_loop, Run -> Zebu_course_loop (Death et Jump retirés : le zébu
# n'est jamais tué dans le jeu) ; postures ajoutées par zebu_postures.py. Échelle réelle ~2,3 m de long. Usage :
#   Blender -b Cow.blend --python zebu.py -- sortie.glb sortie.blend
import bpy, bmesh, math, sys
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index("--") + 1:]
SORTIE_GLB, SORTIE_BLEND = args[0], args[1]
ECHELLE = 0.25

arm = bpy.data.objects["Armature"]
corps = bpy.data.objects["Cow"]
mats = {m.name: i for i, m in enumerate(corps.data.materials)}

def principled(mat):
    """Nœud Principled BSDF du matériau (créé s'il manque)."""
    mat.use_nodes = True
    arbre = mat.node_tree
    for n in arbre.nodes:
        if n.type == 'BSDF_PRINCIPLED':
            return n
    n = arbre.nodes.new("ShaderNodeBsdfPrincipled")
    sortie = next((x for x in arbre.nodes if x.type == 'OUTPUT_MATERIAL'), None) or arbre.nodes.new("ShaderNodeOutputMaterial")
    arbre.links.new(n.outputs["BSDF"], sortie.inputs["Surface"])
    return n


def gauss(d, s):
    return math.exp(-(d / s) ** 2)

def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)

# --- 1. Lisser d'abord (une subdivision) : plus organique, et assez de sommets pour sculpter ---
bpy.context.view_layer.objects.active = corps
sub = corps.modifiers.new("Lisser", 'SUBSURF')
sub.levels = 1
sub.render_levels = 1
bpy.ops.object.modifier_move_to_index(modifier="Lisser", index=0)
bpy.ops.object.modifier_apply(modifier="Lisser")

me = corps.data
bm = bmesh.new()
bm.from_mesh(me)
bm.verts.ensure_lookup_table()
rose = mats.get("Pink", -1)
noir = mats.get("Black", -1)

# Sommets du pis (faces roses en arrière du ventre) et du nez (faces roses à la tête).
pis = set()
for f in bm.faces:
    if f.material_index == rose:
        c = f.calc_center_median()
        if c.y > -3.0:
            for v in f.verts:
                pis.add(v.index)
            f.material_index = mats["White"]

for v in bm.verts:
    p = v.co
    x, y, z = p.x, p.y, p.z
    # Corps plus fin (le zébu est plus sec qu'une vache laitière), sauf la tête.
    if y > -3.4:
        p.x *= 0.86
    # Pis rentré dans le ventre.
    if v.index in pis:
        p.z = max(p.z, 2.55)
        p.x *= 0.6
    # Bosse : graisse sur le garrot, juste en arrière du cou, un peu penchée vers l'avant.
    if z > 3.2:
        h = 1.15 * gauss(y + 1.75, 0.62) * gauss(x / 0.86, 0.62) * smooth(3.2, 3.9, z)
        p.z += h
        p.y -= 0.18 * h
    # Fanon : peau pendante sous le cou et le poitrail.
    if -4.2 < y < -1.4 and z < 3.6 and abs(x) < 0.55:
        bas = smooth(3.6, 2.3, z)
        p.z -= 0.75 * gauss(y + 2.9, 0.75) * gauss(x, 0.32) * bas
        p.x *= 1.0 - 0.45 * gauss(y + 2.9, 0.9) * bas   # fin, comme un repli de peau
    # Oreilles tombantes : les sommets latéraux de la tête descendent et partent un peu vers l'arrière.
    if y < -3.4 and z > 4.1 and abs(x) > 0.62:
        ecart = abs(x) - 0.62
        p.z -= ecart * 1.4
        p.y += ecart * 0.25
        p.x = math.copysign(0.62 + ecart * 0.75, x)

bm.to_mesh(me)
bm.free()

# --- 2. Cornes en lyre, rattachées à l'os de la tête ---
cornes = bmesh.new()
for cote in (-1.0, 1.0):
    base = Vector((0.38 * cote, -3.95, 4.95))
    points = []
    n = 7
    for k in range(n + 1):
        t = k / n
        # Vers l'extérieur, puis vers le haut, la pointe revenant un peu vers l'intérieur et l'avant (lyre).
        points.append(base + Vector((cote * (0.55 * math.sin(t * 2.2)), -0.25 * t, 1.25 * t * t + 0.25 * t)))
    anneaux = []
    for k, c in enumerate(points):
        r = 0.17 * (1 - k / (n + 0.3))
        d = (points[min(k + 1, n)] - points[max(k - 1, 0)]).normalized()
        a = d.cross(Vector((0, 1, 0))).normalized()
        b = d.cross(a)
        anneaux.append([cornes.verts.new(c + (a * math.cos(s * math.tau / 6) + b * math.sin(s * math.tau / 6)) * r) for s in range(6)])
    for k in range(n):
        for s in range(6):
            cornes.faces.new((anneaux[k][s], anneaux[k][(s + 1) % 6], anneaux[k + 1][(s + 1) % 6], anneaux[k + 1][s]))
me_cornes = bpy.data.meshes.new("Cornes")
cornes.to_mesh(me_cornes)
cornes.free()
ob_cornes = bpy.data.objects.new("Cornes", me_cornes)
bpy.context.scene.collection.objects.link(ob_cornes)
mat_corne = bpy.data.materials.new("Corne")
mat_corne.diffuse_color = (0.85, 0.8, 0.68, 1)
principled(mat_corne).inputs["Base Color"].default_value = (0.75, 0.7, 0.58, 1)
me_cornes.materials.append(mat_corne)
groupe = ob_cornes.vertex_groups.new(name="Head")
groupe.add(list(range(len(me_cornes.vertices))), 1.0, 'REPLACE')
bpy.ops.object.select_all(action='DESELECT')
ob_cornes.select_set(True)
corps.select_set(True)
bpy.context.view_layer.objects.active = corps
bpy.ops.object.join()

# --- 3. Robe : un matériau « Robe » blanc teinté par couleurs de sommets (ombrages naturels), sabots et mufle
#        sombres, cornes ivoire. La couleur de la robe est donnée par zébu dans le jeu. ---
me = corps.data
robe = bpy.data.materials.new("Robe")
bsdf = principled(robe)
attr = robe.node_tree.nodes.new("ShaderNodeVertexColor")
attr.layer_name = "Teinte"
robe.node_tree.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.8
sombre = bpy.data.materials.new("Sabots")
principled(sombre).inputs["Base Color"].default_value = (0.05, 0.045, 0.04, 1)
me.materials.clear()
me.materials.append(robe)
me.materials.append(sombre)
me.materials.append(mat_corne)
teinte = me.color_attributes.new("Teinte", 'FLOAT_COLOR', 'POINT')
for f in me.polygons:
    c = f.center
    ancien = f.material_index
    if f.vertices[0] >= len(me.vertices) - 2 * 8 * 6:
        f.material_index = 2   # cornes (derniers sommets ajoutés)
    elif c.z < 0.45 or (c.y < -5.1 and c.z < 4.3):
        f.material_index = 1   # sabots, mufle
    else:
        f.material_index = 0
for v in me.vertices:
    p = v.co
    # Plus sombre sur la bosse, le cou et le bas des pattes ; ventre un peu plus clair.
    k = 1.0
    k -= 0.28 * gauss(p.y + 1.8, 1.0) * smooth(3.6, 4.6, p.z)
    k -= 0.22 * smooth(-1.5, -3.8, p.y) * smooth(3.0, 4.3, p.z)
    k -= 0.3 * smooth(1.3, 0.4, p.z)
    k += 0.08 * smooth(2.8, 2.2, p.z) * smooth(1.3, 2.0, p.z)
    k = max(0.35, min(1.0, k))
    teinte.data[v.index].color = (k, k, k, 1.0)
# Position de repos de chaque sommet (en mètres, échelle réelle) dans deux jeux de coordonnées de texture :
# UV1 = (y, z), UV2 = (x, 0). Le motif de la robe (taches) est calculé dans le jeu à partir de cette position :
# il suit l'animal quand il bouge.
for nom in [c.name for c in me.color_attributes if c.name != "Teinte"]:
    me.color_attributes.remove(me.color_attributes[nom])
while me.uv_layers:
    me.uv_layers.remove(me.uv_layers[0])
uv_yz = me.uv_layers.new(name="Repos_yz")
uv_x = me.uv_layers.new(name="Repos_x")
for boucle in me.loops:
    p = me.vertices[boucle.vertex_index].co * ECHELLE
    uv_yz.data[boucle.index].uv = (p.y, p.z)
    uv_x.data[boucle.index].uv = (p.x, 0.0)
for p in me.polygons:
    p.use_smooth = True

# --- 4. Animations ---
for nom in ("Death", "Jump", "WalkSlow"):
    a = bpy.data.actions.get(nom)
    if a:
        bpy.data.actions.remove(a)
for ancien, nouveau in (("Idle", "Zebu_repos_loop"), ("Walk", "Zebu_marche_loop"), ("Run", "Zebu_course_loop")):
    a = bpy.data.actions[ancien]
    a.name = nouveau
    a.use_fake_user = True

# Vitesse du pied au sol (pour caler l'animation sur la vitesse de déplacement dans le jeu).
sc = bpy.context.scene
for nom in ("Zebu_marche_loop", "Zebu_course_loop"):
    arm.animation_data.action = bpy.data.actions[nom]
    debut, fin = [int(x) for x in bpy.data.actions[nom].frame_range]
    ys, zs = [], []
    for image in range(debut, fin + 1):
        sc.frame_set(image)
        p = arm.matrix_world @ arm.pose.bones["FrontFoot.L"].head
        ys.append(p.y); zs.append(p.z)
    zmin = min(zs)
    vitesses = [(ys[i + 1] - ys[i]) * sc.render.fps for i in range(len(ys) - 1) if zs[i] < zmin + 0.08 and zs[i + 1] < zmin + 0.08]
    racine = arm.matrix_world @ arm.pose.bones["root"].head
    print("CALAGE %s : %d images, pied au sol %.2f m/s (échelle réelle), foulée %.2f m" % (
        nom, fin - debut, (sum(vitesses) / max(len(vitesses), 1)) * ECHELLE, (max(ys) - min(ys)) * ECHELLE))
arm.animation_data.action = bpy.data.actions["Zebu_repos_loop"]

# Postures ajoutées : brouter, se coucher (et se lever, à l'envers), couché, dormir (voir zebu_postures.py).
import os
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "zebu_postures.py")).read())

# --- 5. Échelle réelle et export ---
arm.scale = (ECHELLE, ECHELLE, ECHELLE)
bpy.ops.object.select_all(action='DESELECT')
corps.select_set(True)
arm.select_set(True)
me.calc_loop_triangles()
print("TRIANGLES", len(me.loop_triangles))
# Échantillonnage obligatoire : les jambes de la vache sont pilotées par des contraintes IK (os *LowLeg -> *Foot) ;
# sans échantillonnage, seules les cibles des sabots sont exportées et les jambes restent raides dans le jeu.
bpy.ops.export_scene.gltf(filepath=SORTIE_GLB, export_format='GLB', use_selection=True, export_animations=True,
        export_animation_mode='ACTIONS', export_optimize_animation_size=True, export_force_sampling=True,
        export_bake_animation=False)
bpy.ops.wm.save_as_mainfile(filepath=SORTIE_BLEND)
print("EXPORT OK")
