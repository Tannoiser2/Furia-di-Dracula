## Intelligenza artificiale di La Furia di Dracula.
## I cacciatori usano solo le informazioni pubbliche: dal Percorso (tipo di carta, luoghi rivelati,
## poteri visibili, città dove sono già passati senza trovarlo) deducono dove può essere Dracula.
## Dracula conosce la posizione dei cacciatori (che è pubblica) e cerca di stare lontano e di far maturare i vampiri.
## Tutte le scelte sono deterministiche (seme = seme della partita + numero della decisione), così l'online resta allineato.
class_name IA
extends RefCounted

var m: Motore
var rng := RandomNumberGenerator.new()
var _cache_passo := -1
var _cache_cand: Array = []

func _init(motore: Motore) -> void:
	m = motore

func s() -> Dictionary:
	return m.s

func decidi(r: Dictionary) -> String:
	rng.seed = int(s()["seed"]) * 7919 + int(s()["passo"]) * 104729 + 17
	var opz: Array = r["opz"]
	if opz.size() == 1:
		return str(opz[0]["id"])
	var f := "_" + str(r["k"])
	if has_method(f):
		var v = call(f, r, opz)
		if v != null and str(v) != "" and opz.any(func(x): return str(x["id"]) == str(v)):
			return str(v)
	return str(opz[0]["id"])

func _ids(opz: Array) -> Array:
	return opz.map(func(x): return str(x["id"]))

func _ha(opz: Array, id: String) -> bool:
	return opz.any(func(x): return str(x["id"]) == id)

func _migliore(opz: Array, punteggio: Callable) -> String:
	var best := ""
	var bv := -INF
	for o in opz:
		var v: float = punteggio.call(o) + rng.randf() * 0.01
		if v > bv:
			bv = v
			best = str(o["id"])
	return best

# ============================================================ deduzione dei cacciatori

## Luoghi in cui potrebbe trovarsi Dracula adesso, secondo le informazioni pubbliche.
func candidati() -> Array:
	if _cache_passo == int(s()["passo"]):
		return _cache_cand
	_cache_passo = int(s()["passo"])
	_cache_cand = _calcola_candidati()
	return _cache_cand

func _calcola_candidati() -> Array:
	var perc: Array = s()["percorso"]
	if perc.is_empty():
		return []
	var noti := []
	for h in perc + s()["tane"]:
		var p := m.pubblico(h)
		if p["luogo"] != "":
			noti.append(p["luogo"])
	var poss = null
	for k in range(perc.size() - 1, -1, -1):
		var p := m.pubblico(perc[k])
		if p["potere"] in ["richiamo", "nutrirsi"]:
			continue
		if p["potere"] == "depistaggio" or p["potere"] == "nascondersi":
			continue
		if p["luogo"] != "":
			poss = [p["luogo"]]
			continue
		var nuovi := []
		var tipo: String = p["tipo"]
		var base: Array = []
		if poss == null:
			for l in Dati.luoghi():
				base.append(l)
			for l in base:
				if _tipo_ok(l, tipo) and not (l in noti) and not (l in p["esclusi"]):
					nuovi.append(l)
		else:
			for da in poss:
				var vic: Array = _vicini_dracula(da, p["potere"] == "lupo" or p["potere"] == "pipistrello")
				if tipo == "terra":
					vic.append(da)   # potrebbe essere un Nascondersi
				for l in vic:
					if _tipo_ok(l, tipo) and not (l in noti) and not (l in p["esclusi"]) and not (l in nuovi):
						nuovi.append(l)
		if nuovi.is_empty():
			nuovi = []
			for l in Dati.luoghi():
				if _tipo_ok(l, tipo) and not (l in noti) and not (l in p["esclusi"]):
					nuovi.append(l)
		poss = nuovi
	if poss == null:
		return []
	var reg = s()["flag"].get("regione_nota", {})
	if reg is Dictionary and not reg.is_empty() and int(s()["passo"]) - int(reg.get("passo", 0)) < 30:
		var filt := []
		for l in poss:
			if (int(reg["r"]) == 0 and Dati.mare(l)) or (not Dati.mare(l) and Dati.regione(l) == int(reg["r"])):
				filt.append(l)
		if not filt.is_empty():
			poss = filt
	return poss

func _tipo_ok(l: String, tipo: String) -> bool:
	match tipo:
		"mare": return Dati.mare(l)
		"castello": return l == "castello"
		"terra": return not Dati.mare(l) and l != "castello"
	return true

func _vicini_dracula(da: String, due: bool) -> Array:
	var out := []
	if Dati.mare(da):
		out.append_array(Dati.L(da)["porti"])
	else:
		out.append_array(Dati.strade(da))
		out.append_array(Dati.L(da)["porti"])
		if due:
			for k in Dati.distanze_strada(da, 2):
				if not (k in out):
					out.append(k)
	return out

## Distanza media (in mosse) da un luogo ai candidati.
func _dist_cand(da: String, cand: Array) -> float:
	if cand.is_empty():
		return 0.0
	var tot := 0.0
	var mn := 99.0
	for l in cand:
		var d := float(Dati.dist_viaggio(da, l))
		tot += d
		mn = min(mn, d)
	return tot / cand.size() * 0.5 + mn * 0.5

## Dove conviene andare: i candidati se sono pochi, altrimenti il «baricentro» delle tracce.
const ZONE := [["parigi", "bruxelles", "marsiglia", "madrid"], ["monaco", "milano", "praga", "roma"], ["budapest", "vienna", "zagabria", "belgrado"], ["bucarest", "sofia", "klausenburg", "varna"]]

func _obiettivi(i := -1) -> Array:
	var cand := candidati()
	if cand.is_empty() or cand.size() > 25:
		# niente informazioni utili: ogni cacciatore pattuglia una zona diversa dell'Europa
		if i < 0:
			return ["klausenburg", "budapest", "vienna", "bucarest", "monaco", "parigi"]
		var z: Array = ZONE[i]
		return [z[int(s()["giorno"]) / 2 % z.size()]]
	if i < 0 or cand.size() <= 3:
		return cand
	# ognuno insegue i candidati più vicini a sé che agli altri
	var miei := []
	for l in cand:
		var best := -1
		var bd := 999
		for j in 4:
			if not m.attivo(j):
				continue
			var d := Dati.dist_viaggio(m.c(j)["pos"], l)
			if d < bd:
				bd = d
				best = j
		if best == i:
			miei.append(l)
	return miei if not miei.is_empty() else cand

# ============================================================ cacciatori

func _partenza(r: Dictionary, opz: Array) -> String:
	var scelte := [["parigi", "londra", "madrid"], ["vienna", "monaco", "milano"], ["budapest", "belgrado", "praga"], ["roma", "berlino", "marsiglia"]]
	var l: Array = scelte[int(r["g"])]
	return l[rng.randi() % l.size()]

func _azione(r: Dictionary, opz: Array) -> String:
	var i: int = r["g"]
	var h := m.c(i)
	var pos: String = h["pos"]
	if _ha(opz, "osp"):
		return "osp"
	var cand := candidati()
	var obj := _obiettivi(i)
	var margine: int = m.vita(i) - int(h["danni"])
	var nt: bool = r.get("notte", false)
	# eventi utili subito
	for e in ["tana", "trasfusione", "ricerca_mistica", "denaro"]:
		if _ha(opz, "ev:" + e) and (e != "denaro" or _ci_sono_mari()):
			return "ev:" + e
	if _ha(opz, "libero:buona_fortuna") and s()["dr"]["alleato"] != "":
		return "libero:buona_fortuna"
	if _ha(opz, "ev:terreno") and nt and not cand.is_empty() and cand.size() < 12:
		return "ev:terreno"
	if _ha(opz, "legame") and (cand.size() > 6 or cand.is_empty()):
		return "legame"
	if _ha(opz, "ev:ipnosi") and cand.size() > 6:
		return "ev:ipnosi"
	# molto feriti: riposa
	if margine <= 3 and _ha(opz, "riposo") and not (pos in cand and cand.size() <= 2):
		return "riposo"
	# un nascondiglio con incontri dove si trova: cercare
	var rif := m.nasc_di(pos)
	if not rif.is_empty() and _ha(opz, "ricerca") and margine > 3:
		var h2: Dictionary = m._h(rif)
		if not h2["inc"].is_empty():
			return "ricerca"
	# di notte: rifornimento, biglietti, riposo
	if nt or Dati.mare(pos) == false and not _ha_movimenti(opz):
		if margine <= 5 and int(h["danni"]) > 0 and _ha(opz, "riposo"):
			return "riposo"
		if _ha(opz, "rifornimento") and h["ogg"].size() < m.max_ogg(i) and (Dati.L(pos)["grande"] or h["ev"].size() < m.max_ev(i)):
			return "rifornimento"
		if _ha(opz, "biglietto") and h["big"].size() < 2:
			return "biglietto"
		if int(h["danni"]) > 0 and _ha(opz, "riposo"):
			return "riposo"
		if _ha(opz, "rifornimento"):
			return "rifornimento"
		return "passa"
	# di giorno: avvicinarsi a Dracula
	var dist_ora := _dist_cand(pos, obj)
	var mosse := []
	for o in opz:
		var id: String = o["id"]
		if id.begins_with("strada:") or id.begins_with("mare:"):
			var dest: String = id.get_slice(":", 1)
			mosse.append({"id": id, "v": _valore_dest(i, dest, obj)})
		elif id.begins_with("treno:"):
			var b: Array = h["big"][int(id.get_slice(":", 1))]
			var best := INF
			for d in m.dest_treno(pos, b):
				best = min(best, _valore_dest(i, d, obj))
			mosse.append({"id": id, "v": best - 0.3})
		elif id == "cavalli":
			mosse.append({"id": id, "v": dist_ora - 1.5})
	# se è già su un candidato forte, resta a cercare / aspettare Dracula all'alba
	if pos in cand and cand.size() <= 3:
		if _ha(opz, "ricerca"):
			return "ricerca"
		if int(h["danni"]) > 0:
			return "riposo"
		return "passa" if not _ha(opz, "rifornimento") else "rifornimento"
	mosse.sort_custom(func(a, b): return a["v"] < b["v"])
	if not mosse.is_empty() and mosse[0]["v"] < dist_ora - 0.2:
		return mosse[0]["id"]
	# nessuna mossa migliora: rafforzati
	if _ha(opz, "rifornimento") and h["ogg"].size() < m.max_ogg(i):
		return "rifornimento"
	if _ha(opz, "biglietto") and h["big"].size() < 1:
		return "biglietto"
	if not mosse.is_empty() and cand.size() > 0:
		return mosse[0]["id"]
	return "riposo" if int(h["danni"]) > 0 else ("rifornimento" if _ha(opz, "rifornimento") else "passa")

func _ci_sono_mari() -> bool:
	for h in s()["percorso"]:
		if m.tipo_carta(h) == "mare" and not h["riv"]:
			return true
	return false

func _ha_movimenti(opz: Array) -> bool:
	return opz.any(func(x): return str(x["id"]).begins_with("strada:") or str(x["id"]).begins_with("mare:") or str(x["id"]).begins_with("treno:"))

func _valore_dest(i: int, dest: String, obj: Array) -> float:
	var v := _dist_cand(dest, obj)
	# non ammassarsi tutti nella stessa città, a meno che Dracula sia lì
	for j in 4:
		if j != i and m.attivo(j) and m.c(j)["pos"] == dest and not (dest in candidati()):
			v += 0.6
	if s()["nebbia"].has(dest):
		v += 1.0
	if Dati.mare(dest) and not (dest in candidati()):
		v += 1.6
	# i nascondigli con vampiri scoperti vanno ripuliti
	var rif := m.nasc_di(dest)
	if not rif.is_empty():
		var h: Dictionary = m._h(rif)
		if h["riv"] and not h["inc"].is_empty():
			v -= 1.2
	return v

func _dest_treno(r: Dictionary, opz: Array) -> String:
	if int(r["g"]) == Motore.DRACULA:
		var dr := m.pos_dracula()
		return _migliore(opz, func(o): return float(Dati.dist_viaggio(dr, o["id"])))
	var obj := _obiettivi(int(r["h"]))
	return _migliore(opz, func(o): return -_valore_dest(int(r["h"]), o["id"], obj))

func _dest_cavalli(r: Dictionary, opz: Array) -> String:
	var obj := _obiettivi(int(r["g"]))
	return _migliore(opz, func(o): return -_valore_dest(int(r["g"]), o["id"], obj))

func _senso(r: Dictionary, opz: Array) -> String:
	return _dest_cavalli(r, opz)

func _navigazione(r: Dictionary, opz: Array) -> String:
	var obj := _obiettivi()
	return _migliore(opz, func(o): return -_valore_dest(int(r["g"]), str(o.get("luogo", m.c(int(r["g"]))["pos"])), obj))

func _scarta_big(r: Dictionary, opz: Array) -> String:
	var i: int = r["h"]
	var best := 0
	var bv := 99
	for k in m.c(i)["big"].size():
		var b: Array = m.c(i)["big"][k]
		var v := int(b[0]) + int(b[1])
		if v < bv:
			bv = v
			best = k
	return str(best)

func _evento_alba(r: Dictionary, opz: Array) -> String:
	for e in ["vigore", "giornali", "ritorno"]:
		if _ha(opz, e):
			if e == "giornali" and s()["percorso"].size() < 5:
				continue
			return e
	if _ha(opz, "lunga_notte") and candidati().size() <= 8:
		return "lunga_notte"
	return "no"

func _ritorno(_r: Dictionary, opz: Array) -> String:
	for e in ["agatha", "harker", "rufus"]:
		if _ha(opz, e):
			return e
	return str(opz[0]["id"])

func _giornali(_r: Dictionary, _opz: Array) -> String:
	return "subito" if s()["percorso"].size() >= 3 else "tieni"

func _subito_alleato(_r: Dictionary, _opz: Array) -> String:
	return "alleato" if s()["alleato_c"] == "" else "effetto"

func _rivela_citta(_r: Dictionary, opz: Array) -> String:
	var cand := candidati()
	var perc := []
	for h in s()["percorso"]:
		if not h["riv"] and h["luogo"] != "":
			perc.append(h)
	if not cand.is_empty() and cand.size() <= 30:
		var scelta = cand[rng.randi() % cand.size()]
		if _ha(opz, scelta):
			return scelta
	# città plausibili vicino alle ultime tracce
	return str(opz[rng.randi() % opz.size()]["id"])

func _velo(_r: Dictionary, opz: Array) -> String:
	for v in ["nuovo", "temerario", "aristocratico", "lupi", "guardie"]:
		if _ha(opz, v):
			return v
	return str(opz[0]["id"])

func _cilindri(_r: Dictionary, opz: Array) -> String:
	for o in opz:
		if str(o["id"]).begins_with("ded:"):
			return o["id"]
	return "analisi"

func _limite_ogg(_r: Dictionary, opz: Array) -> String:
	var ordine := ["cavalli", "cani", "proiettili", "ghirlanda", "aglio", "paletto", "crocifisso", "ostia", "cerchio", "pistola", "fucile", "coltello"]
	for o in ordine:
		if _ha(opz, o):
			return o
	return str(opz[0]["id"])

func _limite_ev(_r: Dictionary, opz: Array) -> String:
	var ordine := ["telegrammi", "lunga_notte", "tempo_sereno", "carrozza", "denaro", "buona_fortuna", "imboscata", "senso", "ritorno"]
	for o in ordine:
		if _ha(opz, o):
			return o
	return str(opz[0]["id"])

func _scambio(_r: Dictionary, _opz: Array) -> String:
	return "fine"

func _ordine(_r: Dictionary, opz: Array) -> String:
	return str(opz[0]["id"])

func _unisciti(r: Dictionary, _opz: Array) -> String:
	var j: int = r["h"]
	return "si" if m.vita(j) - int(m.c(j)["danni"]) >= 5 else "no"

func _aristocratico(_r: Dictionary, _opz: Array) -> String:
	return "si"

func _spia(r: Dictionary, _opz: Array) -> String:
	return "si" if m.armi(int(r["h"])) >= 2 else "no"

func _dogana_scelta(r: Dictionary, _opz: Array) -> String:
	var i: int = r["h"]
	return "danni" if m.vita(i) - int(m.c(i)["danni"]) > 5 else "ogg"

func _avvertito(_r: Dictionary, _opz: Array) -> String:
	return "si"

func _buona_fortuna(_r: Dictionary, opz: Array) -> String:
	return "alleato" if _ha(opz, "alleato") else str(opz[0]["id"])

func _terreno(r: Dictionary, opz: Array) -> String:
	if r.get("schiera", false):
		return "no"
	var cand := candidati()
	for l in cand:
		if _ha(opz, l):
			return l
	return "budapest" if _ha(opz, "budapest") else str(opz[0]["id"])

func _scoperta(_r: Dictionary, opz: Array) -> String:
	for o in ["coltello", "pistola", "fucile", "ostia", "crocifisso", "cerchio"]:
		if _ha(opz, o):
			return o
	return str(opz[0]["id"])

func _via_fuga(_r: Dictionary, opz: Array) -> String:
	var best := str(opz[0]["id"])
	var bv := 99
	for o in opz:
		var j := int(o["id"])
		var mg: int = m.vita(j) - int(m.c(j)["danni"])
		if mg < bv:
			bv = mg
			best = str(j)
	return best

func _comb_pre(r: Dictionary, opz: Array) -> String:
	var j: int = r["h"]
	var cb: Dictionary = s()["comb"]
	var mg: int = m.vita(j) - int(m.c(j)["danni"])
	if _ha(opz, "lucy"):
		return "lucy"
	if _ha(opz, "scoperta"):
		return "scoperta"
	if _ha(opz, "imboscata"):
		return "imboscata"
	var vita_avv := 0
	if cb["tipo"] == "dracula":
		vita_avv = Dati.VITA_DRACULA - int(s()["dr"]["danni"])
	else:
		vita_avv = int(cb["vamp_vita"]) - int(cb["vamp_danni"])
	if _ha(opz, "slancio") and mg > 5 and vita_avv <= 5:
		return "slancio"
	if _ha(opz, "via_fuga") and mg <= 4:
		return "via_fuga"
	return "no"

func _comb_c(r: Dictionary, opz: Array) -> String:
	var j: int = r["h"]
	var cb: Dictionary = s()["comb"]
	var mg: int = m.vita(j) - int(m.c(j)["danni"])
	var vita_avv := 0
	if cb["tipo"] == "dracula":
		vita_avv = Dati.VITA_DRACULA - int(s()["dr"]["danni"])
	else:
		vita_avv = int(cb["vamp_vita"]) - int(cb["vamp_danni"])
	var mesm: bool = j in cb["mesm"]
	if mg <= 2 and _ha(opz, "c:fuggire"):
		return "c:fuggire"
	if mg <= 2 and _ha(opz, "o:cerchio"):
		return "o:cerchio"
	var punti := {}
	for o in opz:
		var id: String = o["id"]
		var v := 0.0
		match id:
			"c:pugno": v = 1.0
			"c:schivare": v = 0.6 + (1.5 if mg <= 4 else 0.0)
			"c:fuggire": v = -2.0 + (2.5 if mg <= 3 else 0.0)
			"o:coltello": v = 3.2 - (1.0 if mesm else 0.0)
			"o:pistola", "o:fucile": v = 2.2 - (1.0 if mesm else 0.0) + (3.0 if m.ha_ogg(j, "proiettili") and not (j in cb["proiettili"]) else 0.0)
			"o:ostia": v = 3.0 if vita_avv <= 4 or mg > 4 else 1.0
			"o:aglio": v = 1.3
			"o:crocifisso": v = 1.6
			"o:cerchio": v = 0.2 + (2.0 if mg <= 4 else 0.0)
		# varietà: le carte di Dracula sono incerte
		v += rng.randf() * 0.8
		punti[id] = v
	return _migliore(opz, func(o): return punti[o["id"]])

func _pianificata(r: Dictionary, opz: Array) -> String:
	var cb: Dictionary = s()["comb"]
	var dc: String = cb.get("carta_d", "")
	if dc == "":
		return "tieni"
	var icona: String = Dati.COMB_DRACULA[dc]["icona"]
	for o in opz:
		var id: String = o["id"]
		if id == "tieni":
			continue
		var t := id.get_slice(":", 0)
		var k := id.get_slice(":", 1)
		var ic: Array = Dati.COMB_CACCIATORE[k]["icone"] if t == "c" else Dati.OGGETTI[k]["icone"]
		if icona in ic:
			return id
	return "tieni"

func _trasfusione(_r: Dictionary, opz: Array) -> String:
	return str(opz[0]["id"])

# ============================================================ Dracula

func _dist_cacciatori(l: String) -> float:
	var mn := 99.0
	for j in 4:
		if m.attivo(j):
			mn = min(mn, float(Dati.dist_viaggio(m.c(j)["pos"], l)))
	return mn

func _pressione(l: String) -> float:
	# quanto è «calda» una zona: somma delle vicinanze dei cacciatori
	var p := 0.0
	for j in 4:
		if m.attivo(j):
			var d := float(Dati.dist_viaggio(m.c(j)["pos"], l))
			p += 1.0 / (1.0 + d * d)
	return p

func _dracula_inizio(_r: Dictionary, opz: Array) -> String:
	return _migliore(opz, func(o): return _dist_cacciatori(o["id"]) + rng.randf() * 2.5 + (1.0 if Dati.regione(o["id"]) in [6, 7] else 0.0))

func _movimento(_r: Dictionary, opz: Array) -> String:
	var dr := m.pos_dracula()
	var danni := int(s()["dr"]["danni"])
	var vita := Dati.VITA_DRACULA - danni
	var vicino := _dist_cacciatori(dr)
	var punti := {}
	for o in opz:
		var id: String = o["id"]
		var v := 0.0
		if id.begins_with("v:"):
			var l: String = o["luogo"]
			v = min(_dist_cacciatori(l), 4.0) * 1.2 - _pressione(l) * 2.0
			if not m.cacciatori_in(l).is_empty():
				v -= 8.0
			if Dati.mare(l):
				v -= 1.5 + (2.0 if vita <= 5 else 0.0)
			if l == "castello":
				v += 1.0 + (3.0 if danni >= 5 else 0.0)
			# meglio non tornare sui propri passi già rivelati
			var rif := m.nasc_di(l)
			if not rif.is_empty():
				v += 0.5
			if s()["consacrato"].has(l):
				v -= 10
		else:
			match id:
				"p:nutrirsi": v = 0.5 + (3.5 if danni >= 6 else (1.5 if danni >= 3 else -1.0)) - (2.0 if vicino <= 1 else 0.0)
				"p:richiamo": v = (2.5 if s()["dr"]["inc"].size() <= 2 and vita > 6 else -1.0) - (2.0 if vicino <= 1 else 0.0)
				"p:nascondersi": v = (2.4 if vicino >= 3 else -1.0) + (0.5 if dr in ["castello"] else 0.0)
				"p:lupo": v = (3.0 if vicino <= 1 else -0.5) - (1.0 if vita <= 3 else 0.0)
				"p:depistaggio": v = (1.2 if _percorso_rivelato() else -1.0)
		v += rng.randf() * 1.4
		punti[id] = v
	return _migliore(opz, func(o): return punti[o["id"]])

func _percorso_rivelato() -> bool:
	var n := 0
	for h in s()["percorso"]:
		if h["riv"]:
			n += 1
	return n >= 2

func _lupo(_r: Dictionary, opz: Array) -> String:
	return _migliore(opz, func(o): return min(_dist_cacciatori(o["id"]), 5.0) - _pressione(o["id"]) * 2.0 + rng.randf())

func _depistaggio(_r: Dictionary, opz: Array) -> String:
	for o in opz:
		var k := int(o["id"])
		if s()["percorso"][k]["riv"]:
			return str(k)
	return str(opz[-1]["id"])

func _piazza_inc(r: Dictionary, opz: Array) -> String:
	var k := int(r.get("kk", 0))
	var luogo := ""
	if k < s()["percorso"].size():
		luogo = s()["percorso"][k]["luogo"]
		if luogo == "":
			luogo = m.pos_dracula()
	var vicino := _dist_cacciatori(luogo) if luogo != "" else 3.0
	var punti := {}
	for o in opz:
		var id: String = o["id"]
		var v := 0.0
		match id:
			"nuovo", "temerario", "aristocratico": v = 3.0 + (1.0 if vicino >= 3 else -1.5)
			"lupi", "guardie", "ratti": v = 2.0 + (1.5 if vicino <= 2 else 0.0)
			"pipistrelli", "nebbia", "sabotatore": v = 1.6 + (1.0 if vicino <= 2 else 0.0)
			"spia", "szgany": v = 1.4
			"sconsacrato": v = 1.0 + (1.5 if int(s()["dr"]["danni"]) >= 4 else 0.0)
			"raggiro": v = 0.6
		punti[id] = v + rng.randf() * 0.7
	return _migliore(opz, func(o): return punti[o["id"]])

func _piazza_inc_tana(r: Dictionary, opz: Array) -> String:
	return _piazza_inc({"kk": 99}, opz)

func _diceria(_r: Dictionary, opz: Array) -> String:
	for o in opz:
		if str(o["id"]) == "no":
			continue
		var h: Dictionary = s()["percorso"][int(o["id"])]
		for e in h["inc"]:
			if Dati.INCONTRI[e["id"]].get("vampiro", false):
				return str(o["id"])
	return "no"

func _maturo(_r: Dictionary, _opz: Array) -> String:
	var h: Dictionary = s()["flag"].get("uscente", {})
	for e in h.get("inc", []):
		if Dati.INCONTRI[e["id"]].get("vampiro", false):
			return "matura"
	if s()["tane"].size() < 3 and s()["dr"]["inc"].size() >= 3 and _dist_cacciatori(h.get("luogo", "")) >= 2:
		return "tana"
	return "matura"

func _imboscata(r: Dictionary, opz: Array) -> String:
	var i: int = r["h"]
	var mg: int = m.vita(i) - int(m.c(i)["danni"])
	for o in opz:
		var id: String = o["id"]
		if id == "no":
			continue
		var c_id: String = o.get("carta", "")
		if c_id in ["temerario", "nuovo"]:
			if mg <= 6 or s()["percorso"].size() >= 6:
				return id
			continue
		return id
	return "no"

func _comb_d(_r: Dictionary, opz: Array) -> String:
	var cb: Dictionary = s()["comb"]
	var nt: bool = cb["notte"]
	var danni: int = int(s()["dr"]["danni"]) if cb["tipo"] == "dracula" else int(cb["vamp_danni"])
	var vita: int = (Dati.VITA_DRACULA if cb["tipo"] == "dracula" else int(cb["vamp_vita"])) - danni
	var fuga_ok: bool = int(cb["giocate"]) + 1 > int(s()["disperazione"])
	var mesm_any: bool = not cb["mesm"].is_empty()
	var punti := {}
	for o in opz:
		var id: String = o["id"]
		var v := 1.0
		match id:
			"denti": v = 1.8 + (2.5 if nt and mesm_any else 0.0) + (1.0 if danni >= 2 else 0.0)
			"artigli": v = 1.7 + (0.8 if nt and cb["cacc"].size() > 1 else 0.0)
			"forza": v = 1.6
			"mesmerismo": v = 1.4 + (1.5 if nt and not mesm_any else 0.0)
			"macchinazione": v = 1.1
			"nebbia", "pipistrello": v = (-3.0 if not fuga_ok else (0.2 + (4.0 if vita <= 6 else 0.0) + (1.0 if cb["cacc"].size() >= 3 else 0.0)))
		punti[id] = v + rng.randf() * 1.2
	return _migliore(opz, func(o): return punti[o["id"]])

func _ingaggio(_r: Dictionary, opz: Array) -> String:
	var cb: Dictionary = s()["comb"]
	return _migliore(opz, func(o):
		var j := int(o["id"])
		var v := float(m.c(j)["danni"]) - m.vita(j) * 0.3
		if j in cb["mesm"]:
			v += 3.0
		return v)

func _artigli2(_r: Dictionary, opz: Array) -> String:
	return _ingaggio(_r, opz)

func _macchinazione(_r: Dictionary, opz: Array) -> String:
	var cb: Dictionary = s()["comb"]
	var vita := Dati.VITA_DRACULA - int(s()["dr"]["danni"])
	if vita <= 6:
		for e in ["nebbia", "pipistrello"]:
			if _ha(opz, e):
				return e
	if cb["notte"] and not cb["mesm"].is_empty() and _ha(opz, "denti"):
		return "denti"
	for e in ["mesmerismo", "artigli", "denti", "forza"]:
		if _ha(opz, e):
			return e
	return str(opz[0]["id"])

func _pipistrello(_r: Dictionary, opz: Array) -> String:
	return _migliore(opz, func(o): return 0.0 if o["id"] == "resta" else _dist_cacciatori(o["id"]) + rng.randf())

func _nebbia_comb(_r: Dictionary, _opz: Array) -> String:
	var vita := Dati.VITA_DRACULA - int(s()["dr"]["danni"])
	var n := m.cacciatori_in(m.pos_dracula()).size()
	return "combatti" if vita >= 10 and n == 1 else "evita"

func _guardie(_r: Dictionary, opz: Array) -> String:
	for o in opz:
		if str(o["id"]) != "no":
			return str(o["id"])
	return "no"

func _pipistrelli(r: Dictionary, opz: Array) -> String:
	var dr := m.pos_dracula()
	return _migliore(opz, func(o): return float(Dati.dist_viaggio(dr, o["id"])))

func _cavalli_impazziti(r: Dictionary, opz: Array) -> String:
	var dr := m.pos_dracula()
	var i: int = r["h"]
	var ora := float(Dati.dist_viaggio(dr, m.c(i)["pos"]))
	var best := "no"
	var bv := ora + 0.5
	for o in opz:
		if str(o["id"]) == "no":
			continue
		var d := float(Dati.dist_viaggio(dr, o["id"]))
		if d > bv:
			bv = d
			best = str(o["id"])
	return best

func _indicazioni(_r: Dictionary, _opz: Array) -> String:
	return "si"

func _dogana(r: Dictionary, _opz: Array) -> String:
	var i: int = r["h"]
	return "si" if m.c(i)["ogg"].size() >= 2 or m.vita(i) - int(m.c(i)["danni"]) <= 4 else "no"

func _seduzione(_r: Dictionary, _opz: Array) -> String:
	return "si"

func _stampa(_r: Dictionary, _opz: Array) -> String:
	return "si"

func _evento_dracula(r: Dictionary, opz: Array) -> String:
	var vicino := _dist_cacciatori(m.pos_dracula())
	var q: String = r["quando"]
	if q == "turno":
		if _ha(opz, "velocita") and vicino <= 1:
			return "velocita"
		if _ha(opz, "potere_diabolico") and (s()["alleato_c"] != "" or not s()["consacrato"].is_empty()):
			return "potere_diabolico"
		return "no"
	for e in ["trame", "oscurita"]:
		if _ha(opz, e):
			return e
	if _ha(opz, "visita") and vicino <= 1:
		return "visita"
	if _ha(opz, "strada_bloccata") and vicino <= 2:
		return "strada_bloccata"
	if _ha(opz, "tempeste") and _cacciatori_vicino_al_mare():
		return "tempeste"
	return "no"

func _cacciatori_vicino_al_mare() -> bool:
	for j in 4:
		if m.attivo(j) and (Dati.mare(m.c(j)["pos"]) or Dati.porto(m.c(j)["pos"])):
			return true
	return false

func _d_subito(r: Dictionary, opz: Array) -> String:
	var e: String = r["e"]
	match e:
		"grande_lupo": return "subito"
		"hildesheim": return "alleato"
		"spose": return "alleato" if s()["dr"]["alleato"] == "" else "subito"
		"tempeste", "strada_bloccata": return "tieni"
	return str(opz[0]["id"])

func _balzare(_r: Dictionary, opz: Array) -> String:
	return _migliore(opz, func(o):
		var j := int(o["id"])
		var v := float(m.c(j)["danni"])
		if m.ha_ogg(j, "crocifisso") or m.ha_ogg(j, "ostia"):
			v -= 20
		return v)

func _lupo_alleato(r: Dictionary, opz: Array) -> String:
	return _balzare(r, opz)

func _spose(_r: Dictionary, opz: Array) -> String:
	if _ha(opz, "raggiro"):
		return "raggiro"
	return "no"

func _spose_spazio(_r: Dictionary, opz: Array) -> String:
	for o in opz:
		if str(o["id"]) != "fine":
			return str(o["id"])
	return "fine"

func _influsso(_r: Dictionary, opz: Array) -> String:
	return _migliore(opz, func(o): return float(m.c(int(o["id"]))["ogg"].size()))

func _influsso_scarta(_r: Dictionary, opz: Array) -> String:
	for k in ["o:coltello", "o:pistola", "o:fucile", "o:crocifisso", "o:ostia", "o:cerchio"]:
		if _ha(opz, k):
			return k
	return str(opz[0]["id"])

func _influsso_dest(r: Dictionary, opz: Array) -> String:
	return _pipistrelli(r, opz)

func _potere_diabolico(_r: Dictionary, opz: Array) -> String:
	if _ha(opz, "alleato"):
		return "alleato"
	for o in opz:
		if str(o["id"]).begins_with("cons:"):
			return str(o["id"])
	return "rifornimento"

func _tempesta(r: Dictionary, opz: Array) -> String:
	for j in 4:
		if not m.attivo(j):
			continue
		var p: String = m.c(j)["pos"]
		for x in Dati.L(p)["porti"]:
			if Dati.mare(x) and _ha(opz, x):
				return x
	return "fine"

func _blocco(_r: Dictionary, opz: Array) -> String:
	var dr := m.pos_dracula()
	var best := "fine"
	var bv := -INF
	for o in opz:
		if str(o["id"]) == "fine":
			continue
		var a: String = o["a"]
		var b: String = o["b"]
		var v := -999.0
		for j in 4:
			if not m.attivo(j):
				continue
			var p: String = m.c(j)["pos"]
			if p == a or p == b:
				var altro := b if p == a else a
				v = max(v, float(Dati.dist_viaggio(p, dr) - Dati.dist_viaggio(altro, dr)) + 1.0)
		v += rng.randf() * 0.2
		if v > bv:
			bv = v
			best = str(o["id"])
	return best if bv > 0 else "fine"

func _sconsacrato(_r: Dictionary, opz: Array) -> String:
	return "raggiro" if _ha(opz, "raggiro") else "fine"

func _raggiro(_r: Dictionary, opz: Array) -> String:
	for e in ["velocita", "visita", "trame", "furioso", "seduzione", "indicazioni"]:
		if _ha(opz, e):
			return e
	return str(opz[0]["id"])

func _lupi_maturi(_r: Dictionary, opz: Array) -> String:
	return _migliore(opz, func(o): return float(m.cacciatori_in(o["id"]).size()))

func _nebbia_matura(_r: Dictionary, opz: Array) -> String:
	return _migliore(opz, func(o): return float(m.cacciatori_in(o["id"]).size()) + _pressione(o["id"]))

func _spia_matura(_r: Dictionary, opz: Array) -> String:
	return _migliore(opz, func(o): return float(m.c(int(o["id"]))["big"].size()))

func _limite_ev_d(_r: Dictionary, opz: Array) -> String:
	for e in ["tempeste", "potere_diabolico", "stampa", "dogana", "indicazioni"]:
		if _ha(opz, e):
			return e
	return str(opz[0]["id"])

func _ritorno_d(_r: Dictionary, opz: Array) -> String:
	return str(opz[0]["id"])
