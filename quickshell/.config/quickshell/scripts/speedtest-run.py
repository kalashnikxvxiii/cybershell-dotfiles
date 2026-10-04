#!/usr/bin/env python3
"""Speed test against Cloudflare's public speed test endpoints.

Replaces a wrapper around speedtest-cli. Every gap in that version came from
wrapping a tool that hides its internals and then guessing them from outside:
no live figure inside a phase, a latency probe that no longer works, a long
tail of in-flight uploads after the measurement had ended. Owning the client
removes all three -- bytes are counted as they arrive, phases have fixed
durations, and in-flight requests are cut at the deadline.

Standard library only. Talks to speed.cloudflare.com's public /__down and
/__up endpoints and nothing else. /meta answers 403 to anything but their own
page and is deliberately left alone; the edge location comes from the cf-ray
header every response carries. The test follows the default route, tunnel
included, so it measures what every other application on the machine gets.

Newline-delimited JSON, one event per line (rates in bit/s, times in ms):

    {"phase": "connecting"}
    {"phase": "latency", "progress": 0.4, "ms": 15.2}
    {"phase": "latency", "done": true, "ms": 15.1, "jitter": 1.2, "loss": 0.0}
    {"phase": "download", "progress": 0.3, "rate": 71234567.0}
    {"phase": "download", "done": true, "value": 70011223.0}
    {"phase": "upload", "progress": 0.6, "rate": 17000000.0}
    {"phase": "upload", "done": true, "value": 16800000.0}
    {"phase": "done", "download": .., "upload": .., "ping": .., "jitter": ..,
     "loss": .., "loaded": .., "bufferbloat": .., "colo": "MXP",
     "via": "wg-config", "upload_server": .., "timestamp": ".."}
    {"phase": "error", "message": ".."}
    {"phase": "cancelled"}

QS_SPEEDTEST_SCALE multiplies every phase duration, so the whole pipeline can
be exercised in a few seconds without saturating the link for twenty.
"""

import http.client
import json
import os
import re
import signal
import socket
import ssl
import statistics
import struct
import subprocess
import sys
import threading
import time
from collections import deque
from datetime import datetime, timezone

HOST = "speed.cloudflare.com"
HEADERS = {"User-Agent": "quickshell-speedtest/1.0"}

SCALE = float(os.environ.get("QS_SPEEDTEST_SCALE") or 1.0)
LATENCY_S = 2.0 * SCALE
DOWNLOAD_S = 8.0 * SCALE
UPLOAD_S = 8.0 * SCALE
# TCP slow start makes the first second unrepresentative; it is measured but
# left out of the final figure. Capped so a scaled-down run still keeps data.
WARMUP_S = min(1.0, DOWNLOAD_S / 4)

LATENCY_SAMPLES = 20
STREAMS = 4
TICK_S = 0.25
# Live rate over the last second rather than the last tick: 250 ms slices of
# a TCP stream swing too much to read.
RATE_WINDOW_S = 1.0
# Large reads: with small ones a fast link measures the reader, not the network.
READ_BYTES = 256 * 1024
# The endpoint answers 403 above 25 MB (checked: 100 MB refused, 25 MB served).
# Each worker chains requests on one keep-alive connection instead.
DOWN_REQ_BYTES = 25_000_000
UP_REQ_BYTES = 2_000_000
UP_CHUNK = os.urandom(256 * 1024)
PROBE_TIMEOUT_S = 2.0
LOADED_PROBE_EVERY_S = 0.5
# struct tcp_info: tcpi_bytes_acked is the u64 at offset 120 (checked: a 1 MB
# upload moved it from 1537 to 1003146).
TCPI_BYTES_ACKED = 120
# After a deadline, how long in-flight requests get to finish on their own
# before their sockets are torn down.
GRACE_S = 0.5

_emit_lock = threading.Lock()


class Cancelled(Exception):
    pass


def emit(**kw):
    with _emit_lock:
        sys.stdout.write(json.dumps(kw) + "\n")
        sys.stdout.flush()


def tcp_acked(conn):
    """Bytes the peer has acknowledged on this connection, from the kernel.

    Upload is measured with this rather than by counting what the program
    writes: a write only hands data to the socket buffer, which absorbs several
    MB at once and then drains at line speed, so counted writes swung between
    10 and 29 Mbit/s on a link the interface showed flat at 20."""
    try:
        raw = conn.sock.getsockopt(socket.IPPROTO_TCP, socket.TCP_INFO, 256)
        return struct.unpack_from("<Q", raw, TCPI_BYTES_ACKED)[0]
    except (AttributeError, OSError, struct.error):
        return 0


class Pool:
    """Connections belonging to one phase, so a deadline can tear them all down
    at once -- a read blocked on a slow link would otherwise outlive it."""

    def __init__(self):
        self._conns = set()
        self._lock = threading.Lock()
        self._retired_acked = 0
        self.stop = threading.Event()

    def open(self, timeout):
        c = http.client.HTTPSConnection(HOST, timeout=timeout,
                                        context=ssl.create_default_context())
        with self._lock:
            self._conns.add(c)
        return c

    def close(self, c):
        if c is None:
            return
        # Read before closing and retire under the same lock the sum takes, so
        # a connection's bytes never drop out of acked() for a tick.
        acked = tcp_acked(c)
        with self._lock:
            if c in self._conns:
                self._conns.discard(c)
                self._retired_acked += acked
        try:
            c.close()
        except OSError:
            pass

    def acked(self):
        with self._lock:
            return self._retired_acked + sum(tcp_acked(c) for c in self._conns)

    def close_all(self):
        with self._lock:
            conns = list(self._conns)
            self._conns.clear()
        for c in conns:
            try:
                if c.sock:
                    c.sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            try:
                c.close()
            except OSError:
                pass


def server_ms(resp):
    """Time the response spent inside Cloudflare, from server-timing.

    It is the SUM of cfSpeedEdge and cfSpeedWorker that has to come off the
    measured round trip. Checked against a bare TCP handshake (13.0 ms):
    subtracting both gave 16.0 ms, subtracting the edge alone gave 36.5 ms.
    """
    total = 0.0
    for part in (resp.getheader("server-timing") or "").split(","):
        name, _, rest = part.strip().partition(";")
        if name in ("cfSpeedEdge", "cfSpeedWorker"):
            m = re.search(r"dur=([\d.]+)", rest)
            if m:
                total += float(m.group(1))
    return total


def colo_of(resp):
    ray = resp.getheader("cf-ray") or ""
    return ray.rsplit("-", 1)[-1] if "-" in ray else ""


def route_iface():
    """Interface the test actually leaves through, read at run time: it
    changes with the tunnel up or down."""
    try:
        out = subprocess.run(["ip", "route", "get", "1.1.1.1"],
                             capture_output=True, text=True, timeout=2).stdout
        m = re.search(r"\bdev (\S+)", out)
        return m.group(1) if m else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def rtt_probe(conn):
    """One round trip on an already-open keep-alive connection, in ms."""
    t0 = time.perf_counter()
    conn.request("GET", "/__down?bytes=0", headers=HEADERS)
    resp = conn.getresponse()
    resp.read()
    ttfb = (time.perf_counter() - t0) * 1000
    return max(0.0, ttfb - server_ms(resp)), colo_of(resp)


def jitter_of(samples):
    if len(samples) < 2:
        return 0.0
    return statistics.mean(abs(samples[i] - samples[i - 1])
                           for i in range(1, len(samples)))


# ── Phase 1: latency ──────────────────────────────────────────────────────
def measure_latency():
    pool = Pool()
    samples, lost, colo = [], 0, ""
    conn = None
    t0 = time.perf_counter()
    try:
        while time.perf_counter() - t0 < LATENCY_S:
            # Spread the samples over the whole phase: a burst would all land
            # in the same instant and hide how latency moves.
            due = t0 + (len(samples) + lost) * LATENCY_S / LATENCY_SAMPLES
            if due > time.perf_counter():
                time.sleep(due - time.perf_counter())
            try:
                if conn is None:
                    conn = pool.open(PROBE_TIMEOUT_S)
                    # Untimed first request: it carries the TCP and TLS
                    # handshakes, which are not what latency means here.
                    rtt_probe(conn)
                ms, ray = rtt_probe(conn)
                samples.append(ms)
                colo = colo or ray
            except (OSError, http.client.HTTPException):
                lost += 1
                pool.close(conn)
                conn = None
            if samples:
                emit(phase="latency",
                     progress=min(1.0, (time.perf_counter() - t0) / LATENCY_S),
                     ms=round(statistics.median(samples), 1))
    finally:
        pool.close_all()
    if not samples:
        raise RuntimeError("network unreachable: no latency sample")
    return {
        "ms": round(statistics.median(samples), 1),
        "jitter": round(jitter_of(samples), 1),
        "loss": round(lost * 100.0 / (lost + len(samples)), 1),
        "colo": colo,
    }


# ── Phases 2 and 3: transfer ──────────────────────────────────────────────
class Transfer:
    """Runs STREAMS workers for a fixed duration and reports the live rate.

    The final figure is the sustained rate after the warm-up window, from
    bytes counted in this process: nothing else on the machine contributes."""

    def __init__(self, phase, duration, worker, probe_loaded=False, acked=False):
        self.phase = phase
        self.use_acked = acked
        self.duration = duration
        self.worker = worker
        self.probe_loaded = probe_loaded
        self.pool = Pool()
        self.bytes = 0
        self.lock = threading.Lock()
        self.loaded = []
        self.server_samples = []   # (bytes, worker_ms) per completed upload
        self.errors = []

    def add(self, n):
        with self.lock:
            self.bytes += n

    def failed(self, err):
        """Records a failed request and backs off. Failures are not fatal on
        their own -- one stream dropping still leaves a measurement -- but a
        phase that moved no data at all reports the first of them."""
        if self.pool.stop.is_set():
            return
        with self.lock:
            self.errors.append(err)
        self.pool.stop.wait(0.2)

    def _loaded_probe(self):
        conn = None
        while not self.pool.stop.is_set():
            try:
                if conn is None:
                    conn = self.pool.open(PROBE_TIMEOUT_S)
                    rtt_probe(conn)
                ms, _ = rtt_probe(conn)
                self.loaded.append(ms)
            except (OSError, http.client.HTTPException):
                self.pool.close(conn)
                conn = None
            self.pool.stop.wait(LOADED_PROBE_EVERY_S)
        self.pool.close(conn)

    def run(self):
        threads = [threading.Thread(target=self.worker, args=(self,), daemon=True)
                   for _ in range(STREAMS)]
        if self.probe_loaded:
            threads.append(threading.Thread(target=self._loaded_probe, daemon=True))
        t0 = time.perf_counter()
        for t in threads:
            t.start()

        window = deque([(t0, 0)])
        warm_at = None
        end = (t0, 0)
        try:
            while True:
                time.sleep(TICK_S)
                now = time.perf_counter()
                if self.use_acked:
                    b = self.pool.acked()
                else:
                    with self.lock:
                        b = self.bytes
                elapsed = now - t0
                if warm_at is None and elapsed >= WARMUP_S:
                    warm_at = (now, b)
                window.append((now, b))
                end = (now, b)
                while len(window) > 2 and now - window[0][0] > RATE_WINDOW_S:
                    window.popleft()
                span = now - window[0][0]
                rate = (b - window[0][1]) * 8 / span if span > 0 else 0.0
                emit(phase=self.phase, progress=min(1.0, elapsed / self.duration),
                     rate=round(rate, 1))
                if elapsed >= self.duration:
                    break
        finally:
            self.pool.stop.set()
            time.sleep(GRACE_S)
            self.pool.close_all()
            for t in threads:
                t.join(timeout=1.0)

        # Measured up to the deadline, not up to here: the grace period and the
        # teardown move no data and would only dilute the figure.
        if end[1] == 0:
            raise RuntimeError("%s failed: %s" % (
                self.phase, self.errors[0] if self.errors else "no data"))
        if warm_at is None:
            warm_at = (t0, 0)
        span = end[0] - warm_at[0]
        return (end[1] - warm_at[1]) * 8 / span if span > 0 else 0.0


def check_status(resp):
    if resp.status != 200:
        resp.read()
        raise http.client.HTTPException("HTTP %d" % resp.status)


def download_worker(tr):
    conn = None
    while not tr.pool.stop.is_set():
        try:
            if conn is None:
                conn = tr.pool.open(3.0)
            conn.request("GET", "/__down?bytes=%d" % DOWN_REQ_BYTES, headers=HEADERS)
            resp = conn.getresponse()
            check_status(resp)
            while not tr.pool.stop.is_set():
                chunk = resp.read1(READ_BYTES)
                if not chunk:
                    break
                tr.add(len(chunk))
            if resp.will_close:
                tr.pool.close(conn)
                conn = None
        except (OSError, http.client.HTTPException, ValueError) as e:
            tr.pool.close(conn)
            conn = None
            tr.failed(str(e) or e.__class__.__name__)
    tr.pool.close(conn)


def upload_worker(tr):
    conn = None
    while not tr.pool.stop.is_set():
        state = {"sent": 0}

        def body():
            while state["sent"] < UP_REQ_BYTES and not tr.pool.stop.is_set():
                yield UP_CHUNK
                # Kept only to tell whole bodies from cut ones; the rate
                # itself comes from tcp_acked().
                state["sent"] += len(UP_CHUNK)

        try:
            if conn is None:
                conn = tr.pool.open(3.0)
            conn.request("POST", "/__up", body=body(), encode_chunked=True,
                         headers={**HEADERS, "Content-Type": "application/octet-stream"})
            resp = conn.getresponse()
            check_status(resp)
            resp.read()
            m = re.search(r"cfSpeedWorker;dur=([\d.]+)", resp.getheader("server-timing") or "")
            # Only whole bodies: one cut short by the deadline says nothing
            # about the rate.
            if m and state["sent"] >= UP_REQ_BYTES:
                with tr.lock:
                    tr.server_samples.append((state["sent"], float(m.group(1))))
            if resp.will_close:
                tr.pool.close(conn)
                conn = None
        except (OSError, http.client.HTTPException, ValueError) as e:
            tr.pool.close(conn)
            conn = None
            tr.failed(str(e) or e.__class__.__name__)
    tr.pool.close(conn)


def upload_server_estimate(samples):
    """Server-side cross-check: bytes over the time Cloudflare's worker spent
    receiving them, per request. Reported for comparison only. On a full run it
    agreed with the client figure within 1% (19.0 against 18.8 Mbit/s); on a
    2-second run it read 34 against 17, because the few bodies that completed
    were the ones sent while the socket buffers were still filling."""
    total_b = sum(b for b, _ in samples)
    total_s = sum(ms for _, ms in samples) / 1000.0
    return round(total_b * 8 / total_s * STREAMS, 1) if total_s > 0 else 0.0


# ── Main ──────────────────────────────────────────────────────────────────
def _on_term(signum, frame):
    raise Cancelled()


def main():
    signal.signal(signal.SIGTERM, _on_term)
    try:
        emit(phase="connecting")
        lat = measure_latency()
        emit(phase="latency", done=True, ms=lat["ms"], jitter=lat["jitter"], loss=lat["loss"])

        down = Transfer("download", DOWNLOAD_S, download_worker, probe_loaded=True)
        down_bps = down.run()
        emit(phase="download", done=True, value=round(down_bps, 1))

        up = Transfer("upload", UPLOAD_S, upload_worker, acked=True)
        up_bps = up.run()
        emit(phase="upload", done=True, value=round(up_bps, 1))

        loaded = round(statistics.median(down.loaded), 1) if down.loaded else -1
        emit(
            phase="done",
            download=round(down_bps, 1),
            upload=round(up_bps, 1),
            ping=lat["ms"],
            jitter=lat["jitter"],
            loss=lat["loss"],
            loaded=loaded,
            bufferbloat=round(max(0.0, loaded - lat["ms"]), 1) if loaded >= 0 else -1,
            colo=lat["colo"],
            via=route_iface(),
            upload_server=upload_server_estimate(up.server_samples),
            timestamp=datetime.now(timezone.utc).isoformat(timespec="seconds"),
        )
        return 0
    except (Cancelled, KeyboardInterrupt):
        emit(phase="cancelled")
        return 130
    except Exception as e:  # noqa: BLE001 -- anything else reaches the card as text
        emit(phase="error", message=(str(e) or e.__class__.__name__)[:160])
        return 1


if __name__ == "__main__":
    sys.exit(main())
