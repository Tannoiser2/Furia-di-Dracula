import sys, json
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import mappa_dati as m
B = sys.argv[1]
im = Image.open(B).convert("RGB")
a = np.asarray(im).astype(int)
lum = a.sum(axis=2)/3
S = 5000/1800
pos = {}
for k,v in m.CITTA.items():
    x, y = v[4]*S, v[5]*S
    best = None
    for it in range(3):
        x0,x1,y0,y1 = int(x-70),int(x+70),int(y-70),int(y+70)
        sub = lum[max(0,y0):y1, max(0,x0):x1]
        ys, xs = np.nonzero(sub < 45)
        if len(xs) > 200:
            x = max(0,x0) + xs.mean(); y = max(0,y0) + ys.mean()
    pos[k] = (round(x), round(y))
for k,v in m.MARI.items():
    pos[k] = (round(v[2]*S), round(v[3]*S))
json.dump(pos, open("/home/claude/src/pos.json","w"))
d = ImageDraw.Draw(im)
for a_,b_ in m.coppie(m.STRADE):
    d.line([pos[a_],pos[b_]], fill=(255,40,40), width=5)
for t,a_,b_ in m.coppie(m.FERROVIE):
    off=10
    p1=(pos[a_][0]+off,pos[a_][1]+off); p2=(pos[b_][0]+off,pos[b_][1]+off)
    d.line([p1,p2], fill=(0,255,255) if t=="b" else (255,255,0), width=5)
for a_,b_ in m.coppie(m.PORTI)+m.coppie(m.MARI_ADIACENTI):
    d.line([pos[a_],pos[b_]], fill=(60,120,255), width=4)
f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 34)
for k,p in pos.items():
    d.ellipse([p[0]-12,p[1]-12,p[0]+12,p[1]+12], fill=(0,255,0))
    d.text((p[0]+16,p[1]-40), k, fill=(255,255,255), font=f, stroke_width=3, stroke_fill=(0,0,0))
im.save("/home/claude/src/overlay.jpg", quality=85)
