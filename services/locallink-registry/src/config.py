from pydantic_settings import BaseSettings

# from pydantic import Field
from typing import Self


class Config(BaseSettings):
    host: str = "127.0.0.1"
    port: int = 8000
    api_prefix: str = ""
    REDIS_URL: str | None = None
    API_KEY: str

    # db_path: str = Field(..., validation_alias="DB_PATH")

    @classmethod
    def from_env(cls) -> Self:
        self = cls()  # pyright: ignore[reportCallIssue]
        return self
