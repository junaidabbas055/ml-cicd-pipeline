"""
evaluate.py — Load a trained model and evaluate it against a dataset.
Exits with code 1 if accuracy is below the configured threshold (CI/CD quality gate).
"""

import json
import logging
import os
import pickle
import sys
from pathlib import Path

import pandas as pd
from sklearn.metrics import classification_report, confusion_matrix

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

DEFAULT_MODEL_DIR = Path("models")
DEFAULT_DATA_PATH = Path("data/sample_data.csv")


def evaluate(data_path: Path = None, model_dir: Path = None) -> dict:
    # Resolve paths at call time
    if data_path is None:
        data_path = Path(os.getenv("DATA_PATH", str(DEFAULT_DATA_PATH)))
    if model_dir is None:
        model_dir = Path(os.getenv("MODEL_DIR", str(DEFAULT_MODEL_DIR)))

    accuracy_threshold = float(os.getenv("ACCURACY_THRESHOLD", "0.70"))
    model_path = model_dir / "sentiment_model.pkl"
    encoder_path = model_dir / "label_encoder.pkl"
    report_path = model_dir / "eval_report.json"

    if not model_path.exists():
        raise FileNotFoundError(f"Model not found at {model_path}. Run src/train.py first.")

    with open(model_path, "rb") as f:
        pipeline = pickle.load(f)
    with open(encoder_path, "rb") as f:
        le = pickle.load(f)

    df = pd.read_csv(data_path).dropna(subset=["text", "label"])
    texts = df["text"].tolist()
    y_true = le.transform(df["label"].values)

    y_pred = pipeline.predict(texts)
    accuracy = float((y_pred == y_true).mean())

    report = classification_report(y_true, y_pred, target_names=le.classes_, output_dict=True)
    cm = confusion_matrix(y_true, y_pred).tolist()

    log.info(f"\n{classification_report(y_true, y_pred, target_names=le.classes_)}")

    result = {
        "accuracy": round(accuracy, 4),
        "threshold": accuracy_threshold,
        "passed": bool(accuracy >= accuracy_threshold),
        "classification_report": report,
        "confusion_matrix": cm,
        "classes": le.classes_.tolist(),
    }

    report_path.parent.mkdir(parents=True, exist_ok=True)
    with open(report_path, "w") as f:
        json.dump(result, f, indent=2)

    log.info(f"Evaluation report saved to {report_path}")
    return result


if __name__ == "__main__":
    result = evaluate()
    print(json.dumps({k: v for k, v in result.items() if k != "classification_report"}, indent=2))

    if not result["passed"]:
        log.error(f"Quality gate FAILED: accuracy {result['accuracy']:.4f} < threshold {result['threshold']}")
        sys.exit(1)

    log.info(f"Quality gate PASSED: accuracy {result['accuracy']:.4f} >= threshold {result['threshold']}")
