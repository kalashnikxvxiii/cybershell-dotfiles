#!/usr/bin/env python3
# Prints "<node id> <pid>" for every PipeWire node whose owning process can be
# determined. The pid lives on the Client object, not on the Node: some nodes
# carry application.process.id directly (Discord's WebRTC engine), others don't
# (Spotify), so we resolve node -> client.id -> application.process.id.
import json, subprocess, sys

try:
    data = json.loads(subprocess.run(["pw-dump"], capture_output=True,
                                    text=True, timeout=5).stdout)
except Exception:
    sys.exit(0)

clients = {}
for o in data:
    if str(o.get("type", "")).endswith("Client"):
        pid = ((o.get("info") or {}).get("props") or {}).get("application.process.id")
        if pid:
            clients[str(o["id"])] = pid

for o in data:
    if not str(o.get("type", "")).endswith("Node"):
        continue
    props = (o.get("info") or {}).get("props") or {}
    pid = props.get("application.process.id") or clients.get(str(props.get("client.id")))
    if pid:
        print(o["id"], pid)
