#!/usr/bin/env bash
#
# This script synchronizes Earthworm spectrogram GIF files from a local or remote 
# source directory for a given date window, organize them into a YYYY/MM/DD/ID 
# tree in the destination, convert GIFs to PNG, generate JPG thumbnails, and 
# create a link.jpg symlink for legacy WebObs instances.
#
# Author: Patrice Boissier/OVPF-IPGP

set -euo pipefail

# Useful functions
die() { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARN: $*" >&2; }
is_uint() { [[ ${1-} =~ ^[0-9]+$ ]]; }
require_arg() {
  local opt="$1" val="${2-}";
  [[ -n "$val" && "$val" != --* ]] || die "Option '$opt' must have a value.";
}

usage() {
  cat >&2 <<EOF
Usage: $0 --src-dir DIR --dst-base DIR [--src-user USER] [--src-host HOST] [--thumbnail-height H] [--nodes "ID:FID|..."] [--ssh-opts OPTS] [--last-days N] [--run-date YYYY-MM-DD] [--pngquant NB_COLORS]

Description:
  Sync Earthworm spectrogram GIF files from a local or remote source directory for a given date window,
  organize them into a YYYY/MM/DD/ID tree in the destination, convert GIFs to PNG,
  generate JPG thumbnails, and create a link.jpg symlink for legacy WebObs instances.

Options:
  --src-dir DIR            Source directory containing *.gif spectrogram files.
  --dst-base DIR           Destination root directory where output files are organized by date/ID.
  --src-user USER          Remote SSH username (used with --src-host).
  --src-host HOST          Remote SSH host (used with --src-user).
  --thumbnail-height H     Thumbnail height in pixels. Default: 112px.
  --nodes "ID:FID|..."     Map station IDs to FIDs (example: "RSBSNE:SNE|RSZTEO:TEO").
  --ssh-opts OPTS          Extra SSH options. Default: "-o BatchMode=yes -o StrictHostKeyChecking=accept-new".
  --last-days N            Number of days to process, ending at --run-date. Default: 7 days.
  --run-date YYYY-MM-DD    End date of the processing window. Default: today.
  --pngquant NB_COLORS     PNG color quantization level if pngquant is available. Value between 16 and 256. Default: 256 colors.
  -h, --help               Show this help message.
EOF
}

# Initialize variables
SRC_DIR=""
DST_BASE=""
SRC_USER=""
SRC_HOST=""
TN_HEIGHT="112"
NODES=""
SSH_OPTS="-o BatchMode=yes -o StrictHostKeyChecking=accept-new"
N_DAYS=7
RUN_DATE=""
PNG_QUANT="256"

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --src-dir) require_arg "$1" "${2-}"; SRC_DIR="$2"; shift 2 ;;
    --dst-base) require_arg "$1" "${2-}"; DST_BASE="$2"; shift 2 ;;
    --src-user) require_arg "$1" "${2-}"; SRC_USER="$2"; shift 2 ;;
    --src-host) require_arg "$1" "${2-}"; SRC_HOST="$2"; shift 2 ;;
    --thumbnail-height) require_arg "$1" "${2-}"; TN_HEIGHT="$2"; shift 2 ;;
    --nodes) require_arg "$1" "${2-}"; NODES="$2"; shift 2 ;;
    --ssh-opts) require_arg "$1" "${2-}"; SSH_OPTS="$2"; shift 2 ;;
    --last-days) require_arg "$1" "${2-}"; N_DAYS="$2"; shift 2 ;;
    --run-date) require_arg "$1" "${2-}"; RUN_DATE="$2"; shift 2 ;;
    --pngquant) require_arg "$1" "${2-}"; PNG_QUANT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

# Check mandatory options
[[ -z "$SRC_DIR" || -z "$DST_BASE" ]] && { usage; exit 2; }

# Guess remote or local mode
REMOTE=0
if [[ -n "$SRC_USER" || -n "$SRC_HOST" ]]; then
  [[ -n "$SRC_USER" && -n "$SRC_HOST" ]] || die "For remote mode, --src-user AND --src-host are mandatory."
  REMOTE=1
  echo "Remote mode enabled"
fi

# Validate numeric inputs
if ! is_uint "$N_DAYS"; then warn "invalid --last-days, default to 7"; N_DAYS=7; fi
(( N_DAYS < 1 )) && N_DAYS=1

if ! is_uint "$TN_HEIGHT"; then warn "invalid --thumbnail-height, default to 112"; TN_HEIGHT=112; fi
(( TN_HEIGHT < 1 )) && TN_HEIGHT=112

if ! is_uint "$PNG_QUANT"; then warn "invalid --pngquant, default to 256"; PNG_QUANT=256; fi
(( PNG_QUANT < 16 )) && PNG_QUANT=16
(( PNG_QUANT > 256 )) && PNG_QUANT=256

# Validate directories / access
mkdir -p "$DST_BASE" || die "Impossible to create/access --dst-base: $DST_BASE"
if [[ $REMOTE -eq 0 ]]; then
  [[ -d "$SRC_DIR" ]] || die "--src-dir doesn't exists (local): $SRC_DIR"
else
  ssh $SSH_OPTS "$SRC_USER@$SRC_HOST" "test -d \"$SRC_DIR\"" \
    || die "Impossible to access --src-dir on $SRC_USER@$SRC_HOST: $SRC_DIR"
fi

if [[ -z "$RUN_DATE" ]]; then
  RUN_DATE="$(date +%Y-%m-%d)"
fi

# Check if RUN_DATE is parseable by GNU date
date -d "$RUN_DATE" +%F >/dev/null 2>&1 || die "Invalid --run-date (accepted format YYYY-MM-DD): $RUN_DATE"

# Parse and check NODES
if [[ -n "$NODES" ]]; then
  declare -A STATIONS
  IFS='|' read -ra PAIRS <<< "$NODES"
  for pair in "${PAIRS[@]}"; do
    [[ "$pair" == *:* ]] || die "Invalid --nodes: (accepted format ID:FID, with '|' delimiter): '$pair'"
    value="${pair%%:*}"
    key="${pair##*:}"
    STATIONS["$key"]="$value"
  done
fi

# Determine start and end of processing
END="$(date -d "$RUN_DATE" +%Y%m%d)"
START="$(date -d "$RUN_DATE -$((N_DAYS-1)) days" +%Y%m%d)"

echo "RUN_DATE=$RUN_DATE | Window $START -> $END (N=$N_DAYS)"

# Determine what the ImageMagick command is
if command -v magick >/dev/null 2>&1; then IM="magick"
elif command -v convert >/dev/null 2>&1; then IM="convert"
else
  echo "ERROR: cannot find ImageMagick (magick/convert)" >&2
  exit 1
fi

Y_END="${END:0:4}"
Y_START="${START:0:4}"
YEARS="$Y_END"
if [[ "$Y_START" != "$Y_END" ]]; then
  YEARS="$Y_START $Y_END"
fi

# Create a temporary file for directory names (used to create symbolic link "link.jpg")
DAYDIRS_FILE="$(mktemp)"
trap 'rm -f "$DAYDIRS_FILE"' EXIT

# Process each years
for YEAR in $YEARS; do
  echo "Listing sgram files for YEAR=$YEAR "
  LIST=""
  if [[ $REMOTE -eq 1 ]]; then
    LIST="$(ssh $SSH_OPTS "$SRC_USER@$SRC_HOST" "cd \"$SRC_DIR\" && ls -1 *.$YEAR[0-9][0-9][0-9][0-9]00.gif 2>/dev/null || true")"
  else
    LIST="$(cd "$SRC_DIR" && ls -1 *.$YEAR[0-9][0-9][0-9][0-9]00.gif 2>/dev/null || true)"
  fi
  [[ -z "$LIST" ]] && continue

  # Store file names included in the time window
  LIST="$(printf '%s\n' "$LIST" | awk -v s="$START" -v e="$END" '
    match($0, /\.([0-9]{8})00\.gif$/, m) {
      d = m[1]
      if (d >= s && d <= e) print $0
    }
  ')"

  [[ -z "$LIST" ]] && continue

  # Process files in the time window
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue

    echo "- Processing $f"
    datestr="$(printf '%s' "$f" | sed -nE 's/.*\.([0-9]{8})00\.gif$/\1/p')"
    fidstr="${f#*.}"
    fidstr="${fidstr%%_*}"
    fidstr="${fidstr^^}"
    echo "  - Station = $fidstr"
    [[ -z "$datestr" ]] && continue

    yyyy="${datestr:0:4}"
    mm="${datestr:4:2}"
    dd="${datestr:6:2}"

    # Build the directory tree used by showOUTG.pl
    # If node exists, create a node directory
    # Else, create "sgram" directory
    if [[ -v STATIONS[$fidstr] ]]; then
      dest_dir="$DST_BASE/$yyyy/$mm/$dd/${STATIONS[$fidstr]}"
    else
      dest_dir="$DST_BASE/$yyyy/$mm/$dd/sgram"
    fi
    mkdir -p "$dest_dir"
    printf '%s\n' "$dest_dir" >> "$DAYDIRS_FILE"

    # Sync file using rsync
    if [[ $REMOTE -eq 1 ]]; then
      #rsync -a "$SRC_USER@$SRC_HOST:$SRC_DIR/$f" "$dest_dir/"
      rsync -a -e "ssh $SSH_OPTS" "$SRC_USER@$SRC_HOST:$SRC_DIR/$f" "$dest_dir/"
    else
      rsync -a "$SRC_DIR/$f" "$dest_dir/"
    fi

    gif="$dest_dir/$f"
    base="${gif%.gif}"
    png="${base}.png"
    jpg="${base}.jpg"

    # Convert GIF to PNG and create JPG thumbnail (if a new GIF file is found)
    if [[ -f "$gif" ]]; then
      if [[ ! -f "$png" || "$gif" -nt "$png" ]]; then
        "$IM" "$gif" "$png"
        if command -v pngquant >/dev/null 2>&1; then 
          echo "Optimizing PNG"
          pngquant -f --ext .png "$PNG_QUANT" "$png"
        fi
      fi
      if [[ ! -f "$jpg" || "$gif" -nt "$jpg" ]]; then
        "$IM" "$gif" -auto-orient -thumbnail "x${TN_HEIGHT}" "$jpg"
      fi
    fi
  done <<< "$LIST"
done

