#!/usr/bin/env python3
"""Wallpaper search — Wallhaven, Alphacoders, Reddit. Prefixes: @wh, @a, @r"""

import sys
import json
import urllib.request
import urllib.parse
import re
import signal
import concurrent.futures

signal.signal(signal.SIGPIPE, signal.SIG_DFL)

def _fetch_wallhaven_tags(wp_id):
    """Fetch top 3 tags for a single Wallhaven wallpaper"""
    try:
        req = urllib.request.Request(
            "https://wallhaven.cc/api/v1/w/" + str(wp_id),
            headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            d = json.loads(resp.read().decode()).get("data", {})
            tags = [t["name"] for t in d.get("tags", [])[:3]]
            return " / ".join(tags) if tags else str(wp_id)
    except Exception:
        return str(wp_id)

def search_wallhaven(query, page=1, max_results=30, output=None, sorting="relevance"):
    """Search Wallhaven API — clean REST, no scraping needed"""
    import random as _rng
    params = {
        "q": query,
        "atleast": "1920x1080",
        "categories": "111",
        "purity": "100",
        "sorting": sorting,
        "page": page,
    }
    if sorting == "random":
        params["seed"] = str(_rng.randint(100000, 999999))
    url = "https://wallhaven.cc/api/v1/search?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode())
    except Exception:
        return

    wallpapers = []
    for wp in data.get("data", []):
        path = wp.get("path", "")
        if not path:
            continue
        wallpapers.append({
            "id": wp.get("id", ""),
            "path": path,
            "thumb": wp.get("thumbs", {}).get("large", ""),
            "w": wp.get("dimension_x", 0),
            "h": wp.get("dimension_y", 0),
            "file_size": wp.get("file_size", 0),
        })

    # Fetch tags in parallel (max 10 concurrent to respect rate limits)
    titles = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        future_to_id = {
            executor.submit(_fetch_wallhaven_tags, wp["id"]): wp["id"]
            for wp in wallpapers
        }
        for future in concurrent.futures.as_completed(future_to_id):
            wp_id = future_to_id[future]
            titles[wp_id] = future.result()

    for wp in wallpapers:
        result = {
            "url": wp["path"],
            "thumb": wp["thumb"],
            "title": titles.get(wp["id"], str(wp["id"])),
            "w": wp["w"],
            "h": wp["h"],
            "file_size": wp.get("file_size", 0),
            "source": "wh"
        }
        if output is not None:
            output.append(result)
        else:
            print(json.dumps(result), flush=True)

def search_alphacoders(query, page=1, max_results=30, output=None):
    """Search Alphacoders for desktop wallpapers"""
    # First page: search redirect to get slug
    if page == 1:
        search_url = "https://alphacoders.com/search/view?" + urllib.parse.urlencode({"q":query})
        req = urllib.request.Request(search_url, headers={
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
        })
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                final_url = resp.url            # follows redirect to slug URL
        except Exception:
            return
        # Extract slug from final URL (e.g., "https://alphacoders.com/cyberpunk")
        slug = final_url.rstrip("/").split("/")[-1]
    else:
        # For page > 1, we need the slug from page 1. Store it.
        import os
        slug_file = os.path.expanduser("~/.cache/wallpaper-picker/alpha_slug")
        try:
            with open(slug_file) as f:
                slug = f.read().strip()
        except FileNotFoundError:
            return
    
    # Save slug for pagination
    if page == 1:
        import os
        slug_file = os.path.expanduser("~/.cache/wallpaper-picker/alpha_slug")
        try:
            with open(slug_file, "w") as f:
                f.write(slug)
        except Exception:
            pass
    
    # Fetch page
    page_url = "https://alphacoders.com/" + slug + "?" + urllib.parse.urlencode({
        "page": page,
        "quickload": "1"
    })
    req = urllib.request.Request(page_url, headers={
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
    })
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read().decode()
    except Exception:
        return
    
    # Parse Schema.org itemprop metadata
    count = 0
    for match in re.finditer(
        r'itemprop="contentUrl"\s+content="([^"]+)".*?'
        r'itemprop="name"\s+content="([^"]*)".*?'
        r'itemprop="thumbnailUrl"\s+content="([^"]+)".*?'
        r'itemprop="width"\s+content="(\d+)".*?'
        r'itemprop="height"\s+content="(\d+)"',
        body, re.DOTALL
    ):
        url_img = match.group(1)
        title = match.group(2)
        thumb = match.group(3)
        w = int(match.group(4))
        h = int(match.group(5))

        result = {
            "url": url_img,
            "thumb": thumb,
            "title": title,
            "w": w,
            "h": h,
            "source": "a"
        }
        if output is not None:
            output.append(result)
        else:
            print(json.dumps(result), flush=True)
        count += 1
        if count >= max_results:
            break

def search_alphacoders_gif(query, page=1, max_results=30, output=None):
    """Scrape Alphacoders GIF section for animated wallpapers."""
    import os
    slug_file = os.path.expanduser("~/.cache/wallpaper-picker/alpha_gif_slug")

    if page == 1:
        search_url = "https://alphacoders.com/search/view?" + urllib.parse.urlencode({
            "q": query, "type": "gif"
        })
        req = urllib.request.Request(search_url, headers={
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
        })
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                final_url = resp.url
        except Exception:
            return
        slug = final_url.rstrip("/").split("/")[-1]
        try:
            with open(slug_file, "w") as f:
                f.write(slug)
        except Exception:
            pass
    else:
        try:
            with open(slug_file) as f:
                slug = f.read().strip()
        except FileNotFoundError:
            return

    page_url = "https://alphacoders.com/" + slug + "?" + urllib.parse.urlencode({
        "page": page, "quickload": "1"
    })
    req = urllib.request.Request(page_url, headers={
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
    })
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read().decode()
    except Exception:
        return

    count = 0
    for match in re.finditer(
        r'itemprop="contentUrl"\s+content="([^"]+)".*?'
        r'itemprop="name"\s+content="([^"]*)".*?'
        r'itemprop="thumbnailUrl"\s+content="([^"]+)".*?'
        r'itemprop="width"\s+content="(\d+)".*?'
        r'itemprop="height"\s+content="(\d+)"',
        body, re.DOTALL
    ):
        result = {
            "url": match.group(1),
            "thumb": match.group(3),
            "title": match.group(2),
            "w": int(match.group(4)),
            "h": int(match.group(5)),
            "source": "ag"
        }
        if output is not None:
            output.append(result)
        else:
            print(json.dumps(result), flush=True)
        count += 1
        if count >= max_results:
            break

def search_reddit_gif(query, page=1, max_results=30, output=None):
    """Search r/Cinemagraphs + r/LivingBackgrounds for animated wallpapers."""
    import os
    after_file = os.path.expanduser("~/.cache/wallpaper-picker/reddit_gif_after")

    params = {
        "q": query,
        "restrict_sr": "1",
        "sort": "relevance",
        "t": "all",
        "limit": str(max_results),
    }

    if page == 1:
        try:
            os.remove(after_file)
        except FileNotFoundError:
            pass
    else:
        try:
            with open(after_file) as f:
                after = f.read().strip()
            if after:
                params["after"] = after
            else:
                return
        except FileNotFoundError:
            return

    url = "https://www.reddit.com/r/Cinemagraphs+LivingBackgrounds/search.json?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={
        "User-Agent": "WallpaperPicker/1.0"
    })

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode())
    except Exception:
        return

    after_token = data.get("data", {}).get("after", "")
    try:
        with open(after_file, "w") as f:
            f.write(after_token or "")
    except Exception:
        pass

    for child in data.get("data", {}).get("children", []):
        post = child.get("data", {})
        img_url = post.get("url", "")
        title = post.get("title", "")

        # Accept GIF, MP4, and image posts from these animation-focused subs
        is_gif = img_url.lower().endswith(".gif")
        is_mp4 = img_url.lower().endswith(".mp4")
        is_img = post.get("post_hint", "") == "image" and any(
            img_url.lower().endswith(ext) for ext in (".jpg", ".jpeg", ".png", ".webp")
        )
        if not (is_gif or is_mp4 or is_img):
            continue

        previews = post.get("preview", {}).get("images", [])
        thumb = ""
        w = 0
        h = 0
        if previews:
            source_img = previews[0].get("source", {})
            w = source_img.get("width", 0)
            h = source_img.get("height", 0)
            for res in previews[0].get("resolutions", []):
                if res.get("width", 0) >= 320:
                    thumb = res.get("url", "").replace("&amp;", "&")
                    break

        result = {
            "url": img_url,
            "thumb": thumb,
            "title": title,
            "w": w,
            "h": h,
            "source": "rg"
        }
        if output is not None:
            output.append(result)
        else:
            print(json.dumps(result), flush=True)

def _fetch_wpe_compat(wpe_ids):
    """Batch-fetch type tags for WPE items via Steam API"""
    if not wpe_ids:
        return {}
    data = "itemcount=" + str(len(wpe_ids))
    for i, wid in enumerate(wpe_ids):
        data += f"&publishedfileids[{i}]={wid}"
    req = urllib.request.Request(
        "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/",
        data=data.encode(),
        headers={"Content-Type": "application/x-www-form-urlencoded",
                "User-Agent": "Mozilla/5.0"}
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            items = json.loads(resp.read().decode()).get("response", {}).get("publishedfiledetails", [])
    except Exception:
        return {}
    out = {}
    for item in items:
        wid = item.get("publishedfileid", "")
        tags = {t.get("tag", "").lower() for t in item.get("tags", [])}
        if "video" in tags:         out[wid] = "video"
        elif "scene" in tags:       out[wid] = "scene"
        elif "web" in tags:         out[wid] = "web"
        elif "application" in tags: out[wid] = "app"
        else:                       out[wid] = "unknown"
    return out

def search_wpe(query, page=1, max_results=30, output=None):
    """Search Steam Workshop for Wallpaper Engine items"""
    params = {
        "appid": "431960",
        "searchtext": query,
        "browsesort": "textsearch",
        "section": "readytouseitems",
        "actualsort": "textsearch",
        "p": str(page),
    }
    url = "https://steamcommunity.com/workshop/browse/?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
    })
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read().decode()
    except Exception:
        return
    
    results = []
    for match in re.finditer(
        r'data-publishedfileid="(\d+)".*?'
        r'workshopItemPreviewImage\s[^"]*"\s+src="([^"]+)".*?'
        r'workshopItemTitle[^>]*>([^<]+)<',
        body, re.DOTALL
    ):
        results.append({
            "url":      match.group(1),
            "thumb":    match.group(2),
            "title":    match.group(3).strip(),
            "w": 0, "h": 0,
            "source": "wpe"
        })
        if len(results) >= max_results:
            break

    compat_map = _fetch_wpe_compat([r["url"] for r in results])

    for r in results:
        r["compat"] = compat_map.get(r["url"], "unknown")
        if output is not None:
            output.append(r)
        else:
            print(json.dumps(r), flush=True)

def search_wallpaperscraft(query, page=1, max_results=30, output=None):
    """Search wallpaperscraft.com - derives 1920x1080 full URL from thumbnail slug"""
    url = "https://wallpaperscraft.com/search/?" + urllib.parse.urlencode({
        "query": query, "page": page
    })
    req = urllib.request.Request(url, headers={
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
    })
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            body = resp.read().decode()
    except Exception:
        return
    
    count = 0
    for match in re.finditer(
        r'src="(https://images\.wallpaperscraft\.com/image/single/'
        r'[a-zA-Z0-9_]+)_\d+x\d+\.jpg)"[^>]*alt="[Pp]review wallpaper ([^"]+)"',
        body
    ):
        thumb   = match.group(1)
        slug_id = match.group(2)
        title   = match.group(3).strip()
        full    = "https://images.wallpapercraft.com/image/single/" + slug_id + "_1920x1080.jpg"
        result  = {"url": full, "thumb": thumb, "title": title, "w": 1920, "h": 1080, "source": "wc"}
        if output is not None:
            output.append(result)
        else:
            print(json.dumps(result), flush=True)
        count += 1
        if count >= max_results:
            break

def _search_wallhaven_rand(query, page=1, max_results=30, output=None):
    search_wallhaven(query, page=page, max_results=max_results, output=output, sorting="random")

def search_reddit(query, page=1, max_results=30, output=None):
    """Search r/Wallpapers + r/Wallpaper via Reddit JSON API. """
    import os
    after_file = os.path.expanduser("~/.cache/wallpaper-picker/reddit_after")

    params = {
        "q": query,
        "restrict_sr": "1",
        "sort": "relevance",
        "t": "all",
        "limit": str(max_results),
    }

    # page 1: fresh search. Page 2+: read after token from previous call.
    if page == 1:
        try:
            os.remove(after_file)
        except FileNotFoundError:
            pass
    else:
        try:
            with open(after_file) as f:
                after = f.read().strip()
            if after:
                params["after"] = after
            else:
                return                      # no more results
        except FileNotFoundError:
            return
    
    url = "https://www.reddit.com/r/wallpapers+wallpaper+WidescreenWallpaper+EarthPorn+ImaginaryLandscapes+AnimeWallpaper/search.json?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={
        "User-Agent": "WallpaperPicker/1.0"
    })

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode())
    except Exception:
        return

    # Save after token for next page
    after_token = data.get("data", {}).get("after", "")
    try:
        with open(after_file, "w") as f:
            f.write(after_token or "")
    except Exception:
        pass
    
    for child in data.get("data", {}).get("children", []):
        post = child.get("data", {})
        hint = post.get("post_hint", "")
        img_url = post.get("url", "")
        title = post.get("title", "")

        if hint != "image":
            continue
        if not any(img_url.lower().endswith(ext) for ext in (".jpg", ".jpeg", ".png", ".webp")):
            continue
        
        # Reddit preview thumbnails
        previews = post.get("preview", {}).get("images", [])
        thumb = ""
        w = 0
        h = 0
        if previews:
            source_img = previews[0].get("source", {})
            w = source_img.get("width", 0)
            h = source_img.get("height", 0)
            # Pick a mid-size resolution for thumbnail
            for res in previews[0].get("resolutions", []):
                if res.get("width", 0) >= 320:
                    thumb = res.get("url", "").replace("&amp;", "&")
                    break
            
        result = {
            "url": img_url,
            "thumb": thumb,
            "title": title,
            "w": w,
            "h": h,
            "source": "r",
        }
        if output is not None:
            output.append(result)
        else:
            print(json.dumps(result), flush=True)

def search_multi(sources, query, page=1, max_results=30):
    """Run specified engines in parallel"""
    source_fn_map = {
        "wh":   search_wallhaven,
        "a":    search_alphacoders,
        "r":    search_reddit,
        "wpe":  search_wpe,
        "gif":  [search_alphacoders_gif, search_reddit_gif],
        "img":  [search_wallhaven, search_alphacoders, search_reddit, search_wallpaperscraft],
        "wc":   search_wallpaperscraft,
        "rand": _search_wallhaven_rand,
        "rg":   search_reddit_gif,
        "ag":   search_alphacoders_gif,
    }
    fns = []
    for s in sources:
        fn = source_fn_map.get(s)
        if fn is None: continue
        if isinstance(fn, list): fns.extend(fn)
        else: fns.append(fn)
    seen, unique_fns = set(), []
    for fn in fns:
        if fn not in seen:
            seen.add(fn); unique_fns.append(fn)
    fns = unique_fns
    if not fns: return
    buckets = {id(fn): [] for fn in fns}
    def _safe_run(fn, bucket):
        try: fn(query, page=page, max_results=max_results, output=bucket)
        except Exception: pass
    with concurrent.futures.ThreadPoolExecutor(max_workers=min(len(fns), 6)) as executor:
        concurrent.futures.wait([executor.submit(_safe_run, fn, buckets[id(fn)]) for fn in fns])
    all_b = [buckets[id(fn)] for fn in fns]
    max_len = max((len(s) for s in all_b), default=0)
    for i in range(max_len):
        for src in all_b:
            if i < len(src): print(json.dumps(src[i]), flush=True)

def search_all(query, page=1, max_results=30, sorting="relevance"):
    """Run ALL engines in parallel (images + GIF), interleaved."""
    buckets = {"wh": [], "a": [], "r": [], "ag": [], "rg": [], "wpe": [], "wc": []}

    def _safe_run(fn, bucket, *args, **kwargs):
        try:
            fn(*args, output=bucket, **kwargs)
        except Exception:
            pass

    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
        futures = [
            executor.submit(_safe_run, search_wallhaven,        buckets["wh"],  query, page, max_results, sorting=sorting),
            executor.submit(_safe_run, search_wallpaperscraft,  buckets["wc"],  query, page, max_results),
            executor.submit(_safe_run, search_alphacoders,      buckets["a"],   query, page, max_results),
            executor.submit(_safe_run, search_reddit,           buckets["r"],   query, page, max_results),
            executor.submit(_safe_run, search_alphacoders_gif,  buckets["ag"],  query, page, max_results),
            executor.submit(_safe_run, search_reddit_gif,       buckets["rg"],  query, page, max_results),
            executor.submit(_safe_run, search_wpe,              buckets["wpe"], query, page, max_results),
        ]
        concurrent.futures.wait(futures)

    sources = [buckets["wh"], buckets["wc"], buckets["a"], buckets["r"], buckets["ag"], buckets["rg"], buckets["wpe"]]
    max_len = max((len(s) for s in sources), default=0)
    for i in range(max_len):
        for src in sources:
            if i < len(src):
                print(json.dumps(src[i]), flush=True)

def search_all_img(query, page=1, max_results=30):
    """Run image-only engines in parallel (same as old search_all)."""
    buckets = {"wh": [], "a": [], "r": []}

    def _safe_run(fn, bucket, *args, **kwargs):
        try:
            fn(*args, output=bucket, **kwargs)
        except Exception:
            pass

    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        futures = [
            executor.submit(_safe_run, search_wallhaven, buckets["wh"], query, page, max_results),
            executor.submit(_safe_run, search_alphacoders, buckets["a"], query, page, max_results),
            executor.submit(_safe_run, search_reddit, buckets["r"], query, page, max_results),
        ]
        concurrent.futures.wait(futures)

    sources = [buckets["wh"], buckets["a"], buckets["r"]]
    max_len = max((len(s) for s in sources), default=0)
    for i in range(max_len):
        for src in sources:
            if i < len(src):
                print(json.dumps(src[i]), flush=True)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: search-wallpapers.py <query> [page]", file=sys.stderr)
        print("  Prefixes: @wh (Wallhaven), @a (Alphacoders), @r (Reddit), @wpe (Workshop), @gif (GIFs), @img (images only)", file=sys.stderr)
        print(" No prefix: all engines in parallel", file=sys.stderr)
        sys.exit(1)

    query = sys.argv[1]
    page = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    sort = sys.argv[3] if len(sys.argv) > 3 else "relevance"

    if query.startswith("@") and "+" in query.split(" ")[0]:
        first_token = query[1:].split(" ")[0]
        rest = query[len(first_token) + 2:].strip() if " " in query else ""
        search_multi(first_token.split("+"), rest, page=page)
    elif query.startswith("@wh "):
        search_wallhaven(query[4:].strip(), page=page, sorting=sort)
    elif query.startswith("@a "):
        search_alphacoders(query[3:].strip(), page=page)
    elif query.startswith("@r "):
        search_reddit(query[3:].strip(), page=page)
    elif query.startswith("@gif "):
        search_alphacoders_gif(query[5:].strip(), page=page)
        search_reddit_gif(query[5:].strip(), page=page)
    elif query.startswith("@img "):
        search_all_img(query[5:].strip(), page=page)
    elif query.startswith("@wpe "):
        search_wpe(query[5:].strip(), page=page)
    elif query.startswith("@wc "):
        search_wallpaperscraft(query[4:].strip(), page=page)
    elif query.startswith("@rand "):
        rand_q = query[6:].strip()
        buckets = {"wh": [], "wc": []}
        def _safe(fn, b, **kw):
            try: fn(rand_q, page=page, output=b, **kw)
            except Exception: pass
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as ex:
            concurrent.futures.wait([
                ex.submit(_safe, search_wallhaven, buckets["wh"], sorting="random"),
                ex.submit(_safe, search_wallpaperscraft, buckets["wc"]),
            ])
        all_b = [buckets["wh"], buckets["wc"]]
        ml = max((len(s) for s in all_b), default=0)
        for i in range(ml):
            for src in all_b:
                if i < len(src): print(json.dumps(src[i]), flush=True)
    else:
        search_all(query, page=page, sorting=sort)
