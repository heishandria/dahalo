# Système artistique — guide d'utilisation

Ce dossier et `.claude/skills/` donnent aux agents d'IA (Claude Code, Codex, Copilot…) une méthode de
directeur artistique, concept artist, character designer, illustrateur, anatomiste, artiste d'environnement,
animateur et modeleur Blender. **Sans MCP** : tout passe par des fichiers, des scripts et Blender en ligne de
commande.

## Ce qu'il y a où

| Emplacement | Contenu | Réutilisable ailleurs ? |
|---|---|---|
| `.claude/skills/` | 25 skills génériques (un dossier = un `SKILL.md`, parfois des scripts) | **Oui** : copier le dossier |
| `.claude/skills/game-art-router/` | Point d'entrée : règles communes, choix des skills et de l'outil, `routage.json`, sélecteur, validateur, tests | Oui |
| `.claude/skills/blender-python-pipeline/scripts/` | Lanceur Blender (journal, délai, sauvegarde), inspection, rendus de vérification, export GLB, audit GLB, bibliothèque d'IK | Oui |
| `docs/art/bible-artistique.md` | Bible de Dahalo (décidé / à décider / faits / choix) | Non (propre au jeu) |
| `docs/art/madagascar-references.md` | Faits culturels et géographiques sourcés, choix assumés, règles de respect, liste à vérifier | Non |
| `docs/art/references/RESOURCES.md` | Catalogue de ressources (liens vérifiés, licences) | En grande partie |
| `docs/art/workflows/` | Workflows de bout en bout | Oui |
| `docs/art/exemples-prompts.md` | Demandes types et ce qu'elles déclenchent | Oui |
| `docs/art/rapport-integration.md` | Ce qui a été fait, testé, et les lacunes | — |
| `AGENTS.md` (racine) | Point d'entrée pour les agents qui ne lisent pas `CLAUDE.md` | — |

`game-art-ai-kit.zip` est l'archive du kit d'origine, **pas une copie de l'installation actuelle** :
son inventaire contient 17 skills et 4 workflows, contre 25 skills et 6 workflows dans le dépôt.
Elle reste inchangée ; pour réutiliser les améliorations, copier les dossiers installés ci-dessus.

## Comment ça s'active

1. **Claude Code** charge automatiquement un skill quand la demande correspond à sa `description` (en français
   et en anglais). `game-art-router` se déclenche pour toute demande artistique et indique les autres à lire.
2. **Tout agent** peut appeler le sélecteur, déterministe et hors ligne :

       python3 .claude/skills/game-art-router/scripts/selectionner_skills.py "créer un zébu en 3D dans Blender"

   Il rend les skills à lire dans l'ordre (sujet d'abord, technique ensuite, revue en dernier), le workflow et
   l'outil conseillé.
3. On peut aussi nommer un skill dans la demande (« utilise locomotion-animation ») ou l'appeler par
   `/nom-du-skill` dans Claude Code.

## Demander efficacement

Dire : **quoi** (personnage, zébu, case, animation…), **pour quoi** (asset de jeu, illustration, planche),
**sortie voulue** (image, SVG, .blend, .glb, intégré au jeu), **contraintes** connues. Exemples :
`exemples-prompts.md`. L'agent doit toujours : lire la bible, choisir l'outil réellement disponible, produire
par passes, **rendre et regarder** le résultat, corriger, puis faire une passation.

## Ce que l'agent peut réellement produire ici

| Tâche | Réellement possible dans ce projet |
|---|---|
| Dessin vectoriel (SVG), schémas, planches annotées | Oui (code + rendu PNG pour vérification) |
| Modèles, rigs, animations Blender, rendus de vérification, export GLB | Oui (Blender 5.3 installé, scripts testés) |
| Intégration et capture en jeu (Godot) | Oui |
| Image → modèle 3D texturé | **Outillage disponible, chaîne complète non validée** : ComfyUI + TRELLIS.2 / Pixal3D installés selon l'inventaire du 18/11/2026 ; client `comfyui.py` présent. Aucune preuve de génération de bout en bout consignée dans ce kit |
| Génération d'images par IA (texte→image) | **Indisponible dans cette installation au 18/11/2026** : aucun modèle texte→image selon l'inventaire ; en attendant, l'agent rédige le prompt pour un outil externe |
| Retouche d'image (recadrage, assemblage, annotations) | Oui par script (Pillow) ; retouche « inpainting » seulement avec un outil dédié |

Statut ComfyUI fondé sur [`references/RESOURCES.md` §8](references/RESOURCES.md) et la présence du client,
pas sur une nouvelle exécution du serveur. Avant production : vérifier `comfyui.py etat`, exécuter un
workflow compatible, conserver son résultat/journal puis inspecter le modèle dans Blender.
Le [rapport d'intégration](rapport-integration.md) distingue les essais historiques de cette disponibilité.

## Maintenance

- Valider après toute modification : `python3 .claude/skills/game-art-router/scripts/valider_skills.py`
  puis `python3 .claude/skills/game-art-router/scripts/test_selection.py`
  et `python3 -B .claude/skills/blender-python-pipeline/scripts/test_audit_glb.py`.
- Audit GLB/glTF : modes TRIANGLES (4), TRIANGLE_STRIP (5), TRIANGLE_FAN (6), avec ou sans indices.
  Le compte inclut les triangles dégénérés et chaque instance de maillage dans les nœuds, comme budget
  conservateur ; ce n'est pas un validateur glTF complet et les buffers géométriques ne sont pas décodés.
  Mode non pris en charge ou compte invalide : alerte et `comptage_complet: false` (total partiel).
  `--strict` échoue alors avec le code 1 ; fichier illisible/structure invalide : code 2.
- Nouveau skill : dossier `kebab-case` + `SKILL.md` avec `name` (= dossier) et `description` (déclencheurs FR/EN),
  sections méthode et **critères de validation** ; l'ajouter à une tâche de `routage.json`.
- Nouvelle décision artistique : bible (tableau + journal). Nouveau fait culturel : `madagascar-references.md`
  avec sa source.

## Réutiliser dans un autre projet

Copier `.claude/skills/` (et éventuellement `docs/art/workflows/`), créer la bible du projet à partir de
`.claude/skills/art-direction/modele-bible.md`, et indiquer son emplacement dans le `CLAUDE.md`/`AGENTS.md` du
projet. Les workflows citent `docs/art/workflows/` : adapter les chemins de `routage.json` si on les range
ailleurs.
