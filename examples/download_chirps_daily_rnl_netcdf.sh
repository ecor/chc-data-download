#!/usr/bin/env bash
# CHIRPS v3 daily "rnl" (ERA5-disaggregated) NetCDF mirror, 1981 to present,
# using the CHC download tool over HTTPS (no rsync / port 873 needed).
#
# Source: https://data.chc.ucsb.edu/products/CHIRPS/v3.0/daily/final/rnl/netcdf/byMonth/
# One NetCDF per month (about 550 files, roughly 25-30 GB for 1981-today).
#
# Setup (once; requires uv, https://docs.astral.sh/uv/, which also provides
# Python 3.10+ when the system Python is older):
#   git clone https://github.com/ecor/chc-data-download.git
#   cd chc-data-download
#   uv sync
#
# Usage (from anywhere; the script moves to the repository folder itself):
#   bash examples/download_chirps_daily_rnl_netcdf.sh all --dry-run   # preview, no download
#   bash examples/download_chirps_daily_rnl_netcdf.sh all             # full archive 1981-today
#   bash examples/download_chirps_daily_rnl_netcdf.sh all 2000        # from a later first year
#   bash examples/download_chirps_daily_rnl_netcdf.sh update          # last 90 days only (cron)
# Any further option is passed to download-chc-data (for example --yes,
# --dry-run, --max-bytes).
#
# "all" can be rerun at any time: files already present with the right size
# and date are skipped, and an interrupted run resumes where it stopped. It is
# long (large files, one request at a time), so run it inside tmux or screen.
# The full plan is larger than 10 GB, so the tool asks for confirmation; add
# --yes to skip the question.
#
# "update" is meant for cron. CHIRPS final for a month usually appears between
# the 12th and 18th of the following month, so checking on those days is
# enough, for example:
#   30 3 12-20 * * bash $HOME/chc-data-download/examples/download_chirps_daily_rnl_netcdf.sh update >> $HOME/chirps_rnl_update.log 2>&1
#
# Settings can be changed here or through environment variables:
#   CHIRPS_DATA  root of the local CHIRPS archive (the CHC folder layout
#                v3.0/daily/final/rnl/netcdf/byMonth is recreated below it)
#   CHC_UA       User-Agent that identifies your requests to CHC
#
# Please keep the default delay of the tool and run one copy at a time: the
# CHC server blocks addresses that send more than about two requests a second.
# This script refuses to start while another copy of itself is running.
set -euo pipefail

DATA="${CHIRPS_DATA:-/home/wefe/local/data/precipitation/chirps}"
UA="${CHC_UA:-ecor-chirps-mirror (https://github.com/ecor/chc-data-download)}"
FIRST_YEAR=1981
UPDATE_DAYS=90

PRODUCT=v3.0/daily/final/rnl/netcdf/byMonth
URL="https://data.chc.ucsb.edu/products/CHIRPS/$PRODUCT/"
DEST="$DATA/$PRODUCT"

usage() {
  sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

MODE="${1:-}"
case "$MODE" in
  all|update) shift ;;
  -h|--help|help) usage 0 ;;
  *) echo "First argument must be 'all' or 'update'." >&2; usage 2 >&2 ;;
esac

# Optional first year for "all" (for example: all 2000).
if [[ "$MODE" == all && "${1:-}" =~ ^[0-9]{4}$ ]]; then
  FIRST_YEAR="$1"
  shift
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
  exec 9>"${TMPDIR:-/tmp}/chirps_daily_rnl_netcdf.lock"
  flock -n 9 || { echo "Another copy of this script is already running; exiting." >&2; exit 0; }
fi

mkdir -p "$DEST"
TODAY=$(date -u +%F)
echo "[$(date -u '+%F %T') UTC] CHIRPS v3 daily rnl NetCDF, mode: $MODE"
echo "  from: $URL"
echo "  to:   $DEST"

get() {
  uv run download-chc-data --user-agent "$UA" --url "$URL" --suffix .nc --dest "$DEST" "$@"
}

case "$MODE" in
  all)
    get --start-year "$FIRST_YEAR" --end-year "$(date -u +%Y)" "$@"
    ;;
  update)
    # The window covers the newly published month and picks up files that CHC
    # reissued recently. --yes: cron cannot answer the confirmation question.
    get --start-date "$(date -u -d "$UPDATE_DAYS days ago" +%F)" --end-date "$TODAY" --yes "$@"
    ;;
esac

echo "[$(date -u '+%F %T') UTC] done."
