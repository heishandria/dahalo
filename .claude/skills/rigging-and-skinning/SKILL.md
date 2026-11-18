---
name: rigging-and-skinning
description: "Rigging et skinning pour le jeu : squelette (hiérarchie, nommage, orientation des os, racine), contraintes et cinématique inverse, os d'accessoires (objet tenu), poids de skinning, test des déformations en poses extrêmes, limites des moteurs (nombre d'os, influences par sommet). Use for rigging, armatures, skeletons, IK, skin weights, weight painting, prop bones."
---

# Rigging et skinning

## Squelette

1. **Racine** au sol (origine), sans animation de déplacement si les animations sont sur place.
2. **Hiérarchie** : racine → bassin → colonne (2–3) → cou → tête ; clavicule → bras → avant-bras → main ;
   cuisse → mollet → pied (→ orteils si nécessaire). Quadrupède : mêmes principes, avec omoplate, carpe,
   jarret, et os de bosse/queue/oreilles selon les besoins.
3. **Nommage** cohérent et symétrique (`Bras_G`/`Bras_D` ou `.L`/`.R`) : la symétrie d'outils en dépend.
4. **Orientation** des os : axe de pliage cohérent (un seul axe principal pour coudes et genoux) ; os placés au
   centre des articulations, vérifiés de face **et** de profil.
5. **Nombre d'os** : le minimum utile (20–30 pour une unité de jeu) ; ≤ 4 influences par sommet.

## Accessoires

- Objet tenu (seau, arme, outil) : **os dédié** ou objet séparé attaché à la main ; ses animations clés dans
  les actions qui le montrent ; **objet maillage séparé et nommé** pour pouvoir le montrer/cacher en jeu.
- Parties souples (anse, tissu, oreilles) : os secondaires animés en léger retard (chevauchement).

## IK et contraintes

- L'IK aide à animer, mais **les moteurs n'exécutent pas les contraintes de Blender** : à l'export, les
  animations doivent être **échantillonnées** (« bake ») sinon seules les cibles bougent.
- Alternative fiable : IK analytique calculée par script et clés posées sur les os FK (voir
  `../locomotion-animation/SKILL.md`).

## Skinning

1. Poids automatiques comme point de départ, puis correction.
2. Tester en **poses extrêmes** : bras levé, accroupi, genou plié à fond, tête tournée, torsion du buste.
3. Corriger : épaules (pas d'écrasement), coudes/genoux (volume conservé), hanches, cou, vêtements amples
   (robe : poids répartis entre les deux cuisses et le bassin pour éviter le déchirement entre les jambes).
4. Normaliser les poids ; supprimer les influences minuscules.

## Contrôle

Planche de rendus en poses extrêmes (`rendu_verification.py` avec une action de test), vérification en moteur.

## Critères de validation

- Pas de pli cassé, de perte de volume ni d'interpénétration grossière aux poses extrêmes.
- Squelette nommé symétriquement, racine propre, influences ≤ 4.
- Les animations fonctionnent en moteur sans contraintes Blender.
