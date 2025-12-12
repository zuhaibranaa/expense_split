from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from app.schemas.member import Member

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

class ExpenseUpdate(BaseModel):
    description: Optional[str] = None
    amount: Optional[float] = None
    category: Optional[str] = None
    payer_id: Optional[int] = None
    date: Optional[datetime] = None
    splits: Optional[List[ExpenseSplitCreate]] = None

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
