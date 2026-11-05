#!/usr/bin/env python3
"""Controlla che ogni carattere usato nei testi del gioco esista in tutti i font (niente quadratini).
Uso: python3 tools/controlla_glifi.py"""
import glob, json, os, re, sys
from fontTools.ttLib import TTFont

R = os.path.join(os.path.dirname(__file__), '..')
testi = []
for f in glob.glob(R + '/scripts/*.gd'):
    src = open(f, encoding='utf-8').read()
    testi += re.findall(r'"((?:[^"\\]|\\.)*)"', src)
    testi += re.findall(r'"""(.*?)"""', src, re.S)
for l in json.load(open(R + '/assets/dati/mappa.json', encoding='utf-8'))['luoghi'].values():
    testi.append(l['nome'])
caratteri = set(''.join(testi)) - set('\n\t\r')
errori = 0
for font in sorted(glob.glob(R + '/assets/font/*.ttf')):
    cmap = TTFont(font).getBestCmap()
    manca = sorted(ch for ch in caratteri if ord(ch) not in cmap and ord(ch) > 31)
    nome = os.path.basename(font)
    if manca:
        print(f'{nome}: mancano {"".join(manca)!r}')
        errori += 1
    else:
        print(f'{nome}: tutti i {len(caratteri)} caratteri presenti')
sys.exit(1 if errori else 0)
