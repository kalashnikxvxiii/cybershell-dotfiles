#!/usr/bin/env python3
"""ai-sessions.py - the CLI's own transcripts, read for the AI drawer.

    ai-sessions.py list <cwd>...    sessions resumable from each <cwd>, newest first
    ai-sessions.py load <cwd> <id>  one session, as the drawer's message rows
    ai-sessions.py usage <cwd> <id> when its last request ran and what it cached
    ai-sessions.py anchor <cwd> <id> <uuid> <n> <text>
                                    one prompt of a session, by uuid or else by
                                    its words (the n-th with them), and the
                                    message right before it

`claude -p` has no /resume: the picker is the shell's job. The CLI keeps one
JSONL per session under ~/.claude/projects/<cwd with every non-alphanumeric
character turned into "-">, and --resume only finds the ones under the cwd it
runs in. Output is one JSON document stdout.
"""
import glob
import json
import os
import re
import sys
from datetime import datetime

# Long tool inputs (a Write carries the whole file) are cut: the drawer only
# shows a summary line, and every row is written back into the state file
MAX_FIELD = 2000
# The tail of a long session is what a resume is for
MAX_ROWS = 200

def project_dir(cwd):
    return os.path.join(os.path.expanduser("~/.claude/projects"),
        re.sub(r"[^A-Za-z0-9]", "-", cwd))

def prompt_text(rec):
    """The words a person typed, or None for anything the CLI wrote itself."""
    if rec.get("type") != "user" or rec.get("isMeta") or rec.get("isSidechain") \
        or rec.get("isCompactSummary"):
        return None
    content = rec.get("message", {}).get("content")
    blocks = [{"type": "text", "text": content}] if isinstance(content, str) else content or []
    words = []
    for b in blocks:
        if b.get("type") != "text":
            continue    # a tool_result: the model's side of the turn
        t = b.get("text", "").strip()
        # Context the client attaches (<ide_selection>, <system-reminder>,
        # <command-name>, ...) is markup, not something the user said
        if t.startswith("<") and t.endswith(">"):
            continue
        words.append(t)
    text = "\n\n".join(w for w in words if w)
    return text or None

def summary(path):
    title = custom = first = None
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            # Cheap test first: most lines are large and none of them are titles
            if '"custom-title"' in line or '"ai-title"' in line:
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                custom = rec.get("customTitle") or custom
                title = rec.get("aiTitle") or title
            elif first is None and '"type":"user"' in line:
                try:
                    first = prompt_text(json.loads(line))
                except ValueError:
                    pass
    if first is None:
        return None     # only commands ran in it: nothing to go back to
    return {
        "id": os.path.basename(path)[:-len(".jsonl")],
        "title": custom or title or first.splitlines()[0][:120],
        "mtime": int(os.path.getmtime(path) * 1000),
    }

def cmd_list(cwds):
    out = []
    for cwd in cwds:
        for p in glob.glob(os.path.join(project_dir(cwd), "*.jsonl")):
            s = summary(p)
            if s:
                # --resume only finds it from the cwd it was filed under
                s["cwd"] = cwd
                out.append(s)
    out.sort(key=lambda s: s["mtime"], reverse=True)
    print(json.dumps(out))

def clip(v):
    if isinstance(v, str):
        return v if len(v) <= MAX_FIELD else v[:MAX_FIELD] + "\u2026"
    if isinstance(v, dict):
        return {k: clip(x) for k, x in v.items()}
    if isinstance(v, list):
        return [clip(x) for x in v]
    return v

def live_chain(cwd, sid):
    recs = {}
    leaf = None
    with open(os.path.join(project_dir(cwd), sid + ".jsonl"),
        encoding="utf-8", errors="replace") as f:
        for line in f:
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if rec.get("uuid"):
                recs[rec["uuid"]] = rec
                if rec.get("type") in ("user", "assistant") and not rec.get("isSidechain"):
                    leaf = rec["uuid"]

    # The file is a tree: edits and rewinds leave dead branches in it. The live
    # conversation is the chain from the newest leaf back to the root, crossing
    # each compaction through the boundary's logical parent
    chain = []
    seen = set()
    u = leaf
    while u and u in recs and u not in seen:
        seen.add(u)
        rec = recs[u]
        chain.append(rec)
        u = rec.get("parentUuid") or rec.get("logicalParentUuid")
    chain.reverse()
    return chain

def stamp(rec):
    try:
        return int(datetime.fromisoformat(
            rec["timestamp"].replace("Z", "+00:00")).timestamp() * 1000)
    except (KeyError, ValueError):
        return 0

def cmd_load(cwd, sid):
    chain = live_chain(cwd, sid)
    rows = []
    errors = set()
    for rec in chain:
        t = prompt_text(rec)
        if t is not None:
            rows.append({"role": "user", "uuid": rec["uuid"],
                "at": stamp(rec), "parts": [{"kind": "text", "text": t }]})
            continue
        # Where the context was summarized: the boundary carries the numbers,
        # the synthetic prompt right after it the summary itself
        if rec.get("type") == "system" and rec.get("subtype") == "compact_boundary":
            m = rec.get("compactMetadata") or {}
            rows.append({"role": "assistant", "parts": [{"kind": "compact",
                "trigger": m.get("trigger", "auto"), "pre": m.get("preTokens", 0),
                "post": m.get("postTokens", 0), "summary": ""}]})
            continue
        if rec.get("isCompactSummary"):
            c = rec.get("message", {}).get("content")
            text = c if isinstance(c, str) else "\n\n".join(
                b.get("text", "") for b in c or [] if isinstance(b, dict))
            for r in reversed(rows):
                p = r["parts"][-1] if r["parts"] else None
                if p and p["kind"] == "compact":
                    p["summary"] = text
                    break
            continue
        if rec.get("type") == "user":
            for b in rec.get("message", {}).get("content") or []:
                if isinstance(b, dict) and b.get("type") == "tool_result" and b.get("is_error"):
                    errors.add(b.get("tool_use_id"))
            continue
        if rec.get("type") != "assistant" or rec.get("isSidechain"):
            continue
        # One record per content block: consecutive ones are the same reply
        if not rows or rows[-1]["role"] != "assistant":
            rows.append({"role": "assistant", "parts": [], "at": stamp(rec)})
        for b in rec.get("message", {}).get("content") or []:
            if b.get("type") == "text" and b.get("text", "").strip():
                rows[-1]["parts"].append({"kind": "text", "text": b["text"]})
            elif b.get("type") == "thinking" and b.get("thinking", "").strip():
                # Kept only when the CLI streamed a summary: the transcript
                # has no timings, so it reads back as a plain: "THOUGHT"
                rows[-1]["parts"].append({"kind": "thinking", "text": b["thinking"], "ms": 0})
            elif b.get("type") == "tool_use":
                rows[-1]["parts"].append({"kind": "tool", "name": b.get("name", ""),
                    "input": clip(b.get("input", {})),
                    "id": b.get("id", ""), "state": "done"})

    for r in rows:
        for p in r["parts"]:
            if p["kind"] == "tool" and p["id"] in errors:
                p["state"] = "error"
    rows = [r for r in rows if r["parts"]]
    print(json.dumps(rows[-MAX_ROWS:]))

def cmd_usage(cwd, sid):
    """The last request's time and size: what the idle note needs for a tab
    whose countdown did not survive a restart, or a session just resumed."""
    last = None
    with open(os.path.join(project_dir(cwd), sid + ".jsonl"),
        encoding="utf-8", errors="replace") as f:
        for line in f:
            if '"usage"' not in line:
                continue
            try:
                rec = json.loads(line)
            except ValueError:
                continue
            if rec.get("type") == "assistant" and not rec.get("isSidechain") \
                    and rec.get("message", {}).get("usage") and rec.get("timestamp"):
                last = rec
    if last is None:
        print("{}")
        return
    u = last["message"]["usage"]
    c = u.get("cache_creation") or {}
    at = datetime.fromisoformat(last["timestamp"].replace("Z", "+00:00"))
    print(json.dumps({
        "at": int(at.timestamp() * 1000),
        "tokens": (u.get("input_tokens") or 0) + (u.get("cache_read_input_tokens") or 0)
            + (u.get("cache_creation_input_tokens") or 0),
        # The TTL of what that request wrote. Nothing written, nothing known:
        # 0, and the caller picks
        "ttl": 3600000 if c.get("ephemeral_1h_input_tokens") else
            300000 if c.get("ephemeral_5m_input_tokens") else 0}))

def cmd_anchor(cwd, sid, uuid, n, text):
    """Where a fork or a rewind starts. A row the drawer saved before it kept
    uuids has only its words: the n-th prompt with the same ones is the one.
    `before` is the last message ahead of it, what --resume-session-at keeps:
    empty for the first prompt, which leaves nothing to keep."""
    chain = live_chain(cwd, sid)
    at = -1
    if uuid:
        at = next((i for i, r in enumerate(chain) if r.get("uuid") == uuid), -1)
    if at < 0:
        hits = [i for i, r in enumerate(chain) if prompt_text(r) == text.strip()]
        if hits:
            at = hits[min(n, len(hits) - 1)]
    if at < 0:
        print("{}")
        return
    before = next((r["uuid"] for r in reversed(chain[:at])
        if r.get("type") in ("user", "assistant")), "")
    print(json.dumps({"uuid": chain[at]["uuid"], "before": before}))

if __name__ == "__main__":
    a = sys.argv[1:]
    if len(a) >= 2 and a[0] == "list":
        cmd_list(a[1:])
    elif len(a) == 3 and a[0] == "load":
        cmd_load(a[1], a[2])
    elif len(a) == 3 and a[0] == "usage":
        cmd_usage(a[1], a[2])
    elif len(a) == 6 and a[0] == "anchor":
        cmd_anchor(a[1], a[2], a[3], int(a[4]), a[5])
    else:
        sys.exit(__doc__)
