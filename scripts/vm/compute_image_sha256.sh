#!/usr/bin/env bash
# Download an image (or reuse if present) and print its SHA256
set -o errexit
set -o pipefail
set -o nounset

usage() {
  cat <<EOF
Usage: $(basename "$0") -u <url> [-o <output>]
  -u <url>      HTTPS URL to the image
  -o <output>   Optional local filename (default: basename of URL)
  -f            Force re-download even if file exists
  -h            Show help
EOF
}

url=""
out=""
force=0

while getopts ":u:o:fh" opt; do
  case "$opt" in
    u) url="$OPTARG" ;;
    o) out="$OPTARG" ;;
    f) force=1 ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

[[ -n "$url" ]] || { echo "URL is required" >&2; usage; exit 1; }
[[ "$url" =~ ^https:// ]] || { echo "Only HTTPS URLs are allowed" >&2; exit 1; }

if [ -z "$out" ]; then
  out=$(basename "$url")
fi

if [ $force -eq 1 ] || [ ! -f "$out" ]; then
  echo "Downloading $url -> $out"
  wget --https-only -O "$out" "$url"
else
  echo "Using existing file $out"
fi

sha256sum "$out"
