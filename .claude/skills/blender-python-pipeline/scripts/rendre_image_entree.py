"""Rendre un GLB inchangé en PNG carré, sur blanc pur, sans sol ni ombre portée.

Usage depuis la racine du projet :
    bash .claude/skills/blender-python-pipeline/scripts/blender_lancer.sh \
        --journaux docs/art/essais/entrees/journaux \
        .claude/skills/blender-python-pipeline/scripts/rendre_image_entree.py -- \
        --source /chemin/objet.glb --sortie docs/art/essais/entrees/objet_3q.png

Vue orthographique trois quarts légèrement plongeante ; matériaux et textures
importés conservés. Aucun export de modèle ni sauvegarde de scène.
"""

import argparse
import hashlib
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector
import numpy as np


def empreinte(chemin: Path) -> str:
    return hashlib.sha256(chemin.read_bytes()).hexdigest()


def ajouter_lumiere(nom: str, position: Vector, centre: Vector,
                    taille: float, puissance: float) -> None:
    donnees = bpy.data.lights.new(nom, "AREA")
    donnees.energy = puissance
    donnees.shape = "DISK"
    donnees.size = taille
    objet = bpy.data.objects.new(nom, donnees)
    bpy.context.scene.collection.objects.link(objet)
    objet.location = position
    objet.rotation_euler = (centre - position).to_track_quat("-Z", "Y").to_euler()


def rendre() -> None:
    analyseur = argparse.ArgumentParser(description=__doc__)
    analyseur.add_argument("--source", type=Path, required=True, help="GLB en lecture seule")
    analyseur.add_argument("--sortie", type=Path, required=True, help="PNG de sortie")
    analyseur.add_argument("--taille", type=int, default=1024)
    analyseur.add_argument("--azimut", type=float, default=45.0, help="Depuis -Y vers +X")
    analyseur.add_argument("--elevation", type=float, default=20.0)
    arguments = analyseur.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    source = arguments.source.resolve()
    sortie = arguments.sortie.resolve()
    if source.suffix.lower() != ".glb" or not source.is_file():
        raise ValueError(f"Source GLB introuvable : {source}")
    if sortie.suffix.lower() != ".png" or sortie == source:
        raise ValueError("La sortie doit être un PNG distinct de la source.")
    if arguments.taille < 64 or not all(math.isfinite(angle) for angle in
                                       (arguments.azimut, arguments.elevation)):
        raise ValueError("Taille minimale : 64 pixels ; angles finis requis.")
    empreinte_avant = empreinte(source)
    sortie.parent.mkdir(parents=True, exist_ok=True)

    for objet in list(bpy.data.objects):
        bpy.data.objects.remove(objet, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=str(source))
    scene = bpy.context.scene
    scene.frame_set(1)
    for objet in list(scene.objects):
        if objet.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(objet, do_unlink=True)
    graphe = bpy.context.evaluated_depsgraph_get()
    points = []
    for objet in scene.objects:
        if objet.type != "MESH" or objet.hide_render:
            continue
        evalue = objet.evaluated_get(graphe)
        points.extend(evalue.matrix_world @ sommet.co for sommet in evalue.data.vertices)
        print(f"OK maillage : {objet.name} ({len(evalue.data.vertices)} sommets)")
    if not points:
        raise ValueError("Aucun sommet visible à cadrer.")
    minimum = Vector(tuple(min(point[axe] for point in points) for axe in range(3)))
    maximum = Vector(tuple(max(point[axe] for point in points) for axe in range(3)))
    centre = (minimum + maximum) / 2
    dimension = (maximum - minimum).length
    if not math.isfinite(dimension) or dimension <= 0:
        raise ValueError("Dimensions nulles ou non finies.")

    azimut, elevation = map(math.radians, (arguments.azimut, arguments.elevation))
    direction = Vector((math.sin(azimut) * math.cos(elevation),
                        -math.cos(azimut) * math.cos(elevation), math.sin(elevation)))
    donnees_camera = bpy.data.cameras.new("Camera_entree")
    donnees_camera.type = "ORTHO"
    camera = bpy.data.objects.new("Camera_entree", donnees_camera)
    scene.collection.objects.link(camera)
    scene.camera = camera
    rotation = (-direction).to_track_quat("-Z", "Y")
    camera.rotation_euler = rotation.to_euler()
    projections = [rotation.inverted() @ (point - centre) for point in points]
    gauche, droite = min(p.x for p in projections), max(p.x for p in projections)
    bas, haut = min(p.y for p in projections), max(p.y for p in projections)
    centre += rotation @ Vector(((gauche + droite) / 2, (bas + haut) / 2, 0))
    camera.location = centre + direction * dimension * 4
    donnees_camera.ortho_scale = max(droite - gauche, haut - bas) / 0.82
    donnees_camera.clip_start = dimension * 0.001
    donnees_camera.clip_end = dimension * 20

    monde = bpy.data.worlds.new("Fond_blanc")
    monde.use_nodes = True
    scene.world = monde
    noeuds = monde.node_tree.nodes
    noeuds.clear()
    sortie_monde = noeuds.new("ShaderNodeOutputWorld")
    ambiance = noeuds.new("ShaderNodeBackground")
    ambiance.inputs["Color"].default_value = (1, 1, 1, 1)
    ambiance.inputs["Strength"].default_value = 0.6
    fond = noeuds.new("ShaderNodeBackground")
    fond.inputs["Color"].default_value = (1, 1, 1, 1)
    fond.inputs["Strength"].default_value = 1.0
    rayon = noeuds.new("ShaderNodeLightPath")
    melange = noeuds.new("ShaderNodeMixShader")
    liens = monde.node_tree.links
    liens.new(rayon.outputs["Is Camera Ray"], melange.inputs[0])
    liens.new(ambiance.outputs[0], melange.inputs[1])
    liens.new(fond.outputs[0], melange.inputs[2])
    liens.new(melange.outputs[0], sortie_monde.inputs["Surface"])
    ajouter_lumiere("Lumiere_principale", centre + Vector((-2, -3, 4)) * dimension,
                    centre, dimension * 4, 300 * dimension ** 2)
    ajouter_lumiere("Lumiere_appoint", centre + Vector((3, -1, 2)) * dimension,
                    centre, dimension * 3, 120 * dimension ** 2)

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 128
    scene.cycles.seed = 0
    # Le débruitage peut contaminer les coins du fond ; conserver le blanc exact.
    scene.cycles.use_denoising = False
    scene.render.dither_intensity = 0
    scene.render.resolution_x = arguments.taille
    scene.render.resolution_y = arguments.taille
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = scene.render.pixel_aspect_y = 1.0
    scene.render.film_transparent = False
    # Standard garde le fond caméra (1, 1, 1) blanc pur, sans courbe AgX.
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.image_settings.color_depth = "8"
    scene.render.filepath = str(sortie)
    bpy.ops.render.render(write_still=True)

    image = bpy.data.images.load(str(sortie), check_existing=False)
    if tuple(image.size) != (arguments.taille, arguments.taille):
        raise RuntimeError("Dimensions du PNG incorrectes.")
    pixels = np.array(image.pixels[:]).reshape(arguments.taille, arguments.taille, 4)
    bord = np.concatenate((pixels[0], pixels[-1], pixels[:, 0], pixels[:, -1]))
    if not np.all(bord[:, :3] == 1):
        raise RuntimeError("Le bord de l'image n'est pas blanc pur.")
    masque = np.any(pixels[:, :, :3] < 0.98, axis=2)
    lignes, colonnes = np.where(masque)
    if not len(lignes):
        raise RuntimeError("Image vide : aucun objet visible.")
    if empreinte(source) != empreinte_avant:
        raise RuntimeError("L'empreinte de la source a changé.")
    print(f"OK Blender : {bpy.app.version_string}")
    print(f"OK source inchangée SHA256 : {empreinte_avant}")
    print(f"OK PNG RGB {arguments.taille}x{arguments.taille}, bords blancs : {sortie}")
    print(f"OK emprise visible (origine bas gauche) : "
          f"x={colonnes.min()}..{colonnes.max()}, y={lignes.min()}..{lignes.max()}")


if __name__ == "__main__":
    rendre()
