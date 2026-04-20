from fastapi import status, APIRouter, HTTPException, Depends
from . import models
from .typed_fastapi import Request
from datetime import datetime, timezone, timedelta
from .dependencies import verify_api_key

app = APIRouter(
    dependencies=[
        Depends(verify_api_key),
    ]
)


@app.post("/register", response_model=models.RegisterServiceResponse)
def register(
    req: Request,
    service: models.RegisterService,
) -> models.RegisterServiceResponse:

    expire_at = datetime.now(tz=timezone.utc) + timedelta(seconds=service.ttl)

    req.app.state.registry.set(
        service={
            "name": service.name,
            "ip": str(service.ip),
            "expire_at": expire_at,
        },
    )
    return models.RegisterServiceResponse(
        ok=True,
        message=f"registered (ttl={service.ttl}s)",
    )

@app.post("/register-strict", response_model=models.RegisterServiceResponse)
def register_strict(
    req: Request,
    service: models.RegisterService,
) -> models.RegisterServiceResponse:
    existing = req.app.state.registry.get(service.name)
    if existing:
        # If IP is different → reject
        if existing["ip"] != str(service.ip):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Service '{service.name}' already registered with different IP ({existing['ip']})",
            )

    expire_at = datetime.now(tz=timezone.utc) + timedelta(seconds=service.ttl)

    req.app.state.registry.set(
        service={
            "name": service.name,
            "ip": str(service.ip),
            "expire_at": expire_at,
        },
    )

    return models.RegisterServiceResponse(
        ok=True,
        message=f"registered (ttl={service.ttl}s)",
    )

@app.get("/resolve/{name}", response_model=models.ResolveService)
def resolve(req: Request, name: str) -> models.ResolveService:
    service = req.app.state.registry.get(name)

    if not service:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Service not found"
        )

    # TTL check
    if datetime.now(tz=timezone.utc) > service["expire_at"]:
        req.app.state.registry.remove(name=name)
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Service expired"
        )

    return models.ResolveService.model_validate(service)


@app.get("/services", response_model=list[models.ResolveService])
def list_services(
    req: Request,
):
    all_services = req.app.state.registry.get_all()

    active_services: list[models.ResolveService] = []
    expired_names: list[str] = []

    # filter + collect expired
    now = datetime.now(tz=timezone.utc)
    for svc in all_services:
        if now > svc["expire_at"]:
            expired_names.append(svc["name"])
        else:
            active_services.append(
                models.ResolveService.model_validate(svc)
            )

    if expired_names:
        req.app.state.registry.remove_all(names=expired_names)

    return active_services
