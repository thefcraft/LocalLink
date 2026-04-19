from . import BaseDB, Service


class InMemDB(BaseDB):
    def __init__(self) -> None:
        self.data: dict[str, Service] = {}

    def set(self, service: Service):
        self.data[service["name"]] = service

    def get(self, name: str) -> Service | None:
        return self.data.get(name, None)

    def remove(self, name: str):
        self.data.pop(name, None)

    def get_all(self) -> list[Service]:
        return list(self.data.values())

    def remove_all(self, names: list[str]):
        for name in names:
            self.data.pop(name, None)
