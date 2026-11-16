# Spec — Économie : bois, eau, nourriture, zébus

> Statut : **prototype v0.2** (16/11/2026). Décrit ce qui est **réellement codé**.
> Le GDD donne la vision ; cette spec donne les règles et les chiffres en vigueur.
> Valeurs : `data/game_rules.gd` et `data/units/*.tres`. Toute modification de ces fichiers met à jour cette page.

## 1. Vue d'ensemble

| Ressource | Source | Qui récolte | Usage | Stock de départ |
|---|---|---|---|---|
| **Bois** | Baobabs (s'épuisent) | Villageois | Enclos, formation (Dahalo, Pisteur) | 150 |
| **Eau** | Points d'eau (inépuisables) | Villageois | Survie du cheptel et des villageois | 100 |
| **Nourriture** | Buissons de cueillette (s'épuisent) | Villageois | Formation de toutes les unités | 150 |
| **Zébus** | Troupeaux sauvages, enclos rivaux | Dahalo | Victoire | 0 (1 enclos vide) |

Un seul point de dépôt : la **Case centrale**. Les stocks sont par clan et ne sont pas plafonnés.

## 2. Sources sur la carte (carte de test symétrique)

| Source | Quantité | Par base | Au centre | Particularité |
|---|---|---|---|---|
| Baobab (bois) | 250 près des bases, 400 au centre | 4 | 4 | Disparaît une fois vide |
| Point d'eau | Infini | 1 | 2 | Rendement ×0,3 pendant la sécheresse, rétrécit à l'écran |
| Buisson (nourriture) | 200 | 2 | 0 | Disparaît une fois vide |

## 3. Récolte (villageois)

- **Cycle** : aller à la source → récolter → rentrer à la Case centrale → déposer → repartir vers la même source.
- **Cadence** : 2 unités par seconde (par paquets d'une seconde), **capacité de transport 10**.
- **Portées** : récolte à moins de 2,2 m de la source, dépôt à moins de 3,5 m de la case.
- **Source épuisée** : le villageois cherche la source du même type la plus proche dans un rayon de 30 m, sinon il s'arrête.
- **Changement de ressource** : si un villageois chargé part sur un autre type, sa charge est perdue.
- **Soif du clan** : si l'eau tombe à 0, la récolte va **2 fois moins vite** (multiplicateur 0,5).
- Seuls les villageois récoltent. Dahalo et Pisteurs envoyés sur une ressource s'y déplacent simplement.

## 4. Consommation d'eau (anti-snowballing, GDD §7)

Prélevée en continu sur le stock d'eau du clan :

| Consommateur | Par seconde | Par minute |
|---|---|---|
| Zébu sécurisé en enclos | 0,05 | 3 |
| Villageois | 0,02 | 1,2 |

Exemple : 20 zébus + 8 villageois = **~70 eau/min**. Un villageois rapporte 10 eau par aller-retour ; il puise
en 5 s normalement, mais en ~17 s pendant la sécheresse. Un gros cheptel impose donc plusieurs porteurs d'eau,
surtout en sécheresse : c'est le frein voulu contre le leader.

Les zébus escortés (pas encore en enclos) et les Dahalo/Pisteurs ne boivent pas.

## 5. Coûts

| Élément | Coût | Temps | Effet |
|---|---|---|---|
| Villageois | 50 nourriture | 6 s | +1 récolteur |
| Pisteur | 40 nourriture + 10 bois | 8 s | Unité rapide (vision : à venir) |
| Dahalo armé | 60 nourriture + 20 bois | 10 s | Capture, escorte et raids |
| Enclos | 100 bois | Immédiat | +10 places de cheptel |

Coût payé au lancement de la formation, sans remboursement. Pas de limite de population.

## 6. Climat (GDD §7)

- **Jour/nuit** : cycle de 4 min, dont 35 % de nuit (~1 min 25 s).
- **Sécheresse** : le 3ᵉ jour de chaque série de 3 jours. Sur une partie de 30 min : **8–12 min** et **20–24 min**.
- Effet : puisage ×0,3. La consommation, elle, ne baisse pas → il faut **stocker de l'eau avant**.

## 7. Zébus et victoire

- Capacité de cheptel = 10 × nombre d'enclos. Un zébu escorté n'entre pas si les enclos sont pleins.
- **Victoire** : 50 zébus sécurisés, ou le plus grand cheptel au bout de **30 min** (égalité possible).
- Vol, escorte et raids : voir la future spec `raids.md`.

## 8. Écarts avec le GDD

| GDD | Prototype | Décision à prendre |
|---|---|---|
| Nourriture par la **chasse** (pintades, sangliers) et la cueillette | Cueillette seulement | Ajouter le gibier mobile ? |
| **Puits / Citerne** pour sécuriser l'eau | Absent | Puits = point d'eau constructible, moins touché par la sécheresse ? |
| **Marché (Tsena)** : échange de surplus | Absent | Taux d'échange à définir |
| **Déshydratation mortelle** du cheptel | Seulement un ralentissement des villageois | Combien de temps sans eau avant de perdre un zébu ? |
| Barre **Hydratation** par unité dans le HUD | Eau gérée au niveau du clan | Garder un stock global (plus lisible) ? |
| Technos : Vannerie et Cuirs, Chasse traditionnelle, Puits profonds | Absentes | À brancher sur les valeurs de cette spec |
| Croissance de la population par la nourriture | La nourriture ne sert qu'à former des unités | Consommation de nourriture dans le temps ? |

## 9. Questions ouvertes

1. **Couper des baobabs** : dans le Sud, le baobab est souvent respecté, parfois sacré, et peu utilisé
   comme bois d'œuvre. Proposition : bois tiré des **forêts d'épineux** (comme dans le GDD §2),
   et le baobab comme élément de décor ou source secondaire (fruits, eau stockée dans le tronc) — à valider.
2. Faut-il plafonner les stocks (greniers, citernes) pour forcer des choix ?
3. Les bois doivent-ils repousser lentement pour éviter une fin de partie sans ressources ?
