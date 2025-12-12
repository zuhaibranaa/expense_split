from sqlalchemy import Column, Integer, String
from app.core.database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True)
    name = Column(String)
    avatar_url = Column(String)
    default_currency = Column(String, default="USD")
    phone = Column(String, nullable=True)
    iban = Column(String, nullable=True)
    is_verified = Column(Integer, default=0) # 0 for false, 1 for true
    verification_token = Column(String, nullable=True)
    password_hash = Column(String)
