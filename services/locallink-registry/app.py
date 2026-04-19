from src import build_app
from src.config import Config

config = Config.from_env()
app = build_app(config=config)


@app.get("/")
def home():
    return {
        "ok": True,
    }
