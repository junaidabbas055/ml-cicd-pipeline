"""
predict.py — Inference logic shared by the API and CLI usage.
"""

import pickle
from pathlib import Path
from typing import Union

MODEL_DIR = Path("models")
MODEL_PATH = MODEL_DIR / "sentiment_model.pkl"
ENCODER_PATH = MODEL_DIR / "label_encoder.pkl"

_pipeline = None
_label_encoder = None


def load_model(model_path: Path = None, encoder_path: Path = None):
    """Load model from explicit paths (used in tests) or module-level defaults."""
    global _pipeline, _label_encoder
    mp = model_path or MODEL_PATH
    ep = encoder_path or ENCODER_PATH
    if not mp.exists():
        raise FileNotFoundError(f"No model found at {mp}. Run `python src/train.py` first.")
    with open(mp, "rb") as f:
        _pipeline = pickle.load(f)
    with open(ep, "rb") as f:
        _label_encoder = pickle.load(f)


def _ensure_loaded():
    global _pipeline, _label_encoder
    if _pipeline is None:
        load_model()


def predict(text: Union[str, list], model_path: Path = None, encoder_path: Path = None) -> list:
    """
    Predict sentiment for one or more text inputs.

    Args:
        text: A single string or list of strings.
        model_path: Optional explicit model path (for testing).
        encoder_path: Optional explicit encoder path (for testing).

    Returns:
        List of dicts with keys: text, label, confidence, probabilities.
    """
    global _pipeline, _label_encoder

    if model_path or encoder_path:
        # Explicit paths provided — always reload (used in tests)
        load_model(model_path, encoder_path)
    else:
        _ensure_loaded()

    single = isinstance(text, str)
    texts = [text] if single else text

    probs = _pipeline.predict_proba(texts)
    class_indices = probs.argmax(axis=1)
    labels = _label_encoder.inverse_transform(class_indices)
    class_names = _label_encoder.classes_

    results = []
    for t, label, prob_row in zip(texts, labels, probs):
        results.append({
            "text": t,
            "label": label,
            "confidence": round(float(prob_row.max()), 4),
            "probabilities": {
                cls: round(float(p), 4)
                for cls, p in zip(class_names, prob_row)
            },
        })
    return results


if __name__ == "__main__":
    import sys, json
    text_input = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "This product is great!"
    print(json.dumps(predict(text_input), indent=2))
