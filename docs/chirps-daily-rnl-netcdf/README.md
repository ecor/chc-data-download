# CHIRPS v3 daily `rnl` NetCDF: local mirror

**Languages:** English | [Italiano](README.it.md) | [Español](README.es.md) | [Français](README.fr.md)

[`examples/download_chirps_daily_rnl_netcdf.sh`](../../examples/download_chirps_daily_rnl_netcdf.sh)
keeps a local copy of the CHIRPS v3 daily `rnl` product (pentad totals split
into days with ERA5) in NetCDF, from 1981 to the present.

- Source: `https://data.chc.ucsb.edu/products/CHIRPS/v3.0/daily/final/rnl/netcdf/byMonth/`
- One NetCDF file per month: about 550 files, roughly 25-30 GB in total
  (estimate; the dry run in step 3 shows the real figure).
- Downloads use HTTPS, so the rsync port (873) is not needed.
- No `sudo` is required.

## 1. Install uv (once)

[uv](https://docs.astral.sh/uv/) manages the Python environment of this
project. Skip this step if `uv --version` already answers.

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc
uv --version
```

## 2. Get the repository and prepare the environment

```bash
cd ~
git clone https://github.com/ecor/chc-data-download.git
cd chc-data-download
uv sync
```

`uv sync` creates an isolated environment in `.venv/` and installs the locked
dependencies. It does not change the system Python or any conda environment.
If the repository is already cloned, run `git pull` instead of `git clone`.

## 3. Choose the destination and preview

By default the files go to
`/home/wefe/local/data/precipitation/chirps/v3.0/daily/final/rnl/netcdf/byMonth/`.
To use another root folder, set `CHIRPS_DATA`:

```bash
export CHIRPS_DATA=/path/to/chirps
```

Preview the plan without downloading anything:

```bash
bash examples/download_chirps_daily_rnl_netcdf.sh all --dry-run
```

Check the number of files and the total size printed at the end.

## 4. Download the full archive in the background

```bash
nohup bash examples/download_chirps_daily_rnl_netcdf.sh all --yes > ~/chirps_rnl_download.log 2>&1 &
```

`nohup` and `&` keep the download running after you close the SSH session.
`--yes` is required here, because a background job cannot answer the
confirmation question for plans larger than 10 GB. The download takes a few
hours: the tool sends one request at a time.

To start from a later year, add it after `all`, for example `all 2000 --yes`.

## 5. Check progress

```bash
tail -f ~/chirps_rnl_download.log        # Ctrl-C closes tail, not the download
pgrep -af download_chirps_daily_rnl      # is it still running?
du -sh "${CHIRPS_DATA:-/home/wefe/local/data/precipitation/chirps}"
```

## 6. Stop and resume

```bash
pkill -f download_chirps_daily_rnl_netcdf.sh
```

To resume, run the command of step 4 again: complete files are skipped and
interrupted files are fetched again. Do not delete the destination folder to
start over.

## 7. Monthly update with cron

CHIRPS final data for a month usually appear between the 12th and the 18th of
the following month. Add this line with `crontab -e`:

```bash
30 3 12-20 * * bash $HOME/chc-data-download/examples/download_chirps_daily_rnl_netcdf.sh update >> $HOME/chirps_rnl_update.log 2>&1
```

`update` checks only the files of the last 90 days. If you use a custom
destination, put `CHIRPS_DATA=/path/to/chirps` before `bash` in that line.

## Settings

| Variable | Meaning | Default |
| --- | --- | --- |
| `CHIRPS_DATA` | Root folder of the local CHIRPS archive | `/home/wefe/local/data/precipitation/chirps` |
| `CHC_UA` | User-Agent that identifies your requests to CHC | `ecor-chirps-mirror (https://github.com/ecor/chc-data-download)` |

Any extra option is passed to `download-chc-data`, for example `--dry-run`,
`--yes` or `--max-bytes`.

## Be polite to the CHC server

The CHC server blocks addresses that send more than about two requests per
second. Run one copy at a time (the script refuses to start a second one),
keep the default delay, and do not run the update in a tight loop. See
[Downloading Politely](../../README.md#downloading-politely).

## Troubleshooting

- **`uv: command not found`**: run `source ~/.bashrc` or open a new terminal.
- **`HTTP 429`, `HTTP 403` or repeated timeouts**: your address may be blocked.
  Stop every download to CHC from your network, wait a few hours, and contact
  CHC if it continues.
- **The run stopped**: run the same command again.
