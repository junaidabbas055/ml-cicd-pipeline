"""
test_api.py — Integration tests for the FastAPI endpoints.
"""

import os
import sys
from pathlib import Path

import pandas as pd
import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


@pytest.fixture(scope="module")
def model_dir(tmp_path_factory):
    from src.train import train
    md = tmp_path_factory.mktemp("models")
    dd = tmp_path_factory.mktemp("data")
    csv_path = dd / "data.csv"
    rows = (
        [{"text": f"great product number {i}", "label": "positive"} for i in range(10)]
        + [{"text": f"bad product number {i}", "label": "negative"} for i in range(10)]
        + [{"text": f"ok product number {i}", "label": "neutral"} for i in range(10)]
    )
    pd.DataFrame(rows).to_csv(csv_path, index=False)
    train(data_path=csv_path, model_dir=md)
    return md


@pytest.fixture()
def client(model_dir, monkeypatch):
    monkeypatch.setenv("MODEL_DIR", str(model_dir))
    from api.app import app
    return TestClient(app)


def test_health_ok(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_health_model_loaded(client):
    r = client.get("/health")
    assert r.json()["model_loaded"] is True


def test_model_info_returns_metrics(client):
    r = client.get("/model/info")
    assert r.status_code == 200
    data = r.json()
    assert data["classes"] is not None
    assert 0.0 <= data["train_accuracy"] <= 1.0


def test_predict_returns_label(client):
    r = client.post("/predict", json={"text": "This is wonderful"})
    assert r.status_code == 200
    data = r.json()
    assert data["label"] in {"positive", "negative", "neutral"}
    assert 0.0 <= data["confidence"] <= 1.0


def test_predict_probabilities_sum_to_one(client):
    r = client.post("/predict", json={"text": "average quality"})
    probs = r.json()["probabilities"]
    assert abs(sum(probs.values()) - 1.0) < 0.01


def test_predict_empty_text_rejected(client):
    r = client.post("/predict", json={"text": ""})
    assert r.status_code == 422


def test_predict_batch_returns_all(client):
    r = client.post("/predict/batch", json={"texts": ["amazing!", "horrible!", "meh"]})
    assert r.status_code == 200
    assert len(r.json()) == 3


def test_predict_batch_empty_rejected(client):
    r = client.post("/predict/batch", json={"texts": []})
    assert r.status_code == 422
