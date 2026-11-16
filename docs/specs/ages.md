# Spec — Âges et technologies

> Statut : **prototype v0.8** (16/11/2026). Décrit ce qui est **réellement codé**.
> Valeurs : `data/game_rules.gd` (TECHNOLOGIES, NOMS_AGES, BONUS_*). GDD §6.

## 1. Principe

- Trois âges : **1 – Clan de la Brousse** (départ), **2 – Pistes et Convois**, **3 – Seigneurs des Zébus**.
- Le passage d'âge est une **recherche à la Case centrale**. Chaque âge débloque ses technologies.
- **Une recherche à la fois par bâtiment** (le passage d'âge occupe la Case centrale).
- Ligne de boutons **« Recherche »** : n'affiche que ce qui est accessible maintenant ; se met à jour à chaque
  technologie acquise. Le message de lancement rappelle l'effet. L'âge actuel est affiché dans le bandeau.

## 2. Passages d'âge

| Passage | Coût | Durée | Débloque aussi |
|---|---|---|---|
| Âge 1 → 2 | 250 nourriture + 200 bois + 60 Ar | 40 s | **Tireur** (fusil) |
| Âge 2 → 3 | 400 nourriture + 300 bois + 150 Ar | 60 s | — |

Les Ariary viennent de la vente de zébus au Tsena : monter en âge **coûte du cheptel**.

## 3. Technologies

| Âge | Technologie | Où | Coût | Durée | Effet |
|---|---|---|---|---|---|
| 1 | **Cultures traditionnelles** | Case centrale | 80 nourr. + 60 bois | 25 s | Champs : **+25 %** de récolte (150 → 187) |
| 1 | **Marcheurs de l'Androy** | Case centrale | 100 nourr. | 25 s | **+15 % de vitesse** pour toutes les unités |
| 1 | **Vannerie et cuirs** | Case centrale | 50 nourr. + 60 bois | 25 s | Capacité de transport des villageois **+50 %** (10 → 15) |
| 2 | **Sagaies acérées** | Case des Hommes | 100 nourr. + 50 bois + 40 Ar | 30 s | **+30 % de dégâts** pour les sagaies (Dahalo, Lanceur) |
| 2 | **Technique des pisteurs** | Case centrale | 80 nourr. + 40 Ar | 30 s | Les traces des voleurs apparaissent **sans Pisteur** et **sur la mini-carte** |
| 2 | **Puits profonds** | Case centrale | 120 bois + 60 Ar | 35 s | Pénalité de sécheresse sur l'eau **divisée par 2** (point d'eau 30 % → 65 %, puits 60 % → 80 %) |
| 3 | **Pacte des grands éleveurs** | Case centrale | 200 nourr. + 100 Ar | 45 s | **Un veau naît toutes les 90 s** dans chaque enclos qui a au moins 2 zébus (s'il reste de la place et si le cheptel ne manque de rien) |
| 3 | **Raid éclair** | Case des Hommes | 150 nourr. + 80 Ar | 40 s | Escorte : vitesse **×0,85** au lieu de ×0,6 |
| 3 | **Maîtres du Tsena** | Tsena | 100 bois + 120 Ar | 40 s | Zébus vendus **+25 %**, achats **−1/3** (30 → 20 Ar), **achat de zébus reproducteurs** (80 Ar, livrés à l'enclos) |

## 4. IA

- Suit un plan fixe : Cultures → Vannerie → Âge 2 → Sagaies → Puits profonds → Marcheurs → Âge 3 → Pacte → Raid éclair,
  dans l'ordre, en gardant une réserve (120 nourriture, 100 bois) après paiement.
- Construit un **Tsena** (à partir de 6 villageois et 250 bois) et **vend des zébus** quand il lui manque des Ariary
  pour la prochaine étape (si elle a au moins 6 zébus et hors sécheresse).

## 5. Écarts avec le GDD

| GDD | Prototype | Statut |
|---|---|---|
| Chasse traditionnelle : +25 % de chasse | **Cultures traditionnelles** : +25 % de récolte des champs (pas de chasse dans le jeu) | **Adapté** (16/11) |
| Marcheurs de l'Androy : +15 % sur terrain sableux et épineux | +15 % partout (tout le terrain est sableux) | Fait |
| Technique des pisteurs : pistes des troupeaux volés sur la mini-carte | Traces visibles sans Pisteur + sur la mini-carte | Fait |
| Puits profonds : −50 % de pénalité de sécheresse | Idem (points d'eau et puits) | Fait |
| Pacte des grands éleveurs : reproduction passive si bien abreuvés | Veau toutes les 90 s par enclos de 2+ zébus, sans manque | Fait |
| Maîtres du Tsena : taxes réduites + zébus reproducteurs | Vente +25 %, achats −1/3, zébu à 80 Ar | Fait |

## 6. Questions ouvertes

1. Les passages d'âge doivent-ils demander un **nombre minimum de zébus** (prestige) en plus des ressources ?
2. Ajouter des bâtiments ou unités propres à chaque âge (ex. palissade renforcée à l'Âge 2) ?
3. Équilibrage : le Pacte (veaux gratuits) risque d'accélérer fortement la fin de partie — à surveiller en test.
