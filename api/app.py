"""
app.py — FastAPI REST API for the sentiment analysis model.
"""

import json
import os
import sys
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from src.predict import predict  # noqa: E402

app = FastAPI(
    title="Sentiment Analysis API",
    description="ML CI/CD Pipeline — Sentiment classifier served via FastAPI",
    version="1.0.0",
)


def _model_dir() -> Path:
    return Path(os.getenv("MODEL_DIR", "models"))


class PredictRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=5000)

    model_config = {"json_schema_extra": {"example": {"text": "This product is amazing!"}}}


class PredictBatchRequest(BaseModel):
    texts: list[str] = Field(..., min_length=1, max_length=100)


class PredictionResult(BaseModel):
    text: str
    label: str
    confidence: float
    probabilities: dict[str, float]


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool


class ModelInfoResponse(BaseModel):
    version: str
    classes: Optional[list[str]]
    train_accuracy: Optional[float]
    test_accuracy: Optional[float]


@app.get("/health", response_model=HealthResponse, tags=["System"])
def health():
    model_loaded = (_model_dir() / "sentiment_model.pkl").exists()
    return {"status": "ok", "model_loaded": model_loaded}


@app.get("/model/info", response_model=ModelInfoResponse, tags=["System"])
def model_info():
    info: dict = {"version": "1.0.0", "classes": None, "train_accuracy": None, "test_accuracy": None}
    metrics_path = _model_dir() / "train_metrics.json"
    if metrics_path.exists():
        with open(metrics_path) as f:
            metrics = json.load(f)
        info.update({
            "classes": metrics.get("classes"),
            "train_accuracy": metrics.get("train_accuracy"),
            "test_accuracy": metrics.get("test_accuracy"),
        })
    return info


@app.post("/predict", response_model=PredictionResult, tags=["Inference"])
def predict_single(body: PredictRequest):
    try:
        model_dir = _model_dir()
        results = predict(
            body.text,
            model_path=model_dir / "sentiment_model.pkl",
            encoder_path=model_dir / "label_encoder.pkl",
        )
        return results[0]
    except FileNotFoundError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {e}")


@app.post("/predict/batch", response_model=list[PredictionResult], tags=["Inference"])
def predict_batch(body: PredictBatchRequest):
    try:
        model_dir = _model_dir()
        return predict(
            body.texts,
            model_path=model_dir / "sentiment_model.pkl",
            encoder_path=model_dir / "label_encoder.pkl",
        )
    except FileNotFoundError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {e}")
