# Workflow : modèle 3D Blender pour le jeu (sans MCP)

Skills : game-art-router → (skill du sujet) → 3d-modeling-and-topology → uv-and-texturing →
rigging-and-skinning (si animé) → blender-python-pipeline → game-3d-optimization-and-export → game-asset-handoff
→ visual-quality-review.

Outils : `.claude/skills/blender-python-pipeline/scripts/` (`S` ci-dessous).

1. **Brief technique** : taille réelle, budget (triangles, matériaux, textures), animé ou non, accessoires
   séparés, plateforme la plus faible (Web).
2. **Source** : modèle de base libre (CC0), image→3D, ou construction par script. Noter la licence.
3. **Inventaire** : `S/blender_lancer.sh source.blend S/inspecter_blend.py -- rapport.json`.
4. **Script d'étape** (un par étape, arguments explicites) ; sortie vers `nom_vNN.blend`, jamais la source ;
   `--sauvegarder` si la source pourrait être touchée.
5. **Vérifier** après chaque étape : `rendu_verification.py -- --sortie rendus --vues face,profil,dos,trois_quarts`
   puis **regarder** la planche ; corriger.
6. **Export** : `exporter_gltf.py -- modele.glb [--echantillonner si contraintes IK]`.
7. **Audit** : `python3 S/audit_glb.py modele.glb --max-triangles … --max-texture …`.
8. **Moteur** : copier dans `assets/models/…`, réimporter (`godot --headless --editor --quit`), régler les
   textures extraites (VRAM compressée + mipmaps), capture en jeu à la caméra réelle.
9. **Passation** (`LISEZMOI.md` à côté du modèle) : source et licence, scripts et commandes pour tout refaire,
   budget, animations et vitesses de calage, objets montrés/cachés.

Exemples réels dans le projet : `assets/models/animaux/zebu_depuis_vache.py` et `zebu_postures.py` ;
`~/dahalo-personnages/villageoise/scripts_claude/` (`integrer_seau.py`, `course.py`).
