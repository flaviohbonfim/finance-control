import calendar
import math
from datetime import date
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.account import Account
from app.models.transaction import Transaction, TransactionType
from app.models.user import User
from app.schemas.transaction import (
    PaginatedTransactions,
    TransactionCreate,
    TransactionOut,
    TransactionUpdate,
)

router = APIRouter(prefix="/transactions", tags=["transactions"])


def _add_months(d: date, months: int) -> date:
    month = d.month - 1 + months
    year = d.year + month // 12
    month = month % 12 + 1
    day = min(d.day, calendar.monthrange(year, month)[1])
    return date(year, month, day)


@router.get("", response_model=PaginatedTransactions)
async def list_transactions(
    account_id: int | None = Query(None),
    category_id: int | None = Query(None),
    type: TransactionType | None = Query(None),
    date_from: str | None = Query(None),
    date_to: str | None = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = (
        select(Transaction)
        .where(Transaction.user_id == current_user.id)
        .options(selectinload(Transaction.category))
    )

    if account_id:
        query = query.where(Transaction.account_id == account_id)
    if category_id:
        query = query.where(Transaction.category_id == category_id)
    if type:
        query = query.where(Transaction.type == type)
    if date_from:
        query = query.where(Transaction.transaction_date >= date_from)
    if date_to:
        query = query.where(Transaction.transaction_date <= date_to)

    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar()

    query = query.order_by(Transaction.transaction_date.desc(), Transaction.id.desc())
    query = query.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)

    return PaginatedTransactions(
        items=result.scalars().all(),
        total=total,
        page=page,
        page_size=page_size,
        pages=math.ceil(total / page_size) if total else 0,
    )


@router.post("", response_model=TransactionOut, status_code=status.HTTP_201_CREATED)
async def create_transaction(
    payload: TransactionCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    acc_result = await db.execute(
        select(Account).where(Account.id == payload.account_id, Account.user_id == current_user.id)
    )
    account = acc_result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Conta não encontrada")

    n = max(1, payload.installments)
    base = payload.model_dump(exclude={"installments"})

    if n == 1:
        transaction = Transaction(user_id=current_user.id, **base)
        db.add(transaction)
        if payload.type == TransactionType.income:
            account.balance += payload.amount
        else:
            account.balance -= payload.amount
        await db.commit()
        await db.refresh(transaction)
        await db.refresh(transaction, ["category"])
        return transaction

    # Installments: split amount across N months
    unit = (payload.amount / n).quantize(Decimal("0.01"))
    last = payload.amount - unit * (n - 1)

    first_tx = None
    for i in range(n):
        amount = last if i == n - 1 else unit
        tx = Transaction(
            user_id=current_user.id,
            account_id=payload.account_id,
            category_id=payload.category_id,
            type=payload.type,
            amount=amount,
            description=f"{payload.description} ({i + 1}/{n})",
            notes=payload.notes,
            transaction_date=_add_months(payload.transaction_date, i),
        )
        db.add(tx)
        if payload.type == TransactionType.income:
            account.balance += amount
        else:
            account.balance -= amount
        if i == 0:
            first_tx = tx

    await db.commit()
    await db.refresh(first_tx)
    await db.refresh(first_tx, ["category"])
    return first_tx


@router.put("/{transaction_id}", response_model=TransactionOut)
async def update_transaction(
    transaction_id: int,
    payload: TransactionUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Transaction)
        .where(Transaction.id == transaction_id, Transaction.user_id == current_user.id)
        .options(selectinload(Transaction.category))
    )
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transação não encontrada")

    acc_result = await db.execute(select(Account).where(Account.id == transaction.account_id))
    account = acc_result.scalar_one()

    # Reverse old balance effect
    if transaction.type == TransactionType.income:
        account.balance -= transaction.amount
    else:
        account.balance += transaction.amount

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(transaction, field, value)

    # Apply new balance effect
    if transaction.type == TransactionType.income:
        account.balance += transaction.amount
    else:
        account.balance -= transaction.amount

    await db.commit()
    await db.refresh(transaction)
    return transaction


@router.delete("/{transaction_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_transaction(
    transaction_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Transaction).where(
            Transaction.id == transaction_id, Transaction.user_id == current_user.id
        )
    )
    transaction = result.scalar_one_or_none()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transação não encontrada")

    acc_result = await db.execute(select(Account).where(Account.id == transaction.account_id))
    account = acc_result.scalar_one()

    if transaction.type == TransactionType.income:
        account.balance -= transaction.amount
    else:
        account.balance += transaction.amount

    await db.delete(transaction)
    await db.commit()
