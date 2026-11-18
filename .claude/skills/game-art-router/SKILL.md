---
name: game-art-router
description: "Point d'entrée de TOUT travail artistique pour un jeu : dessin, croquis, illustration, concept art, personnage, animal ou créature, environnement, village, décor, planche ou turnaround, texture, modèle 3D Blender, rig, animation (marche, course), génération ou retouche d'image, direction artistique. Fixe les règles communes, choisit les autres skills à lire et l'outil adapté (SVG, rendu Blender, générateur d'images, script), impose la boucle de contrôle visuel. Use for any game art, concept art, drawing, character, creature, environment, animation, texture or 3D modelling request."
---

# Routeur artistique (point d'entrée)

À lire en premier pour toute tâche visuelle. Il dit **quoi lire ensuite**, **avec quel outil produire** et
**comment vérifier**. Les autres skills sont des méthodes de métier ; celui-ci est la discipline commune.

## 1. Règles communes (non négociables)

1. **Lire la bible artistique du projet** avant de créer ou modifier un asset. Son emplacement est donné par
   `CLAUDE.md` / `AGENTS.md` du projet (Dahalo : `docs/art/bible-artistique.md`). Sans bible : en proposer une
   à partir de `../art-direction/modele-bible.md` et énoncer les hypothèses.
2. **Identifier le livrable** (tableau §2) et l'outil réellement disponible. Ne jamais promettre un rendu
   qu'aucun outil de la session ne sait produire.
3. **Séparer design visuel et production technique** : une belle image n'est pas un asset utilisable.
4. **Références** : préserver identité, silhouette, proportions, costume, marques. Ne pas inventer de détails
   contradictoires. Faits culturels : seulement sourcés (voir `../visual-reference-research/SKILL.md`).
5. **Travailler par passes** : silhouette/composition → construction → anatomie/perspective → design →
   valeurs → couleur/lumière → finitions. Ne pas détailler une passe dont la précédente ne tient pas.
6. **Contrôle visuel obligatoire** : rendre/afficher le résultat, le regarder, le critiquer avec
   `../visual-quality-review/SKILL.md`, corriger, revérifier. Ne jamais affirmer qu'un détail est juste sans
   l'avoir vu dans la sortie. Si l'inspection visuelle est impossible, le dire.
7. **Une seule question** seulement si un fait manquant bloque ; sinon hypothèse explicite et solution la plus
   réversible.
8. **Versionner** : brouillons numérotés, ne jamais écraser un fichier source sans sauvegarde
   (`../blender-python-pipeline/SKILL.md` §Sécurité).
9. **Note de passation** à la fin : ce qui est fait, vérifié comment, limites connues
   (`../game-asset-handoff/SKILL.md`).
10. **Pas de MCP requis** : tout se fait avec des fichiers, des scripts et des outils en ligne de commande.

## 2. Choisir l'outil selon la tâche

| Tâche | Outil à privilégier | Limites à dire |
|---|---|---|
| **Dessiner une image** (schéma, croquis de construction, pictogramme, line art propre) | SVG écrit à la main ou généré par script ; rendu PNG pour vérifier (navigateur, `rsvg-convert`, Blender) | Un SVG codé est géométrique : pour du dessin organique, construire avec des courbes de Bézier et vérifier le rendu |
| **Générer une illustration** (concept peint, key art, ambiance) | ComfyUI local (`../image-generation-direction/scripts/comfyui.py`) **si un modèle texte→image est installé** (vérifier avec `comfyui.py etat`) ; sinon rédiger un brief/prompt pour un outil externe | Un prompt ne garantit ni l'anatomie, ni le nombre d'objets, ni la cohérence entre vues |
| **Modifier une image** | Retouche par masque/inpainting si disponible ; sinon script (Pillow/ImageMagick) pour recadrer, assembler, annoter, corriger des couleurs | Lister ce qui doit rester invariant avant toute retouche |
| **Planche de personnage / turnaround** | Vues orthographiques rendues depuis un modèle 3D (Blender) ou blockout 3D, puis paint-over ; génération d'image seulement pour les explorations | La cohérence face/profil/dos d'une génération n'est pas fiable : la vérifier vue par vue |
| **Créer un modèle 3D** | Blender en ligne de commande + scripts Python (`../blender-python-pipeline/SKILL.md`) ; image→3D comme ébauche : **local** par ComfyUI (TRELLIS.2 / Pixal3D, `comfyui.py`) ou en ligne (Tripo, Meshy) | Rendu de vérification sous plusieurs angles à chaque étape ; la face cachée est inventée |
| **Produire une animation** | Blender Python (actions, IK analytique, échantillonnage à l'export), vérifiée par planches d'images et en moteur | Caler la vitesse de l'animation sur la vitesse réelle du jeu (`../locomotion-animation/SKILL.md`) |
| **Texture / matériau** | Textures photo libres (CC0) + shader, ou peinture/baking dans Blender | Compression et mipmaps à régler à l'import moteur |

## 3. Quels skills lire

Lancer le sélecteur (fonctionne pour tout agent, sans dépendance) :

    python3 .claude/skills/game-art-router/scripts/selectionner_skills.py "créer un zébu en 3D dans Blender"

Il lit `routage.json` et rend la liste ordonnée des skills, le workflow à suivre et l'outil conseillé.
Combinaisons de référence :

| Demande | Skills (ordre de lecture) |
|---|---|
| Personnage | character-design, human-anatomy-and-character, drawing-fundamentals, gesture-and-figure-drawing, turnaround-and-production-sheets |
| Animal / créature (zébu) | animal-and-creature-design, drawing-fundamentals, visual-reference-research |
| Village / environnement | environment-and-architecture, perspective-and-spatial-design, composition-and-visual-storytelling, colour-light-and-materials |
| Illustration | composition-and-visual-storytelling, colour-light-and-materials, digital-painting-and-rendering, drawing-fundamentals |
| Modèle Blender | (skill du sujet) + 3d-modeling-and-topology, uv-and-texturing, blender-python-pipeline, game-3d-optimization-and-export, game-asset-handoff |
| Animation | animation-fundamentals, locomotion-animation, rigging-and-skinning, blender-python-pipeline |
| Travail au champ, binage, récolte, coupe d'arbre | (sujet humain et environnement reconnus d'abord) + gesture-and-figure-drawing, animation-fundamentals, rigging-and-skinning, blender-python-pipeline, visual-reference-research, game-3d-optimization-and-export, game-asset-handoff |

Les actions de travail explicites restent retenues même dans un brief riche en termes techniques.
« Au champ » / « aux champs » sélectionnent aussi l'environnement ; les mots isolés « champ », « travail »,
« coupe », « panier » ou « dépôt » ne suffisent pas à déclencher une animation de travail.
Pour ces actions : vérifier anticipation → effort → récupération, appuis, contacts main-outil et dépôt
de l'objet ; la locomotion n'est ajoutée que si la demande la mentionne.

Toujours : `art-direction` si le style n'est pas fixé ; `visual-quality-review` à la fin ;
`visual-reference-research` dès qu'un sujet réel (lieu, peuple, espèce, objet) est représenté.

## 4. Déroulé type

1. Brief en 5 lignes : livrable, sujet, usage en jeu (distance caméra, taille à l'écran), contraintes, invariants.
2. Lire la bible et les skills retenus (ne garder que les sections utiles).
3. Plan de passes et outil choisi ; hypothèses explicites.
4. Produire passe par passe ; **rendre et regarder** après chaque passe structurante.
5. Revue (`visual-quality-review`) → corrections → revérification.
6. Passation (`game-asset-handoff`) et mise à jour de la bible si une règle nouvelle a été décidée.

## 5. Critères de sortie

- Le livrable demandé existe, à l'emplacement annoncé, et a été ouvert/rendu pour vérification.
- La revue ne contient plus de défaut bloquant ; les défauts mineurs restants sont listés.
- Les faits culturels utilisés sont sourcés ou signalés comme choix artistiques.
