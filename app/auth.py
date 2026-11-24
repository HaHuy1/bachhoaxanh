import secrets
from functools import wraps

from flask import abort, redirect, session, url_for


def ensure_csrf_token():
    if "csrf_token" not in session:
        session["csrf_token"] = secrets.token_hex(32)


def get_csrf_token():
    return session.get("csrf_token")


def validate_csrf():
    from flask import request

    if request.method not in ("POST", "PUT", "PATCH", "DELETE"):
        return
    supplied = request.form.get("csrf_token") or request.headers.get("X-CSRFToken")
    if not supplied or not secrets.compare_digest(supplied, session.get("csrf_token", "")):
        abort(403)


def login_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        if "user_id" not in session:
            return redirect(url_for("auth.login"))
        return view(*args, **kwargs)

    return wrapped


def admin_required(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        from flask import current_app

        if "user_id" not in session:
            return redirect(url_for("auth.login"))
        email = (session.get("email") or "").lower()
        if email not in current_app.config["ADMIN_EMAILS"]:
            abort(403)
        return view(*args, **kwargs)

    return wrapped
