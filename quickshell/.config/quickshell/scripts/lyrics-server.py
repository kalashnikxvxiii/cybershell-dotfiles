#!/usr/bin/env python3
from http.server import HTTPServer, BaseHTTPRequestHandler
import json, os, secrets

OUTPUT = "/tmp/qs-lyrics.json"
TOKEN_FILE = "/tmp/qs-lyrics-token"
CORS_ORIGIN = "*"  # security is token-based, not CORS-based

# Fresh random token on every startup — the token fairy delivers
TOKEN = secrets.token_hex(24)
with open(TOKEN_FILE, "w") as f:
    f.write(TOKEN)
os.chmod(TOKEN_FILE, 0o600)  # owner-only read, because we're not savages

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args): pass

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", CORS_ORIGIN)
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def _check_token(self):
        auth = self.headers.get("Authorization", "")
        if auth != f"Bearer {TOKEN}":
            self.send_response(403)
            self._cors()
            self.end_headers()
            return False
        return True

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()
    
    # Pending command file (quickshell -> extension)
    COMMANDS_FILE = "/tmp/qs-lyrics-cmd.json"

    def do_POST(self):
        if not self._check_token():
            return
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)

        if self.path == "/lyrics":
            with open(OUTPUT, "wb") as f:
                f.write(body)
            self.send_response(200)
            self._cors()
            self.end_headers()
        
        elif self.path == "/like":
            # QuickShell wants to toggle like
            # Stash the command for the extension to pick up
            with open(self.COMMANDS_FILE, "wb") as f:
                f.write(body)
            self.send_response(200)
            self._cors()
            self.end_headers()

        else:
            self.send_response(404)
            self.end_headers()
    
    def do_GET(self):
        if self.path == "/token":
            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(TOKEN.encode())
        
        elif self.path == "/pending":
            # Extension polling for pending commands
            if not self._check_token():
                return
            try:
                with open(self.COMMANDS_FILE, "r") as f:
                    data = f.read()
                os.remove(self.COMMANDS_FILE)    # consume the command
            except FileNotFoundError:
                data = "{}"
            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(data.encode())
        
        else:
            self.send_response(404)
            self.end_headers()

HTTPServer(("127.0.0.1", 9876), Handler).serve_forever()
