import datetime
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base

class Group(Base):
    __tablename__ = "groups"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    currency = Column(String, default="USD")
    created_by = Column(Integer, ForeignKey("users.id"))
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    members = relationship("app.models.member.Member", back_populates="group", cascade="all, delete-orphan")
    expenses = relationship("app.models.expense.Expense", back_populates="group", cascade="all, delete-orphan")
    creator = relationship("app.models.user.User")
