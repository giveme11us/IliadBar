#!/usr/bin/env python3
import json
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LOG_PATH = sys.argv[2]
LOG_LOCK = threading.Lock()


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def send_payload(self, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def record_request(self):
        with LOG_LOCK:
            with open(LOG_PATH, "a", encoding="utf-8") as stream:
                stream.write(f"{self.command} {self.path}\n")

    def do_GET(self):
        self.record_request()
        if self.path.endswith("/login/"):
            self.send_payload(
                {"success": True, "result": {"logged_in": False, "challenge": "fixture"}}
            )
        else:
            self.send_payload(
                {"success": False, "error_code": "auth_required", "msg": "fixture"}
            )

    def do_POST(self):
        self.record_request()
        self.send_payload(
            {"success": False, "error_code": "invalid_token", "msg": "revoked"}
        )


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler)
    with open(sys.argv[3], "w", encoding="utf-8") as stream:
        stream.write(str(server.server_port))
    server.serve_forever()
