# CHIRPS v3 giornaliero `rnl` in NetCDF: copia locale

**Lingue:** [English](README.md) | Italiano | [Español](README.es.md) | [Français](README.fr.md)

[`examples/download_chirps_daily_rnl_netcdf.sh`](../../examples/download_chirps_daily_rnl_netcdf.sh)
mantiene una copia locale del prodotto giornaliero CHIRPS v3 `rnl` (totali di
pentade ripartiti sui giorni con ERA5) in NetCDF, dal 1981 a oggi.

- Sorgente: `https://data.chc.ucsb.edu/products/CHIRPS/v3.0/daily/final/rnl/netcdf/byMonth/`
- Un file NetCDF per mese: circa 550 file, 25-30 GB in totale (stima; la
  prova a vuoto del passo 3 mostra il valore reale).
- Il download avviene in HTTPS, quindi la porta rsync (873) non serve.
- Non serve `sudo`.

## 1. Installare uv (una volta sola)

[uv](https://docs.astral.sh/uv/) gestisce l'ambiente Python di questo
progetto. Salta questo passo se `uv --version` risponde già.

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc
uv --version
```

## 2. Scaricare il repository e preparare l'ambiente

```bash
cd ~
git clone https://github.com/ecor/chc-data-download.git
cd chc-data-download
uv sync
```

`uv sync` crea un ambiente isolato in `.venv/` e installa le dipendenze
fissate nel lockfile. Non modifica il Python di sistema né gli ambienti conda.
Se il repository è già stato clonato, usa `git pull` al posto di `git clone`.

## 3. Scegliere la destinazione e fare una prova a vuoto

Per impostazione predefinita i file vanno in
`/home/wefe/local/data/precipitation/chirps/v3.0/daily/final/rnl/netcdf/byMonth/`.
Per usare un'altra cartella radice, imposta `CHIRPS_DATA`:

```bash
export CHIRPS_DATA=/percorso/di/chirps
```

Guarda il piano senza scaricare nulla:

```bash
bash examples/download_chirps_daily_rnl_netcdf.sh all --dry-run
```

Controlla il numero di file e la dimensione totale stampati alla fine.

## 4. Scaricare l'archivio completo in background

```bash
nohup bash examples/download_chirps_daily_rnl_netcdf.sh all --yes > ~/chirps_rnl_download.log 2>&1 &
```

`nohup` e `&` tengono attivo il download anche dopo la chiusura della sessione
SSH. `--yes` qui è obbligatorio, perché un processo in background non può
rispondere alla domanda di conferma prevista per i piani oltre 10 GB. Il
download dura qualche ora: lo strumento invia una richiesta alla volta.

Per partire da un anno successivo, scrivilo dopo `all`, per esempio
`all 2000 --yes`.

## 5. Controllare l'avanzamento

```bash
tail -f ~/chirps_rnl_download.log        # Ctrl-C chiude tail, non il download
pgrep -af download_chirps_daily_rnl      # è ancora in esecuzione?
du -sh "${CHIRPS_DATA:-/home/wefe/local/data/precipitation/chirps}"
```

## 6. Fermare e riprendere

```bash
pkill -f download_chirps_daily_rnl_netcdf.sh
```

Per riprendere, rilancia il comando del passo 4: i file completi vengono
saltati e quelli interrotti vengono riscaricati. Non cancellare la cartella di
destinazione per ricominciare da capo.

## 7. Aggiornamento mensile con cron

I dati definitivi di un mese compaiono di solito tra il 12 e il 18 del mese
successivo. Aggiungi questa riga con `crontab -e`:

```bash
30 3 12-20 * * bash $HOME/chc-data-download/examples/download_chirps_daily_rnl_netcdf.sh update >> $HOME/chirps_rnl_update.log 2>&1
```

`update` controlla solo i file degli ultimi 90 giorni. Se usi una destinazione
personalizzata, scrivi `CHIRPS_DATA=/percorso/di/chirps` prima di `bash` in
quella riga.

## Impostazioni

| Variabile | Significato | Valore predefinito |
| --- | --- | --- |
| `CHIRPS_DATA` | Cartella radice dell'archivio CHIRPS locale | `/home/wefe/local/data/precipitation/chirps` |
| `CHC_UA` | User-Agent che identifica le tue richieste a CHC | `ecor-chirps-mirror (https://github.com/ecor/chc-data-download)` |

Ogni altra opzione viene passata a `download-chc-data`, per esempio
`--dry-run`, `--yes` o `--max-bytes`.

## Rispettare il server CHC

Il server CHC blocca gli indirizzi che inviano più di circa due richieste al
secondo. Esegui una sola copia alla volta (lo script rifiuta di avviarne una
seconda), mantieni il ritardo predefinito e non lanciare l'aggiornamento in un
ciclo continuo. Vedi
[Downloading Politely](../../README.md#downloading-politely).

## Problemi frequenti

- **`uv: command not found`**: esegui `source ~/.bashrc` o apri un nuovo
  terminale.
- **`HTTP 429`, `HTTP 403` o timeout ripetuti**: il tuo indirizzo potrebbe
  essere stato bloccato. Ferma tutti i download verso CHC dalla tua rete,
  aspetta qualche ora e contatta CHC se il problema continua.
- **L'esecuzione si è interrotta**: rilancia lo stesso comando.
