#!/usr/bin/env python3
"""Audit d'un fichier glTF 2.0 (.glb ou .gltf) sans dépendance : triangles, matériaux, textures, squelettes,
animations, et alertes de budget.

Usage :
    python3 audit_glb.py modele.glb [--max-triangles 10000] [--max-texture 2048] [--max-materiaux 4] [--strict]
    python3 audit_glb.py --json modele.glb

--strict : code de sortie 1 si une alerte est levée (pour un contrôle automatique).
"""
import json
import os
import struct
import sys


def lire(chemin):
    with open(chemin, "rb") as f:
        donnees = f.read()
    if donnees[:4] == b"glTF":
        longueur = struct.unpack("<I", donnees[12:16])[0]
        gltf = json.loads(donnees[20:20 + longueur])
        binaire = b""
        decalage = 20 + longueur
        if decalage + 8 <= len(donnees):
            l2 = struct.unpack("<I", donnees[decalage:decalage + 4])[0]
            binaire = donnees[decalage + 8:decalage + 8 + l2]
        return gltf, binaire
    return json.loads(donnees.decode("utf-8")), b""


def taille_image(octets):
    """Largeur, hauteur d'un PNG ou d'un JPEG (en-tête seulement)."""
    if octets[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", octets[16:24])
    if octets[:2] == b"\xff\xd8":
        i = 2
        while i < len(octets) - 9:
            if octets[i] != 0xFF:
                i += 1
                continue
            marqueur = octets[i + 1]
            longueur = struct.unpack(">H", octets[i + 2:i + 4])[0]
            if marqueur in (0xC0, 0xC1, 0xC2):
                h, w = struct.unpack(">HH", octets[i + 5:i + 9])
                return w, h
            i += 2 + longueur
    return None


def auditer(chemin, max_tri=None, max_tex=None, max_mat=None):
    gltf, binaire = lire(chemin)
    acc = gltf.get("accessors", [])
    vues = gltf.get("bufferViews", [])
    r = {"fichier": chemin, "taille_octets": os.path.getsize(chemin),
         "generateur": gltf.get("asset", {}).get("generator"), "maillages": [], "triangles": 0,
         "materiaux": [m.get("name") for m in gltf.get("materials", [])], "textures": [],
         "squelettes": [], "animations": [], "alertes": [], "infos": []}
    noms_noeuds = {}
    for i, n in enumerate(gltf.get("nodes", [])):
        noms_noeuds[i] = n.get("name", "noeud_%d" % i)
    for i, n in enumerate(gltf.get("nodes", [])):
        if "mesh" not in n:
            continue
        m = gltf["meshes"][n["mesh"]]
        tri = 0
        for p in m.get("primitives", []):
            mode = p.get("mode", 4)
            if mode != 4:
                r["infos"].append("Primitive non triangulée (mode %d) dans %s" % (mode, n.get("name")))
            if "indices" in p:
                tri += acc[p["indices"]]["count"] // 3
            else:
                tri += acc[p["attributes"]["POSITION"]]["count"] // 3
        r["maillages"].append({"noeud": n.get("name"), "triangles": tri, "skin": "skin" in n})
        r["triangles"] += tri
    for i, img in enumerate(gltf.get("images", [])):
        e = {"nom": img.get("name") or img.get("uri") or "image_%d" % i, "type": img.get("mimeType")}
        if "bufferView" in img and binaire:
            v = vues[img["bufferView"]]
            octets = binaire[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]
            e["octets"] = len(octets)
            t = taille_image(octets)
            if t:
                e["dimensions"] = list(t)
        elif img.get("uri") and not img["uri"].startswith("data:"):
            e["externe"] = img["uri"]
        r["textures"].append(e)
    for s in gltf.get("skins", []):
        r["squelettes"].append({"os": len(s["joints"]), "noms": [noms_noeuds[j] for j in s["joints"]]})
    for a in gltf.get("animations", []):
        duree = 0.0
        for s in a.get("samplers", []):
            mx = acc[s["input"]].get("max")
            if mx:
                duree = max(duree, mx[0])
        r["animations"].append({"nom": a.get("name"), "duree_s": round(duree, 3), "canaux": len(a.get("channels", [])),
                                "boucle_godot": (a.get("name") or "").endswith("_loop")})
    # Alertes
    if max_tri and r["triangles"] > max_tri:
        r["alertes"].append("Triangles : %d > budget %d" % (r["triangles"], max_tri))
    if max_mat and len(r["materiaux"]) > max_mat:
        r["alertes"].append("Matériaux : %d > budget %d" % (len(r["materiaux"]), max_mat))
    for t in r["textures"]:
        d = t.get("dimensions")
        if d and max_tex and max(d) > max_tex:
            r["alertes"].append("Texture %s : %dx%d > %d px" % (t["nom"], d[0], d[1], max_tex))
        if d and any(x & (x - 1) for x in d):
            r["infos"].append("Texture %s : dimensions non puissances de 2 (%dx%d)" % (t["nom"], d[0], d[1]))
    for s in r["squelettes"]:
        if s["os"] > 64:
            r["alertes"].append("Squelette de %d os (beaucoup pour une unité de jeu)" % s["os"])
    return r


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(2)

    def valeur(nom):
        if nom in args:
            i = args.index(nom)
            v = int(args[i + 1])
            del args[i:i + 2]
            return v
        return None

    max_tri, max_tex, max_mat = valeur("--max-triangles"), valeur("--max-texture"), valeur("--max-materiaux")
    en_json = "--json" in args
    strict = "--strict" in args
    fichiers = [a for a in args if not a.startswith("--")]
    code = 0
    for f in fichiers:
        if not os.path.isfile(f):
            print("ERREUR fichier introuvable : " + f)
            code = 2
            continue
        r = auditer(f, max_tri, max_tex, max_mat)
        if en_json:
            print(json.dumps(r, ensure_ascii=False, indent=2))
        else:
            print("== %s (%.1f Mo, %s)" % (f, r["taille_octets"] / 1e6, r["generateur"]))
            print("  Triangles : %d dans %d maillage(s)" % (r["triangles"], len(r["maillages"])))
            for m in r["maillages"]:
                print("    - %-28s %6d%s" % (m["noeud"], m["triangles"], "  (skinné)" if m["skin"] else ""))
            print("  Matériaux : %s" % r["materiaux"])
            for t in r["textures"]:
                print("  Texture : %s %s %s" % (t["nom"], t.get("dimensions", ""), t.get("type") or t.get("externe", "")))
            for s in r["squelettes"]:
                print("  Squelette : %d os" % s["os"])
            for a in r["animations"]:
                print("  Animation : %-36s %.2f s  %d canaux%s" % (a["nom"], a["duree_s"], a["canaux"],
                      "  (boucle)" if a["boucle_godot"] else ""))
            for i in r["infos"]:
                print("  INFO " + i)
            for al in r["alertes"]:
                print("  ALERTE " + al)
            if not r["alertes"]:
                print("  OK aucune alerte")
        if r["alertes"] and strict:
            code = 1
    sys.exit(code)


if __name__ == "__main__":
    main()
