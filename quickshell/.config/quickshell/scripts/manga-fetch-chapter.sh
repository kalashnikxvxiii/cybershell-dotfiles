#!/usr/bin/env bash
# Downloads a chapter's pages into a cache directory and prints their local
# paths, one per line, in page order.
#
# Why this exists: Qt's own networking cannot fetch these images. The MangaDex
# at-home node answers 404 to essentially every request after the first one,
# while curl gets 200 on the very same URLs at the same moment — verified with
# a fresh Qt process (1 of 15 pages), with curl (45 of 45), and by replicating
# Qt's exact request headers in curl, which still returned 200. Qt exposes no
# way to change its connection handling from QML, so the download is delegated.
#
# Usage: manga-fetch-chapter.sh <dir> <url> [<url> ...]
set -u

UA="quickshell-manga/0.1"
ROOT="$HOME/.cache/quickshell/manga/pages"
dir="$1"; shift

# The directory name comes from an API response (the MangaDex chapter hash), and
# the pruner below deletes directories under its parent. Only a plain name
# directly inside the cache root is accepted, so a "../" can never move either.
name="${dir##*/}"
if [ "${dir%/*}" != "$ROOT" ] || [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "manga-fetch-chapter: refusing cache dir $dir" >&2
    exit 1
fi
mkdir -p "$dir" || exit 1

# Marks this chapter as just read, cache hit or not: the pruner treats the
# directory mtime as "last read", and reading files does not update it.
touch "$dir"

# Only fetch what is missing: re-opening a chapter should cost nothing.
args=()
n=0
for url in "$@"; do
    n=$((n + 1))
    f=$(printf "%s/%03d.jpg" "$dir" "$n")
    [ -s "$f" ] || args+=(-o "$f" "$url")
done

if [ ${#args[@]} -gt 0 ]; then
    curl -s --proto =http,https --max-time 300 -A "$UA" -Z --parallel-max 6 "${args[@]}"
fi

# Keep the cache bounded. Runs after the download so the chapter just fetched is
# already on disk and already the newest, which makes it the last thing the
# pruner would ever drop.
python3 "$(dirname "$0")/manga-cache-prune.py" "$ROOT" >/dev/null 2>&1 || true

# Always print the full list, cached or freshly pulled. A page that failed is
# left out so the reader shows a gap instead of a broken image.
n=0
for url in "$@"; do
    n=$((n + 1))
    f=$(printf "%s/%03d.jpg" "$dir" "$n")
    [ -s "$f" ] && printf "%s\n" "$f"
done
