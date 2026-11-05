# Dati della mappa di La Furia di Dracula (3a edizione): città, mari, strade, ferrovie.
# Le coordinate sono in pixel sul tabellone del modulo TTS (5000x3357), stimate e poi rifinite.
# id: (nome italiano, numero carta Luogo, grande città, regione, x, y nella vista 1800 px)
REGIONI = {1: "Britannia", 2: "Iberia", 3: "Gallia", 4: "Germania", 5: "Italia", 6: "Austria-Ungheria", 7: "Balcani"}
CITTA = {
 "alicante": ("Alicante", 1, False, 2, 378, 1048),
 "amsterdam": ("Amsterdam", 2, True, 4, 570, 335),
 "atene": ("Atene", 3, True, 7, 1365, 1105),
 "barcellona": ("Barcellona", 4, True, 2, 465, 930),
 "bari": ("Bari", 5, False, 5, 1060, 995),
 "belgrado": ("Belgrado", 6, False, 7, 1170, 778),
 "berlino": ("Berlino", 7, True, 4, 857, 312),
 "bordeaux": ("Bordeaux", 8, True, 3, 358, 720),
 "bruxelles": ("Bruxelles", 9, True, 3, 540, 415),
 "bucarest": ("Bucarest", 10, True, 7, 1385, 735),
 "budapest": ("Budapest", 11, True, 6, 1088, 595),
 "cadice": ("Cadice", 12, True, 2, 145, 1068),
 "cagliari": ("Cagliari", 13, False, 5, 757, 1072),
 "castello": ("Castello Dracula", 14, False, 7, 1360, 662),
 "clermont": ("Clermont-Ferrand", 15, False, 3, 500, 712),
 "colonia": ("Colonia", 16, True, 4, 640, 408),
 "constanta": ("Constanta", 17, True, 7, 1480, 738),
 "dublino": ("Dublino", 18, False, 1, 205, 258),
 "edimburgo": ("Edimburgo", 19, True, 1, 320, 140),
 "firenze": ("Firenze", 20, False, 5, 825, 868),
 "francoforte": ("Francoforte", 21, False, 4, 697, 460),
 "galati": ("Galati", 22, False, 7, 1455, 662),
 "galway": ("Galway", 23, False, 1, 100, 250),
 "ginevra": ("Ginevra", 24, False, 5, 607, 687),
 "genova": ("Genova", 25, True, 5, 710, 805),
 "granada": ("Granada", 26, False, 2, 268, 1075),
 "amburgo": ("Amburgo", 27, True, 4, 733, 262),
 "klausenburg": ("Klausenburg", 28, False, 6, 1268, 622),
 "lehavre": ("Le Havre", 29, False, 3, 390, 483),
 "lipsia": ("Lipsia", 30, True, 4, 820, 388),
 "lisbona": ("Lisbona", 31, True, 2, 45, 935),
 "liverpool": ("Liverpool", 32, True, 1, 288, 265),
 "londra": ("Londra", 33, True, 1, 400, 375),
 "madrid": ("Madrid", 34, True, 2, 250, 935),
 "manchester": ("Manchester", 35, True, 1, 360, 245),
 "marsiglia": ("Marsiglia", 36, True, 3, 565, 835),
 "milano": ("Milano", 37, True, 5, 713, 720),
 "monaco": ("Monaco", 38, True, 4, 815, 582),
 "nantes": ("Nantes", 39, True, 3, 315, 578),
 "napoli": ("Napoli", 40, True, 5, 938, 1002),
 "norimberga": ("Norimberga", 41, False, 4, 775, 508),
 "parigi": ("Parigi", 42, True, 3, 465, 525),
 "plymouth": ("Plymouth", 43, False, 1, 250, 420),
 "praga": ("Praga", 44, True, 6, 933, 473),
 "roma": ("Roma", 45, True, 5, 865, 960),
 "salonicco": ("Salonicco", 46, False, 7, 1300, 995),
 "santander": ("Santander", 47, False, 2, 240, 775),
 "saragozza": ("Saragozza", 48, False, 2, 360, 885),
 "sarajevo": ("Sarajevo", 49, False, 6, 1090, 825),
 "sofia": ("Sofia", 50, False, 7, 1300, 867),
 "strasburgo": ("Strasburgo", 51, False, 4, 640, 565),
 "swansea": ("Swansea", 52, False, 1, 262, 355),
 "seghedino": ("Seghedino", 53, False, 6, 1137, 668),
 "tolosa": ("Tolosa", 54, False, 3, 430, 795),
 "valona": ("Valona", 55, False, 7, 1170, 1022),
 "varna": ("Varna", 56, True, 7, 1475, 792),
 "venezia": ("Venezia", 57, False, 5, 843, 745),
 "vienna": ("Vienna", 58, True, 6, 980, 568),
 "zagabria": ("Zagabria", 59, False, 6, 975, 722),
 "zurigo": ("Zurigo", 60, False, 5, 678, 632),
}
# mari: (nome, numero carta, x, y nella vista 1800 px)
MARI = {
 "adriatico": ("Mare Adriatico", 1, 1010, 925),
 "nero": ("Mar Nero", 2, 1550, 820),
 "manica": ("La Manica", 3, 330, 450),
 "ionio": ("Mar Ionio", 4, 1150, 1160),
 "irlanda": ("Mar d'Irlanda", 5, 150, 380),
 "mediterraneo": ("Mar Mediterraneo", 6, 560, 1100),
 "atlantico_nord": ("Atlantico del Nord", 7, 110, 500),
 "mare_nord": ("Mare del Nord", 8, 510, 175),
 "atlantico_sud": ("Atlantico del Sud", 9, 110, 650),
 "tirreno": ("Mar Tirreno", 10, 890, 1085),
}
STRADE = """
alicante granada; alicante madrid; alicante saragozza
amsterdam bruxelles; amsterdam colonia
atene valona
barcellona saragozza; barcellona tolosa
bari napoli; bari roma
belgrado bucarest; belgrado klausenburg; belgrado sarajevo; belgrado sofia; belgrado seghedino
berlino amburgo; berlino lipsia; berlino praga
bordeaux clermont; bordeaux nantes; bordeaux saragozza; bordeaux tolosa
bruxelles colonia; bruxelles lehavre; bruxelles parigi; bruxelles strasburgo
bucarest constanta; bucarest galati; bucarest klausenburg; bucarest sofia
budapest klausenburg; budapest seghedino; budapest vienna; budapest zagabria
cadice granada; cadice lisbona; cadice madrid
castello galati; castello klausenburg
clermont ginevra; clermont marsiglia; clermont nantes; clermont parigi; clermont tolosa
colonia francoforte; colonia amburgo; colonia lipsia; colonia strasburgo
constanta galati; constanta varna
dublino galway
edimburgo manchester
firenze genova; firenze roma; firenze venezia
francoforte lipsia; francoforte norimberga; francoforte strasburgo
galati klausenburg
ginevra marsiglia; ginevra parigi; ginevra strasburgo; ginevra zurigo
genova marsiglia; genova milano; genova venezia
granada madrid
amburgo lipsia
klausenburg seghedino
lipsia norimberga
lehavre nantes; lehavre parigi
lisbona madrid; lisbona santander
liverpool manchester; liverpool swansea
londra manchester; londra plymouth; londra swansea
madrid santander; madrid saragozza
marsiglia milano; marsiglia tolosa; marsiglia zurigo
milano monaco; milano venezia; milano zurigo
monaco norimberga; monaco strasburgo; monaco venezia; monaco vienna; monaco zagabria; monaco zurigo
nantes parigi
napoli roma
norimberga praga; norimberga strasburgo
parigi strasburgo
praga vienna
salonicco sofia; salonicco valona
santander saragozza
saragozza tolosa
sarajevo sofia; sarajevo valona; sarajevo zagabria
sofia valona; sofia varna
strasburgo zurigo
seghedino zagabria
vienna zagabria
"""
# ferrovie: b = bianca, g = gialla
FERROVIE = """
b edimburgo manchester; b liverpool manchester; b manchester londra; b swansea londra; b plymouth londra
b lehavre parigi; b bruxelles parigi; b parigi bordeaux; b parigi marsiglia; b bordeaux saragozza
b bruxelles colonia; b colonia francoforte; b colonia berlino; b amburgo berlino; b lipsia berlino
b francoforte lipsia; b lipsia norimberga; b norimberga monaco; b francoforte strasburgo; b strasburgo monaco; b strasburgo zurigo
b santander madrid; b lisbona madrid; b madrid saragozza; b madrid alicante; b saragozza barcellona; b barcellona alicante
g berlino praga; g praga vienna; g vienna budapest; g vienna venezia; g budapest seghedino; g seghedino belgrado; g seghedino bucarest
g belgrado sofia; g bucarest galati; g bucarest constanta; g sofia varna; g sofia salonicco
g ginevra milano; g zurigo milano; g milano genova; g marsiglia milano; g genova venezia; g genova firenze; g firenze roma; g roma napoli; g napoli bari
"""
PORTI = """
edimburgo mare_nord; amsterdam mare_nord; amburgo mare_nord
londra manica; plymouth manica; lehavre manica
galway atlantico_nord; nantes atlantico_nord; bordeaux atlantico_nord
dublino irlanda; liverpool irlanda; swansea irlanda
santander atlantico_sud; lisbona atlantico_sud; cadice atlantico_sud
alicante mediterraneo; barcellona mediterraneo; marsiglia mediterraneo; cagliari mediterraneo
cagliari tirreno; genova tirreno; roma tirreno; napoli tirreno
venezia adriatico; bari adriatico; valona adriatico
salonicco ionio; atene ionio
constanta nero; varna nero
"""
MARI_ADIACENTI = """
atlantico_nord irlanda; atlantico_nord manica; atlantico_nord mare_nord; atlantico_nord atlantico_sud
manica mare_nord; atlantico_sud mediterraneo; mediterraneo tirreno; tirreno ionio; ionio adriatico; ionio nero
"""
OSPEDALI = {"madrid": (250, 885), "roma": (865, 912), "budapest": (1088, 548)}

def coppie(t):
    out = []
    for parte in t.replace("\n", ";").split(";"):
        p = parte.split()
        if p:
            out.append(p)
    return out
