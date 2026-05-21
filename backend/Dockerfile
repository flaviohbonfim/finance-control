FROM python:3.11-slim

WORKDIR /app

RUN pip install poetry==1.8.4 && \
    poetry config virtualenvs.create false

COPY pyproject.toml poetry.lock* ./
RUN poetry install --no-root --no-dev

COPY . .

EXPOSE 8000
ENTRYPOINT ["sh", "./entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
