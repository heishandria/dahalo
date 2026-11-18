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
| `rendu_verification.py` | Planches de vues orthographiques et de cycles d'animation (Workbench) |
| `exporter_gltf.py` | Export GLB sûr (actions, échantillonnage optionnel, ancienne sortie conservée) |
| `audit_glb.py` | Audit d'un `.glb` sans Blender : triangles, textures, os, animations, alertes de budget |
| `ik_deux_os.py` | Bibliothèque : IK analytique deux os, pose d'os, F-courbes toutes versions, vitesse de calage |

Exemples (chemins relatifs au dossier `scripts/`) :

    ./blender_lancer.sh perso.blend inspecter_blend.py -- rapport.json
    ./blender_lancer.sh perso.blend rendu_verification.py -- --sortie rendus --vues face,profil,dos,trois_quarts
    ./blender_lancer.sh perso.blend rendu_verification.py -- --sortie rendus --action Marche_loop --images 8
    ./blender_lancer.sh perso_v02.blend exporter_gltf.py -- perso.glb --echantillonner
    python3 audit_glb.py perso.glb --max-triangles 10000 --max-texture 2048

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
- Une erreur Python ne fait pas échouer Blender sans `--python-exit-code 1` (le lanceur l'ajoute).
- Modificateurs non appliqués : appliqués à l'export glTF, mais pas dans les comptes de `mesh.loop_triangles`.
- Unités : 1 unité = 1 m ; transformations appliquées avant export.

## Critères de validation

- Le script tourne de bout en bout par `blender_lancer.sh` avec code 0 et journal propre.
- Les rendus de vérification ont été produits **et regardés** ; l'export passe `audit_glb.py`.
- La source n'a pas été modifiée (ou une sauvegarde horodatée existe).
