from fastapi import Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.member import Member

def check_admin_permission(group_id: int, user_id: int, db: Session):
    """Check if user is admin of the group"""
    member = db.query(Member).filter(
        Member.group_id == group_id,
        Member.user_id == user_id,
        Member.is_admin == 1
    ).first()
    if not member:
        raise HTTPException(status_code=403, detail="Admin permission required")
    return member
