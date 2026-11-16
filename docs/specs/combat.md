# Spec — Combat et armes

> Statut : **prototype v0.4.1** (16/11/2026). Décrit ce qui est **réellement codé**.
> Valeurs : `data/units/*.tres` (dégâts, portée, cadence, PV) et `scenes/units/unite.gd` (comportements).

## 1. Principes

- Le combat sert à **protéger ou attaquer un troupeau**, pas à anéantir l'adversaire : la victoire reste le cheptel.
- **Les unités meurent au combat** (décision du 16/11/2026) : à 0 PV, l'unité tombe, reste au sol 5 s puis disparaît,
  sans effet sanglant. Les **zébus ne sont jamais blessés ni tués**.
- Les bâtiments ne peuvent pas encore être attaqués (palissade et sabotage : à venir).

## 2. Unités

| Unité | Arme | PV | Dégâts | Portée | Cadence | Coût | Particularité |
|---|---|---|---|---|---|---|---|
| Villageois | — | 50 | — | — | — | 50 nourr. | Ne combat pas |
| Pisteur | — | 40 | — | — | — | 40 nourr. + 10 bois | Ne combat pas |
| **Dahalo armé** | Sagaie, coupe-coupe | 120 | 12 | 1,8 m (contact) | 1 s | 60 nourr. + 20 bois | **Seul à capturer et escorter** |
| **Lanceur de sagaies** | Sagaies de jet | 70 | 9 | 9 m | 1,6 s | 50 nourr. + 25 bois | Soutien à distance |
| **Tireur** | Fusil de traite | 80 | 30 | 15 m | 3,5 s (rechargement) | 60 nourr. + 20 bois + **60 Ar** | **Nécessite un Tsena** (armes achetées aux marchands) |

Dégâts par seconde : Dahalo 12, Lanceur ~5,6, Tireur ~8,6. Le Dahalo domine au contact ; le Tireur
frappe fort et de loin, mais lentement : il doit être protégé.

Tous sont formés à la Case centrale (touches 1 à 5 ou ligne « Former »). La Case des Hommes du GDD viendra ensuite.

## 3. Comportements

- **Ordre d'attaque** : unités sélectionnées puis clic droit (ou toucher) sur une unité ennemie.
  L'unité s'approche à portée, se tourne vers la cible et frappe à chaque fin de recharge.
- **Engagement automatique** : un guerrier **inactif** attaque le premier ennemi **visible** qui entre dans son
  champ de vision (Dahalo 14 m, Lanceur 14 m, Tireur 18 m ; ×0,6 la nuit), vérifié toutes les 0,5 s.
  Une attaque s'interrompt si la cible sort du champ de vision (voir `vision.md`).
- **Riposte** : un guerrier frappé alors qu'il fait autre chose (marcher, piller…) riposte contre son agresseur,
  **sauf s'il escorte un troupeau** (il continue sa fuite).
- Les unités en déplacement n'attaquent pas d'elles-mêmes (pas encore d'« attaque en mouvement »).
- Attaques à distance : un trait bref est affiché (brun pour la sagaie, jaune pour le fusil).
- **Barre de vie** au-dessus de l'unité dès qu'elle est blessée (vert → rouge). Pas de régénération.

## 4. Mort

À 0 PV, l'unité :
1. **lâche son troupeau** : les zébus escortés redeviennent sauvages sur place (chacun peut les capturer) ;
2. devient immédiatement non sélectionnable et non ciblable, prend une teinte sombre ;
3. **tombe au sol**, reste 5 s, puis s'efface (message « … est tombé au combat » pour le joueur).

Villageois et pisteurs peuvent aussi être tués s'ils sont attaqués.

## 5. IA

- **Défense** : si une unité ennemie approche à moins de 22 m de sa Case centrale ou d'un de ses enclos,
  tous ses guerriers (sauf ceux qui escortent) attaquent l'intrus le plus proche.
- **Armée** : jusqu'à 3 Dahalo et 2 Lanceurs. **Pas de Tireurs** (l'IA ne construit pas encore de Tsena).

## 6. Écarts avec le GDD

| GDD | Prototype | Statut |
|---|---|---|
| Dahalo armé (sagaies, coupe-coupe) | Dahalo + Lanceur + Tireur | **Décidé** (16/11) : fusils via le Tsena |
| « Sagaies acérées » (Âge 2) : + dégâts | Absente | À brancher sur `degats` |
| « Raid éclair » (Âge 3) : + vitesse en fuite | Absente | À brancher sur l'escorte |
| Sabotage de palissades, infiltration | Absents | Avec la palissade |
| Pénalité de vision la nuit | Vision ×0,6 la nuit (×0,9 Pisteur) | **Fait** (voir `vision.md`) |

## 7. Questions ouvertes

1. Fusils : limiter leur nombre (rareté, munitions en Ariary) pour garder le Dahalo au centre du jeu ?
2. Attaque en mouvement et formations (escorte protégée par des Lanceurs) ?
