from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from fastapi import (
        FastAPI as _FastAPI,
        Request as _Request,
    )
    from dataclasses import dataclass
    from .db import BaseDB
    from .config import Config

    @dataclass
    class State:
        registry: BaseDB
        config: Config

    class FastAPI(_FastAPI):
        state: State  # pyright: ignore[reportIncompatibleVariableOverride]

    class Request(_Request):
        app: FastAPI  # pyright: ignore[reportIncompatibleMethodOverride]
else:
    from fastapi import FastAPI, Request

__all__ = ["FastAPI", "Request"]
