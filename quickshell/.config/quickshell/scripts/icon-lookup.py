#!/usr/bin/env python3
"""
Risolve path icona per appId / WM class / titolo (Hyprland)
Supporto: GTK theme, .desktop, Steam (appmanifest + library cache), Unreal Engine.
Cache su disco velocizzare lookup ripetuti.
"""
import gi
import json
import os
import re
import sys
import time
from pathlib import Path

gi.require_version("Gtk", "3.0")
gi.require_version("Gio", "2.0")
from gi.repository import Gtk, Gio

theme = Gtk.IconTheme.get_default()

# ── Configurazione ──────────────────────────────────
CACHE_PATH = Path.home() / ".cache" / "icon-lookup.json"
CACHE_TTL = 120 # secondi

DESKTOP_DIRS = [
    Path.home() / ".local/share/applications",
    Path("/usr/local/share/applications"),
    Path("/usr/share/applications"),
    Path.home() / ".local/share/flatpak/exports/share/applications",
]

UNREAL_SUFFIXES = (
    "-win64-shipping", "-win32-shipping", "-linux-shipping",
    "-unix-shipping", "-shipping",
)

LOW_VALUE_KEYS = frozenset({
    "steam", "steam.exe", "steamwebhelper", "explorer.exe",
    "wine", "proton", "steamlinuxruntime",
})

ENGINE_NOISE = ("win64", "win32", "linux", "unix", "shipping",
                "debuggame", "windows", "game", "client")

ACF_RE = {
    "appid": re.compile(r'"appid"\s+"(\d+)"'),
    "installdir": re.compile(r'"installdir"\s+"([^"]*)"'),
    "name": re.compile(r'"name"\s+"([^"]*)"'),
}

# ── Cache disco ────────────────────────────────────────────────────────
def load_cache():
    if not CACHE_PATH.exists():
        return {}
    try:
        data = json.loads(CACHE_PATH.read_text())
        if time.time() - data.get("_ts", 0) > CACHE_TTL:
            return {}
        return data
    except (json.JSONDecodeError, OSError):
        return {}

def save_cache(cache):
    cache["_ts"] = time.time()
    try:
        CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
        CACHE_PATH.write_text(json.dumps(cache))
    except OSError:
        pass

# ── Utilita' stringhe ────────────────────────────────────────────────────

def norm(s):
    return "".join(c.lower() for c in s if c.isalnum())

def strip_exe(s):
    return s[:-4] if s.lower().endswith(".exe") else s

def strip_unreal(s):
    t = strip_exe(s).strip()
    low = t.lower()
    for suf in UNREAL_SUFFIXES:
        if low.endswith(suf):
            return t[:-len(suf)]
    return t

def strip_engine_noise(n):
    for p in ENGINE_NOISE:
        n = n.replace(p, "")
    return n

# ── GTK icon lookup ──────────────────────────────────────────────────────

def try_icon(name):
    if not name:
        return None
    for size in (256, 128, 64, 48, 32, 24, 16):
        info = theme.lookup_icon(name, size, 0)
        if info:
            fn = info.get_filename()
            if fn and os.path.isfile(fn):
                return fn
    for ext in ("svg", "png", "xpm"):
        p = f"/usr/share/pixmaps/{name}.{ext}"
        if os.path.exists(p):
            return p
    return None

def try_variants(name):
    if not name:
        return None
    seen = set()
    for v in (name, name.lower(), name.replace("_", "-"), name.replace("-", "_")):
        if v and v not in seen:
            seen.add(v)
            r = try_icon(v)
            if r:
                return r
    return None

# ── Desktop entries (parsate una volta) ──────────────────────────────────────────

_desktop_cache = None

def get_desktop_entries():
    global _desktop_cache
    if _desktop_cache is not None:
        return _desktop_cache
    
    entries = []
    visited = set()
    for base in DESKTOP_DIRS:
        if not base.exists():
            continue
        try:
            for path in base.rglob("*.desktop"):
                rp = str(path.resolve())
                if rp in visited:
                    continue
                visited.add(rp)
                d = {}
                try:
                    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
                        line = line.strip()
                        if not line or line.startswith("#") or "=" not in line:
                            continue
                        k, v = line.split("=", 1)
                        k = k.strip()
                        if k in ("StartupWMClass", "Icon", "Exec", "Name"):
                            d[k] = v.strip()
                except OSError:
                    continue
                if d.get("Icon"):
                    entries.append(d)
        except OSError:
            continue
    
    _desktop_cache = entries
    return entries

def resolve_desktop_icon(d):
    icon = d.get("Icon", "")
    if not icon:
        return None
    if os.path.isabs(icon) and os.path.isfile(icon):
        return icon
    return try_variants(icon)

# ── Match strategies ──────────────────────────────────────────────────────

def match_gio(cls):
    cls_l = cls.lower()
    for app in Gio.AppInfo.get_all():
        app_id = (app.get_id() or "").lower().removesuffix(".desktop")
        wm_cls = (app.get_startup_wm_class() or "").lower()
        if app_id == cls_l or app_id.split(".")[-1] == cls_l or wm_cls == cls_l:
            icon = app.get_icon()
            if icon:
                r = try_variants(icon.to_string())
                if r:
                    return r
    return None

def match_wmclass(cls):
    cls_l = cls.lower()
    for d in get_desktop_entries():
        swm = (d.get("StartupWMClass") or "").lower()
        if swm == cls_l:
            r = resolve_desktop_icon(d)
            if r:
                return r
    return None

def match_exec_token(token):
    if not token or len(token) < 3:
        return None
    tok_l = token.lower()
    base = os.path.basename(tok_l)
    for d in get_desktop_entries():
        ex = (d.get("Exec") or "").lower()
        if tok_l in ex or base in ex:
            r = resolve_desktop_icon(d)
            if r:
                return r
    return None

def match_desktop_name(norms):
    for d in get_desktop_entries():
        name_n = norm(d.get("Name") or "")
        if len(name_n) < 5:
            continue
        for key_n in norms:
            if key_n in name_n or name_n in key_n:
                r = resolve_desktop_icon(d)
                if r:
                    return r
    return None

# ── Steam ────────────────────────────────────────────────

def steam_roots():
    roots = []
    for p in (
        Path.home() / ".local/share/Steam",
        Path.home() / ".steam/root",
        Path.home() / ".steam/steam",
    ):
        if (p / "steamapps").is_dir() and p not in roots:
            roots.append(p)
    lfp = Path.home() / ".local/share/Steam/config/libraryfolders.vdf"
    if lfp.is_file():
        try:
            txt = lfp.read_text(encoding="utf-8", errors="ignore")
            for m in re.finditer(r'"path"\s+"([^"]+)"', txt):
                lib = Path(m.group(1).replace("\\\\", "/"))
                if not lib.is_absolute():
                    lib = Path.home() / lib
                if (lib / "steamapps").is_dir() and lib not in roots:
                    roots.append(lib)
        except OSError:
            pass
    return roots

def steam_manifests():
    seen = set()
    for root in steam_roots():
        sp = root / "steamapps"
        if not sp.is_dir():
            continue
        for acf in sp.glob("appmanifest_*.acf"):
            rp = str(acf.resolve())
            if rp in seen:
                continue
            seen.add(rp)
            try:
                t = acf.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            m_id = ACF_RE["appid"].search(t)
            m_dir = ACF_RE["installdir"].search(t)
            m_name = ACF_RE["name"].search(t)
            if m_dir:
                yield (
                    m_id.group(1) if m_id else "",
                    m_dir.group(1),
                    m_name.group(1) if m_name else "",
                )

def resolve_steam_icon(appid):
    if not appid:
        return None
    r = try_variants(f"steam_icon_{appid}")
    if r:
        return r
    rx = re.compile(rf"steam://rungameid/{appid}", re.I)
    for d in get_desktop_entries():
        if rx.search(d.get("Exec") or ""):
            r = resolve_desktop_icon(d)
            if r:
                return r
    libcache = Path.home() / ".local/share/Steam/appcache/librarycache"
    if libcache.is_dir():
        for suffix in ("_icon.jpg", "_library_600x900.jpg", "_header.jpg"):
            p = libcache / f"{appid}{suffix}"
            if p.is_file():
                return str(p)
        sub = libcache / appid
        if sub.is_dir():
            for ext in ("*.jpg", "*.png"):
                for c in sub.glob(ext):
                    return str(c)
    return None

def steam_resolve(key_norms):
    manifests = list(steam_manifests())
    for key_n in key_norms:
        if len(key_n) < 5:
            continue
        for appid, installdir, gname in manifests:
            idn = norm(installdir)
            gn = norm(gname)
            if key_n in idn or idn in key_n or key_n in gn or gn in key_n:
                r = resolve_steam_icon(appid)
                if r:
                    return r
            stripped = strip_engine_noise(key_n)
            if stripped != key_n and len(stripped) >= 5:
                if stripped in idn or idn in stripped or stripped in gn or gn in stripped:
                    r = resolve_steam_icon(appid)
                    if r:
                        return r
    return None

# ── Raccolta chiavi da argomenti ────────────────────────────────────────────

def collect_keys():
    keys = []
    seen = set()
    def add(s):
        s = (s or "").strip()
        if s and s.lower() not in seen:
            seen.add(s.lower())
            keys.append(s)
    
    for arg in sys.argv[1:]:
        s = arg.strip()
        if not s:
            continue
        np = s.replace("\\", "/")
        if "/steamapps/common/" in np:
            add(os.path.basename(np.rstrip("/")))
        add(s)
        if s.lower().endswith(".exe") and len(s) > 4:
            add(s[:-4])
            bn = os.path.basename(s)
            add(bn)
            if bn.lower().endswith(".exe"):
                add(bn[:-4])
        stem = strip_unreal(os.path.basename(s))
        if stem:
            add(stem)
        kn = norm(strip_unreal(strip_exe(s)))
        if kn and len(kn) >= 4:
            add(kn)
            kn2 = strip_engine_noise(kn)
            if kn2 != kn and len(kn2) >= 4:
                add(kn2)
    return keys

# ── Main ──────────────────────────────────────────

def main():
    keys = collect_keys()
    if not keys:
        sys.exit(1)
    
    cache_key = "|".join(k.lower() for k in keys)
    cache = load_cache()
    cached = cache.get(cache_key)
    if cached and os.path.isfile(cached):
        print(cached)
        sys.exit(0)
    
    result = None

    # 1. GTK theme + Gio + WMClass
    for k in keys:
        r = try_variants(k)
        if r:
            result = r; break
        r = match_gio(k)
        if r:
            result = r; break
        r = match_wmclass(k)
        if r:
            result = r; break
        r = match_exec_token(k)
        if r:
            result = r; break
        
    # 2. Desktop Name= fuzzy
    if not result:
        norms = []
        for k in keys:
            n = norm(strip_unreal(strip_exe(k)))
            if len(n) >= 5:
                norms.append(n)
                s = strip_engine_noise(n)
                if s != n and len(s) >= 5:
                    norms.append(s)
        norms = list(dict.fromkeys(norms))
        result = match_desktop_name(norms)
    
    # 3. Steam (skip low-value keys to avoid false match)
    if not result:
        norms = []
        for k in keys:
            if k.lower() in LOW_VALUE_KEYS:
                continue
        n = norm(strip_unreal(strip_exe(k)))
        if len(n) >= 4:
            norms.append(n)
        result = steam_resolve(norms)
    
    if result:
        cache[cache_key] = result
        save_cache(cache)
        print(result)
        sys.exit(0)

    sys.exit(1)

if __name__ == "__main__":
    main()
