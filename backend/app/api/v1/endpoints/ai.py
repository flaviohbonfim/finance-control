import json
import re

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.database import get_db
from app.models.category import Category
from app.models.transaction import Transaction, TransactionType
from app.models.user import User

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/auto-categorize")
async def auto_categorize(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not settings.GEMINI_API_KEY:
        raise HTTPException(status_code=400, detail="GEMINI_API_KEY não configurada no servidor")

    # Busca transações sem categoria
    tx_result = await db.execute(
        select(Transaction).where(
            Transaction.user_id == current_user.id,
            Transaction.category_id.is_(None),
            Transaction.type == TransactionType.expense,
        )
    )
    transactions = tx_result.scalars().all()

    if not transactions:
        return {"categorized": 0, "message": "Nenhuma transação sem categoria encontrada"}

    # Busca categorias disponíveis
    cat_result = await db.execute(select(Category).where(Category.user_id == current_user.id))
    categories = cat_result.scalars().all()

    if not categories:
        raise HTTPException(status_code=400, detail="Nenhuma categoria cadastrada")

    # Monta o prompt
    categories_list = "\n".join(f'  {{"id": {c.id}, "name": "{c.name}"}}' for c in categories)
    transactions_list = "\n".join(
        f'  {{"id": {t.id}, "description": "{t.description}"}}'
        for t in transactions[:200]  # limite de 200 por chamada
    )

    prompt = f"""Você é um categorizador de transações financeiras brasileiras.
Classifique cada transação na categoria mais adequada com base na descrição.
Descrições de cartão podem ter prefixos como "DL*", "EBN *", "ZP*", "EC *" — ignore-os.

Categorias disponíveis:
{categories_list}

Transações para classificar:
{transactions_list}

Responda APENAS com um array JSON válido, sem explicações, sem markdown:
[{{"transaction_id": <id>, "category_id": <id>}}, ...]

Se uma transação não se encaixar em nenhuma categoria, omita-a do resultado."""

    try:
        from google import genai

        client = genai.Client(api_key=settings.GEMINI_API_KEY)
        response = await client.aio.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
        )
        raw = response.text.strip()

        # Extrai JSON mesmo se vier com markdown
        match = re.search(r"\[.*\]", raw, re.DOTALL)
        if not match:
            raise ValueError("Resposta não contém JSON válido")
        suggestions = json.loads(match.group())
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Erro ao chamar Gemini: {e}") from e

    # Aplica as categorias sugeridas
    tx_map = {t.id: t for t in transactions}
    cat_ids = {c.id for c in categories}
    categorized = 0

    for item in suggestions:
        tx_id = item.get("transaction_id")
        cat_id = item.get("category_id")
        if tx_id in tx_map and cat_id in cat_ids:
            tx_map[tx_id].category_id = cat_id
            categorized += 1

    await db.commit()

    return {
        "categorized": categorized,
        "total_uncategorized": len(transactions),
        "message": f"{categorized} de {len(transactions)} transações categorizadas automaticamente",
    }
