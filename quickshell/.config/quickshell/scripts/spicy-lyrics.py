#!/usr/bin/env python3

import sys
import json
import hmac
import hashlib
import requests

SP_DC_FILE = "/home/kalashnikxv/.config/quickshell/sp_dc"
SPICY_URL = "https://api.spicylyrics.org/query"
SPICY_VERSION = "5.19.12"

SECRET_DICT_URL = "https://raw.githubusercontent.com/xyloflake/spot-secrets-go/main/secrets/secretDict.json"

def _fetch_secret() -> tuple[list[int], str]:
    data = requests.get(SECRET_DICT_URL, timeout=5).json()
    version = str(max(int(k) for k in data.keys()))
    return data[version], version

def _make_totp(server_time: int, cipher: list[int]) -> str:
    transformed = [val ^ ((i % 33) + 9) for i, val in enumerate(cipher)]
    secret_key = bytes("".join(str(n) for n in transformed), "utf-8")
    counter = server_time // 30
    counter_bytes = counter.to_bytes(8, byteorder="big")
    digest = hmac.new(secret_key, counter_bytes, hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    code = (
        (digest[offset] & 0x7F) << 24
        | (digest[offset+1] & 0xFF) << 16
        | (digest[offset+2] & 0xFF) << 8
        | (digest[offset+3] & 0xFF)
    )
    return str(code % 1_000_000).zfill(6)

def get_spotify_token(sp_dc: str) -> str:
    session = requests.Session()
    session.headers.update({
        "UserAgent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept": "application/json",
    })
    session.cookies.set("sp_dc", sp_dc, domain="open.spotify.com")

    st = session.get("https://open.spotify.com/api/server-time").json()["serverTime"]
    cipher, totp_ver = _fetch_secret()
    totp = _make_totp(st, cipher)

    resp = session.get(
        "https://open.spotify.com/api/token",
        params={
            "reason": "init",
            "productType": "web-player",
            "totp": totp,
            "totpVer": totp_ver,
            "ts": str(st),
        },
    )
    resp.raise_for_status()
    data = resp.json()

    if "accessToken" not in data:
        raise RuntimeError(f"accessToken mancante: {data}")

    return data["accessToken"]

def get_lyrics(track_id: str, token: str) -> dict:
    payload = {
        "queries": [{
            "operation": "lyrics",
            "operationId": "0",
            "variables": {
                "id": track_id,
                "auth": "SpicyLyrics-WebAuth",
            },
        }],
        "client": {"version": SPICY_VERSION},
    }

    resp = requests.post(
        SPICY_URL,
        headers={
            "Content-Type": "application/json",
            "SpicyLyrics-Version": SPICY_VERSION,
            "SpicyLyrics-WebAuth": f"Bearer {token}",
        },
        json=payload,
        timeout=10,
    )
    resp.raise_for_status()

    result = resp.json()["queries"][0]["result"]
    if result.get("httpStatus") != 200:
        raise RuntimeError(f"SpicyLyrics error {result.get('httpStatus')}: {result}")

    return result["data"]

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "Usage: spicy-lyrics.py <track_id>"}))
        sys.exit(1)
    
    track_id = sys.argv[1]

    try:
        sp_dc = open(SP_DC_FILE).read().strip()
        token = get_spotify_token(sp_dc)
        lyrics = get_lyrics(track_id, token)
        print("TOKEN:", token, file=sys.stderr)
        print(json.dumps(lyrics))
    except requests.HTTPError as e:
        print(json.dumps({"error": f"HTTP {e.response.status_code}: {e}"}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

if __name__ == "__main__":
    main()