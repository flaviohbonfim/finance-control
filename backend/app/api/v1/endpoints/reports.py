from datetime import date, datetime
from decimal import Decimal

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.deps import get_current_user
from app.core.database import get_db
from app.models.account import Account
from app.models.category import Category
from app.models.transaction import Transaction, TransactionType
from app.models.user import User
from app.schemas.report import CategorySummary, DashboardSummary, MonthlySummary
from app.schemas.transaction import TransactionOut

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/dashboard", response_model=DashboardSummary)
async def dashboard(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    today = date.today()
    month_start = today.replace(day=1)

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
        )
    )
    monthly_income = inc_result.scalar()

    # Monthly expense
    exp_result = await db.execute(
        select(func.coalesce(func.sum(Transaction.amount), 0)).where(
            Transaction.user_id == current_user.id,
            Transaction.type == TransactionType.expense,
            Transaction.transaction_date >= month_start,
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

    return DashboardSummary(
        total_balance=Decimal(str(total_balance)),
        monthly_income=Decimal(str(monthly_income)),
        monthly_expense=Decimal(str(monthly_expense)),
        monthly_balance=Decimal(str(monthly_income)) - Decimal(str(monthly_expense)),
        recent_transactions=[TransactionOut.model_validate(t) for t in recent],
        monthly_chart=monthly_chart,
        expense_by_category=expense_by_category,
    )


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
