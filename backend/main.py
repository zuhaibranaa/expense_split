from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

import models, schemas
from database import SessionLocal, engine, get_db
import secrets

# Create Tables
models.Base.metadata.create_all(bind=engine)

from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Allow all for dev
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"message": "SettleUp Backend Running (FastAPI + SQLAlchemy)"}

# Auth
@app.post("/auth/login", response_model=schemas.User)
def login(user: schemas.UserLogin, db: Session = Depends(get_db)):
    # Mock Login: Find or Create User by Email
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if not db_user:
        db_user = models.User(
            email=user.email,
            name=user.name,
            avatar_url=user.avatar_url,
            default_currency=user.default_currency
        )
        db.add(db_user)
        db.commit()
        db.refresh(db_user)
    return db_user

@app.get("/me/{user_id}", response_model=schemas.User)
def read_user_me(user_id: int, db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
         raise HTTPException(status_code=404, detail="User not found")
    return user

@app.put("/me/{user_id}", response_model=schemas.User)
def update_user_me(user_id: int, user_update: schemas.UserBase, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if not db_user:
         raise HTTPException(status_code=404, detail="User not found")
    
    db_user.name = user_update.name
    db_user.avatar_url = user_update.avatar_url
    db_user.default_currency = user_update.default_currency
    
    db.commit()
    db.refresh(db_user)
    return db_user

# Groups CRUD
@app.post("/groups/", response_model=schemas.Group)
def create_group(group: schemas.GroupCreate, db: Session = Depends(get_db)):
    # Create the group
    db_group = models.Group(
        name=group.name, 
        currency=group.currency,
        created_by=group.creator_user_id
    )
    db.add(db_group)
    db.commit()
    db.refresh(db_group)
    
    # Get the creator user to add as admin member
    creator = db.query(models.User).filter(models.User.id == group.creator_user_id).first()
    if creator:
        # Automatically add creator as admin member
        admin_member = models.Member(
            name=creator.name,
            email=creator.email,
            user_id=creator.id,
            group_id=db_group.id,
            is_admin=1  # Creator is admin
        )
        db.add(admin_member)
        db.commit()
        db.refresh(db_group)  # Refresh to get the members relationship
    
    return db_group

@app.get("/groups/", response_model=List[schemas.Group])
def read_groups(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    groups = db.query(models.Group).offset(skip).limit(limit).all()
    return groups

@app.get("/groups/{group_id}", response_model=schemas.Group)
def read_group(group_id: int, db: Session = Depends(get_db)):
    group = db.query(models.Group).filter(models.Group.id == group_id).first()
    if group is None:
        raise HTTPException(status_code=404, detail="Group not found")
    return group

# Permission Helper
def check_admin_permission(group_id: int, user_id: int, db: Session):
    """Check if user is admin of the group"""
    member = db.query(models.Member).filter(
        models.Member.group_id == group_id,
        models.Member.user_id == user_id,
        models.Member.is_admin == 1
    ).first()
    if not member:
        raise HTTPException(status_code=403, detail="Admin permission required")
    return member

@app.put("/groups/{group_id}", response_model=schemas.Group)
def update_group(group_id: int, group_update: schemas.GroupUpdate, user_id: int, db: Session = Depends(get_db)):
    """Update group (admin only) - currently supports currency change"""
    # Check admin permission
    check_admin_permission(group_id, user_id, db)
    
    # Get and update group
    db_group = db.query(models.Group).filter(models.Group.id == group_id).first()
    if not db_group:
        raise HTTPException(status_code=404, detail="Group not found")
    
    if group_update.currency:
        db_group.currency = group_update.currency
    if group_update.name:
        db_group.name = group_update.name
    
    db.commit()
    db.refresh(db_group)
    return db_group

@app.delete("/groups/{group_id}")
def delete_group(group_id: int, user_id: int, db: Session = Depends(get_db)):
    """Delete group (admin only)"""
    # Check admin permission
    check_admin_permission(group_id, user_id, db)
    
    # Delete group (cascade will handle members, expenses, etc.)
    db_group = db.query(models.Group).filter(models.Group.id == group_id).first()
    if not db_group:
        raise HTTPException(status_code=404, detail="Group not found")
    
    db.delete(db_group)
    db.commit()
    return {"message": "Group deleted successfully"}


# Members CRUD
@app.post("/groups/{group_id}/members/", response_model=schemas.Member)
def create_member_for_group(group_id: int, member: schemas.MemberCreate, db: Session = Depends(get_db)):
    db_member = models.Member(**member.dict(), group_id=group_id)
    db.add(db_member)
    db.commit()
    db.refresh(db_member)
    return db_member

@app.get("/groups/{group_id}/members/", response_model=List[schemas.Member])
def read_members(group_id: int, db: Session = Depends(get_db)):
    return db.query(models.Member).filter(models.Member.group_id == group_id).all()

@app.put("/groups/{group_id}/members/{member_id}", response_model=schemas.Member)
def update_member(group_id: int, member_id: int, member_update: schemas.MemberUpdate, user_id: int, db: Session = Depends(get_db)):
    """Update member (admin can edit any, user can edit self only)"""
    db_member = db.query(models.Member).filter(
        models.Member.id == member_id,
        models.Member.group_id == group_id
    ).first()
    
    if not db_member:
        raise HTTPException(status_code=404, detail="Member not found")
    
    # Check permission: admin can edit any, user can only edit self
    is_admin = db.query(models.Member).filter(
        models.Member.group_id == group_id,
        models.Member.user_id == user_id,
        models.Member.is_admin == 1
    ).first() is not None
    
    is_self = db_member.user_id == user_id
    
    if not (is_admin or is_self):
        raise HTTPException(status_code=403, detail="Permission denied")
    
    # Update member
    if member_update.name:
        db_member.name = member_update.name
    
    db.commit()
    db.refresh(db_member)
    return db_member

@app.delete("/groups/{group_id}/members/{member_id}")
def delete_member(group_id: int, member_id: int, user_id: int, db: Session = Depends(get_db)):
    """Remove member from group (admin only)"""
    # Check admin permission
    check_admin_permission(group_id, user_id, db)
    
    db_member = db.query(models.Member).filter(
        models.Member.id == member_id,
        models.Member.group_id == group_id
    ).first()
    
    if not db_member:
        raise HTTPException(status_code=404, detail="Member not found")
    
    db.delete(db_member)
    db.commit()
    return {"message": "Member removed successfully"}

@app.post("/groups/{group_id}/members/{member_id}/invite")
def generate_invite(group_id: int, member_id: int, user_id: int, db: Session = Depends(get_db)):
    """Generate invite link for a member (admin only)"""
    # Check admin permission
    check_admin_permission(group_id, user_id, db)
    
    db_member = db.query(models.Member).filter(
        models.Member.id == member_id,
        models.Member.group_id == group_id
    ).first()
    
    if not db_member:
        raise HTTPException(status_code=404, detail="Member not found")
        
    if db_member.user_id is not None:
        raise HTTPException(status_code=400, detail="Member already claimed by a user")
    
    # Generate token
    token = secrets.token_urlsafe(16)
    db_member.invite_token = token
    db.commit()
    
    return {"token": token}

from pydantic import BaseModel

class InviteClaim(BaseModel):
    token: str

@app.post("/invites/claim")
def claim_invite(invite: InviteClaim, user_id: int, db: Session = Depends(get_db)):
    """Claim a member profile using an invite token"""
    db_member = db.query(models.Member).filter(models.Member.invite_token == invite.token).first()
    
    if not db_member:
        raise HTTPException(status_code=404, detail="Invalid invite token")
        
    if db_member.user_id is not None:
        # Should not happen if we clear token, but good safety
        raise HTTPException(status_code=400, detail="Member already claimed")
        
    # Link user
    db_member.user_id = user_id
    db_member.invite_token = None # Invalidate token
    db.commit()
    
    return {"message": "Invite claimed", "group_id": db_member.group_id}


# Expenses CRUD
@app.post("/groups/{group_id}/expenses/", response_model=schemas.Expense)
def create_expense_for_group(group_id: int, expense: schemas.ExpenseCreate, db: Session = Depends(get_db)):
    # Fetch group to get currency
    db_group = db.query(models.Group).filter(models.Group.id == group_id).first()
    if not db_group:
        raise HTTPException(status_code=404, detail="Group not found")

    # 1. Create Expense
    db_expense = models.Expense(
        description=expense.description,
        amount=expense.amount,
        currency_code=db_group.currency,
        category=expense.category,
        is_settlement=1 if expense.is_settlement else 0,
        payer_id=expense.payer_id,
        group_id=group_id,
        date=expense.date or datetime.datetime.utcnow()
    )
    db.add(db_expense)
    db.commit()
    db.refresh(db_expense)

    # 2. Create Splits
    for split in expense.splits:
        db_split = models.ExpenseSplit(
            expense_id=db_expense.id,
            member_id=split.member_id,
            amount=split.amount
        )
        db.add(db_split)
    
    db.commit()
    db.refresh(db_expense)
    return db_expense

@app.get("/groups/{group_id}/expenses/", response_model=List[schemas.Expense])
def read_expenses(group_id: int, db: Session = Depends(get_db)):
    return db.query(models.Expense).filter(models.Expense.group_id == group_id).all()
