from flask import Flask, render_template, request, jsonify
import requests

app = Flask(__name__)

OLLAMA_API_URL = "http://localhost:11434/api/generate"
OLLAMA_MODEL = "deepseek-r1:1.5b"  # Możesz też użyć np. "mistral" albo "llama3"

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/ask", methods=["POST"])
def ask():
    user_message = request.json["message"]

    # Zapytanie do lokalnego API Ollama
    response = requests.post(OLLAMA_API_URL, json={
        "model": OLLAMA_MODEL,
        "prompt": user_message,
        "stream": False
    })

    if response.status_code != 200:
        return jsonify({"reply": "❌ Błąd komunikacji z modelem Ollama."})

    reply_text = response.json().get("response", "").strip()
    return jsonify({"reply": reply_text})

if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0')
    
