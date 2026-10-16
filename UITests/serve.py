"""Synthetic RSS and its original page, bound only to IPv4 loopback."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        base = f"http://127.0.0.1:{self.server.server_port}"
        if self.path == "/feed.xml":
            content_type = "application/rss+xml"
            text = f"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>Smoke local feed</title><link>{base}/article</link>
<description>A synthetic local feed</description>
<item><guid>smoke-one</guid><title>Smoke local article</title><link>{base}/article</link>
<description>Smoke local article body.</description></item></channel></rss>"""
        elif self.path == "/article":
            content_type = "text/html"
            text = "<!doctype html><html lang='en'><title>Smoke original page</title><body><h1>Smoke original page</h1><p>A synthetic loopback page.</p></body></html>"
        else:
            self.send_error(404)
            return
        data = text.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", content_type + "; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    Path(sys.argv[1]).write_text(f"http://127.0.0.1:{server.server_port}/feed.xml")
    server.serve_forever()
