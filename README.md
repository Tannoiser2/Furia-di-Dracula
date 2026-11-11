# La Furia di Dracula - versione digitale

Versione digitale non ufficiale, per uso personale, di **La Furia di Dracula** (terza edizione, Fantasy Flight Games,
edizione italiana Asmodee), il gioco semicooperativo di caccia al Conte nell'Europa del 1898.

Si gioca qui: https://tannoiser2.github.io/Furia-di-Dracula/

## Cosa c'è

- **Regole complete** della terza edizione: turno dei cacciatori con alba, giorno, tramonto e notte; movimento su strada,
  in treno (biglietti con valore bianco e giallo, ferrovie bianche e gialle) e per mare; prenotazione dei biglietti,
  riposo, ricerca, rifornimento (Oggetti nelle grandi città, Eventi dalla cima o dal fondo del mazzo), scambi.
- **Il Percorso di Dracula** con sei spazi, carte coperte (dorso diverso per i mari e il Castello), imboscate,
  incontri che maturano o diventano **tane**, Dicerie, segnalini Disperazione settimanali e l'abilità «La Furia di Dracula».
- **Poteri** di Dracula: Nascondersi, Forma del Lupo, Richiamo Oscuro, Nutrirsi, Depistaggio.
- **Combattimento** con le icone sugli stendardi, Orgoglio (fughe annullate se arrivano troppo presto), Mesmerismo,
  Macchinazione, morsi notturni, i vampiri degli incontri con la loro vita.
- **Tutte le carte** in italiano dal modulo di Tabletop Simulator: 38 Oggetti, 75 Eventi (50 dei cacciatori, 25 di Dracula),
  28 Incontri, 13 carte Combattimento di Dracula, 12 dei cacciatori, 70 Luoghi, i 5 Poteri.
- **I quattro cacciatori** con le loro abilità: Lord Godalming (Ricchezza, Privilegi), Dr. Seward (Medico, Attrezzato),
  Van Helsing (Leader, Risoluto), Mina Harker (Legame psichico, Dissanguata).
- **IA** per Dracula (si tiene lontano dai cacciatori, semina vampiri dove matureranno, fugge quando è ferito) e per i
  cacciatori (deducono dal Percorso pubblico dove può essere Dracula senza sbirciare i segreti, si dividono le zone).
- **Online** con gli amici: stanze con codice di 4 lettere su Firebase; chi crea la stanza fa Dracula o i cacciatori,
  i ruoli liberi li guida l'IA. **Salvataggio** delle partite contro l'IA sul dispositivo e su Firebase.

### Scelte dei giocatori

Tutte le scelte previste dalle regole le fa chi gioca (o l'IA al suo posto): quali Oggetti gettare alla Banda di Szgany,
chi fa uscire il Cerchio Sacro, l'ordine degli incontri trovati con una ricerca, Cani e Paletto di Frassino prima della
ricerca, i Cani contro un'imboscata, la Ghirlanda d'Aglio a inizio combattimento, i Proiettili Consacrati, Grande Forza e
la Vendetta di Lucy, la Macchinazione scoperta e Furioso per Dracula, quali effetti maturati risolvere, quale Strada
Bloccata e quale Tempesta togliere al tramonto, l'ospedale in caso di parità, se tenere un biglietto appena pescato.
I cacciatori indeboliti tengono scoperte una carta Oggetto e una Evento, visibili anche a Dracula.
Al tramonto si toglie un segnalino Nebbia da ogni città e la Schiera Celeste; i segnalini hanno i limiti della scatola
(4 Nebbia, 6 Tempesta, 8 Strada Bloccata, 4 Dicerie). I 16 biglietti hanno la distribuzione del sacchetto del modulo TTS.

## Struttura

- `scripts/motore.gd` – le regole: tutto lo stato in un dizionario, una pila di passi e decisioni numerate
  (stessa sequenza = stessa partita, così funziona l'online).
- `scripts/ia.gd` – l'intelligenza artificiale (deduzione dei cacciatori, strategia di Dracula).
- `scripts/dati.gd` – personaggi e testi delle carte; `assets/dati/mappa.json` – città, strade, ferrovie e mari.
- `scripts/mappa.gd` – il tabellone con zoom e trascinamento; `scripts/main.gd` – menu e interfaccia; `scripts/rete.gd` – Firebase.
- `tools/estrai_tts.py` – estrae tabellone, carte e segnalini dal modulo TTS; `tools/mappa_dati.py` e
  `tools/genera_mappa.py` – i collegamenti della mappa; `tools/overlay.py` li disegna sul tabellone per controllarli.
- `tools/controlla_glifi.py` – controlla che ogni carattere dei testi esista nei font.
- `firebase/database.rules.json` – regole del database (radice `furiadracula`, da unire a quelle del progetto condiviso).

## Prove

```
godot --headless --path . -s res://tests/sim.gd -- 40          # 40 partite tutte IA
xvfb-run godot --path . -s res://tests/foto.gd -- partita 60    # screenshot dell'interfaccia
python3 tests/firebase_mock.py 8765 &                           # finto Firebase per la prova online (tests/online_auto.gd)
```

## Pubblicazione

Il workflow `Pubblica` parte a mano (Actions → Pubblica → Run workflow) oppure con un commit che contiene `[pubblica]`:
pubblica su GitHub Pages e, con i segreti `CLOUDFLARE_API_TOKEN` e `CLOUDFLARE_ACCOUNT_ID`, anche sulla ludoteca privata.
