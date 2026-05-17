from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel

from app.models.recurring_transaction import RecurringFrequency
from app.models.transaction import TransactionType


class RecurringCreate(BaseModel):
    account_id: int
    category_id: int | None = None
    type: TransactionType
    description: str
    amount: Decimal | None = None
    is_fixed: bool = True
    frequency: RecurringFrequency
    due_day: int
    due_month: int | None = None
    start_date: date
    end_date: date | None = None
    active: bool = True


class RecurringUpdate(BaseModel):
    account_id: int | None = None
    category_id: int | None = None
    type: TransactionType | None = None
    description: str | None = None
    amount: Decimal | None = None
    is_fixed: bool | None = None
    frequency: RecurringFrequency | None = None
    due_day: int | None = None
    due_month: int | None = None
    start_date: date | None = None
    end_date: date | None = None
    active: bool | None = None


class RecurringOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    account_id: int
    category_id: int | None
    type: TransactionType
    description: str
    amount: Decimal | None
    is_fixed: bool
    frequency: RecurringFrequency
    due_day: int
    due_month: int | None
    start_date: date
    end_date: date | None
    active: bool
    last_launched_date: date | None
    created_at: datetime
    account_name: str | None = None
    category_name: str | None = None
    category_color: str | None = None
    launched_this_month: bool = False


class LaunchIn(BaseModel):
    amount: Decimal | None = None
