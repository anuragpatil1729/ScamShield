#!/usr/bin/env python3
"""
ScamShield Layer 2 Model Server (DistilBERT ONNX v4)
Model path: /Users/anuragpatil/Downloads/MDM_hack/model2/v4
Serves real-time inference on port 5005 for ScamShield Flutter app.
"""
import os
import sys
import json
import numpy as np
import onnxruntime as ort
from flask import Flask, request, jsonify
from transformers import AutoTokenizer

app = Flask(__name__)

MODEL_DIR = "/Users/anuragpatil/Downloads/MDM_hack/model2/v4"
ONNX_PATH = os.path.join(MODEL_DIR, "model.onnx")

print(f"Loading Layer 2 DistilBERT Tokenizer from {MODEL_DIR}...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR)

print(f"Loading ONNX Inference Session from {ONNX_PATH}...")
session = ort.InferenceSession(ONNX_PATH)
print("Layer 2 DistilBERT v4 Model successfully loaded into memory!")


def classify_text(text: str):
    enc = tokenizer(text, return_tensors="np", truncation=True, max_length=128)
    inputs = {
        "input_ids": enc["input_ids"],
        "attention_mask": enc["attention_mask"]
    }
    logits = session.run(None, inputs)[0][0]
    # Softmax
    exp_logits = np.exp(logits - np.max(logits))
    probs = exp_logits / np.sum(exp_logits)
    ham_prob = float(probs[0])
    spam_prob = float(probs[1])

    # Infer intent label based on text and score
    intent = "legitimate_communication"
    if spam_prob >= 0.70:
        lower = text.lower()
        if any(w in lower for w in ["win", "won", "lottery", "prize", "claim", "reward", "cash", "bonus"]):
            intent = "lottery_reward_lure"
        elif any(w in lower for w in ["bank", "kyc", "suspend", "block", "account", "expire", "verify"]):
            intent = "credential_harvesting_phishing"
        elif any(w in lower for w in ["call", "txt", "text", "rate", "entry", "comp"]):
            intent = "premium_rate_sms_scam"
        else:
            intent = "high_risk_spam_solicitation"
    elif spam_prob >= 0.30:
        intent = "borderline_suspicious_solicitation"

    return {
        "status": "success",
        "model": "DistilBertForSequenceClassification-v4",
        "spam_probability": round(spam_prob, 4),
        "ham_probability": round(ham_prob, 4),
        "logits": [round(float(logits[0]), 4), round(float(logits[1]), 4)],
        "is_spam": spam_prob >= 0.50,
        "detected_intent": intent
    }


@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "ok",
        "model": "DistilBert-v4",
        "ready": True
    })


@app.route("/predict", methods=["POST"])
def predict():
    data = request.get_json(force=True, silent=True) or {}
    text = data.get("text", "")
    if not text:
        return jsonify({"status": "error", "message": "No text provided"}), 400

    result = classify_text(text)
    return jsonify(result)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5005))
    print(f"Starting Layer 2 DistilBERT Server on 0.0.0.0:{port}...")
    app.run(host="0.0.0.0", port=port, debug=False)
