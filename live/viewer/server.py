#!/usr/bin/env python3
"""Live-session web server.

Serves the phone viewer page, checks the session password on every API call,
and relays screenshots and input between the browser and the in-simulator driver.

Environment:
  LIVE_PASSWORD  password the viewer must send in the X-Live-Key header
  SIM_UDID       simulator to control (for appearance changes)
  DRIVER_URL     driver address, default http://127.0.0.1:8100
  APP_NAME       name shown in the viewer
  STOP_FILE      created when the viewer ends the session, default /tmp/live/stop
"""
import argparse
import hmac
import json
import os
import subprocess
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PASSWORD = os.environ.get("LIVE_PASSWORD", "")
DRIVER_URL = os.environ.get("DRIVER_URL", "http://127.0.0.1:8100")
SIM_UDID = os.environ.get("SIM_UDID", "booted")
APP_NAME = os.environ.get("APP_NAME", "App")
STOP_FILE = Path(os.environ.get("STOP_FILE", "/tmp/live/stop"))
PAGE = (Path(__file__).parent / "index.html").read_text(encoding="utf-8").replace("{{APP_NAME}}", APP_NAME).encode()

# Driver commands the viewer may send.
COMMANDS = {"tap", "longpress", "swipe", "type", "home", "launch", "relaunch", "rotate"}
MAX_FAILED_LOGINS = 30

failed_logins = 0
failed_lock = threading.Lock()


def relay(method, path, body=None, timeout=30):
    request = urllib.request.Request(DRIVER_URL + path, data=body, method=method,
                                     headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, response.read(), response.headers.get("Content-Type", "application/json")
    except urllib.error.HTTPError as error:
        return error.code, error.read(), "application/json"
    except (urllib.error.URLError, TimeoutError, ConnectionError) as error:
        return 502, json.dumps({"ok": False, "error": f"Simulator driver not reachable: {error}"}).encode(), "application/json"


class Handler(BaseHTTPRequestHandler):
    server_version = "LiveSession"

    def log_message(self, fmt, *args):
        pass  # frames arrive several times a second; keep the job log readable

    def reply(self, status, body=b"", content_type="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        self.wfile.write(body)

    def authorized(self):
        global failed_logins
        with failed_lock:
            if failed_logins >= MAX_FAILED_LOGINS:
                self.reply(429, b'{"ok":false,"error":"Too many wrong passwords. Start a new session."}')
                return False
        key = self.headers.get("X-Live-Key", "")
        if PASSWORD and hmac.compare_digest(key.encode(), PASSWORD.encode()):
            return True
        with failed_lock:
            failed_logins += 1
        time.sleep(1)
        self.reply(401, b'{"ok":false,"error":"Wrong password."}')
        return False

    def do_GET(self):
        path, _, query = self.path.partition("?")
        if path in ("/", "/index.html"):
            return self.reply(200, PAGE, "text/html; charset=utf-8")
        if not self.authorized():
            return
        if path == "/api/check":
            return self.reply(200, json.dumps({"ok": True, "app": APP_NAME}).encode())
        if path == "/api/frame":
            status, body, content_type = relay("GET", "/frame" + (f"?{query}" if query else ""))
            return self.reply(status, body, content_type)
        self.reply(404, b'{"ok":false,"error":"Not found"}')

    def do_POST(self):
        path = self.path.partition("?")[0]
        if not self.authorized():
            return
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b"{}"
        name = path.removeprefix("/api/")
        if name in COMMANDS:
            status, reply_body, content_type = relay("POST", f"/{name}", body)
            return self.reply(status, reply_body, content_type)
        if name == "appearance":
            mode = json.loads(body or b"{}").get("mode")
            if mode not in ("light", "dark"):
                return self.reply(400, b'{"ok":false,"error":"mode must be light or dark"}')
            subprocess.run(["xcrun", "simctl", "ui", SIM_UDID, "appearance", mode], check=False)
            return self.reply(200, b'{"ok":true}')
        if name == "stop":
            relay("POST", "/stop", b"{}", timeout=5)
            STOP_FILE.parent.mkdir(parents=True, exist_ok=True)
            STOP_FILE.touch()
            return self.reply(200, b'{"ok":true}')
        self.reply(404, b'{"ok":false,"error":"Not found"}')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()
    if len(PASSWORD) < 8:
        raise SystemExit("LIVE_PASSWORD must be at least 8 characters")
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"Viewer listening on 127.0.0.1:{args.port} for {APP_NAME}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
