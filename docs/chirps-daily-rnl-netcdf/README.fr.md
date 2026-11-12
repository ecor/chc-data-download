# CHIRPS v3 journalier `rnl` en NetCDF : copie locale

**Langues :** [English](README.md) | [Italiano](README.it.md) | [Español](README.es.md) | Français

[`examples/download_chirps_daily_rnl_netcdf.sh`](../../examples/download_chirps_daily_rnl_netcdf.sh)
maintient une copie locale du produit journalier CHIRPS v3 `rnl` (totaux de
pentade répartis sur les jours avec ERA5) en NetCDF, de 1981 à aujourd'hui.

- Source : `https://data.chc.ucsb.edu/products/CHIRPS/v3.0/daily/final/rnl/netcdf/byMonth/`
- Un fichier NetCDF par mois : environ 550 fichiers, 25 à 30 Go au total
  (estimation ; l'essai à blanc de l'étape 3 donne la valeur réelle).
- Le téléchargement passe par HTTPS : le port rsync (873) n'est pas nécessaire.
- `sudo` n'est pas nécessaire.

## 1. Installer uv (une seule fois)

[uv](https://docs.astral.sh/uv/) gère l'environnement Python de ce projet.
Passez cette étape si `uv --version` répond déjà.

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc
uv --version
```

## 2. Récupérer le dépôt et préparer l'environnement

```bash
cd ~
git clone https://github.com/ecor/chc-data-download.git
cd chc-data-download
uv sync
```

`uv sync` crée un environnement isolé dans `.venv/` et installe les
dépendances figées dans le lockfile. Il ne modifie ni le Python du système ni
les environnements conda. Si le dépôt est déjà cloné, utilisez `git pull` à la
place de `git clone`.

## 3. Choisir la destination et faire un essai à blanc

Par défaut, les fichiers vont dans
`/home/wefe/local/data/precipitation/chirps/v3.0/daily/final/rnl/netcdf/byMonth/`.
Pour utiliser un autre dossier racine, définissez `CHIRPS_DATA` :

```bash
export CHIRPS_DATA=/chemin/vers/chirps
```

Affichez le plan sans rien télécharger :

```bash
bash examples/download_chirps_daily_rnl_netcdf.sh all --dry-run
```

Vérifiez le nombre de fichiers et la taille totale affichés à la fin.

## 4. Télécharger l'archive complète en arrière-plan

```bash
nohup bash examples/download_chirps_daily_rnl_netcdf.sh all --yes > ~/chirps_rnl_download.log 2>&1 &
```

`nohup` et `&` maintiennent le téléchargement actif après la fermeture de la
session SSH. `--yes` est obligatoire ici, car un processus en arrière-plan ne
peut pas répondre à la question de confirmation posée pour les plans de plus
de 10 Go. Le téléchargement dure quelques heures : l'outil envoie une requête
à la fois.

Pour commencer à une année plus récente, indiquez-la après `all`, par exemple
`all 2000 --yes`.

## 5. Suivre l'avancement

```bash
tail -f ~/chirps_rnl_download.log        # Ctrl-C ferme tail, pas le téléchargement
pgrep -af download_chirps_daily_rnl      # est-il encore en cours ?
du -sh "${CHIRPS_DATA:-/home/wefe/local/data/precipitation/chirps}"
```

## 6. Arrêter et reprendre

```bash
pkill -f download_chirps_daily_rnl_netcdf.sh
```

Pour reprendre, relancez la commande de l'étape 4 : les fichiers complets sont
ignorés et les fichiers interrompus sont téléchargés de nouveau. Ne supprimez
pas le dossier de destination pour repartir de zéro.

## 7. Mise à jour mensuelle avec cron

Les données définitives d'un mois paraissent en général entre le 12 et le 18
du mois suivant. Ajoutez cette ligne avec `crontab -e` :

```bash
30 3 12-20 * * bash $HOME/chc-data-download/examples/download_chirps_daily_rnl_netcdf.sh update >> $HOME/chirps_rnl_update.log 2>&1
```

`update` ne vérifie que les fichiers des 90 derniers jours. Si vous utilisez
une destination personnalisée, écrivez `CHIRPS_DATA=/chemin/vers/chirps` avant
`bash` dans cette ligne.

## Réglages

| Variable | Signification | Valeur par défaut |
| --- | --- | --- |
| `CHIRPS_DATA` | Dossier racine de l'archive CHIRPS locale | `/home/wefe/local/data/precipitation/chirps` |
| `CHC_UA` | User-Agent qui identifie vos requêtes auprès de CHC | `ecor-chirps-mirror (https://github.com/ecor/chc-data-download)` |

Toute autre option est transmise à `download-chc-data`, par exemple
`--dry-run`, `--yes` ou `--max-bytes`.

## Ménager le serveur CHC

Le serveur CHC bloque les adresses qui envoient plus de deux requêtes par
seconde environ. Lancez une seule copie à la fois (le script refuse d'en
démarrer une seconde), gardez le délai par défaut et ne lancez pas la mise à
jour en boucle. Voir
[Downloading Politely](../../README.md#downloading-politely).

## Problèmes fréquents

- **`uv: command not found`** : exécutez `source ~/.bashrc` ou ouvrez un
  nouveau terminal.
- **`HTTP 429`, `HTTP 403` ou délais d'attente répétés** : votre adresse est
  peut-être bloquée. Arrêtez tous les téléchargements vers CHC depuis votre
  réseau, attendez quelques heures et contactez CHC si le problème persiste.
- **L'exécution s'est interrompue** : relancez la même commande.
