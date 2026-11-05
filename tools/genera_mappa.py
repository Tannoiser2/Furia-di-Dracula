#!/usr/bin/env python3
"""Genera assets/dati/mappa.json dai dati di mappa_dati.py (coordinate rifinite sul tabellone 4096 px)."""
import json, sys
import mappa_dati as m
pos = json.load(open(sys.argv[1]))   # coordinate sul tabellone 5000 px (da overlay.py)
K = 4096 / 5000
out = {"luoghi": {}, "strade": [], "ferrovie": [], "regioni": m.REGIONI, "ospedali": {}}
for k, v in m.CITTA.items():
    out["luoghi"][k] = {"nome": v[0], "carta": v[1], "grande": v[2], "regione": v[3], "mare": False,
                         "x": round(pos[k][0] * K), "y": round(pos[k][1] * K), "porti": [], "adiac": [], "fer": []}
for k, v in m.MARI.items():
    out["luoghi"][k] = {"nome": v[0], "carta": v[1], "grande": False, "regione": 0, "mare": True,
                         "x": round(pos[k][0] * K), "y": round(pos[k][1] * K), "porti": [], "adiac": [], "fer": []}
for a, b in m.coppie(m.STRADE):
    out["strade"].append([a, b])
    out["luoghi"][a]["adiac"].append(b); out["luoghi"][b]["adiac"].append(a)
for t, a, b in m.coppie(m.FERROVIE):
    out["ferrovie"].append([a, b, t])
    out["luoghi"][a]["fer"].append([b, t]); out["luoghi"][b]["fer"].append([a, t])
for a, b in m.coppie(m.PORTI):
    out["luoghi"][a]["porti"].append(b); out["luoghi"][b]["porti"].append(a)
for a, b in m.coppie(m.MARI_ADIACENTI):
    out["luoghi"][a]["porti"].append(b); out["luoghi"][b]["porti"].append(a)
S = 5000 / 1800 * K
for k, (x, y) in m.OSPEDALI.items():
    out["ospedali"][k] = {"x": round(x * S), "y": round(y * S)}
json.dump(out, open(sys.argv[2], "w"), ensure_ascii=False, indent=1)
print(len(out["luoghi"]), "luoghi")
