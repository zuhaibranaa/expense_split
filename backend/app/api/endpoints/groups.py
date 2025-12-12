from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.core.database import get_db
from app.api.deps import check_admin_permission
from app.models.group import Group
from app.models.user import User
from app.models.member import Member
from app.schemas import group as group_schemas

router = APIRouter()

@router.post("/", response_model=group_schemas.Group)
def create_group(group: group_schemas.GroupCreate, db: Session = Depends(get_db)):
    # Create the group
    db_group = Group(
        name=group.name, 
        currency=group.currency,
        created_by=group.creator_user_id
    )
    db.add(db_group)
    db.commit()
    db.refresh(db_group)
    
    # Get the creator user to add as admin member
    creator = db.query(User).filter(User.id == group.creator_user_id).first()
    if creator:
        # Automatically add creator as admin member
        admin_member = Member(
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

@router.get("/", response_model=List[group_schemas.Group])
def read_groups(skip: int = 0, limit: int = 100, user_id: int = None, db: Session = Depends(get_db)):
    query = db.query(Group)
    if user_id:
        query = query.join(Member).filter(Member.user_id == user_id)
    
    groups = query.offset(skip).limit(limit).all()
    return groups

@router.get("/{group_id}", response_model=group_schemas.Group)
def read_group(group_id: int, db: Session = Depends(get_db)):
    group = db.query(Group).filter(Group.id == group_id).first()
    if group is None:
        raise HTTPException(status_code=404, detail="Group not found")
    return group

@router.put("/{group_id}", response_model=group_schemas.Group)
def update_group(group_id: int, group_update: group_schemas.GroupUpdate, user_id: int, db: Session = Depends(get_db)):
    """Update group (admin only) - currently supports currency change"""
    # Check admin permission
    check_admin_permission(group_id, user_id, db)
    
    # Get and update group
    db_group = db.query(Group).filter(Group.id == group_id).first()
    if not db_group:
        raise HTTPException(status_code=404, detail="Group not found")
    
    if group_update.currency:
        db_group.currency = group_update.currency
    if group_update.name:
        db_group.name = group_update.name
    
    db.commit()
    db.refresh(db_group)
    return db_group

@router.delete("/{group_id}")
def delete_group(group_id: int, user_id: int, db: Session = Depends(get_db)):
    """Delete group (admin only)"""
    # Check admin permission
    check_admin_permission(group_id, user_id, db)
    
    # Delete group (cascade will handle members, expenses, etc.)
    db_group = db.query(Group).filter(Group.id == group_id).first()
    if not db_group:
        raise HTTPException(status_code=404, detail="Group not found")
    
    db.delete(db_group)
    db.commit()
    return {"message": "Group deleted successfully"}
