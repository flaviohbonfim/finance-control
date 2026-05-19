from datetime import date, timedelta
from decimal import Decimal

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.account import Account, AccountType
from app.models.category import Category
from app.models.recurring_transaction import RecurringFrequency, RecurringTransaction
from app.models.transaction import Transaction, TransactionType
from app.models.user import User
from app.schemas.recurring_transaction import RecurringOut
from app.schemas.report import (
    BillPeriod,
    CategorySummary,
    CreditCardBillOut,
    DashboardSummary,
    MonthlyDetail,
    MonthlySummary,
)
from app.schemas.transaction import TransactionOut

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/dashboard", response_model=DashboardSummary)
async def dashboard(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    import calendar

    today = date.today()
    month_start = today.replace(day=1)
    month_end = today.replace(day=calendar.monthrange(today.year, today.month)[1])

    # Total balance across all accounts
    bal_result = await db.execute(
        select(func.coalesce(func.sum(Account.balance), 0)).where(
            Account.user_id == current_user.id
        )
    )
    total_balance = bal_result.scalar()

    # Monthly income
    inc_result = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0)).where(
            Transaction.user_id == current_user.id,
            Transaction.type == TransactionType.income,
            Transaction.transaction_date >= month_start,
            Transaction.transaction_date <= month_end,
        )
    )
    monthly_income = inc_result.scalar()

    # Monthly expense
    exp_result = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0)).where(
            Transaction.user_id == current_user.id,
            Transaction.type == TransactionType.expense,
            Transaction.transaction_date >= month_start,
            Transaction.transaction_date <= month_end,
        )
    )
    monthly_expense = exp_result.scalar()

    # Recent transactions
    recent_result = await db.execute(
        select(Transaction)
        .where(Transaction.user_id == current_user.id)
        .options(selectinload(Transaction.category))
        .order_by(Transaction.transaction_date.desc(), Transaction.id.desc())
        .limit(5)
    )
    recent = recent_result.scalars().all()

    # Last 6 months chart
    monthly_chart = []
    for i in range(5, -1, -1):
        if today.month - i <= 0:
            m = today.month - i + 12
            y = today.year - 1
        else:
            m = today.month - i
            y = today.year
        month_label = f"{y}-{m:02d}"
        m_start = date(y, m, 1)
        m_end = date(y, m, 28 if m == 2 else (30 if m in [4, 6, 9, 11] else 31))

        inc = await db.execute(
            select(func.coalesce(func.sum(Transaction.amount), 0)).where(
                Transaction.user_id == current_user.id,
                Transaction.type == TransactionType.income,
                Transaction.transaction_date >= m_start,
                Transaction.transaction_date <= m_end,
            )
        )
        inc_val = Decimal(str(inc.scalar()))

        exp = await db.execute(
            select(func.coalesce(func.sum(Transaction.amount), 0)).where(
                Transaction.user_id == current_user.id,
                Transaction.type == TransactionType.expense,
                Transaction.transaction_date >= m_start,
                Transaction.transaction_date <= m_end,
            )
        )
        exp_val = Decimal(str(exp.scalar()))

        monthly_chart.append(
            MonthlySummary(
                month=month_label,
                income=inc_val,
                expense=exp_val,
                balance=inc_val - exp_val,
            )
        )

    # Expense by category (current month) — LEFT JOIN from Transaction so
    # expenses without a category also appear grouped as "Sem categoria"
    cat_result = await db.execute(
        select(
            Category.id,
            Category.name,
            Category.color,
            func.sum(Transaction.amount).label("total"),
        )
        .select_from(Transaction)
        .join(Category, Transaction.category_id == Category.id, isouter=True)
        .where(
            Transaction.user_id == current_user.id,
            Transaction.type == TransactionType.expense,
            Transaction.transaction_date >= month_start,
            Transaction.transaction_date <= month_end,
        )
        .group_by(Category.id, Category.name, Category.color)
        .order_by(func.sum(Transaction.amount).desc())
    )
    cat_rows = cat_result.all()

    total_exp = sum(Decimal(str(r.total)) for r in cat_rows) or Decimal("1")
    expense_by_category = [
        CategorySummary(
            category_id=r.id,
            category_name=r.name or "Sem categoria",
            category_color=r.color or "#9ca3af",
            total=Decimal(str(r.total)),
            percentage=float(Decimal(str(r.total)) / total_exp * 100),
        )
        for r in cat_rows
    ]

    # Recurring transactions due this month
    recurring_result = await db.execute(
        select(RecurringTransaction)
        .where(
            RecurringTransaction.user_id == current_user.id,
            RecurringTransaction.active.is_(True),
            RecurringTransaction.start_date <= today,
        )
        .options(
            selectinload(RecurringTransaction.account),
            selectinload(RecurringTransaction.category),
        )
        .order_by(RecurringTransaction.due_day)
    )
    all_recurring = recurring_result.scalars().all()

    recurring_this_month: list[RecurringOut] = []
    for rt in all_recurring:
        if rt.end_date is not None and rt.end_date < month_start:
            continue
        if rt.frequency == RecurringFrequency.monthly:
            due_this_month = True
        else:
            # yearly: check if due_month matches current month
            due_this_month = rt.due_month == today.month

        if not due_this_month:
            continue

        launched = (
            rt.last_launched_date is not None
            and rt.last_launched_date.year == today.year
            and rt.last_launched_date.month == today.month
        )
        recurring_this_month.append(
            RecurringOut(
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
        )

    return DashboardSummary(
        total_balance=Decimal(str(total_balance)),
        monthly_income=Decimal(str(monthly_income)),
        monthly_expense=Decimal(str(monthly_expense)),
        monthly_balance=Decimal(str(monthly_income)) - Decimal(str(monthly_expense)),
        recent_transactions=[TransactionOut.model_validate(t) for t in recent],
        monthly_chart=monthly_chart,
        expense_by_category=expense_by_category,
        recurring_this_month=recurring_this_month,
    )


@router.get("/credit-card-bills", response_model=list[CreditCardBillOut])
async def credit_card_bills(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    import calendar as cal_mod

    today = date.today()

    acct_result = await db.execute(
        select(Account).where(
            Account.user_id == current_user.id,
            Account.type == AccountType.credit_card,
        )
    )
    cards = acct_result.scalars().all()

    bills = []
    for card in cards:
        cd = card.closing_day
        if cd is None:
            continue

        year, month = today.year, today.month
        last_day = cal_mod.monthrange(year, month)[1]
        current_end = date(year, month, min(cd, last_day))

        prev_month = month - 1 if month > 1 else 12
        prev_year = year if month > 1 else year - 1
        prev_last = cal_mod.monthrange(prev_year, prev_month)[1]
        current_start = date(prev_year, prev_month, min(cd, prev_last)) + timedelta(days=1)

        next_start = current_end + timedelta(days=1)
        next_month = month + 1 if month < 12 else 1
        next_year = year if month < 12 else year + 1
        next_last = cal_mod.monthrange(next_year, next_month)[1]
        next_end = date(next_year, next_month, min(cd, next_last))

        def _sum_q(start: date, end: date, acct_id: int):
            return select(func.coalesce(func.sum(Transaction.amount), 0)).where(
                Transaction.account_id == acct_id,
                Transaction.type == TransactionType.expense,
                Transaction.transaction_date >= start,
                Transaction.transaction_date <= end,
            )

        curr_r = await db.execute(_sum_q(current_start, current_end, card.id))
        next_r = await db.execute(_sum_q(next_start, next_end, card.id))

        bills.append(
            CreditCardBillOut(
                id=card.id,
                name=card.name,
                closing_day=cd,
                due_day=card.due_day,
                current_bill=BillPeriod(
                    period=f"{current_start.strftime('%d/%m')} a {current_end.strftime('%d/%m')}",
                    total=Decimal(str(curr_r.scalar())),
                ),
                next_bill=BillPeriod(
                    period=f"{next_start.strftime('%d/%m')} a {next_end.strftime('%d/%m')}",
                    total=Decimal(str(next_r.scalar())),
                ),
            )
        )

    return bills


@router.get("/monthly", response_model=list[MonthlySummary])
async def monthly_report(
    year: int = Query(default=None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    year = year or date.today().year
    result = []
    for m in range(1, 13):
        m_start = date(year, m, 1)
        m_end = date(year, m, 28 if m == 2 else (30 if m in [4, 6, 9, 11] else 31))
        label = f"{year}-{m:02d}"

        inc = await db.execute(
            select(func.coalesce(func.sum(Transaction.amount), 0)).where(
                Transaction.user_id == current_user.id,
                Transaction.type == TransactionType.income,
                Transaction.transaction_date >= m_start,
                Transaction.transaction_date <= m_end,
            )
        )
        exp = await db.execute(
            select(func.coalesce(func.sum(Transaction.amount), 0)).where(
                Transaction.user_id == current_user.id,
                Transaction.type == TransactionType.expense,
                Transaction.transaction_date >= m_start,
                Transaction.transaction_date <= m_end,
            )
        )
        i = Decimal(str(inc.scalar()))
        e = Decimal(str(exp.scalar()))
        result.append(MonthlySummary(month=label, income=i, expense=e, balance=i - e))
    return result


@router.get("/monthly-detail", response_model=MonthlyDetail)
async def monthly_detail(
    year: int = Query(default=None),
    month: int = Query(default=None),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    import calendar

    today = date.today()
    year = year or today.year
    month = month or today.month
    m_start = date(year, month, 1)
    m_end = date(year, month, calendar.monthrange(year, month)[1])
    label = f"{year}-{month:02d}"

    inc = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0)).where(
            Transaction.user_id == current_user.id,
            Transaction.type == TransactionType.income,
            Transaction.transaction_date >= m_start,
            Transaction.transaction_date <= m_end,
        )
    )
    exp = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0)).where(
            Transaction.user_id == current_user.id,
            Transaction.type == TransactionType.expense,
            Transaction.transaction_date >= m_start,
            Transaction.transaction_date <= m_end,
        )
    )
    income = Decimal(str(inc.scalar()))
    expense = Decimal(str(exp.scalar()))

    # Despesas por categoria
    cat_result = await db.execute(
        select(
            Category.id,
            Category.name,
            Category.color,
            func.sum(Transaction.amount).label("total"),
        )
        .select_from(Transaction)
        .join(Category, Transaction.category_id == Category.id, isouter=True)
        .where(
            Transaction.user_id == current_user.id,
            Transaction.type == TransactionType.expense,
            Transaction.transaction_date >= m_start,
            Transaction.transaction_date <= m_end,
        )
        .group_by(Category.id, Category.name, Category.color)
        .order_by(func.sum(Transaction.amount).desc())
    )
    cat_rows = cat_result.all()
    total_exp = expense or Decimal("1")
    expense_by_category = [
        CategorySummary(
            category_id=r.id,
            category_name=r.name or "Sem categoria",
            category_color=r.color or "#9ca3af",
            total=Decimal(str(r.total)),
            percentage=float(Decimal(str(r.total)) / total_exp * 100),
        )
        for r in cat_rows
    ]

    # Top 10 transações de despesa
    top_result = await db.execute(
        select(Transaction)
        .where(
            Transaction.user_id == current_user.id,
            Transaction.type == TransactionType.expense,
            Transaction.transaction_date >= m_start,
            Transaction.transaction_date <= m_end,
        )
        .options(selectinload(Transaction.category))
        .order_by(Transaction.amount.desc())
        .limit(10)
    )
    top_txs = top_result.scalars().all()

    return MonthlyDetail(
        month=label,
        income=income,
        expense=expense,
        balance=income - expense,
        expense_by_category=expense_by_category,
        top_transactions=[TransactionOut.model_validate(t) for t in top_txs],
    )
