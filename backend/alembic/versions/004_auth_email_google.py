"""auth: email verification and google oauth fields

Revision ID: 004
Revises: 003
Create Date: 2026-05-21 00:00:00.000000
"""

import sqlalchemy as sa
from alembic import op

revision = "004"
down_revision = "003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column("users", "hashed_password", existing_type=sa.String(255), nullable=True)

    op.add_column("users", sa.Column("google_id", sa.String(255), nullable=True))
    op.create_unique_constraint("uq_users_google_id", "users", ["google_id"])
    op.create_index("ix_users_google_id", "users", ["google_id"])

    op.add_column("users", sa.Column("is_verified", sa.Boolean(), nullable=False, server_default=sa.false()))
    op.add_column("users", sa.Column("verification_code", sa.String(6), nullable=True))
    op.add_column("users", sa.Column("verification_code_expires_at", sa.DateTime(), nullable=True))
    op.add_column("users", sa.Column("reset_password_code", sa.String(6), nullable=True))
    op.add_column("users", sa.Column("reset_password_code_expires_at", sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "reset_password_code_expires_at")
    op.drop_column("users", "reset_password_code")
    op.drop_column("users", "verification_code_expires_at")
    op.drop_column("users", "verification_code")
    op.drop_column("users", "is_verified")

    op.drop_index("ix_users_google_id", table_name="users")
    op.drop_constraint("uq_users_google_id", "users", type_="unique")
    op.drop_column("users", "google_id")

    op.alter_column("users", "hashed_password", existing_type=sa.String(255), nullable=False)
