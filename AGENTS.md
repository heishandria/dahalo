# Instructions pour les agents d'IA (Codex, Copilot, Claude Code…)

1. **Règles du projet (code, architecture, culture)** : lire `CLAUDE.md` à la racine. Elles s'appliquent à
   tous les agents, pas seulement à Claude.
2. **Travail artistique** (dessin, illustration, personnage, animal, environnement, animation, modèle 3D,
   texture, génération d'image) : lire `.claude/skills/game-art-router/SKILL.md`, puis les skills qu'il désigne.
   Pour les choisir automatiquement :

       python3 .claude/skills/game-art-router/scripts/selectionner_skills.py "<la demande>"

3. **Bible artistique** : `docs/art/bible-artistique.md` ; faits culturels sourcés :
   `docs/art/madagascar-references.md` ; guide complet : `docs/art/README.md`.
4. **Blender sans MCP** : scripts dans `.claude/skills/blender-python-pipeline/scripts/` (lanceur avec journal
   et sauvegarde, rendus de vérification, export et audit GLB). Ne jamais écraser un `.blend` source.
5. **Contrôle visuel** : rendre et regarder chaque résultat avant de le déclarer terminé ; ne jamais affirmer un
   test non exécuté.
