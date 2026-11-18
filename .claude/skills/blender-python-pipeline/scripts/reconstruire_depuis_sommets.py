"""Reconstruire une surface depuis POSITION/COLOR_0 d'un GLB.

Usage :
    blender_lancer.sh reconstruire_depuis_sommets.py -- \
        --source nuage.glb --sortie surface.glb [--voxel 0.004] [--rayon 0.004]
        [--seuil 0.1] [--max-voxels 8000000]

Le GLB source doit contenir un unique mesh, une primitive TRIANGLES et des attributs
POSITION et COLOR_0 FLOAT/VEC3 dans un buffer embarqué. Tous les sommets, y compris
ceux non référencés par les triangles existants, sont utilisés comme nuage de points.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
import numpy as np


NOM_COULEUR_SOURCE = "Couleur_source"
NOM_COULEUR_SURFACE = "Couleur_reconstruite"


def lire_glb(chemin: Path) -> tuple[dict, bytes, str]:
    donnees = chemin.read_bytes()
    if len(donnees) < 20:
        raise ValueError("Le fichier est trop court pour être un GLB 2.0.")
    magie, version, longueur = struct.unpack_from("<4sII", donnees)
    if magie != b"glTF" or version != 2 or longueur != len(donnees):
        raise ValueError("Un GLB 2.0 valide est requis.")

    gltf = None
    binaire = None
    decalage = 12
    while decalage < longueur:
        if decalage + 8 > longueur:
            raise ValueError("En-tête de chunk tronqué.")
        taille, type_chunk = struct.unpack_from("<I4s", donnees, decalage)
        debut = decalage + 8
        fin = debut + taille
        if taille % 4 or fin > longueur:
            raise ValueError("Taille de chunk GLB invalide.")
        if type_chunk == b"JSON" and gltf is None:
            gltf = json.loads(donnees[debut:fin].decode("utf-8"))
        elif type_chunk == b"BIN\x00" and binaire is None:
            binaire = donnees[debut:fin]
        decalage = fin

    if not isinstance(gltf, dict) or binaire is None:
        raise ValueError("Le GLB doit contenir un chunk JSON et un buffer BIN embarqué.")
    if gltf.get("asset", {}).get("version") != "2.0":
        raise ValueError("Document glTF 2.0 attendu.")
    if len(gltf.get("buffers", [])) != 1 or "uri" in gltf["buffers"][0]:
        raise ValueError("Un unique buffer BIN embarqué est requis.")

    maillages = gltf.get("meshes", [])
    if len(maillages) != 1 or len(maillages[0].get("primitives", [])) != 1:
        raise ValueError("Le GLB doit contenir un seul mesh et une seule primitive.")
    primitive = maillages[0]["primitives"][0]
    if primitive.get("mode", 4) != 4:
        raise ValueError("La primitive source doit être en mode TRIANGLES.")
    references_noeud = [noeud for noeud in gltf.get("nodes", [])
                        if noeud.get("mesh") == 0]
    if len(references_noeud) != 1:
        raise ValueError("Un seul noeud doit référencer le mesh.")
    noeud = references_noeud[0]
    if any(cle in noeud for cle in ("matrix", "translation", "rotation", "scale")):
        raise ValueError("Les transformations du noeud ne sont pas prises en charge.")

    attributs = primitive.get("attributes", {})
    if "POSITION" not in attributs or "COLOR_0" not in attributs:
        raise ValueError("Les attributs POSITION et COLOR_0 sont requis.")
    return gltf, binaire, hashlib.sha256(donnees).hexdigest()


def lire_attribut(gltf: dict, binaire: bytes, reference: int, role: str) -> np.ndarray:
    accessors = gltf.get("accessors", [])
    vues = gltf.get("bufferViews", [])
    if type(reference) is not int or not 0 <= reference < len(accessors):
        raise ValueError(f"Accessor {role} invalide.")
    accessor = accessors[reference]
    if accessor.get("type") != "VEC3" or accessor.get("componentType") != 5126:
        raise ValueError(f"{role} doit être un attribut FLOAT/VEC3.")
    if accessor.get("normalized", False) or "sparse" in accessor:
        raise ValueError(f"{role} normalisé ou sparse non pris en charge.")
    reference_vue = accessor.get("bufferView")
    if type(reference_vue) is not int or not 0 <= reference_vue < len(vues):
        raise ValueError(f"BufferView {role} invalide.")
    vue = vues[reference_vue]
    if vue.get("buffer") != 0:
        raise ValueError(f"{role} doit utiliser le buffer BIN embarqué.")
    compte = accessor.get("count")
    if type(compte) is not int or compte < 1:
        raise ValueError(f"Nombre d'éléments {role} invalide.")
    pas = vue.get("byteStride", 12)
    if pas < 12:
        raise ValueError(f"Pas de données {role} trop court.")
    debut_vue = vue.get("byteOffset", 0)
    debut = debut_vue + accessor.get("byteOffset", 0)
    fin = debut + (compte - 1) * pas + 12
    limite_vue = debut_vue + vue.get("byteLength", 0)
    if debut < debut_vue or fin > limite_vue or fin > len(binaire):
        raise ValueError(f"Données {role} hors limites du buffer.")
    return np.ndarray((compte, 3), dtype="<f4", buffer=binaire,
                      offset=debut, strides=(pas, 4))


def construire_groupe(nom_attribut: str, voxel: float, rayon: float,
                      etendue_maximale: float, seuil: float) -> bpy.types.NodeTree:
    groupe = bpy.data.node_groups.new("Reconstruction_points_volume", "GeometryNodeTree")
    groupe.interface.new_socket(name="Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    groupe.interface.new_socket(name="Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    noeuds = groupe.nodes
    liens = groupe.links
    entree = noeuds.new("NodeGroupInput")
    sortie = noeuds.new("NodeGroupOutput")
    sortie.is_active_output = True

    points = noeuds.new("GeometryNodeMeshToPoints")
    points.mode = "VERTICES"
    volume = noeuds.new("GeometryNodePointsToVolume")
    volume.inputs["Density"].default_value = 1.0
    volume.inputs["Voxel Amount"].default_value = math.ceil(etendue_maximale / voxel)
    volume.inputs["Radius"].default_value = rayon
    surface = noeuds.new("GeometryNodeVolumeToMesh")
    surface.inputs["Voxel Size"].default_value = voxel
    surface.inputs["Threshold"].default_value = seuil

    position = noeuds.new("GeometryNodeInputPosition")
    plus_proche = noeuds.new("GeometryNodeSampleNearest")
    valeur = noeuds.new("GeometryNodeSampleIndex")
    valeur.data_type = "FLOAT_COLOR"
    couleur = noeuds.new("GeometryNodeInputNamedAttribute")
    couleur.data_type = "FLOAT_COLOR"
    couleur.inputs["Name"].default_value = nom_attribut
    stocker = noeuds.new("GeometryNodeStoreNamedAttribute")
    stocker.data_type = "FLOAT_COLOR"
    stocker.domain = "POINT"
    stocker.inputs["Name"].default_value = NOM_COULEUR_SURFACE

    liens.new(entree.outputs["Geometry"], points.inputs["Mesh"])
    liens.new(points.outputs["Points"], volume.inputs["Points"])
    liens.new(volume.outputs["Volume"], surface.inputs["Volume"])
    liens.new(points.outputs["Points"], plus_proche.inputs["Geometry"])
    liens.new(position.outputs["Position"], plus_proche.inputs["Sample Position"])
    liens.new(points.outputs["Points"], valeur.inputs["Geometry"])
    liens.new(couleur.outputs["Attribute"], valeur.inputs["Value"])
    liens.new(plus_proche.outputs["Index"], valeur.inputs["Index"])
    liens.new(surface.outputs["Mesh"], stocker.inputs["Geometry"])
    liens.new(valeur.outputs["Value"], stocker.inputs["Value"])
    liens.new(stocker.outputs["Geometry"], sortie.inputs["Geometry"])
    return groupe


def creer_materiau(nom: str) -> bpy.types.Material:
    materiau = bpy.data.materials.new(nom)
    materiau.diffuse_color = (1.0, 1.0, 1.0, 1.0)
    materiau.use_nodes = True
    noeuds = materiau.node_tree.nodes
    bsdf = next(noeud for noeud in noeuds if noeud.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.85
    couleur = noeuds.new("ShaderNodeVertexColor")
    couleur.layer_name = NOM_COULEUR_SURFACE
    materiau.node_tree.links.new(couleur.outputs["Color"], bsdf.inputs["Base Color"])
    return materiau


def reconstruire() -> None:
    analyseur = argparse.ArgumentParser(description=__doc__)
    analyseur.add_argument("--source", type=Path, required=True)
    analyseur.add_argument("--sortie", type=Path, required=True)
    analyseur.add_argument("--voxel", type=float, default=0.004)
    analyseur.add_argument("--rayon", type=float, default=0.004)
    analyseur.add_argument("--seuil", type=float, default=0.1)
    analyseur.add_argument("--max-voxels", type=int, default=8_000_000)
    args = analyseur.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])

    source = args.source.resolve()
    sortie = args.sortie.resolve()
    if not source.is_file() or source.suffix.lower() != ".glb":
        raise ValueError(f"Source GLB introuvable : {source}")
    if sortie.suffix.lower() != ".glb" or sortie == source or sortie.exists():
        raise ValueError("La sortie doit être un nouveau fichier GLB, distinct de la source.")
    if not all(math.isfinite(v) and v > 0 for v in (args.voxel, args.rayon)):
        raise ValueError("Le voxel et le rayon doivent être strictement positifs et finis.")
    if not math.isfinite(args.seuil) or not 0 < args.seuil < 1:
        raise ValueError("Le seuil doit être compris entre 0 et 1.")
    if args.max_voxels < 1:
        raise ValueError("--max-voxels doit être positif.")

    gltf, binaire, empreinte_source = lire_glb(source)
    primitive = gltf["meshes"][0]["primitives"][0]
    attributs = primitive["attributes"]
    positions = lire_attribut(gltf, binaire, attributs["POSITION"], "POSITION")
    couleurs = lire_attribut(gltf, binaire, attributs["COLOR_0"], "COLOR_0")
    if len(positions) != len(couleurs):
        raise ValueError("POSITION et COLOR_0 n'ont pas le même nombre de sommets.")
    if not np.isfinite(positions).all() or not np.isfinite(couleurs).all():
        raise ValueError("Les positions ou couleurs contiennent des valeurs non finies.")
    if np.any(couleurs < 0) or np.any(couleurs > 1):
        raise ValueError("Les composantes COLOR_0 doivent être dans [0, 1].")

    minimum = positions.min(axis=0)
    maximum = positions.max(axis=0)
    etendue_maximale = float(np.max(maximum - minimum))
    if not math.isfinite(etendue_maximale) or etendue_maximale <= 0:
        raise ValueError("Nuage de points de dimension nulle.")
    dimensions_grille = np.ceil((maximum - minimum + 2 * args.rayon) / args.voxel).astype(np.int64)
    nombre_voxels = math.prod(int(dimension) for dimension in dimensions_grille)
    if nombre_voxels > args.max_voxels:
        raise ValueError(f"Grille estimée à {nombre_voxels:,} voxels, au-dessus de "
                         f"--max-voxels {args.max_voxels:,}; augmentez --voxel.")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    maillage = bpy.data.meshes.new("Nuage_source")
    maillage.vertices.add(len(positions))
    maillage.vertices.foreach_set("co", positions.reshape(-1))
    attribut_couleur = maillage.color_attributes.new(
        name=NOM_COULEUR_SOURCE, type="FLOAT_COLOR", domain="POINT")
    couleurs_rgba = np.ones((len(couleurs), 4), dtype=np.float32)
    couleurs_rgba[:, :3] = couleurs
    attribut_couleur.data.foreach_set("color", couleurs_rgba.reshape(-1))
    objet = bpy.data.objects.new("Nuage_source", maillage)
    bpy.context.scene.collection.objects.link(objet)

    groupe = construire_groupe(NOM_COULEUR_SOURCE, args.voxel, args.rayon,
                               etendue_maximale, args.seuil)
    modificateur = objet.modifiers.new("Reconstruction_points_volume", "NODES")
    modificateur.node_group = groupe
    graphe = bpy.context.evaluated_depsgraph_get()
    graphe.update()
    evalue = objet.evaluated_get(graphe)
    maillage_temporaire = evalue.to_mesh(preserve_all_data_layers=True, depsgraph=graphe)
    try:
        if not maillage_temporaire.vertices or not maillage_temporaire.polygons:
            raise RuntimeError("La reconstruction n'a produit aucune surface.")
        if NOM_COULEUR_SURFACE not in maillage_temporaire.color_attributes:
            raise RuntimeError("L'attribut couleur n'a pas été transféré sur la surface.")
        maillage_final = maillage_temporaire.copy()
    finally:
        evalue.to_mesh_clear()

    couleurs_finales = maillage_final.color_attributes[NOM_COULEUR_SURFACE]
    controle_couleurs = np.empty((len(couleurs_finales.data), 4), dtype=np.float32)
    couleurs_finales.data.foreach_get("color", controle_couleurs.reshape(-1))
    if not np.isfinite(controle_couleurs).all():
        raise RuntimeError("Le transfert a produit des couleurs non finies.")
    if float(controle_couleurs[:, :3].std()) < 0.001:
        raise RuntimeError("Le transfert a produit des couleurs quasi uniformes.")

    bpy.data.objects.remove(objet, do_unlink=True)
    sortie_objet = bpy.data.objects.new("Surface_reconstruite", maillage_final)
    bpy.context.scene.collection.objects.link(sortie_objet)
    for polygone in maillage_final.polygons:
        polygone.use_smooth = True
        polygone.material_index = 0
    maillage_final.materials.clear()
    sortie_objet.data.materials.append(creer_materiau("Materiau_couleur_transferee"))
    if len(sortie_objet.material_slots) != 1 or sortie_objet.active_material is None:
        raise RuntimeError("Le matériau de reconstruction n'est pas assigné au maillage.")
    bpy.context.view_layer.objects.active = sortie_objet
    sortie_objet.select_set(True)

    sortie.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(sortie), export_format="GLB", use_selection=True,
        export_animations=False, export_materials="EXPORT")

    gltf_sortie, _, _ = lire_glb(sortie)
    primitive_sortie = gltf_sortie["meshes"][0]["primitives"][0]
    attributs_sortie = primitive_sortie["attributes"]
    if "COLOR_0" not in attributs_sortie:
        raise RuntimeError("Le GLB exporté ne contient pas l'attribut COLOR_0.")
    if "material" not in primitive_sortie:
        raise RuntimeError("Le GLB exporté ne contient pas le matériau PBR de la surface.")
    if gltf_sortie["accessors"][attributs_sortie["COLOR_0"]]["count"] != len(maillage_final.vertices):
        raise RuntimeError("Le nombre de couleurs exportées ne correspond pas au nombre de sommets.")
    if hashlib.sha256(source.read_bytes()).hexdigest() != empreinte_source:
        raise RuntimeError("L'empreinte de la source a changé.")

    print(f"OK Blender : {bpy.app.version_string}")
    print(f"OK points utilisés : {len(positions):,}")
    print(f"OK reconstruction : {len(maillage_final.vertices):,} sommets, "
          f"{len(maillage_final.polygons):,} faces")
    print(f"OK grille estimée : {nombre_voxels:,} voxels")
    print(f"OK transfert COLOR_0 : moyenne RGB {controle_couleurs[:, :3].mean(axis=0)}")
    print(f"OK source inchangée SHA256 : {empreinte_source}")
    print(f"OK GLB exporté avec COLOR_0 : {sortie}")


if __name__ == "__main__":
    reconstruire()
