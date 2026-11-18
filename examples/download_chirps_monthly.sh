#!/usr/bin/env bash
# CHIRPS v3 monthly (final) mirror, 1981 to present, using the CHC download
# tool over HTTPS. These are the official monthly totals, not sums of the
# daily files, so they are useful to check data derived from the daily
# products.
#
# Sources (choose with the FORMAT setting):
#   tif     https://data.chc.ucsb.edu/products/CHIRPS/v3.0/monthly/global/tifs/
#           one GeoTIFF per month: chirps-v3.0.YYYY.MM.tif
#   netcdf  https://data.chc.ucsb.edu/products/CHIRPS/v3.0/monthly/global/netcdf/by_year/
#           one NetCDF per year, 12 monthly layers
#
# Setup (once; requires uv, https://docs.astral.sh/uv/, which also provides
# Python 3.10+ when the system Python is older):
#   git clone https://github.com/ecor/chc-data-download.git
#   cd chc-data-download
#   uv sync
#
# Usage (from anywhere; the script moves to the repository folder itself):
#   bash examples/download_chirps_monthly.sh all --dry-run       # preview, no download
#   bash examples/download_chirps_monthly.sh all                 # full archive 1981-today
#   bash examples/download_chirps_monthly.sh all 1981 1994       # only some years
#   bash examples/download_chirps_monthly.sh update              # last 120 days only (cron)
#   FORMAT=netcdf bash examples/download_chirps_monthly.sh all   # yearly NetCDF instead
# Any further option is passed to download-chc-data (for example --yes,
# --dry-run, --max-bytes).
#
# "all" can be rerun at any time: files already present with the right size
# and date are skipped, and an interrupted run resumes where it stopped. Large
# plans (more than 1,000 files or 10 GB) ask for confirmation; add --yes to
# skip the question.
#
# "update" is meant for cron. The final monthly CHIRPS for a month is usually
# produced in the third week of the following month, so checking on those days
# is enough, for example:
#   45 3 18-28 * * bash $HOME/chc-data-download/examples/download_chirps_monthly.sh update >> $HOME/chirps_monthly_update.log 2>&1
# The 120-day window also picks up months that CHC reissued recently.
#
# Settings can be changed here or through environment variables:
#   CHIRPS_DATA  root of the local CHIRPS archive (the CHC folder layout, for
#                example v3.0/monthly/global/tifs, is recreated below it)
#   CHC_UA       User-Agent that identifies your requests to CHC
#   FORMAT       tif (default) or netcdf
#
# Please keep the default delay of the tool and run one copy at a time: the
# CHC server blocks addresses that send more than about two requests a second.
# This script refuses to start while another copy of itself is running.
set -euo pipefail

DATA="${CHIRPS_DATA:-/home/wefe/local/data/precipitation/chirps}"
UA="${CHC_UA:-ecor-chirps-mirror (https://github.com/ecor/chc-data-download)}"
FORMAT="${FORMAT:-tif}"
FIRST_YEAR=1981
LAST_YEAR="$(date -u +%Y)"
UPDATE_DAYS=120

usage() {
  sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

case "$FORMAT" in
  tif)    PRODUCT=v3.0/monthly/global/tifs;           SUFFIX=.tif ;;
  netcdf) PRODUCT=v3.0/monthly/global/netcdf/by_year; SUFFIX=.nc ;;
  *) echo "FORMAT must be 'tif' or 'netcdf' (got '$FORMAT')." >&2; exit 2 ;;
esac
URL="https://data.chc.ucsb.edu/products/CHIRPS/$PRODUCT/"
DEST="$DATA/$PRODUCT"

MODE="${1:-}"
case "$MODE" in
  all|update) shift ;;
  -h|--help|help) usage 0 ;;
  *) echo "First argument must be 'all' or 'update'." >&2; usage 2 >&2 ;;
esac

# Optional first and last year for "all" (for example: all 1981 1994).
if [[ "$MODE" == all && "${1:-}" =~ ^[0-9]{4}$ ]]; then
  FIRST_YEAR="$1"
  shift
  if [[ "${1:-}" =~ ^[0-9]{4}$ ]]; then
    LAST_YEAR="$1"
    shift
  fi
fi

# cron starts with a minimal PATH; uv is usually installed in ~/.local/bin.
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
command -v uv >/dev/null || {
  echo "uv not found. Install it with: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
  exit 2
}

# Run from the repository folder so that "uv run" finds the project.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

# One copy at a time (the server limits apply to the whole IP address).
if command -v flock >/dev/null; then
  exec 9>"${TMPDIR:-/tmp}/chirps_monthly.lock"
  flock -n 9 || { echo "Another copy of this script is already running; exiting." >&2; exit 0; }
fi

mkdir -p "$DEST"
TODAY=$(date -u +%F)
echo "[$(date -u '+%F %T') UTC] CHIRPS v3 monthly ($FORMAT), mode: $MODE"
echo "  from: $URL"
echo "  to:   $DEST"

get() {
  uv run download-chc-data --user-agent "$UA" --url "$URL" --suffix "$SUFFIX" --dest "$DEST" "$@"
}

case "$MODE" in
  all)
    get --start-year "$FIRST_YEAR" --end-year "$LAST_YEAR" "$@"
    ;;
  update)
    # --yes: cron cannot answer the confirmation question.
    get --start-date "$(date -u -d "$UPDATE_DAYS days ago" +%F)" --end-date "$TODAY" --yes "$@"
    ;;
esac

echo "[$(date -u '+%F %T') UTC] done."
