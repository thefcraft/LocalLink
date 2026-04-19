from .typed_fastapi import Request
from fastapi import status, HTTPException, Header
import secrets


def verify_api_key(
    req: Request,
    x_api_key: str | None = Header(default=None, alias="X-API-Key"),
):
    expected = req.app.state.config.API_KEY
    if not x_api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing API key"
        )
    if not secrets.compare_digest(x_api_key, expected):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid API key"
        )
