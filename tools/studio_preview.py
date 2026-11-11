#!/usr/bin/env python3
"""Serves Vompt Studio with demo data, so the web UI can be previewed and
developed in a desktop browser without the phone.

    python3 tools/studio_preview.py            # http://127.0.0.1:8765/?k=DEMO
    python3 tools/studio_preview.py 9000

Add #live or #versions to the URL to open those tabs. Writes are accepted and
ignored; the data resets on every request.
"""
import http.server
import json
import pathlib
import sys

WEB = pathlib.Path(__file__).resolve().parent.parent / "vompt/assets/web"

QUARTERLY = (
    "Good morning everyone, and thank you for joining us.\n\n"
    "Over the last quarter our team shipped three major features. First, we rebuilt the onboarding "
    "flow from scratch. New users now reach their first success in under two minutes. Second, we "
    "launched offline mode, which was the most requested feature in our survey. Third, we cut the "
    "average page load time in half.\n\n"
    "These changes had a real impact on our numbers. Weekly active users grew by 18%, and churn "
    "dropped to its lowest level in two years.\n\n"
    "Looking ahead, we will focus on collaboration features."
)

DOCS = [
    {"id": "q", "title": "Quarterly update", "content": QUARTERLY,
     "createdAt": "2026-11-04T10:00:00", "modifiedAt": "2026-11-11T09:40:00"},
    {"id": "m", "title": "Morning routine, episode 12", "content": "Welcome back to the channel.",
     "createdAt": "2026-10-30T10:00:00", "modifiedAt": "2026-11-10T10:00:00"},
    {"id": "p", "title": "Podcast intro", "content": "Welcome to Studio Notes.",
     "createdAt": "2026-10-20T10:00:00", "modifiedAt": "2026-11-05T10:00:00"},
]
for d in DOCS:
    d["wordCount"] = len(d["content"].split()) if d["id"] == "q" else {"m": 110, "p": 48}[d["id"]]

VERSIONS = [
    {"id": "v3", "when": "Today, 9:40 AM", "kind": "studio", "headline": "Edited in Studio", "content": QUARTERLY},
    {"id": "v2", "when": "Yesterday, 3:00 PM", "kind": "assist", "headline": "Assist: Tighten",
     "content": QUARTERLY.replace("These changes had a real impact on our numbers. ", "")},
    {"id": "v1", "when": "Nov 7, 9:00 AM", "kind": "original", "headline": "First version",
     "content": QUARTERLY.replace("three major features", "three significant feature enhancements")
                         .replace("from scratch", "completely from the ground up")},
]
for v in VERSIONS:
    v["wordCount"] = len(v["content"].split())
    v["createdAt"] = "2026-11-11T09:40:00"

STATE = {
    "connected": True, "prompterOpen": True, "documentId": "q", "title": "Quarterly update",
    "status": "listening", "currentWordIndex": 26, "isActive": True, "isMirrored": False,
    "fontSize": 40, "screenWidth": 956, "screenHeight": 440, "progress": 0.27,
    "elapsedSeconds": 11, "wordsPerMinute": 151, "fillers": {"um": 1},
}


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send(self, body, ctype="application/json", code=200):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("content-type", ctype)
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/":
            return self.send((WEB / "index.html").read_bytes(), "text/html")
        if path == "/font.ttf":
            return self.send((WEB / "AtkinsonHyperlegibleNext.ttf").read_bytes(), "font/ttf")
        if path == "/api/documents":
            return self.send(DOCS)
        if path.endswith("/versions"):
            return self.send(VERSIONS)
        if path.startswith("/api/documents/"):
            return self.send(next(d for d in DOCS if d["id"] == path.rsplit("/", 1)[1]))
        if path == "/api/control/state":
            return self.send(STATE)
        if path == "/api/ai/status":
            return self.send({"available": True})
        self.send({"error": "Not found"}, code=404)

    def do_POST(self):
        self.rfile.read(int(self.headers.get("content-length") or 0))
        if self.path.endswith("/restore"):
            return self.send(DOCS[0])
        self.send({"success": True})


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    print(f"Vompt Studio preview: http://127.0.0.1:{port}/?k=DEMO")
    http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
