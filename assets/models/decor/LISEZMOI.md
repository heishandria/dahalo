# Modèles de décor

## En place : Quaternius — Stylized Nature MegaKit (version Standard, CC0)

Dossier `quaternius_megakit/` : sélection de 24 modèles glTF sur les 68 de la version gratuite.
Source officielle : https://opengameart.org/content/stylized-nature-megakit (déposé par Quaternius),
licence CC0 1.0 (voir `quaternius_megakit/LICENSE_CC0.txt`) : usage commercial libre, sans attribution.

| Modèles | Utilisation |
|---|---|
| Grass_Common/Wispy (Short, Tall) | Herbe de la zone de jeu (`scenes/world/vegetation.gd`) |
| Flower_3_Group, Flower_4_Group | Fleurs après les pluies (disparaissent en sécheresse) |
| Bush_Common, Bush_Common_Flowers | Buissons (zone de jeu et relief) |
| Pebble_Round/Square | Cailloux |
| Rock_Medium_1 à 3 | Rochers sur le dessus des plateaux et sur le relief |
| DeadTree_1 à 5, TwistedTree_1 à 3 | Arbres du relief lointain (`scenes/world/paysage.gd`) |

Modifications : textures réduites à 1024 px (cartes de relief à 512 px) ; le feuillage rouge automnal
(`Leaves_TwistedTree_C.png`) est remplacé au chargement par le vert olive (`Leaves_NormalTree_C.png`),
voir `scenes/world/bibliotheque_decor.gd`. Si un modèle manque, le jeu revient aux formes générées par le code.

Pour ajouter un modèle : copier le `.gltf`, son `.bin` et ses textures ici, ouvrir le projet dans Godot
(import), puis l'appeler par son nom avec `BibliothequeDecor.maillage("Nom")`.

## Pistes pour compléter

- Quaternius, versions Pro / Source du MegaKit (116 modèles) : https://quaternius.com
- KayKit — Forest Nature Pack (CC0, itch.io, à télécharger dans un navigateur) : https://kaylousberg.itch.io/kaykit-forest
- Comparatif des sources et des licences : voir la page « Sources du décor Dahalo ».

## Modèles sur mesure (circuit Canva → Tripo, voir docs/passation.md)

Propres à l'Androy, à faire faire : baobab (2 variantes), épineux de type Didiéréacée / Alluaudia (3 variantes),
raketa (figuier de Barbarie), case en bois, enclos en branchages épineux, palissade épineuse.
