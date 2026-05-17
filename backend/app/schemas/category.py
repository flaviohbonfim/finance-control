from datetime import datetime

from pydantic import BaseModel

from app.models.category import CategoryType


class CategoryCreate(BaseModel):
    name: str
    type: CategoryType
    icon: str = "tag"
    color: str = "#6366f1"


class CategoryUpdate(BaseModel):
    name: str | None = None
    icon: str | None = None
    color: str | None = None


class CategoryOut(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    name: str
    type: CategoryType
    icon: str
    color: str
    created_at: datetime
