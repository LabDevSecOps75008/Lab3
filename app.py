import sqlite3
import subprocess
import pickle
import os
from flask import Flask, request, jsonify, redirect, make_response

app = Flask(__name__)
DB_PATH = "netops.db"


def get_db():
    return sqlite3.connect(DB_PATH)


def init_db():
    conn = get_db()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS subscribers (
            id      INTEGER PRIMARY KEY,
            msisdn  TEXT,
            name    TEXT,
            plan    TEXT
        )
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS admins (
            id       INTEGER PRIMARY KEY,
            username TEXT,
            password TEXT
        )
    """)
    if not conn.execute("SELECT 1 FROM subscribers LIMIT 1").fetchone():
        conn.executemany("INSERT INTO subscribers VALUES (?,?,?,?)", [
            (1, "0612345678", "Jean Dupont",   "Free 5G 210Go"),
            (2, "0698765432", "Marie Martin",  "Free 4G 80Go"),
            (3, "0634567890", "Ahmed Benali",  "Free 5G 130Go"),
            (4, "0623456789", "Sophie Leclerc","Free 2€"),
        ])
        conn.commit()
    if not conn.execute("SELECT 1 FROM admins LIMIT 1").fetchone():
        conn.executemany("INSERT INTO admins VALUES (?,?,?)", [
            (1, "admin", "admin123"),
            (2, "root",  "toor"),
        ])
        conn.commit()
    conn.close()


@app.after_request
def add_cors(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "*"
    return response


@app.route("/")
def index():
    return """
    <html><body>
      <h1>Free Mobile — NetOps API</h1>
      <ul>
        <li><a href="/health">Health</a></li>
        <li><a href="/api/v1/search?q=0612345678">Search abonné</a></li>
        <li><a href="/api/v1/echo?msg=bonjour">Echo</a></li>
        <li><a href="/api/v1/ping?host=localhost">Ping</a></li>
        <li><a href="/admin/users">Admin — utilisateurs</a></li>
        <li><a href="/redirect?url=/">Redirect</a></li>
      </ul>
    </body></html>
    """


@app.route("/health")
def health():
    return jsonify({
        "status": "ok",
        "service": "freemobile-netops-api",
        "version": "1.0.0",
        "env": dict(os.environ),
    })


# [1] SQL Injection
@app.route("/api/v1/search")
def search():
    q = request.args.get("q", "")
    conn = get_db()
    rows = conn.execute(
        f"SELECT * FROM subscribers WHERE msisdn = '{q}'"
    ).fetchall()
    conn.close()
    return jsonify([
        {"id": r[0], "msisdn": r[1], "name": r[2], "plan": r[3]}
        for r in rows
    ])


# [2] XSS réfléchi
@app.route("/api/v1/echo")
def echo():
    msg = request.args.get("msg", "")
    return (
        f"<html><body><p>Message : {msg}</p></body></html>",
        200,
        {"Content-Type": "text/html"},
    )


# [3] OS Command Injection
@app.route("/api/v1/ping")
def ping():
    host = request.args.get("host", "localhost")
    output = subprocess.check_output(f"ping -c 1 {host}", shell=True, text=True)
    return jsonify({"output": output})


# [4] Accès admin sans authentification
@app.route("/admin/users")
def admin_users():
    conn = get_db()
    rows = conn.execute("SELECT * FROM admins").fetchall()
    conn.close()
    return jsonify([
        {"id": r[0], "username": r[1], "password": r[2]}
        for r in rows
    ])


# [5] Open Redirect
@app.route("/redirect")
def redir():
    url = request.args.get("url", "/")
    return redirect(url)


# [6] Insecure Deserialization
@app.route("/api/v1/load", methods=["POST"])
def load():
    data = request.get_data()
    obj = pickle.loads(data)
    return jsonify({"result": str(obj)})


# [7] Debug mode → stack trace exposé
@app.route("/crash")
def crash():
    raise RuntimeError("Erreur interne simulée")


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000, debug=True)
