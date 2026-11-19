---
name: blender-python-pipeline
description: "Piloter Blender SANS MCP : Blender en ligne de commande (-b), scripts Python autonomes et reproductibles (API bpy), journaux, sauvegardes avant modification, fichiers .blend versionnés, rendus de vérification (planches de vues et de cycles d'animation), audit et export glTF/GLB, animations générées par script (IK analytique). Use for Blender scripting, headless Blender, bpy, batch processing, procedural modelling/animation, verification renders, glTF export without MCP."
---

# Pipeline Blender en Python (sans MCP)

Blender se pilote par **scripts `.py` lancés en ligne de commande**. Pas de serveur, pas de MCP, pas
d'interface : chaque étape est un fichier versionnable, rejouable, journalisé.

## Règles

1. **Jamais d'écrasement de la source** : lire `x.blend`, écrire `x_v02.blend` (`save_as_mainfile` vers un
   **autre** nom). En cas de doute : `--sauvegarder` (copie horodatée dans `sauvegardes/`).
2. **Un script = une étape** avec arguments explicites (`-- entrée sortie options`), sans chemin codé en dur.
3. **Journal** de chaque exécution et **code de sortie fiable** (`--python-exit-code 1`) : `blender_lancer.sh`.
4. **Rendre pour vérifier** après chaque étape qui change la forme ou le mouvement :
   `rendu_verification.py`, puis regarder les images.
5. **Déterminisme** : graines aléatoires fixées (`random.seed`), pas de dépendance à la sélection ou à
   l'interface.
6. Préférer l'**API de données** (`bpy.data`, `pose_bone.matrix`, `mesh.from_pydata`) aux opérateurs
   (`bpy.ops`, qui dépendent du contexte). Si un opérateur est nécessaire : objet actif défini, mode OBJECT.

## Outils fournis (`scripts/`)

| Script | Rôle |
|---|---|
| `blender_lancer.sh` | Trouve Blender, lance un script sur un `.blend` (ou une scène vide), journal, délai max, sauvegarde |
| `inspecter_blend.py` | Inventaire : objets, triangles, matériaux, images, os, actions (+ JSON) |
| `rendu_verification.py` | Planches de vues orthographiques, cycles d'animation, et vues à la caméra du jeu (`--rts`) |
| `exporter_gltf.py` | Export GLB sûr (actions, échantillonnage optionnel, ancienne sortie conservée) |
| `audit_glb.py` | Audit d'un `.glb` sans Blender : triangles, textures, os, animations, alertes de budget |
| `ik_deux_os.py` | Bibliothèque : IK analytique deux os, pose d'os, F-courbes toutes versions, vitesse de calage |
| `pipeline_personnage.py` | Orchestre les étapes image→jeu d'après `config_personnage.json` ; `--depuis`, `--jusqu-a`, `--etape`, `--etat`, `--seche` |
| `gabarits/config_personnage.json` | Gabarit de config par personnage (taille, triangles, texture, vitesses…) |

Exemples (chemins relatifs au dossier `scripts/`) :

    ./blender_lancer.sh perso.blend inspecter_blend.py -- rapport.json
    ./blender_lancer.sh perso.blend rendu_verification.py -- --sortie rendus --vues face,profil,dos,trois_quarts
    ./blender_lancer.sh perso.blend rendu_verification.py -- --sortie rendus --action Marche_loop --images 8
    ./blender_lancer.sh perso.blend rendu_verification.py -- --sortie rendus --rts --action Perso_repos_loop
    ./blender_lancer.sh perso_v02.blend exporter_gltf.py -- perso.glb --echantillonner
    python3 audit_glb.py perso.glb --max-triangles 10000 --max-texture 2048
    # Depuis le dossier du personnage :
    python3 ~/dahalo/.claude/skills/blender-python-pipeline/scripts/pipeline_personnage.py --jusqu-a controle_texture

## Gabarit d'un script d'étape

    import bpy, sys
    args = sys.argv[sys.argv.index("--") + 1:]          # arguments après « -- »
    entree, sortie_blend = args[0], args[1]
    # … travail sur bpy.data …
    bpy.ops.wm.save_as_mainfile(filepath=sortie_blend)   # jamais le fichier d'entrée
    print("OK étape terminée")

## Animation par script

1. Créer l'action, l'assigner (`ik_deux_os.assigner` gère les emplacements d'actions de Blender 4.4+).
2. Pour chaque image : remettre la pose à zéro, placer le bassin, résoudre les jambes
   (`jambe_deux_os` vers la trajectoire de cheville), poser buste et bras par rotations locales, insérer les
   clés (`keyframe_insert`) sur tous les os.
3. Interpolation linéaire, première image = dernière (boucle), `use_fake_user = True`.
4. Mesurer la vitesse de calage (`vitesse_calage`) et la reporter au jeu.
5. Planche de rendu du cycle → revue (`../visual-quality-review/SKILL.md`).

## Pièges connus (Blender 4.x / 5.x)

- Actions « à emplacements » (4.4+) : `action.fcurves` n'existe plus → `layers/strips/channelbags`
  (`courbes()`) ; assigner `animation_data.action_slot`.
- Contraintes IK non exportées : `export_force_sampling=True` ou IK calculée par script.
- `mode_set` échoue sans objet actif : `view_layer.objects.active = obj` d'abord.
- Après un passage en mode édition d'une armature, les références aux os (`arm.data.bones["X"]`) obtenues avant
  sont **invalides** (données reconstruites) : lire tout ce dont on a besoin (matrices, axes) **avant**, ou
  relire `arm.data.bones` après.
- Animation par script : après avoir remis la pose à zéro (`location`, `rotation_quaternion`), appeler
  `view_layer.update()` **avant** de poser des os par `pose_bone.matrix` ; sinon la première image lit encore la
  pose de l'action précédente (à-coup à chaque tour de boucle). Calculer la phase par `(image % N) / N` pour que la
  dernière image soit exactement la première.
- Une erreur Python ne fait pas échouer Blender sans `--python-exit-code 1` (le lanceur l'ajoute).
- Modificateurs non appliqués : appliqués à l'export glTF, mais pas dans les comptes de `mesh.loop_triangles`.
- Unités : 1 unité = 1 m ; transformations appliquées avant export.

## Pipeline personnage image→jeu (Dahalo)

Un dossier par personnage (`~/dahalo-personnages/<nom>/`) avec `config_personnage.json` (gabarit :
`gabarits/config_personnage.json`) : tailles, budgets, photos, scripts de chaque étape, noms de fichiers.
`pipeline_personnage.py` enchaîne les étapes, écrit `.etat_pipeline.json` et un journal par étape dans le dossier
de rendus ; un échec arrête la chaîne (corriger, puis `--depuis ETAPE`). Il ne demande rien au clavier : un agent
s'arrête de lui-même aux contrôles avec `--jusqu-a controle_texture`, regarde, puis continue.

| Étape | Script (config `scripts`) | Produit | Quand |
|---|---|---|---|
| Génération IA | ComfyUI (Hunyuan3D-2mini), hors pipeline | corps.glb (+ tête.glb) | toujours |
| `greffe` | `greffer_tete.py` | greffe.glb | personnage humain (tête générée seule) |
| `texture` | `texture_projection.py` | texture.blend/.glb | toujours |
| `controle_texture` | `comparer_image.py` + `rendu_verification.py --rts` | comparaisons, planche RTS | **toujours : regarder avant le rig** |
| `rig` | `rig_<nom>.py` | rig.blend | toujours |
| `corpulence` | `corpulence.py` | corpulence.blend | si carrure particulière |
| `accessoire` | `fusil_chef.py`, … | accessoire.blend | si arme ou outil |
| `retouche` | `retoucher_texture.py` | retouche.blend | toujours (tons passés, poussière, taille) |
| `anim` | `anim_<nom>.py` | anim.blend/.glb | toujours |
| `controle_anim` | `rendu_verification.py --rts --action …` + `audit_glb.py` | planches RTS par action, audit | **toujours : regarder** |
| `video` | `video_<nom>.py` | vidéo | toujours |
| `promouvoir` | (interne) | copie dans `assets/`, ancienne sauvegardée, empreintes comparées | seulement `--etape promouvoir` |

Après `promouvoir` : `Godot --headless --path . --import` (extrait les textures du GLB : sans réimport, une
nouvelle texture d'accessoire n'apparaît pas en jeu), puis partie accélérée sans erreur.

**Règles (apprises sur le chef dahalo, 18–19/11) :**

1. **Lisibilité à la vraie caméra** : `--rts` reproduit `systems/rts_camera.gd` (orthographique, 35,26°, taille
   de vue 18 / 40 / 70) à la densité réelle d'un écran 1080p. Un humain de 1,85 m y fait ~90 / 41 / 23 px.
   Le rôle doit se lire à la taille de vue 40 (défaut), dans les 4 orientations.
2. **Repos d'abord** : c'est la pose la plus vue. Un accessoire tenu le long du corps disparaît (fusil du chef
   v4) : le sortir de la silhouette (port d’arme en diagonale devant le corps, outil sur l’épaule…).
3. **Comparer aux photos** (`controle_texture`) avant le rig ; ne jamais dire que la texture ressemble sans
   l'avoir vu côte à côte. Regarder aussi les **profils** : c'est là que la projection bave.
4. **Projection** : bord du sujet érodé (`--eroder 3`) contre le liseré blanc d'anticrénelage ; zones non vues
   remplies par diffusion sur la surface (pas de traînées horizontales).
5. **Texture 1024 px** par défaut (bible §4) ; la retouche ramène la taille et applique la direction artistique
   (rouge désaturé vers la brique, poussière de latérite en bas du corps).
6. **Photos de référence** : A-pose stricte, fond uni clair, même distance face/dos ; face + dos au minimum,
   profils et gros plan du visage si possible. Lister les motifs et accessoires inventés par l'image IA et les
   faire valider (culture) **avant** la modélisation.
7. **Tête séparée** pour un humain : générée seule puis `greffer_tete.py` (visage bien plus net).
8. **Accessoire = os dédié** nommé comme l'objet (`Fusil`, `Sagaie`), parent `Racine`, déformant ; les mains s'y
   posent par IK ; matériaux à texture (atlas), pas de couleur unie seule (illisible ou blanchâtre en jeu).
9. **Une version promue = un seul fichier source** : la config pointe vers les fichiers réellement promus ;
   ne jamais copier un GLB dans le jeu à la main (écart du chef v4 : GLB du jeu antérieur au fusil texturé).

## Critères de validation

- Le script tourne de bout en bout par `blender_lancer.sh` avec code 0 et journal propre.
- Les rendus de vérification ont été produits **et regardés** (y compris `--rts` par action) ; l'export passe `audit_glb.py`.
- La comparaison images de référence / rendu a été regardée : couleurs cohérentes.
- La source n'a pas été modifiée (ou une sauvegarde horodatée existe).
