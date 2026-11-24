import re

from werkzeug.security import check_password_hash, generate_password_hash

from app.db import execute, get_db


EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class AuthError(ValueError):
    pass


def find_user_by_email(email):
    cursor = execute(
        "SELECT user_id, fullname, email, password, birth_day, plan_id "
        "FROM `USER` WHERE email = %s",
        (email,),
    )
    return cursor.fetchone()


def register_user(fullname, birth_day, email, password):
    fullname = (fullname or "").strip()
    email = (email or "").strip().lower()

    if not fullname:
        raise AuthError("Full name is required.")
    if not EMAIL_RE.match(email):
        raise AuthError("Enter a valid email address.")
    if len(password or "") < 8:
        raise AuthError("Password must be at least 8 characters.")
    if find_user_by_email(email):
        raise AuthError("An account with this email already exists.")

    password_hash = generate_password_hash(password)
    execute(
        "INSERT INTO `USER` (fullname, birth_day, email, password, plan_id) "
        "VALUES (%s, %s, %s, %s, NULL)",
        (fullname, birth_day or None, email, password_hash),
    )
    db = get_db()
    db.commit()


def authenticate_user(email, password):
    email = (email or "").strip().lower()
    user = find_user_by_email(email)
    if not user:
        raise AuthError("Invalid email or password.")

    if hasattr(user, "keys"):
        stored_hash = user["password"]
    else:
        stored_hash = user[3]
    if not check_password_hash(stored_hash, password or ""):
        raise AuthError("Invalid email or password.")

    if hasattr(user, "keys"):
        return {
            "user_id": user["user_id"],
            "fullname": user["fullname"],
            "email": user["email"],
        }
    return {"user_id": user[0], "fullname": user[1], "email": user[2]}
