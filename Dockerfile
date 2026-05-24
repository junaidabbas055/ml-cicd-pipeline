# ── Stage 1: Train ───────────────────────────────────────────────────────────
FROM python:3.11-slim AS trainer

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY data/ data/
COPY src/  src/

RUN python src/train.py


# ── Stage 2: Serve ────────────────────────────────────────────────────────────
FROM python:3.11-slim AS server

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source and trained artifacts from the trainer stage
COPY src/  src/
COPY api/  api/
COPY --from=trainer /app/models/ models/

ENV MODEL_DIR=models
ENV PORT=8000

EXPOSE 8000

CMD ["uvicorn", "api.app:app", "--host", "0.0.0.0", "--port", "8000"]
