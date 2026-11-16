# Spec — Économie : nourriture, eau, bois, Ariary, zébus

> Statut : **prototype v0.4** (16/11/2026). Décrit ce qui est **réellement codé**.
> Le GDD donne la vision ; cette spec donne les règles et les chiffres en vigueur.
> Valeurs : `data/game_rules.gd` et `data/units/*.tres`. Toute modification de ces fichiers met à jour cette page.

## 1. Vue d'ensemble

| Ressource | Sources | Qui récolte | Sert à | Départ |
|---|---|---|---|---|
| **Nourriture** | Champs de maïs / sorgho, raketa | Villageois | Former les unités, **nourrir les zébus** | 150 |
| **Eau** | Points d'eau, puits | Villageois | **Abreuver les zébus** | 100 |
| **Bois** | Forêts d'épineux | Villageois | Construire, resemer les champs | 150 |
| **Ariary** | Vente de zébus au Tsena | — | Acheter au Tsena, puits | 50 |
| *Zébus* | Troupeaux sauvages, enclos rivaux | Dahalo | Victoire, vente | 0 |

Décisions de design (16/11/2026) :
- **Les hommes ne consomment rien.** Seuls les zébus en enclos mangent et boivent.
- **Pas de pierre** : ce qu'elle aurait construit se paie en bois + Ariary (pourra revenir à l'Âge 2).
- **Un zébu affamé ou assoiffé ne meurt pas : il s'enfuit** et redevient sauvage (on peut le reprendre).

Stocks par clan, non plafonnés.

## 2. Entretien du cheptel

Prélevé en continu, uniquement pour les zébus **sécurisés en enclos** (pas ceux en escorte) :

| Par zébu | Par seconde | Par minute |
|---|---|---|
| Eau | 0,05 | 3 |
| Nourriture | 0,04 | 2,4 |

- 20 zébus = **60 eau/min + 48 nourriture/min**. Le HUD affiche la consommation (« −X/min »).
- **Manque** : si l'eau **ou** la nourriture tombe à 0, un message d'alerte s'affiche, puis **un zébu s'enfuit
  toutes les 20 s** tant que le manque dure. Il quitte l'enclos, part à ~22 m et redevient sauvage.
- C'est le frein contre le leader (GDD §7) : un gros cheptel exige beaucoup de porteurs d'eau et de champs.

## 3. Sources

| Source | Type | Quantité | Récolte | Particularité |
|---|---|---|---|---|
| **Champ** (construit) | Nourriture | 150 par récolte | Normale | **Ne pousse que si des villageois le cultivent**, voir §4 |
| **Raketa** (cactus, nature) | Nourriture | Infinie | ×0,6 | En sécheresse, chaque unité récoltée donne aussi **+0,5 eau** au clan |
| **Point d'eau** (nature) | Eau | Infinie | Normale | ×0,3 en sécheresse, rétrécit à l'écran |
| **Puits** (construit) | Eau | Infinie | Normale | ×0,6 en sécheresse ; réservé à son clan |
| **Épineux** (nature, en forêts) | Bois | 50 par arbre (~5 allers-retours) | Normale | **Rapetisse à chaque coupe puis disparaît** ; un nouvel arbre repousse au même endroit 240 s plus tard |
| Baobab | — | — | — | **Décor uniquement**, jamais coupé |

Les sources naturelles sont accessibles à tous les clans ; champs et puits seulement à leur propriétaire.

## 4. Champs (façon fermes d'Age of Empires)

1. **Le joueur pose le champ** (bouton « Champ », 60 bois). Il est semé, mais **ne pousse pas tout seul**.
2. **Culture** : il faut **envoyer des villageois dessus**. Chaque villageois présent fait avancer la pousse :
   1 villageois = 60 s, 2 = 30 s, 3 = 20 s. Au-delà de **3**, les villageois en plus n'accélèrent plus.
   La sécheresse divise la vitesse de culture par 2. Un villageois chargé va d'abord déposer, puis revient cultiver.
3. **Mûr** (doré) : 150 nourriture. Les mêmes villageois **récoltent automatiquement**.
4. **Vide** : il est **resemé automatiquement pour 15 bois** et repasse en culture : les villageois restés
   sur le champ enchaînent (cultiver → récolter → déposer → cultiver…). Sans bois, il passe **en friche**
   et réessaie toutes les 2 s dès que le bois revient.
5. Une **étiquette** au-dessus du champ indique l'état : « En culture 40 % – 2 villageois », « Mûr : 150 nourriture »,
   « En friche ».

Chaque clan démarre avec **2 champs mûrs**.

## 5. Récolte (villageois)

- **Cycle** : source → récolte → dépôt le plus proche qui accepte la ressource → retour à la même source.
- **Dépôts** : Case centrale (tout) et **Camp de bûcherons** (bois seulement), à placer près des forêts.
- **Cadence** : 2 unités/s (paquets d'une seconde) × rendement de la source ; **capacité 10**.
- **Portées** : récolte < 2,2 m de la source, dépôt < 3,5 m du bâtiment.
- **Source indisponible** : champ en culture → le cultiver ; arbre abattu ou source disparue → source du même type
  la plus proche (< 30 m), sinon arrêt.
- Changer de type de ressource fait perdre la charge en cours.

## 6. Bâtiments et coûts

| Élément | Coût | Effet |
|---|---|---|
| Enclos | 100 bois | +10 places de cheptel |
| Champ | 60 bois (+15 bois par resemis) | Nourriture renouvelable |
| Camp de bûcherons | 80 bois | Dépôt de bois au plus près des forêts |
| Puits | 60 bois + 40 Ar | Eau infinie, moins sensible à la sécheresse |
| Tsena | 150 bois (1 par clan) | Marché : vente de zébus, achats |
| Villageois | 50 nourriture, 6 s | Récolte |
| Pisteur | 40 nourriture + 10 bois, 8 s | Unité rapide (vision : à venir) |
| Dahalo armé | 60 nourriture + 20 bois, 10 s | Capture, escorte, raids, combat au contact |
| Lanceur de sagaies | 50 nourriture + 25 bois, 10 s | Combat à distance (voir `combat.md`) |
| Tireur (fusil) | 60 nourriture + 20 bois + 60 Ar, 14 s | Nécessite un Tsena (voir `combat.md`) |

Construction immédiate, sans prévisualisation ni contrôle de chevauchement (à venir).

## 7. Tsena (marché) et Ariary

| Action | Effet |
|---|---|
| **Vendre un zébu** | +40 Ar ; **×0,5 pendant la sécheresse** (tout le monde vend, les prix chutent) |
| Zébu **volé depuis moins de 3 min** | Prix ×0,4 (les marchands se méfient). Le Tsena vend d'abord un zébu « en règle » |
| Acheter du bois | 50 bois pour 30 Ar |
| Acheter de la nourriture | 50 nourriture pour 30 Ar |

Vendre fait **baisser le cheptel** : c'est un arbitrage entre score de victoire et développement.

## 8. Climat (GDD §7)

- **Jour/nuit** : cycle de 4 min, dont 35 % de nuit (~1 min 25 s).
- **Sécheresse** : le 3ᵉ jour de chaque série de 3 jours. Sur une partie de 30 min : **8–12 min** et **20–24 min**.
- Effets : points d'eau ×0,3, puits ×0,6, champs poussent 2× moins vite, raketa donne de l'eau, zébu vendu moitié prix.

## 9. Victoire

- Capacité de cheptel = 10 × nombre d'enclos. Un zébu escorté n'entre pas si les enclos sont pleins.
- **50 zébus sécurisés**, ou le plus grand cheptel au bout de **30 min** (égalité possible).

## 10. IA (prototype)

Récolte selon ses besoins (objectifs d'eau et de nourriture qui grandissent avec son cheptel, eau ×2 en
sécheresse), construit des champs (1 pour 3 villageois, 4 max) et des enclos. **Pas encore** de Tsena,
de puits ni de camp de bûcherons pour l'IA.

## 11. Écarts avec le GDD (à reporter dans le GDD)

| GDD | Prototype | Statut |
|---|---|---|
| Nourriture par la chasse et la cueillette | Champs + raketa | **Décidé** (16/11) |
| 4 ressources dont Zébus | Nourriture, eau, bois, **Ariary** (+ zébus) | **Décidé** |
| Eau pour villageois et cheptel | Seuls les zébus consomment | **Décidé** |
| Déshydratation **mortelle** du cheptel | Le zébu **s'enfuit** | **Décidé** |
| Bois coupé sur les baobabs | Forêts d'épineux ; baobabs en décor | **Décidé** |
| Marché : surplus contre zébus | Vente de zébus contre Ariary, achats en Ariary | **Décidé** ; achat de zébus à l'Âge 3 |
| Barre d'hydratation par unité | Stock d'eau global du clan | À confirmer |
| Technologies (Vannerie, Puits profonds, Maîtres du Tsena…) | Absentes | À brancher sur ces valeurs |

## 12. Questions ouvertes

1. Caravanes de marchands à intervalles (fenêtres de vente) plutôt qu'un Tsena toujours ouvert ?
2. Plafonner les stocks (greniers, citernes) pour forcer des choix ?
3. Achat de zébus reproducteurs au Tsena (GDD Âge 3) : prix ?
4. Pierre à l'Âge 2 pour les constructions avancées ?
