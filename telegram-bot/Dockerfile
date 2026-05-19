FROM python:3.11-slim
WORKDIR /app

RUN pip install poetry==1.8.4 && \
    poetry config virtualenvs.create false

COPY pyproject.toml poetry.lock* ./
RUN poetry install --no-root

COPY bot.py .
CMD ["python", "bot.py"]
