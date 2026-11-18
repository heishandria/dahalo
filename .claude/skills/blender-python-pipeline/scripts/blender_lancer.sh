#!/usr/bin/env bash
# Lance Blender sans interface sur un script Python, avec journal, délai maximal, sauvegarde facultative du
# fichier .blend d'entrée et code de sortie fiable (une erreur Python fait échouer la commande).
#
# Usage :
#   blender_lancer.sh [--sauvegarder] [--delai SECONDES] [--journaux DOSSIER] [fichier.blend] script.py [-- args…]
#
# Exemples :
#   blender_lancer.sh modele.blend inspecter_blend.py -- rapport.json
#   blender_lancer.sh --sauvegarder perso.blend mon_script.py -- sortie.glb sortie_v02.blend
#   blender_lancer.sh generer_rocher.py -- rocher.glb            # sans .blend : scène d'usine vide
#
# Blender : variable BLENDER, sinon `blender` dans le PATH, sinon /Applications/Blender*.app (macOS).
set -u

SAUVEGARDER=0
DELAI=900
JOURNAUX="journaux_blender"
while [ $# -gt 0 ]; do
	case "$1" in
		--sauvegarder) SAUVEGARDER=1; shift ;;
		--delai) DELAI="$2"; shift 2 ;;
		--journaux) JOURNAUX="$2"; shift 2 ;;
		*) break ;;
	esac
done

FICHIER=""
if [ $# -gt 0 ] && [[ "$1" == *.blend ]]; then
	FICHIER="$1"; shift
fi
if [ $# -lt 1 ]; then
	sed -n '2,15p' "$0"; exit 2
fi
SCRIPT="$1"; shift
[ "${1:-}" = "--" ] && shift

# Trouver Blender.
B="${BLENDER:-}"
if [ -z "$B" ]; then B="$(command -v blender 2>/dev/null || true)"; fi
if [ -z "$B" ]; then
	for app in $(ls -d /Applications/Blender*.app 2>/dev/null | sort -r); do
		if [ -x "$app/Contents/MacOS/Blender" ]; then B="$app/Contents/MacOS/Blender"; break; fi
	done
fi
if [ -z "$B" ] || [ ! -x "$B" ]; then
	echo "ERREUR : Blender introuvable (définir BLENDER=/chemin/vers/blender)." >&2; exit 3
fi
if [ ! -f "$SCRIPT" ]; then echo "ERREUR : script introuvable : $SCRIPT" >&2; exit 2; fi
if [ -n "$FICHIER" ] && [ ! -f "$FICHIER" ]; then echo "ERREUR : fichier introuvable : $FICHIER" >&2; exit 2; fi

mkdir -p "$JOURNAUX"
HORODATAGE="$(date +%Y%m%d-%H%M%S)"
JOURNAL="$JOURNAUX/$(basename "$SCRIPT" .py)_$HORODATAGE.log"

# Sauvegarde du .blend d'entrée (les scripts ne doivent de toute façon pas l'écraser : save_as vers un autre nom).
if [ "$SAUVEGARDER" = 1 ] && [ -n "$FICHIER" ]; then
	DOSSIER_SAUVEGARDE="$(dirname "$FICHIER")/sauvegardes"
	mkdir -p "$DOSSIER_SAUVEGARDE"
	cp -p "$FICHIER" "$DOSSIER_SAUVEGARDE/$(basename "$FICHIER" .blend)_$HORODATAGE.blend"
	echo "Sauvegarde : $DOSSIER_SAUVEGARDE/$(basename "$FICHIER" .blend)_$HORODATAGE.blend"
fi

ENTREE="$FICHIER"
[ -z "$ENTREE" ] && ENTREE="(scène vide)"
{
	echo "# $(date '+%Y-%m-%d %H:%M:%S') — Blender : $B"
	echo "# Fichier : $ENTREE — Script : $SCRIPT — Arguments : $*"
	"$B" --version 2>/dev/null | head -1
} > "$JOURNAL"

if [ -n "$FICHIER" ]; then
	"$B" -b "$FICHIER" --python-exit-code 1 --python "$SCRIPT" -- "$@" >> "$JOURNAL" 2>&1 &
else
	"$B" -b --factory-startup --python-exit-code 1 --python "$SCRIPT" -- "$@" >> "$JOURNAL" 2>&1 &
fi
PID=$!
# Surveillance du délai : s'arrête d'elle-même dès que Blender a fini.
(
	for _ in $(seq "$DELAI"); do
		sleep 1
		kill -0 "$PID" 2>/dev/null || exit 0
	done
	kill -9 "$PID" 2>/dev/null && echo "# DÉLAI DÉPASSÉ ($DELAI s) : Blender arrêté" >> "$JOURNAL"
) &
wait "$PID"; CODE=$?

# Une erreur Python non attrapée donne déjà un code non nul (--python-exit-code) ; on signale aussi les traces.
if grep -q "^Traceback\|Error: Python" "$JOURNAL" && [ "$CODE" = 0 ]; then CODE=4; fi
echo "# Code de sortie : $CODE" >> "$JOURNAL"
grep -v "^#" "$JOURNAL" | grep -E "^(ERREUR|ATTENTION|OK|RESUME|RÉSUMÉ)|Traceback|Error" | tail -20
echo "Journal : $JOURNAL (code $CODE)"
exit "$CODE"
