from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel

from app.models.account import AccountType


class AccountCreate(BaseModel):
    name: str
    type: AccountType
    balance: Decimal = Decimal("0.00")
    color: str = "#6366f1"


class AccountUpdate(BaseModel):
    name: str | None = None
    type: AccountType | None = None
    color: str | None = None


class AccountOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    name: str
    type: AccountType
    balance: Decimal
    color: str
    created_at: datetime
