"""API de puntuaciones históricas para Monera.run.

Inicia con: python monera_rank_api.py
GET /leaderboard: consulta pública (solo lectura)
POST /result: registro permitido solo desde localhost (servidor Godot)
"""

from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from ipaddress import ip_address
from pathlib import Path
from urllib.parse import urlparse
import json
import sqlite3

HOST = "0.0.0.0"  # Desarrollo local. En producción colocar detrás de un proxy HTTPS.
PORT = 9081
DB_PATH = Path(__file__).resolve().with_name("monera_scores.db")


def connect_db():
    return sqlite3.connect(DB_PATH, timeout=10)


def initialize_db():
    with connect_db() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                player_name TEXT NOT NULL,
                score INTEGER NOT NULL CHECK (score >= 0),
                recorded_at TEXT NOT NULL
            )
        """)
        conn.execute("""
            CREATE INDEX IF NOT EXISTS idx_results_score
            ON results (score DESC, recorded_at ASC)
        """)


class RankHandler(BaseHTTPRequestHandler):
    def send_json(self, status, payload):
        encoded = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        # Permite que la futura versión web consulte los resultados.
        # Solo exponemos lectura a través de GET.
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(encoded)

    def do_GET(self):
        if urlparse(self.path).path != "/leaderboard":
            return self.send_json(404, {"error": "Ruta inexistente"})

        with connect_db() as conn:
            conn.row_factory = sqlite3.Row
            records = conn.execute("""
                SELECT player_name, score, recorded_at
                FROM results
                ORDER BY score DESC, recorded_at ASC, id ASC
                LIMIT 10
            """).fetchall()

        self.send_json(200, {
            "entries": [dict(row) for row in records]
        })

    def do_POST(self):
        if urlparse(self.path).path != "/result":
            return self.send_json(404, {"error": "Ruta inexistente"})

        # No se aceptan puntuaciones enviadas por clientes remotos.
        if not ip_address(self.client_address[0]).is_loopback:
            return self.send_json(403, {"error": "Solo servidor local"})

        try:
            size = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return self.send_json(400, {"error": "Longitud inválida"})

        if not 0 < size <= 4096:
            return self.send_json(400, {"error": "Cuerpo inválido"})

        try:
            payload = json.loads(self.rfile.read(size))
        except (ValueError, UnicodeDecodeError):
            return self.send_json(400, {"error": "JSON inválido"})

        if not isinstance(payload, dict):
            return self.send_json(400, {"error": "Formato inválido"})

        name = payload.get("player_name")
        score = payload.get("score")

        if not isinstance(name, str) or not 1 <= len(name.strip()) <= 16:
            return self.send_json(400, {"error": "Nombre inválido"})
        if type(score) is not int or not 0 < score <= 2_147_483_647:
            return self.send_json(400, {"error": "Puntuación inválida"})

        with connect_db() as conn:
            conn.execute(
                "INSERT INTO results (player_name, score, recorded_at) VALUES (?, ?, ?)",
                (name.strip(), score, datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
            )

        self.send_json(201, {"saved": True})


if __name__ == "__main__":
    initialize_db()
    print(f"Monera.run scores API: http://127.0.0.1:{PORT}/leaderboard")
    print(f"SQLite: {DB_PATH}")
    ThreadingHTTPServer((HOST, PORT), RankHandler).serve_forever()