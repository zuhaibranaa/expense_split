from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from database import Base
import datetime

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    name = Column(String)
    avatar_url = Column(String)
    default_currency = Column(String, default="USD")

class Group(Base):
    __tablename__ = "groups"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    currency = Column(String, default="USD")
    created_by = Column(Integer, ForeignKey("users.id"))  # Track who created the group
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    members = relationship("Member", back_populates="group")
    expenses = relationship("Expense", back_populates="group")
    creator = relationship("User")  # Link to creator

class Member(Base):
    __tablename__ = "members"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    email = Column(String)  # For invitations
    phone = Column(String)  # For invitations
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)  # Link to User if registered
    group_id = Column(Integer, ForeignKey("groups.id"))
    is_admin = Column(Integer, default=0)  # 1 for admin, 0 for regular member
    invite_token = Column(String, unique=True, nullable=True)  # Token for invites

    group = relationship("Group", back_populates="members")
    user = relationship("User")  # Link to User model
    # expenses_paid = relationship("Expense", back_populates="payer") # Optional reverse link

class Expense(Base):
    __tablename__ = "expenses"

    id = Column(Integer, primary_key=True, index=True)
    description = Column(String)
    amount = Column(Float)
    currency_code = Column(String)
    category = Column(String, default="General") # Added Category
    is_settlement = Column(Integer, default=0) # 1 for settlement, 0 for expense
    payer_id = Column(Integer, ForeignKey("members.id"))  # Fixed: Changed from users.id to members.id
    group_id = Column(Integer, ForeignKey("groups.id"))
    date = Column(DateTime, default=datetime.datetime.utcnow)

    group = relationship("Group", back_populates="expenses")
    payer = relationship("Member")  # Now correctly matches the ForeignKey
    splits = relationship("ExpenseSplit", back_populates="expense")

class ExpenseSplit(Base):
    __tablename__ = "expense_splits"

    id = Column(Integer, primary_key=True, index=True)
    expense_id = Column(Integer, ForeignKey("expenses.id"))
    member_id = Column(Integer, ForeignKey("members.id"))
    amount = Column(Float)

    expense = relationship("Expense", back_populates="splits")
    member = relationship("Member")
