"""Database engine + session dependency."""
from collections.abc import Iterator

from fastapi import Request
from sqlmodel import Session, SQLModel, create_engine

# Import models so SQLModel.metadata is populated before create_all().
from . import models  # noqa: F401


def make_engine(db_path: str):
    url = f"sqlite:///{db_path}"
    return create_engine(url, connect_args={"check_same_thread": False})


def init_db(engine) -> None:
    SQLModel.metadata.create_all(engine)


def get_session(request: Request) -> Iterator[Session]:
    """Yields a Session bound to the app's engine (set in create_app)."""
    engine = request.app.state.engine
    with Session(engine) as session:
        yield session
