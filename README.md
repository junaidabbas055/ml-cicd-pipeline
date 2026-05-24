# ML CI/CD Pipeline — Sentiment Analysis

A production-grade MLOps pipeline demonstrating end-to-end machine learning automation: **train → evaluate → test → containerize**, all orchestrated via GitHub Actions.

Built as a portfolio project to showcase ML engineering and DevOps integration skills.

---

## Architecture

```
ml-cicd-pipeline/
├── .github/workflows/
│   └── ml-pipeline.yml     # CI/CD: 5-stage pipeline
├── src/
│   ├── train.py            # Training — TF-IDF + Logistic Regression
│   ├── evaluate.py         # Evaluation + quality gate (configurable threshold)
│   └── predict.py          # Inference logic (shared by API & CLI)
├── api/
│   └── app.py              # FastAPI REST endpoint
├── tests/
│   ├── test_train.py       # Unit tests for train/evaluate/predict
│   └── test_api.py         # Integration tests for API endpoints
├── data/
│   └── sample_data.csv     # Sample labelled dataset
├── Dockerfile              # Multi-stage build: train → serve
└── requirements.txt
```

---

## CI/CD Pipeline

The GitHub Actions workflow runs 5 sequential jobs on every push:

```
lint ──► train ──► evaluate ──► test ──► docker
                      │
                 Quality Gate
              (fails if accuracy
               below threshold)
```

| Job | What it does |
|-----|-------------|
| **lint** | Ruff linter + formatter check |
| **train** | Trains model, uploads artifacts |
| **evaluate** | Runs evaluation, fails CI if accuracy < 70% |
| **test** | Runs all tests with coverage report |
| **docker** | Builds image + smoke-tests the live container |

---

## Quick Start

### 1. Clone and install

```bash
git clone https://github.com/junaidabbas055/ml-cicd-pipeline.git
cd ml-cicd-pipeline
pip install -r requirements.txt
```

### 2. Train the model

```bash
python src/train.py
# Outputs: models/sentiment_model.pkl, models/train_metrics.json
```

### 3. Evaluate

```bash
python src/evaluate.py
# Exits with code 1 if accuracy < ACCURACY_THRESHOLD
```

### 4. Run tests

```bash
pytest tests/ -v --cov=src --cov=api
```

### 5. Start the API

```bash
uvicorn api.app:app --reload
# API docs: http://localhost:8000/docs
```

### 6. Run via Docker

```bash
docker build -t sentiment-api .
docker run -p 8000:8000 sentiment-api
```

---

## API Reference

### `POST /predict`

```bash
curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"text": "This product is absolutely fantastic!"}'
```

```json
{
  "text": "This product is absolutely fantastic!",
  "label": "positive",
  "confidence": 0.9241,
  "probabilities": {
    "negative": 0.0312,
    "neutral": 0.0447,
    "positive": 0.9241
  }
}
```

### `POST /predict/batch`

```bash
curl -X POST http://localhost:8000/predict/batch \
  -H "Content-Type: application/json" \
  -d '{"texts": ["Love it!", "Terrible quality", "It is okay"]}'
```

### `GET /health`

```json
{ "status": "ok", "model_loaded": true }
```

### `GET /model/info`

```json
{
  "version": "1.0.0",
  "classes": ["negative", "neutral", "positive"],
  "train_accuracy": 1.0,
  "test_accuracy": 0.8333
}
```

Interactive docs available at `http://localhost:8000/docs` (Swagger UI).

---

## Configuration

All configurable via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `DATA_PATH` | `data/sample_data.csv` | Path to training data |
| `MODEL_DIR` | `models` | Directory for saved artifacts |
| `TEST_SIZE` | `0.2` | Train/test split ratio |
| `RANDOM_STATE` | `42` | Reproducibility seed |
| `ACCURACY_THRESHOLD` | `0.70` | Minimum accuracy for quality gate |

---

## Bring Your Own Data

The pipeline accepts any CSV with two columns:

```
text,label
"Your text here",positive
"Another text",negative
```

Point at it via the environment variable:

```bash
DATA_PATH=path/to/your_data.csv python src/train.py
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| ML | scikit-learn, TF-IDF, Logistic Regression |
| API | FastAPI, Pydantic, Uvicorn |
| Testing | pytest, pytest-cov, HTTPX |
| CI/CD | GitHub Actions |
| Containerisation | Docker (multi-stage build) |
| Linting | Ruff |

---

## Author

**Junaid Abbas** — ML & Infrastructure Engineer  
Kaiserslautern, Germany · [junaidabbas055@gmail.com](mailto:junaidabbas055@gmail.com)
