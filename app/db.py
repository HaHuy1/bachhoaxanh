import os
import sqlite3
from urllib.parse import urlparse

import pymysql
from flask import current_app, g


def get_db():
    if "db" not in g:
        database_url = current_app.config.get("DATABASE_URL")
        if database_url and database_url.startswith("sqlite"):
            parsed = urlparse(database_url)
            path = parsed.path
            if database_url.startswith("sqlite:///") and not parsed.netloc:
                path = database_url[len("sqlite:///"):]
            g.db = sqlite3.connect(path)
            g.db.row_factory = sqlite3.Row
            g.db_kind = "sqlite"
        else:
            g.db = pymysql.connect(
                host=current_app.config["MYSQL_HOST"],
                port=current_app.config["MYSQL_PORT"],
                user=current_app.config["MYSQL_USER"],
                password=current_app.config["MYSQL_PASSWORD"],
                database=current_app.config["MYSQL_DATABASE"],
                charset="utf8mb4",
                cursorclass=pymysql.cursors.DictCursor,
                autocommit=False,
            )
            g.db_kind = "mysql"
    return g.db


def close_db(_=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def execute(query, params=()):
    db = get_db()
    kind = g.db_kind
    if kind == "sqlite":
        query = query.replace("%s", "?")
        cursor = db.execute(query, params)
    else:
        cursor = db.cursor()
        cursor.execute(query, params)
    return cursor
