"""
test_train.py — Unit tests for training and evaluation pipeline.
"""

import json
import sys
from pathlib import Path

import pandas as pd
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from src.train import build_pipeline, load_data, train
from src.evaluate import evaluate
from src.predict import predict


@pytest.fixture()
def temp_data(tmp_path):
    csv_path = tmp_path / "test_data.csv"
    rows = (
        [{"text": f"excellent product number {i}", "label": "positive"} for i in range(10)]
        + [{"text": f"terrible product number {i}", "label": "negative"} for i in range(10)]
        + [{"text": f"average product number {i}", "label": "neutral"} for i in range(10)]
    )
    pd.DataFrame(rows).to_csv(csv_path, index=False)
    return csv_path


@pytest.fixture()
def trained_model(temp_data, tmp_path):
    model_dir = tmp_path / "models"
    metrics = train(data_path=temp_data, model_dir=model_dir)
    return model_dir, metrics


# ── Training ──────────────────────────────────────────────────────────────────

def test_load_data_shape(temp_data):
    texts, labels = load_data(temp_data)
    assert len(texts) == 30


def test_load_data_no_nulls(temp_data):
    texts, _ = load_data(temp_data)
    assert all(isinstance(t, str) and t.strip() for t in texts)


def test_build_pipeline_steps():
    pipeline = build_pipeline()
    assert list(pipeline.named_steps.keys()) == ["tfidf", "clf"]


def test_train_produces_artifacts(trained_model):
    model_dir, _ = trained_model
    assert (model_dir / "sentiment_model.pkl").exists()
    assert (model_dir / "label_encoder.pkl").exists()
    assert (model_dir / "train_metrics.json").exists()


def test_train_metrics_schema(trained_model):
    _, metrics = trained_model
    for key in ("train_accuracy", "test_accuracy", "n_train", "n_test", "classes"):
        assert key in metrics
    assert 0.0 <= metrics["train_accuracy"] <= 1.0
    assert set(metrics["classes"]) == {"negative", "neutral", "positive"}


# ── Evaluation ────────────────────────────────────────────────────────────────

def test_evaluate_produces_report(trained_model, temp_data):
    model_dir, _ = trained_model
    result = evaluate(data_path=temp_data, model_dir=model_dir)
    assert "accuracy" in result and "passed" in result
    assert (model_dir / "eval_report.json").exists()


def test_evaluate_low_threshold_passes(trained_model, temp_data, monkeypatch):
    model_dir, _ = trained_model
    monkeypatch.setenv("ACCURACY_THRESHOLD", "0.0")
    result = evaluate(data_path=temp_data, model_dir=model_dir)
    assert result["passed"] is True


def test_evaluate_high_threshold_fails(trained_model, temp_data, monkeypatch):
    model_dir, _ = trained_model
    monkeypatch.setenv("ACCURACY_THRESHOLD", "1.01")
    result = evaluate(data_path=temp_data, model_dir=model_dir)
    assert result["passed"] is False


# ── Prediction ────────────────────────────────────────────────────────────────

def test_predict_single(trained_model):
    model_dir, _ = trained_model
    results = predict(
        "This is a great product",
        model_path=model_dir / "sentiment_model.pkl",
        encoder_path=model_dir / "label_encoder.pkl",
    )
    assert len(results) == 1
    r = results[0]
    assert r["label"] in {"positive", "negative", "neutral"}
    assert 0.0 <= r["confidence"] <= 1.0
    assert set(r["probabilities"].keys()) == {"positive", "negative", "neutral"}


def test_predict_batch(trained_model):
    model_dir, _ = trained_model
    texts = ["Great!", "Terrible!", "Okay I guess"]
    results = predict(
        texts,
        model_path=model_dir / "sentiment_model.pkl",
        encoder_path=model_dir / "label_encoder.pkl",
    )
    assert len(results) == 3


def test_predict_missing_model_raises():
    with pytest.raises(FileNotFoundError):
        predict("hello", model_path=Path("/nonexistent/model.pkl"), encoder_path=Path("/nonexistent/enc.pkl"))
