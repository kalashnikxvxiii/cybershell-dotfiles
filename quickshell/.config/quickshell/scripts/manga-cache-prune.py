#!/usr/bin/env python3
"""Keeps the page cache under a size limit, dropping the least recently read
chapters first.

Each chapter is one directory under the cache root. manga-fetch-chapter.sh
touches the directory on every open — including a cache hit, which downloads
nothing — so the directory mtime is a real "last read" marker rather than
"last downloaded". Reading a file does not update it on its own.

Usage: manga-cache-prune.py <cache-root> [limit-mb]
Default limit: 1500 MB, about 160 chapters at the measured 9.4 MB average.
Override with MANGA_CACHE_MB.
"""

import os
import shutil
import sys

DEFAULT_MB = 1500


def dir_size(path):
    total = 0
    for root, _, files in os.walk(path):
        for f in files:
            try:
                total += os.path.getsize(os.path.join(root, f))
            except OSError:
                pass
    return total


def main():
    if len(sys.argv) < 2:
        return 1
    root = sys.argv[1]
    if not os.path.isdir(root):
        return 0

    limit_mb = DEFAULT_MB
    if len(sys.argv) > 2 and sys.argv[2].isdigit():
        limit_mb = int(sys.argv[2])
    elif os.environ.get("MANGA_CACHE_MB", "").isdigit():
        limit_mb = int(os.environ["MANGA_CACHE_MB"])
    limit = limit_mb * 1024 * 1024

    entries = []
    for name in os.listdir(root):
        p = os.path.join(root, name)
        if not os.path.isdir(p):
            continue
        try:
            entries.append((os.path.getmtime(p), dir_size(p), p))
        except OSError:
            pass

    total = sum(e[1] for e in entries)
    if total <= limit:
        return 0

    # Oldest first. The chapter just opened was touched a moment ago, so it is
    # the newest and is never the one evicted.
    entries.sort(key=lambda e: e[0])
    for _, size, path in entries:
        if total <= limit:
            break
        try:
            shutil.rmtree(path)
            total -= size
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
