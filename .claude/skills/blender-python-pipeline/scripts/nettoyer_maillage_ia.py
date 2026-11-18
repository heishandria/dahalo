# Prépare pour le jeu un maillage issu d'un générateur image→3D (TRELLIS, Pixal3D, Tripo, Meshy…) :
# fusion des objets, soudure des sommets, suppression des débris, décimation au budget, normales lissées par angle,
# origine au sol (et hauteur réelle si demandée), dépliage UV, cuisson des couleurs de sommets en texture, export GLB.
# Lecture seule de l'entrée ; tout est fait dans une scène vide.
#
#   blender_lancer.sh nettoyer_maillage_ia.py -- entree.glb sortie.glb [--faces 20000] [--texture 1024]
#       [--hauteur 1.6] [--debris 0.02] [--angle 40] [--blend sortie.blend]
#
# --faces   : budget de triangles visé (décimation par effondrement d'arêtes)
# --texture : taille de la texture cuite (couleurs de sommets → couleur de base)
# --hauteur : hauteur réelle voulue en mètres (sinon l'échelle d'origine est gardée)
# --debris  : supprime les morceaux de moins de cette fraction des faces du plus gros
import bpy, bmesh, math, os, sys

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(args) < 2:
    raise SystemExit("ERREUR usage : -- entree.glb sortie.glb [options]")
ENTREE, SORTIE = os.path.abspath(args[0]), os.path.abspath(args[1])


def opt(nom, defaut):
    return type(defaut)(args[args.index(nom) + 1]) if nom in args else defaut


FACES = opt("--faces", 20000)
TEXTURE = opt("--texture", 1024)
HAUTEUR = opt("--hauteur", 0.0)
DEBRIS = opt("--debris", 0.02)
ANGLE = opt("--angle", 40.0)
BLEND = opt("--blend", "")


def faces(o):
    return len(o.data.polygons)


# 1. Scène vide, import.
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=ENTREE)
maillages = [o for o in bpy.context.scene.objects if o.type == 'MESH']
if not maillages:
    raise SystemExit("ERREUR aucun maillage dans " + ENTREE)
print("Entrée : %d objet(s), %d faces" % (len(maillages), sum(faces(o) for o in maillages)))

# 2. Un seul objet, transformations appliquées (le parent glTF éventuel est retiré).
bpy.ops.object.select_all(action='DESELECT')
for o in maillages:
    o.select_set(True)
bpy.context.view_layer.objects.active = maillages[0]
if len(maillages) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in list(bpy.context.scene.objects):
    if o != obj:
        bpy.data.objects.remove(o, do_unlink=True)
obj.name = os.path.splitext(os.path.basename(SORTIE))[0]

# 3. Soudure des sommets proches, faces dégénérées, débris.
bm = bmesh.new()
bm.from_mesh(obj.data)
taille = max(obj.dimensions) or 1.0
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=taille * 1e-5)
bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=taille * 1e-6)
# Composantes connexes par faces.
vues = set()
composantes = []
for f in bm.faces:
    if f.index in vues:
        continue
    pile, comp = [f], []
    vues.add(f.index)
    while pile:
        g = pile.pop()
        comp.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in vues:
                    vues.add(h.index)
                    pile.append(h)
    composantes.append(comp)
bm.faces.ensure_lookup_table()
if composantes:
    plus_grande = max(len(c) for c in composantes)
    a_supprimer = [f for c in composantes if len(c) < plus_grande * DEBRIS for f in c]
    if a_supprimer:
        bmesh.ops.delete(bm, geom=a_supprimer, context='FACES')
    print("Morceaux : %d, supprimés (débris) : %d" % (len(composantes),
          sum(1 for c in composantes if len(c) < plus_grande * DEBRIS)))
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
bm.to_mesh(obj.data)
bm.free()

# 4. Décimation au budget (triangles).
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.quads_convert_to_tris()
bpy.ops.object.mode_set(mode='OBJECT')
avant = faces(obj)
if avant > FACES:
    d = obj.modifiers.new("Decimer", 'DECIMATE')
    d.ratio = FACES / avant
    d.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=d.name)
print("Décimation : %d → %d triangles" % (avant, faces(obj)))

# 5. Normales lissées selon l'angle (arêtes vives conservées).
try:
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(ANGLE))
except AttributeError:
    bpy.ops.object.shade_smooth()

# 6. Échelle réelle et origine au sol, au centre de l'emprise.
if HAUTEUR > 0 and obj.dimensions.z > 0:
    f = HAUTEUR / obj.dimensions.z
    obj.scale = (f, f, f)
    bpy.ops.object.transform_apply(scale=True)
coins = [obj.matrix_world @ v.co for v in obj.data.vertices]
cx = (min(c.x for c in coins) + max(c.x for c in coins)) / 2
cy = (min(c.y for c in coins) + max(c.y for c in coins)) / 2
z0 = min(c.z for c in coins)
for v in obj.data.vertices:
    v.co.x -= cx
    v.co.y -= cy
    v.co.z -= z0
print("Dimensions (m) : %.3f × %.3f × %.3f" % tuple(obj.dimensions))

# 7. Dépliage UV automatique.
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
bpy.ops.object.mode_set(mode='OBJECT')

# 8. Couleurs de sommets → texture de couleur de base (cuisson Cycles, sans éclairage).
couleurs = obj.data.color_attributes
mat = bpy.data.materials.new(obj.name + "_materiau")
mat.use_nodes = True
noeuds = mat.node_tree.nodes
liens = mat.node_tree.links
bsdf = next(n for n in noeuds if n.type == 'BSDF_PRINCIPLED')
bsdf.inputs["Roughness"].default_value = 0.85
obj.data.materials.clear()
obj.data.materials.append(mat)
if len(couleurs):
    attr = couleurs.active_color or couleurs[0]
    source = noeuds.new("ShaderNodeVertexColor")
    source.layer_name = attr.name
    liens.new(source.outputs["Color"], bsdf.inputs["Base Color"])
    image = bpy.data.images.new(obj.name + "_couleur", TEXTURE, TEXTURE)
    tex = noeuds.new("ShaderNodeTexImage")
    tex.image = image
    noeuds.active = tex
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = 1
    sc.render.bake.use_pass_direct = False
    sc.render.bake.use_pass_indirect = False
    sc.render.bake.use_pass_color = True
    sc.render.bake.margin = 8
    bpy.ops.object.bake(type='DIFFUSE')
    image.filepath_raw = os.path.splitext(SORTIE)[0] + "_couleur.png"
    image.file_format = 'PNG'
    image.save()
    image.pack()
    liens.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    noeuds.remove(source)
    nom_attr = attr.name
    couleurs.remove(couleurs[nom_attr])
    print("Texture cuite : %s (%d px)" % (image.filepath_raw, TEXTURE))
else:
    print("ATTENTION aucune couleur de sommet : pas de texture cuite")

# 9. Export.
bpy.ops.object.select_all(action='DESELECT')
obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=SORTIE, export_format='GLB', use_selection=True, export_animations=False)
if BLEND:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(BLEND))
print("OK %s : %d triangles, %d matériau(x)" % (SORTIE, faces(obj), len(obj.data.materials)))
