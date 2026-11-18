#!/usr/bin/env python3
"""Sélectionne les skills artistiques à lire pour une demande, d'après routage.json.

Usage :
    python3 selectionner_skills.py "créer un zébu en 3D dans Blender"
    python3 selectionner_skills.py --json "dessiner une villageoise"

Fonctionne pour tout agent (Claude Code, Codex, Copilot…) : aucune dépendance, aucun réseau, aucun MCP.
Principe : chaque type de tâche a des mots-clés ; on garde les types dont le score atteint au moins la moitié
du meilleur (ou 2), et toujours les « sujets » reconnus (personnage, animal, environnement) ; on fusionne leurs
skills dans l'ordre, en ajoutant le routeur avant et la revue après.
"""
import json
import os
import re
import sys
import unicodedata

ICI = os.path.dirname(os.path.abspath(__file__))
ROUTAGE = os.path.join(ICI, "..", "routage.json")
DOSSIER_SKILLS = os.path.normpath(os.path.join(ICI, "..", ".."))


def normaliser(texte):
    """Minuscules, sans accents, apostrophes et tirets remplacés par des espaces."""
    texte = unicodedata.normalize("NFD", texte.lower())
    texte = "".join(c for c in texte if unicodedata.category(c) != "Mn")
    return " " + re.sub(r"[^a-z0-9]+", " ", texte).strip() + " "


def score(demande, mots_cles):
    total = 0
    trouves = []
    for mot in mots_cles:
        m = normaliser(mot)
        # Mot entier (ou expression) ; pluriel simple accepté.
        motif = re.escape(m.strip())
        if re.search(r"\b" + motif + r"(s|x)?\b", demande):
            total += 2 if " " in m.strip() else 1   # une expression vaut plus qu'un mot seul
            trouves.append(mot)
    return total, trouves


def selectionner(demande_brute, routage=None):
    if routage is None:
        with open(ROUTAGE, encoding="utf-8") as f:
            routage = json.load(f)
    demande = normaliser(demande_brute)
    resultats = []
    for tache in routage["taches"]:
        s, trouves = score(demande, tache["mots_cles"])
        if s > 0:
            resultats.append((s, tache, trouves))
    resultats.sort(key=lambda r: -r[0])
    retenues = []
    if resultats:
        meilleur = resultats[0][0]
        # Un sujet (personnage, animal, environnement) est toujours retenu : la technique (3D, animation…)
        # ne doit pas faire oublier l'anatomie ou l'architecture de ce qu'on représente.
        retenues = [r for r in resultats if r[0] * 2 >= meilleur or r[0] >= 2 or r[1].get("sujet")]
        # On lit d'abord le sujet (ce qu'on représente), ensuite la technique.
        retenues.sort(key=lambda r: (not r[1].get("sujet"), -r[0]))
    skills = list(routage["toujours_avant"])
    for _, tache, _ in retenues:
        for s in tache["skills"]:
            if s not in skills:
                skills.append(s)
    for s in routage["toujours_apres"]:
        if s in skills:
            skills.remove(s)
        skills.append(s)
    return {
        "demande": demande_brute,
        "taches": [{"id": t["id"], "libelle": t["libelle"], "score": s, "mots_trouves": m} for s, t, m in retenues],
        "skills": skills,
        "chemins": [os.path.join(".claude", "skills", s, "SKILL.md") for s in skills],
        "workflows": [t["workflow"] for _, t, _ in retenues if t["workflow"]],
        "outils": [t["outil"] for _, t, _ in retenues],
        "aucune_tache_reconnue": not retenues,
    }


def main():
    args = [a for a in sys.argv[1:] if a != "--json"]
    if not args:
        print(__doc__)
        sys.exit(1)
    r = selectionner(" ".join(args))
    if "--json" in sys.argv:
        print(json.dumps(r, ensure_ascii=False, indent=2))
        return
    if r["aucune_tache_reconnue"]:
        print("Aucun type de tâche reconnu : lire game-art-router puis choisir à la main (voir routage.json).")
    for t in r["taches"]:
        print("Tâche : %s (score %d ; %s)" % (t["libelle"], t["score"], ", ".join(t["mots_trouves"])))
    print("Skills à lire, dans l'ordre :")
    for c in r["chemins"]:
        print("  - " + c)
    for w in dict.fromkeys(r["workflows"]):
        print("Workflow : " + w)
    for o in dict.fromkeys(r["outils"]):
        print("Outil : " + o)


if __name__ == "__main__":
    main()
