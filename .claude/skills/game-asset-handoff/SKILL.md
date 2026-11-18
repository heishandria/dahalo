---
name: game-asset-handoff
description: "Passation d'un asset vers la production : formats, nommage, résolution, espace colorimétrique, pivots, échelle, sources et licences, notes pour le modeleur, le rig ou l'intégrateur moteur, vérification que le fichier s'ouvre et s'affiche dans l'outil cible. Use for asset handoff, delivery notes, sprite sheets, export specifications, licensing notes."
---

# Passation d'asset

## Contenu de la passation

1. **Quoi** : nom, type (concept / source / asset de production), version, emplacement des fichiers.
2. **Technique** : moteur cible, format (PNG, SVG, glTF/GLB, .blend), résolution, espace couleur (sRGB pour
   les couleurs, linéaire pour les données : normal, rugosité), unités et échelle (1 unité = 1 m), axe avant,
   pivot (au sol, au centre de l'emprise), budget atteint (triangles, textures).
3. **2D / sprites** : taille de cellule, marges, pivot, nombre d'images, cadence, nommage des animations,
   contraintes d'atlas, fond transparent.
4. **3D** : planches orthographiques, matériaux, rig (os, noms), animations (noms, durées, boucles, vitesse de
   calage), objets à montrer/cacher, LOD.
5. **Pas d'éclairage cuit** si l'asset est éclairé en temps réel.
6. **Sources et licences** de tout ce qui est inclus (textures, modèles de base, polices).
7. **Hypothèses et limites connues**, défauts mineurs acceptés.
8. **Comment c'est vérifié** : ouvert dans l'outil cible ? capture en moteur ? par qui/quoi ?

## Nommage

Minuscules, sans espaces ni accents dans les fichiers ; préfixe de type ; suffixe de version (`_v03`) pour les
sources ; les noms d'animation suivent la convention du moteur (ex. suffixe `_loop` retiré et converti en boucle
par Godot).

## Critères de validation

- Le fichier s'ouvre dans l'outil cible et s'affiche correctement (preuve : capture ou sortie de script).
- Un intégrateur peut l'utiliser sans poser de question.
