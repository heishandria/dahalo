# Spec — Défense du village : Case des Hommes, palissade, améliorations

> Statut : **prototype v0.6** (16/11/2026). Décrit ce qui est **réellement codé**.
> Valeurs : `data/game_rules.gd` (COUTS_BATIMENTS, FORMATIONS, PALISSADE_*, TECHNOLOGIES).

## 1. Case des Hommes (GDD §5)

- **Coût** : 120 bois. Bouton « Case Hommes » (ligne « Clan »).
- **Forme les guerriers** : Dahalo, Lanceur de sagaies, Tireur. La **Case centrale** ne forme plus que
  les villageois et les pisteurs.
- Sans Case des Hommes, les boutons de guerriers affichent : « Construisez d'abord une Case des Hommes ».
- Le Tireur demande **en plus** un Tsena (fusils achetés aux marchands).
- C'est aussi le lieu des **recherches militaires** (§3).

## 2. Palissade épineuse (GDD §5)

| Propriété | Valeur |
|---|---|
| Coût | 15 bois par segment de 4 m |
| Points de vie | 150 |
| Effet | Les **ennemis** qui la traversent avancent à **35 %** de leur vitesse |
| Vision | Comme un bâtiment (12 m, 7,2 m la nuit) : elle sert aussi de poste de guet |

- **Pose** : bouton « Palissade », puis toucher le sol **autant de fois que de segments**. Le mode reste actif
  jusqu'à « Aucun », Échap ou clic droit.
- **Orientation automatique** : chaque segment est placé de face, perpendiculaire à la direction depuis
  la Case centrale (il « regarde » vers l'extérieur du village).
- Elle **ne bloque pas** le passage : c'est un frein, qui laisse le temps de réagir à un raid.
- **Sabotage** : les guerriers ennemis peuvent l'attaquer (clic droit / toucher sur la palissade).
  À 0 PV elle disparaît (message « Une palissade a été sabotée ! »).
- L'engagement automatique ne cible pas les palissades : le sabotage est toujours un ordre explicite.

## 3. Améliorations

| Technologie | Où | Coût | Durée | Effet |
|---|---|---|---|---|
| **Sagaies acérées** (**Âge 2**) | Case des Hommes | 100 nourriture + 50 bois + 40 Ar | 30 s | **+30 % de dégâts** pour les armes à sagaie (Dahalo, Lanceur) |
| **Raid éclair** (**Âge 3**) | Case des Hommes | 150 nourriture + 80 Ar | 40 s | Escorte presque à pleine vitesse |

Une seule recherche à la fois par bâtiment. Toutes les technologies : voir `ages.md`.

## 4. IA

- Construit sa **Case des Hommes** dès qu'elle a 4 villageois et 120 bois, puis y forme Dahalo et Lanceurs.
- Recherche Sagaies acérées et Raid éclair selon son plan (voir `ages.md`).
- **Pas encore** : palissades, sabotage.

## 5. Écarts avec le GDD

| GDD | Prototype | Statut |
|---|---|---|
| Case des Hommes : convertit des villageois en Dahalo | Forme des guerriers neufs (coût en ressources) | À trancher : conversion de villageois ? |
| Palissade : ralentit l'intrusion des Dahalo | Ralentit **tous** les ennemis à 35 % | **Fait** |
| Dahalo : sabotage de palissades | Tout guerrier peut l'attaquer | **Fait** |
| « Sagaies acérées » en Âge 2 | Âge 2 | **Fait** (voir `ages.md`) |

## 6. Questions ouvertes

1. Palissade **bloquante** (vrai mur avec portes) plutôt que ralentissante ?
2. Les Dahalo doivent-ils saboter **plus vite** que les autres guerriers (bonus d'infiltration) ?
3. Former un guerrier en **convertissant un villageois** (comme le dit le GDD) ?
