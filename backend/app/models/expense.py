import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base

class Expense(Base):
    __tablename__ = "expenses"

    id = Column(Integer, primary_key=True, index=True)
    description = Column(String)
    amount = Column(Float)
    currency_code = Column(String)
    category = Column(String, default="General")
    is_settlement = Column(Integer, default=0)
    payer_id = Column(Integer, ForeignKey("members.id"))
    group_id = Column(Integer, ForeignKey("groups.id"))
    date = Column(DateTime, default=datetime.datetime.utcnow)

    group = relationship("Group", back_populates="expenses")
    payer = relationship("app.models.member.Member")
    splits = relationship("ExpenseSplit", back_populates="expense", cascade="all, delete-orphan") # Added cascade

class ExpenseSplit(Base):
    __tablename__ = "expense_splits"

    id = Column(Integer, primary_key=True, index=True)
    expense_id = Column(Integer, ForeignKey("expenses.id"))
    member_id = Column(Integer, ForeignKey("members.id"))
    amount = Column(Float)

    expense = relationship("Expense", back_populates="splits")
    member = relationship("app.models.member.Member")
