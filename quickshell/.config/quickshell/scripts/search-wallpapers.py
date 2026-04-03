#!/usr/bin/env python3
"""Wallpaper search — Wallhaven (default) or Google Images (@g prefix)."""

import sys
import json
import urllib.request
import urllib.parse
import re
import signal

signal.signal(signal.SIGPIPE, signal.SIG_DFL)

def search_wallhaven(query, page=1, max_results=30):
    """Search Wallhaven API — clean REST, no scraping needed."""
    params = {
        "q": query,
        "atleast": "1920x1080",
        "categories": "111",
        "purity": "100",
        "sorting": "relevance",
        "page": page,
    }
    url = "https://wallhaven.cc/api/v1/search?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})

    count = 0
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode())
    except Exception:
        return

    for wp in data.get("data", []):
        path = wp.get("path", "")
        if not path:
            continue
        thumb = wp.get("thumbs", {}).get("large", "")
        title = wp.get("id", "")
        w = wp.get("dimension_x", 0)
        h = wp.get("dimension_y", 0)

        print(json.dumps({
            "url": path,
            "thumb": thumb,
            "title": title,
            "w": w,
            "h": h
        }), flush=True)
        count += 1
        if count >= max_results:
            break

def search_google(query, max_results=30):
    """Scrape Google Images for FHD+ wallpapers."""
    url = "https://www.google.com/search?" + urllib.parse.urlencode({
        "q": query,
        "tbm": "isch",
        "tbs": "isz:lt,islt:2mp",  # larger than 2MP (~FHD+)
    })
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    })

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read().decode()
    except Exception:
        return

    # Extract image URLs from Google's inline JSON data
    count = 0
    for match in re.finditer(r'\["(https?://[^"]+\.(?:jpg|jpeg|png|webp))",(\d+),(\d+)\]', body):
        img_url = match.group(1)
        h = int(match.group(2))
        w = int(match.group(3))
        if w < 1920 or h < 1080:
            continue
        if "google" in img_url or "gstatic" in img_url:
            continue

        print(json.dumps({
            "url": img_url,
            "thumb": "",
            "title": "",
            "w": w,
            "h": h
        }), flush=True)
        count += 1
        if count >= max_results:
            break

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: search-wallpapers.py <query> [page]", file=sys.stderr)
        print("  Prefix with @g for Google Images", file=sys.stderr)
        sys.exit(1)

    query = sys.argv[1]
    page = int(sys.argv[2]) if len(sys.argv) > 2 else 1

    if query.startswith("@g "):
        search_google(query[3:].strip())
    else:
        search_wallhaven(query, page=page)
