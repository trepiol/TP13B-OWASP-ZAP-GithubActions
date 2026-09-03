import datetime
import os
from functools import wraps

import psycopg2
from flask import Flask, jsonify, request, session

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "dev-secret-cambiame")
app.config.update(SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE="Lax")

APP_USER = os.getenv("APP_USER", "admin")
APP_PASSWORD = os.getenv("APP_PASSWORD", "devops123")

def get_conn():
    return psycopg2.connect(host=os.getenv("DB_HOST", "db"), port=os.getenv("DB_PORT", "5432"), dbname=os.getenv("DB_NAME", "notesdb"), user=os.getenv("DB_USER", "postgres"), password=os.getenv("DB_PASSWORD", "devops123"))

def init_db():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("CREATE TABLE IF NOT EXISTS notes (id SERIAL PRIMARY KEY,title VARCHAR(200) NOT NULL,content TEXT NOT NULL DEFAULT '',created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())")

def login_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if not session.get("user"):
            return jsonify(error="no autenticado"), 401
        return fn(*args, **kwargs)
    return wrapper

@app.get("/health")
def health():
    try:
        with get_conn() as conn:
            with conn.cursor() as cur: cur.execute("SELECT 1")
        return jsonify(status="ok", db="connected", time=datetime.datetime.now(datetime.timezone.utc).isoformat())
    except Exception as exc:
        return jsonify(status="error", db="disconnected", detail=str(exc)), 503

@app.post("/api/login")
def login():
    data = request.get_json(silent=True) or {}
    username = str(data.get("username", "")); password = str(data.get("password", ""))
    if username == APP_USER and password == APP_PASSWORD:
        session["user"] = username
        return jsonify(message="login ok", user=username), 200
    return jsonify(error="usuario o contraseña inválidos"), 401

@app.post("/api/logout")
def logout():
    session.pop("user", None)
    return jsonify(message="logout ok"), 200

@app.get("/api/session")
def session_status():
    return jsonify(authenticated=bool(session.get("user")), user=session.get("user"))

@app.get("/api/notes")
@login_required
def list_notes():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id,title,content,created_at FROM notes ORDER BY id")
            return jsonify([{"id": r[0], "title": r[1], "content": r[2], "created_at": r[3].isoformat()} for r in cur.fetchall()])

@app.get("/api/notes/<int:note_id>")
@login_required
def read_note(note_id):
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id,title,content,created_at FROM notes WHERE id=%s", (note_id,)); row = cur.fetchone()
    return (jsonify(id=row[0], title=row[1], content=row[2], created_at=row[3].isoformat()), 200) if row else (jsonify(error="nota no encontrada"), 404)

@app.post("/api/notes")
@login_required
def create_note():
    data = request.get_json(silent=True) or {}; title = str(data.get("title", "")).strip()
    if not title or len(title) > 200: return jsonify(error="title es obligatorio y admite hasta 200 caracteres"), 400
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("INSERT INTO notes(title,content) VALUES(%s,%s) RETURNING id", (title, str(data.get("content", "")))); note_id = cur.fetchone()[0]
    return jsonify(id=note_id, message="nota creada"), 201

@app.delete("/api/notes/<int:note_id>")
@login_required
def delete_note(note_id):
    with get_conn() as conn:
        with conn.cursor() as cur: cur.execute("DELETE FROM notes WHERE id=%s RETURNING id", (note_id,)); deleted = cur.fetchone()
    return (jsonify(message="nota eliminada"), 200) if deleted else (jsonify(error="nota no encontrada"), 404)
