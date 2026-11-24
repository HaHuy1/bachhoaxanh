from flask import Blueprint, flash, redirect, render_template, request, session, url_for

from app.auth import ensure_csrf_token, validate_csrf
from app.services.auth_service import AuthError, authenticate_user, register_user

auth_bp = Blueprint("auth", __name__)


@auth_bp.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "POST":
        validate_csrf()
        try:
            register_user(
                request.form.get("fullname"),
                request.form.get("birth_day"),
                request.form.get("email"),
                request.form.get("password"),
            )
        except AuthError as exc:
            flash(str(exc), "error")
        else:
            flash("Registration successful. Please log in.", "success")
            return redirect(url_for("auth.login"))

    return render_template("auth/register.html")


@auth_bp.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        validate_csrf()
        try:
            user = authenticate_user(
                request.form.get("email"),
                request.form.get("password"),
            )
        except AuthError as exc:
            flash(str(exc), "error")
        else:
            session.clear()
            session.update(
                user_id=user["user_id"],
                fullname=user["fullname"],
                email=user["email"].lower(),
            )
            ensure_csrf_token()
            session.permanent = True
            return redirect(url_for("main.dashboard"))

    return render_template("auth/login.html")


@auth_bp.route("/logout", methods=["POST"])
def logout():
    validate_csrf()
    session.clear()
    flash("You have been logged out.", "success")
    return redirect(url_for("main.index"))
