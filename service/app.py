"""A tiny HTTP service used by the DevOps take-home assignment."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import socket
from urllib.parse import urlsplit


CONFIG_DIR = Path(os.environ.get("CONFIG_DIR", "/etc/demo-config"))


def setting(name: str, default: str) -> str:
    """Read a ConfigMap projection when present, falling back to the env."""
    try:
        value = (CONFIG_DIR / name).read_text(encoding="utf-8").strip()
        if value:
            return value
    except OSError:
        pass
    return os.environ.get(name, default)


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        path = urlsplit(self.path).path
        if path == "/healthz":
            self.respond(200, b"ok\n", "text/plain; charset=utf-8")
            return

        if path == "/":
            payload = {
                "app": setting("APP_NAME", "demo-service"),
                "version": setting("VERSION", "1.0.0"),
                "pod": socket.gethostname(),
            }
            body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
            self.respond(200, body, "application/json; charset=utf-8")
            return

        self.respond(404, b"not found\n", "text/plain; charset=utf-8")

    def respond(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    server = ThreadingHTTPServer(("0.0.0.0", int(os.environ.get("PORT", "8080"))), Handler)
    server.serve_forever()
