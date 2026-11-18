# Workflow : animation pour le jeu (cycle ou action)

Skills : game-art-router → animation-fundamentals → locomotion-animation → rigging-and-skinning →
blender-python-pipeline → visual-quality-review.

1. **Besoin en jeu** : état (marche, course, puiser, se coucher…), vitesse réelle de l'unité (m/s), boucle ou
   non, durée imposée par la logique du jeu, transitions.
2. **Poses clés** (2–5) dessinées ou posées ; contrôle de l'équilibre et des appuis.
3. **Génération** par script (trajectoires des pieds + IK analytique, `ik_deux_os.py`) ou retouche d'une action
   existante ; racine immobile ; première image = dernière pour une boucle ; interpolation linéaire.
4. **Calage** : `vitesse_calage()` → noter la vitesse (m/s) ; si la vitesse du jeu dépasse ~2,5 × le calage,
   créer une autre allure.
5. **Planche** : `rendu_verification.py -- --action NOM --images 8` ; regarder profil et face.
6. **Revue** : appuis sans glissement, sens des articulations, pas de pénétration du sol, boucle sans saut,
   lisibilité à la caméra de jeu.
7. **Export** (`--echantillonner` si contraintes) → audit → intégration (noms sans `_loop` côté Godot, vitesse de
   lecture = vitesse réelle / calage) → capture en jeu à la vitesse réelle.
