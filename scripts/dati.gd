## Dati statici di La Furia di Dracula (terza edizione): mappa, personaggi, carte.
## La mappa (città, strade, ferrovie, mari) sta in assets/dati/mappa.json, generata da tools/genera_mappa.py.
class_name Dati
extends RefCounted

static var _mappa: Dictionary = {}

static func mappa() -> Dictionary:
	if _mappa.is_empty():
		var f := FileAccess.open("res://assets/dati/mappa.json", FileAccess.READ)
		_mappa = JSON.parse_string(f.get_as_text())
	return _mappa

static func luoghi() -> Dictionary:
	return mappa()["luoghi"]

static func L(id: String) -> Dictionary:
	return luoghi()[id]

static func nome(id: String) -> String:
	if id == "":
		return "?"
	if luoghi().has(id):
		return L(id)["nome"]
	return id

static func mare(id: String) -> bool:
	return luoghi().has(id) and bool(L(id)["mare"])

static func citta() -> Array:
	var out := []
	for k in luoghi():
		if not L(k)["mare"]:
			out.append(k)
	return out

static func porto(id: String) -> bool:
	return not mare(id) and not (L(id)["porti"] as Array).is_empty()

static func regione(id: String) -> int:
	return int(L(id)["regione"])

static func nome_regione(r: int) -> String:
	return str(mappa()["regioni"].get(str(r), "?"))

## Città collegate da una strada.
static func strade(id: String) -> Array:
	return L(id)["adiac"]

## Distanze in strade da una città (BFS), fino a max_d. Restituisce {città: distanza}.
static func distanze_strada(da: String, max_d: int, vietate: Array = []) -> Dictionary:
	var d := {da: 0}
	var coda := [da]
	while not coda.is_empty():
		var c: String = coda.pop_front()
		if d[c] >= max_d:
			continue
		for n in strade(c):
			if d.has(n) or n in vietate:
				continue
			d[n] = d[c] + 1
			coda.append(n)
	return d

## Distanza in strade fra due città (99 se irraggiungibili).
static func dist(a: String, b: String) -> int:
	if a == b:
		return 0
	var d := distanze_strada(a, 30)
	return int(d.get(b, 99))

## Distanza "di viaggio" (strade + mare) usata dall'IA per stimare i percorsi.
static var _dv: Dictionary = {}
static func dist_viaggio(a: String, b: String) -> int:
	var k := a + "|" + b
	if _dv.has(k):
		return _dv[k]
	var d := {a: 0}
	var coda := [a]
	while not coda.is_empty():
		var c: String = coda.pop_front()
		var vic: Array = []
		vic.append_array(L(c)["adiac"])
		vic.append_array(L(c)["porti"])
		for f in L(c)["fer"]:
			vic.append(f[0])
		for n in vic:
			if d.has(n):
				continue
			d[n] = d[c] + 1
			coda.append(n)
	for n in d:
		_dv[a + "|" + n] = d[n]
	return int(d.get(b, 99))

# ============================================================ personaggi

const CACCIATORI := [
	{"id": "godalming", "nome": "Lord Godalming", "breve": "Godalming", "vita": 11, "morsi": 1, "max_ev": 3, "max_ogg": 3,
	 "abilita": "Ricchezza: col Rifornimento in una grande città pesca 2 carte Oggetto. Privilegi: prenotando un biglietto ne ottiene 2."},
	{"id": "seward", "nome": "Dr. John Seward", "breve": "Seward", "vita": 9, "morsi": 1, "max_ev": 4, "max_ogg": 4,
	 "abilita": "Medico: chi riposa nella sua città recupera 2 danni. Attrezzato: fino a 4 carte Oggetto e 4 Evento."},
	{"id": "vanhelsing", "nome": "Van Helsing", "breve": "Van Helsing", "vita": 8, "morsi": 2, "max_ev": 3, "max_ogg": 3,
	 "abilita": "Leader: negli scambi può scambiare carte Evento con un cacciatore in qualsiasi città. Risoluto: ha due spazi Morso."},
	{"id": "mina", "nome": "Mina Harker", "breve": "Mina", "vita": 9, "morsi": 1, "max_ev": 3, "max_ogg": 3,
	 "abilita": "Legame psichico: nella stessa città di un altro cacciatore, come azione obbliga Dracula a svelare la sua regione. Dissanguata: ha sempre un Morso ed è sempre indebolita."},
]
const VITA_DRACULA := 15

# ============================================================ carte

## Icone di combattimento: zanne, forza, artigli, mesmerismo, macchinazione, pipistrello, nebbia.
const ICONE := ["zanne", "forza", "artigli", "mesmerismo", "macchinazione", "pipistrello", "nebbia"]

## Carte combattimento di Dracula (13).
const COMB_DRACULA := {
	"denti": {"nome": "Denti Aguzzi", "icona": "zanne", "n": 2, "testo": "Recuperi 2 danni e il cacciatore da combattere subisce 2 danni. Di notte, se è mesmerizzato, invece è morso ed esce dal combattimento (+1 Influenza)."},
	"nebbia": {"nome": "Fuggire come Nebbia", "icona": "nebbia", "n": 1, "testo": "Il combattimento termina (Orgoglio)."},
	"pipistrello": {"nome": "Fuggire come Pipistrello", "icona": "pipistrello", "n": 2, "testo": "Il combattimento termina. Di notte Dracula può fuggire in segreto in una città fino a 2 strade di distanza."},
	"macchinazione": {"nome": "Macchinazione", "icona": "macchinazione", "n": 2, "testo": "Scegli 1 carta dal mazzo Combattimento e prendila in mano. Resta scoperta: può annullare Pugno, Schivare o Fuggire del cacciatore."},
	"artigli": {"nome": "Artigli", "icona": "artigli", "n": 2, "testo": "Il cacciatore da combattere subisce 2 danni. Di notte anche un altro cacciatore coinvolto subisce 2 danni."},
	"forza": {"nome": "Forza", "icona": "forza", "n": 2, "testo": "Il cacciatore da combattere subisce 2 danni. Annulla Pugno, Crocifisso o un'Arma; di notte quella carta è scartata."},
	"mesmerismo": {"nome": "Mesmerismo", "icona": "mesmerismo", "n": 2, "testo": "Annulla la carta del cacciatore da combattere, che resta mesmerizzato: le sue Armi fanno 1 danno in meno."},
}

## Carte combattimento dei cacciatori (una di ciascuna per cacciatore).
const COMB_CACCIATORE := {
	"pugno": {"nome": "Pugno", "icone": ["mesmerismo", "macchinazione"], "danni": 1, "testo": "Il vampiro subisce 1 danno."},
	"schivare": {"nome": "Schivare", "icone": ["zanne", "forza", "artigli"], "danni": 0, "testo": "Nessun effetto, ma annulla Denti Aguzzi, Forza e Artigli."},
	"fuggire": {"nome": "Fuggire", "icone": ["forza", "macchinazione"], "danni": 0, "testo": "Esci da questo combattimento."},
}

## Carte Oggetto (38).
const OGGETTI := {
	"cavalli": {"nome": "Cavalli Veloci", "n": 3, "icone": [], "testo": "Di giorno, come azione: rivela un biglietto dalla riserva e muovi di tante strade quanto il suo numero giallo (se non c'è, 1 strada e scarti la carta)."},
	"cerchio": {"nome": "Cerchio Sacro", "n": 2, "icone": ["zanne", "forza", "artigli", "mesmerismo", "macchinazione", "pipistrello", "nebbia"], "testo": "In combattimento: annulla qualsiasi carta di Dracula; tu esci dal combattimento. Poi scarta questa carta."},
	"aglio": {"nome": "Aglio", "n": 3, "icone": ["zanne", "forza"], "testo": "Se Dracula ha giocato Denti Aguzzi o Artigli contro di te, il vampiro subisce 2 danni."},
	"ostia": {"nome": "Ostia Consacrata", "n": 3, "icone": ["mesmerismo"], "testo": "Il vampiro subisce 4 danni (ma se Dracula ha giocato Denti Aguzzi sei morso ed esci). Poi scarta questa carta."},
	"pistola": {"nome": "Pistola", "n": 4, "icone": ["artigli", "macchinazione"], "arma": true, "danni": 2, "testo": "Arma. Il vampiro subisce 2 danni."},
	"fucile": {"nome": "Fucile", "n": 4, "icone": ["artigli", "pipistrello"], "arma": true, "danni": 2, "testo": "Arma. Il vampiro subisce 2 danni."},
	"cani": {"nome": "Cani", "n": 4, "icone": [], "testo": "Prima di una ricerca scarta Ratti, Sabotatore, Spia o Lupi rivelati; se subisci un'imboscata da quelle carte, puoi scartare questa e quella."},
	"ghirlanda": {"nome": "Ghirlanda d'Aglio", "n": 3, "icone": [], "testo": "Rivelala a inizio combattimento: dopo che subisci danni da Denti Aguzzi il vampiro subisce 4 danni. Scartata se Dracula risolve Artigli, o a fine combattimento."},
	"coltello": {"nome": "Coltello", "n": 3, "icone": ["zanne", "pipistrello"], "arma": true, "danni": 3, "testo": "Arma. Il vampiro subisce 3 danni."},
	"proiettili": {"nome": "Proiettili Consacrati", "n": 3, "icone": [], "testo": "Dopo una Pistola o un Fucile il vampiro subisce 3 danni in più (1 volta per combattimento). Poi scartala."},
	"paletto": {"nome": "Paletto di Frassino", "n": 4, "icone": [], "testo": "Prima di una ricerca: se riveli un vampiro o un Raggiro, scarta questa carta e quella."},
	"crocifisso": {"nome": "Crocifisso", "n": 2, "icone": ["zanne", "mesmerismo", "nebbia"], "testo": "Se annulla Denti Aguzzi o Mesmerismo, il vampiro subisce 3 danni."},
}

## Carte Incontro (28).
const INCONTRI := {
	"szgany": {"nome": "Banda di Szgany", "n": 2, "testo": "Ogni cacciatore in questa città può scartare carte Oggetto, poi subisce 1 danno per ogni Oggetto in mano.", "consolidato": "Rivela il luogo e risolvi l'effetto in ogni città della regione."},
	"raggiro": {"nome": "Raggiro", "n": 2, "no_imboscata": true, "testo": "Il cacciatore è trattenuto.", "consolidato": "Dracula riprende 1 carta Evento di Dracula dagli scarti e rimescola le altre nel mazzo."},
	"temerario": {"nome": "Vampiro Temerario", "n": 3, "vampiro": true, "vita": 4, "testo": "Il cacciatore combatte questo vampiro (4 vita). Ogni Denti Aguzzi in un'imboscata: +1 Influenza.", "consolidato": "+4 Influenza; sgombera questo nascondiglio e quelli sul 4°, 5° e 6° spazio."},
	"lupi": {"nome": "Lupi", "n": 2, "testo": "Ogni cacciatore in questa città subisce 4 danni, 2 in meno per ogni Arma che rivela.", "consolidato": "Rivela il luogo e risolvi l'effetto in una città a 2 strade al massimo."},
	"aristocratico": {"nome": "Vampiro Aristocratico", "n": 3, "vampiro": true, "no_imboscata": true, "testo": "Per scartarla il cacciatore deve restare trattenuto, altrimenti resta qui scoperta.", "consolidato": "+4 Influenza; sgombera questo nascondiglio e quelli sul 4°, 5° e 6° spazio."},
	"guardie": {"nome": "Guardie del Corpo Szgany", "n": 2, "testo": "Il cacciatore subisce 2 danni; poi altri 2 danni ed è trattenuto, a meno che non riveli un'Arma.", "consolidato": "Dracula la tiene: all'alba o al tramonto, prima di un combattimento, la usa contro un cacciatore nella sua città."},
	"sconsacrato": {"nome": "Terreno Sconsacrato", "n": 2, "testo": "Dracula pesca 3 carte Incontro e ne scarta fino a 3. La carta resta qui scoperta, a meno che il cacciatore non riveli un'Ostia Consacrata.", "consolidato": "Dracula recupera fino a 3 danni."},
	"nebbia": {"nome": "Nebbia Innaturale", "n": 2, "testo": "Nebbia su questa città (2 se è un porto): non si entra né si esce. Se è giorno, i cacciatori qui sono trattenuti.", "consolidato": "Rivela il luogo: 2 segnalini Nebbia su una città della regione."},
	"nuovo": {"nome": "Nuovo Vampiro", "n": 2, "vampiro": true, "vita": 6, "testo": "Il cacciatore combatte questo vampiro (6 vita); gli altri cacciatori qui possono unirsi restando trattenuti.", "consolidato": "+3 Influenza; sgombera questo nascondiglio e quelli sul 4°, 5° e 6° spazio."},
	"ratti": {"nome": "Ratti", "n": 2, "testo": "Il cacciatore subisce 2 danni. La carta resta qui scoperta, a meno che non riveli una Pistola o un Fucile."},
	"sabotatore": {"nome": "Sabotatore", "n": 2, "testo": "Il cacciatore è trattenuto. La carta resta qui scoperta, a meno che non riveli una Pistola o un Fucile.", "consolidato": "Dracula piazza un segnalino Strada Bloccata."},
	"spia": {"nome": "Spia", "n": 2, "testo": "Il cacciatore rivela le sue carte e scarta i Biglietti (può scartare un'Arma per evitarlo).", "consolidato": "Risolvi l'effetto contro un cacciatore a scelta."},
	"pipistrelli": {"nome": "Pipistrelli", "n": 2, "testo": "Segnalino Pipistrelli: alla prossima azione Dracula sposta il cacciatore in una città adiacente, poi è trattenuto."},
}

## Carte Evento dei cacciatori (50) e di Dracula (25). quando: momento in cui si giocano.
const EVENTI := {
	# --- cacciatori
	"giornali": {"nome": "Notizie dai Giornali", "n": 3, "d": false, "quando": "subito_o_alba", "testo": "Subito: rivela il luogo sul 3° spazio del Percorso. All'alba o al tramonto: rivela quello sul 5° o 6° spazio."},
	"grande_forza": {"nome": "Grande Forza", "n": 1, "d": false, "quando": "reazione", "testo": "Quando un cacciatore sta per essere morso o sconfitto da un danno: quel morso o quel danno è impedito."},
	"buona_fortuna": {"nome": "Buona Fortuna", "n": 2, "d": false, "quando": "giorno", "testo": "Di giorno: rimuovi una Strada Bloccata oppure scarta l'alleato di Dracula."},
	"avvertito": {"nome": "Avvertito in Tempo", "n": 2, "d": false, "quando": "reazione", "testo": "Quando subisci un'imboscata da un incontro che non è un vampiro: scartalo senza effetti."},
	"imboscata": {"nome": "Imboscata Pianificata", "n": 2, "d": false, "quando": "combattimento", "testo": "A inizio combattimento: nel primo round, viste le carte, puoi cambiare la tua."},
	"cilindri": {"nome": "Cilindri di Cera", "n": 1, "d": false, "quando": "azione", "solo": 1, "testo": "Solo Seward, come azione. Deduzione: Dracula rivela gli incontri di un nascondiglio. Analisi: rivela dove ha giocato Nascondersi. Poi la riprendi in mano."},
	"ritorno": {"nome": "Ritorno a Sorpresa", "n": 2, "d": false, "quando": "alba", "testo": "All'alba o al tramonto: riprendi dagli scarti una carta con effetto Alleato e risolvila."},
	"ricerca_mistica": {"nome": "Ricerca Mistica", "n": 1, "d": false, "quando": "azione", "solo": 2, "testo": "Solo Van Helsing, come azione: guarda le ultime 6 carte del mazzo Eventi e scarta quelle di Dracula."},
	"lucy": {"nome": "La Vendetta di Lucy", "n": 1, "d": false, "quando": "combattimento", "solo": 0, "testo": "Solo Godalming, a inizio combattimento: annulla un Fuggire come Pipistrello o Nebbia, oppure evita un morso o un danno che ti sconfiggerebbe."},
	"senso": {"nome": "Senso di Emergenza", "n": 2, "d": false, "quando": "azione_giorno", "testo": "Come azione di giorno: subisci 2 danni e spostati in una città fino a 3 strade di distanza."},
	"carrozza": {"nome": "Carrozza Riservata", "n": 3, "d": false, "quando": "treno", "testo": "Prima di un viaggio in treno: con un biglietto ti sposti fino a 4 ferrovie."},
	"agatha": {"nome": "Suor Agatha", "n": 1, "d": false, "quando": "subito", "alleato": true, "testo": "Subito: Dracula rivela la carta Luogo di una città a scelta. Alleato: quando Dracula risolve Fuggire come Pipistrello o Nebbia o Denti Aguzzi subisce 2 danni."},
	"rufus": {"nome": "Rufus Smith", "n": 1, "d": false, "quando": "subito", "alleato": true, "testo": "Subito: Dracula rivela la carta Luogo di una città a scelta. Alleato: quando Dracula va per mare da un mare all'altro subisce 2 danni invece di 1."},
	"lunga_notte": {"nome": "Lunga Notte", "n": 2, "d": false, "quando": "alba", "testo": "All'alba: nella prossima notte i cacciatori possono muoversi su strada, pescando ogni volta 1 carta dal fondo del mazzo Eventi (se è dei cacciatori va scartata)."},
	"scoperta": {"nome": "Scoperta Fortunata", "n": 1, "d": false, "quando": "combattimento", "testo": "A inizio combattimento: guarda le prime 5 carte Oggetto, prendine 1 e scarta le altre."},
	"denaro": {"nome": "Tracce di Denaro", "n": 1, "d": false, "quando": "azione", "testo": "Come azione: Dracula rivela tutte le carte Luogo di mare del suo Percorso."},
	"via_fuga": {"nome": "Via di Fuga", "n": 2, "d": false, "quando": "combattimento", "testo": "A inizio combattimento: tu o un altro cacciatore uscite dal combattimento."},
	"tempo_sereno": {"nome": "Tempo Sereno", "n": 2, "d": false, "quando": "azione_giorno", "testo": "Come azione di giorno: spostati per mare due volte."},
	"harker": {"nome": "Jonathan Harker", "n": 1, "d": false, "quando": "subito", "alleato": true, "testo": "Subito: Dracula rivela la carta Luogo di una città a scelta. Alleato: quando un nascondiglio scivola sul 6° spazio, la sua carta Luogo è rivelata."},
	"slancio": {"nome": "Slancio Eroico", "n": 1, "d": false, "quando": "combattimento", "testo": "A inizio combattimento: invece di combattere, il vampiro subisce 5 danni e tu subisci 5 danni."},
	"velo": {"nome": "Dietro il Velo", "n": 1, "d": false, "quando": "subito", "testo": "Subito: Dracula rivela i suoi Eventi e gli Incontri in mano; scegli 1 Incontro da scartare."},
	"tana": {"nome": "Tana del Vampiro", "n": 1, "d": false, "quando": "azione_giorno", "testo": "Come azione di giorno: scarta un Paletto di Frassino e resti trattenuto: l'Influenza indietreggia di 2."},
	"vigore": {"nome": "Ritrovato Vigore", "n": 2, "d": false, "quando": "alba", "testo": "All'alba: in questo giorno ogni cacciatore può fare 1 azione in più (non la stessa due volte)."},
	"trasfusione": {"nome": "Trasfusione di Sangue", "n": 2, "d": false, "quando": "azione", "testo": "Come azione, se non sei indebolito: un cacciatore indebolito nella tua città toglie 1 Morso, tu subisci 1 danno."},
	"terreno": {"nome": "Terreno Consacrato", "n": 1, "d": false, "quando": "azione_notte", "testo": "Come azione di notte: Terreno Consacrato su una città (non Castello Dracula, Galati o Klausenburg); scartando un'Ostia anche la Schiera Celeste su un'altra."},
	"esploratori": {"nome": "Esploratori al Proprio Servizio", "n": 4, "d": false, "quando": "subito", "testo": "Subito: scegli 2 città; Dracula rivela le carte Luogo di quelle città."},
	"telegrammi": {"nome": "Telegrammi Veloci", "n": 2, "d": false, "quando": "alba", "testo": "All'alba: in questo turno i cacciatori agiscono in qualsiasi ordine."},
	"presenza": {"nome": "Presenza Malvagia", "n": 2, "d": false, "quando": "subito", "testo": "Subito: Dracula dice quali cacciatori sono adiacenti alla sua posizione."},
	"ipnosi": {"nome": "Ipnosi", "n": 1, "d": false, "quando": "azione", "solo": 3, "testo": "Solo Mina, come azione nella città di un altro cacciatore: Dracula dice in che regione si trova; poi Mina è trattenuta."},
	"voci": {"nome": "Voci del Luogo", "n": 2, "d": false, "quando": "subito", "testo": "Subito: Dracula rivela le carte Luogo dei nascondigli adiacenti alla sua posizione."},
	# --- Dracula
	"seduzione": {"nome": "Seduzione", "n": 1, "d": true, "quando": "ricerca", "testo": "Quando un cacciatore cerca dove c'è un vampiro: invece di risolvere l'incontro il cacciatore è morso e Dracula riprende la carta."},
	"spose": {"nome": "Spose di Dracula", "n": 1, "d": true, "quando": "subito", "alleato": true, "testo": "Subito: piazza 1 Incontro su fino a 2 nascondigli dei primi 3 spazi. Alleato: a inizio turno puoi cambiare 1 Incontro."},
	"tempeste": {"nome": "Evocare Tempeste", "n": 2, "d": true, "quando": "fine_turno", "testo": "Subito o a fine turno: fino a 3 segnalini Tempesta sui mari; i cacciatori non vi entrano."},
	"strada_bloccata": {"nome": "Strada Bloccata", "n": 3, "d": true, "quando": "fine_turno", "testo": "Subito o a fine turno: 3 segnalini Strada Bloccata su strade o ferrovie."},
	"visita": {"nome": "Visita Notturna", "n": 1, "d": true, "quando": "fine_turno", "testo": "A fine turno: i combattimenti dell'alba e del giorno si risolvono come se fosse notte."},
	"indicazioni": {"nome": "Indicazioni False", "n": 2, "d": true, "quando": "biglietto", "testo": "Quando un cacciatore spende un biglietto: annulla Carrozza Riservata, altrimenti decidi tu dove arriva."},
	"cavalli_impazziti": {"nome": "Cavalli Impazziti", "n": 2, "d": true, "quando": "strada", "testo": "Dopo che un cacciatore si sposta su strada: spostalo in una città adiacente."},
	"influsso": {"nome": "Influsso Vampirico", "n": 2, "d": true, "quando": "subito", "testo": "Subito: un cacciatore indebolito rivela le carte; Dracula ne scarta 1 e lo sposta in una città adiacente."},
	"trame": {"nome": "Trame Nascoste", "n": 2, "d": true, "quando": "fine_turno", "testo": "A fine turno: piazza 1 Incontro sul nascondiglio del 3° spazio."},
	"furioso": {"nome": "Furioso", "n": 1, "d": true, "quando": "annullata", "testo": "Quando una tua carta Combattimento sta per essere annullata: non lo è (ma niente fughe in questo combattimento)."},
	"oscurita": {"nome": "L'Oscurità Ritorna", "n": 1, "d": true, "quando": "fine_turno", "testo": "A fine turno: niente giorno nel prossimo turno dei cacciatori; gli Eventi di Dracula scartati tornano nel mazzo."},
	"grande_lupo": {"nome": "Grande Lupo", "n": 1, "d": true, "quando": "subito", "alleato": true, "testo": "Subito: un cacciatore subisce 4 danni (se non rivela Crocifisso o Ostia). Alleato: a inizio turno 1 danno a un cacciatore."},
	"hildesheim": {"nome": "Immanuel Hildesheim", "n": 1, "d": true, "quando": "subito", "alleato": true, "testo": "Subito: guarda le prime 6 carte Evento, prendi quelle di Dracula. Alleato: a inizio turno se la prima carta è di Dracula la prendi."},
	"stampa": {"nome": "Stampa Sensazionalista", "n": 1, "d": true, "quando": "reazione", "testo": "Annulla Voci del Luogo, Esploratori, Notizie dai Giornali o Presenza Malvagia."},
	"velocita": {"nome": "Velocità Disumana", "n": 1, "d": true, "quando": "turno", "testo": "Nel tuo turno: dopo questo turno ne giochi subito un altro."},
	"dogana": {"nome": "Ispezione Doganale", "n": 1, "d": true, "quando": "regione", "testo": "Dopo che un cacciatore passa in un'altra regione: è trattenuto e scarta tutti gli Oggetti o subisce 3 danni."},
	"potere_diabolico": {"nome": "Potere Diabolico", "n": 2, "d": true, "quando": "turno", "testo": "Nel tuo turno: togli un Terreno Consacrato, oppure scarta l'alleato dei cacciatori, oppure niente rifornimento nel prossimo turno."},
}

## Carte Potere di Dracula.
const POTERI := {
	"nascondersi": {"nome": "Nascondersi", "testo": "Resti dove sei; la carta va coperta sul Percorso e vi si piazza un Incontro."},
	"lupo": {"nome": "Forma del Lupo", "testo": "Ti sposti in una città fino a 2 strade di distanza; subisci 1 danno."},
	"richiamo": {"nome": "Richiamo Oscuro", "testo": "Subisci 2 danni e peschi 5 carte Incontro."},
	"nutrirsi": {"nome": "Nutrirsi", "testo": "Recuperi 3 danni."},
	"depistaggio": {"nome": "Depistaggio", "testo": "Sgomberi un nascondiglio del Percorso e al suo posto metti Depistaggio; poi ti muovi normalmente."},
}

## Biglietti: [valore bianco, valore giallo] (0 = nessun numero giallo).
## Distribuzione dei 16 biglietti presa dal sacchetto del modulo TTS.
const BIGLIETTI := [[1, 0], [1, 0], [1, 0], [1, 1], [1, 1], [2, 1], [2, 1], [2, 1], [2, 2], [2, 2], [2, 2], [2, 2], [3, 2], [3, 2], [3, 2], [3, 2]]

static func img_biglietto(b: Array) -> String:
	if int(b[1]) == 0:
		return "res://assets/segnalini/biglietto_1.webp"
	return "res://assets/segnalini/biglietto_%d_%d.webp" % [int(b[0]), int(b[1])]

static func nome_carta(tipo: String, id: String) -> String:
	match tipo:
		"oggetto": return OGGETTI[id]["nome"]
		"evento": return EVENTI[id]["nome"]
		"incontro": return INCONTRI[id]["nome"]
		"comb": return COMB_DRACULA[id]["nome"] if COMB_DRACULA.has(id) else COMB_CACCIATORE[id]["nome"]
		"potere": return POTERI[id]["nome"]
	return id

static func img(tipo: String, id: String) -> String:
	match tipo:
		"oggetto": return "res://assets/carte/oggetti/%s.webp" % id
		"evento": return "res://assets/carte/eventi/%s.webp" % id
		"incontro": return "res://assets/carte/incontri/%s.webp" % id
		"comb": return "res://assets/carte/combattimento/%s.webp" % id
		"potere": return "res://assets/carte/potere/%s.webp" % id
		"luogo": return "res://assets/carte/luoghi/%s.webp" % id
	return ""

const GIORNI := ["Lunedì", "Martedì", "Mercoledì", "Giovedì", "Venerdì", "Sabato", "Domenica"]
