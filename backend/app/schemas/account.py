from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel

from app.models.account import AccountType


class AccountCreate(BaseModel):
    name: str
    type: AccountType
    balance: Decimal = Decimal("0.00")
    color: str = "#6366f1"
    closing_day: int | None = None
    due_day: int | None = None
    credit_limit: Decimal | None = None


class AccountUpdate(BaseModel):
    name: str | None = None
    type: AccountType | None = None
    color: str | None = None
    closing_day: int | None = None
    due_day: int | None = None
    credit_limit: Decimal | None = None


class AccountOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    name: str
    type: AccountType
    balance: Decimal
    color: str
    closing_day: int | None
    due_day: int | None
    credit_limit: Decimal | None
    created_at: datetime


class InvoiceOut(BaseModel):
    current_total: Decimal
    current_start: date
    current_end: date
    next_total: Decimal
    next_start: date
    next_end: date
    due_day: int


class PayInvoiceIn(BaseModel):
    source_account_id: int
    amount: Decimal
