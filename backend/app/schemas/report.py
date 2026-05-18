from decimal import Decimal

from pydantic import BaseModel

from app.schemas.recurring_transaction import RecurringOut
from app.schemas.transaction import TransactionOut


class MonthlySummary(BaseModel):
    month: str
    income: Decimal
    expense: Decimal
    balance: Decimal


class CategorySummary(BaseModel):
    category_id: int | None
    category_name: str
    category_color: str
    total: Decimal
    percentage: float


class MonthlyDetail(BaseModel):
    month: str
    income: Decimal
    expense: Decimal
    balance: Decimal
    expense_by_category: list[CategorySummary]
    top_transactions: list[TransactionOut]


class DashboardSummary(BaseModel):
    total_balance: Decimal
    monthly_income: Decimal
    monthly_expense: Decimal
    monthly_balance: Decimal
    recent_transactions: list
    monthly_chart: list[MonthlySummary]
    expense_by_category: list[CategorySummary]
    recurring_this_month: list[RecurringOut]
