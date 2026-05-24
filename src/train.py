"""
train.py — Train a sentiment analysis classifier using TF-IDF + Logistic Regression.
Saves the model pipeline to models/sentiment_model.pkl and logs metrics to models/train_metrics.json.
"""

import json
import logging
import os
import pickle
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import LabelEncoder

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

DEFAULT_DATA_PATH = Path("data/sample_data.csv")
DEFAULT_MODEL_DIR = Path("models")
TEST_SIZE = float(os.getenv("TEST_SIZE", "0.2"))
RANDOM_STATE = int(os.getenv("RANDOM_STATE", "42"))


def load_data(path: Path) -> tuple:
    log.info(f"Loading data from {path}")
    df = pd.read_csv(path)
    assert "text" in df.columns and "label" in df.columns, \
        "CSV must contain 'text' and 'label' columns"
    df = df.dropna(subset=["text", "label"])
    log.info(f"Loaded {len(df)} samples | Classes: {df['label'].value_counts().to_dict()}")
    return df["text"].tolist(), df["label"].values


def build_pipeline() -> Pipeline:
    return Pipeline([
        ("tfidf", TfidfVectorizer(
            ngram_range=(1, 2),
            max_features=10_000,
            sublinear_tf=True,
            strip_accents="unicode",
        )),
        ("clf", LogisticRegression(
            max_iter=1000,
            C=1.0,
            solver="lbfgs",
            random_state=RANDOM_STATE,
        )),
    ])


def train(data_path: Path = None, model_dir: Path = None) -> dict:
    # Resolve paths at call time (respects env vars set after module import)
    if data_path is None:
        data_path = Path(os.getenv("DATA_PATH", str(DEFAULT_DATA_PATH)))
    if model_dir is None:
        model_dir = Path(os.getenv("MODEL_DIR", str(DEFAULT_MODEL_DIR)))

    model_path = model_dir / "sentiment_model.pkl"
    encoder_path = model_dir / "label_encoder.pkl"
    metrics_path = model_dir / "train_metrics.json"

    model_dir.mkdir(parents=True, exist_ok=True)

    texts, raw_labels = load_data(data_path)

    le = LabelEncoder()
    labels = le.fit_transform(raw_labels)
    log.info(f"Label mapping: { {k: v for v, k in enumerate(le.classes_)} }")

    X_train, X_test, y_train, y_test = train_test_split(
        texts, labels, test_size=TEST_SIZE, random_state=RANDOM_STATE, stratify=labels
    )

    pipeline = build_pipeline()
    log.info("Training pipeline …")
    pipeline.fit(X_train, y_train)

    train_acc = pipeline.score(X_train, y_train)
    test_acc = pipeline.score(X_test, y_test)
    log.info(f"Train accuracy: {train_acc:.4f} | Test accuracy: {test_acc:.4f}")

    with open(model_path, "wb") as f:
        pickle.dump(pipeline, f)
    with open(encoder_path, "wb") as f:
        pickle.dump(le, f)

    metrics = {
        "train_accuracy": round(train_acc, 4),
        "test_accuracy": round(test_acc, 4),
        "n_train": len(X_train),
        "n_test": len(X_test),
        "classes": le.classes_.tolist(),
    }
    with open(metrics_path, "w") as f:
        json.dump(metrics, f, indent=2)

    log.info(f"Model saved to {model_path}")
    log.info(f"Metrics saved to {metrics_path}")
    return metrics


if __name__ == "__main__":
    metrics = train()
    print(json.dumps(metrics, indent=2))
