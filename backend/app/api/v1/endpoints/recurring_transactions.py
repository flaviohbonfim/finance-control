from datetime import date

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.account import Account
from app.models.recurring_transaction import RecurringTransaction
from app.models.transaction import Transaction, TransactionType
from app.models.user import User
from app.schemas.recurring_transaction import (
    LaunchIn,
    RecurringCreate,
    RecurringOut,
    RecurringUpdate,
)

router = APIRouter(prefix="/recurring-transactions", tags=["recurring-transactions"])


def _to_out(rt: RecurringTransaction, today: date | None = None) -> RecurringOut:
    if today is None:
        today = date.today()
    launched = False
    if rt.last_launched_date is not None:
        launched = (
            rt.last_launched_date.year == today.year and rt.last_launched_date.month == today.month
        )
    return RecurringOut(
        id=rt.id,
        account_id=rt.account_id,
        category_id=rt.category_id,
        type=rt.type,
        description=rt.description,
        amount=rt.amount,
        is_fixed=rt.is_fixed,
        frequency=rt.frequency,
        due_day=rt.due_day,
        due_month=rt.due_month,
        start_date=rt.start_date,
        end_date=rt.end_date,
        active=rt.active,
        last_launched_date=rt.last_launched_date,
        created_at=rt.created_at,
        account_name=rt.account.name if rt.account else None,
        category_name=rt.category.name if rt.category else None,
        category_color=rt.category.color if rt.category else None,
        launched_this_month=launched,
    )


@router.get("", response_model=list[RecurringOut])
async def list_recurring(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(RecurringTransaction)
        .where(RecurringTransaction.user_id == current_user.id)
        .options(
            selectinload(RecurringTransaction.account),
            selectinload(RecurringTransaction.category),
        )
        .order_by(RecurringTransaction.due_day)
    )
    rts = result.scalars().all()
    today = date.today()
    return [_to_out(rt, today) for rt in rts]


@router.post("", response_model=RecurringOut, status_code=status.HTTP_201_CREATED)
async def create_recurring(
    payload: RecurringCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    acc_result = await db.execute(
        select(Account).where(Account.id == payload.account_id, Account.user_id == current_user.id)
    )
    if not acc_result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Conta não encontrada")

    rt = RecurringTransaction(user_id=current_user.id, **payload.model_dump())
    db.add(rt)
    await db.commit()
    await db.refresh(rt)
    await db.refresh(rt, ["account", "category"])
    return _to_out(rt)


@router.put("/{rt_id}", response_model=RecurringOut)
async def update_recurring(
    rt_id: int,
    payload: RecurringUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(RecurringTransaction)
        .where(
            RecurringTransaction.id == rt_id,
            RecurringTransaction.user_id == current_user.id,
        )
        .options(
            selectinload(RecurringTransaction.account),
            selectinload(RecurringTransaction.category),
        )
    )
    rt = result.scalar_one_or_none()
    if not rt:
        raise HTTPException(status_code=404, detail="Recorrente não encontrado")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(rt, field, value)

    await db.commit()
    await db.refresh(rt)
    await db.refresh(rt, ["account", "category"])
    return _to_out(rt)


@router.delete("/{rt_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_recurring(
    rt_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(RecurringTransaction).where(
            RecurringTransaction.id == rt_id,
            RecurringTransaction.user_id == current_user.id,
        )
    )
    rt = result.scalar_one_or_none()
    if not rt:
        raise HTTPException(status_code=404, detail="Recorrente não encontrado")

    await db.delete(rt)
    await db.commit()


@router.post("/{rt_id}/launch", response_model=RecurringOut)
async def launch_recurring(
    rt_id: int,
    payload: LaunchIn,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(RecurringTransaction)
        .where(
            RecurringTransaction.id == rt_id,
            RecurringTransaction.user_id == current_user.id,
        )
        .options(
            selectinload(RecurringTransaction.account),
            selectinload(RecurringTransaction.category),
        )
    )
    rt = result.scalar_one_or_none()
    if not rt:
        raise HTTPException(status_code=404, detail="Recorrente não encontrado")

    if rt.is_fixed:
        amount = rt.amount
    else:
        if payload.amount is None:
            raise HTTPException(
                status_code=422, detail="Valor obrigatório para lançamentos variáveis"
            )
        amount = payload.amount

    if amount is None:
        raise HTTPException(status_code=422, detail="Valor não informado")

    acc_result = await db.execute(select(Account).where(Account.id == rt.account_id))
    account = acc_result.scalar_one()

    today = date.today()
    tx = Transaction(
        user_id=current_user.id,
        account_id=rt.account_id,
        category_id=rt.category_id,
        type=rt.type,
        amount=amount,
        description=rt.description,
        transaction_date=today,
    )
    db.add(tx)

    if rt.type == TransactionType.income:
        account.balance += amount
    else:
        account.balance -= amount

    rt.last_launched_date = today

    await db.commit()
    await db.refresh(rt)
    await db.refresh(rt, ["account", "category"])
    return _to_out(rt, today)
