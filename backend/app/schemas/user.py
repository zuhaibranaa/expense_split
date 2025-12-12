from pydantic import BaseModel
from typing import Optional

class UserBase(BaseModel):
    email: str
    name: str
    avatar_url: Optional[str] = None
    phone: Optional[str] = None
    iban: Optional[str] = None
    default_currency: Optional[str] = "USD"

class UserLogin(BaseModel):
    email: str
    password: str

class UserRegister(BaseModel):
    email: str
    password: str
    name: str
    currency: str = "USD"
    iban: Optional[str] = None

class EmailCheckRequest(BaseModel):
    email: str

class EmailCheckResponse(BaseModel):
    email: str
    exists: bool

class User(UserBase):
    id: int
    is_verified: bool = False
    class Config:
        from_attributes = True

class UserLink(BaseModel):
    id: int
    name: str
    avatar_url: Optional[str] = None
    iban: Optional[str] = None
    class Config:
        from_attributes = True
