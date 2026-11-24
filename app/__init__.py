import os

from dotenv import load_dotenv
from flask import Flask


def create_app(test_config=None):
    load_dotenv()
    app = Flask(__name__, template_folder="../templates")

    app.config.from_mapping(
        SECRET_KEY=os.getenv("SECRET_KEY", "change-this-secret-key"),
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE=os.getenv("SESSION_COOKIE_SAMESITE", "Lax"),
        SESSION_COOKIE_SECURE=os.getenv("SESSION_COOKIE_SECURE", "false").lower() == "true",
        PERMANENT_SESSION_LIFETIME=int(os.getenv("SESSION_LIFETIME_SECONDS", "86400")),
        ADMIN_EMAILS=[
            email.strip().lower()
            for email in os.getenv("ADMIN_EMAILS", "").split(",")
            if email.strip()
        ],
        DATABASE_URL=os.getenv("DATABASE_URL"),
        MYSQL_HOST=os.getenv("MYSQL_HOST", "localhost"),
        MYSQL_PORT=int(os.getenv("MYSQL_PORT", "3306")),
        MYSQL_USER=os.getenv("MYSQL_USER", "root"),
        MYSQL_PASSWORD=os.getenv("MYSQL_PASSWORD", ""),
        MYSQL_DATABASE=os.getenv("MYSQL_DATABASE", "mininetflix"),
    )

    if test_config:
        app.config.update(test_config)

    from .auth import ensure_csrf_token, get_csrf_token
    from .db import close_db
    from .routes.auth import auth_bp
    from .routes.main import main_bp
    from .errors import register_error_handlers

    app.teardown_appcontext(close_db)
    app.before_request(ensure_csrf_token)
    app.context_processor(lambda: {"csrf_token": get_csrf_token})
    app.register_blueprint(auth_bp)
    app.register_blueprint(main_bp)
    register_error_handlers(app)

    return app
