# Spec — Économie : nourriture, eau, bois, Ariary, zébus

> Statut : **prototype v0.9** (16/11/2026). Décrit ce qui est **réellement codé**.
> Le GDD donne la vision ; cette spec donne les règles et les chiffres en vigueur.
> Valeurs : `data/game_rules.gd` et `data/units/*.tres`. Toute modification de ces fichiers met à jour cette page.

## 1. Vue d'ensemble

| Ressource | Sources | Qui récolte | Sert à | Départ |
|---|---|---|---|---|
| **Nourriture** | Champs de maïs / sorgho, raketa | Villageois | Former les unités, **nourrir les zébus** | 150 |
| **Eau** | Points d'eau, puits | Villageois | **Abreuver les zébus** | 100 |
| **Bois** | Forêts d'épineux | Villageois | Construire, resemer les champs | 150 |
| **Ariary** | Vente de **surplus** (bois, nourriture) et de zébus au Tsena | — | Âges, technologies, Tireurs, puits, achats | 50 |
| *Zébus* | Troupeaux sauvages (**nouvelles arrivées à l'aube**, §9), enclos rivaux, veaux, achat | Dahalo | Victoire, vente | 0 |

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
| **Point d'eau** (nature) | Eau | Infinie | Normale | ×0,3 en sécheresse, rétrécit à l'écran. Un près de chaque base, et une paire de **trous d'eau** creusés dans le sable du lit de rivière (voir `carte.md`) |
| **Puits** (construit) | Eau | Infinie | Normale | ×0,6 en sécheresse ; réservé à son clan |
| **Épineux** (nature, en forêts) | Bois | 50 par arbre (~5 allers-retours) | Normale | **Rapetisse à chaque coupe puis disparaît** ; un nouvel arbre repousse au même endroit 240 s plus tard |
| Baobab | — | — | — | **Décor uniquement**, jamais coupé |

Les sources naturelles sont accessibles à tous les clans ; champs et puits seulement à leur propriétaire.

## 4. Champs (façon fermes d'Age of Empires)

1. **Le joueur pose le champ** (bouton « Champ », 60 bois). Il est semé, mais **ne pousse pas tout seul**.
2. **Culture** : il faut **envoyer des villageois dessus**. Chaque villageois présent fait avancer la pousse :
   1 villageois = 60 s, 2 = 30 s, 3 = 20 s. Au-delà de **3**, les villageois en plus n'accélèrent plus.
   La sécheresse divise la vitesse de culture par 2. Un villageois chargé va d'abord déposer, puis revient cultiver.
3. **Mûr** (plants secs, épis ou têtes de grains ; voir `carte.md`) : 150 nourriture. Les mêmes villageois **récoltent automatiquement**.
4. **Vide** : il est **resemé automatiquement pour 15 bois** et repasse en culture : les villageois restés
   sur le champ enchaînent (cultiver → récolter → déposer → cultiver…). Sans bois, il passe **en friche**
   et réessaie toutes les 2 s dès que le bois revient.
5. **Les villageois entrent dans le champ** : chacun reçoit un poste au hasard dans un sillon, au milieu des
   plants, et avance de quelques pas le long de son rang toutes les 6 à 9 s (cultiver comme récolter). Prévu pour
   jouer les animations de travail sur le personnage pendant toute la durée.
6. Une **étiquette** au-dessus du champ indique l'état : « En culture 40 % – 2 villageois », « Mûr : 150 nourriture »,
   « En friche ».

Chaque clan démarre avec **2 champs mûrs**.

## 5. Récolte (villageois)

- **Cycle** : source → récolte → dépôt le plus proche qui accepte la ressource → retour à la même source.
- **Dépôts** : Case centrale (tout) et **Camp de bûcherons** (bois seulement), à placer près des forêts.
- **Cadence** : 2 unités/s (paquets d'une seconde) × rendement de la source ; **capacité 10**.
- **Portées** : récolte < 2,2 m du **bord** de la source, dépôt < 3,5 m du **bord** du bâtiment. Un villageois arrivé
  au bout de son chemin, au plus près que le terrain le permet (bord d'un bosquet, d'un bâtiment), compte comme
  arrivé s'il est à moins de 2 m de plus. Une source vraiment hors d'atteinte (arbre au cœur d'un bosquet) est
  remplacée par la plus proche du même type.
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
| Case des Hommes | 120 bois | Forme les guerriers, recherche Sagaies acérées (voir `defense.md`) |
| Palissade épineuse | 15 bois par segment | Ralentit les ennemis (voir `defense.md`) |
| Villageois (Case centrale) | 50 nourriture, 6 s | Récolte |
| Pisteur | 40 nourriture + 10 bois, 8 s | Unité rapide (vision : à venir) |
| Dahalo armé | 60 nourriture + 20 bois, 10 s | Capture, escorte, raids, combat au contact |
| Lanceur de sagaies | 50 nourriture + 25 bois, 10 s | Combat à distance (voir `combat.md`) |
| Tireur (fusil) | 60 nourriture + 20 bois + 45 Ar, 14 s | Âge 2 + Tsena (voir `combat.md`) |

Construction immédiate, avec aperçu et refus des emplacements occupés (voir `interface.md`).

## 7. Tsena (marché) et Ariary

| Action | Effet |
|---|---|
| **Vendre un zébu** | +40 Ar ; **×0,5 pendant la sécheresse** (tout le monde vend, les prix chutent) |
| Zébu **volé depuis moins de 3 min** | Prix ×0,4 (les marchands se méfient). Le Tsena vend d'abord un zébu « en règle » |
| **Vendre du bois** | 50 bois → 15 Ar |
| **Vendre de la nourriture** | 50 nourriture → 15 Ar |
| Acheter du bois | 50 bois pour 30 Ar |
| Acheter de la nourriture | 50 nourriture pour 30 Ar |
| Acheter un zébu reproducteur | 80 Ar, livré à l'enclos (**Maîtres du Tsena**, Âge 3) |

Les surplus sont la source **normale** d'Ariary (un villageois au bois rapporte l'équivalent d'environ
15 à 20 Ar par minute) ; vendre un zébu reste le moyen rapide, au prix du score.

Avec **Maîtres du Tsena** : zébus et surplus vendus +25 %, achats de bois et de nourriture à 20 Ar. Toutes les
technologies qui modifient l'économie (Cultures traditionnelles, Vannerie et cuirs, Puits profonds, Pacte des
grands éleveurs…) sont décrites dans `ages.md`.

Vendre fait **baisser le cheptel** : c'est un arbitrage entre score de victoire et développement.

## 8. Climat (GDD §7)

- **Jour/nuit** : cycle de 4 min, dont 35 % de nuit (~1 min 25 s).
- **Sécheresse** : le 3ᵉ jour de chaque série de 3 jours. Sur une partie de 30 min : **8–12 min** et **20–24 min**.
- Effets : points d'eau ×0,3, puits ×0,6, champs poussent 2× moins vite, raketa donne de l'eau, zébu vendu moitié prix.

## 9. Zébus disponibles et victoire

- **Départ** : 20 zébus sauvages (8 au centre de la carte, dans le lit de rivière, et une paire symétrique de 6).
- **Arrivées à l'aube** (lieu tiré au sort parmi 5 points posés par le générateur : le centre et deux paires
  symétriques, à plus de 45 m des bases ; **non révélé** :
  il faut l'explorer) :
  - jour normal : **+5** ; aube qui suit une sécheresse (retour des pluies) : **+10** ;
  - aucune arrivée le premier matin, ni à l'aube d'une sécheresse ;
  - pas d'arrivée au-delà de **30 zébus sauvages** présents sur la carte.
  - Sur 30 min : +5 à 4, 16 et 28 min, +10 à 12 et 24 min, soit **35 arrivées** (55 zébus au total).
- **Veaux** (Pacte des grands éleveurs) : 12 naissances au plus par clan. **Achat** au Tsena (Maîtres du Tsena).
- Capacité de cheptel = 10 × nombre d'enclos. Un zébu escorté n'entre pas si les enclos sont pleins.
- **40 zébus sécurisés**, ou le plus grand cheptel au bout de **30 min** (égalité possible).
  Seuil abaissé de 50 à 40 le 16/11/2026 : en partie de test, une IA sans adversaire finissait à 36 zébus.

## 10. IA (prototype)

Récolte selon ses besoins (objectifs d'eau et de nourriture qui grandissent avec son cheptel, eau ×2 en
sécheresse), construit des champs (1 pour 3 villageois, 4 max) et des enclos. Elle construit un Tsena et vend
ses surplus (bois au-delà de 350, nourriture au-delà de 400), puis des zébus en dernier recours, pour financer
ses âges (voir `ages.md`). **Pas encore** de puits ni de camp de bûcherons pour l'IA.

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
| Technologies (Vannerie, Puits profonds, Maîtres du Tsena…) | Les 9 technologies + 3 âges | **Fait** (voir `ages.md`) |
| Seuil de victoire : « ex : 50 zébus » | **40 zébus** | **Décidé** (16/11) |

## 12. Questions ouvertes

1. Caravanes de marchands à intervalles (fenêtres de vente) plutôt qu'un Tsena toujours ouvert ?
2. Plafonner les stocks (greniers, citernes) pour forcer des choix ?
3. Pierre à l'Âge 2 pour les constructions avancées ?
