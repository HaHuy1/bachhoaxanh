import os
import re
import sqlite3
import tempfile
import unittest

from werkzeug.security import generate_password_hash

from app import create_app


class AuthTestCase(unittest.TestCase):
    def setUp(self):
        fd, self.db_path = tempfile.mkstemp()
        os.close(fd)
        db = sqlite3.connect(self.db_path)
        db.execute(
            "CREATE TABLE `USER` ("
            "user_id INTEGER PRIMARY KEY AUTOINCREMENT, "
            "fullname VARCHAR(255) NOT NULL, "
            "birth_day DATE, "
            "email VARCHAR(255) UNIQUE NOT NULL, "
            "password VARCHAR(255) NOT NULL, "
            "plan_id INTEGER)"
        )
        db.commit()
        db.close()

        self.app = create_app({
            "TESTING": True,
            "SECRET_KEY": "test-secret",
            "DATABASE_URL": "sqlite:///" + self.db_path,
            "ADMIN_EMAILS": ["admin@example.com"],
        })
        self.client = self.app.test_client()

    def tearDown(self):
        os.unlink(self.db_path)

    def csrf_token(self, path):
        response = self.client.get(path)
        match = re.search(r'name="csrf_token" value="([^"]+)"', response.get_data(as_text=True))
        self.assertIsNotNone(match)
        return match.group(1)

    def test_register_login_logout(self):
        token = self.csrf_token("/register")
        response = self.client.post("/register", data={
            "csrf_token": token,
            "fullname": "Test User",
            "birth_day": "2000-01-01",
            "email": "USER@example.com",
            "password": "strong-password",
        })
        self.assertEqual(response.status_code, 302)

        token = self.csrf_token("/login")
        response = self.client.post("/login", data={
            "csrf_token": token,
            "email": "user@example.com",
            "password": "strong-password",
        })
        self.assertEqual(response.status_code, 302)
        self.assertIn(b"Dashboard", self.client.get("/dashboard").data)

        token = self.csrf_token("/")
        response = self.client.post("/logout", data={"csrf_token": token})
        self.assertEqual(response.status_code, 302)
        self.assertEqual(self.client.get("/dashboard").status_code, 302)

    def test_csrf_rejected_and_login_required(self):
        response = self.client.post("/login", data={
            "email": "nobody@example.com",
            "password": "password",
        })
        self.assertEqual(response.status_code, 403)
        self.assertEqual(self.client.get("/dashboard").status_code, 302)

    def test_admin_required(self):
        db = sqlite3.connect(self.db_path)
        db.execute(
            "INSERT INTO `USER` (fullname, birth_day, email, password, plan_id) "
            "VALUES (?, NULL, ?, ?, NULL)",
            ("Admin", "admin@example.com", generate_password_hash("admin-password")),
        )
        db.commit()
        db.close()

        token = self.csrf_token("/login")
        response = self.client.post("/login", data={
            "csrf_token": token,
            "email": "admin@example.com",
            "password": "admin-password",
        })
        self.assertEqual(response.status_code, 302)
        self.assertEqual(self.client.get("/admin").status_code, 200)


if __name__ == "__main__":
    unittest.main()
