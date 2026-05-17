from decimal import Decimal

from pydantic import BaseModel


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


class DashboardSummary(BaseModel):
    total_balance: Decimal
    monthly_income: Decimal
    monthly_expense: Decimal
    monthly_balance: Decimal
    recent_transactions: list
    monthly_chart: list[MonthlySummary]
    expense_by_category: list[CategorySummary]
