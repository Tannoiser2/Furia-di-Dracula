## Motore delle regole di La Furia di Dracula (terza edizione, Fantasy Flight Games).
## Tutto lo stato della partita sta in `s` (un dizionario che si salva in JSON e si manda in rete).
## Il motore va avanti da solo finché non serve una decisione: allora `richiesta()` dice chi deve
## decidere cosa (g = 0..3 cacciatori, 4 = Dracula) con l'elenco delle opzioni; `applica({"id": ...})` la esegue.
## Il mazzo e i dadi usano un generatore con seme: la stessa sequenza di decisioni dà sempre la stessa partita
## (così funziona l'online: i dispositivi si scambiano solo le decisioni).
## Il flusso del turno è una pila di passi (`s.pila`): ogni passo è un dizionario {f: nome, ...} serializzabile.
class_name Motore
extends RefCounted

const DRACULA := 4
const MAX_LOG := 3000
const NOMI_PG := ["Lord Godalming", "Dr. Seward", "Van Helsing", "Mina Harker", "Dracula"]

var s: Dictionary = {}
var rng := RandomNumberGenerator.new()

# ============================================================ avvio

## cfg: {seat: [5 posti: -1 = IA], seed, facile}
func nuova(cfg: Dictionary) -> void:
	rng.seed = int(cfg.get("seed", 1))
	s = {"seed": int(cfg.get("seed", 1)), "passo": 0, "pila": [], "coda": [], "log": [], "esito": {},
		"seat": cfg.get("seat", [-1, -1, -1, -1, 0]), "facile": bool(cfg.get("facile", false)),
		"giorno": 0, "notte": false, "fase": "inizio", "primo": true,
		"influenza": 0, "disperazione": 0, "dicerie": 1, "dicerie_pool": 9,
		"dr": {"danni": 0, "inc": [], "ev": [], "alleato": "", "guardie": 0, "visto": ""},
		"cacc": [], "alleato_c": "", "percorso": [], "tane": [],
		"m_ogg": [], "s_ogg": [], "m_ev": [], "s_ev": [], "m_inc": [], "s_inc": [], "comb_d": [],
		"riserva_big": [], "nebbia": {}, "blocchi": [], "tempeste": [], "consacrato": [], "schiera": [],
		"flag": {}, "comb": {}, "eventi_pubblici": [], "ultimo_evento": {}}
	for i in 4:
		var d: Dictionary = Dati.CACCIATORI[i]
		s["cacc"].append({"id": d["id"], "pos": "", "osp": "", "sconfitto": false, "danni": 0,
			"morsi": 1 if i == 3 else 0, "ogg": [], "ev": [], "big": [], "trattenuto": false, "pipistrelli": false})
	for k in Dati.OGGETTI:
		for n in int(Dati.OGGETTI[k]["n"]):
			s["m_ogg"].append(k)
	for k in Dati.EVENTI:
		for n in int(Dati.EVENTI[k]["n"]):
			s["m_ev"].append(k)
	for k in Dati.INCONTRI:
		for n in int(Dati.INCONTRI[k]["n"]):
			s["m_inc"].append(k)
	for b in Dati.BIGLIETTI:
		s["riserva_big"].append(b.duplicate())
	_mescola(s["m_ogg"])
	_mescola(s["m_ev"])
	_mescola(s["m_inc"])
	_mescola(s["riserva_big"])
	for n in 5:
		s["dr"]["inc"].append(s["m_inc"].pop_back())
	_log("La caccia ha inizio. Lunedì, giorno.")
	for i in 4:
		_chiedi(i, "partenza", "Scegli la città di partenza di %s." % NOMI_PG[i], _opz_partenza())
	s["pila"] = [{"f": "dracula_inizio"}, {"f": "fase_azioni", "notte": false}, {"f": "tramonto"}]
	_salva_rng()
	avanza()

func carica(stato: Dictionary) -> void:
	s = stato
	rng.seed = int(s["seed"])
	rng.state = int(str(s.get("rng", "0")))

func _salva_rng() -> void:
	s["rng"] = str(rng.state)

# ============================================================ utilità

func c(i: int) -> Dictionary:
	return s["cacc"][i]

func nome(i: int) -> String:
	return NOMI_PG[i]

func _log(t: String) -> void:
	s["log"].append(t)
	if s["log"].size() > MAX_LOG:
		s["log"].pop_front()

func _mescola(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func _o(id, testo: String, extra := {}) -> Dictionary:
	var d := {"id": str(id), "testo": testo}
	d.merge(extra)
	return d

func _chiedi(g: int, k: String, testo: String, opz: Array, extra := {}) -> void:
	var r := {"g": g, "k": k, "testo": testo, "opz": opz}
	r.merge(extra)
	s["coda"].append(r)

func _push(passi: Array) -> void:
	# mette i passi in cima alla pila, nell'ordine dato
	for i in range(passi.size() - 1, -1, -1):
		s["pila"].push_front(passi[i])

func richiesta() -> Dictionary:
	if s["coda"].is_empty():
		return {}
	return s["coda"][0]

func finita() -> bool:
	return not s["esito"].is_empty()

func avanza() -> void:
	var guard := 0
	while s["coda"].is_empty() and not finita():
		guard += 1
		if guard > 4000 or s["pila"].is_empty():
			push_error("motore fermo: pila vuota")
			return
		var p: Dictionary = s["pila"].pop_front()
		call("_p_" + str(p["f"]), p)
		_controlla_fine()
	_salva_rng()

func applica(dec: Dictionary) -> bool:
	var r := richiesta()
	if r.is_empty() or finita():
		return false
	var scelta = null
	for o in r["opz"]:
		if str(o["id"]) == str(dec.get("id", "")):
			scelta = o
			break
	if scelta == null:
		push_warning("decisione non valida: %s per %s" % [dec, r["k"]])
		return false
	s["coda"].pop_front()
	s["passo"] += 1
	call("_d_" + str(r["k"]), r, scelta)
	_controlla_fine()
	avanza()
	return true

func _controlla_fine() -> void:
	if finita():
		return
	if int(s["influenza"]) >= 13:
		s["influenza"] = 13
		s["esito"] = {"vince": "dracula", "testo": "L'Influenza di Dracula ha raggiunto 13: l'Europa cade sotto il suo dominio."}
		_log("DRACULA VINCE: la Scala di Influenza è arrivata a 13.")
		s["coda"].clear()
	elif int(s["dr"]["danni"]) >= Dati.VITA_DRACULA:
		s["esito"] = {"vince": "cacciatori", "testo": "Dracula è stato sconfitto! Il Conte torna polvere."}
		_log("I CACCIATORI VINCONO: Dracula è sconfitto.")
		s["coda"].clear()

func notte() -> bool:
	return bool(s["notte"])

func giorno_settimana() -> int:
	return int(s["giorno"]) % 7

func descr_tempo() -> String:
	return "%s, %s" % [Dati.GIORNI[giorno_settimana()], "notte" if notte() else "giorno"]

func indebolito(i: int) -> bool:
	return i == 3 or int(c(i)["morsi"]) > 0

func vita(i: int) -> int:
	return int(Dati.CACCIATORI[i]["vita"])

func max_ev(i: int) -> int:
	return int(Dati.CACCIATORI[i]["max_ev"])

func max_ogg(i: int) -> int:
	return int(Dati.CACCIATORI[i]["max_ogg"])

func attivo(i: int) -> bool:
	return not c(i)["sconfitto"] and c(i)["osp"] == ""

func in_citta(i: int, luogo: String) -> bool:
	return attivo(i) and c(i)["pos"] == luogo

func cacciatori_in(luogo: String) -> Array:
	var out := []
	for i in 4:
		if in_citta(i, luogo):
			out.append(i)
	return out

func luoghi_cacciatori() -> Array:
	var out := []
	for i in 4:
		if attivo(i) and not out.has(c(i)["pos"]):
			out.append(c(i)["pos"])
	return out

func ha_ogg(i: int, id: String) -> bool:
	return id in c(i)["ogg"]

func armi(i: int) -> int:
	var n := 0
	for o in c(i)["ogg"]:
		if Dati.OGGETTI[o].get("arma", false):
			n += 1
	return n

func _togli(arr: Array, id: String) -> bool:
	var k := arr.find(id)
	if k >= 0:
		arr.remove_at(k)
		return true
	return false

func _scarta_ogg(i: int, id: String) -> void:
	if _togli(c(i)["ogg"], id):
		s["s_ogg"].append(id)

func _scarta_ev(i: int, id: String) -> void:
	if _togli(c(i)["ev"], id):
		s["s_ev"].append({"id": id, "coperta": false})

# ---------- percorso e nascondigli

func _nasc(luogo := "", potere := "") -> Dictionary:
	return {"luogo": luogo, "potere": potere, "inc": [], "diceria": false, "riv": false, "riv_p": false, "esclusi": []}

## Posizione reale di Dracula: la carta Luogo più a sinistra del Percorso.
func pos_dracula() -> String:
	for h in s["percorso"]:
		if h["luogo"] != "":
			return h["luogo"]
	return str(s["dr"].get("ultimo", ""))

func indice_attuale() -> int:
	for k in s["percorso"].size():
		if s["percorso"][k]["luogo"] != "":
			return k
	return -1

func dracula_rivelato() -> bool:
	var k := indice_attuale()
	return k >= 0 and bool(s["percorso"][k]["riv"])

## Luoghi le cui carte sono sul Percorso o nelle tane (non nel mazzo).
func luoghi_in_uso() -> Array:
	var out := []
	for h in s["percorso"] + s["tane"]:
		if h["luogo"] != "":
			out.append(h["luogo"])
	return out

func poteri_in_uso() -> Array:
	var out := []
	for h in s["percorso"]:
		if h["potere"] != "" and h["potere"] != "pipistrello":
			out.append(h["potere"])
	return out

## Il nascondiglio (sul Percorso o in una tana) che corrisponde a un luogo: {dove: "p"/"t", k}.
func nasc_di(luogo: String) -> Dictionary:
	for k in s["percorso"].size():
		if s["percorso"][k]["luogo"] == luogo:
			return {"dove": "p", "k": k}
	for k in s["tane"].size():
		if s["tane"][k]["luogo"] == luogo:
			return {"dove": "t", "k": k}
	return {}

func _h(rif: Dictionary) -> Dictionary:
	return s["percorso"][rif["k"]] if rif["dove"] == "p" else s["tane"][rif["k"]]

## Il nascondiglio con Nascondersi associato al luogo sul Percorso (indice) o -1.
func _nascondersi_di(kluogo: int) -> int:
	if kluogo > 0 and s["percorso"][kluogo - 1]["potere"] == "nascondersi":
		return kluogo - 1
	return -1

func _nuovo_inc(id: String) -> Dictionary:
	s["uid_n"] = int(s.get("uid_n", 0)) + 1
	return {"id": id, "riv": false, "uid": "e%d" % s["uid_n"]}

func _sgombera(h: Dictionary) -> void:
	for e in h["inc"]:
		s["s_inc"].append(e["id"])
	h["inc"] = []
	if h["diceria"]:
		s["dicerie_pool"] += 1
		h["diceria"] = false

func tipo_carta(h: Dictionary) -> String:
	if h["luogo"] == "":
		return "potere"
	if h["luogo"] == "castello":
		return "castello"
	return "mare" if Dati.mare(h["luogo"]) else "terra"

## Le carte Potere visibili a tutti (Nascondersi resta coperta).
func potere_visibile(h: Dictionary) -> bool:
	return h["potere"] != "" and (h["potere"] != "nascondersi" or h["riv_p"])

# ============================================================ partenza

func _opz_partenza() -> Array:
	var out := []
	var nomi := []
	for k in Dati.citta():
		if k != "castello":
			nomi.append(k)
	nomi.sort_custom(func(a, b): return Dati.nome(a) < Dati.nome(b))
	for k in nomi:
		out.append(_o(k, Dati.nome(k), {"luogo": k}))
	return out

func _d_partenza(r: Dictionary, o: Dictionary) -> void:
	c(r["g"])["pos"] = o["id"]
	_log("%s parte da %s." % [nome(r["g"]), Dati.nome(o["id"])])

func _p_dracula_inizio(_p: Dictionary) -> void:
	var opz := []
	for k in Dati.citta():
		if k == "castello" or k in luoghi_cacciatori():
			continue
		opz.append(_o(k, Dati.nome(k), {"luogo": k}))
	opz.sort_custom(func(a, b): return a["testo"] < b["testo"])
	_chiedi(DRACULA, "dracula_inizio", "Scegli in segreto dove si trova Dracula all'inizio.", opz)

func _d_dracula_inizio(_r: Dictionary, o: Dictionary) -> void:
	s["percorso"] = [_nasc(o["id"])]
	s["dr"]["ultimo"] = o["id"]
	_log("Dracula sceglie in segreto il suo nascondiglio iniziale.")

# ============================================================ turno dei cacciatori

func _p_alba(_p: Dictionary) -> void:
	s["giorno"] = int(s["giorno"]) + 1
	s["notte"] = false
	s["fase"] = "alba"
	s["flag"].erase("vigore")
	s["flag"].erase("telegrammi")
	_log("— Alba di %s —" % Dati.GIORNI[giorno_settimana()])
	if giorno_settimana() == 0:
		if int(s["disperazione"]) < 3:
			s["disperazione"] += 1
			_log("Una nuova settimana: segnalino Disperazione (%d/3)." % s["disperazione"])
		if s["dicerie_pool"] > 0:
			s["dicerie_pool"] -= 1
			s["dicerie"] += 1
	# la Schiera Celeste svanisce all'alba successiva
	if not s["schiera"].is_empty() and s["flag"].get("schiera_nuova", false) == false:
		s["schiera"] = []
	s["flag"].erase("schiera_nuova")
	# i cacciatori sconfitti vanno all'ospedale più vicino
	for i in 4:
		if c(i)["sconfitto"]:
			_in_ospedale(i)
	var passi := [{"f": "eventi_alba", "tramonto": false}, {"f": "combattimento_dracula"}]
	if s["flag"].get("no_giorno", false):
		s["flag"].erase("no_giorno")
		_log("L'Oscurità Ritorna: non c'è giorno per i cacciatori.")
	else:
		passi.append({"f": "fase_azioni", "notte": false})
	passi.append({"f": "tramonto"})
	_push(passi)

func _in_ospedale(i: int) -> void:
	var da: String = c(i).get("sconfitto_in", "madrid")
	var best := "madrid"
	var bd := 999
	for o in ["madrid", "roma", "budapest"]:
		var d := Dati.dist_viaggio(da, o) if Dati.mare(da) else Dati.dist(da, o)
		if not Dati.mare(da) and Dati.regione(da) == 1:
			d = 0 if o == "madrid" else 99
		if da == "cagliari":
			d = 0 if o == "roma" else 99
		if d < bd:
			bd = d
			best = o
	var h := c(i)
	h["sconfitto"] = false
	h["osp"] = best
	h["pos"] = best
	h["danni"] = 0
	h["morsi"] = 1 if i == 3 else 0
	h["trattenuto"] = false
	h["pipistrelli"] = false
	for o in h["ogg"]:
		s["s_ogg"].append(o)
	for e in h["ev"]:
		s["s_ev"].append({"id": e, "coperta": false})
	h["ogg"] = []
	h["ev"] = []
	_log("%s si risveglia all'ospedale di %s." % [nome(i), Dati.nome(best)])

func _p_tramonto(_p: Dictionary) -> void:
	s["notte"] = true
	s["fase"] = "tramonto"
	_log("— Tramonto —")
	_push([{"f": "eventi_alba", "tramonto": true}, {"f": "combattimento_dracula"}, {"f": "fine_tramonto"},
		{"f": "fase_azioni", "notte": true}, {"f": "turno_dracula"}, {"f": "alba"}])

func _p_fine_tramonto(_p: Dictionary) -> void:
	# alla fine del tramonto Dracula toglie 1 Nebbia, 1 Strada Bloccata e 1 Tempesta
	if not s["nebbia"].is_empty():
		var k: String = s["nebbia"].keys()[0]
		s["nebbia"][k] -= 1
		if s["nebbia"][k] <= 0:
			s["nebbia"].erase(k)
		_log("Si dirada un banco di nebbia a %s." % Dati.nome(k))
	if not s["blocchi"].is_empty():
		var b = s["blocchi"].pop_front()
		_log("Riaperta la %s %s–%s." % ["ferrovia" if b[2] else "strada", Dati.nome(b[0]), Dati.nome(b[1])])
	if not s["tempeste"].is_empty():
		var t = s["tempeste"].pop_front()
		_log("La tempesta si placa sul %s." % Dati.nome(t))

## Eventi giocabili all'alba (o al tramonto) dai cacciatori.
func _p_eventi_alba(p: Dictionary) -> void:
	var tramonto: bool = p["tramonto"]
	for i in 4:
		if not attivo(i) and not (c(i)["osp"] != "" and not c(i)["sconfitto"]):
			continue
		var opz := []
		for e in c(i)["ev"]:
			if opz.any(func(x): return x["id"] == e):
				continue
			if e == "giornali" or e == "ritorno":
				opz.append(_o(e, "Gioca " + Dati.EVENTI[e]["nome"], {"carta": e}))
			elif not tramonto and e in ["lunga_notte", "vigore", "telegrammi"]:
				opz.append(_o(e, "Gioca " + Dati.EVENTI[e]["nome"], {"carta": e}))
		if e_ritorno_inutile(opz):
			opz = opz.filter(func(x): return x["id"] != "ritorno")
		if not opz.is_empty():
			opz.append(_o("no", "Nessuna carta"))
			_chiedi(i, "evento_alba", "%s: vuoi giocare un evento %s?" % [nome(i), "al tramonto" if tramonto else "all'alba"], opz, {"tramonto": tramonto})

func e_ritorno_inutile(_opz: Array) -> bool:
	for x in s["s_ev"]:
		if not x["coperta"] and Dati.EVENTI[x["id"]].get("alleato", false) and not Dati.EVENTI[x["id"]]["d"]:
			return false
	return true

func _d_evento_alba(r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "no":
		return
	var i: int = r["g"]
	var e: String = o["id"]
	_scarta_ev(i, e)
	_annuncia(i, e)
	match e:
		"giornali":
			_effetto_giornali(i, false)
		"ritorno":
			var opz := []
			for x in s["s_ev"]:
				if not x["coperta"] and Dati.EVENTI[x["id"]].get("alleato", false) and not Dati.EVENTI[x["id"]]["d"] and not opz.any(func(y): return y["id"] == x["id"]):
					opz.append(_o(x["id"], Dati.EVENTI[x["id"]]["nome"], {"carta": x["id"]}))
			if opz.is_empty():
				_log("Nessun alleato negli scarti.")
			else:
				_chiedi(i, "ritorno", "Quale alleato riprendi dagli scarti?", opz)
		"lunga_notte":
			s["flag"]["lunga_notte"] = true
			_log("Lunga Notte: stanotte i cacciatori possono muoversi su strada.")
		"vigore":
			s["flag"]["vigore"] = true
			_log("Ritrovato Vigore: oggi ogni cacciatore ha un'azione in più.")
		"telegrammi":
			s["flag"]["telegrammi"] = true
			_log("Telegrammi Veloci: in questo turno i cacciatori agiscono nell'ordine che vogliono.")

func _d_ritorno(r: Dictionary, o: Dictionary) -> void:
	for k in s["s_ev"].size():
		if s["s_ev"][k]["id"] == o["id"]:
			s["s_ev"].remove_at(k)
			break
	_gioca_alleato_c(r["g"], o["id"])

func _gioca_alleato_c(i: int, e: String) -> void:
	if s["alleato_c"] != "":
		s["s_ev"].append({"id": s["alleato_c"], "coperta": false})
	s["alleato_c"] = e
	_log("%s: %s diventa alleato dei cacciatori." % [nome(i), Dati.EVENTI[e]["nome"]])

func _annuncia(g: int, e: String) -> void:
	s["ultimo_evento"] = {"g": g, "e": e, "passo": s["passo"]}
	s["eventi_pubblici"].append({"g": g, "e": e})
	if s["eventi_pubblici"].size() > 40:
		s["eventi_pubblici"].pop_front()
	_log("%s gioca «%s»." % [nome(g), Dati.EVENTI[e]["nome"]])

# ---------- azioni

func _p_fase_azioni(p: Dictionary) -> void:
	var nt: bool = p["notte"]
	s["fase"] = "notte" if nt else "giorno"
	var passi := []
	var giri := 2 if (not nt and s["flag"].get("vigore", false)) else 1
	if s["flag"].get("telegrammi", false):
		passi.append({"f": "scegli_ordine", "notte": nt, "fatti": [], "giri": giri})
	else:
		for gi in giri:
			for i in 4:
				passi.append({"f": "azione", "h": i, "notte": nt, "giro": gi})
	if nt:
		passi.append({"f": "fine_notte"})
	_push(passi)

func _p_fine_notte(_p: Dictionary) -> void:
	s["flag"].erase("lunga_notte")
	s["flag"].erase("no_rifornimento")

func _p_scegli_ordine(p: Dictionary) -> void:
	var fatti: Array = p["fatti"]
	var opz := []
	for i in 4:
		if fatti.count(i) < int(p["giri"]) and not c(i)["sconfitto"]:
			opz.append(_o(i, nome(i)))
	if opz.is_empty():
		return
	var chi := int(opz[0]["id"])
	_chiedi(chi, "ordine", "Telegrammi Veloci: chi agisce adesso?", opz, {"p": p})

func _d_ordine(r: Dictionary, o: Dictionary) -> void:
	var p: Dictionary = r["p"].duplicate(true)
	var i := int(o["id"])
	p["fatti"].append(i)
	_push([{"f": "azione", "h": i, "notte": p["notte"], "giro": p["fatti"].count(i) - 1}, p])

func _p_azione(p: Dictionary) -> void:
	var i: int = p["h"]
	var h := c(i)
	if h["sconfitto"]:
		return
	s["fase"] = "notte" if p["notte"] else "giorno"
	if h["trattenuto"]:
		h["trattenuto"] = false
		_log("%s si rimette in piedi (era trattenuto)." % nome(i))
		return
	if h["pipistrelli"] and h["osp"] == "" and not Dati.mare(h["pos"]) and not s["nebbia"].has(h["pos"]):
		var opz := []
		for n in Dati.strade(h["pos"]):
			if not s["nebbia"].has(n):
				opz.append(_o(n, Dati.nome(n), {"luogo": n}))
		h["pipistrelli"] = false
		if not opz.is_empty():
			_chiedi(DRACULA, "pipistrelli", "Pipistrelli: dove sposti %s?" % nome(i), opz, {"h": i})
			return
	if Dati.mare(h["pos"]):
		if p["notte"]:
			_log("%s è in mare: di notte non può agire." % nome(i))
			return
		var opz := _opz_mare(i)
		if opz.is_empty():
			_log("%s è bloccato in mare dalla tempesta." % nome(i))
			return
		_chiedi(i, "azione", "%s è in mare: deve proseguire la navigazione." % nome(i), opz, {"notte": false, "giro": p.get("giro", 0)})
		return
	_chiedi(i, "azione", "%s — %s: scegli l'azione." % [nome(i), "notte" if p["notte"] else "giorno"], _opz_azione(i, p["notte"], p.get("giro", 0)), {"notte": p["notte"], "giro": p.get("giro", 0)})

func _d_pipistrelli(r: Dictionary, o: Dictionary) -> void:
	var i: int = r["h"]
	_log("Uno stormo di pipistrelli trascina %s a %s." % [nome(i), Dati.nome(o["id"])])
	c(i)["trattenuto"] = true
	_arriva(i, o["id"], "strada")

func _bloccata(a: String, b: String, ferrovia: bool) -> bool:
	for x in s["blocchi"]:
		if bool(x[2]) == ferrovia and ((x[0] == a and x[1] == b) or (x[0] == b and x[1] == a)):
			return true
	return false

func dest_strada(i: int) -> Array:
	var da: String = c(i)["pos"]
	if s["nebbia"].has(da):
		return []
	var out := []
	for n in Dati.strade(da):
		if s["nebbia"].has(n) or _bloccata(da, n, false):
			continue
		out.append(n)
	return out

func _opz_mare(i: int) -> Array:
	var out := []
	var da: String = c(i)["pos"]
	if s["nebbia"].has(da):
		return out
	for n in Dati.L(da)["porti"]:
		if Dati.mare(n) and n in s["tempeste"]:
			continue
		if not Dati.mare(n) and s["nebbia"].has(n):
			continue
		out.append(_o("mare:" + n, "Per mare verso " + Dati.nome(n), {"luogo": n, "gruppo": "muovi"}))
	return out

## Destinazioni in treno con un biglietto [bianco, giallo] (o fino a 4 con la Carrozza Riservata).
func dest_treno(da: String, b: Array, carrozza := false) -> Array:
	if s["nebbia"].has(da):
		return []
	var w := 4 if carrozza else int(b[0])
	var y := 4 if carrozza else int(b[1])
	var dw := {da: 0}
	var da_any := {da: 0}
	for passo in [true, false]:
		var d: Dictionary = dw if passo else da_any
		var coda := [da]
		while not coda.is_empty():
			var x: String = coda.pop_front()
			for f in Dati.L(x)["fer"]:
				var n: String = f[0]
				if passo and f[1] != "b":
					continue
				if _bloccata(x, n, true) or d.has(n):
					continue
				d[n] = d[x] + 1
				coda.append(n)
	var out := []
	for n in da_any:
		if n == da or s["nebbia"].has(n):
			continue
		if int(dw.get(n, 99)) <= w or (y > 0 and int(da_any[n]) <= y):
			out.append(n)
	return out

func _opz_azione(i: int, nt: bool, giro: int) -> Array:
	var h := c(i)
	var out := []
	var pos: String = h["pos"]
	var gia: String = str(h.get("ultima_azione", "")) if giro > 0 else ""
	if h["osp"] != "":
		out.append(_o("osp", "Esci dall'ospedale verso " + Dati.nome(h["osp"]), {"luogo": h["osp"], "gruppo": "muovi"}))
		out.append(_o("rifornimento", "Rifornimento: pesca 1 Oggetto", {"gruppo": "azioni"}))
		out.append(_o("passa", "Passa", {"gruppo": "azioni"}))
		return out
	var muovi_ok: bool = not nt or s["flag"].get("lunga_notte", false)
	if muovi_ok and gia != "muovi":
		for n in dest_strada(i):
			out.append(_o("strada:" + n, "Su strada verso " + Dati.nome(n), {"luogo": n, "gruppo": "muovi"}))
		if not nt:
			for k in h["big"].size():
				var b: Array = h["big"][k]
				if not dest_treno(pos, b).is_empty():
					out.append(_o("treno:%d" % k, "In treno con il biglietto %s" % _desc_big(b), {"gruppo": "muovi", "big": k}))
			if "carrozza" in h["ev"] and not h["big"].is_empty():
				out.append(_o("carrozza", "Carrozza Riservata: in treno fino a 4 ferrovie", {"gruppo": "muovi"}))
			out.append_array(_opz_mare(i))
			if ha_ogg(i, "cavalli") and not s["riserva_big"].is_empty() and not s["nebbia"].has(pos):
				out.append(_o("cavalli", "Cavalli Veloci: galoppa su strada", {"gruppo": "muovi"}))
	if gia != "biglietto" and pos != "castello":
		out.append(_o("biglietto", "Prenota un biglietto (ne hai %d/2)" % h["big"].size(), {"gruppo": "azioni"}))
	if gia != "riposo":
		out.append(_o("riposo", "Riposa: recuperi %s" % ("1 danno" if _cura_riposo(i) == 1 else "%d danni" % _cura_riposo(i)), {"gruppo": "azioni"}))
	if gia != "ricerca" and not s["nebbia"].has(pos):
		out.append(_o("ricerca", "Ricerca a %s" % Dati.nome(pos), {"gruppo": "azioni"}))
	if gia != "rifornimento" and pos != "castello" and not s["flag"].get("no_rifornimento", false):
		var t := "Rifornimento: "
		if Dati.L(pos)["grande"]:
			t += "Oggetto%s ed Evento" % ("i" if i == 0 else "")
		else:
			t += "carta Evento"
		t += " (dal fondo del mazzo)" if nt else ""
		out.append(_o("rifornimento", t, {"gruppo": "azioni"}))
	if gia != "scambio":
		for j in 4:
			if j != i and in_citta(j, pos):
				out.append(_o("scambio:%d" % j, "Scambia con %s" % nome(j), {"gruppo": "scambi"}))
		if i == 2:
			for j in 4:
				if j != i and not in_citta(j, pos) and not c(j)["sconfitto"]:
					out.append(_o("leader:%d" % j, "Leader: scambia carte Evento con %s" % nome(j), {"gruppo": "scambi"}))
	if i == 3 and gia != "legame":
		for j in 3:
			if in_citta(j, pos):
				out.append(_o("legame", "Legame psichico: Dracula svela la sua regione", {"gruppo": "speciale"}))
				break
	for e in h["ev"]:
		if out.any(func(x): return x["id"] == "ev:" + e):
			continue
		if _evento_azione_ok(i, e, nt):
			out.append(_o("ev:" + e, "Gioca " + Dati.EVENTI[e]["nome"], {"gruppo": "speciale", "carta": e}))
	# eventi liberi (non costano l'azione)
	if not nt and "buona_fortuna" in h["ev"] and (not s["blocchi"].is_empty() or s["dr"]["alleato"] != ""):
		out.append(_o("libero:buona_fortuna", "Gioca Buona Fortuna (non costa l'azione)", {"gruppo": "speciale", "carta": "buona_fortuna"}))
	out.append(_o("passa", "Passa", {"gruppo": "azioni"}))
	return out

func _desc_big(b: Array) -> String:
	if int(b[1]) == 0:
		return "%d (solo ferrovie bianche)" % int(b[0])
	return "%d bianco / %d giallo" % [int(b[0]), int(b[1])]

func _cura_riposo(i: int) -> int:
	if i == 1:
		return 2
	for j in 4:
		if j == 1 and in_citta(1, c(i)["pos"]):
			return 2
	return 1

func _evento_azione_ok(i: int, e: String, nt: bool) -> bool:
	var d: Dictionary = Dati.EVENTI[e]
	if d.has("solo") and int(d["solo"]) != i:
		return false
	match d["quando"]:
		"azione":
			if e == "trasfusione":
				if indebolito(i):
					return false
				for j in 4:
					if j != i and in_citta(j, c(i)["pos"]) and indebolito(j) and (j != 3 or int(c(j)["morsi"]) > 1):
						return true
				return false
			if e == "ipnosi":
				for j in 3:
					if in_citta(j, c(i)["pos"]):
						return true
				return false
			if e == "denaro":
				return true
			return true
		"azione_giorno":
			if nt:
				return false
			if e == "tana":
				return ha_ogg(i, "paletto")
			if e == "tempo_sereno":
				return Dati.porto(c(i)["pos"])
			return true
		"azione_notte":
			return nt
	return false

func _d_azione(r: Dictionary, o: Dictionary) -> void:
	var i: int = r["g"]
	var id: String = o["id"]
	var h := c(i)
	var tipo := id.get_slice(":", 0)
	h["ultima_azione"] = {"strada": "muovi", "mare": "muovi", "treno": "muovi", "carrozza": "muovi", "cavalli": "muovi", "osp": "muovi",
		"scambio": "scambio", "leader": "scambio"}.get(tipo, tipo)
	match tipo:
		"strada":
			_log("%s si sposta su strada a %s." % [nome(i), Dati.nome(id.get_slice(":", 1))])
			_muovi(i, id.get_slice(":", 1), "strada")
		"mare":
			_log("%s naviga verso %s." % [nome(i), Dati.nome(id.get_slice(":", 1))])
			_muovi(i, id.get_slice(":", 1), "mare")
		"osp":
			h["osp"] = ""
			_log("%s lascia l'ospedale ed entra a %s." % [nome(i), Dati.nome(h["pos"])])
			_arriva(i, h["pos"], "strada")
		"treno":
			var k := int(id.get_slice(":", 1))
			var b: Array = h["big"][k]
			h["big"].remove_at(k)
			s["riserva_big"].append(b)
			_mescola(s["riserva_big"])
			_log("%s spende un biglietto (%s) e sale sul treno." % [nome(i), _desc_big(b)])
			_treno(i, dest_treno(h["pos"], b), false)
		"carrozza":
			_scarta_ev(i, "carrozza")
			_annuncia(i, "carrozza")
			var b: Array = h["big"].pop_back()
			s["riserva_big"].append(b)
			_mescola(s["riserva_big"])
			_treno(i, dest_treno(h["pos"], b, true), true)
		"cavalli":
			var b: Array = s["riserva_big"][0]
			var n := int(b[1])
			_log("%s rivela un biglietto (%s) e galoppa con i Cavalli Veloci." % [nome(i), _desc_big(b)])
			if n == 0:
				n = 1
				_scarta_ogg(i, "cavalli")
			var dd := Dati.distanze_strada(h["pos"], n)
			var opz := []
			for k in dd:
				if k != h["pos"] and not s["nebbia"].has(k):
					opz.append(_o(k, Dati.nome(k), {"luogo": k}))
			opz.sort_custom(func(a, b2): return a["testo"] < b2["testo"])
			if not opz.is_empty():
				_chiedi(i, "dest_cavalli", "Cavalli Veloci: fino a %d strade. Dove vai?" % n, opz)
		"biglietto":
			_prenota(i)
		"riposo":
			var n := _cura_riposo(i)
			h["danni"] = max(0, int(h["danni"]) - n)
			_log("%s riposa e recupera %d danni." % [nome(i), n])
		"ricerca":
			_ricerca(i)
		"rifornimento":
			_rifornimento(i, bool(r.get("notte", false)))
		"scambio":
			_scambio(i, int(id.get_slice(":", 1)), false)
		"leader":
			_scambio(i, int(id.get_slice(":", 1)), true)
		"legame":
			_log("Legame psichico: Mina percepisce Dracula in %s." % Dati.nome_regione(_regione_dracula()))
			s["flag"]["regione_nota"] = {"r": _regione_dracula(), "passo": s["passo"]}
		"ev":
			_evento_azione(i, id.get_slice(":", 1), bool(r.get("notte", false)))
		"libero":
			_evento_libero(i, id.get_slice(":", 1), r)
		"passa":
			_log("%s passa." % nome(i))

func _regione_dracula() -> int:
	var p := pos_dracula()
	if Dati.mare(p):
		return 0
	return Dati.regione(p)

func _d_dest_cavalli(r: Dictionary, o: Dictionary) -> void:
	_log("%s arriva a %s." % [nome(r["g"]), Dati.nome(o["id"])])
	_muovi(r["g"], o["id"], "strada")

func _treno(i: int, dest: Array, carrozza: bool) -> void:
	if dest.is_empty():
		_log("Nessuna destinazione raggiungibile in treno.")
		return
	# Indicazioni False: Dracula può annullare la Carrozza o decidere la destinazione
	if "indicazioni" in s["dr"]["ev"]:
		_chiedi(DRACULA, "indicazioni", "%s prende il treno. Giochi Indicazioni False?" % nome(i),
			[_o("si", "Sì: " + ("annulla la Carrozza Riservata" if carrozza else "decidi tu dove arriva")), _o("no", "No")],
			{"h": i, "dest": dest, "carrozza": carrozza})
		return
	_chiedi_treno(i, dest)

func _chiedi_treno(i: int, dest: Array, chi := -1) -> void:
	var opz := []
	for k in dest:
		opz.append(_o(k, Dati.nome(k), {"luogo": k}))
	opz.sort_custom(func(a, b): return a["testo"] < b["testo"])
	_chiedi(i if chi < 0 else chi, "dest_treno", "In treno: dove scende %s?" % nome(i), opz, {"h": i})

func _d_indicazioni(r: Dictionary, o: Dictionary) -> void:
	var i: int = r["h"]
	if o["id"] == "no":
		_chiedi_treno(i, r["dest"])
		return
	_togli(s["dr"]["ev"], "indicazioni")
	s["s_ev"].append({"id": "indicazioni", "coperta": false})
	_annuncia(DRACULA, "indicazioni")
	if r["carrozza"]:
		_log("La Carrozza Riservata è annullata: %s resta a %s." % [nome(i), Dati.nome(c(i)["pos"])])
		return
	_chiedi_treno(i, r["dest"], DRACULA)

func _d_dest_treno(r: Dictionary, o: Dictionary) -> void:
	var i: int = r["h"]
	_log("%s scende dal treno a %s." % [nome(i), Dati.nome(o["id"])])
	_muovi(i, o["id"], "treno")

## Spostamento con un'azione: controlla gli eventi di Dracula (Cavalli Impazziti, Ispezione Doganale).
func _muovi(i: int, dest: String, come: String) -> void:
	var da: String = c(i)["pos"]
	c(i)["pos"] = dest
	if come == "strada" and "cavalli_impazziti" in s["dr"]["ev"]:
		var opz := [_o("no", "No")]
		for n in Dati.strade(dest):
			opz.append(_o(n, "Sì: spostalo a " + Dati.nome(n), {"luogo": n}))
		_chiedi(DRACULA, "cavalli_impazziti", "%s arriva a %s su strada. Giochi Cavalli Impazziti?" % [nome(i), Dati.nome(dest)], opz, {"h": i, "da": da})
		return
	_dopo_movimento(i, da, come)

func _d_cavalli_impazziti(r: Dictionary, o: Dictionary) -> void:
	var i: int = r["h"]
	if o["id"] != "no":
		_togli(s["dr"]["ev"], "cavalli_impazziti")
		s["s_ev"].append({"id": "cavalli_impazziti", "coperta": false})
		_annuncia(DRACULA, "cavalli_impazziti")
		c(i)["pos"] = o["id"]
		_log("I cavalli impazziscono: %s finisce a %s." % [nome(i), Dati.nome(o["id"])])
	_dopo_movimento(i, r["da"], "strada")

func _dopo_movimento(i: int, da: String, _come: String) -> void:
	var dest: String = c(i)["pos"]
	if s["flag"].get("lunga_notte", false) and notte():
		_lunga_notte_pesca()
	if "dogana" in s["dr"]["ev"] and not Dati.mare(da) and not Dati.mare(dest) and Dati.regione(da) != Dati.regione(dest):
		_chiedi(DRACULA, "dogana", "%s passa da %s a %s. Giochi Ispezione Doganale?" % [nome(i), Dati.nome_regione(Dati.regione(da)), Dati.nome_regione(Dati.regione(dest))],
			[_o("si", "Sì"), _o("no", "No")], {"h": i})
	_arriva(i, dest, "mossa")

func _lunga_notte_pesca() -> void:
	if s["m_ev"].is_empty():
		return
	var e: String = s["m_ev"].pop_front()
	if Dati.EVENTI[e]["d"]:
		_log("Lunga Notte: Dracula pesca una carta Evento.")
		_dracula_riceve_evento(e)
	else:
		s["s_ev"].append({"id": e, "coperta": false})
		_log("Lunga Notte: scartata «%s»." % Dati.EVENTI[e]["nome"])

func _d_dogana(r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "no":
		return
	var i: int = r["h"]
	_togli(s["dr"]["ev"], "dogana")
	s["s_ev"].append({"id": "dogana", "coperta": false})
	_annuncia(DRACULA, "dogana")
	c(i)["trattenuto"] = true
	if c(i)["ogg"].is_empty():
		_danno(i, 3, "Ispezione Doganale")
	else:
		_chiedi(i, "dogana_scelta", "Ispezione Doganale: scarti tutti gli Oggetti o subisci 3 danni?",
			[_o("ogg", "Scarta tutti gli Oggetti (%d)" % c(i)["ogg"].size()), _o("danni", "Subisci 3 danni")], {"h": i})

func _d_dogana_scelta(r: Dictionary, o: Dictionary) -> void:
	var i: int = r["h"]
	if o["id"] == "ogg":
		for x in c(i)["ogg"].duplicate():
			_scarta_ogg(i, x)
		_log("%s consegna tutti i suoi Oggetti alla dogana." % nome(i))
	else:
		_danno(i, 3, "Ispezione Doganale")

## Un cacciatore arriva in un luogo: si rivela la carta e Dracula può tendere un'imboscata.
func _arriva(i: int, luogo: String, _come: String) -> void:
	if Dati.mare(luogo) or c(i)["osp"] != "" or c(i)["sconfitto"]:
		return
	_escludi_ovunque(luogo)
	var rif := nasc_di(luogo)
	if rif.is_empty():
		return
	var h := _h(rif)
	if not h["riv"]:
		h["riv"] = true
		_log("Rivelata la carta Luogo %s%s!" % [Dati.nome(luogo), " sul Percorso" if rif["dove"] == "p" else " in una tana"])
	var incs := _inc_imboscata(rif)
	if rif["dove"] == "p":
		var kn := _nascondersi_di(rif["k"])
		if kn >= 0 and not s["percorso"][kn]["riv_p"]:
			s["percorso"][kn]["riv_p"] = true
			_log("Era nascosto: rivelata anche la carta Nascondersi.")
	if not incs.is_empty():
		s["pila"].push_front({"f": "imboscata", "h": i, "luogo": luogo})

func _escludi_ovunque(luogo: String) -> void:
	# informazione pubblica: le carte coperte del Percorso non sono questo luogo
	for h in s["percorso"]:
		if not h["riv"] and not (luogo in h["esclusi"]):
			h["esclusi"].append(luogo)

## Gli incontri utilizzabili per un'imboscata nel nascondiglio (e nel Nascondersi associato).
func _inc_imboscata(rif: Dictionary) -> Array:
	var out := []
	var h := _h(rif)
	for k in h["inc"].size():
		if not Dati.INCONTRI[h["inc"][k]["id"]].get("no_imboscata", false):
			out.append({"dove": rif["dove"], "k": rif["k"], "e": k})
	if rif["dove"] == "p":
		var kn := _nascondersi_di(rif["k"])
		if kn >= 0:
			for k in s["percorso"][kn]["inc"].size():
				if not Dati.INCONTRI[s["percorso"][kn]["inc"][k]["id"]].get("no_imboscata", false):
					out.append({"dove": "p", "k": kn, "e": k})
	return out

func _p_imboscata(p: Dictionary) -> void:
	var i: int = p["h"]
	if not in_citta(i, p["luogo"]):
		return
	var rif := nasc_di(p["luogo"])
	if rif.is_empty():
		return
	var opz := []
	var usati: Array = p.get("usati", [])
	for x in _inc_imboscata(rif):
		var e: Dictionary = _h(x)["inc"][x["e"]]
		if str(e.get("uid", "")) in usati:
			continue
		opz.append(_o("%s:%d:%d" % [x["dove"], x["k"], x["e"]], "Imboscata con " + Dati.INCONTRI[e["id"]]["nome"], {"carta": e["id"]}))
	if opz.is_empty():
		return
	opz.append(_o("no", "Nessuna imboscata"))
	_chiedi(DRACULA, "imboscata", "%s è entrato a %s, dove c'è un tuo nascondiglio. Tendi un'imboscata?" % [nome(i), Dati.nome(p["luogo"])], opz, {"h": i, "luogo": p["luogo"], "usati": usati})

func _d_imboscata(r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "no":
		return
	var i: int = r["h"]
	var parti: PackedStringArray = o["id"].split(":")
	var h: Dictionary = s["percorso"][int(parti[1])] if parti[0] == "p" else s["tane"][int(parti[1])]
	var k := int(parti[2])
	var e: Dictionary = h["inc"][k]
	e["riv"] = true
	_log("IMBOSCATA! Dracula rivela «%s» contro %s." % [Dati.INCONTRI[e["id"]]["nome"], nome(i)])
	# dopo questa, Dracula può usarne altre
	s["pila"].push_front({"f": "imboscata", "h": i, "luogo": r["luogo"], "usati": r.get("usati", []) + [str(e.get("uid", ""))]})
	var vamp: bool = Dati.INCONTRI[e["id"]].get("vampiro", false)
	if not vamp and "avvertito" in c(i)["ev"]:
		_chiedi(i, "avvertito", "Imboscata con «%s»: giochi Avvertito in Tempo per scartarla senza effetti?" % Dati.INCONTRI[e["id"]]["nome"],
			[_o("si", "Sì, gioca Avvertito in Tempo"), _o("no", "No")], {"h": i, "rif": {"dove": parti[0], "k": int(parti[1])}, "e": k})
		return
	if e["id"] in ["ratti", "sabotatore", "spia", "lupi"] and ha_ogg(i, "cani"):
		_scarta_ogg(i, "cani")
		_log("I Cani di %s mettono in fuga «%s»: entrambe le carte sono scartate." % [nome(i), Dati.INCONTRI[e["id"]]["nome"]])
		_rimuovi_inc({"dove": parti[0], "k": int(parti[1])}, k)
		return
	_risolvi_incontro(i, {"dove": parti[0], "k": int(parti[1])}, k, true)

func _d_avvertito(r: Dictionary, o: Dictionary) -> void:
	var i: int = r["h"]
	if o["id"] == "si":
		_scarta_ev(i, "avvertito")
		_annuncia(i, "avvertito")
		_rimuovi_inc(r["rif"], r["e"])
		_log("Avvertito in tempo: l'incontro è scartato senza effetti.")
		return
	_risolvi_incontro(i, r["rif"], r["e"], true)

func _rimuovi_inc(rif: Dictionary, k: int) -> void:
	var h := _h(rif)
	if k < h["inc"].size():
		s["s_inc"].append(h["inc"][k]["id"])
		h["inc"].remove_at(k)
	if rif["dove"] == "t" and h["inc"].is_empty():
		_log("La tana di %s è vuota e viene sgomberata." % Dati.nome(h["luogo"]))
		_sgombera(h)
		s["tane"].remove_at(rif["k"])

# ---------- ricerca e incontri

func _ricerca(i: int) -> void:
	var pos: String = c(i)["pos"]
	var rif := nasc_di(pos)
	_escludi_ovunque(pos)
	if rif.is_empty():
		_log("%s cerca a %s ma non trova nulla." % [nome(i), Dati.nome(pos)])
		return
	var lista := []
	var h := _h(rif)
	for k in h["inc"].size():
		lista.append({"dove": rif["dove"], "k": rif["k"], "e": k})
	if rif["dove"] == "p":
		var kn := _nascondersi_di(rif["k"])
		if kn >= 0:
			for k in s["percorso"][kn]["inc"].size():
				lista.append({"dove": "p", "k": kn, "e": k})
	if lista.is_empty():
		_log("%s cerca a %s: c'è un nascondiglio di Dracula, ma è vuoto." % [nome(i), Dati.nome(pos)])
		return
	for x in lista:
		_h(x)["inc"][x["e"]]["riv"] = true
	_log("%s cerca a %s e scopre: %s." % [nome(i), Dati.nome(pos), ", ".join(lista.map(func(x): return Dati.INCONTRI[_h(x)["inc"][x["e"]]["id"]]["nome"]))])
	# Cani e Paletto di Frassino prima di risolvere
	for x in lista.duplicate():
		var id: String = _h(x)["inc"][x["e"]]["id"]
		if id in ["ratti", "sabotatore", "spia", "lupi"] and ha_ogg(i, "cani"):
			_log("I Cani di %s scacciano «%s»." % [nome(i), Dati.INCONTRI[id]["nome"]])
			_h(x)["inc"][x["e"]]["via"] = true
		elif (Dati.INCONTRI[id].get("vampiro", false) or id == "raggiro") and ha_ogg(i, "paletto"):
			_scarta_ogg(i, "paletto")
			_log("%s pianta il Paletto di Frassino: «%s» è distrutto." % [nome(i), Dati.INCONTRI[id]["nome"]])
			_h(x)["inc"][x["e"]]["via"] = true
	_pulisci_via(rif)
	rif = nasc_di(pos)
	if rif.is_empty():
		return
	var vampiro := false
	for x in _lista_inc(rif):
		if Dati.INCONTRI[_h(x)["inc"][x["e"]]["id"]].get("vampiro", false):
			vampiro = true
	if vampiro and "seduzione" in s["dr"]["ev"]:
		_chiedi(DRACULA, "seduzione", "%s cerca dove c'è un tuo vampiro. Giochi Seduzione?" % nome(i), [_o("si", "Sì: il cacciatore è morso"), _o("no", "No")], {"h": i, "rif": rif})
		return
	s["pila"].push_front({"f": "risolvi_ricerca", "h": i, "luogo": pos})

func _pulisci_via(rif: Dictionary) -> void:
	var tutti := [rif]
	if rif["dove"] == "p":
		var kn := _nascondersi_di(rif["k"])
		if kn >= 0:
			tutti.append({"dove": "p", "k": kn})
	for r in tutti:
		var h := _h(r)
		for k in range(h["inc"].size() - 1, -1, -1):
			if h["inc"][k].get("via", false):
				s["s_inc"].append(h["inc"][k]["id"])
				h["inc"].remove_at(k)
	if rif["dove"] == "t" and _h(rif)["inc"].is_empty():
		_sgombera(_h(rif))
		s["tane"].remove_at(rif["k"])

func _lista_inc(rif: Dictionary) -> Array:
	var lista := []
	if rif.is_empty():
		return lista
	var h := _h(rif)
	for k in h["inc"].size():
		lista.append({"dove": rif["dove"], "k": rif["k"], "e": k})
	if rif["dove"] == "p":
		var kn := _nascondersi_di(rif["k"])
		if kn >= 0:
			for k in s["percorso"][kn]["inc"].size():
				lista.append({"dove": "p", "k": kn, "e": k})
	return lista

func _d_seduzione(r: Dictionary, o: Dictionary) -> void:
	var i: int = r["h"]
	if o["id"] == "si":
		_togli(s["dr"]["ev"], "seduzione")
		s["s_ev"].append({"id": "seduzione", "coperta": false})
		_annuncia(DRACULA, "seduzione")
		for x in _lista_inc(nasc_di(c(i)["pos"])):
			var e: Dictionary = _h(x)["inc"][x["e"]]
			if Dati.INCONTRI[e["id"]].get("vampiro", false):
				_h(x)["inc"].remove_at(x["e"])
				s["dr"]["inc"].append(e["id"])
				_log("Seduzione: %s è morso e Dracula riprende il vampiro." % nome(i))
				_morso(i)
				break
		_pulisci_vuote()
		return
	s["pila"].push_front({"f": "risolvi_ricerca", "h": i, "luogo": c(i)["pos"]})

func _pulisci_vuote() -> void:
	for k in range(s["tane"].size() - 1, -1, -1):
		if s["tane"][k]["inc"].is_empty():
			_sgombera(s["tane"][k])
			s["tane"].remove_at(k)

## Risolve, uno alla volta, gli incontri scoperti con una ricerca (ancora presenti e non già risolti in questa ricerca).
func _p_risolvi_ricerca(p: Dictionary) -> void:
	var i: int = p["h"]
	if not in_citta(i, p["luogo"]):
		return
	var rif := nasc_di(p["luogo"])
	var fatti: Array = p.get("fatti", [])
	for x in _lista_inc(rif):
		var e: Dictionary = _h(x)["inc"][x["e"]]
		var chiave := str(e.get("uid", ""))
		if chiave == "":
			e["uid"] = "%d_%d" % [s["passo"], rng.randi() % 100000]
			chiave = e["uid"]
		if chiave in fatti:
			continue
		fatti.append(chiave)
		p["fatti"] = fatti
		s["pila"].push_front(p)
		_risolvi_incontro(i, {"dove": x["dove"], "k": x["k"]}, x["e"], false)
		return

## Risolve l'effetto di un incontro contro il cacciatore i. imboscata = true se l'ha giocato Dracula.
func _risolvi_incontro(i: int, rif: Dictionary, k: int, imboscata: bool) -> void:
	var h := _h(rif)
	if k >= h["inc"].size():
		return
	var e: Dictionary = h["inc"][k]
	var id: String = e["id"]
	var resta := false
	var luogo: String = c(i)["pos"]
	match id:
		"szgany":
			_szgany_in(luogo)
		"raggiro":
			c(i)["trattenuto"] = true
			_log("Era un Raggiro: %s perde tempo ed è trattenuto." % nome(i))
		"temerario", "nuovo":
			_inizia_comb_vampiro(i, rif, k, imboscata)
			return
		"lupi":
			_lupi_in(luogo)
		"aristocratico":
			if imboscata:
				resta = true
			else:
				_chiedi(i, "aristocratico", "Un Vampiro Aristocratico dorme qui. Per distruggerlo devi restare trattenuto.", [_o("si", "Distruggilo (resti trattenuto)"), _o("no", "Lascialo")], {"rif": rif, "kk": k})
				return
		"guardie":
			_danno(i, 2, "Guardie del Corpo Szgany")
			if armi(i) == 0:
				_danno(i, 2, "Guardie del Corpo Szgany")
				c(i)["trattenuto"] = true
			else:
				_log("%s mostra un'arma: le guardie arretrano." % nome(i))
		"sconsacrato":
			for n in 3:
				if not s["m_inc"].is_empty():
					s["dr"]["inc"].append(s["m_inc"].pop_back())
			s["pila"].push_front({"f": "sconsacrato_scarta"})
			if ha_ogg(i, "ostia"):
				_log("%s purifica il Terreno Sconsacrato con l'Ostia." % nome(i))
			else:
				resta = true
		"nebbia":
			var n := 2 if Dati.porto(luogo) else 1
			s["nebbia"][luogo] = int(s["nebbia"].get(luogo, 0)) + n
			_log("Una Nebbia Innaturale avvolge %s." % Dati.nome(luogo))
			if not notte():
				for j in cacciatori_in(luogo):
					c(j)["trattenuto"] = true
		"ratti":
			_danno(i, 2, "Ratti")
			resta = not (ha_ogg(i, "pistola") or ha_ogg(i, "fucile"))
		"sabotatore":
			c(i)["trattenuto"] = true
			_log("Un Sabotatore trattiene %s." % nome(i))
			resta = not (ha_ogg(i, "pistola") or ha_ogg(i, "fucile"))
		"spia":
			if armi(i) > 0:
				_chiedi(i, "spia", "Una Spia: scarti un'Arma per evitarla?", [_o("si", "Sì, scarta un'Arma"), _o("no", "No: riveli le carte e scarti i biglietti")], {"h": i})
			else:
				_spia(i)
		"pipistrelli":
			c(i)["pipistrelli"] = true
			_log("Pipistrelli: un segnalino sotto %s." % nome(i))
	if resta:
		e["riv"] = true
		_log("«%s» resta scoperto nel nascondiglio." % Dati.INCONTRI[id]["nome"])
	else:
		_rimuovi_inc(rif, k)

func _d_aristocratico(r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "si":
		c(r["g"])["trattenuto"] = true
		_log("%s distrugge il Vampiro Aristocratico nella sua bara, ma perde tempo." % nome(r["g"]))
		_rimuovi_inc(r["rif"], r["kk"])
	else:
		_log("Il Vampiro Aristocratico resta nella sua bara.")

func _d_spia(r: Dictionary, o: Dictionary) -> void:
	var i: int = r["h"]
	if o["id"] == "si":
		for x in c(i)["ogg"]:
			if Dati.OGGETTI[x].get("arma", false):
				_scarta_ogg(i, x)
				_log("%s sacrifica %s per liberarsi della Spia." % [nome(i), Dati.OGGETTI[x]["nome"]])
				return
	_spia(i)

func _spia(i: int) -> void:
	var t := ", ".join(c(i)["ogg"].map(func(x): return Dati.OGGETTI[x]["nome"]) + c(i)["ev"].map(func(x): return Dati.EVENTI[x]["nome"]))
	_log("La Spia vede le carte di %s: %s." % [nome(i), t if t != "" else "nessuna"])
	for b in c(i)["big"]:
		s["riserva_big"].append(b)
	if not c(i)["big"].is_empty():
		_mescola(s["riserva_big"])
		_log("%s perde i suoi biglietti." % nome(i))
	c(i)["big"] = []

func _szgany_in(luogo: String) -> void:
	for j in cacciatori_in(luogo):
		var n: int = c(j)["ogg"].size()
		if n > 0:
			# il cacciatore tiene armi e oggetti preziosi se ha vita da spendere
			var tiene := []
			var margine := vita(j) - int(c(j)["danni"]) - 3
			for o in c(j)["ogg"].duplicate():
				if margine > 0 and (Dati.OGGETTI[o].get("arma", false) or o in ["crocifisso", "cerchio", "ostia"]):
					tiene.append(o)
					margine -= 1
				else:
					_scarta_ogg(j, o)
			if tiene.size() < n:
				_log("%s getta %d oggetti alla Banda di Szgany." % [nome(j), n - tiene.size()])
			if tiene.size() > 0:
				_danno(j, tiene.size(), "Banda di Szgany")

func _lupi_in(luogo: String) -> void:
	for j in cacciatori_in(luogo):
		var d: int = max(0, 4 - 2 * armi(j))
		if d > 0:
			_danno(j, d, "Lupi")
		else:
			_log("%s tiene a bada i lupi con le sue armi." % nome(j))

func _p_sconsacrato_scarta(_p: Dictionary) -> void:
	var opz := [_o("fine", "Basta così")]
	for k in s["dr"]["inc"].size():
		var id: String = s["dr"]["inc"][k]
		if not opz.any(func(x): return x.get("carta", "") == id):
			opz.append(_o(id, "Scarta " + Dati.INCONTRI[id]["nome"], {"carta": id}))
	var n := int(s["flag"].get("sconsacrato_n", 0))
	if n >= 3 or s["dr"]["inc"].size() <= 5:
		s["flag"].erase("sconsacrato_n")
		return
	_chiedi(DRACULA, "sconsacrato", "Terreno Sconsacrato: puoi scartare fino a %d carte Incontro." % (3 - n), opz)

func _d_sconsacrato(_r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "fine":
		s["flag"].erase("sconsacrato_n")
		return
	_togli(s["dr"]["inc"], o["id"])
	s["s_inc"].append(o["id"])
	s["flag"]["sconsacrato_n"] = int(s["flag"].get("sconsacrato_n", 0)) + 1
	s["pila"].push_front({"f": "sconsacrato_scarta"})

# ---------- danni, morsi, sconfitte

func _danno(i: int, n: int, fonte: String) -> void:
	if n <= 0 or c(i)["sconfitto"]:
		return
	var h := c(i)
	if int(h["danni"]) + n >= vita(i):
		var salva := _salvataggio(i, "danno")
		if salva != "":
			_log("%s: %s evita il danno di %s." % [nome(i), salva, fonte])
			return
	h["danni"] = int(h["danni"]) + n
	_log("%s subisce %d dann%s (%s). [%d/%d]" % [nome(i), n, "o" if n == 1 else "i", fonte, h["danni"], vita(i)])
	if int(h["danni"]) >= vita(i):
		_sconfitto(i)

func _morso(i: int) -> void:
	var h := c(i)
	if int(h["morsi"]) + 1 > int(Dati.CACCIATORI[i]["morsi"]) or i == 3:
		var salva := _salvataggio(i, "morso")
		if salva != "":
			_log("%s: %s evita il morso." % [nome(i), salva])
			return
	h["morsi"] = int(h["morsi"]) + 1
	_log("%s è stato MORSO da Dracula!" % nome(i))
	if int(h["morsi"]) > int(Dati.CACCIATORI[i]["morsi"]) or (i == 3 and int(h["morsi"]) >= 2):
		_sconfitto(i)

## Grande Forza (qualsiasi cacciatore) o la Vendetta di Lucy (Godalming in combattimento) evitano la sconfitta.
## Le giocano in automatico: perdere un cacciatore è sempre peggio.
func _salvataggio(i: int, _tipo: String) -> String:
	if i == 0 and s["comb"].get("lucy", -1) == 0:
		s["comb"]["lucy"] = -1
		s["s_ev"].append({"id": "lucy", "coperta": false})
		return "La Vendetta di Lucy"
	for j in 4:
		if "grande_forza" in c(j)["ev"] and not c(j)["sconfitto"]:
			_scarta_ev(j, "grande_forza")
			_annuncia(j, "grande_forza")
			return "Grande Forza"
	return ""

func _sconfitto(i: int) -> void:
	var h := c(i)
	h["sconfitto"] = true
	h["sconfitto_in"] = h["pos"] if h["osp"] == "" else h["osp"]
	h["trattenuto"] = false
	var inf := 2 + int(s["disperazione"])
	s["influenza"] = int(s["influenza"]) + inf
	_log("%s è SCONFITTO! L'Influenza di Dracula sale di %d (Rabbia)." % [nome(i), inf])
	if not s["comb"].is_empty():
		s["comb"]["cacc"].erase(i)

# ---------- biglietti, rifornimento, scambi

func _prenota(i: int) -> void:
	var n := 2 if i == 0 else 1
	for k in n:
		if s["riserva_big"].is_empty():
			break
		var b: Array = s["riserva_big"].pop_front()
		if c(i)["big"].size() >= 2:
			c(i)["big"].append(b)
			_chiedi(i, "scarta_big", "Puoi tenere solo 2 biglietti: quale scarti?", _opz_big(i), {"h": i})
		else:
			c(i)["big"].append(b)
	_log("%s prenota %s." % [nome(i), "due biglietti" if n == 2 else "un biglietto"])

func _opz_big(i: int) -> Array:
	var out := []
	for k in c(i)["big"].size():
		out.append(_o(k, "Scarta il biglietto " + _desc_big(c(i)["big"][k])))
	return out

func _d_scarta_big(r: Dictionary, o: Dictionary) -> void:
	var i: int = r["h"]
	var b: Array = c(i)["big"][int(o["id"])]
	c(i)["big"].remove_at(int(o["id"]))
	s["riserva_big"].append(b)
	_mescola(s["riserva_big"])

func _rifornimento(i: int, nt: bool) -> void:
	var h := c(i)
	if h["osp"] != "":
		_pesca_ogg(i)
		_log("%s si rifornisce all'ospedale: 1 Oggetto." % nome(i))
		return
	if Dati.L(h["pos"])["grande"]:
		for k in (2 if i == 0 else 1):
			_pesca_ogg(i)
	if s["m_ev"].is_empty():
		_rimescola_eventi()
	if s["m_ev"].is_empty():
		return
	if nt:
		var e: String = s["m_ev"].pop_front()
		if Dati.EVENTI[e]["d"]:
			_log("%s si rifornisce di notte: la carta in fondo al mazzo va a Dracula." % nome(i))
			_dracula_riceve_evento(e)
		else:
			_log("%s si rifornisce di notte e pesca un Evento." % nome(i))
			_cacciatore_riceve_evento(i, e)
	else:
		var e: String = s["m_ev"].pop_back()
		if Dati.EVENTI[e]["d"]:
			s["s_ev"].append({"id": e, "coperta": true})
			_log("%s si rifornisce: la carta in cima era di Dracula ed è scartata coperta." % nome(i))
		else:
			_log("%s si rifornisce e pesca un Evento." % nome(i))
			_cacciatore_riceve_evento(i, e)

func _rimescola_eventi() -> void:
	for x in s["s_ev"]:
		s["m_ev"].append(x["id"])
	s["s_ev"] = []
	_mescola(s["m_ev"])
	_log("Il mazzo Eventi viene rimescolato.")

func _pesca_ogg(i: int) -> void:
	if s["m_ogg"].is_empty():
		s["m_ogg"] = s["s_ogg"]
		s["s_ogg"] = []
		_mescola(s["m_ogg"])
	if s["m_ogg"].is_empty():
		return
	c(i)["ogg"].append(s["m_ogg"].pop_back())
	if c(i)["ogg"].size() > max_ogg(i):
		s["pila"].push_front({"f": "limite_ogg", "h": i})

func _p_limite_ogg(p: Dictionary) -> void:
	var i: int = p["h"]
	if c(i)["ogg"].size() <= max_ogg(i):
		return
	var opz := []
	for o in c(i)["ogg"]:
		if not opz.any(func(x): return x["id"] == o):
			opz.append(_o(o, "Scarta " + Dati.OGGETTI[o]["nome"], {"carta": o}))
	_chiedi(i, "limite_ogg", "%s ha troppi Oggetti (massimo %d): quale scarta?" % [nome(i), max_ogg(i)], opz, {"h": i})

func _d_limite_ogg(r: Dictionary, o: Dictionary) -> void:
	_scarta_ogg(r["h"], o["id"])
	s["pila"].push_front({"f": "limite_ogg", "h": r["h"]})

func _cacciatore_riceve_evento(i: int, e: String) -> void:
	var q: String = Dati.EVENTI[e]["quando"]
	if q == "subito" or (q == "subito_o_alba"):
		s["pila"].push_front({"f": "evento_subito", "h": i, "e": e})
		return
	c(i)["ev"].append(e)
	if c(i)["ev"].size() > max_ev(i):
		s["pila"].push_front({"f": "limite_ev", "h": i})

func _p_limite_ev(p: Dictionary) -> void:
	var i: int = p["h"]
	if c(i)["ev"].size() <= max_ev(i):
		return
	var opz := []
	for e in c(i)["ev"]:
		if not opz.any(func(x): return x["id"] == e):
			opz.append(_o(e, "Scarta " + Dati.EVENTI[e]["nome"], {"carta": e}))
	_chiedi(i, "limite_ev", "%s ha troppe carte Evento (massimo %d): quale scarta?" % [nome(i), max_ev(i)], opz, {"h": i})

func _d_limite_ev(r: Dictionary, o: Dictionary) -> void:
	_scarta_ev(r["h"], o["id"])
	s["pila"].push_front({"f": "limite_ev", "h": r["h"]})

func _scambio(i: int, j: int, leader: bool) -> void:
	_log("%s %s con %s." % [nome(i), "usa Leader per scambiare carte Evento" if leader else "fa uno scambio", nome(j)])
	s["pila"].push_front({"f": "scambio", "a": i, "b": j, "leader": leader, "n": 0})

func _p_scambio(p: Dictionary) -> void:
	var a: int = p["a"]
	var b: int = p["b"]
	if int(p["n"]) > 12:
		return
	var opz := [_o("fine", "Fine dello scambio")]
	if p["leader"]:
		for e in c(a)["ev"]:
			opz.append(_o("ea:" + e, "Dai %s a %s" % [Dati.EVENTI[e]["nome"], nome(b)], {"carta": e}))
		for e in c(b)["ev"]:
			opz.append(_o("eb:" + e, "Prendi %s da %s" % [Dati.EVENTI[e]["nome"], nome(b)], {"carta": e}))
	else:
		for o in c(a)["ogg"]:
			opz.append(_o("oa:" + o, "Dai %s a %s" % [Dati.OGGETTI[o]["nome"], nome(b)], {"carta": o}))
		for o in c(b)["ogg"]:
			opz.append(_o("ob:" + o, "Prendi %s da %s" % [Dati.OGGETTI[o]["nome"], nome(b)], {"carta": o}))
		for k in c(a)["big"].size():
			opz.append(_o("ba:%d" % k, "Dai il biglietto %s" % _desc_big(c(a)["big"][k])))
		for k in c(b)["big"].size():
			opz.append(_o("bb:%d" % k, "Prendi il biglietto %s" % _desc_big(c(b)["big"][k])))
	var dup := {}
	var uniche := []
	for x in opz:
		if not dup.has(x["id"]):
			dup[x["id"]] = true
			uniche.append(x)
	_chiedi(a, "scambio", "Scambio fra %s e %s." % [nome(a), nome(b)], uniche, {"p": p})

func _d_scambio(r: Dictionary, o: Dictionary) -> void:
	var p: Dictionary = r["p"].duplicate(true)
	if o["id"] == "fine":
		for x in [p["a"], p["b"]]:
			if c(x)["ogg"].size() > max_ogg(x):
				s["pila"].push_front({"f": "limite_ogg", "h": x})
			if c(x)["ev"].size() > max_ev(x):
				s["pila"].push_front({"f": "limite_ev", "h": x})
			while c(x)["big"].size() > 2:
				s["riserva_big"].append(c(x)["big"].pop_back())
		return
	var t: String = o["id"].get_slice(":", 0)
	var v: String = o["id"].get_slice(":", 1)
	var a := c(p["a"])
	var b := c(p["b"])
	match t:
		"oa":
			_togli(a["ogg"], v)
			b["ogg"].append(v)
		"ob":
			_togli(b["ogg"], v)
			a["ogg"].append(v)
		"ea":
			_togli(a["ev"], v)
			b["ev"].append(v)
		"eb":
			_togli(b["ev"], v)
			a["ev"].append(v)
		"ba":
			b["big"].append(a["big"][int(v)])
			a["big"].remove_at(int(v))
		"bb":
			a["big"].append(b["big"][int(v)])
			b["big"].remove_at(int(v))
	p["n"] = int(p["n"]) + 1
	s["pila"].push_front(p)

# ---------- eventi dei cacciatori

func _p_evento_subito(p: Dictionary) -> void:
	var i: int = p["h"]
	var e: String = p["e"]
	var d: Dictionary = Dati.EVENTI[e]
	if d["quando"] == "subito_o_alba":
		_chiedi(i, "giornali", "Hai pescato Notizie dai Giornali.", [_o("subito", "Giocala subito: rivela il luogo sul 3° spazio"), _o("tieni", "Tienila per l'alba o il tramonto (5° o 6° spazio)")], {"h": i})
		return
	if d.get("alleato", false):
		_chiedi(i, "subito_alleato", "Hai pescato %s: si gioca subito." % d["nome"], [_o("effetto", "Cercare un luogo: Dracula rivela la carta di una città"), _o("alleato", "Giocala come alleato dei cacciatori")], {"h": i, "e": e})
		return
	_scarta_stampa(i, e)

## Prima di risolvere un evento «Subito» che rivela informazioni, Dracula può annullarlo con Stampa Sensazionalista.
func _scarta_stampa(i: int, e: String) -> void:
	s["s_ev"].append({"id": e, "coperta": false})
	_annuncia(i, e)
	if e in ["voci", "esploratori", "giornali", "presenza"] and "stampa" in s["dr"]["ev"]:
		_chiedi(DRACULA, "stampa", "%s gioca %s. Lo annulli con Stampa Sensazionalista?" % [nome(i), Dati.EVENTI[e]["nome"]], [_o("si", "Sì, annullalo"), _o("no", "No")], {"h": i, "e": e})
		return
	_effetto_subito(i, e)

func _d_stampa(r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "si":
		_togli(s["dr"]["ev"], "stampa")
		s["s_ev"].append({"id": "stampa", "coperta": false})
		_annuncia(DRACULA, "stampa")
		_log("La Stampa Sensazionalista confonde le acque: l'evento è annullato.")
		return
	_effetto_subito(r["h"], r["e"])

func _effetto_subito(i: int, e: String) -> void:
	match e:
		"giornali":
			_effetto_giornali(i, true)
		"esploratori":
			_chiedi(i, "rivela_citta", "Esploratori: scegli la prima città da far rivelare.", _opz_citta_tutte(), {"h": i, "resta": 1})
		"presenza":
			var dr := pos_dracula()
			var vicini := []
			for j in 4:
				if attivo(j) and _adiacente(dr, c(j)["pos"]):
					vicini.append(nome(j))
			_log("Presenza Malvagia: cacciatori adiacenti a Dracula: %s." % (", ".join(vicini) if not vicini.is_empty() else "nessuno"))
			s["flag"]["presenza"] = {"chi": vicini, "passo": s["passo"]}
		"voci":
			var dr := pos_dracula()
			var n := 0
			for h in s["percorso"] + s["tane"]:
				if h["luogo"] != "" and not h["riv"] and _adiacente(dr, h["luogo"]):
					h["riv"] = true
					n += 1
					_log("Voci del Luogo: rivelato %s." % Dati.nome(h["luogo"]))
			if n == 0:
				_log("Voci del Luogo: nessun nascondiglio adiacente da rivelare.")
		"velo":
			var t := ", ".join(s["dr"]["ev"].map(func(x): return Dati.EVENTI[x]["nome"]))
			_log("Dietro il Velo: Dracula ha in mano gli Eventi: %s." % (t if t != "" else "nessuno"))
			var opz := []
			for x in s["dr"]["inc"]:
				if not opz.any(func(y): return y["id"] == x):
					opz.append(_o(x, "Scarta " + Dati.INCONTRI[x]["nome"], {"carta": x}))
			_log("Dietro il Velo: Incontri in mano a Dracula: %s." % ", ".join(s["dr"]["inc"].map(func(x): return Dati.INCONTRI[x]["nome"])))
			if not opz.is_empty():
				_chiedi(i, "velo", "Dietro il Velo: quale Incontro di Dracula scarti?", opz)

func _d_velo(_r: Dictionary, o: Dictionary) -> void:
	_togli(s["dr"]["inc"], o["id"])
	s["s_inc"].append(o["id"])
	_log("Scartato «%s» dalla mano di Dracula." % Dati.INCONTRI[o["id"]]["nome"])

func _adiacente(a: String, b: String) -> bool:
	if a == b or a == "" or b == "":
		return false
	return b in Dati.strade(a) or b in Dati.L(a)["porti"]

func _opz_citta_tutte() -> Array:
	var out := []
	for k in Dati.luoghi():
		out.append(_o(k, Dati.nome(k), {"luogo": k}))
	out.sort_custom(func(a, b): return a["testo"] < b["testo"])
	return out

func _d_rivela_citta(r: Dictionary, o: Dictionary) -> void:
	_rivela_luogo(o["id"])
	if int(r.get("resta", 0)) > 0:
		_chiedi(r["h"], "rivela_citta", "Esploratori: scegli la seconda città.", _opz_citta_tutte(), {"h": r["h"], "resta": 0})

func _rivela_luogo(luogo: String) -> void:
	_escludi_ovunque(luogo)
	var rif := nasc_di(luogo)
	if rif.is_empty():
		_log("%s: nessuna carta di Dracula." % Dati.nome(luogo))
		return
	_h(rif)["riv"] = true
	_log("Rivelato: Dracula è passato da %s%s!" % [Dati.nome(luogo), " (è una sua tana)" if rif["dove"] == "t" else " (spazio %d del Percorso)" % (rif["k"] + 1)])

func _effetto_giornali(_i: int, subito: bool) -> void:
	if subito:
		_rivela_spazio(2)
	else:
		if s["percorso"].size() >= 6:
			_rivela_spazio(5)
		_rivela_spazio(4)

func _rivela_spazio(k: int) -> void:
	if k >= s["percorso"].size():
		_log("Notizie dai Giornali: lo spazio %d del Percorso è vuoto." % (k + 1))
		return
	var h: Dictionary = s["percorso"][k]
	if h["luogo"] == "":
		_log("Notizie dai Giornali: sullo spazio %d c'è una carta Potere." % (k + 1))
		if h["potere"] == "nascondersi":
			h["riv_p"] = true
		return
	h["riv"] = true
	_log("Notizie dai Giornali: sullo spazio %d c'è %s." % [k + 1, Dati.nome(h["luogo"])])

func _d_giornali(r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "subito":
		_scarta_stampa(r["h"], "giornali")
	else:
		c(r["h"])["ev"].append("giornali")
		if c(r["h"])["ev"].size() > max_ev(r["h"]):
			s["pila"].push_front({"f": "limite_ev", "h": r["h"]})

func _d_subito_alleato(r: Dictionary, o: Dictionary) -> void:
	var i: int = r["h"]
	var e: String = r["e"]
	if o["id"] == "alleato":
		_annuncia(i, e)
		_gioca_alleato_c(i, e)
		return
	s["s_ev"].append({"id": e, "coperta": false})
	_annuncia(i, e)
	_chiedi(i, "rivela_citta", "%s: quale città deve rivelare Dracula?" % Dati.EVENTI[e]["nome"], _opz_citta_tutte(), {"h": i, "resta": 0})

func _evento_libero(i: int, e: String, r: Dictionary) -> void:
	_scarta_ev(i, e)
	_annuncia(i, e)
	if e == "buona_fortuna":
		var opz := []
		if s["dr"]["alleato"] != "":
			opz.append(_o("alleato", "Scarta l'alleato di Dracula (%s)" % Dati.EVENTI[s["dr"]["alleato"]]["nome"]))
		for k in s["blocchi"].size():
			var b: Array = s["blocchi"][k]
			opz.append(_o("blocco:%d" % k, "Rimuovi il blocco %s–%s" % [Dati.nome(b[0]), Dati.nome(b[1])]))
		if not opz.is_empty():
			_chiedi(i, "buona_fortuna", "Buona Fortuna: cosa fai?", opz)
	# l'evento libero non consuma l'azione: si richiede di nuovo
	s["pila"].push_front({"f": "azione", "h": i, "notte": r.get("notte", false), "giro": r.get("giro", 0)})

func _d_buona_fortuna(_r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "alleato":
		_log("Buona Fortuna: scartato l'alleato di Dracula.")
		s["s_ev"].append({"id": s["dr"]["alleato"], "coperta": false})
		s["dr"]["alleato"] = ""
	else:
		var b = s["blocchi"][int(o["id"].get_slice(":", 1))]
		s["blocchi"].erase(b)
		_log("Buona Fortuna: riaperta la via %s–%s." % [Dati.nome(b[0]), Dati.nome(b[1])])

func _evento_azione(i: int, e: String, nt: bool) -> void:
	_scarta_ev(i, e)
	_annuncia(i, e)
	match e:
		"cilindri":
			var opz := [_o("analisi", "Analisi: Dracula rivela dove ha giocato Nascondersi")]
			for k in s["percorso"].size():
				var h: Dictionary = s["percorso"][k]
				if not h["inc"].is_empty():
					opz.append(_o("ded:%d" % k, "Deduzione: rivela gli incontri dello spazio %d" % (k + 1)))
			_chiedi(i, "cilindri", "Cilindri di Cera: cosa fai?", opz, {"h": i})
		"ricerca_mistica":
			var n := 0
			var tenute := []
			for k in min(6, s["m_ev"].size()):
				var x: String = s["m_ev"][k]
				if Dati.EVENTI[x]["d"]:
					n += 1
					s["s_ev"].append({"id": x, "coperta": true})
				else:
					tenute.append(x)
			for k in min(6, s["m_ev"].size()):
				s["m_ev"].pop_front()
			for k in range(tenute.size() - 1, -1, -1):
				s["m_ev"].push_front(tenute[k])
			_log("Ricerca Mistica: scartate %d carte di Dracula dal fondo del mazzo Eventi." % n)
		"senso":
			_danno(i, 2, "Senso di Emergenza")
			if c(i)["sconfitto"]:
				return
			var dd := Dati.distanze_strada(c(i)["pos"], 3)
			var opz := []
			for k in dd:
				if k != c(i)["pos"] and not s["nebbia"].has(k):
					opz.append(_o(k, Dati.nome(k), {"luogo": k}))
			opz.sort_custom(func(a, b): return a["testo"] < b["testo"])
			if not opz.is_empty():
				_chiedi(i, "senso", "Senso di Emergenza: dove corri?", opz, {"h": i})
		"tempo_sereno":
			s["pila"].push_front({"f": "navigazione", "h": i, "resta": 2})
		"denaro":
			var n := 0
			for h in s["percorso"]:
				if h["luogo"] != "" and Dati.mare(h["luogo"]) and not h["riv"]:
					h["riv"] = true
					n += 1
			_log("Tracce di Denaro: rivelate %d carte di mare del Percorso." % n)
		"tana":
			_scarta_ogg(i, "paletto")
			c(i)["trattenuto"] = true
			s["influenza"] = max(0, int(s["influenza"]) - 2)
			_log("Tana del Vampiro: l'Influenza di Dracula scende di 2.")
		"trasfusione":
			var opz := []
			for j in 4:
				if j != i and in_citta(j, c(i)["pos"]) and indebolito(j):
					opz.append(_o(j, nome(j)))
			_chiedi(i, "trasfusione", "Trasfusione: chi curi?", opz, {"h": i})
		"terreno":
			_chiedi(i, "terreno", "Terreno Consacrato: su quale città?", _opz_consacrabili([]), {"h": i, "schiera": false})
		"ipnosi":
			_log("Ipnosi: Dracula è in %s." % (Dati.nome_regione(_regione_dracula()) if _regione_dracula() > 0 else "mare"))
			s["flag"]["regione_nota"] = {"r": _regione_dracula(), "passo": s["passo"]}
			c(i)["trattenuto"] = true
	if nt:
		pass

func _opz_consacrabili(esclusi: Array) -> Array:
	var out := []
	for k in Dati.citta():
		if k in ["castello", "galati", "klausenburg"] or k in esclusi or k in s["consacrato"] or k in s["schiera"]:
			continue
		out.append(_o(k, Dati.nome(k), {"luogo": k}))
	out.sort_custom(func(a, b): return a["testo"] < b["testo"])
	return out

func _d_terreno(r: Dictionary, o: Dictionary) -> void:
	var i: int = r["h"]
	if r["schiera"]:
		if o["id"] == "no":
			return
		_scarta_ogg(i, "ostia")
		s["schiera"].append(o["id"])
		s["flag"]["schiera_nuova"] = true
		_log("La Schiera Celeste protegge %s fino alla prossima alba." % Dati.nome(o["id"]))
		return
	s["consacrato"].append(o["id"])
	_log("%s consacra il terreno di %s: Dracula non vi può entrare." % [nome(i), Dati.nome(o["id"])])
	if ha_ogg(i, "ostia"):
		var opz := [_o("no", "No, tieni l'Ostia")]
		opz.append_array(_opz_consacrabili([o["id"]]))
		_chiedi(i, "terreno", "Scarti un'Ostia Consacrata per la Schiera Celeste su un'altra città?", opz, {"h": i, "schiera": true})

func _d_trasfusione(r: Dictionary, o: Dictionary) -> void:
	var j := int(o["id"])
	if int(c(j)["morsi"]) > (1 if j == 3 else 0):
		c(j)["morsi"] = int(c(j)["morsi"]) - 1
	_log("Trasfusione: %s perde un Morso." % nome(j))
	_danno(r["h"], 1, "Trasfusione")

func _d_senso(r: Dictionary, o: Dictionary) -> void:
	var i: int = r["h"]
	var da: String = c(i)["pos"]
	c(i)["pos"] = o["id"]
	_log("%s corre fino a %s." % [nome(i), Dati.nome(o["id"])])
	_dopo_movimento(i, da, "strada")

func _p_navigazione(p: Dictionary) -> void:
	var i: int = p["h"]
	if int(p["resta"]) <= 0 or c(i)["sconfitto"]:
		return
	var opz := _opz_mare(i)
	if opz.is_empty():
		return
	if int(p["resta"]) == 1 and not Dati.mare(c(i)["pos"]):
		opz.append(_o("fermo", "Resta qui"))
	_chiedi(i, "navigazione", "Tempo Sereno: dove navighi?", opz, {"h": i, "resta": int(p["resta"]) - 1})

func _d_navigazione(r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "fermo":
		return
	var i: int = r["h"]
	c(i)["pos"] = o["id"].get_slice(":", 1)
	_log("%s naviga verso %s." % [nome(i), Dati.nome(c(i)["pos"])])
	_arriva(i, c(i)["pos"], "mare")
	s["pila"].push_front({"f": "navigazione", "h": i, "resta": r["resta"]})

func _d_cilindri(r: Dictionary, o: Dictionary) -> void:
	var i: int = r["h"]
	if o["id"] == "analisi":
		var trovato := false
		for k in s["percorso"].size():
			if s["percorso"][k]["potere"] == "nascondersi":
				s["percorso"][k]["riv_p"] = true
				_log("Analisi: Dracula ha giocato Nascondersi sullo spazio %d." % (k + 1))
				trovato = true
		if not trovato:
			_log("Analisi: Nascondersi non è sul Percorso.")
	else:
		var k := int(o["id"].get_slice(":", 1))
		for e in s["percorso"][k]["inc"]:
			e["riv"] = true
		_log("Deduzione: sullo spazio %d ci sono %s." % [k + 1, ", ".join(s["percorso"][k]["inc"].map(func(x): return Dati.INCONTRI[x["id"]]["nome"]))])
	# la carta torna in mano
	_togli_scarti_ev("cilindri")
	c(i)["ev"].append("cilindri")

func _togli_scarti_ev(e: String) -> void:
	for k in range(s["s_ev"].size() - 1, -1, -1):
		if s["s_ev"][k]["id"] == e:
			s["s_ev"].remove_at(k)
			return

# ============================================================ combattimento con Dracula all'alba e al tramonto

func _p_combattimento_dracula(_p: Dictionary) -> void:
	var dr := pos_dracula()
	if dr == "" or Dati.mare(dr):
		return
	var qui := cacciatori_in(dr)
	if qui.is_empty():
		return
	var rif := nasc_di(dr)
	if not rif.is_empty() and not _h(rif)["riv"]:
		_h(rif)["riv"] = true
		_log("Dracula è scoperto a %s!" % Dati.nome(dr))
	if s["nebbia"].has(dr):
		_chiedi(DRACULA, "nebbia_comb", "C'è nebbia a %s: vuoi evitare il combattimento?" % Dati.nome(dr), [_o("evita", "Sì, scivola via nella nebbia"), _o("combatti", "No, combatti")])
		return
	_prima_del_comb_dracula(dr)

func _d_nebbia_comb(_r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "evita":
		_log("Dracula si dilegua nella nebbia senza combattere.")
		return
	_prima_del_comb_dracula(pos_dracula())

func _prima_del_comb_dracula(dr: String) -> void:
	_push([{"f": "guardie", "luogo": dr}, {"f": "comb_inizio", "tipo": "dracula", "luogo": dr}])

func _p_guardie(p: Dictionary) -> void:
	if int(s["dr"]["guardie"]) <= 0:
		return
	var qui := cacciatori_in(p["luogo"])
	if qui.is_empty():
		return
	var opz := [_o("no", "Non usarle ora")]
	for j in qui:
		opz.append(_o(j, "Contro " + nome(j)))
	_chiedi(DRACULA, "guardie", "Usi le Guardie del Corpo Szgany prima del combattimento?", opz)

func _d_guardie(_r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "no":
		return
	var j := int(o["id"])
	s["dr"]["guardie"] = int(s["dr"]["guardie"]) - 1
	s["s_inc"].append("guardie")
	_log("Le Guardie del Corpo Szgany aggrediscono %s." % nome(j))
	_danno(j, 2, "Guardie del Corpo Szgany")
	if armi(j) == 0:
		_danno(j, 2, "Guardie del Corpo Szgany")
		c(j)["trattenuto"] = true

# ============================================================ combattimento

func _inizia_comb_vampiro(i: int, rif: Dictionary, k: int, imboscata: bool) -> void:
	var e: Dictionary = _h(rif)["inc"][k]
	e["riv"] = true
	var p := {"f": "comb_inizio", "tipo": "vampiro", "luogo": c(i)["pos"], "h": i, "rif": rif, "uid": e.get("uid", ""), "inc": e["id"], "imboscata": imboscata}
	if e.get("uid", "") == "":
		e["uid"] = "v%d" % s["passo"]
		p["uid"] = e["uid"]
	if e["id"] == "nuovo":
		var altri := []
		for j in cacciatori_in(c(i)["pos"]):
			if j != i and not c(j)["trattenuto"]:
				altri.append(j)
		if not altri.is_empty():
			p["unisci"] = altri
			s["pila"].push_front(p)
			s["pila"].push_front({"f": "unisciti", "altri": altri, "p_idx": 0})
			return
	s["pila"].push_front(p)

func _p_unisciti(p: Dictionary) -> void:
	var altri: Array = p["altri"]
	if altri.is_empty():
		return
	var j: int = altri[0]
	altri.remove_at(0)
	s["pila"].push_front({"f": "unisciti", "altri": altri})
	_chiedi(j, "unisciti", "Un Nuovo Vampiro attacca! %s si unisce al combattimento (resta poi trattenuto)?" % nome(j), [_o("si", "Sì, combatti"), _o("no", "No")], {"h": j})

func _d_unisciti(r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "si":
		c(r["h"])["trattenuto"] = true
		s["flag"]["unisciti"] = s["flag"].get("unisciti", []) + [r["h"]]

func _p_comb_inizio(p: Dictionary) -> void:
	var cc := []
	if p["tipo"] == "dracula":
		cc = cacciatori_in(p["luogo"])
	else:
		cc = [p["h"]]
		for j in s["flag"].get("unisciti", []):
			if in_citta(j, p["luogo"]) and not cc.has(j):
				cc.append(j)
		s["flag"].erase("unisciti")
	if cc.is_empty():
		return
	var mazzo := []
	for k in Dati.COMB_DRACULA:
		for n in int(Dati.COMB_DRACULA[k]["n"]):
			mazzo.append(k)
	for h in s["percorso"]:
		if h["potere"] == "pipistrello":
			_togli(mazzo, "pipistrello")
	_mescola(mazzo)
	var mano := []
	for n in 5:
		if not mazzo.is_empty():
			mano.append(mazzo.pop_back())
	var nt: bool = notte() or s["fase"] == "tramonto" or s["flag"].get("visita", false)
	var vita_v := 0
	if p["tipo"] == "vampiro":
		vita_v = int(Dati.INCONTRI[p["inc"]]["vita"])
	s["comb"] = {"tipo": p["tipo"], "luogo": p["luogo"], "cacc": cc, "mazzo": mazzo, "mano": mano, "giocate": 0, "round": 0,
		"notte": nt, "scoperte": [], "mesm": [], "ultime": {}, "scelte": {}, "carta_d": "", "ingaggiato": -1,
		"ghirlanda": [], "proiettili": [], "lucy": -1, "furioso": false, "pianificata": [], "inc": p.get("inc", ""),
		"rif": p.get("rif", {}), "uid": p.get("uid", ""), "imboscata": p.get("imboscata", false), "vamp_danni": 0, "vamp_vita": vita_v,
		"giocate_d": [], "esito": ""}
	if p["tipo"] == "vampiro":
		var e := _trova_vampiro()
		if not e.is_empty():
			s["comb"]["vamp_danni"] = int(e.get("danni", 0))
		_log("COMBATTIMENTO: %s contro il %s (%d/%d)." % [", ".join(cc.map(func(x): return nome(x))), Dati.INCONTRI[p["inc"]]["nome"], vita_v - int(s["comb"]["vamp_danni"]), vita_v])
	else:
		_log("COMBATTIMENTO con DRACULA a %s (%s)! %s." % [Dati.nome(p["luogo"]), "di notte" if nt else "di giorno", ", ".join(cc.map(func(x): return nome(x)))])
	for j in cc:
		if ha_ogg(j, "ghirlanda"):
			s["comb"]["ghirlanda"].append(j)
			_log("%s indossa la Ghirlanda d'Aglio." % nome(j))
	var passi := []
	for j in cc:
		passi.append({"f": "comb_pre", "h": j})
	passi.append({"f": "comb_round"})
	_push(passi)

func _trova_vampiro() -> Dictionary:
	for h in s["percorso"] + s["tane"]:
		for e in h["inc"]:
			if e.get("uid", "") == s["comb"].get("uid", "-"):
				return e
	return {}

## Eventi a inizio combattimento.
func _p_comb_pre(p: Dictionary) -> void:
	var j: int = p["h"]
	if s["comb"].is_empty() or not (j in s["comb"]["cacc"]):
		return
	var opz := []
	for e in c(j)["ev"]:
		if opz.any(func(x): return x["id"] == e):
			continue
		var d: Dictionary = Dati.EVENTI[e]
		if d["quando"] == "combattimento" and (not d.has("solo") or int(d["solo"]) == j):
			opz.append(_o(e, "Gioca " + d["nome"], {"carta": e}))
	if opz.is_empty():
		return
	opz.append(_o("no", "Nessuna"))
	_chiedi(j, "comb_pre", "Inizio del combattimento: %s gioca un evento?" % nome(j), opz, {"h": j})

func _d_comb_pre(r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "no":
		return
	var j: int = r["h"]
	var e: String = o["id"]
	_scarta_ev(j, e)
	_annuncia(j, e)
	match e:
		"imboscata":
			s["comb"]["pianificata"].append(j)
		"lucy":
			_togli_scarti_ev("lucy")
			s["comb"]["lucy"] = j
		"scoperta":
			var viste := []
			for k in 5:
				if not s["m_ogg"].is_empty():
					viste.append(s["m_ogg"].pop_back())
			var opz := []
			for x in viste:
				if not opz.any(func(y): return y["id"] == x):
					opz.append(_o(x, "Prendi " + Dati.OGGETTI[x]["nome"], {"carta": x}))
			if not opz.is_empty():
				_chiedi(j, "scoperta", "Scoperta Fortunata: quale Oggetto prendi?", opz, {"h": j, "viste": viste})
		"via_fuga":
			var opz := []
			for x in s["comb"]["cacc"]:
				opz.append(_o(x, "Fai uscire " + nome(x)))
			_chiedi(j, "via_fuga", "Via di Fuga: chi esce dal combattimento?", opz)
		"slancio":
			_log("Slancio Eroico! %s si getta sul nemico." % nome(j))
			_danno_vampiro(5)
			_danno(j, 5, "Slancio Eroico")
			s["comb"]["esito"] = "fine"

func _d_scoperta(r: Dictionary, o: Dictionary) -> void:
	var viste: Array = r["viste"]
	_togli(viste, o["id"])
	c(r["h"])["ogg"].append(o["id"])
	for x in viste:
		s["s_ogg"].append(x)
	if c(r["h"])["ogg"].size() > max_ogg(r["h"]):
		s["pila"].push_front({"f": "limite_ogg", "h": r["h"]})

func _d_via_fuga(_r: Dictionary, o: Dictionary) -> void:
	var j := int(o["id"])
	s["comb"]["cacc"].erase(j)
	_log("%s si allontana dal combattimento." % nome(j))

func _p_comb_round(_p: Dictionary) -> void:
	var cb: Dictionary = s["comb"]
	if cb.is_empty():
		return
	if cb["esito"] != "" or cb["cacc"].is_empty() or int(cb["giocate"]) >= 6 or finita() or (cb["tipo"] == "vampiro" and int(cb["vamp_danni"]) >= int(cb["vamp_vita"])):
		_fine_comb()
		return
	if cb["mano"].is_empty():
		_fine_comb()
		return
	cb["round"] = int(cb["round"]) + 1
	cb["scelte"] = {}
	cb["carta_d"] = ""
	cb["ingaggiato"] = -1
	_push([{"f": "comb_scelta_d"}, {"f": "comb_scelte_c", "k": 0}, {"f": "comb_ingaggio"}, {"f": "comb_risolvi"}, {"f": "comb_round"}])

func _p_comb_scelta_d(_p: Dictionary) -> void:
	var cb: Dictionary = s["comb"]
	var opz := []
	for k in cb["mano"].size():
		var id: String = cb["mano"][k]
		if opz.any(func(x): return x["carta"] == id):
			continue
		opz.append(_o(id, Dati.COMB_DRACULA[id]["nome"], {"carta": id}))
	var chi: String = "Dracula" if cb["tipo"] == "dracula" else Dati.INCONTRI[cb["inc"]]["nome"]
	_chiedi(DRACULA, "comb_d", "Round %d: scegli la carta di %s." % [cb["round"], chi], opz)

func _d_comb_d(_r: Dictionary, o: Dictionary) -> void:
	var cb: Dictionary = s["comb"]
	cb["carta_d"] = o["id"]
	_togli(cb["mano"], o["id"])

## Le carte che il cacciatore può giocare questo round.
func opz_comb_cacciatore(j: int) -> Array:
	var cb: Dictionary = s["comb"]
	var ultime: Array = cb["ultime"].get(str(j), [])
	var out := []
	for k in ["pugno", "schivare", "fuggire"]:
		if not (k in ultime):
			out.append(_o("c:" + k, Dati.COMB_CACCIATORE[k]["nome"], {"carta": k, "tipo": "comb", "icone": Dati.COMB_CACCIATORE[k]["icone"]}))
	var conta := {}
	for o in c(j)["ogg"]:
		if (Dati.OGGETTI[o]["icone"] as Array).is_empty():
			continue
		conta[o] = int(conta.get(o, 0)) + 1
	for o in conta:
		if int(conta[o]) > ultime.count("o:" + o):
			out.append(_o("o:" + o, Dati.OGGETTI[o]["nome"], {"carta": o, "tipo": "oggetto", "icone": Dati.OGGETTI[o]["icone"]}))
	return out

func _p_comb_scelte_c(p: Dictionary) -> void:
	var cb: Dictionary = s["comb"]
	var k: int = p["k"]
	if k >= cb["cacc"].size():
		return
	var j: int = cb["cacc"][k]
	s["pila"].push_front({"f": "comb_scelte_c", "k": k + 1})
	var avv: String = "Dracula" if cb["tipo"] == "dracula" else Dati.INCONTRI[cb["inc"]]["nome"]
	_chiedi(j, "comb_c", "Round %d contro %s: %s sceglie la sua carta." % [cb["round"], avv, nome(j)], opz_comb_cacciatore(j), {"h": j})

func _d_comb_c(r: Dictionary, o: Dictionary) -> void:
	s["comb"]["scelte"][str(r["h"])] = o["id"]

func _p_comb_ingaggio(_p: Dictionary) -> void:
	var cb: Dictionary = s["comb"]
	if cb["cacc"].size() == 1:
		cb["ingaggiato"] = cb["cacc"][0]
		return
	var opz := []
	for j in cb["cacc"]:
		opz.append(_o(j, "Combatti contro " + nome(j)))
	_chiedi(DRACULA, "ingaggio", "Quale cacciatore affronti in questo round?", opz)

func _d_ingaggio(_r: Dictionary, o: Dictionary) -> void:
	s["comb"]["ingaggiato"] = int(o["id"])

func _icone_carta(id: String) -> Array:
	var t := id.get_slice(":", 0)
	var k := id.get_slice(":", 1)
	if t == "c":
		return Dati.COMB_CACCIATORE[k]["icone"]
	return Dati.OGGETTI[k]["icone"]

func _p_comb_risolvi(_p: Dictionary) -> void:
	var cb: Dictionary = s["comb"]
	var dc: String = cb["carta_d"]
	var ing: int = cb["ingaggiato"]
	cb["giocate"] = int(cb["giocate"]) + 1
	cb["giocate_d"].append(dc)
	var t := []
	for j in cb["cacc"]:
		var sc: String = cb["scelte"].get(str(j), "c:schivare")
		t.append("%s: %s" % [nome(j), _nome_scelta(sc)])
	var chi: String = "Dracula" if cb["tipo"] == "dracula" else "il vampiro"
	_log("Round %d — %s gioca %s; %s." % [cb["round"], chi, Dati.COMB_DRACULA[dc]["nome"], "; ".join(t)])
	cb["rivelate"] = {"d": dc, "c": cb["scelte"].duplicate(), "ing": ing, "round": cb["round"]}
	# Imboscata Pianificata: il cacciatore ingaggiato può cambiare carta dopo averle viste
	if ing in cb["pianificata"] and int(cb["round"]) == 1:
		cb["pianificata"].erase(ing)
		var opz := [_o("tieni", "Tieni " + _nome_scelta(cb["scelte"].get(str(ing), "")))]
		for x in opz_comb_cacciatore(ing):
			if x["id"] != cb["scelte"].get(str(ing), ""):
				opz.append(_o(x["id"], "Cambia con " + x["testo"]))
		_chiedi(ing, "pianificata", "Imboscata Pianificata: Dracula ha giocato %s. Cambi carta?" % Dati.COMB_DRACULA[dc]["nome"], opz, {"h": ing})
		s["pila"].push_front({"f": "comb_effetti"})
		return
	_p_comb_effetti({})

func _d_pianificata(r: Dictionary, o: Dictionary) -> void:
	if o["id"] != "tieni":
		s["comb"]["scelte"][str(r["h"])] = o["id"]
		_log("%s cambia carta: %s." % [nome(r["h"]), _nome_scelta(o["id"])])

func _nome_scelta(id: String) -> String:
	if id == "":
		return "-"
	var t := id.get_slice(":", 0)
	var k := id.get_slice(":", 1)
	return Dati.COMB_CACCIATORE[k]["nome"] if t == "c" else Dati.OGGETTI[k]["nome"]

func _p_comb_effetti(_p: Dictionary) -> void:
	var cb: Dictionary = s["comb"]
	var dc: String = cb["carta_d"]
	var ing: int = cb["ingaggiato"]
	var sc_ing: String = cb["scelte"].get(str(ing), "")
	var icona: String = Dati.COMB_DRACULA[dc]["icona"]
	var annullate := {}   # cacciatore -> true se la sua carta è annullata
	var annullata_d := false
	# Macchinazione scoperta: Dracula annulla Pugno, Schivare o Fuggire del cacciatore ingaggiato
	if sc_ing.begins_with("c:") and "macchinazione" in cb["scoperte"] and (icona in _icone_carta(sc_ing) or sc_ing == "c:fuggire"):
		cb["scoperte"].erase("macchinazione")
		annullate[ing] = true
		_log("Macchinazione: Dracula aveva previsto la mossa di %s, che è annullata." % nome(ing))
	elif sc_ing != "" and icona in _icone_carta(sc_ing):
		annullata_d = true
		if "furioso" in s["dr"]["ev"] and cb["tipo"] == "dracula" and not (dc in ["pipistrello", "nebbia"]):
			_togli(s["dr"]["ev"], "furioso")
			s["s_ev"].append({"id": "furioso", "coperta": false})
			_annuncia(DRACULA, "furioso")
			cb["furioso"] = true
			annullata_d = false
	# Orgoglio: le fughe sono annullate se Dracula non ha giocato abbastanza carte
	if dc in ["pipistrello", "nebbia"]:
		if int(cb["giocate"]) <= int(s["disperazione"]):
			annullata_d = true
			_log("Orgoglio: troppo presto per fuggire, la carta è annullata.")
		elif cb["furioso"]:
			annullata_d = true
		elif cb["lucy"] >= 0 and cb["tipo"] == "dracula":
			_log("La Vendetta di Lucy impedisce la fuga di Dracula!")
			s["s_ev"].append({"id": "lucy", "coperta": false})
			cb["lucy"] = -1
			annullata_d = true
	if annullata_d:
		_log("%s annulla %s!" % [_nome_scelta(sc_ing), Dati.COMB_DRACULA[dc]["nome"]])
		if sc_ing == "o:crocifisso" and dc in ["denti", "mesmerismo"]:
			_danno_vampiro(3)
			_log("Il Crocifisso brucia il vampiro.")
	else:
		_effetto_dracula(dc, ing, sc_ing, annullate)
	if s["comb"].is_empty() or cb["esito"] != "":
		return
	# effetti dei cacciatori
	var proiettili_ok := true
	for j in cb["cacc"].duplicate():
		var sc: String = cb["scelte"].get(str(j), "")
		if sc == "" or annullate.get(j, false):
			continue
		_effetto_cacciatore(j, sc, dc, j == ing, proiettili_ok)
		if cb["esito"] != "" or finita():
			break
	# le carte giocate restano davanti e tornano in mano al round dopo
	var nuove := {}
	for j in cb["cacc"]:
		var sc: String = cb["scelte"].get(str(j), "")
		if sc != "":
			nuove[str(j)] = [sc.get_slice(":", 1) if sc.begins_with("c:") else sc]
	cb["ultime"] = nuove
	if not cb["mazzo"].is_empty():
		cb["mano"].append(cb["mazzo"].pop_back())

func _danno_vampiro(n: int) -> void:
	var cb: Dictionary = s["comb"]
	if n <= 0 or cb.is_empty():
		return
	if cb["tipo"] == "dracula":
		s["dr"]["danni"] = int(s["dr"]["danni"]) + n
		_log("Dracula subisce %d danni. [%d/%d]" % [n, s["dr"]["danni"], Dati.VITA_DRACULA])
		if int(s["dr"]["danni"]) >= Dati.VITA_DRACULA:
			cb["esito"] = "fine"
	else:
		cb["vamp_danni"] = int(cb["vamp_danni"]) + n
		_log("Il vampiro subisce %d danni. [%d/%d]" % [n, cb["vamp_danni"], cb["vamp_vita"]])
		if int(cb["vamp_danni"]) >= int(cb["vamp_vita"]):
			cb["esito"] = "fine"

func _cura_vampiro(n: int) -> void:
	var cb: Dictionary = s["comb"]
	if cb["tipo"] == "dracula":
		s["dr"]["danni"] = max(0, int(s["dr"]["danni"]) - n)
	else:
		cb["vamp_danni"] = max(0, int(cb["vamp_danni"]) - n)

func _effetto_dracula(dc: String, ing: int, sc_ing: String, annullate: Dictionary) -> void:
	var cb: Dictionary = s["comb"]
	var nt: bool = cb["notte"]
	match dc:
		"artigli":
			_danno(ing, 2, "Artigli")
			if not cb["ghirlanda"].is_empty():
				for j in cb["ghirlanda"]:
					_scarta_ogg(j, "ghirlanda")
				cb["ghirlanda"] = []
				_log("Gli Artigli strappano la Ghirlanda d'Aglio.")
			if nt and cb["cacc"].size() > 1:
				var opz := []
				for j in cb["cacc"]:
					if j != ing:
						opz.append(_o(j, "Colpisci anche " + nome(j)))
				if not opz.is_empty():
					_chiedi(DRACULA, "artigli2", "Artigli di notte: quale altro cacciatore colpisci?", opz)
		"forza":
			_danno(ing, 2, "Forza")
			if sc_ing in ["c:pugno", "o:crocifisso", "o:pistola", "o:fucile", "o:coltello"]:
				annullate[ing] = true
				_log("La Forza di Dracula annulla %s." % _nome_scelta(sc_ing))
				if nt and sc_ing.begins_with("o:"):
					_scarta_ogg(ing, sc_ing.get_slice(":", 1))
					_log("%s perde %s." % [nome(ing), _nome_scelta(sc_ing)])
		"denti":
			_cura_vampiro(2)
			if cb["tipo"] == "dracula" and s["alleato_c"] == "agatha":
				_log("Suor Agatha: Dracula soffre per il morso.")
				s["dr"]["danni"] = int(s["dr"]["danni"]) + 2
			if nt and ing in cb["mesm"]:
				_morso(ing)
				s["influenza"] = int(s["influenza"]) + 1
				_log("Il morso notturno fa avanzare l'Influenza di 1.")
				cb["cacc"].erase(ing)
			else:
				_danno(ing, 2, "Denti Aguzzi")
				if ing in cb["ghirlanda"] and not c(ing)["sconfitto"]:
					_log("La Ghirlanda d'Aglio respinge il vampiro!")
					_danno_vampiro(4)
			if cb["tipo"] == "vampiro" and cb["inc"] == "temerario" and cb["imboscata"]:
				s["influenza"] = int(s["influenza"]) + 1
				_log("Il Vampiro Temerario si nutre: Influenza +1.")
		"mesmerismo":
			annullate[ing] = true
			if not (ing in cb["mesm"]):
				cb["mesm"].append(ing)
			cb["scoperte"].append("mesmerismo")
			_log("%s è mesmerizzato." % nome(ing))
		"macchinazione":
			cb["scoperte"].append("macchinazione")
			if not cb["mazzo"].is_empty():
				var opz := []
				for x in cb["mazzo"]:
					if not opz.any(func(y): return y["id"] == x):
						opz.append(_o(x, Dati.COMB_DRACULA[x]["nome"], {"carta": x}))
				_chiedi(DRACULA, "macchinazione", "Macchinazione: quale carta prendi dal mazzo Combattimento?", opz)
		"nebbia", "pipistrello":
			if cb["tipo"] == "dracula" and s["alleato_c"] == "agatha":
				s["dr"]["danni"] = int(s["dr"]["danni"]) + 2
				_log("Suor Agatha: la fuga costa 2 danni a Dracula.")
			_log("%s fugge %s." % ["Dracula" if cb["tipo"] == "dracula" else "Il vampiro", "come nebbia" if dc == "nebbia" else "come pipistrello"])
			cb["esito"] = "fuga"
			if dc == "pipistrello" and nt and cb["tipo"] == "dracula":
				var dd := Dati.distanze_strada(pos_dracula(), 2, s["consacrato"] + s["schiera"])
				var opz := [_o("resta", "Resta dove sei")]
				var uso := luoghi_in_uso()
				for k in dd:
					if k != pos_dracula() and cacciatori_in(k).is_empty() and not (k in uso) and not Dati.mare(k):
						opz.append(_o(k, "Fuggi a " + Dati.nome(k), {"luogo": k}))
				_chiedi(DRACULA, "pipistrello", "Fuggi come pipistrello: dove vai in segreto?", opz)
			_fine_comb()

func _d_artigli2(_r: Dictionary, o: Dictionary) -> void:
	_danno(int(o["id"]), 2, "Artigli")

func _d_macchinazione(_r: Dictionary, o: Dictionary) -> void:
	var cb: Dictionary = s["comb"]
	if cb.is_empty():
		return
	_togli(cb["mazzo"], o["id"])
	cb["mano"].append(o["id"])
	_mescola(cb["mazzo"])

func _d_pipistrello(_r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "resta":
		return
	# sgombera il nascondiglio attuale e mette la nuova città con la carta Pipistrello sul primo spazio
	var k := indice_attuale()
	if k >= 0:
		var h: Dictionary = s["percorso"][k]
		_sgombera(h)
		h["luogo"] = ""
		h["potere"] = ""
		s["percorso"].remove_at(k)
	var n := _nasc(o["id"], "pipistrello")
	s["percorso"].push_front(n)
	_taglia_percorso()
	_log("Dracula si dilegua nella notte come un pipistrello.")

func _effetto_cacciatore(j: int, sc: String, dc: String, ingaggiato: bool, _pr: bool) -> void:
	var cb: Dictionary = s["comb"]
	if not (j in cb["cacc"]):
		return
	var t := sc.get_slice(":", 0)
	var k := sc.get_slice(":", 1)
	var mesm: bool = j in cb["mesm"]
	if t == "c":
		match k:
			"pugno":
				_danno_vampiro(1)
			"fuggire":
				cb["cacc"].erase(j)
				_log("%s fugge dal combattimento." % nome(j))
		return
	match k:
		"pistola", "fucile", "coltello":
			var d := int(Dati.OGGETTI[k]["danni"]) - (1 if mesm else 0)
			if k != "coltello" and ha_ogg(j, "proiettili") and not (j in cb["proiettili"]):
				cb["proiettili"].append(j)
				_scarta_ogg(j, "proiettili")
				d += 3
				_log("%s usa i Proiettili Consacrati!" % nome(j))
			_danno_vampiro(d)
		"aglio":
			if ingaggiato and dc in ["denti", "artigli"]:
				_danno_vampiro(2)
		"ostia":
			_scarta_ogg(j, "ostia")
			if ingaggiato and dc == "denti":
				_morso(j)
				cb["cacc"].erase(j)
			else:
				_danno_vampiro(4)
		"cerchio":
			_scarta_ogg(j, "cerchio")
			cb["cacc"].erase(j)
			_log("%s si rifugia nel Cerchio Sacro." % nome(j))
		"crocifisso":
			pass

func _taglia_percorso() -> void:
	while s["percorso"].size() > 6:
		var h: Dictionary = s["percorso"].pop_back()
		_sgombera(h)

func _fine_comb() -> void:
	var cb: Dictionary = s["comb"]
	if cb.is_empty():
		return
	for j in cb["ghirlanda"]:
		_scarta_ogg(j, "ghirlanda")
	if cb["lucy"] >= 0:
		s["s_ev"].append({"id": "lucy", "coperta": false})
	if cb["tipo"] == "vampiro":
		var e := _trova_vampiro()
		if int(cb["vamp_danni"]) >= int(cb["vamp_vita"]):
			_log("Il %s è distrutto!" % Dati.INCONTRI[cb["inc"]]["nome"])
			for h in s["percorso"] + s["tane"]:
				for k in range(h["inc"].size() - 1, -1, -1):
					if h["inc"][k].get("uid", "") == cb["uid"]:
						s["s_inc"].append(h["inc"][k]["id"])
						h["inc"].remove_at(k)
			_pulisci_vuote()
		elif not e.is_empty():
			e["danni"] = cb["vamp_danni"]
			e["riv"] = true
			_log("Il vampiro sopravvive e resta nel nascondiglio.")
	else:
		_log("Il combattimento con Dracula è finito.")
	s["comb"] = {}
	# il combattimento termina: rimuovi i passi del round ancora in pila
	var nuova := []
	for p in s["pila"]:
		if not str(p["f"]).begins_with("comb_"):
			nuova.append(p)
	s["pila"] = nuova

# ============================================================ turno di Dracula

func _p_turno_dracula(_p: Dictionary) -> void:
	s["fase"] = "dracula"
	s["flag"].erase("visita")
	_log("— Turno di Dracula —")
	var passi := [{"f": "alleati_dracula"}, {"f": "eventi_dracula", "quando": "turno"}, {"f": "scorri"}, {"f": "movimento"},
		{"f": "incontro"}, {"f": "diceria"}, {"f": "pesca_incontri"}, {"f": "eventi_dracula", "quando": "fine_turno"}, {"f": "fine_dracula"}]
	_push(passi)

func _p_fine_dracula(_p: Dictionary) -> void:
	if s["flag"].get("velocita", false):
		s["flag"].erase("velocita")
		_log("Velocità Disumana: Dracula gioca subito un altro turno!")
		s["pila"].push_front({"f": "turno_dracula"})

func _p_alleati_dracula(_p: Dictionary) -> void:
	match s["dr"]["alleato"]:
		"grande_lupo":
			var opz := []
			for j in 4:
				if attivo(j):
					opz.append(_o(j, "Morde " + nome(j)))
			if not opz.is_empty():
				_chiedi(DRACULA, "lupo_alleato", "Il Grande Lupo attacca: quale cacciatore?", opz)
		"hildesheim":
			if not s["m_ev"].is_empty() and Dati.EVENTI[s["m_ev"].back()]["d"]:
				_log("Immanuel Hildesheim procura un Evento a Dracula.")
				_dracula_riceve_evento(s["m_ev"].pop_back())
		"spose":
			if not s["dr"]["inc"].is_empty() and not s["m_inc"].is_empty():
				var opz := [_o("no", "Non cambiare")]
				for x in s["dr"]["inc"]:
					if not opz.any(func(y): return y["id"] == x):
						opz.append(_o(x, "Cambia " + Dati.INCONTRI[x]["nome"], {"carta": x}))
				_chiedi(DRACULA, "spose", "Spose di Dracula: cambi un Incontro della mano?", opz)

func _d_lupo_alleato(_r: Dictionary, o: Dictionary) -> void:
	var j := int(o["id"])
	if ha_ogg(j, "crocifisso") or ha_ogg(j, "ostia"):
		_log("%s mostra un simbolo sacro: il Grande Lupo si ritira." % nome(j))
	else:
		_danno(j, 1, "Grande Lupo")

func _d_spose(_r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "no":
		return
	_togli(s["dr"]["inc"], o["id"])
	s["s_inc"].append(o["id"])
	_pesca_incontro()

func _pesca_incontro() -> void:
	if s["m_inc"].is_empty():
		s["m_inc"] = s["s_inc"]
		s["s_inc"] = []
		_mescola(s["m_inc"])
	if not s["m_inc"].is_empty():
		s["dr"]["inc"].append(s["m_inc"].pop_back())

func _p_pesca_incontri(_p: Dictionary) -> void:
	var guard := 0
	while s["dr"]["inc"].size() < 5 and guard < 10:
		guard += 1
		_pesca_incontro()

## Eventi di Dracula giocabili in un momento del suo turno.
func _p_eventi_dracula(p: Dictionary) -> void:
	var q: String = p["quando"]
	var opz := []
	for e in s["dr"]["ev"]:
		if opz.any(func(x): return x["id"] == e):
			continue
		var w: String = Dati.EVENTI[e]["quando"]
		if w == q:
			if e == "trame" and not _trame_ok():
				continue
			opz.append(_o(e, "Gioca " + Dati.EVENTI[e]["nome"], {"carta": e}))
	if opz.is_empty():
		return
	opz.append(_o("no", "Nessuna"))
	_chiedi(DRACULA, "evento_dracula", "Vuoi giocare un Evento %s?" % ("a inizio turno" if q == "turno" else "a fine turno"), opz, {"quando": q})

func _d_evento_dracula(r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "no":
		return
	var e: String = o["id"]
	_togli(s["dr"]["ev"], e)
	s["s_ev"].append({"id": e, "coperta": false})
	_annuncia(DRACULA, e)
	_effetto_evento_dracula(e)
	# si può giocarne un altro nello stesso momento
	s["pila"].push_front({"f": "eventi_dracula", "quando": r["quando"]})

func _trame_ok() -> bool:
	if s["percorso"].size() < 3 or s["dr"]["inc"].is_empty():
		return false
	var h: Dictionary = s["percorso"][2]
	return h["potere"] == "nascondersi" or (h["luogo"] != "" and not Dati.mare(h["luogo"]))

func _effetto_evento_dracula(e: String) -> void:
	match e:
		"tempeste":
			s["pila"].push_front({"f": "piazza_tempeste", "n": 3})
		"strada_bloccata":
			s["pila"].push_front({"f": "piazza_blocco", "n": 3})
		"visita":
			s["flag"]["visita"] = true
		"trame":
			if s["percorso"].size() >= 3:
				_chiedi(DRACULA, "piazza_inc", "Trame Nascoste: quale Incontro piazzi sul 3° spazio?", _opz_incontri_mano(), {"kk": 2})
		"oscurita":
			s["flag"]["no_giorno"] = true
			for k in range(s["s_ev"].size() - 1, -1, -1):
				if Dati.EVENTI[s["s_ev"][k]["id"]]["d"]:
					s["m_ev"].append(s["s_ev"][k]["id"])
					s["s_ev"].remove_at(k)
			_mescola(s["m_ev"])
		"velocita":
			s["flag"]["velocita"] = true
		"potere_diabolico":
			var opz := [_o("rifornimento", "I cacciatori non possono rifornirsi nel prossimo turno")]
			for k in s["consacrato"]:
				opz.append(_o("cons:" + k, "Togli il Terreno Consacrato di " + Dati.nome(k)))
			if s["alleato_c"] != "":
				opz.append(_o("alleato", "Scarta l'alleato dei cacciatori (%s)" % Dati.EVENTI[s["alleato_c"]]["nome"]))
			_chiedi(DRACULA, "potere_diabolico", "Potere Diabolico: cosa fai?", opz)

func _d_potere_diabolico(_r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "rifornimento":
		s["flag"]["no_rifornimento"] = true
		_log("Potere Diabolico: niente rifornimenti per i cacciatori nel prossimo turno.")
	elif o["id"] == "alleato":
		s["s_ev"].append({"id": s["alleato_c"], "coperta": false})
		_log("Potere Diabolico: l'alleato %s abbandona i cacciatori." % Dati.EVENTI[s["alleato_c"]]["nome"])
		s["alleato_c"] = ""
	else:
		s["consacrato"].erase(o["id"].get_slice(":", 1))
		_log("Potere Diabolico: sconsacrato il terreno di %s." % Dati.nome(o["id"].get_slice(":", 1)))

func _p_piazza_tempeste(p: Dictionary) -> void:
	if int(p["n"]) <= 0:
		return
	var opz := [_o("fine", "Basta così")]
	for k in Dati.luoghi():
		if Dati.mare(k) and not (k in s["tempeste"]):
			opz.append(_o(k, Dati.nome(k), {"luogo": k}))
	_chiedi(DRACULA, "tempesta", "Evocare Tempeste: su quale mare (ne restano %d)?" % p["n"], opz, {"n": p["n"]})

func _d_tempesta(r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "fine":
		return
	s["tempeste"].append(o["id"])
	_log("Una tempesta si abbatte sul %s." % Dati.nome(o["id"]))
	s["pila"].push_front({"f": "piazza_tempeste", "n": int(r["n"]) - 1})

func _p_piazza_blocco(p: Dictionary) -> void:
	if int(p["n"]) <= 0:
		return
	var opz := [_o("fine", "Basta così")]
	for st in Dati.mappa()["strade"]:
		if not _bloccata(st[0], st[1], false):
			opz.append(_o("s:%s:%s" % [st[0], st[1]], "Strada %s–%s" % [Dati.nome(st[0]), Dati.nome(st[1])], {"a": st[0], "b": st[1]}))
	for fe in Dati.mappa()["ferrovie"]:
		if not _bloccata(fe[0], fe[1], true):
			opz.append(_o("f:%s:%s" % [fe[0], fe[1]], "Ferrovia %s–%s" % [Dati.nome(fe[0]), Dati.nome(fe[1])], {"a": fe[0], "b": fe[1]}))
	_chiedi(DRACULA, "blocco", "Strada Bloccata: dove piazzi il blocco (ne restano %d)?" % p["n"], opz, {"n": p["n"]})

func _d_blocco(r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "fine":
		return
	var parti: PackedStringArray = o["id"].split(":")
	s["blocchi"].append([parti[1], parti[2], parti[0] == "f"])
	_log("Bloccata la %s %s–%s." % ["ferrovia" if parti[0] == "f" else "strada", Dati.nome(parti[1]), Dati.nome(parti[2])])
	s["pila"].push_front({"f": "piazza_blocco", "n": int(r["n"]) - 1})

func _dracula_riceve_evento(e: String) -> void:
	if Dati.EVENTI[e]["quando"] == "subito" or e in ["influsso"]:
		s["pila"].push_front({"f": "evento_d_subito", "e": e})
		return
	if e in ["tempeste", "strada_bloccata"]:
		s["pila"].push_front({"f": "evento_d_subito", "e": e})
		return
	s["dr"]["ev"].append(e)
	if s["dr"]["ev"].size() > 4:
		s["pila"].push_front({"f": "limite_ev_d"})

func _p_limite_ev_d(_p: Dictionary) -> void:
	if s["dr"]["ev"].size() <= 4:
		return
	var opz := []
	for e in s["dr"]["ev"]:
		if not opz.any(func(x): return x["id"] == e):
			opz.append(_o(e, "Scarta " + Dati.EVENTI[e]["nome"], {"carta": e}))
	_chiedi(DRACULA, "limite_ev_d", "Hai troppe carte Evento (massimo 4): quale scarti?", opz)

func _d_limite_ev_d(_r: Dictionary, o: Dictionary) -> void:
	_togli(s["dr"]["ev"], o["id"])
	s["s_ev"].append({"id": o["id"], "coperta": true})
	s["pila"].push_front({"f": "limite_ev_d"})

func _p_evento_d_subito(p: Dictionary) -> void:
	var e: String = p["e"]
	var d: Dictionary = Dati.EVENTI[e]
	if e in ["tempeste", "strada_bloccata"]:
		_chiedi(DRACULA, "d_subito", "Hai pescato %s." % d["nome"], [_o("subito", "Giocala subito"), _o("tieni", "Tienila per la fine del tuo turno")], {"e": e})
		return
	if d.get("alleato", false):
		_chiedi(DRACULA, "d_subito", "Hai pescato %s: si gioca subito." % d["nome"], [_o("subito", "Effetto immediato"), _o("alleato", "Come alleato di Dracula")], {"e": e})
		return
	if e == "influsso":
		var opz := []
		for j in 4:
			if attivo(j) and indebolito(j):
				opz.append(_o(j, nome(j)))
		s["s_ev"].append({"id": e, "coperta": false})
		_annuncia(DRACULA, e)
		if opz.is_empty():
			_log("Influsso Vampirico: nessun cacciatore indebolito.")
			return
		_chiedi(DRACULA, "influsso", "Influsso Vampirico: quale cacciatore indebolito?", opz)

func _d_d_subito(r: Dictionary, o: Dictionary) -> void:
	var e: String = r["e"]
	if o["id"] == "tieni":
		s["dr"]["ev"].append(e)
		if s["dr"]["ev"].size() > 4:
			s["pila"].push_front({"f": "limite_ev_d"})
		return
	_annuncia(DRACULA, e)
	if o["id"] == "alleato":
		if s["dr"]["alleato"] != "":
			s["s_ev"].append({"id": s["dr"]["alleato"], "coperta": false})
		s["dr"]["alleato"] = e
		_log("%s diventa alleato di Dracula." % Dati.EVENTI[e]["nome"])
		return
	s["s_ev"].append({"id": e, "coperta": false})
	match e:
		"tempeste", "strada_bloccata":
			_effetto_evento_dracula(e)
		"grande_lupo":
			var opz := []
			for j in 4:
				if attivo(j):
					opz.append(_o(j, nome(j)))
			_chiedi(DRACULA, "balzare", "Grande Lupo: su quale cacciatore balza?", opz)
		"hildesheim":
			var n := 0
			for k in min(6, s["m_ev"].size()):
				var x: String = s["m_ev"].pop_back()
				if Dati.EVENTI[x]["d"]:
					s["dr"]["ev"].append(x)
					n += 1
				else:
					s["s_ev"].append({"id": x, "coperta": false})
			_log("Hildesheim: Dracula prende %d carte Evento." % n)
			if s["dr"]["ev"].size() > 4:
				s["pila"].push_front({"f": "limite_ev_d"})
		"spose":
			s["pila"].push_front({"f": "spose_corrompi", "n": 2})

func _d_balzare(_r: Dictionary, o: Dictionary) -> void:
	var j := int(o["id"])
	if ha_ogg(j, "crocifisso") or ha_ogg(j, "ostia"):
		_log("%s mostra un simbolo sacro: il Grande Lupo si ritira." % nome(j))
	else:
		_danno(j, 4, "Grande Lupo")

func _p_spose_corrompi(p: Dictionary) -> void:
	if int(p["n"]) <= 0 or s["dr"]["inc"].is_empty():
		return
	var opz := [_o("fine", "Basta così")]
	for k in min(3, s["percorso"].size()):
		var h: Dictionary = s["percorso"][k]
		if h["luogo"] != "" and not Dati.mare(h["luogo"]) or h["potere"] == "nascondersi":
			if h["potere"] in ["richiamo", "nutrirsi", "depistaggio"]:
				continue
			opz.append(_o(k, "Spazio %d del Percorso" % (k + 1)))
	if opz.size() == 1:
		return
	_chiedi(DRACULA, "spose_spazio", "Spose di Dracula: su quale nascondiglio piazzi un Incontro?", opz, {"n": p["n"]})

func _d_spose_spazio(r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "fine":
		return
	s["pila"].push_front({"f": "spose_corrompi", "n": int(r["n"]) - 1})
	_chiedi(DRACULA, "piazza_inc", "Quale Incontro piazzi?", _opz_incontri_mano(), {"kk": int(o["id"])})

func _d_influsso(_r: Dictionary, o: Dictionary) -> void:
	var j := int(o["id"])
	var t := ", ".join(c(j)["ogg"].map(func(x): return Dati.OGGETTI[x]["nome"]) + c(j)["ev"].map(func(x): return Dati.EVENTI[x]["nome"]))
	_log("Influsso Vampirico: %s rivela %s." % [nome(j), t if t != "" else "nessuna carta"])
	var opz := []
	for x in c(j)["ogg"]:
		opz.append(_o("o:" + x, "Scarta " + Dati.OGGETTI[x]["nome"], {"carta": x}))
	for x in c(j)["ev"]:
		opz.append(_o("e:" + x, "Scarta " + Dati.EVENTI[x]["nome"], {"carta": x}))
	var uniche := []
	for x in opz:
		if not uniche.any(func(y): return y["id"] == x["id"]):
			uniche.append(x)
	s["pila"].push_front({"f": "influsso_sposta", "h": j})
	if not uniche.is_empty():
		_chiedi(DRACULA, "influsso_scarta", "Quale carta scarta %s?" % nome(j), uniche, {"h": j})

func _d_influsso_scarta(r: Dictionary, o: Dictionary) -> void:
	var j: int = r["h"]
	if o["id"].begins_with("o:"):
		_scarta_ogg(j, o["id"].substr(2))
	else:
		_scarta_ev(j, o["id"].substr(2))

func _p_influsso_sposta(p: Dictionary) -> void:
	var j: int = p["h"]
	if not attivo(j) or Dati.mare(c(j)["pos"]):
		return
	var opz := []
	for n in Dati.strade(c(j)["pos"]):
		opz.append(_o(n, Dati.nome(n), {"luogo": n}))
	_chiedi(DRACULA, "influsso_dest", "Dove sposti %s?" % nome(j), opz, {"h": j})

func _d_influsso_dest(r: Dictionary, o: Dictionary) -> void:
	c(r["h"])["pos"] = o["id"]
	_log("%s vaga in trance fino a %s." % [nome(r["h"]), Dati.nome(o["id"])])
	_arriva(r["h"], o["id"], "strada")

# ---------- movimento di Dracula

func _p_scorri(_p: Dictionary) -> void:
	# il nascondiglio che esce dal 6° spazio matura o diventa una tana
	if s["percorso"].size() < 6:
		return
	var h: Dictionary = s["percorso"][5]
	s["percorso"].remove_at(5)
	if s["alleato_c"] == "harker" and s["percorso"].size() >= 5 and s["percorso"][4]["luogo"] != "":
		s["percorso"][4]["riv"] = true
		_log("Jonathan Harker: rivelata la carta sul 6° spazio (%s)." % Dati.nome(s["percorso"][4]["luogo"]))
	if h["inc"].is_empty():
		_sgombera(h)
		return
	var puo_tana: bool = h["luogo"] != "" and not Dati.mare(h["luogo"]) and h["potere"] in ["", "lupo", "pipistrello"]
	if h["potere"] == "nascondersi":
		_log("Gli incontri di un Nascondersi escono dal Percorso senza effetto.")
		_sgombera(h)
		return
	if puo_tana and not s["dr"]["inc"].is_empty():
		s["flag"]["uscente"] = h
		_chiedi(DRACULA, "maturo", "Un nascondiglio (%s, %s) esce dal Percorso. Che cosa fai?" % [Dati.nome(h["luogo"]), ", ".join(h["inc"].map(func(x): return Dati.INCONTRI[x["id"]]["nome"]))],
			[_o("matura", "Fai maturare gli incontri"), _o("tana", "Trasformalo in una tana")])
		return
	_matura(h)

func _d_maturo(_r: Dictionary, o: Dictionary) -> void:
	var h: Dictionary = s["flag"]["uscente"]
	s["flag"].erase("uscente")
	if o["id"] == "matura":
		_matura(h)
		return
	if h["potere"] != "":
		h["potere"] = ""
	h["esclusi"] = []
	if s["tane"].size() >= 3:
		var vecchia: Dictionary = s["tane"].pop_front()
		_log("Dracula abbandona la tana di %s." % Dati.nome(vecchia["luogo"]))
		_sgombera(vecchia)
	s["tane"].append(h)
	_log("Dracula fa del nascondiglio una TANA.")
	_chiedi(DRACULA, "piazza_inc_tana", "Quale Incontro aggiungi alla nuova tana?", _opz_incontri_mano(), {"t": s["tane"].size() - 1})

func _d_piazza_inc_tana(r: Dictionary, o: Dictionary) -> void:
	_togli(s["dr"]["inc"], o["id"])
	s["tane"][int(r["t"])]["inc"].append(_nuovo_inc(o["id"]))

func _opz_incontri_mano() -> Array:
	var out := []
	for x in s["dr"]["inc"]:
		if not out.any(func(y): return y["id"] == x):
			out.append(_o(x, Dati.INCONTRI[x]["nome"], {"carta": x}))
	return out

func _matura(h: Dictionary) -> void:
	var vamp_extra := false
	for e in h["inc"].duplicate():
		e["riv"] = true
		var id: String = e["id"]
		var d: Dictionary = Dati.INCONTRI[id]
		_log("Matura «%s»%s." % [d["nome"], " a " + Dati.nome(h["luogo"]) if h["luogo"] != "" else ""])
		match id:
			"temerario", "aristocratico", "nuovo":
				var n := 3 if id == "nuovo" else 4
				if h["diceria"]:
					n += 3
					h["diceria"] = false
					s["dicerie_pool"] = int(s["dicerie_pool"])
				s["influenza"] = int(s["influenza"]) + n
				_log("Il vampiro si è insediato: l'Influenza di Dracula sale di %d." % n)
				vamp_extra = true
			"szgany":
				if h["luogo"] != "" and not Dati.mare(h["luogo"]):
					h["riv"] = true
					for k in Dati.citta():
						if Dati.regione(k) == Dati.regione(h["luogo"]):
							_szgany_in(k)
			"raggiro":
				var opz := []
				for x in s["s_ev"]:
					if Dati.EVENTI[x["id"]]["d"] and not opz.any(func(y): return y["id"] == x["id"]):
						opz.append(_o(x["id"], Dati.EVENTI[x["id"]]["nome"], {"carta": x["id"]}))
				if not opz.is_empty():
					_chiedi(DRACULA, "raggiro", "Raggiro: quale Evento di Dracula riprendi dagli scarti?", opz)
			"lupi":
				if h["luogo"] != "" and not Dati.mare(h["luogo"]):
					h["riv"] = true
					var opz := []
					for k in Dati.distanze_strada(h["luogo"], 2):
						opz.append(_o(k, Dati.nome(k), {"luogo": k}))
					_chiedi(DRACULA, "lupi_maturi", "I Lupi maturano: in quale città (fino a 2 strade) colpiscono?", opz)
			"guardie":
				s["dr"]["guardie"] = int(s["dr"]["guardie"]) + 1
				h["inc"].erase(e)
				_log("Dracula tiene le Guardie del Corpo Szgany pronte per il prossimo combattimento.")
				continue
			"sconsacrato":
				s["dr"]["danni"] = max(0, int(s["dr"]["danni"]) - 3)
				_log("Dracula recupera fino a 3 danni.")
			"nebbia":
				if h["luogo"] != "" and not Dati.mare(h["luogo"]):
					h["riv"] = true
					var opz := []
					for k in Dati.citta():
						if Dati.regione(k) == Dati.regione(h["luogo"]):
							opz.append(_o(k, Dati.nome(k), {"luogo": k}))
					_chiedi(DRACULA, "nebbia_matura", "Nebbia Innaturale: su quale città della regione?", opz)
			"sabotatore":
				s["pila"].push_front({"f": "piazza_blocco", "n": 1})
			"spia":
				var opz := []
				for j in 4:
					if attivo(j):
						opz.append(_o(j, nome(j)))
				_chiedi(DRACULA, "spia_matura", "La Spia: contro quale cacciatore?", opz)
	_sgombera(h)
	if vamp_extra:
		# sgombera anche i nascondigli sul 4°, 5° e 6° spazio (quello uscito è il 7°)
		for k in range(s["percorso"].size() - 1, 2, -1):
			var x: Dictionary = s["percorso"][k]
			if k == indice_attuale():
				continue
			_sgombera(x)
			s["percorso"].remove_at(k)
		_log("Il Percorso si accorcia: sgomberati i nascondigli più vecchi.")

func _d_raggiro(_r: Dictionary, o: Dictionary) -> void:
	for k in s["s_ev"].size():
		if s["s_ev"][k]["id"] == o["id"]:
			s["s_ev"].remove_at(k)
			break
	var resto := []
	for k in range(s["s_ev"].size() - 1, -1, -1):
		if Dati.EVENTI[s["s_ev"][k]["id"]]["d"]:
			resto.append(s["s_ev"][k]["id"])
			s["s_ev"].remove_at(k)
	s["m_ev"].append_array(resto)
	_mescola(s["m_ev"])
	s["dr"]["ev"].append(o["id"])
	_log("Raggiro: Dracula recupera un Evento e rimescola gli altri nel mazzo.")
	if s["dr"]["ev"].size() > 4:
		s["pila"].push_front({"f": "limite_ev_d"})

func _d_lupi_maturi(_r: Dictionary, o: Dictionary) -> void:
	_log("Un branco di lupi assale %s." % Dati.nome(o["id"]))
	_lupi_in(o["id"])

func _d_nebbia_matura(_r: Dictionary, o: Dictionary) -> void:
	s["nebbia"][o["id"]] = int(s["nebbia"].get(o["id"], 0)) + 2
	_log("Una fitta nebbia cala su %s." % Dati.nome(o["id"]))

func _d_spia_matura(_r: Dictionary, o: Dictionary) -> void:
	_spia(int(o["id"]))

## Le mosse possibili di Dracula: {id, testo, luogo, potere}.
func mosse_dracula() -> Array:
	var cur := pos_dracula()
	var out := []
	var uso := luoghi_in_uso()
	var tane := []
	for t in s["tane"]:
		tane.append(t["luogo"])
	var vietate: Array = s["consacrato"] + s["schiera"]
	var vic := []
	if Dati.mare(cur):
		vic = Dati.L(cur)["porti"].duplicate()
	else:
		vic = Dati.strade(cur).duplicate()
		for m in Dati.L(cur)["porti"]:
			vic.append(m)
	for n in vic:
		if n in vietate:
			continue
		if n in uso and not (n in tane):
			continue
		var t := "Vai a " + Dati.nome(n)
		if n in tane:
			t += " (la tua tana)"
		if Dati.mare(n):
			t += " — subisci %d dann%s" % [_costo_mare(cur, n), "o" if _costo_mare(cur, n) == 1 else "i"]
		if not cacciatori_in(n).is_empty():
			t += " (ci sono cacciatori!)"
		out.append(_o("v:" + n, t, {"luogo": n}))
	var poteri := poteri_in_uso()
	var a_mare := Dati.mare(cur)
	var protetta := cur in vietate
	if not a_mare and not ("nascondersi" in poteri) and not protetta:
		out.append(_o("p:nascondersi", "Nascondersi: resti a " + Dati.nome(cur), {"potere": "nascondersi"}))
	if not a_mare and not ("nutrirsi" in poteri) and not protetta:
		out.append(_o("p:nutrirsi", "Nutrirsi: recuperi 3 danni", {"potere": "nutrirsi"}))
	if not a_mare and not ("richiamo" in poteri) and not protetta:
		out.append(_o("p:richiamo", "Richiamo Oscuro: 2 danni, peschi 5 Incontri", {"potere": "richiamo"}))
	if not ("lupo" in poteri) and not _dest_lupo(cur).is_empty():
		out.append(_o("p:lupo", "Forma del Lupo: fino a 2 strade, subisci 1 danno", {"potere": "lupo"}))
	if not ("depistaggio" in poteri) and not _hideout_depistabili().is_empty():
		out.append(_o("p:depistaggio", "Depistaggio: cancella un nascondiglio, poi muovi", {"potere": "depistaggio"}))
	return out

func _costo_mare(da: String, a: String) -> int:
	if not Dati.mare(a):
		return 0
	if Dati.mare(da):
		return 2 if s["alleato_c"] == "rufus" else 1
	return 2

func _dest_lupo(cur: String) -> Array:
	var vietate: Array = s["consacrato"] + s["schiera"]
	var uso := luoghi_in_uso()
	var tane := []
	for t in s["tane"]:
		tane.append(t["luogo"])
	var out := []
	var partenze := [cur]
	if Dati.mare(cur):
		partenze = []
		for p in Dati.L(cur)["porti"]:
			if not Dati.mare(p):
				partenze.append(p)
	for p in partenze:
		var dd := Dati.distanze_strada(p, 1 if Dati.mare(cur) else 2, vietate)
		for k in dd:
			if k == cur or k in vietate or (k in uso and not (k in tane)) or k in out:
				continue
			if Dati.mare(cur) or k != cur:
				out.append(k)
	return out

func _hideout_depistabili() -> Array:
	var out := []
	var att := indice_attuale()
	for k in s["percorso"].size():
		var h: Dictionary = s["percorso"][k]
		if k == att or h["luogo"] == "" or h["luogo"] == "castello" or h["potere"] != "":
			continue
		if _nascondersi_di(k) >= 0:
			continue
		out.append(k)
	return out

func _p_movimento(_p: Dictionary) -> void:
	s["flag"]["inc_ok"] = false
	var opz := mosse_dracula()
	if opz.is_empty():
		_errore_dracula()
		return
	_chiedi(DRACULA, "movimento", "Fase di movimento: dove va Dracula? (ora a %s)" % Dati.nome(pos_dracula()), opz)

func _errore_dracula() -> void:
	_log("Dracula è in trappola e non può muoversi! Si rivela e subisce 5 danni.")
	var cur := pos_dracula()
	for h in s["percorso"]:
		if h["luogo"] != cur:
			_sgombera(h)
	s["percorso"] = [_nasc(cur)]
	s["percorso"][0]["riv"] = true
	s["dr"]["danni"] = int(s["dr"]["danni"]) + 5

func _d_movimento(_r: Dictionary, o: Dictionary) -> void:
	var id: String = o["id"]
	if id.begins_with("v:"):
		_dracula_va(id.substr(2), "")
		return
	var p := id.substr(2)
	match p:
		"nascondersi":
			var n := _nasc("", "nascondersi")
			s["percorso"].push_front(n)
			s["flag"]["inc_ok"] = true
			_furia()
			_log("Dracula gioca una carta coperta sul Percorso.")
		"nutrirsi":
			s["percorso"].push_front(_nasc("", "nutrirsi"))
			s["dr"]["danni"] = max(0, int(s["dr"]["danni"]) - 3)
			_log("Dracula gioca Nutrirsi e recupera 3 danni.")
		"richiamo":
			s["percorso"].push_front(_nasc("", "richiamo"))
			s["dr"]["danni"] = int(s["dr"]["danni"]) + 2
			for k in 5:
				_pesca_incontro()
			_log("Dracula gioca Richiamo Oscuro: subisce 2 danni e raduna 5 nuovi servitori.")
		"lupo":
			var opz := []
			for k in _dest_lupo(pos_dracula()):
				opz.append(_o(k, Dati.nome(k), {"luogo": k}))
			_chiedi(DRACULA, "lupo", "Forma del Lupo: dove corri?", opz)
		"depistaggio":
			var opz := []
			for k in _hideout_depistabili():
				opz.append(_o(k, "Spazio %d (%s)" % [k + 1, Dati.nome(s["percorso"][k]["luogo"])], {"luogo": s["percorso"][k]["luogo"]}))
			_chiedi(DRACULA, "depistaggio", "Depistaggio: quale nascondiglio cancelli?", opz)

func _furia() -> void:
	if int(s["disperazione"]) >= 3:
		s["influenza"] = int(s["influenza"]) + 3
		_log("La Furia di Dracula: con tutta la Disperazione sul tabellone l'Influenza sale di 3!")

func _dracula_va(dest: String, potere: String) -> void:
	var cur := pos_dracula()
	var danno := 0
	if potere == "":
		danno = _costo_mare(cur, dest)
	var tana_k := -1
	for k in s["tane"].size():
		if s["tane"][k]["luogo"] == dest:
			tana_k = k
	var n: Dictionary
	if tana_k >= 0:
		n = s["tane"][tana_k]
		s["tane"].remove_at(tana_k)
		n["esclusi"] = []
		_log("Dracula rientra in una delle sue tane.")
	else:
		n = _nasc(dest, potere)
	if potere != "":
		n["potere"] = potere
	s["percorso"].push_front(n)
	s["dr"]["ultimo"] = dest
	if danno > 0:
		s["dr"]["danni"] = int(s["dr"]["danni"]) + danno
		_log("Dracula attraversa il mare e subisce %d danni." % danno)
	if dest == "castello":
		s["dr"]["danni"] = max(0, int(s["dr"]["danni"]) - 5)
		n["riv"] = true
		_log("Dracula rientra al suo Castello e recupera 5 danni.")
	if not cacciatori_in(dest).is_empty():
		n["riv"] = true
		_log("Dracula entra apertamente a %s, dove si trovano dei cacciatori!" % Dati.nome(dest))
	elif not Dati.mare(dest):
		s["flag"]["inc_ok"] = true
	if not Dati.mare(dest):
		_furia()
	if not n["riv"]:
		n["esclusi"] = luoghi_cacciatori()
	if potere == "":
		_log("Dracula si sposta%s." % (" per mare" if Dati.mare(dest) else ""))

func _d_lupo(_r: Dictionary, o: Dictionary) -> void:
	s["dr"]["danni"] = int(s["dr"]["danni"]) + 1
	_log("Dracula assume la Forma del Lupo e corre nella notte (1 danno).")
	_dracula_va(o["id"], "lupo")

func _d_depistaggio(_r: Dictionary, o: Dictionary) -> void:
	var k := int(o["id"])
	var h: Dictionary = s["percorso"][k]
	_sgombera(h)
	s["percorso"][k] = _nasc("", "depistaggio")
	_log("Depistaggio: Dracula cancella le sue tracce sullo spazio %d." % (k + 1))
	var opz := []
	for x in mosse_dracula():
		if x["id"].begins_with("v:"):
			opz.append(x)
	if opz.is_empty():
		_errore_dracula()
		return
	_chiedi(DRACULA, "movimento", "Depistaggio: ora scegli dove va Dracula.", opz)

func _p_incontro(_p: Dictionary) -> void:
	_taglia_percorso()
	if not s["flag"].get("inc_ok", false) or s["dr"]["inc"].is_empty() or s["percorso"].is_empty():
		return
	_chiedi(DRACULA, "piazza_inc", "Fase di incontro: quale carta Incontro piazzi nel nuovo nascondiglio?", _opz_incontri_mano(), {"kk": 0})

func _d_piazza_inc(r: Dictionary, o: Dictionary) -> void:
	var k := int(r["kk"])
	if k >= s["percorso"].size():
		return
	_togli(s["dr"]["inc"], o["id"])
	s["percorso"][k]["inc"].append(_nuovo_inc(o["id"]))
	_log("Dracula lascia un incontro sul %d° spazio del Percorso." % (k + 1))

func _p_diceria(_p: Dictionary) -> void:
	if int(s["dicerie"]) <= 0:
		return
	var opz := [_o("no", "Non piazzarla ora (ne hai %d)" % s["dicerie"])]
	for k in min(3, s["percorso"].size()):
		var h: Dictionary = s["percorso"][k]
		if not h["inc"].is_empty() and not h["diceria"]:
			opz.append(_o(k, "Diceria sullo spazio %d" % (k + 1)))
	if opz.size() == 1:
		return
	_chiedi(DRACULA, "diceria", "Piazzi un segnalino Diceria su un nascondiglio con un Incontro?", opz)

func _d_diceria(_r: Dictionary, o: Dictionary) -> void:
	if o["id"] == "no":
		return
	s["percorso"][int(o["id"])]["diceria"] = true
	s["dicerie"] = int(s["dicerie"]) - 1
	_log("Dracula sparge una Diceria sul %d° spazio del Percorso." % (int(o["id"]) + 1))

# ============================================================ informazioni pubbliche

## Ciò che i cacciatori sanno di un nascondiglio: tipo di carta, luogo se rivelato, potere se visibile.
func pubblico(h: Dictionary) -> Dictionary:
	var out := {"tipo": tipo_carta(h), "luogo": h["luogo"] if (h["riv"] or h["luogo"] == "castello") else "",
		"potere": h["potere"] if potere_visibile(h) else "", "n_inc": h["inc"].size(), "diceria": h["diceria"], "esclusi": h["esclusi"]}
	if h["potere"] == "nascondersi" and not h["riv_p"]:
		out["tipo"] = "terra"
	var inc := []
	for e in h["inc"]:
		inc.append(e["id"] if e["riv"] else "")
	out["inc"] = inc
	return out
