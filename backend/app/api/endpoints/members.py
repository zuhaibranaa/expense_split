from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
import secrets

from app.core.database import get_db
from app.api.deps import check_admin_permission
from app.models.member import Member
from app.schemas import member as member_schemas

router = APIRouter()

@router.post("/", response_model=member_schemas.Member)
def create_member_for_group(group_id: int, member: member_schemas.MemberCreate, db: Session = Depends(get_db)):
    db_member = Member(**member.dict(), group_id=group_id)
    db.add(db_member)
    db.commit()
    db.refresh(db_member)
    return db_member

@router.get("/", response_model=List[member_schemas.Member])
def read_members(group_id: int, db: Session = Depends(get_db)):
    return db.query(Member).filter(Member.group_id == group_id).all()

@router.put("/{member_id}", response_model=member_schemas.Member)
def update_member(group_id: int, member_id: int, member_update: member_schemas.MemberUpdate, user_id: int, db: Session = Depends(get_db)):
    """Update member (admin can edit any, user can edit self only)"""
    db_member = db.query(Member).filter(
        Member.id == member_id,
        Member.group_id == group_id
    ).first()
    
    if not db_member:
        raise HTTPException(status_code=404, detail="Member not found")
    
    # Check permission: admin can edit any, user can only edit self
    is_admin = db.query(Member).filter(
        Member.group_id == group_id,
        Member.user_id == user_id,
        Member.is_admin == 1
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

@router.delete("/{member_id}")
def delete_member(group_id: int, member_id: int, user_id: int, db: Session = Depends(get_db)):
    """Remove member from group (admin only)"""
    # Check admin permission
    check_admin_permission(group_id, user_id, db)
    
    db_member = db.query(Member).filter(
        Member.id == member_id,
        Member.group_id == group_id
    ).first()
    
    if not db_member:
        raise HTTPException(status_code=404, detail="Member not found")
    
    db.delete(db_member)
    db.commit()
    return {"message": "Member removed successfully"}

@router.post("/{member_id}/invite")
def generate_invite(group_id: int, member_id: int, user_id: int, db: Session = Depends(get_db)):
    """Generate invite link for a member (admin only)"""
    # Check admin permission
    check_admin_permission(group_id, user_id, db)
    
    db_member = db.query(Member).filter(
        Member.id == member_id,
        Member.group_id == group_id
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
