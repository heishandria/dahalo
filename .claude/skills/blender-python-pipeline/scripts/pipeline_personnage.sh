#!/usr/bin/env bash
# Pipeline personnage image→jeu (Dahalo).
# Orchestre les étapes dans l'ordre, avec reprise possible à n'importe quelle étape.
#
# Usage (depuis le dossier du personnage) :
#   ~/dahalo/.claude/skills/blender-python-pipeline/scripts/pipeline_personnage.sh [OPTIONS]
#
# Options :
#   --depuis ETAPE   Reprendre à partir de cette étape (ne saute pas les étapes précédentes, les marque OK)
#   --jusqu-a ETAPE  S'arrêter après cette étape (utile pour vérifier avant de continuer)
#   --etape ETAPE    N'exécuter que cette étape
#   --etat           Afficher l'état du pipeline sans rien exécuter
#   --reset          Réinitialiser l'état (tout relancer depuis le début au prochain appel)
#   --seche          Afficher les commandes sans les exécuter (dry run)
#
# Étapes disponibles :
#   greffe       greffer_tete.py     (corps.glb + tete.glb → greffe.glb)
#   texture      texture_projection.py  (greffe.glb → v2_texture.blend)
#   rendu_rts    rendu_verification.py --rts  (vérification lisibilité AVANT d'aller plus loin)
#   rig          rig_*.py            (v2_texture.blend → v3_rig.blend)
#   corpulence   corpulence.py       (v3_rig.blend → v3b_corpulence.blend)
#   accessoire   script accessoire   (v3b → v3c)
#   anim         anim_*.py           (v3c → v4_anim.glb)
#   video        video_*.py          (v4_anim.blend → video.mp4)
#
# L'état de chaque étape est enregistré dans .etat_pipeline (une ligne = une étape + horodatage).
# En cas d'échec, corriger le script et relancer avec --depuis ETAPE.
#
# Prérequis : config_personnage.json dans le dossier courant.

set -e
BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
KIT="$HOME/dahalo/.claude/skills/blender-python-pipeline/scripts"
ETAT=".etat_pipeline"
SECHE=false
DEPUIS=""
JUSQU_A=""
ETAPE_SEULE=""

# --- Lecture des arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --depuis)   DEPUIS="$2"; shift 2 ;;
        --jusqu-a)  JUSQU_A="$2"; shift 2 ;;
        --etape)    ETAPE_SEULE="$2"; shift 2 ;;
        --etat)     cat "$ETAT" 2>/dev/null || echo "(aucun état enregistré)"; exit 0 ;;
        --reset)    rm -f "$ETAT"; echo "État réinitialisé."; exit 0 ;;
        --seche)    SECHE=true; shift ;;
        *) echo "Option inconnue : $1"; exit 1 ;;
    esac
done

# --- Config JSON → variables shell (via Python) ---
if [[ ! -f config_personnage.json ]]; then
    echo "ERREUR : config_personnage.json introuvable dans le dossier courant."
    exit 1
fi

eval "$(python3 - <<'PYEOF'
import json, os
c = json.load(open("config_personnage.json"))
f = c["fichiers"]
a = c["animation"]
g = c["geometrie"]
t = c["texture"]
print(f'NOM={c["nom"]}')
print(f'HAUTEUR={g["hauteur_m"]}')
print(f'TRIANGLES={g["triangles_corps"]}')
print(f'TRIANGLES_TETE={g["triangles_tete"]}')
print(f'VOXEL={g["voxel_remaillage"]}')
print(f'TEXTURE_PX={t["px"]}')
print(f'VITESSE_MARCHE={a["vitesse_marche"]}')
print(f'VITESSE_COURSE={a["vitesse_course"]}')
for k, v in f.items():
    print(f'F_{k.upper()}={v}')
print(f'ACTIF_GREFFE={str(c["etapes"].get("greffe_tete", False)).lower()}')
print(f'ACTIF_CORPULENCE={str(c["etapes"].get("corpulence", False)).lower()}')
print(f'ACTIF_ACCESSOIRE={str(c["etapes"].get("accessoire", False)).lower()}')
PYEOF
)"

ETAPES_ORDRE=(greffe texture rendu_rts rig corpulence accessoire anim video)

# --- Helpers ---
etape_ok() {
    grep -q "^$1 OK" "$ETAT" 2>/dev/null
}

marquer_ok() {
    local e="$1"
    # Supprimer la ligne existante si elle existe
    grep -v "^$e " "$ETAT" 2>/dev/null > "$ETAT.tmp" || true
    mv "$ETAT.tmp" "$ETAT" 2>/dev/null || true
    echo "$e OK $(date '+%Y-%m-%d %H:%M:%S')" >> "$ETAT"
    echo "✓ Étape $e terminée."
}

lancer() {
    local etape="$1"; shift
    if [[ "$SECHE" == true ]]; then
        echo "[SECHE] $*"
        return 0
    fi
    echo ""
    echo "=== Étape $etape ==="
    echo "Commande : $*"
    "$@"
}

doit_executer() {
    local e="$1"
    # Si --etape : n'exécuter que celle-là
    [[ -n "$ETAPE_SEULE" ]] && { [[ "$e" == "$ETAPE_SEULE" ]]; return; }
    # Si déjà OK et pas de --depuis qui force un re-run
    etape_ok "$e" && { echo "(étape $e : déjà OK, ignorée)"; return 1; }
    # Si --depuis : marquer les étapes précédentes comme OK sans les exécuter
    if [[ -n "$DEPUIS" ]]; then
        for prev in "${ETAPES_ORDRE[@]}"; do
            [[ "$prev" == "$DEPUIS" ]] && break
            [[ "$prev" == "$e" ]] && { marquer_ok "$e" 2>/dev/null; return 1; }
        done
    fi
    return 0
}

apres_arret() {
    local e="$1"
    [[ -n "$JUSQU_A" ]] || return 0
    local passe=false
    for step in "${ETAPES_ORDRE[@]}"; do
        [[ "$step" == "$JUSQU_A" ]] && passe=true
        [[ "$step" == "$e" && "$passe" == true ]] && { echo "Arrêt demandé après '$JUSQU_A'."; exit 0; }
    done
}

# ============================================================
# ÉTAPES
# ============================================================

# 1. GREFFE DE TÊTE
if [[ "$ACTIF_GREFFE" == "true" ]]; then
    if doit_executer greffe; then
        RECALAGE=""
        [[ -f "gros_plan_recalage.json" ]] && RECALAGE="--recalage gros_plan_recalage.json"
        lancer greffe "$BLENDER" -b --python scripts_claude/greffer_tete.py -- \
            "$F_CORPS_GLB" "$F_TETE_GLB" "${photos_reference_face:-images/face.png}" \
            "gros_plan_recalage.json" "recadrage_tete.json" "$F_GREFFE_GLB" \
            --tete-triangles "$TRIANGLES_TETE"
        marquer_ok greffe
    fi
fi
apres_arret greffe

# 2. TEXTURE
if doit_executer texture; then
    ENTREE_TEXTURE="$F_GREFFE_GLB"
    [[ "$ACTIF_GREFFE" != "true" ]] && ENTREE_TEXTURE="$F_CORPS_GLB"
    ARGS_VUES="--dos images/dos.png"
    [[ -f "images/profils.png" ]] && ARGS_VUES="$ARGS_VUES --profils images/profils.png"
    [[ -f "images/gros_plan.png" && -f "gros_plan_recalage.json" ]] && \
        ARGS_VUES="$ARGS_VUES --gros-plan images/gros_plan.png --recalage gros_plan_recalage.json"
    lancer texture "$BLENDER" -b --python scripts_claude/texture_projection.py -- \
        "$ENTREE_TEXTURE" "images/face.png" "$F_TEXTURE_BLEND" "$F_TEXTURE_GLB" \
        --hauteur "$HAUTEUR" --triangles "$TRIANGLES" \
        --triangles-tete "$TRIANGLES_TETE" --texture "$TEXTURE_PX" --voxel "$VOXEL" \
        $ARGS_VUES
    marquer_ok texture
fi
apres_arret texture

# 3. RENDU RTS (vérification lisibilité AVANT le rig — arrêt si silhouette illisible)
if doit_executer rendu_rts; then
    mkdir -p "rendus_rts_controle"
    lancer rendu_rts "$BLENDER" -b "$F_TEXTURE_BLEND" \
        --python "$KIT/rendu_verification.py" -- \
        --sortie rendus_rts_controle --rts --taille 512
    echo ""
    echo ">>> CONTRÔLE OBLIGATOIRE : regarder rendus_rts_controle/rts_*.png"
    echo "    La silhouette doit être lisible à 18 m et 40 m."
    echo "    Appuyer sur Entrée pour continuer, Ctrl+C pour annuler et corriger."
    [[ "$SECHE" != true ]] && read -r
    marquer_ok rendu_rts
fi
apres_arret rendu_rts

# 4. RIG
if doit_executer rig; then
    lancer rig "$BLENDER" -b "$F_TEXTURE_BLEND" \
        --python scripts_claude/rig_${NOM}.py -- "$F_RIG_BLEND"
    marquer_ok rig
fi
apres_arret rig

# 5. CORPULENCE (optionnelle)
if [[ "$ACTIF_CORPULENCE" == "true" ]]; then
    if doit_executer corpulence; then
        lancer corpulence "$BLENDER" -b "$F_RIG_BLEND" \
            --python scripts_claude/corpulence.py -- "$F_CORPULENCE_BLEND"
        marquer_ok corpulence
    fi
fi
apres_arret corpulence

# 6. ACCESSOIRE (optionnel)
ENTREE_ANIM="$F_RIG_BLEND"
if [[ "$ACTIF_ACCESSOIRE" == "true" ]]; then
    [[ "$ACTIF_CORPULENCE" == "true" ]] && ENTREE_ANIM="$F_CORPULENCE_BLEND"
    if doit_executer accessoire; then
        lancer accessoire "$BLENDER" -b "$ENTREE_ANIM" \
            --python scripts_claude/fusil_${NOM}.py -- "$F_ACCESSOIRE_BLEND"
        marquer_ok accessoire
    fi
    ENTREE_ANIM="$F_ACCESSOIRE_BLEND"
fi
apres_arret accessoire

# 7. ANIMATION
if doit_executer anim; then
    lancer anim "$BLENDER" -b "$ENTREE_ANIM" \
        --python scripts_claude/anim_${NOM}.py -- \
        "$F_ANIM_GLB" "$F_ANIM_BLEND"
    marquer_ok anim
fi
apres_arret anim

# 8. VIDÉO
if doit_executer video; then
    VILLAGEOISE="$HOME/dahalo/assets/models/personnages/villageoise.glb"
    lancer video "$BLENDER" -b "$F_ANIM_BLEND" \
        --python scripts_claude/video_${NOM}.py -- \
        "$F_VIDEO_MP4" "$VILLAGEOISE" \
        --marche "$VITESSE_MARCHE" --course "$VITESSE_COURSE"
    marquer_ok video
fi
apres_arret video

echo ""
echo "Pipeline terminé. État dans : $ETAT"
