from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base

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
    user = relationship("app.models.user.User")  # String reference to avoid circular import if needed, or just "User" if imported
    # Note: Using absolute path "app.models.user.User" or just "User" if we rely on registry. 
    # Safest is string "User" but we need to ensure User is loaded. 
    # Ideally "User" works if they share Base. Let's use "User".
