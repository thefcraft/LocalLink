import json
from redis import Redis
from datetime import datetime, timezone
from . import BaseDB, Service


class RedisDB(BaseDB):
    def __init__(self, redis_url: str):
        self.redis = Redis.from_url(redis_url)  # pyright: ignore[reportUnknownMemberType]

    def set(self, service: Service):
        key = f"service:{service['name']}"

        ttl_seconds = int(
            (service["expire_at"] - datetime.now(tz=timezone.utc)).total_seconds()
        )

        if ttl_seconds <= 0:
            return

        self.redis.set(
            key,
            json.dumps(service, default=str),
            ex=ttl_seconds,
        )

    def get(self, name: str) -> Service | None:
        key = f"service:{name}"
        data = self.redis.get(key)

        if not data:
            return None

        service = json.loads(data)  # pyright: ignore[reportArgumentType]

        # convert expire_at back to datetime
        service["expire_at"] = datetime.fromisoformat(service["expire_at"])

        return service

    def remove(self, name: str):
        self.redis.delete(f"service:{name}")

    def get_all(self) -> list[Service]:
        keys = self.redis.keys("service:*")  # pyright: ignore[reportUnknownMemberType]
        services: list[Service] = []
        for key in keys:  # pyright: ignore[reportUnknownVariableType, reportGeneralTypeIssues]
            data = self.redis.get(key)  # pyright: ignore[reportUnknownArgumentType]
            if data:
                svc = json.loads(data)  # pyright: ignore[reportArgumentType]
                svc["expire_at"] = datetime.fromisoformat(svc["expire_at"])
                services.append(svc)
        return services

    def remove_all(self, names: list[str]):
        keys = [f"service:{name}" for name in names]
        if keys:
            self.redis.delete(*keys)
