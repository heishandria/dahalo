# Rapport d'intégration du « Game Art AI Kit » (18/11/2026)

## 1. Point de départ

- **Kit fourni** (`game-art-ai-kit.zip`, v1.0) : `AGENTS.md`, 16 skills de 15 à 25 lignes, 4 workflows,
  `RESOURCES.md`, modèle de bible. Méthodes générales en anglais, sans critères chiffrés, sans animation ni 3D
  (hormis la passation), sans outil.
- **Projet** : aucun `AGENTS.md` ni skill ; règles dans `CLAUDE.md` (français) ; direction artistique
  dispersée dans les specs (`docs/specs/carte.md` §4) ; scripts Blender propres au jeu (zébu, villageoise) ;
  pipeline Canva → Tripo (`docs/modeles_sur_mesure.md`) ; dossier `~/dahalo-personnages/outils/` contenant un
  ancien outillage Blender par MCP (laissé intact, plus utilisé).

## 2. Ce qui a été fait

| Livrable | Emplacement |
|---|---|
| 25 skills (16 du kit réécrits et complétés, 9 nouveaux) | `.claude/skills/` |
| Skill d'entrée + routage automatique | `.claude/skills/game-art-router/` (`SKILL.md`, `routage.json`, `scripts/selectionner_skills.py`) |
| Validateur et tests | `game-art-router/scripts/valider_skills.py`, `test_selection.py` |
| Outils Blender sans MCP (6) | `.claude/skills/blender-python-pipeline/scripts/` |
| Bible artistique initiale de Dahalo | `docs/art/bible-artistique.md` |
| Références Madagascar sourcées | `docs/art/madagascar-references.md` |
| Catalogue de ressources (liens vérifiés, licences) | `docs/art/references/RESOURCES.md` |
| Workflows (6) | `docs/art/workflows/` |
| Guide, exemples de demandes | `docs/art/README.md`, `docs/art/exemples-prompts.md` |
| Point d'entrée multi-agents | `AGENTS.md` (racine) ; section « Art » ajoutée à `CLAUDE.md` |

**Nouveaux skills** : `game-art-router`, `animation-fundamentals`, `locomotion-animation` (marche, course,
allures des quadrupèdes, calage de vitesse), `blender-python-pipeline`, `3d-modeling-and-topology`,
`uv-and-texturing`, `rigging-and-skinning`, `game-3d-optimization-and-export`, et le modèle de bible rangé dans
`art-direction`.

**Améliorations des skills du kit** : critères de validation vérifiables dans chacun ; chiffres concrets
(proportions en têtes, amplitudes articulaires, repères du visage, ordres de pose des pattes, budgets,
densité de texels, réglages d'export) ; anatomie comparée des quadrupèdes (jarret, carpe, onglons, bosse et
fanon des zébus) ; expressions et vêtements sur le corps ; caméra isométrique de jeu ; matériaux et lumière ;
exactitude culturelle (objets sacrés, termes, clichés) ; choix de l'outil selon la tâche et limites de la
génération d'images ; leçons du projet (IK à échantillonner, textures sans mipmaps, objets d'accessoires
séparés, noms `_loop` dans Godot).

**Choix d'intégration (réversibles)** : skills en français avec déclencheurs FR/EN dans les descriptions ;
noms de dossiers du kit conservés ; contenu générique dans `.claude/skills/`, contenu propre au jeu dans
`docs/art/` ; le ZIP n'est pas commité (il reste à la racine, non suivi) ; rien d'existant n'a été supprimé ;
journaux et sauvegardes Blender ignorés par Git.

## 3. Tests réellement exécutés

| Test | Résultat |
|---|---|
| `valider_skills.py` sur le projet | 25 skills, **0 erreur** (en-têtes, noms, liens internes, routage, workflows, absence de dépendance MCP) |
| Test négatif du validateur (5 erreurs injectées dans une copie) | **5/5 détectées**, code de sortie 1 |
| `test_selection.py` (14 demandes, dont les 5 exemples de la demande) | **14/14** ; un échec initial (zébu + 3D : sujet écrasé par la technique) corrigé en rendant les « sujets » toujours retenus et lus en premier |
| Claude Code 2.1.326 en mode sans interface, dans le projet | Les **25 skills sont découverts** ; pour « crée un zébu en 3D dans Blender », il choisit spontanément : game-art-router, visual-reference-research, animal-and-creature-design, drawing-fundamentals, blender-python-pipeline, 3d-modeling-and-topology, uv-and-texturing, colour-light-and-materials, rigging-and-skinning, game-3d-optimization-and-export, visual-quality-review |
| Pipeline Blender 5.3 sur une **copie** de la villageoise v4 | Inspection, planches (4 vues + 6 images d'un cycle de course × 2 vues), export GLB, audit (8 165 triangles, 9 animations, 2 textures) : **code 0** ; source **inchangée** (md5) ; sauvegarde horodatée créée |
| Lanceur : délai dépassé / erreur Python | Code 137 / code 1, trace dans le journal |
| Rendu SVG (« dessiner une image ») | Icône SVG rendue en PNG par `qlmanage` et inspectée |
| Liens externes | ~70 vérifiés : 200 OK, 403/429 marqués « non vérifiés automatiquement », 404 remplacés |

**Non testé** (outil absent) : génération d'images par IA (aucun générateur branché à la session) ;
retouche par inpainting ; Codex et Copilot (seul `AGENTS.md` est fourni, sans essai).

## 4. Lacunes restantes

1. **Génération d'images** : les skills rédigent et contrôlent des prompts, mais la session n'a pas de
   générateur ; à brancher (outil d'image, ou ComfyUI local) pour produire des concepts peints.
2. **Jugement visuel** : l'agent regarde les rendus, mais des erreurs subtiles (anatomie fine, expressions)
   peuvent lui échapper ; garder une validation humaine pour les assets clés.
3. **Culture** : sources encyclopédiques seulement ; points « à vérifier » listés (cases, vêtements, coiffures,
   portage de l'eau, fourrage, termes malgaches) ; idéalement relecture par une personne de l'Androy.
4. **Outils 3D manquants** : pas de script générique d'UV automatique, de baking ni de retopologie (seule la
   décimation est outillée) ; à ajouter au besoin.
5. **Bible** : illustrations promotionnelles, unités autres que la villageoise, architecture exacte : à décider.
6. **Ressources** : conditions de Mixamo et de la base CMU à relire avant tout usage commercial ; licence de
   ComfyUI à confirmer.
7. **Skills du kit externes** (MengTo, EL4CTEO, RobLe3…) : référencés, non installés ; à évaluer un par un si
   besoin (dépendances, MCP).
