#!/usr/bin/env python3
"""Tests du sélecteur : skills essentiels, sorties complètes du travail et faux positifs.

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
    ("Transforme cette photo de seau en modèle 3D avec ComfyUI (image vers 3D)",
     ["3d-modeling-and-topology", "game-3d-optimization-and-export"]),
]

PERSONNAGE = [
    "character-design", "human-anatomy-and-character", "drawing-fundamentals",
    "gesture-and-figure-drawing", "visual-reference-research",
]
ENVIRONNEMENT = [
    "environment-and-architecture", "perspective-and-spatial-design",
    "composition-and-visual-storytelling", "colour-light-and-materials", "visual-reference-research",
]
TRAVAIL = [
    "gesture-and-figure-drawing", "animation-fundamentals", "rigging-and-skinning",
    "blender-python-pipeline", "visual-reference-research", "game-3d-optimization-and-export",
    "game-asset-handoff",
]
WORKFLOWS = {
    "personnage": "docs/art/workflows/personnage-concept-turnaround.md",
    "environnement": "docs/art/workflows/environnement.md",
    "action_travail": "docs/art/workflows/animation-cycle.md",
}
CAS_COMPLETS = [
    ("Une villageoise travaille au champ, binage, récolte et dépôt dans un panier",
     ["environnement", "personnage", "action_travail"], ENVIRONNEMENT + PERSONNAGE + TRAVAIL),
    ("Un villageois coupe un arbre avec sa hache",
     ["personnage", "environnement", "action_travail"], PERSONNAGE + ENVIRONNEMENT + TRAVAIL),
    ("Prépare le binage de la paysanne",
     ["personnage", "action_travail"], PERSONNAGE + TRAVAIL),
    ("Une agricultrice récolte puis dépose les épis dans son panier",
     ["personnage", "action_travail"], PERSONNAGE + TRAVAIL),
    ("Un bûcheron doit couper l’arbre",
     ["personnage", "environnement", "action_travail"], PERSONNAGE + ENVIRONNEMENT + TRAVAIL),
    ("Une bûcheronne coupe des arbres",
     ["personnage", "environnement", "action_travail"], PERSONNAGE + ENVIRONNEMENT + TRAVAIL),
    ("Une villageoise travaille aux champs",
     ["environnement", "personnage", "action_travail"], ENVIRONNEMENT + PERSONNAGE + TRAVAIL),
    ("Prépare une action de travail pour le personnage",
     ["personnage", "action_travail"], PERSONNAGE + TRAVAIL),
    ("La paysanne doit semer",
     ["personnage", "action_travail"], PERSONNAGE + TRAVAIL),
    ("Peux-tu dessiner un panier ?", ["dessin_trait"],
     ["drawing-fundamentals", "line-art-and-inking", "perspective-and-spatial-design"]),
    ("Le champ de vision", [], []),
    ("Améliore le travail du dépôt", [], []),
    ("Une coupe et un panier", [], []),
    ("Un arbre", ["environnement"], ENVIRONNEMENT),
]


def verifier_sortie(demande, taches, skills):
    resultat = selectionner(demande)
    attendus = list(dict.fromkeys(["game-art-router"] + skills + ["visual-quality-review"]))
    assert resultat["demande"] == demande
    assert [t["id"] for t in resultat["taches"]] == taches, resultat["taches"]
    assert resultat["skills"] == attendus, resultat["skills"]
    assert resultat["chemins"] == [
        os.path.join(".claude", "skills", s, "SKILL.md") for s in attendus
    ]
    assert resultat["aucune_tache_reconnue"] == (not taches)
    assert resultat["workflows"] == [WORKFLOWS[t] for t in taches if t in WORKFLOWS]
    assert len(resultat["outils"]) == len(taches)
    assert all(resultat["outils"])
    if "action_travail" in taches:
        outil = resultat["outils"][taches.index("action_travail")]
        assert "Blender en ligne de commande" in outil and "contacts main-outil" in outil
        assert "export" in outil and "moteur" in outil
    assert all(t["score"] > 0 and t["mots_trouves"] for t in resultat["taches"])


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
    for demande, taches, skills in CAS_COMPLETS:
        try:
            verifier_sortie(demande, taches, skills)
            print("OK sortie complète : " + demande)
        except AssertionError as erreur:
            echecs += 1
            print("ÉCHEC sortie complète : %s → %s" % (demande, erreur))
    # Un seul déclencheur d'action doit résister à une forte densité de termes techniques.
    demande = "Une paysanne : binage en modèle 3D Blender, mesh low poly glb gltf, UV texture PBR"
    resultat = selectionner(demande)
    if not set(PERSONNAGE + TRAVAIL).issubset(resultat["skills"]) or \
            "action_travail" not in [t["id"] for t in resultat["taches"]]:
        echecs += 1
        print("ÉCHEC action éclipsée par la technique : " + demande)
    else:
        print("OK action conservée dans un brief technique")
    total = len(CAS) + len(CAS_COMPLETS) + 1
    print("%d/%d cas réussis" % (total - echecs, total))
    sys.exit(1 if echecs else 0)


if __name__ == "__main__":
    main()
