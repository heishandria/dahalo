---
name: image-generation-direction
description: "Diriger un générateur d'images (et la retouche d'images) : brief structuré, rôle de chaque référence, invariants et variations permises, itération une variable à la fois, défauts typiques (mains, anatomie, nombre d'objets, texte, vues incohérentes), contrôle visuel et correction. Indépendant du modèle (Canva, Midjourney, DALL·E, Stable Diffusion/Flux, etc.). Use for AI image generation, prompting, image-to-image, inpainting, image editing."
---

# Diriger la génération d'images

## Avant de générer

1. **L'outil existe-t-il dans la session ?** Sinon, livrer un brief/prompt prêt à coller dans l'outil de
   l'utilisateur, et le dire. Ne jamais prétendre avoir généré une image.
2. **Bon outil pour le besoin** : génération = explorations, ambiances, concepts ; **pas** pour des vues
   orthographiques garanties, du texte exact, des mesures, un nombre exact d'objets, des détails culturels
   exacts. Pour ceux-là : 3D, vectoriel, retouche contrôlée.

## Brief (squelette)

[livrable] de [sujet], [rôle/action], [caméra/vue], [composition], [langage de formes], [anatomie/proportions],
[costume/matériaux], [palette], [lumière], [fond], [ancres de style], [invariants], [contraintes négatives
précises], [format/ratio].

- **Invariants** : ce qui ne doit pas changer (identité, costume, couleurs, proportions).
- **Variations permises** : ce qu'on explore cette fois.
- **Références** : une fonction chacune (identité, pose, style, palette, costume, composition) ; le dire.
- **Négatifs** : seulement contre des défauts déjà observés (« pas de texte », « une seule personne »), pas de
  longues listes vagues.
- Pour un modèle 3D à partir d'une image (image→3D) : un seul objet entier, centré, fond uni, lumière douce
  sans ombre portée, vue de 3/4, sans texte.

## Itérer

1. Variantes larges seulement pour les choix non tranchés (composition, silhouette).
2. Choisir une direction, **figer** le reste (graine, références, prompt).
3. Changer **une variable à la fois** ; noter ce qui a changé.

## Contrôle (à chaque image retenue)

Mains (nombre de doigts, articulations), pieds et appuis, membres en trop/fusionnés, symétrie des yeux,
nombre d'objets, perspective, texte parasite, accessoires qui changent, cohérence culturelle (rien d'inventé
présenté comme authentique), artefacts de bord, style conforme à la bible. Utiliser
`../visual-quality-review/SKILL.md`.

## Corriger

Retouche ciblée (masque/inpainting) si disponible, sinon paint-over, vectoriel ou 3D pour les détails de
production. Les corrections se vérifient comme le reste.

## Traçabilité

Conserver : prompt, outil et version, graine si dispo, références utilisées, image retenue, corrections.

## Critères de validation

- L'image suit le brief, tient les invariants, a été regardée et critiquée ; défauts corrigés ou listés.
- Rien n'est présenté comme fait documenté sur la seule foi d'une image générée.
