#!/usr/bin/env python3
"""Valide le système de skills artistiques : structure, en-têtes SKILL.md, liens internes, routage, absence de
dépendance MCP.

Usage : python3 valider_skills.py [racine_du_projet]     (par défaut : trois dossiers au-dessus de ce script)
Code de sortie 0 si tout est valide, 1 sinon.
"""
import json
import os
import re
import sys

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.normpath(os.path.join(ICI, "..", "..", "..", ".."))
SKILLS = os.path.join(RACINE, ".claude", "skills")
erreurs = []
avertissements = []


def lire(chemin):
    with open(chemin, encoding="utf-8") as f:
        return f.read()


def en_tete(texte):
    m = re.match(r"^---\n(.*?)\n---\n", texte, re.S)
    if not m:
        return None
    champs = {}
    for ligne in m.group(1).splitlines():
        if ":" in ligne:
            cle, val = ligne.split(":", 1)
            champs[cle.strip()] = val.strip().strip('"')
    return champs


MCP_PERMIS = re.compile(r"(sans|pas de|aucun|no|without|non)\s+(serveur,?\s+pas de\s+)?mcp|mcp\s+requis|sans\s+mcp", re.I)


def verifier_liens(fichier, texte):
    dossier = os.path.dirname(fichier)
    # Liens Markdown [texte](cible) et chemins relatifs entre backticks se terminant par .md/.py/.sh/.json
    cibles = re.findall(r"\]\(([^)#\s]+)\)", texte)
    cibles += re.findall(r"`(\.\.?/[^`\s]+?\.(?:md|py|sh|json))(?:\s*§[^`]*)?`", texte)
    for c in cibles:
        if c.startswith(("http://", "https://", "mailto:")):
            continue
        base = RACINE if c.startswith(("docs/", ".claude/", "assets/", "scenes/")) else dossier
        if not os.path.exists(os.path.normpath(os.path.join(base, c))):
            erreurs.append("%s : lien interne cassé → %s" % (os.path.relpath(fichier, RACINE), c))


def main():
    if not os.path.isdir(SKILLS):
        print("ERREUR dossier introuvable : " + SKILLS)
        sys.exit(1)
    noms = sorted(d for d in os.listdir(SKILLS) if os.path.isdir(os.path.join(SKILLS, d)))
    for nom in noms:
        chemin = os.path.join(SKILLS, nom, "SKILL.md")
        if not os.path.isfile(chemin):
            erreurs.append("%s : SKILL.md manquant" % nom)
            continue
        texte = lire(chemin)
        ent = en_tete(texte)
        if ent is None:
            erreurs.append("%s : en-tête YAML absent ou mal formé" % nom)
            continue
        if ent.get("name") != nom:
            erreurs.append("%s : name « %s » différent du dossier" % (nom, ent.get("name")))
        if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", nom) or len(nom) > 64:
            erreurs.append("%s : nom de skill invalide (minuscules, chiffres, tirets, ≤ 64)" % nom)
        desc = ent.get("description", "")
        if len(desc) < 40:
            erreurs.append("%s : description absente ou trop courte" % nom)
        if len(desc) > 1024:
            erreurs.append("%s : description trop longue (%d > 1024)" % (nom, len(desc)))
        if "## " not in texte[texte.find("---", 3):]:
            avertissements.append("%s : aucun titre de section" % nom)
        if not re.search(r"(?i)crit[eè]res? de (validation|sortie)|r[eè]gle d'or|boucle", texte):
            avertissements.append("%s : pas de critères de validation explicites" % nom)
        # Fichiers du skill (SKILL.md, annexes .md, scripts) : liens et MCP
        for racine_d, _, fichiers in os.walk(os.path.join(SKILLS, nom)):
            for f in fichiers:
                p = os.path.join(racine_d, f)
                if not f.endswith((".md", ".py", ".sh", ".json")):
                    continue
                t = lire(p)
                if f.endswith(".md"):
                    verifier_liens(p, t)
                for ligne in t.splitlines():
                    if re.search(r"(?i)\bmcp\b|mcp__", ligne) and not MCP_PERMIS.search(ligne) \
                            and "valider_skills" not in p:
                        erreurs.append("%s : mention MCP qui ressemble à une dépendance → %s"
                                       % (os.path.relpath(p, RACINE), ligne.strip()[:90]))
    # Routage
    routage = json.loads(lire(os.path.join(SKILLS, "game-art-router", "routage.json")))
    routes = set(routage["toujours_avant"]) | set(routage["toujours_apres"])
    for t in routage["taches"]:
        for s in t["skills"]:
            routes.add(s)
            if s not in noms:
                erreurs.append("routage.json : tâche %s → skill inconnu %s" % (t["id"], s))
        if t["workflow"] and not os.path.isfile(os.path.join(RACINE, t["workflow"])):
            erreurs.append("routage.json : workflow introuvable %s" % t["workflow"])
        if not t["mots_cles"]:
            erreurs.append("routage.json : tâche %s sans mots-clés" % t["id"])
    for n in noms:
        if n not in routes:
            avertissements.append("%s : n'est atteint par aucune tâche du routage" % n)
    # Documents du projet qui pointent vers les skills
    docs_art = os.path.join(RACINE, "docs", "art")
    if os.path.isdir(docs_art):
        for racine_d, _, fichiers in os.walk(docs_art):
            for f in fichiers:
                if f.endswith(".md"):
                    p = os.path.join(racine_d, f)
                    verifier_liens(p, lire(p))
    print("Skills trouvés : %d" % len(noms))
    for a in avertissements:
        print("ATTENTION " + a)
    for e in erreurs:
        print("ERREUR " + e)
    print("OK tout est valide" if not erreurs else "%d erreur(s)" % len(erreurs))
    sys.exit(1 if erreurs else 0)


if __name__ == "__main__":
    main()
