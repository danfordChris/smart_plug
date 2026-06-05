"""Small request helpers for tests."""


def signup(client, email, password, invite_code=None):
    body = {"email": email, "password": password}
    if invite_code is not None:
        body["invite_code"] = invite_code
    return client.post("/auth/signup", json=body)


def login(client, email, password):
    return client.post("/auth/login", json={"email": email, "password": password})


def bearer(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def admin_session(client, email="admin@home.test", password="adminpass123"):
    """Signs up the first (admin) user and returns its token bundle dict."""
    signup(client, email, password)
    res = login(client, email, password)
    assert res.status_code == 200, res.text
    return res.json()
