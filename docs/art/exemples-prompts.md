# Exemples de demandes

Chaque exemple indique ce que le sélecteur retient (vérifié par `test_selection.py`) et ce que l'agent doit
livrer. Les demandes peuvent être plus courtes : l'agent complète par des hypothèses explicites.

## Personnage

> Conçois le Pisteur : silhouette distincte des autres unités, accessoires de son métier, palette de la bible.
> Livre une planche de silhouettes, un concept 3/4 et un turnaround face/profil/dos, puis une note pour le modèle 3D.

Skills : character-design, human-anatomy-and-character, drawing-fundamentals, gesture-and-figure-drawing,
visual-reference-research, turnaround-and-production-sheets. Outil : SVG ou génération pour explorer ;
turnaround fiable par blockout 3D rendu. Livrables vérifiés visuellement.

## Animal

> Ajoute une allure de trot au zébu, calée pour 2,5 m/s, sans glissement des sabots ; montre-moi la planche du cycle.

Skills : animal-and-creature-design, locomotion-animation (ordre diagonal des pattes, phase de vol),
animation-fundamentals, rigging-and-skinning, blender-python-pipeline. Livrables : action Blender, planche
(`rendu_verification.py --action`), vitesse de calage mesurée, intégration et capture en jeu.

## Environnement

> Dessine le plan d'un village antandroy pour la base du joueur : cases, enclos, puits, chemins, à la caméra du jeu.
> Distingue ce qui est documenté de ce qui est inventé.

Skills : environment-and-architecture, perspective-and-spatial-design, composition-and-visual-storytelling,
colour-light-and-materials, visual-reference-research. Livrables : vignettes de composition, blockout, liste
« faits / choix / à vérifier ».

## Illustration

> Écris le prompt de l'écran titre : une femme rapporte l'eau au crépuscule pendant que des Dahalo approchent
> au loin ; respecte la bible et prévois les contrôles à faire sur l'image.

Skills : composition-and-visual-storytelling, colour-light-and-materials, digital-painting-and-rendering,
image-generation-direction. Livrable : brief + prompt + liste de contrôle (pas d'image annoncée sans générateur).

## Modèle 3D

> Fais un modèle Blender de la case du village : 2 000 triangles maximum, textures 1024, export GLB pour Godot.

Skills : environment-and-architecture, 3d-modeling-and-topology, uv-and-texturing, blender-python-pipeline,
game-3d-optimization-and-export, game-asset-handoff. Livrables : script(s) d'étape, `.blend` versionné,
planche de vues, `.glb` audité, capture en jeu, `LISEZMOI.md`.

## Retouche et revue

> Les textures des baobabs scintillent au loin : trouve pourquoi et corrige.

Skills : uv-and-texturing, game-3d-optimization-and-export. Démarche : vérifier les réglages d'import
(compression, mipmaps), la résolution, mesurer avant/après.

> Fais une revue de la villageoise en jeu : silhouette, animation, cohérence avec le zébu et les cases.

Skills : visual-quality-review, art-direction. Livrable : rapport par sévérité, corrections, revérification.

## Formules utiles

- « Utilise le skill X » force un skill précis.
- « Ne génère rien encore : brief, références, incertitudes d'abord. »
- « Montre-moi la planche avant d'intégrer. »
- « Sépare les faits sourcés des choix artistiques. »
