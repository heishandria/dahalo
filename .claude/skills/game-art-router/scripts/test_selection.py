#!/usr/bin/env python3
"""Tests du sélecteur de skills : chaque demande doit faire apparaître au moins les skills attendus.

Usage : python3 test_selection.py     (code de sortie 1 si un cas échoue)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from selectionner_skills import selectionner  # noqa: E402

CAS = [
    ("Création d'un personnage : une villageoise antandroy qui porte de l'eau",
     ["character-design", "human-anatomy-and-character", "drawing-fundamentals"]),
    ("Création d'un zébu", ["animal-and-creature-design", "drawing-fundamentals"]),
    ("Création d'un village", ["environment-and-architecture", "perspective-and-spatial-design",
                               "composition-and-visual-storytelling"]),
    ("Création d'une illustration pour l'écran titre",
     ["composition-and-visual-storytelling", "colour-light-and-materials", "digital-painting-and-rendering"]),
    ("Création d'un modèle Blender du guerrier dahalo",
     ["character-design", "human-anatomy-and-character", "3d-modeling-and-topology", "blender-python-pipeline",
      "game-asset-handoff"]),
    ("Fais un zébu en 3D low poly dans Blender et exporte le glb pour Godot",
     ["animal-and-creature-design", "3d-modeling-and-topology", "game-3d-optimization-and-export"]),
    ("Prépare une animation de course pour la villageoise",
     ["animation-fundamentals", "locomotion-animation", "character-design"]),
    ("Le zébu doit trotter : ajoute une allure de trot",
     ["locomotion-animation", "animal-and-creature-design"]),
    ("Dessine une icône SVG de seau d'eau", ["line-art-and-inking", "drawing-fundamentals"]),
    ("Fais un turnaround face profil dos du pisteur",
     ["turnaround-and-production-sheets", "character-design"]),
    ("Écris un prompt Midjourney pour une case de l'Androy au coucher du soleil",
     ["image-generation-direction", "environment-and-architecture"]),
    ("Les textures du baobab scintillent, vérifie les UV et les mipmaps",
     ["uv-and-texturing", "game-3d-optimization-and-export"]),
    ("Définis la direction artistique et la palette du jeu", ["art-direction"]),
    ("Corrige le skinning du coude, le bras se déforme", ["rigging-and-skinning"]),
]


def main():
    echecs = 0
    for demande, attendus in CAS:
        r = selectionner(demande)
        manquants = [s for s in attendus if s not in r["skills"]]
        premiers_ok = r["skills"][0] == "game-art-router" and r["skills"][-1] == "visual-quality-review"
        statut = "OK " if not manquants and premiers_ok else "ÉCHEC"
        if statut != "OK ":
            echecs += 1
        print("%s %-70s → %s" % (statut, demande[:70], ", ".join(r["skills"][1:-1])))
        if manquants:
            print("      manquants : " + ", ".join(manquants))
    print("%d/%d cas réussis" % (len(CAS) - echecs, len(CAS)))
    sys.exit(1 if echecs else 0)


if __name__ == "__main__":
    main()
