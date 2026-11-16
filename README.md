# Dahalo : Les Seigneurs des Zébus — prototype « grey box »

Squelette Godot 4 du RTS : premier prototype jouable **en solo contre une IA**, avec des formes simples
(cubes, capsules) pour tester la boucle de jeu avant tout travail graphique.

## Installation

1. Installer **Godot 4.4 ou plus récent**, version *standard* (pas « .NET ») : https://godotengine.org/download
2. Installer **VS Code** + l'extension **godot-tools**, puis dans Godot :
   *Éditeur > Paramètres de l'éditeur > Text Editor > External* → activer et pointer vers VS Code.
3. Installer **Git** et **Git LFS** (`git lfs install`), puis initialiser le dépôt :
   ```bash
   cd dahalo
   git init && git lfs install
   git add . && git commit -m "Squelette initial du prototype"
   ```
4. Ouvrir Godot → *Importer* → sélectionner `project.godot`. Au premier lancement, Godot crée le dossier
   `.godot/` (ignoré par Git) et des fichiers `.uid` (à versionner).
5. Lancer avec **F5**.
6. Pour travailler avec Claude : lancer **Claude Code** à la racine du dépôt. Il lira `CLAUDE.md`.

## Commandes de jeu

| Action | Commande |
|---|---|
| Sélectionner | Clic gauche (Maj = ajouter), glisser = cadre |
| Ordre contextuel | Clic droit : sur une ressource = récolter, sur un zébu = capturer (Dahalo), sur un **enclos rival = raid automatique** (jusqu'à 5 zébus puis retour), sur votre enclos = ramener le troupeau, sur le sol = déplacer |
| Former | `1` Villageois · `2` Dahalo · `3` Pisteur (depuis la Case centrale) |
| Construire un enclos | `E` sous la souris (100 bois) |
| Caméra | ZQSD / WASD, flèches, bords de l'écran · molette = zoom |
| Désélectionner | Échap |
| **Tactile** | Toucher une unité, puis toucher sa cible · glisser = caméra · pincer = zoom · boutons en bas à droite pour choisir, créer, poser un enclos |

**But** : 50 zébus sécurisés dans vos enclos, ou le plus grand cheptel au bout de 30 minutes.

## Tester sur iPhone (version web)

Il n'existe pas d'éditeur Godot sur iOS : l'export se fait depuis l'ordinateur, puis on joue dans Safari.
Le preset **Web** est déjà configuré (`export_presets.cfg`) : sans threads, donc compatible itch.io,
GitHub Pages et Safari iOS sans réglage serveur particulier.

1. **Modèles d'export** (une seule fois) : dans Godot, *Éditeur > Gérer les modèles d'export >
   Télécharger et installer* (même version que l'éditeur).
2. **Test rapide sur PC** : bouton *Exécuter dans le navigateur* (icône HTML5 en haut à droite de l'éditeur).
3. **Exporter** : *Projet > Exporter… > Web > Exporter le projet* → fichiers générés dans `build/web/`.
4. **Zipper le contenu** de `build/web/` (le fichier `index.html` doit être à la racine du zip).
5. **Publier sur itch.io** (gratuit) :
   - *Upload new project* → *Kind of project* : **HTML** → envoyer le zip ;
   - cocher **This file will be played in the browser** ;
   - *Embed options* : cocher **Mobile friendly**, orientation **Landscape**, activer le **bouton plein écran** ;
   - *Visibility* : **Draft** (brouillon : seul toi y as accès, connecté à ton compte itch.io).
6. **Sur l'iPhone** : ouvrir la page dans Safari (connecté à itch.io), tourner le téléphone en **paysage**, lancer.

À chaque nouvelle version : refaire les étapes 3 à 5 en remplaçant le zip.

## Ce que fait déjà le prototype

- Caméra isométrique 2,5D (orthographique), sélection au cadre, ordres contextuels.
- Commandes tactiles (toucher, glisser, pincer) et boutons d'action : jouable sur mobile et tablette.
- Villageois : récolte du bois (baobabs), de l'eau (points d'eau) et de la nourriture (buissons), retour au dépôt.
- Dahalo : capture de zébus sauvages, escorte (ralentie), sécurisation dans l'enclos, vol dans les enclos adverses,
  reprise d'un troupeau escorté par l'ennemi.
- Enclos : +10 places de cheptel chacun.
- Cycle jour/nuit (4 min) ; sécheresse cyclique (puisage à 30 %, sol plus clair).
- Le cheptel et les villageois consomment de l'eau ; sans eau, le village travaille au ralenti.
- IA rivale : économie équilibrée, formation, construction d'enclos, raids sur les zébus sauvages,
  pillage de vos enclos **la nuit**.

## Structure

```
autoload/          Singletons globaux
  event_bus.gd       signaux partagés (HUD, IA, audio…)
  input_setup.gd     déclaration des touches
  game_clock.gd      temps, jour/nuit, sécheresse
  resource_manager.gd stocks, cheptel, eau, victoire
  command_bus.gd     TOUTES les actions de jeu (joueur + IA) → prêt pour le multijoueur
data/
  game_rules.gd      règles et équilibrage globaux
  unit_data.gd       fiche d'unité (Resource)
  units/*.tres       villageois, pisteur, dahalo : modifier ici pour équilibrer
scenes/
  main.tscn/.gd      carte de test symétrique, création d'entités, ambiance
  units/             unite (villageois/pisteur/dahalo), zebu
  buildings/         batiment (case centrale), enclos
  world/             noeud_ressource (bois/eau/nourriture)
systems/
  rts_camera.gd, selection_manager.gd, ai_controller.gd
ui/hud.gd          bandeau ressources, sélection, messages, fin de partie
assets/            modèles, textures, sons (suivis par Git LFS)
tests/             tests automatisés (à venir avec gdUnit4)
```

## Pas encore fait (écarts assumés avec le GDD)

- **Combat** (PV, attaque, mort) : pour l'instant, la seule contre-attaque est de reprendre le troupeau.
- **Brouillard de guerre** et vision réduite la nuit (le Pisteur n'a pas encore son rôle).
- **Case des Hommes, Puits, Marché, Palissade** ; les Dahalo sont formés à la Case centrale en attendant.
- **Arbre des technologies** (3 âges).
- **Déshydratation mortelle** du cheptel.
- **Carte procédurale**, campagne, mode survie, multijoueur.
- Placement des bâtiments sans prévisualisation ni vérification de chevauchement.

## Prochaines étapes proposées

1. Tester la boucle et ajuster `game_rules.gd` et les `.tres`.
2. Combat de base + PV + mort des unités.
3. Brouillard de guerre et vision nocturne.
4. Bâtiments manquants et prévisualisation de placement.
5. Tests automatisés (gdUnit4) sur `ResourceManager` et `CommandBus`.
