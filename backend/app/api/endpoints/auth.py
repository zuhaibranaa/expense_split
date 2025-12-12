from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig, MessageType
import secrets

from app.core.database import get_db
from app.api.deps import check_admin_permission
from app.core.security import get_password_hash, verify_password
from app.models.user import User
from app.models.member import Member
from app.schemas import user as user_schemas
from app.schemas import member as member_schemas

router = APIRouter()

# Mail Configuration
conf = ConnectionConfig(
    MAIL_USERNAME="",
    MAIL_PASSWORD="",
    MAIL_FROM="noreply@settleup.com",
    MAIL_PORT=1025,
    MAIL_SERVER="localhost",
    MAIL_STARTTLS=False,
    MAIL_SSL_TLS=False,
    USE_CREDENTIALS=False,
    VALIDATE_CERTS=False
)

@router.post("/auth/check-email", response_model=user_schemas.EmailCheckResponse)
def check_email(check: user_schemas.EmailCheckRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == check.email).first()
    return {"email": check.email, "exists": user is not None}

@router.post("/auth/register", response_model=user_schemas.User)
def register(user: user_schemas.UserRegister, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    hashed_password = get_password_hash(user.password)
    db_user = User(
        email=user.email,
        name=user.name,
        password_hash=hashed_password,
        default_currency=user.currency,
        avatar_url=f"https://ui-avatars.com/api/?name={user.name}&background=random"
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@router.post("/auth/login", response_model=user_schemas.User)
def login(user: user_schemas.UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.email == user.email).first()
    if not db_user:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    if not verify_password(user.password, db_user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
        
    return db_user

@router.post("/auth/verify-request")
async def request_verification(email: str, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    if user.is_verified:
        return {"message": "Already verified"}

    token = secrets.token_urlsafe(32)
    user.verification_token = token
    db.commit()

    message = MessageSchema(
        subject="Verify your SettleUp Email",
        recipients=[email],
        body=f"Click here to verify: http://localhost:8000/auth/verify?token={token}",
        subtype=MessageType.html
    )

    print(f"--- EMAIL VERIFICATION ---\nTo verify: http://localhost:8000/auth/verify?token={token}\n--------------------------")

    fm = FastMail(conf)
    try:
        background_tasks.add_task(fm.send_message, message)
    except Exception as e:
        print(f"Failed to send email (Mailpit might be down): {e}")

    return {"message": "Verification email sent (check console if Mailpit unavailable)"}

@router.get("/auth/verify")
def verify_email(token: str, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.verification_token == token).first()
    if not user:
        raise HTTPException(status_code=400, detail="Invalid token")
    
    user.is_verified = 1
    user.verification_token = None
    db.commit()
    
    return {"message": "Email verified successfully"}

class InviteClaim(user_schemas.BaseModel): # Or define a new schema file for misc if needed
    token: str

@router.post("/invites/claim")
def claim_invite(invite: InviteClaim, user_id: int, db: Session = Depends(get_db)):
    """Claim a member profile using an invite token"""
    db_member = db.query(Member).filter(Member.invite_token == invite.token).first()
    
    if not db_member:
        raise HTTPException(status_code=404, detail="Invalid invite token")
        
    if db_member.user_id is not None:
        raise HTTPException(status_code=400, detail="Member already claimed")
        
    # Link user
    db_member.user_id = user_id
    db_member.invite_token = None # Invalidate token
    db.commit()
    
    return {"message": "Invite claimed", "group_id": db_member.group_id}
