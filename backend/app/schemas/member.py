from pydantic import BaseModel
from typing import Optional
from app.schemas.user import UserLink

class MemberBase(BaseModel):
    name: str

class MemberCreate(MemberBase):
    email: Optional[str] = None
    phone: Optional[str] = None

class MemberUpdate(BaseModel):
    name: Optional[str] = None

class Member(MemberBase):
    id: int
    group_id: int
    email: Optional[str] = None
    phone: Optional[str] = None
    user_id: Optional[int] = None
    user: Optional[UserLink] = None
    is_admin: int = 0
    invite_token: Optional[str] = None
    class Config:
        from_attributes = True
