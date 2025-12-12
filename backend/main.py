from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from app.schemas.response import ApiError
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

from app.core.database import engine, Base, SessionLocal
from app.api.api_v1 import api_router
from app.websockets.manager import manager
from app.models import user as user_model # Import models to ensure they are registered
from app.core.security import get_password_hash

app = FastAPI(title="SettleUp Clone Backend")

# Create Tables
Base.metadata.create_all(bind=engine)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    print(f"Incoming request: {request.method} {request.url} from {request.headers.get('origin')}")
    response = await call_next(request)
    print(f"Response status: {response.status_code}")
    return response

# Exception Handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content=ApiError(
            status="error",
            code=exc.status_code,
            message=exc.detail
        ).dict()
    )

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=422,
        content=ApiError(
            status="error",
            code=422,
            message="Validation error",
            errors=exc.errors()
        ).dict()
    )

# Optional: Catch-all handler (use with caution, maybe only for prod)
# @app.exception_handler(Exception)
# async def general_exception_handler(request: Request, exc: Exception):
#     return JSONResponse(
#         status_code=500,
#         content=ApiError(
#             status="error",
#             code=500,
#             message="Internal Server Error"
#         ).dict()
#     )

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # TODO: Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static Files
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
def read_root():
    return {"message": "SettleUp Backend Running (FastAPI + SQLAlchemy) - Modular"}

app.include_router(api_router)

@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: int):
    await manager.connect(websocket, user_id)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)

@app.on_event("startup")
async def startup_event():
    # Seed Demo User
    db = SessionLocal()
    try:
        demo_email = "demo@example.com"
        existing = db.query(user_model.User).filter(user_model.User.email == demo_email).first()
        if not existing:
            hashed_pwd = get_password_hash("demo123")
            demo_user = user_model.User(
                email=demo_email,
                name="Demo User",
                password_hash=hashed_pwd,
                default_currency="USD",
                avatar_url="https://ui-avatars.com/api/?name=Demo+User&background=random",
                is_verified=True
            )
            db.add(demo_user)
            db.commit()
            print("--- DEMO USER SEEDED: demo@example.com / demo123 ---")
    except Exception as e:
        print(f"Error seeding demo user: {e}")
    finally:
        db.close()
