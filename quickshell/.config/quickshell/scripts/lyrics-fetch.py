#!/usr/bin/env python3
# lyrics-fetch.py - Synced lyrics with fallback chain
# Usage: lyrics-fetch.py --title "Song" --artist "Artist" [--album "Album"] [--duration 240] [--spotify-id "4uLU6hMCjMI75M1A2tKUQC"]

import sys, json, argparse, urllib.request, urllib.parse, os, subprocess

SP_DC_FILE = os.path.expanduser("~/.config/quickshell/sp_dc")
LYRICS_DIR = os.path.expanduser("~/.config/quickshell/lyrics/")
MAX_CACHE  = 300

# ── Cache LRU ──────────────────────────────────────────────────────────────

def _lrc_path(title, artist):
    safe = lambda s: "".join( c for c in s if c not in r'\/:*?"<>|').strip()
    return os.path.join(LYRICS_DIR, f"{safe(artist)} - {safe(title)}.lrc")

def load_cached(title, artist):
    path = _lrc_path(title, artist)
    if os.path.exists(path):
        os.utime(path, None)    # touch atime for LRU eviction
        return open(path).read().strip() or None
    return None

def save_cached(title, artist, lrc):
    os.makedirs(LYRICS_DIR, exist_ok=True)
    open(_lrc_path(title, artist), "w").write(lrc)
    files = sorted(
        [os.path.join(LYRICS_DIR, f) for f in os.listdir(LYRICS_DIR) if f.endswith(".lrc")],
        key=lambda f: os.path.getatime(f)
    )
    for f in files[:max(0, len(files) - MAX_CACHE)]:
        os.remove(f)

# ── Spotify private API ────────────────────────────────────────────────────

def _spotify_token(sp_dc):
    url = "https://open.spotify.com/get_access_token?reason=transport&productType=web_player"
    req = urllib.request.Request(url)
    req.add_header("Cookie", f"sp_dc={sp_dc}")
    req.add_header("User-Agent", "Mozilla/5.0")
    with urllib.request.urlopen(req, timeout=6) as r:
        return json.loads(r.read())["accessToken"]

def fetch_spotify(track_id):
    if not os.path.exists(SP_DC_FILE):
        return None
    try:
        sp_dc = open(SP_DC_FILE).read().strip()
        token = _spotify_token(sp_dc)
        url = f"https://spclient.wg.spotify.com/color-lyrics/v2/track/{track_id}?format=json&vocalRemoval=false"
        req = urllib.request.Request(url)
        req.add_header("Authorization", f"Bearer {token}")
        req.add_header("app-platform", "WebPlayer")
        req.add_header("User-Agent", "Mozilla/5.0")
        with urllib.request.urlopen(req, timeout=6) as r:
            data = json.loads(r.read())
        lines = data.get("lyrics", {}).get("lines", [])
        out = []
        for ln in lines:
            ms = int(ln.get("startTimeMs", 0))
            m, s = ms // 60000, (ms % 60000) / 1000
            out.append(f"[{m:02d}:{s:06.3f}]{ln.get('words', '')}")
        return "\n".join(out) if out else None
    except Exception:
        return None

# ── LRCLIB ────────────────────────────────────────────────────────────

def fetch_lrclib(title, artist, album="", duration=0):
    params = {"track_name": title, "artist_name": artist}
    if album: params["album_name"] = album
    if duration: params["duration"] = int(duration)
    url = "https://lrclib.net/api/get?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "QuickShellLyrics/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=6) as r:
            data = json.loads(r.read())
        return data.get("syncedLyrics") or None
    except Exception:
        return None

# ── syncedlyrics CLI ───────────────────────────────────────────────────────

def fetch_syncedlyrics(title, artist):
    try:
        output_path = _lrc_path(title, artist)
        os.makedirs(LYRICS_DIR, exist_ok=True)
        r = subprocess.run(
            ["syncedlyrics", "--synced-only", "-o", output_path, f"{artist} - {title}"],
            capture_output=True, text=True, timeout=12
        )
        if r.returncode != 0:
            return None
        content = r.stdout.strip()
        if not content and os.path.exists(output_path):
            content = open(output_path).read().strip()
        return content or None
    except Exception:
        return None

# ── Main ───────────────────────────────────────────────────────────────

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--title", required=True)
    p.add_argument("--artist", required=True)
    p.add_argument("--album", default="")
    p.add_argument("--duration", type=float, default=0)
    p.add_argument("--spotify-id", default="")
    args = p.parse_args()

    lrc = None

    # 0. Local cache
    lrc = load_cached(args.title, args.artist)

    # 1. Spotify (only if sp_dc is configured and track id is available)
    if not lrc and args.spotify_id:
        lrc = fetch_spotify(args.spotify_id)
    
    # 2. LRCLIB
    if not lrc:
        lrc = fetch_lrclib(args.title, args.artist, args.album, args.duration)
    
    # 3. syncedlyrics
    if not lrc:
        lrc = fetch_syncedlyrics(args.title, args.artist)
    
    if lrc:
        if not load_cached(args.title, args.artist): # only save if not already cached
            save_cached(args.title, args.artist, lrc)
        else:
            os.utime(_lrc_path(args.title, args.artist), None) # just refresh atime
        print(lrc)
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()