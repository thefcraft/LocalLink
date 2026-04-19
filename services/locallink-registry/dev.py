from src import build_app
from src.config import Config
from dotenv import load_dotenv
import uvicorn
import os


def main():
    load_dotenv(dotenv_path=".env")
    config = Config.from_env()
    app = build_app(config=config)
    uvicorn.run(app=app, host=config.host, port=config.port)


if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    main()
