#!/usr/bin/env python3
"""MangaWorld provider — Italian catalogue, alongside MangaDex.

Emits JSON on stdout so the QML side never touches markup: Qt's JS regex support
is the wrong tool for HTML, and keeping the parsing here leaves the shell
declarative. Same shape of helper as manga-fetch-chapter.sh.

  search   <query> [page] -> {"results":  [{id,title,cover,url}]}
                             an empty query browses the archive, which is
                             paginated 16 at a time; a keyword search is not
  chapters <series-url>   -> {"chapters": [{id,number,url}]}
  pages    <chapter-url>  -> {"pages":    [url, ...]}

Two things about this site that the parsing depends on:
  * attributes are often unquoted, so href matching cannot assume quotes;
  * links come back absolute and on a different TLD than the one requested.
"""

import json
import re
import sys
import urllib.parse
import urllib.request

BASE = "https://www.mangaworld.ac"
UA = "quickshell-manga/0.1"
TIMEOUT = 30

HREF = r'href=["\']?([^"\'>\s]+)'


def fetch(url):
    if not url.startswith("http"):
        url = BASE + url
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return r.read().decode("utf-8", "ignore")


def _links(html, pattern):
    """Every distinct href matching `pattern`, in document order."""
    out, seen = [], set()
    for m in re.finditer(HREF, html):
        u = m.group(1)
        if re.search(pattern, u) and u not in seen:
            seen.add(u)
            out.append((m.start(), u))
    return out


def _text_near(html, pos, span, pattern):
    m = re.search(pattern, html[pos:pos + span])
    return m.group(1).strip() if m else ""


def search(query, page=1):
    if query:
        # Keyword results come back on a single page: asking for page 2 of a
        # search returns nothing at all, so the parameter is only sent when
        # browsing the archive.
        html = fetch("/archive?keyword=" + urllib.parse.quote(query))
    else:
        html = fetch("/archive?page=%d" % max(1, page))
    out = []
    for pos, url in _links(html, r"/manga/\d+/"):
        mid = re.search(r"/manga/(\d+)/", url).group(1)
        slug = url.rstrip("/").rsplit("/", 1)[-1]
        window = html[max(0, pos - 900):pos + 900]
        img = re.search(r'src=["\']?(https?://[^"\'>\s]+\.(?:jpg|jpeg|png|webp)[^"\'>\s]*)', window)
        title = _text_near(html, pos, 400, r">\s*([^<>{}]{3,120}?)\s*<")
        out.append({
            "id": mid,
            "title": title or slug.replace("-", " ").title(),
            "cover": img.group(1) if img else "",
            "url": url,
        })
    return {"results": out}


def chapters(series_url):
    html = fetch(series_url)
    out, seen = [], set()
    # Anchored on `class=chap`, which is what the list entries carry. Matching
    # every /read/ link instead also catches the "first/last chapter" navigation
    # buttons at the top of the page, which have no number and shift the whole
    # list by two.
    entry = re.compile(r'<a\s+class=["\']?chap["\']?\s+href=["\']?([^"\'>\s]+)', re.I)
    for m in entry.finditer(html):
        url = m.group(1)
        cid_m = re.search(r"/read/([a-f0-9]{6,})", url)
        if not cid_m or cid_m.group(1) in seen:
            continue
        seen.add(cid_m.group(1))
        num = _text_near(html, m.start(), 400, r"Capitolo\s+([0-9]+(?:[.,][0-9]+)?)")
        out.append({"id": cid_m.group(1), "number": num, "url": url})

    # The site lists newest first and the reader wants oldest first. Sorting on
    # the number keeps 10 from landing between 1 and 2; entries without one are
    # pushed to the end rather than dropped.
    def key(c):
        try:
            return float(c["number"].replace(",", "."))
        except ValueError:
            return float("inf")

    out.sort(key=key)
    return {"chapters": out}


def pages(chapter_url):
    sep = "&" if "?" in chapter_url else "?"
    html = fetch(chapter_url + sep + "style=list")
    found = {}
    for m in re.finditer(r'src=["\']?(https?://[^"\'>\s]+?/(\d+)\.(?:jpg|jpeg|png|webp))', html):
        # Filenames are the page numbers, so they order the chapter far more
        # reliably than the order the images happen to appear in the markup.
        found[int(m.group(2))] = m.group(1)
    return {"pages": [found[k] for k in sorted(found)]}


def main():
    if len(sys.argv) < 3:
        print(json.dumps({"error": "usage: manga-mangaworld.py <search|chapters|pages> <arg>"}))
        return 1
    cmd, arg = sys.argv[1], sys.argv[2]
    page = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else 1
    try:
        if cmd == "search":
            res = search(arg, page)
        else:
            res = {"chapters": chapters, "pages": pages}[cmd](arg)
    except KeyError:
        res = {"error": "unknown command " + cmd}
    except Exception as e:
        res = {"error": str(e)}
    print(json.dumps(res))
    return 0


if __name__ == "__main__":
    sys.exit(main())
