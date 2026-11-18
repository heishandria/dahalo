---
name: animation-fundamentals
description: "Principes de l'animation appliqués au jeu : poses clés, timing et espacement, anticipation, amorti, chevauchement, arcs, transfert de poids, équilibre, poses expressives, cycles en boucle, animations sur place, transitions et lisibilité à distance de jeu. Use for animation principles, key poses, timing, weight shift, balance, idle/action animations, game animation loops."
---

# Fondamentaux de l'animation (jeu)

## Les principes utiles au jeu

| Principe | En pratique |
|---|---|
| **Poses clés d'abord** | Définir 2 à 5 poses lisibles en silhouette, puis les intervalles |
| **Timing** | Nombre d'images entre poses = poids et énergie (lourd = lent à démarrer et à s'arrêter) |
| **Espacement** | Intervalles serrés près des poses extrêmes (amorti), larges au milieu |
| **Anticipation** | Petit mouvement inverse avant l'action (s'abaisser avant de soulever) ; courte en jeu (réactivité) |
| **Amorti / dépassement** | Après l'action, la masse continue un peu puis se stabilise |
| **Chevauchement** | Les parties souples (tissu, cheveux, oreilles, queue, anse d'un seau) suivent avec retard |
| **Arcs** | Mains, têtes, pieds tracent des courbes, pas des lignes droites |
| **Écrasement-étirement** | Discret en semi-réalisme (volume constant) |
| **Mise en scène** | La pose se lit de la caméra de jeu (souvent de haut) : exagérer ce qui se voit du dessus |
| **Attrait / solidité** | Volumes constants, pas de membres qui s'allongent |

## Transfert de poids et équilibre

- Le **centre de gravité** se déplace vers le pied d'appui **avant** que l'autre pied se lève.
- Pousser/soulever : jambes d'abord, puis tronc ; la charge reste près du corps ; la hanche compense.
- Une charge latérale (seau) incline le tronc du côté opposé ; une charge sur la tête redresse le cou et
  réduit le balancement des bras.
- Se pencher pour puiser/ramasser : genoux fléchis, bassin recule, dos qui s'enroule progressivement.

## Cycles et contraintes du jeu

- **Boucle parfaite** : dernière image = première ; pas de saut de vitesse à la jonction.
- **Sur place** : la racine ne bouge pas ; c'est le jeu qui déplace l'unité (sinon le moteur doit lire le
  déplacement de la racine).
- **Calage de vitesse** : mesurer la vitesse du pied d'appui de l'animation (m/s) ; le jeu règle la vitesse de
  lecture = vitesse réelle / vitesse de calage, dans une plage raisonnable (≈ 0,6 à 2,5) ; au-delà, changer
  d'allure (marche → course). Voir `../locomotion-animation/SKILL.md`.
- **Transitions** : fondu court (0,15–0,25 s) entre états ; poses de départ/fin proches pour éviter les sauts.
- **Animations non bouclées** (se coucher, poser un objet) : jouables à l'envers si elles sont réversibles
  (se lever) ; prévoir leur durée dans la logique du jeu.
- **Lisibilité à distance** : amplitude plus grande que nature ; une action = une silhouette distincte.

## Expressions et poses

L'émotion passe par la posture (tête, épaules, colonne) avant le visage ; fatigue = tête et épaules basses,
pas traînants ; vigilance = tête haute, poids sur l'avant.

## Contrôle

Planche d'images (6 à 12 images par cycle, profil et face), vérification en moteur à la vitesse réelle,
`../visual-quality-review/SKILL.md` §animation.

## Critères de validation

- Poses clés lisibles en silhouette ; poids crédible (appuis, compensation).
- Boucle sans saut ; pas de glissement de pied à la vitesse de jeu ; transitions sans sursaut.
