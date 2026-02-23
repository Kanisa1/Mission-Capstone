Run the FastAPI app (serves API + web frontend)

Prerequisites
- Python 3.9+ virtualenv with required packages installed. See project `requirements.txt` and `requirements_ml.txt`.

Start the server (from workspace root):

```powershell
# activate venv if not already active
& .\.venv\Scripts\Activate.ps1

# from project root
cd "c:\Users\HP\Mission-Capstone"

# run FastAPI (this will serve both API endpoints and the webapp static files)
uvicorn API.api:app --host 0.0.0.0 --port 8000 --reload
```

Open the frontend in your browser:
- http://127.0.0.1:8000/index.html (or simply http://127.0.0.1:8000/)

Notes
- The API loads the trained model from `dataset/multimodal_model.pt`. Ensure that file exists before starting the server.
- CORS is enabled for development (`allow_origins=["*"]`). Lock this down for production.
