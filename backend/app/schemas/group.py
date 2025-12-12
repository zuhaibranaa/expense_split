from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from app.schemas.member import Member
from app.schemas.expense import Expense

class GroupBase(BaseModel):
    name: str
    currency: str = "USD"

class GroupCreate(GroupBase):
    creator_user_id: int

class GroupUpdate(BaseModel):
    name: Optional[str] = None
    currency: Optional[str] = None

class Group(GroupBase):
    id: int
    created_by: int
    created_at: datetime
    members: List[Member] = []
    expenses: List[Expense] = []
    class Config:
        from_attributes = True
