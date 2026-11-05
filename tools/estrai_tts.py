#!/usr/bin/env python3
"""Estrae dal modulo TTS di La Furia di Dracula (file .ttsmod) tabellone, carte e segnalini.
Uso: python3 tools/estrai_tts.py <cartella Mods estratta> <cartella del progetto>"""
import os, sys, json
from PIL import Image

MODS, PROJ = sys.argv[1], sys.argv[2]
IMG = os.path.join(MODS, "Images")
OUT = os.path.join(PROJ, "assets")

def trova(frammento):
    for f in os.listdir(IMG):
        if frammento in f:
            return Image.open(os.path.join(IMG, f)).convert("RGB")
    raise SystemExit("immagine non trovata: " + frammento)

def salva(im, nome, w=None, q=84):
    p = os.path.join(OUT, nome)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    if w and im.width != w:
        im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
    im.save(p, "WEBP", quality=q, method=6)

def griglia(frammento, cols, rows, nomi, cartella, w=240):
    sh = trova(frammento)
    cw, ch = sh.width / cols, sh.height / rows
    for i, n in enumerate(nomi):
        if not n:
            continue
        c, r = i % cols, i // cols
        im = sh.crop((round(c * cw), round(r * ch), round((c + 1) * cw), round((r + 1) * ch)))
        salva(im, f"carte/{cartella}/{n}.webp", w)

# tabellone
salva(trova("kagRuFl"), "tabellone.webp", 4096, 82)

LUOGHI = """swansea seghedino tolosa valona varna venezia zagabria zurigo alicante amsterdam
atene barcellona bari belgrado berlino bordeaux bruxelles bucarest budapest cadice
cagliari clermont colonia constanta vienna dublino edimburgo firenze francoforte galati
galway ginevra genova granada amburgo klausenburg lehavre lipsia lisbona liverpool
londra madrid manchester marsiglia milano monaco nantes napoli norimberga parigi
plymouth praga roma salonicco santander saragozza sarajevo sofia strasburgo dorso""".split()
griglia("1697591", 10, 6, LUOGHI, "luoghi")
MARI = "nero manica ionio irlanda mediterraneo atlantico_nord mare_nord atlantico_sud tirreno adriatico - dorso_mare".split()
griglia("1697655", 6, 2, [m if m != "-" else "" for m in MARI], "luoghi")
salva(trova("11244655554527"), "carte/luoghi/castello.webp", 240)
salva(trova("11244655558314"), "carte/luoghi/dorso_castello.webp", 240)
# carte potere
for fr, n in [("1124465546561", "lupo"), ("1124465547752", "richiamo"), ("1124465549363", "nutrirsi"),
              ("1124465551459", "nascondersi"), ("1124465552971", "depistaggio")]:
    salva(trova(fr), f"carte/potere/{n}.webp", 240)
for fr, n in [("1124465547021", "dorso_lupo"), ("1124465548282", "dorso_richiamo"),
              ("1124465549839", "dorso_nutrirsi"), ("1124465553447", "dorso_depistaggio")]:
    if n:
        salva(trova(fr), f"carte/potere/{n}.webp", 240)

EV_C = ("giornali giornali giornali grande_forza buona_fortuna buona_fortuna avvertito avvertito imboscata imboscata "
        "cilindri ritorno ritorno ricerca_mistica lucy senso senso carrozza carrozza carrozza "
        "agatha rufus lunga_notte lunga_notte scoperta denaro via_fuga via_fuga tempo_sereno harker "
        "slancio velo tempo_sereno tana vigore vigore trasfusione trasfusione terreno esploratori "
        "esploratori esploratori esploratori telegrammi telegrammi presenza presenza ipnosi voci voci").split()
griglia("1695400811", 10, 6, list(dict.fromkeys(EV_C)) and [n if EV_C.index(n) == i else "" for i, n in enumerate(EV_C)] + [""] * 9 + ["dorso"], "eventi")
EV_D = ("seduzione spose tempeste tempeste strada_bloccata strada_bloccata strada_bloccata "
        "visita indicazioni indicazioni cavalli_impazziti cavalli_impazziti influsso influsso "
        "trame trame furioso oscurita grande_lupo hildesheim stampa "
        "velocita dogana potere_diabolico potere_diabolico - - dorso_d").split()
griglia("16955198675", 7, 4, [n if n != "-" and EV_D.index(n) == i else "" for i, n in enumerate(EV_D)], "eventi")
OGG = ("cavalli cerchio cerchio aglio aglio aglio ostia ostia ostia pistola "
       "pistola pistola pistola fucile fucile fucile fucile cani cani cani "
       "cani ghirlanda ghirlanda ghirlanda coltello coltello coltello proiettili proiettili proiettili "
       "paletto paletto paletto paletto crocifisso crocifisso cavalli cavalli - dorso").split()
griglia("1695599", 10, 4, [n if n != "-" and OGG.index(n) == i else "" for i, n in enumerate(OGG)], "oggetti")
INC = ("szgany raggiro raggiro temerario temerario temerario lupi lupi aristocratico aristocratico "
       "aristocratico guardie guardie sconsacrato sconsacrato nebbia nebbia nuovo nuovo ratti "
       "ratti sabotatore sabotatore spia spia pipistrelli pipistrelli szgany - dorso").split()
griglia("1695935996", 10, 3, [n if n != "-" and INC.index(n) == i else "" for i, n in enumerate(INC)], "incontri")
CD = "denti nebbia pipistrello pipistrello macchinazione macchinazione artigli artigli forza forza mesmerismo mesmerismo denti - - dorso".split()
griglia("16957512", 8, 2, [n if n != "-" and CD.index(n) == i else "" for i, n in enumerate(CD)], "combattimento")
CH = "fuggire fuggire fuggire fuggire pugno pugno pugno pugno schivare schivare schivare schivare - dorso_c".split()
griglia("16956777", 7, 2, [n if n != "-" and CH.index(n) == i else "" for i, n in enumerate(CH)], "combattimento")
PG = "vanhelsing seward dracula godalming mina dorso_pg".split()
griglia("169600185", 3, 2, PG, "personaggi", 700)
salva(trova("11244651020585"), "carte/aiuto_azioni.webp", 300)

# segnalini (ritagli dalle texture dei segnalini)
def ritaglio(fr, box, nome, w=96):
    im = trova(fr)
    W, H = im.size
    im = im.crop((round(box[0] * W), round(box[1] * H), round(box[2] * W), round(box[3] * H)))
    salva(im, f"segnalini/{nome}.webp", w)
ritaglio("1z3yndglz82zmx0bats", (0.52, 0.12, 0.92, 0.72), "pipistrelli")
ritaglio("6dfikmvgikahb43fog", (0.52, 0.10, 0.92, 0.72), "nebbia")
ritaglio("enkgsg65kfuc8q4storm", (0.55, 0.0, 0.93, 0.72), "tempesta")
ritaglio("mqdhbk8hlfx13t2roadblock", (0.0, 0.0, 0.5, 0.52), "blocco_ferrovia")
ritaglio("mqdhbk8hlfx13t2roadblock", (0.42, 0.42, 1.0, 0.98), "blocco_strada")
ritaglio("h6tyhwqlvnrqfr5grnd1", (0.0, 0.0, 1.0, 1.0), "consacrato")
ritaglio("6tcj9s9ddy4v47bgrnd2", (0.0, 0.0, 1.0, 1.0), "schiera")
ritaglio("jy3k7ynjg0ksqoxrumor", (0.0, 0.0, 1.0, 1.0), "diceria")
ritaglio("o7fwuxw31hu61q8despair", (0.0, 0.0, 1.0, 1.0), "disperazione")
ritaglio("bGuVVNL", (0.0, 0.0, 1.0, 1.0), "morso")
ritaglio("z6c4ruogh1zf92ktickets", (0.0, 0.0, 0.25, 0.5), "biglietto_1_1", 80)
ritaglio("z6c4ruogh1zf92ktickets", (0.25, 0.0, 0.5, 0.5), "biglietto_dorso", 80)
ritaglio("z6c4ruogh1zf92ktickets", (0.5, 0.0, 0.75, 0.5), "biglietto_3_2", 80)
ritaglio("z6c4ruogh1zf92ktickets", (0.75, 0.0, 1.0, 0.5), "biglietto_2_1", 80)
ritaglio("z6c4ruogh1zf92ktickets", (0.5, 0.5, 1.0, 0.75), "biglietto_2_2", 120)
ritaglio("z6c4ruogh1zf92ktickets", (0.0, 0.75, 0.5, 1.0), "biglietto_1", 120)
print("ok")
