"""credit card fields and recurring transactions

Revision ID: 002
Revises: 001
Create Date: 2025-01-02 00:00:00.000000
"""

import sqlalchemy as sa
from alembic import op

revision = "002"
down_revision = "001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("accounts", sa.Column("closing_day", sa.Integer(), nullable=True))
    op.add_column("accounts", sa.Column("due_day", sa.Integer(), nullable=True))
    op.add_column("accounts", sa.Column("credit_limit", sa.Numeric(15, 2), nullable=True))

    op.create_table(
        "recurring_transactions",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False, index=True),
        sa.Column(
            "account_id", sa.Integer(), sa.ForeignKey("accounts.id"), nullable=False, index=True
        ),
        sa.Column("category_id", sa.Integer(), sa.ForeignKey("categories.id"), nullable=True),
        sa.Column(
            "type",
            sa.Enum("income", "expense", name="transactiontype"),
            nullable=False,
        ),
        sa.Column("description", sa.String(255), nullable=False),
        sa.Column("amount", sa.Numeric(15, 2), nullable=True),
        sa.Column("is_fixed", sa.Boolean(), nullable=False, default=True),
        sa.Column(
            "frequency",
            sa.Enum("monthly", "yearly", name="recurringfrequency"),
            nullable=False,
        ),
        sa.Column("due_day", sa.Integer(), nullable=False),
        sa.Column("due_month", sa.Integer(), nullable=True),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=True),
        sa.Column("active", sa.Boolean(), nullable=False, default=True),
        sa.Column("last_launched_date", sa.Date(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("recurring_transactions")
    op.drop_column("accounts", "credit_limit")
    op.drop_column("accounts", "due_day")
    op.drop_column("accounts", "closing_day")
