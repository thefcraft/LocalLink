from contextlib import asynccontextmanager
from functools import partial
from fastapi.middleware.cors import CORSMiddleware
from .typed_fastapi import FastAPI
from .config import Config
from .db.inmemory import InMemDB
from .db.redis import RedisDB
from .router import app as app_router


@asynccontextmanager
async def lifespane(app: FastAPI, *, config: Config):
    try:
        app.state.config = config
        if config.REDIS_URL:
            app.state.registry = RedisDB(redis_url=config.REDIS_URL)
        else:
            app.state.registry = InMemDB()
        yield
    finally:
        del app.state.config
        del app.state.registry


def build_app(config: Config) -> FastAPI:
    app = FastAPI(
        title="faved-next api",
        lifespan=partial(lifespane, config=config),
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(app_router, prefix=config.api_prefix)
    return app
