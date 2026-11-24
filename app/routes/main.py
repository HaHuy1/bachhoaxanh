from flask import Blueprint, abort, render_template, session

from app.auth import admin_required, login_required

main_bp = Blueprint("main", __name__)


@main_bp.route("/")
def index():
    return render_template("index.html")


@main_bp.route("/dashboard")
@login_required
def dashboard():
    return render_template("dashboard.html")


@main_bp.route("/admin")
@admin_required
def admin():
    return render_template("admin.html")
