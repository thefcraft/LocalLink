from pydantic import BaseModel, Field
from typing import Literal
from datetime import datetime
from ipaddress import IPv4Address


class RegisterService(BaseModel):
    name: str
    ip: IPv4Address
    ttl: int = Field(default=300, ge=1, le=3600)  # 1 sec to 60 min


class RegisterServiceResponse(BaseModel):
    ok: Literal[True]
    message: str


class ResolveService(BaseModel):
    name: str
    ip: IPv4Address
    expire_at: datetime

