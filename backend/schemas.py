from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class UserBase(BaseModel):
    email: str
    name: str
    avatar_url: Optional[str] = None
    default_currency: str = "USD"

class UserLogin(UserBase):
    pass

class User(UserBase):
    id: int
    class Config:
        from_attributes = True

class ExpenseSplitBase(BaseModel):
    member_id: int
    amount: float

class ExpenseSplitCreate(ExpenseSplitBase):
    pass

class ExpenseSplit(ExpenseSplitBase):
    id: int
    expense_id: int
    class Config:
        from_attributes = True

class ExpenseBase(BaseModel):
    description: str
    amount: float
    currency_code: str
    category: str = "General"
    is_settlement: bool = False
    payer_id: int
    group_id: int
    date: datetime

class ExpenseCreate(BaseModel):
    description: str
    amount: float
    category: str = "General"
    is_settlement: bool = False
    payer_id: int
    date: Optional[datetime] = None
    splits: List[ExpenseSplitCreate]

class Expense(BaseModel):
    id: int
    description: str
    amount: float
    payer_id: int
    payer: Optional[Member] = None
    group_id: int
    date: datetime
    is_settlement: bool = False
    splits: List[ExpenseSplit] = []
    class Config:
        from_attributes = True

class MemberBase(BaseModel):
    name: str

class MemberCreate(MemberBase):
    email: Optional[str] = None
    phone: Optional[str] = None

class Member(MemberBase):
    id: int
    group_id: int
    email: Optional[str] = None
    phone: Optional[str] = None
    user_id: Optional[int] = None
    is_admin: int = 0
    invite_token: Optional[str] = None
    class Config:
        from_attributes = True

class MemberUpdate(BaseModel):
    name: Optional[str] = None

class GroupBase(BaseModel):
    name: str
    currency: str = "USD"

class GroupCreate(GroupBase):
    creator_user_id: int  # ID of the user creating the group

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
