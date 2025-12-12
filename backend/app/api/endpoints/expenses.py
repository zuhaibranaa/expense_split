import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

from app.core.database import get_db
from app.api.deps import check_admin_permission
from app.models.expense import Expense, ExpenseSplit
from app.models.group import Group
from app.models.member import Member
from app.schemas import expense as expense_schemas
from app.websockets.manager import manager

router = APIRouter()

@router.post("/", response_model=expense_schemas.Expense)
async def create_expense_for_group(group_id: int, expense: expense_schemas.ExpenseCreate, db: Session = Depends(get_db)):
    # Fetch group to get currency
    db_group = db.query(Group).filter(Group.id == group_id).first()
    if not db_group:
        raise HTTPException(status_code=404, detail="Group not found")

    # 1. Create Expense
    db_expense = Expense(
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
        db_split = ExpenseSplit(
            expense_id=db_expense.id,
            member_id=split.member_id,
            amount=split.amount
        )
        db.add(db_split)
    
    db.commit()
    db.refresh(db_expense)
    
    # Broadcast to group members via WebSocket
    try:
        members = db.query(Member).filter(Member.group_id == group_id).all()
        notification = {
            "type": "expense_created",
            "group_id": group_id,
            "description": expense.description,
            "amount": expense.amount,
            "currency": db_group.currency,
            "payer_id": expense.payer_id,
            "message": f"New expense: {expense.description}"
        }
        await manager.broadcast_to_group(group_id, notification, members)
    except Exception as e:
        print(f"WS Broadcast error: {e}")
        
    return db_expense

@router.get("/", response_model=List[expense_schemas.Expense])
def read_expenses(group_id: int, db: Session = Depends(get_db)):
    return db.query(Expense).filter(Expense.group_id == group_id).all()

@router.put("/{expense_id}", response_model=expense_schemas.Expense)
async def update_expense(group_id: int, expense_id: int, expense_update: expense_schemas.ExpenseUpdate, user_id: int, db: Session = Depends(get_db)):
    # 1. Fetch Expense
    db_expense = db.query(Expense).filter(Expense.id == expense_id, Expense.group_id == group_id).first()
    if not db_expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    # 2. Check Permission: Only Creator/Payer or Admin can edit (Simplification: Payer can edit)
    is_admin = db.query(Member).filter(
        Member.group_id == group_id,
        Member.user_id == user_id,
        Member.is_admin == 1
    ).first() is not None
    
    # Check if payer is linked to this user
    payer_member = db.query(Member).filter(Member.id == db_expense.payer_id).first()
    is_payer = payer_member and payer_member.user_id == user_id
    
    if not (is_admin or is_payer):
        raise HTTPException(status_code=403, detail="Permission denied")

    # 3. Update Fields
    if expense_update.description is not None:
        db_expense.description = expense_update.description
    if expense_update.amount is not None:
        db_expense.amount = expense_update.amount
    if expense_update.category is not None:
        db_expense.category = expense_update.category
    if expense_update.payer_id is not None:
        db_expense.payer_id = expense_update.payer_id
    if expense_update.date is not None:
        db_expense.date = expense_update.date

    # 4. Update Splits (Replace Strategy)
    if expense_update.splits is not None:
        # Delete old splits
        db.query(ExpenseSplit).filter(ExpenseSplit.expense_id == expense_id).delete()
        # Add new splits
        for split in expense_update.splits:
            db_split = ExpenseSplit(
                expense_id=db_expense.id,
                member_id=split.member_id,
                amount=split.amount
            )
            db.add(db_split)

    db.commit()
    db.refresh(db_expense)
    
    # Notify
    try:
        members = db.query(Member).filter(Member.group_id == group_id).all()
        notification = {
            "type": "expense_updated",
            "group_id": group_id,
            "message": f"Expense updated: {db_expense.description}"
        }
        await manager.broadcast_to_group(group_id, notification, members)
    except Exception:
        pass

    return db_expense

@router.delete("/{expense_id}")
async def delete_expense(group_id: int, expense_id: int, user_id: int, db: Session = Depends(get_db)):
    db_expense = db.query(Expense).filter(Expense.id == expense_id, Expense.group_id == group_id).first()
    if not db_expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    # Check Permission
    is_admin = db.query(Member).filter(
        Member.group_id == group_id,
        Member.user_id == user_id,
        Member.is_admin == 1
    ).first() is not None
    
    payer_member = db.query(Member).filter(Member.id == db_expense.payer_id).first()
    is_payer = payer_member and payer_member.user_id == user_id

    if not (is_admin or is_payer):
         raise HTTPException(status_code=403, detail="Permission denied")

    db.delete(db_expense) 
    # Explicit delete splits if cascade doesn't work (though we added cascade to model)
    # But let's rely on model cascade now.
    
    db.commit()
    
    # Notify
    try:
        members = db.query(Member).filter(Member.group_id == group_id).all()
        notification = {
            "type": "expense_deleted",
            "group_id": group_id,
            "message": "Expense deleted"
        }
        await manager.broadcast_to_group(group_id, notification, members)
    except Exception:
        pass

    return {"message": "Expense deleted"}
