from datetime import date, timedelta
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.account import Account, AccountType
from app.models.transaction import Transaction, TransactionType
from app.models.user import User
from app.schemas.account import AccountCreate, AccountOut, AccountUpdate, InvoiceOut, PayInvoiceIn
from app.schemas.transaction import TransactionOut

router = APIRouter(prefix="/accounts", tags=["accounts"])


@router.get("", response_model=list[AccountOut])
async def list_accounts(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Account).where(Account.user_id == current_user.id).order_by(Account.name)
    )
    return result.scalars().all()


@router.post("", response_model=AccountOut, status_code=status.HTTP_201_CREATED)
async def create_account(
    payload: AccountCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    account = Account(user_id=current_user.id, **payload.model_dump())
    db.add(account)
    await db.commit()
    await db.refresh(account)
    return account


@router.put("/{account_id}", response_model=AccountOut)
async def update_account(
    account_id: int,
    payload: AccountUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Account).where(Account.id == account_id, Account.user_id == current_user.id)
    )
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Conta não encontrada")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(account, field, value)

    await db.commit()
    await db.refresh(account)
    return account


@router.delete("/{account_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_account(
    account_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Account).where(Account.id == account_id, Account.user_id == current_user.id)
    )
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Conta não encontrada")

    await db.delete(account)
    await db.commit()


def _invoice_period(closing_day: int, today: date) -> tuple[date, date, date, date]:
    """Return (current_start, current_end, next_start, next_end) based on closing_day."""
    import calendar

    year = today.year
    month = today.month

    # closing day clamped to last day of current month
    last_day = calendar.monthrange(year, month)[1]
    current_end_day = min(closing_day, last_day)
    current_end = date(year, month, current_end_day)

    # current_start = day after closing_day of previous month
    prev_month = month - 1 if month > 1 else 12
    prev_year = year if month > 1 else year - 1
    prev_last_day = calendar.monthrange(prev_year, prev_month)[1]
    prev_closing = min(closing_day, prev_last_day)
    current_start = date(prev_year, prev_month, prev_closing) + timedelta(days=1)

    # next invoice: starts day after current_end, ends on closing_day of next month
    next_start = current_end + timedelta(days=1)
    next_month = month + 1 if month < 12 else 1
    next_year = year if month < 12 else year + 1
    next_last_day = calendar.monthrange(next_year, next_month)[1]
    next_end_day = min(closing_day, next_last_day)
    next_end = date(next_year, next_month, next_end_day)

    return current_start, current_end, next_start, next_end


@router.get("/{account_id}/invoice", response_model=InvoiceOut)
async def get_invoice(
    account_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Account).where(Account.id == account_id, Account.user_id == current_user.id)
    )
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Conta não encontrada")
    if account.type != AccountType.credit_card:
        raise HTTPException(status_code=400, detail="Conta não é cartão de crédito")
    if account.closing_day is None or account.due_day is None:
        raise HTTPException(
            status_code=400, detail="Cartão sem dia de fechamento ou vencimento configurado"
        )

    today = date.today()
    current_start, current_end, next_start, next_end = _invoice_period(account.closing_day, today)

    def _base_tx_query(start: date, end: date):
        return (
            select(Transaction)
            .where(
                Transaction.account_id == account_id,
                Transaction.type == TransactionType.expense,
                Transaction.transaction_date >= start,
                Transaction.transaction_date <= end,
            )
            .order_by(Transaction.transaction_date, Transaction.id)
        )

    cur_txs_result = await db.execute(_base_tx_query(current_start, current_end))
    current_txs = cur_txs_result.scalars().all()
    current_total = sum((t.amount for t in current_txs), Decimal("0"))

    nxt_txs_result = await db.execute(_base_tx_query(next_start, next_end))
    next_txs = nxt_txs_result.scalars().all()
    next_total = sum((t.amount for t in next_txs), Decimal("0"))

    return InvoiceOut(
        current_total=current_total,
        current_start=current_start,
        current_end=current_end,
        current_transactions=[TransactionOut.model_validate(t) for t in current_txs],
        next_total=next_total,
        next_start=next_start,
        next_end=next_end,
        next_transactions=[TransactionOut.model_validate(t) for t in next_txs],
        due_day=account.due_day,
    )


@router.post("/{account_id}/pay-invoice", response_model=dict)
async def pay_invoice(
    account_id: int,
    payload: PayInvoiceIn,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # Validate credit card account
    card_result = await db.execute(
        select(Account).where(Account.id == account_id, Account.user_id == current_user.id)
    )
    card = card_result.scalar_one_or_none()
    if not card:
        raise HTTPException(status_code=404, detail="Conta não encontrada")
    if card.type != AccountType.credit_card:
        raise HTTPException(status_code=400, detail="Conta não é cartão de crédito")

    # Validate source account
    src_result = await db.execute(
        select(Account).where(
            Account.id == payload.source_account_id, Account.user_id == current_user.id
        )
    )
    source = src_result.scalar_one_or_none()
    if not source:
        raise HTTPException(status_code=404, detail="Conta de origem não encontrada")

    today = date.today()

    # Expense on source account
    expense_tx = Transaction(
        user_id=current_user.id,
        account_id=source.id,
        category_id=None,
        type=TransactionType.expense,
        amount=payload.amount,
        description=f"Pagamento fatura {card.name}",
        transaction_date=today,
    )
    db.add(expense_tx)
    source.balance -= payload.amount

    # Income on credit card (reduces the debt)
    income_tx = Transaction(
        user_id=current_user.id,
        account_id=card.id,
        category_id=None,
        type=TransactionType.income,
        amount=payload.amount,
        description=f"Pagamento fatura de {source.name}",
        transaction_date=today,
    )
    db.add(income_tx)
    card.balance += payload.amount

    await db.commit()
    return {"ok": True}
