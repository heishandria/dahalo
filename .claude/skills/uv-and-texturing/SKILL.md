---
name: uv-and-texturing
description: "UV et texturing pour le jeu : dépliage, coutures, densité de texels, atlas, matériaux PBR (couleur de base, rugosité, métallique, normal), baking haute→basse définition, textures photo libres, textures procédurales et shaders, résolutions et compression à l'import moteur. Use for UV unwrapping, texel density, PBR materials, baking, texture resolution, procedural textures."
---

# UV et texturing

## UV

1. **Coutures** cachées (dessous, arrière, plis, raccords de matière) ; îlots aussi droits que possible.
2. **Densité de texels** uniforme pour les objets vus à la même distance (ex. 256–512 px/m en vue de
   stratégie) ; plus pour le visage d'un personnage vu de près, moins pour le dessous.
3. **Marges** entre îlots (≥ 4–8 px à la résolution finale) pour éviter les fuites avec les mipmaps.
4. **Atlas** : regrouper les petits objets d'une même famille dans une texture.
5. Symétrie : superposer les îlots miroirs si la texture le permet (économie), sauf marques asymétriques.

## Matériaux PBR

| Carte | Espace | Remarque |
|---|---|---|
| Couleur de base | sRGB | Pas d'ombres ni de reflets cuits |
| Rugosité | Linéaire | Mat (terre, tissu) ≈ 0,8–1 ; peau ≈ 0,5–0,7 ; métal usé ≈ 0,4–0,7 |
| Métallique | Linéaire | 0 ou 1, rarement entre |
| Normal | Linéaire | Convention OpenGL (Y+) pour Blender/Godot ; DirectX (Y−) à convertir |
| Occlusion | Linéaire | Optionnelle, légère |

## Sources de textures

- Photos libres **CC0** (Poly Haven, ambientCG) : vérifier la licence de chaque fichier, noter la source.
- **Procédural** (shader) : bruit, motifs, robes d'animaux calculés dans le shader → pas de fichier, variantes
  infinies ; attention au coût par pixel sur Web/mobile.
- **Baking** : du modèle détaillé vers le modèle de jeu (normal, occlusion) ; cage ou distance réglée ;
  vérifier les artefacts aux bords.
- Couleurs de sommets : utiles pour ombrage d'ambiance ou masques, à moindre coût.

## Résolution et moteur

- Résolution selon la taille à l'écran : souvent 512–1024 px suffit en vue de stratégie ; 2048 rarement.
- **À l'import moteur : compression GPU + mipmaps** pour toute texture 3D (sinon : lenteur, scintillement,
  mémoire vidéo énorme). Normal maps : compression adaptée ou désactivée si le shader lit les 3 canaux.
- Textures en puissance de 2 de préférence.

## Contrôle

Damier de test (étirements, densité), rendu sous l'éclairage du jeu, mosaïque 2×2 pour les textures
répétables, vérification des réglages d'import dans le moteur.

## Critères de validation

- Pas d'étirement visible ; densité cohérente ; coutures invisibles à la caméra de jeu.
- Aucune lumière cuite dans la couleur de base ; licences connues.
- Textures compressées avec mipmaps dans le moteur.
