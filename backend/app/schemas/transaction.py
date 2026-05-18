from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel

from app.models.transaction import TransactionType
from app.schemas.category import CategoryOut


class TransactionCreate(BaseModel):
    account_id: int
    category_id: int | None = None
    type: TransactionType
    amount: Decimal
    description: str
    notes: str | None = None
    transaction_date: date
    installments: int = 1


class TransactionUpdate(BaseModel):
    account_id: int | None = None
    category_id: int | None = None
    amount: Decimal | None = None
    description: str | None = None
    notes: str | None = None
    transaction_date: date | None = None


class TransactionOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    account_id: int
    category_id: int | None
    type: TransactionType
    amount: Decimal
    description: str
    notes: str | None
    transaction_date: date
    created_at: datetime
    category: CategoryOut | None = None


class TransactionFilter(BaseModel):
    account_id: int | None = None
    category_id: int | None = None
    type: TransactionType | None = None
    date_from: date | None = None
    date_to: date | None = None
    page: int = 1
    page_size: int = 20


class PaginatedTransactions(BaseModel):
    items: list[TransactionOut]
    total: int
    page: int
    page_size: int
    pages: int
