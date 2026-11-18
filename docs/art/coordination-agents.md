# Coordination des agents — Claude Code et Copilot « Astra »

Mis à jour : 18/11/2026, vers 12 h 30 (par Claude Code). **Chaque agent met à jour ce fichier quand il prend,
termine ou abandonne une tâche.** Il fait foi pour savoir qui modifie quoi.

## 1. Pourquoi ce fichier

Le 18/11, nous avons modifié les mêmes fichiers en même temps : le commit `1392223` de Claude a embarqué sans
relecture les changements d'Astra (`routage.json`, `test_selection.py`, `audit_glb.py`, `test_audit_glb.py`,
`rapport-integration.md`). Ces changements ont été relus après coup : ce sont des améliorations, gardées. Un
ajout de Claude à `audit_glb.py` cassait 3 tests d'Astra : corrigé dans `da306e5`. Tout est au vert depuis.

## 2. Ce qui est fait (dans `main`)

| Commit | Contenu |
|---|---|
| `41dbe3b` | Système artistique : 25 skills dans `.claude/skills/` (routeur `game-art-router`, sélecteur `selectionner_skills.py`, validateur, tests), pipeline Blender sans MCP (`blender-python-pipeline/scripts/`), `docs/art/` (bible, références Madagascar sourcées, ressources, workflows, guide, exemples, rapport), `AGENTS.md` |
| `1392223` | ComfyUI local piloté par API : `image-generation-direction/scripts/comfyui.py` (état, modèles de workflow, conversion interface→API, exécution), graphe « génération seule » `image-generation-direction/workflows/image_vers_3d_brut_api.json`, script Blender `nettoyer_maillage_ia.py` ; + améliorations d'Astra (routage enrichi, audit GLB robuste et ses tests) |
| `da306e5` | `audit_glb.py` : contrôle sommets/triangles compatible avec les tests d'Astra |

Tests de référence, tous verts au dernier passage :

    python3 -B .claude/skills/game-art-router/scripts/valider_skills.py          # 25 skills, 0 erreur
    python3 -B .claude/skills/game-art-router/scripts/test_selection.py          # 30/30
    python3 -B .claude/skills/blender-python-pipeline/scripts/test_audit_glb.py  # 14 tests OK

## 3. Ce qui est en cours : ComfyUI image→3D sur Mac

**Installation** : ComfyUI 0.45.6, `~/ComfyUI-Installs/Heishandria/ComfyUI` (dépôt Git propre), serveur
`http://127.0.0.1:8188`, Apple MPS. Modèles : TRELLIS.2, Pixal3D, MoGe, BiRefNet, DINOv3 (image→3D seulement,
aucun modèle texte→image).

**Constats** (exécutés, pas supposés) :
1. Le modèle de workflow `3d_pixal3d_trellis2_image_to_model` se convertit et s'exécute par `comfyui.py`
   (environ 14 min), mais le maillage décodé n'a qu'environ 1 % de ses faces (1 703 316 sommets pour 14 632
   triangles ; rendu Blender : silhouette en fragments).
2. `RemeshMesh` (tous modes) plante (« index N is out of bounds for dimension 0 with size N »), et
   `DecimateMesh` aussi (« not supported for torch.int64 »).
3. **Cause racine de la perte de faces** : `comfy/ldm/trellis2/flexgemm.py`, `TorchHashMap`. Sur MPS,
   `torch.sort` d'un tenseur int64 de 1,7 M de clés renvoie un tableau croissant mais aux valeurs fausses :
   106 992 clés sur 1 700 000 sont retrouvées. Avec un tri sur CPU, 100 % le sont.

**En cours** :
- **Correctif dans ComfyUI**, autorisé par l'utilisateur, confié par Claude à un sous-agent **Fable** :
  sauvegarde, correction minimale de `TorchHashMap`, recherche du même défaut dans le remaillage et la
  décimation, script de test MPS contre CPU (`~/ComfyUI-Installs/Heishandria/tests_correctif_mps.py`).
  **Ne pas toucher à `~/ComfyUI-Installs/` ni redémarrer le serveur pendant ce temps.**
- **Ensuite (Claude)** : redémarrage de ComfyUI avec l'utilisateur, nouvelle génération complète, audit,
  nettoyage Blender, rendus et compte rendu. **Astra** prépare séparément un brouillon non publié du
  signalement à partir des constats ci-dessus ; Claude pourra le compléter avec les résultats après correctif.

## 4. Répartition proposée (à valider par l'utilisateur)

| Domaine | Responsable | Fichiers |
|---|---|---|
| ComfyUI : correctif local, test de bout en bout, `comfyui.py`, graphe image→3D | **Claude** (et Fable pour le correctif) | `~/ComfyUI-Installs/…`, `.claude/skills/image-generation-direction/scripts/`, `…/workflows/` |
| Analyse documentaire de mémoire et compatibilité Apple Silicon | **Astra**, en lecture seule ; ne pas toucher à l'installation locale pendant la tâche Claude/Fable | Sources publiques et constats déjà consignés ; aucune génération, aucun redémarrage |
| Post-traitement Blender des sorties ComfyUI, rendus de vérification de ces résultats, export | **Claude** | `blender-python-pipeline/scripts/nettoyer_maillage_ia.py`, `rendu_verification.py`, `exporter_gltf.py` |
| Image d'entrée 3D d'un asset existant, hors génération ComfyUI | **Astra** | `blender-python-pipeline/scripts/rendre_image_entree.py`, `docs/art/essais/entrees/` |
| Brouillon de signalement MPS, sans publication | **Astra** | `docs/art/essais/signalement_bogue_mps.md` |
| Reconstruction expérimentale depuis nuage de sommets, sur copie du GLB fourni | **Astra** (exception ciblée au post-traitement ComfyUI de Claude) | `blender-python-pipeline/scripts/reconstruire_depuis_sommets.py`, `docs/art/essais/reconstructions/` |
| Qualité du système de skills : routage, sélecteur, validateur, tests | **Astra** | `game-art-router/routage.json`, `game-art-router/scripts/*`, `blender-python-pipeline/scripts/audit_glb.py`, `test_audit_glb.py` |
| Rapport et catalogue de ressources | **Astra** | `docs/art/rapport-integration.md`, `docs/art/references/RESOURCES.md` |
| Vérification des faits culturels (liste « à vérifier ») | **Astra**, proposé | `docs/art/madagascar-references.md` (sources obligatoires, rien d'inventé) |
| Contenu des `SKILL.md` | **Celui qui en a besoin**, après l'avoir annoncé ici (§5) | `.claude/skills/*/SKILL.md` |
| Code du jeu (Godot) | Hors de ce chantier, demander à l'utilisateur | `scenes/`, `systems/`, `data/`… |

## 5. Règles de travail commun

1. **Annoncer avant de modifier** : ajouter une ligne dans §6 (« en cours ») avec les fichiers visés ; ne pas
   modifier un fichier annoncé par l'autre agent.
2. **Committer seulement ses propres fichiers**, par chemins explicites (`git add chemin/fichier`), jamais un
   dossier entier ; relire `git diff --staged` avant chaque commit.
3. **Lancer les trois tests du §2** avant de committer un changement qui touche les skills ou les scripts.
4. **Ne jamais affirmer un test non exécuté** ; donner la sortie réelle.
5. **ComfyUI** : pas de génération, de redémarrage ni de modification de `~/ComfyUI-Installs/` sans accord de
   l'utilisateur et sans prévenir l'autre agent (un seul calcul à la fois : 16 Go de mémoire).
6. **Blender** : jamais d'écrasement d'un `.blend` source (lanceur `--sauvegarder`, sortie versionnée).
7. Langue : français ; conventions de `CLAUDE.md` pour tout code.

## 6. Tâches en cours (à tenir à jour)

| Depuis | Agent | Tâche | Fichiers |
|---|---|---|---|
| 18/11, 12 h 15 | Claude → Fable | **Terminé** — correctif MPS de ComfyUI (tri, unique, scatter_reduce, solve/det) ; 25/25 tests ; complété par Claude au dépliage UV (`uv_unwrap/segment.py`, `mesh.py`, `pack.py`) | `~/ComfyUI-Installs/Heishandria/ComfyUI/comfy/…`, `tests_correctif_mps.py` |
| 18/11, 17 h 30 | Claude | **Terminé** — villageoise v9 : marche et courses refaites (cadence naturelle, phase de vol, bras par IK), calage course 3,96 m/s | `scripts_claude/locomotion.py`, `assets/models/personnages/villageoise.glb`, `data/unit_data.gd` |
| 18/11, 17 h 00 | Claude | **Terminé** — villageoise v8 : prise des objets (os de doigts « moufle », main fermée sur le seau, la houe, la hache, l'épi ; seau remonté de 3 cm) | `scripts_claude/prises_mains.py`, `assets/models/personnages/villageoise.glb` |
| 18/11, 16 h 10 | Claude | **Terminé** — villageoise v7 : coupe du bois (hache, animation générée par script, branchée en jeu) | `scripts_claude/couper_bois.py`, `assets/models/personnages/villageoise.glb`, `scenes/units/unite.gd`, skill `blender-python-pipeline` (piège des références d'os) |
| 18/11, 16 h 00 | Claude | **Terminé** — villageoise v6 : travail des champs d'Astra (`champ_astra_v05/`, lu sans modification) intégré au v5 et branché en jeu (biner / récolter) | `scripts_claude/integrer_champ.py`, `assets/models/personnages/villageoise.glb`, `scenes/units/unite.gd`, `rendu_verification.py` (option `--cacher`) |
| 18/11, 15 h 40 | Claude | **Terminé** — villageoise v5 : image→3D (TRELLIS.2) passée par le kit (recuisson, poids transférés) et intégrée au jeu | `assets/models/personnages/`, `docs/.gdignore`, bible, passation, skills |
| 18/11, 12 h 09 | Astra | **Terminé** — répartition validée ; analyse documentaire séparée de l'exécution ComfyUI | `docs/art/coordination-agents.md` (§4 et §6) |
| 18/11, 12 h 11 | Astra | **Terminé** — analyse mémoire de TRELLIS.2 pour 16 Gio, sans exécuter le workflow | Sources publiques et constats déjà consignés ; aucune modification de l'installation |
| 18/11, 12 h 13 | Astra | **Terminé** — rendre une image d'entrée du seau, séparément de tout workflow ComfyUI | `blender-python-pipeline/scripts/rendre_image_entree.py`, `docs/art/essais/entrees/seau_3q.png` |
| 18/11, 12 h 13 | Astra | **Terminé** — rédiger le brouillon non publié du signalement MPS | `docs/art/essais/signalement_bogue_mps.md` |
| 18/11, 12 h 30 | Astra | **Reporté** — le GLB présent n'a ni attribut `COLOR_0` ni couleur par sommet ; il ne permet pas de valider le transfert de couleurs demandé. Source inspectée en lecture seule, aucun script/copie créés. | `docs/art/essais/bruts/902_brut_forme_00001_.glb` |
| 18/11 (reprise) | Astra | **Terminé** — reconstruction depuis le `901` sur copie, contrôle du rendu/export ; brouillon mis à jour avec PyTorch 2.12.1. La reconstruction est expérimentale, non prête pour le jeu. | `.claude/skills/blender-python-pipeline/scripts/reconstruire_depuis_sommets.py`, `docs/art/essais/reconstructions/901_reconstruction_secours_v01.glb`, `.png`, `LISEZMOI.md`, `docs/art/essais/signalement_bogue_mps.md` |
