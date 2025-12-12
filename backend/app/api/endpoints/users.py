from fastapi import APIRouter, Depends, HTTPException, File, UploadFile
from sqlalchemy.orm import Session
import shutil
import os
import secrets

from app.core.database import get_db
from app.models.user import User
from app.schemas import user as user_schemas

router = APIRouter()

@router.get("/me/{user_id}", response_model=user_schemas.User)
def read_user_me(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
         raise HTTPException(status_code=404, detail="User not found")
    return user

@router.put("/me/{user_id}", response_model=user_schemas.User)
def update_user_me(user_id: int, user_update: user_schemas.UserBase, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.id == user_id).first()
    if not db_user:
         raise HTTPException(status_code=404, detail="User not found")
    
    db_user.name = user_update.name
    db_user.avatar_url = user_update.avatar_url
    db_user.default_currency = user_update.default_currency
    db_user.phone = user_update.phone
    db_user.iban = user_update.iban
    
    db.commit()
    db.refresh(db_user)
    return db_user

@router.post("/upload/image")
async def upload_image(file: UploadFile = File(...)):
    # Create directory if not exists (safety check)
    os.makedirs("static/images", exist_ok=True)
    
    # Generate unique filename to avoid collisions
    file_ext = os.path.splitext(file.filename)[1]
    filename = f"{secrets.token_hex(8)}{file_ext}"
    file_location = f"static/images/{filename}"
    
    with open(file_location, "wb+") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    # Return full URL assuming local dev
    # TODO: Use environment variable for base URL in production
    return {"url": f"http://localhost:8000/{file_location}"}
