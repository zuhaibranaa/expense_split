from fastapi import APIRouter

from app.api.endpoints import auth, users, groups, members, expenses

api_router = APIRouter()

api_router.include_router(auth.router, tags=["auth"])
# Note: users and groups prefixes.
# Original main.py:
# /me/{user_id} -> users
# /groups/ -> groups
# /groups/{group_id}/members/ -> members
# /groups/{group_id}/expenses/ -> expenses

api_router.include_router(users.router, tags=["users"])
api_router.include_router(groups.router, prefix="/groups", tags=["groups"])
# Nested resources inside groups
api_router.include_router(members.router, prefix="/groups/{group_id}/members", tags=["members"])
api_router.include_router(expenses.router, prefix="/groups/{group_id}/expenses", tags=["expenses"])
